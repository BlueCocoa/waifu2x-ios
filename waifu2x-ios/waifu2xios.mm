//
//  waifu2xios.mm
//  waifu2xios
//
//  Created by Cocoa on 2019/4/25.
//  Copyright © 2019-2020 Cocoa. All rights reserved.
//

#import "waifu2xios.h"
#import "waifu2x.h"
#import <unistd.h>
#import <algorithm>
#import <vector>
#import <queue>
#import <thread>

// image decoder and encoder with stb
#define STB_IMAGE_IMPLEMENTATION
#define STBI_NO_PSD
#define STBI_NO_TGA
#define STBI_NO_GIF
#define STBI_NO_HDR
#define STBI_NO_PIC
#include "stb_image.h"
#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"

// ncnn
#include "cpu.h"
#include "gpu.h"
#include "platform.h"
#include "filesystem_utils.h"

class Task
{
public:
    int id;

    path_t inpath;
    path_t outpath;
    bool save_file;

    ncnn::Mat inimage;
    ncnn::Mat outimage;
    uint64_t total;
};

class TaskQueue
{
public:
    TaskQueue()
    {
    }

    void put(const Task& v)
    {
        lock.lock();

        while (tasks.size() >= 8) // FIXME hardcode queue length
        {
            condition.wait(lock);
        }

        tasks.push(v);

        lock.unlock();

        condition.signal();
    }

    void get(Task& v)
    {
        lock.lock();

        while (tasks.size() == 0)
        {
            condition.wait(lock);
        }

        v = tasks.front();
        tasks.pop();

        lock.unlock();

        condition.signal();
    }

private:
    ncnn::Mutex lock;
    ncnn::ConditionVariable condition;
    std::queue<Task> tasks;
};

TaskQueue toproc;
TaskQueue tosave;

#ifdef ENABLE_VIDEO
class VideoThreadParams
{
public:
    cv::VideoCapture * video;
    int scale, jobs_proc, jobs_save;
};
#endif

class ProcThreadParams
{
public:
    const Waifu2x* waifu2x;
    waifu2xProcessPercentageCallback cb;
};

void* proc(void* args)
{
    const ProcThreadParams* ptp = (const ProcThreadParams*)args;
    const Waifu2x* waifu2x = ptp->waifu2x;

    for (;;)
    {
        Task v;

        toproc.get(v);

        if (v.id == -233)
            break;

        waifu2x->process(v.inimage, v.outimage, ptp->cb);

        tosave.put(v);
    }

    return 0;
}

class SaveThreadParams
{
public:
    int verbose;
    waifu2xCompleteSingleBlock cb;
};

#ifdef ENABLE_VIDEO
void * read_video(void* args)
{
    const VideoThreadParams* vtp = (const VideoThreadParams*)args;
    // load image
    uint64_t count = (uint64_t)vtp->video->get(cv::CAP_PROP_FRAME_COUNT);
    uint64_t current = 0;
    
    cv::VideoCapture &video=*vtp->video;
    while (1) {
        cv::Mat frame;
        video >> frame;
        if (frame.empty()) {
            break;
        }
        
        Task v;
        v.id = (int)current;
        v.inpath = "";
        v.outpath = "";
        v.total = count;
        
        v.inimage = ncnn::Mat(frame.size().width, frame.size().height, (void*)frame.data, (size_t)3, 3);
        v.outimage = ncnn::Mat(frame.size().width * vtp->scale, frame.size().height * vtp->scale, (size_t)3u, 3);
        v.save_file = false;
        toproc.put(v);
        current++;
    }
    
    Task end;
    end.id = -233;

    for (int i=0; i<vtp->jobs_proc; i++)
    {
        toproc.put(end);
    }
    
    for (int i=0; i<vtp->jobs_save; i++)
    {
        tosave.put(end);
    }
    
    return NULL;
}
#endif

void* save(void* args)
{
    const SaveThreadParams* stp = (const SaveThreadParams*)args;
    const int verbose = stp->verbose;

    for (;;)
    {
        Task v;

        tosave.get(v);

        if (v.id == -233)
            break;

        if (stp->cb) {
            // most of the output are correct
            stp->cb(v.outimage, v.id, v.total);
        }
    }

    return 0;
}

@implementation waifu2xios

//+ (void)videoInput:(cv::VideoCapture&)video
//        noise:(int)noise
//        scale:(int)scale
//     tilesize:(int)tilesize
//        model:(NSString *)model
//        gpuid:(int)gpuid
//     tta_mode:(BOOL)enable_tta_mode
// proc_job_num:(int)jobs_proc
// save_job_num:(int)jobs_save
//      save_cb:(waifu2xCompleteSingleBlock)save_cb
//    VRAMUsage:(double *)usage
//     progress:(waifu2xProgressBlock)cb {
//    int total = 9;
//    if (noise < -1 || noise > 3)
//    {
//        if (cb) cb(1, total, NSLocalizedString(@"Error: supported noise is 0, 1 or 2", @""));
//        return;
//    }
//
//    if (scale < 1 || scale > 2)
//    {
//        if (cb) cb(1, total, NSLocalizedString(@"Error: supported scale is 1 or 2", @""));
//        return;
//    }
//
//    if (tilesize < 32)
//    {
//        if (cb) cb(1, total, NSLocalizedString(@"Error: tilesize should no less than 32", @""));
//        return;
//    }
//
//    if (jobs_proc <= 0)
//    {
//        jobs_proc = INT32_MAX;
//    }
//
//    if (jobs_save <= 0)
//    {
//        jobs_save = 2;
//    }
//
//    if (cb) cb(2, total, NSLocalizedString(@"Prepare models...", @""));
//
//    int prepadding = 0;
//    if ([model isEqualToString:@"models-cunet"]) {
//        if (noise == -1)
//        {
//            prepadding = 18;
//        }
//        else if (scale == 1)
//        {
//            prepadding = 28;
//        }
//        else if (scale == 2)
//        {
//            prepadding = 18;
//        }
//    } else if ([model isEqualToString:@"models-upconv_7_anime_style_art_rgb"]) {
//        prepadding = 7;
//    } else if ([model isEqualToString:@"models-upconv_7_photo"]) {
//        prepadding = 7;
//    } else {
//        if (cb) cb(3, total, NSLocalizedString(@"[ERROR] No such model", @""));
//        return;
//    }
//
//    NSString * parampath = nil;
//    NSString * modelpath = nil;
//    if (noise == -1)
//    {
//        parampath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/scale2.0x_model.param", model] ofType:nil];
//        modelpath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/scale2.0x_model.bin", model] ofType:nil];
//    }
//    else if (scale == 1)
//    {
//        parampath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/noise%d_model.param", model, noise] ofType:nil];
//        modelpath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/noise%d_model.bin", model, noise] ofType:nil];
//    }
//    else if (scale == 2)
//    {
//        parampath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/noise%d_scale2.0x_model.param", model, noise] ofType:nil];
//        modelpath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/noise%d_scale2.0x_model.bin", model, noise] ofType:nil];
//    }
//
//    if (cb) cb(3, total, NSLocalizedString(@"Creating GPU instance...", @""));
//    ncnn::create_gpu_instance();
//
//    int gpu_count = ncnn::get_gpu_count();
//    if (gpuid < 0 || gpuid >= gpu_count)
//    {
//        if (cb) cb(3, total, NSLocalizedString(@"[ERROR] Invalid gpu device", @""));
//
//        ncnn::destroy_gpu_instance();
//        return;
//    }
//
//    int gpu_queue_count = ncnn::get_gpu_info(gpuid).compute_queue_count;
//    const_cast<ncnn::GpuInfo&>(ncnn::get_gpu_info(gpuid)).buffer_offset_alignment = 16;
//    jobs_proc = std::min(jobs_proc, gpu_queue_count);
//
//    {
//        Waifu2x waifu2x(gpuid, enable_tta_mode);
//
//        if (cb) cb(4, total, NSLocalizedString(@"Loading models...", @""));
//        waifu2x.load([parampath UTF8String], [modelpath UTF8String]);
//
//        waifu2x.noise = noise;
//        waifu2x.scale = scale;
//        waifu2x.tilesize = tilesize;
//        waifu2x.prepadding = prepadding;
//
//        // main routine
//        {
//            if (cb) cb(5, total, NSLocalizedString(@"Initializing pipeline...", @""));
//
//            // waifu2x proc
//            ProcThreadParams ptp;
//            ptp.waifu2x = &waifu2x;
//
//            std::vector<ncnn::Thread*> proc_threads(jobs_proc);
//            for (int i=0; i<jobs_proc; i++)
//            {
//                proc_threads[i] = new ncnn::Thread(proc, (void*)&ptp);
//            }
//
//            // save image
//            SaveThreadParams stp;
//            stp.verbose = 0;
//            stp.cb = save_cb;
//
//            std::vector<ncnn::Thread*> save_threads(jobs_save);
//            for (int i=0; i<jobs_save; i++)
//            {
//                save_threads[i] = new ncnn::Thread(save, (void*)&stp);
//            }
//            // end
//
//            VideoThreadParams vtp;
//            vtp.video = &video;
//            vtp.scale = scale;
//            vtp.jobs_proc = jobs_proc;
//            vtp.jobs_save = jobs_save;
//
//            ncnn::Thread* videoProc = new ncnn::Thread(read_video, (void *)&vtp);
//
//            for (int i=0; i<jobs_proc; i++)
//            {
//                proc_threads[i]->join();
//                delete proc_threads[i];
//            }
//
//            for (int i=0; i<jobs_save; i++)
//            {
//                save_threads[i]->join();
//                delete save_threads[i];
//            }
//
//            videoProc->join();
//        }
//    }
//}

+ (void)input:(UIImage *)image
             noise:(int)noise
             scale:(int)scale
          tilesize:(int)tilesize
             model:(NSString *)model
             gpuid:(int)gpuid
          tta_mode:(BOOL)enable_tta_mode
      load_job_num:(int)jobs_load
      proc_job_num:(int)jobs_proc
           save_cb:(waifu2xCompleteSingleBlock)save_cb
          progress:(waifu2xProgressBlock)cb {
    int total = 9;
    
    if (cb) cb(1, total, NSLocalizedString(@"Check parameters...", @""));
    if (noise < -1 || noise > 3)
    {
        if (cb) cb(1, total, NSLocalizedString(@"[ERROR] supported noise is 0, 1 or 2", @""));
        return;
    }

    if (tilesize < 32)
    {
        if (cb) cb(1, total, NSLocalizedString(@"[ERROR] tilesize should no less than 32", @""));
        return;
    }
    
    if (jobs_proc <= 0)
    {
        jobs_proc = INT32_MAX;
    }
    
    if (jobs_load <= 0)
    {
        jobs_load = 1;
    }

    if (cb) cb(2, total, NSLocalizedString(@"Prepare models...", @""));
    
    int prepadding = 0;
    Waifu2x::Mode mode;
    if ([model isEqualToString:@"models-cunet"]) {
        if (noise == -1)
        {
            prepadding = 18;
        }
        else if (scale == 1)
        {
            prepadding = 28;
        }
        else if (scale == 2)
        {
            prepadding = 18;
        }
        mode = Waifu2x::Mode::waifu2x;
    } else if ([model isEqualToString:@"models-upconv_7_anime_style_art_rgb"]) {
        prepadding = 7;
        mode = Waifu2x::Mode::waifu2x;
    } else if ([model isEqualToString:@"models-upconv_7_photo"]) {
        prepadding = 7;
        mode = Waifu2x::Mode::waifu2x;
    } else if ([model isEqualToString:@"models-DF2K"]) {
        prepadding = 10;
        mode = Waifu2x::Mode::realsr;
    } else if ([model isEqualToString:@"models-DF2K_JPEG"]) {
        prepadding = 10;
        mode = Waifu2x::Mode::realsr;
    } else {
        if (cb) cb(3, total, NSLocalizedString(@"[ERROR] No such model", @""));
        return;
    }
    
    NSString * parampath = nil;
    NSString * modelpath = nil;
    if (mode == Waifu2x::Mode::waifu2x) {
        if (scale < 1 || scale > 2)
        {
            if (cb) cb(3, total, NSLocalizedString(@"[ERROR] supported scale is 1 or 2", @""));
            return;
        }
        
        if (noise == -1)
        {
            parampath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/scale2.0x_model.param", model] ofType:nil];
            modelpath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/scale2.0x_model.bin", model] ofType:nil];
        }
        else if (scale == 1)
        {
            parampath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/noise%d_model.param", model, noise] ofType:nil];
            modelpath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/noise%d_model.bin", model, noise] ofType:nil];
        }
        else if (scale == 2)
        {
            parampath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/noise%d_scale2.0x_model.param", model, noise] ofType:nil];
            modelpath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/noise%d_scale2.0x_model.bin", model, noise] ofType:nil];
        }
    } else if (mode == Waifu2x::Mode::realsr) {
        if (scale == 4)
        {
            parampath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/x4.param", model] ofType:nil];
            modelpath = [[NSBundle mainBundle] pathForResource:[NSString stringWithFormat:@"models/%@/x4.bin", model] ofType:nil];
        }
        else
        {
            if (cb) cb(3, total, NSLocalizedString(@"[ERROR] RealSR supported scale is 4", @""));
            return;
        }
    }
    
    if (cb) cb(3, total, NSLocalizedString(@"Creating GPU instance...", @""));
    ncnn::create_gpu_instance();
    int cpu_count = std::max(1, ncnn::get_cpu_count());
    jobs_load = std::min(jobs_load, cpu_count);
    
    int gpu_count = ncnn::get_gpu_count();
    if (gpuid < 0 || gpuid >= gpu_count)
    {
        if (cb) cb(3, total, NSLocalizedString(@"[ERROR] Invalid gpu device", @""));

        ncnn::destroy_gpu_instance();
        return;
    }
    
    int gpu_queue_count = ncnn::get_gpu_info(gpuid).compute_queue_count;
    const_cast<ncnn::GpuInfo&>(ncnn::get_gpu_info(gpuid)).buffer_offset_alignment = 16;
    jobs_proc = std::min(jobs_proc, gpu_queue_count);

    
    {
        Waifu2x waifu2x(gpuid, enable_tta_mode, mode);

        if (cb) cb(4, total, NSLocalizedString(@"Loading models...", @""));
        waifu2x.load([parampath UTF8String], [modelpath UTF8String]);

        waifu2x.noise = noise;
        waifu2x.scale = scale;
        waifu2x.tilesize = tilesize;
        waifu2x.prepadding = prepadding;
        
        // main routine
        {
            if (cb) cb(5, total, NSLocalizedString(@"Initializing pipeline...", @""));

            Task v;
            v.id = 1;
            
            CGImageRef imageRef = [image CGImage];
            NSUInteger width = CGImageGetWidth(imageRef);
            NSUInteger height = CGImageGetHeight(imageRef);
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            unsigned char *rawData = (unsigned char*)calloc(height * width * 4, sizeof(unsigned char));
            NSUInteger bytesPerPixel = 4;
            NSUInteger bytesPerRow = bytesPerPixel * width;
            NSUInteger bitsPerComponent = 8;
            CGContextRef context = CGBitmapContextCreate(rawData, width, height,
                            bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Little);
            CGColorSpaceRelease(colorSpace);

            CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
            CGContextRelease(context);

            v.inimage = ncnn::Mat((int)width, (int)height, (void*)rawData, (size_t)4, 4);
            v.outimage = ncnn::Mat((int)width * scale, (int)height * scale, (size_t)4u, 4);
            toproc.put(v);
            
            // waifu2x proc
            ProcThreadParams ptp;
            ptp.waifu2x = &waifu2x;
            NSTimeInterval start_time = [[NSDate date] timeIntervalSince1970];
            ptp.cb = ^(float percentage) {
                if (cb) {
                    NSString * msg = [NSString stringWithFormat:@"Waifu2x processing...%0.2f%%", percentage];
                    if (percentage > 0) {
                        NSTimeInterval current = [[NSDate date] timeIntervalSince1970];
                        double estimated = (current - start_time) / percentage * (100.f - percentage);
                        msg = [msg stringByAppendingFormat:@"\nEsimated left time: %.0lfs", estimated   ];
                    }
                    cb(percentage, 100, msg);
                }
            };

            std::vector<ncnn::Thread*> proc_threads(jobs_proc);
            for (int i=0; i<jobs_proc; i++)
            {
                proc_threads[i] = new ncnn::Thread(proc, (void*)&ptp);
            }

            // save image
            SaveThreadParams stp;
            stp.verbose = 0;
            stp.cb = save_cb;
            
            std::vector<ncnn::Thread*> save_threads(1);
            save_threads[0] = new ncnn::Thread(save, (void*)&stp);

            if (cb) cb(6, total, NSLocalizedString(@"Done image(s) loading...", @""));
            Task end;
            end.id = -233;

            for (int i=0; i<jobs_proc; i++)
            {
                toproc.put(end);
            }

            if (cb) cb(7, total, NSLocalizedString(@"Waifu2x processing...", @""));
            for (int i=0; i<jobs_proc; i++)
            {
                proc_threads[i]->join();
                delete proc_threads[i];
            }
            
            
            if (cb) cb(8, total, NSLocalizedString(@"Saving image(s)...", @""));
            for (int i=0; i<1; i++)
            {
                tosave.put(end);
            }

            for (int i=0; i<1; i++)
            {
                save_threads[i]->join();
                delete save_threads[i];
            }
            
            free(rawData);
        }
    }
        
    ncnn::destroy_gpu_instance();
    
    if (cb) cb(9, total, NSLocalizedString(@"Done!", @""));
    
    return;
}

@end
