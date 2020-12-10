//
//  waifu2xios.h
//  waifu2xios
//
//  Created by Cocoa on 2019/4/25.
//  Copyright © 2019-2020 Cocoa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GPUInfo.h"
#import <mat.h>
#import <UIKit/UIKit.h>

typedef void (^waifu2xProgressBlock)(int current, int total, NSString * description);
typedef void (^waifu2xCompleteSingleBlock)(ncnn::Mat& scaled_frame, int current, uint64_t total);

@interface waifu2xios : NSObject

#ifdef ENABLE_VIDEO
+ (void)videoInput:(cv::VideoCapture&)video
        noise:(int)noise
        scale:(int)scale
     tilesize:(int)tilesize
        model:(NSString *)model
        gpuid:(int)gpuid
     tta_mode:(BOOL)enable_tta_mode
 proc_job_num:(int)jobs_proc
 save_job_num:(int)jobs_save
      save_cb:(waifu2xCompleteSingleBlock)save_cb
    VRAMUsage:(double *)usage
     progress:(waifu2xProgressBlock)cb;
#endif

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
          progress:(waifu2xProgressBlock)cb;

@end

