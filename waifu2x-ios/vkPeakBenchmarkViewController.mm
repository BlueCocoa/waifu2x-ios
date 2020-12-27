//
//  vkPeakBenchmarkViewController.m
//  waifu2x-ios
//
//  Created by Cocoa on 27/12/2020.
//

#import "vkPeakBenchmarkViewController.h"
#import <SVProgressHUD/SVProgressHUD.h>
#include <float.h>
#include <string>
#include <vector>
#import <objc/runtime.h>

#include <vulkan/vulkan.h>

// ncnn
#include "benchmark.h"
#include "c_api.h"
#include "command.h"
#include "gpu.h"
#include "mat.h"
#include "pipeline.h"


static const char glsl_p1_data[] = "\
#version 450\n\
#if NCNN_fp16_storage\n\
#extension GL_EXT_shader_16bit_storage: require\n\
#endif\n\
#if NCNN_fp16_arithmetic\n\
#extension GL_EXT_shader_explicit_arithmetic_types_float16: require\n\
#endif\n\
layout (constant_id = 0) const int count = 0;\n\
layout (constant_id = 1) const int loop = 1;\n\
layout (binding = 0) readonly buffer a_blob { sfp a_blob_data[]; };\n\
layout (binding = 1) readonly buffer b_blob { sfp b_blob_data[]; };\n\
layout (binding = 2) writeonly buffer c_blob { sfp c_blob_data[]; };\n\
void main()\n\
{\n\
    int gx = int(gl_GlobalInvocationID.x);\n\
    int gy = int(gl_GlobalInvocationID.y);\n\
    int gz = int(gl_GlobalInvocationID.z);\n\
    if (gx >= count || gy >= 1 || gz >= 1)\n\
        return;\n\
    afp a = buffer_ld1(a_blob_data, gx);\n\
    afp b = buffer_ld1(b_blob_data, gx);\n\
    afp c = afp(1.f);\n\
    for (int i = 0; i < loop; i++)\n\
    {\n\
        c = a * c + b;\n\
        c = a * c + b;\n\
        c = a * c + b;\n\
        c = a * c + b;\n\
        c = a * c + b;\n\
        c = a * c + b;\n\
        c = a * c + b;\n\
        c = a * c + b;\n\
    }\n\
    buffer_st1(c_blob_data, gx, c);\n\
}";

static const char glsl_p4_data[] = "\
#version 450\n\
#if NCNN_fp16_storage\n\
#extension GL_EXT_shader_16bit_storage: require\n\
#endif\n\
#if NCNN_fp16_arithmetic\n\
#extension GL_EXT_shader_explicit_arithmetic_types_float16: require\n\
#endif\n\
layout (constant_id = 0) const int count = 0;\n\
layout (constant_id = 1) const int loop = 1;\n\
layout (binding = 0) readonly buffer a_blob { sfpvec4 a_blob_data[]; };\n\
layout (binding = 1) readonly buffer b_blob { sfpvec4 b_blob_data[]; };\n\
layout (binding = 2) writeonly buffer c_blob { sfpvec4 c_blob_data[]; };\n\
void main()\n\
{\n\
    int gx = int(gl_GlobalInvocationID.x);\n\
    int gy = int(gl_GlobalInvocationID.y);\n\
    int gz = int(gl_GlobalInvocationID.z);\n\
    if (gx >= count || gy >= 1 || gz >= 1)\n\
        return;\n\
    afpvec4 a = buffer_ld4(a_blob_data, gx);\n\
    afpvec4 b = buffer_ld4(b_blob_data, gx);\n\
    afpvec4 c = afpvec4(1.f);\n\
    for (int i = 0; i < loop; i++)\n\
    {\n\
        c = a * c + b;\n\
        c = a * c + b;\n\
        c = a * c + b;\n\
        c = a * c + b;\n\
        c = a * c + b;\n\
        c = a * c + b;\n\
        c = a * c + b;\n\
        c = a * c + b;\n\
    }\n\
    buffer_st4(c_blob_data, gx, c);\n\
}";

static const char glsl_p8_data[] = "\
#version 450\n\
#if NCNN_fp16_storage\n\
#extension GL_EXT_shader_16bit_storage: require\n\
#endif\n\
#if NCNN_fp16_arithmetic\n\
#extension GL_EXT_shader_explicit_arithmetic_types_float16: require\n\
#endif\n\
layout (constant_id = 0) const int count = 0;\n\
layout (constant_id = 1) const int loop = 1;\n\
layout (binding = 0) readonly buffer a_blob { sfpvec8 a_blob_data[]; };\n\
layout (binding = 1) readonly buffer b_blob { sfpvec8 b_blob_data[]; };\n\
layout (binding = 2) writeonly buffer c_blob { sfpvec8 c_blob_data[]; };\n\
void main()\n\
{\n\
    int gx = int(gl_GlobalInvocationID.x);\n\
    int gy = int(gl_GlobalInvocationID.y);\n\
    int gz = int(gl_GlobalInvocationID.z);\n\
    if (gx >= count || gy >= 1 || gz >= 1)\n\
        return;\n\
    afpvec8 a = buffer_ld8(a_blob_data, gx);\n\
    afpvec8 b = buffer_ld8(b_blob_data, gx);\n\
    afpvec8 c = afpvec8(afpvec4(1.f), afpvec4(1.f));\n\
    for (int i = 0; i < loop; i++)\n\
    {\n\
        c[0] = a[0] * c[0] + b[0];\n\
        c[1] = a[1] * c[1] + b[1];\n\
        c[0] = a[0] * c[0] + b[0];\n\
        c[1] = a[1] * c[1] + b[1];\n\
        c[0] = a[0] * c[0] + b[0];\n\
        c[1] = a[1] * c[1] + b[1];\n\
        c[0] = a[0] * c[0] + b[0];\n\
        c[1] = a[1] * c[1] + b[1];\n\
        c[0] = a[0] * c[0] + b[0];\n\
        c[1] = a[1] * c[1] + b[1];\n\
        c[0] = a[0] * c[0] + b[0];\n\
        c[1] = a[1] * c[1] + b[1];\n\
        c[0] = a[0] * c[0] + b[0];\n\
        c[1] = a[1] * c[1] + b[1];\n\
        c[0] = a[0] * c[0] + b[0];\n\
        c[1] = a[1] * c[1] + b[1];\n\
    }\n\
    buffer_st8(c_blob_data, gx, c);\n\
}";

static float vkpeak(int loop, int count_mb, int cmd_loop, int storage_type, int arithmetic_type, int packing_type)
{
    const int count = count_mb * 1024 * 1024;

    int elempack = packing_type == 0 ? 1 : packing_type == 1 ? 4 : 8;

    ncnn::VulkanDevice* vkdev = ncnn::get_gpu_device();

    if (!vkdev)
    {
        return -1;
    }

    if (!vkdev->info.support_fp16_storage && storage_type == 2)
    {
        return -233;
    }
    if (!vkdev->info.support_fp16_arithmetic && arithmetic_type == 1)
    {
        return -233;
    }

    double max_gflops = -233;

    ncnn::Option opt;
    opt.use_vulkan_compute = true;
    opt.use_fp16_packed = storage_type == 1;
    opt.use_fp16_storage = storage_type == 2;
    opt.use_fp16_arithmetic = arithmetic_type == 1;
    opt.use_shader_pack8 = packing_type == 2;

    // setup pipeline
    ncnn::Pipeline pipeline(vkdev);
    {
        int local_size_x = std::min(128, std::max(32, (int)vkdev->info.subgroup_size));

        pipeline.set_local_size_xyz(local_size_x, 1, 1);

        std::vector<ncnn::vk_specialization_type> specializations(2);
        specializations[0].i = count;
        specializations[1].i = loop;

        // glsl to spirv
        // -1 for omit the tail '\0'
        std::vector<uint32_t> spirv;
        if (packing_type == 0)
        {
            ncnn::compile_spirv_module(glsl_p1_data, sizeof(glsl_p1_data) - 1, opt, spirv);
        }
        if (packing_type == 1)
        {
            ncnn::compile_spirv_module(glsl_p4_data, sizeof(glsl_p4_data) - 1, opt, spirv);
        }
        if (packing_type == 2)
        {
            ncnn::compile_spirv_module(glsl_p8_data, sizeof(glsl_p8_data) - 1, opt, spirv);
        }

        pipeline.create(spirv.data(), spirv.size() * 4, specializations);
    }

    ncnn::VkAllocator* allocator = vkdev->acquire_blob_allocator();

    // prepare storage
    {
    ncnn::VkMat a;
    ncnn::VkMat b;
    ncnn::VkMat c;
    {
        if (opt.use_fp16_packed || opt.use_fp16_storage)
        {
            a.create(count, (size_t)(2u * elempack), elempack, allocator);
            b.create(count, (size_t)(2u * elempack), elempack, allocator);
            c.create(count, (size_t)(2u * elempack), elempack, allocator);
        }
        else
        {
            a.create(count, (size_t)(4u * elempack), elempack, allocator);
            b.create(count, (size_t)(4u * elempack), elempack, allocator);
            c.create(count, (size_t)(4u * elempack), elempack, allocator);
        }
    }

    for (int i = 0; i < cmd_loop; i++)
    {
        // encode command
        ncnn::VkCompute cmd(vkdev);
        {
            std::vector<ncnn::VkMat> bindings(3);
            bindings[0] = a;
            bindings[1] = b;
            bindings[2] = c;

            std::vector<ncnn::vk_constant_type> constants(0);

            cmd.record_pipeline(&pipeline, bindings, constants, c);
        }

        // time this
        {
            double t0 = ncnn::get_current_time();

            int ret = cmd.submit_and_wait();
            if (ret != 0)
            {
                vkdev->reclaim_blob_allocator(allocator);
                return -1;
            }

            double time = ncnn::get_current_time() - t0;

            const double mac = (double)count * (double)loop * 8 * elempack * 2;

            double gflops = mac / time / 1000000;

//             fprintf(stderr, "%f gflops\n", gflops);

            if (gflops > max_gflops)
                max_gflops = gflops;
        }
    }

    }

    vkdev->reclaim_blob_allocator(allocator);

    return max_gflops;
}

@interface vkPeakBenchmarkViewController() <UIAdaptivePresentationControllerDelegate, UIPickerViewDelegate, UIPickerViewDataSource>
@property (atomic) BOOL isBenchmarking;
@property (nonatomic, nullable) UIPickerView * modalPicker;
@property (strong) NSArray * selectableItems;
@end

@implementation vkPeakBenchmarkViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self addObserver:self forKeyPath:@"GPUName" options:NSKeyValueObservingOptionNew context:NULL];
    [self.presentationController setDelegate:self];
    self.isBenchmarking = NO;
    
    [self.MACs8xSelector setEnabled:YES];
    [self.countSelector setEnabled:YES];
    [self.loopsSelector setEnabled:YES];
    [self.MACs8xSelector addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(selector:)]];
    [self.countSelector addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(selector:)]];
    [self.loopsSelector addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(selector:)]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"GPUName"]) {
        [self.GPUNameLabel setText:self.GPUName];
    }
}

- (void)selector:(UITapGestureRecognizer *)ges {
    NSString * title = nil;
    self.selectableItems = @[];
    if ([ges view] == self.MACs8xSelector) {
        title = @"MACs(8x)";
        self.selectableItems = @[@"40", @"100", @"200", @"400"];
    } else if ([ges view] == self.countSelector) {
        title = @"Count(MB)";
        self.selectableItems = @[@"4", @"10", @"20", @"40"];
    } else if ([ges view] == self.loopsSelector) {
        title = @"Loops";
        self.selectableItems = @[@"4", @"10", @"20", @"40"];
    } else {
        return;
    }
    
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert setModalInPopover:YES];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [alert dismissViewControllerAnimated:YES completion:^{
            NSUInteger selectedIndex = [self.modalPicker selectedRowInComponent:0];
            if (selectedIndex >= self.selectableItems.count) {
                selectedIndex = 0;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [(UITextField *)[ges view] setText:self.selectableItems[selectedIndex]];
            });
        }];
    }]];
    CGRect containerFrame = CGRectMake(10, 70, 280, 140);
    self.modalPicker = [[UIPickerView alloc] initWithFrame:containerFrame];
    [alert.view addSubview:self.modalPicker];
    [self.modalPicker setDelegate:self];
    [self.modalPicker setDataSource:self];
    
    NSLayoutConstraint * cons1 = [NSLayoutConstraint constraintWithItem:alert.view attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:self.modalPicker attribute:NSLayoutAttributeHeight multiplier:1.0 constant:150.0];
    NSLayoutConstraint * cons2 = [NSLayoutConstraint constraintWithItem:alert.view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:self.modalPicker attribute:NSLayoutAttributeWidth multiplier:1.0 constant:20.0];
    [alert.view addConstraints:@[cons1, cons2]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)runBenchmark:(id)sender {
    self.isBenchmarking = YES;
    int loop = [self.MACs8xSelector.text intValue];
    int count_mb = [self.countSelector.text intValue];
    int cmd_loop = [self.loopsSelector.text intValue];
    
    void (*displayWithInterval)(id, SEL, id, id, NSTimeInterval) = (void(*)(id, SEL, id, id, NSTimeInterval))method_getImplementation(class_getInstanceMethod([SVProgressHUD class], @selector(showImage:status:duration:)));
    SVProgressHUD * hud = (SVProgressHUD*)[SVProgressHUD performSelector:@selector(sharedView)];
    void (^benchmark)(NSString * info, UILabel * display, int loop, int count_mb, int cmd_loop, int storage_type, int arithmetic_type, int packing_type) = ^(NSString * info, UILabel * display, int loop, int count_mb, int cmd_loop, int storage_type, int arithmetic_type, int packing_type) {
        dispatch_async(dispatch_get_main_queue(), ^{
            displayWithInterval(hud, @selector(showImage:status:duration:), hud.infoImage, info, 10000);
        });
        float result = vkpeak(loop, count_mb, cmd_loop, storage_type, arithmetic_type, packing_type);
        dispatch_async(dispatch_get_main_queue(), ^{
            displayWithInterval(hud, @selector(showImage:status:duration:), hud.infoImage, @"Sleep 5 seconds to cool down...", 10000);
            [display setText:[self textHelper:result]];
        });
        sleep(5);
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD dismiss];
        });
    };
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.view setUserInteractionEnabled:NO];
            [[self.view gestureRecognizers][0] setEnabled:NO];
        });
        ncnn::create_gpu_instance();
        benchmark(@"Benchmarking FP32 Scalar...",  self.fp32ScalarLabel,  loop, count_mb, cmd_loop, 0, 0, 0);
        benchmark(@"Benchmarking FP32 vec4...",    self.fp32Vec4Label,    loop, count_mb, cmd_loop, 0, 0, 1);
        benchmark(@"Benchmarking FP32 vec8...",    self.fp32Vec8Label,    loop, count_mb, cmd_loop, 0, 0, 2);
        benchmark(@"Benchmarking FP16p vec4...",   self.fp16pVec4Label,   loop, count_mb, cmd_loop, 1, 1, 1);
        benchmark(@"Benchmarking FP16p vec8...",   self.fp16pVec8Label,   loop, count_mb, cmd_loop, 1, 1, 2);
        benchmark(@"Benchmarking FP16s Scalar...", self.fp16sScalarLabel, loop, count_mb, cmd_loop, 2, 1, 0);
        benchmark(@"Benchmarking FP16s vec4...",   self.fp16sVec4Label,   loop, count_mb, cmd_loop, 2, 1, 1);
        benchmark(@"Benchmarking FP16s vec8...",   self.fp16sVec8Label,   loop, count_mb, cmd_loop, 2, 1, 2);
        ncnn::destroy_gpu_instance();
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.view setUserInteractionEnabled:YES];
            [[self.view gestureRecognizers][0] setEnabled:YES];
            self.isBenchmarking = NO;
        });
    });
}

- (NSString *)textHelper:(float)result {
    if (result == -1)
        return @"Error";

    if (result == -233)
        return @"Not supported";
    
    return [NSString stringWithFormat:@"%.2f", result];
}

- (BOOL)presentationControllerShouldDismiss:(UIPresentationController *)presentationController {
    return !self.isBenchmarking;
}

#pragma mark - UIPickerViewDataSource

// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    if (pickerView == self.modalPicker) {
        return 1;
    }
    return 0;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if (pickerView == self.modalPicker) {
        if (component == 0) {
            return self.selectableItems.count;
        }
    }
    return 0;
}

#pragma mark - UIPickerViewDelegate

- (nullable NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (pickerView == self.modalPicker) {
        return self.selectableItems[row];
    }
    return nil;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component {
    if (pickerView == self.modalPicker) {
        if (component == 0) {
            return 35.0f;
        }
    }
    return 0.0;
}

@end
