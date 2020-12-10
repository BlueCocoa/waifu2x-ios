//
//  ViewController.m
//  waifu2x-ios
//
//  Created by Cocoa on 09/12/2020.
//

#import "ViewController.h"
#import "waifu2xios.h"
#import "GPUInfo.h"
#import <SVProgressHUD/SVProgressHUD.h>

@interface ViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIPickerViewDelegate, UIPickerViewDataSource> {
    VkInstance gpuInstance;
}
@property (strong) NSArray<GPUInfo *> * gpus;
@property (nonatomic) uint32_t currentGPUID;
@property (strong, nonatomic) NSTimer * vramStaticticsTimer;
@property (nullable, nonatomic) UIImagePickerController * imagePicker;
@property (nullable, strong, atomic) NSArray<UIImage *>* images;
@property (nullable, strong, atomic) UIImage * scaledImage;
@property (strong, nonatomic) NSArray<NSString *> * modelNames;
@property (strong, nonatomic) NSArray<NSString *> * modelDisplayNames;
@property (strong) UITapGestureRecognizer * tapOnModelSelector;
@property (nonatomic, nullable) UIPickerView * modelPicker;
@property (atomic, assign) NSUInteger modelIndex;
@end

@implementation ViewController

@synthesize GPUNameLabel;
@synthesize VRAMUsageLabel;
@synthesize VRAMUsageBar;

- (void)viewDidLoad {
    [super viewDidLoad];
    self.modelIndex = 0;
    
    self.modelNames = @[
        @"models-cunet",
        @"models-upconv_7_photo",
        @"models-upconv_7_anime_style_art_rgb",
        @"models-DF2K",
        @"models-DF2K_JPEG"
    ];
    self.modelDisplayNames = @[
        @"CUNet",
        @"upconv7 photo",
        @"upconv7 anime",
        @"RealSR DF2K",
        @"RealSR DF2K JPEG"
    ];
    [self.imagePreview setContentMode:UIViewContentModeScaleAspectFit];
    [self.startButon setHidden:YES];
    [self.noiseSelect setSelectedSegmentIndex:2];
    [self.scaleSelect setSelectedSegmentIndex:1];
    [self.scaleSelect setEnabled:NO forSegmentAtIndex:0];
    [self createGPUInstance];
    
    [self.modelSelector setEnabled:YES];
    [self.modelSelector setText:self.modelDisplayNames[self.modelIndex]];

    self.tapOnModelSelector = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(selectModel)];
    [self.modelSelector addGestureRecognizer:self.tapOnModelSelector];
}

- (void)selectModel {
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Select Model" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert setModalInPopover:YES];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [alert dismissViewControllerAnimated:YES completion:^{
            self.modelIndex = [self.modelPicker selectedRowInComponent:0];
            if (self.modelIndex >= self.modelDisplayNames.count) {
                self.modelIndex = 0;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.modelSelector setText:self.modelDisplayNames[self.modelIndex]];
                if ([self.modelDisplayNames[self.modelIndex] hasPrefix:@"RealSR"]) {
                    [self.noiseSelect setSelectedSegmentIndex:0];
                    [self.noiseSelect setEnabled:YES forSegmentAtIndex:1];
                    [self.noiseSelect setEnabled:NO forSegmentAtIndex:1];
                    [self.noiseSelect setEnabled:NO forSegmentAtIndex:2];
                    [self.scaleSelect setSelectedSegmentIndex:0];
                    [self.scaleSelect setEnabled:YES forSegmentAtIndex:0];
                    [self.scaleSelect setEnabled:NO forSegmentAtIndex:1];
                    [self.scaleSelect setEnabled:NO forSegmentAtIndex:2];
                } else {
                    if (self.scaleSelect.selectedSegmentIndex == 0) {
                        [self.scaleSelect setSelectedSegmentIndex:1];
                    }
                    [self.noiseSelect setEnabled:YES forSegmentAtIndex:1];
                    [self.noiseSelect setEnabled:YES forSegmentAtIndex:2];
                    [self.scaleSelect setEnabled:YES forSegmentAtIndex:1];
                    [self.scaleSelect setEnabled:YES forSegmentAtIndex:2];
                    [self.scaleSelect setEnabled:NO forSegmentAtIndex:0];
                }
            });
        }];
    }]];
    CGRect containerFrame = CGRectMake(10, 70, 280, 140);
    self.modelPicker = [[UIPickerView alloc] initWithFrame:containerFrame];
    [alert.view addSubview:self.modelPicker];
    [self.modelPicker setDelegate:self];
    [self.modelPicker setDataSource:self];
    
    NSLayoutConstraint * cons1 = [NSLayoutConstraint constraintWithItem:alert.view attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:self.modelPicker attribute:NSLayoutAttributeHeight multiplier:1.0 constant:150.0];
    NSLayoutConstraint * cons2 = [NSLayoutConstraint constraintWithItem:alert.view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:self.modelPicker attribute:NSLayoutAttributeWidth multiplier:1.0 constant:20.0];
    [alert.view addConstraints:@[cons1, cons2]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UIPickerViewDelegate

- (nullable NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (pickerView == self.modelPicker) {
        return self.modelDisplayNames[row];
    }
    return nil;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component {
    if (pickerView == self.modelPicker) {
        if (component == 0) {
            return 35.0f;
        }
    }
    return 0.0;
}

#pragma mark - UIPickerViewDataSource

// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    if (pickerView == self.modelPicker) {
        return 1;
    }
    return 0;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if (pickerView == self.modelPicker) {
        if (component == 0) {
            return self.modelDisplayNames.count;
        }
    }
    return 0;
}

- (BOOL)createGPUInstance {
    // copied from Tencent/ncnn/gpu.cpp with minor changes
    // https://github.com/Tencent/ncnn/blob/master/src/gpu.cpp
    VkResult ret;

    std::vector<const char*> enabledLayers;
    std::vector<const char*> enabledExtensions;
    
    uint32_t instanceExtensionPropertyCount;
    ret = vkEnumerateInstanceExtensionProperties(NULL, &instanceExtensionPropertyCount, NULL);
    if (ret != VK_SUCCESS) {
        fprintf(stderr, "vkEnumerateInstanceExtensionProperties failed %d\n", ret);
        return NO;
    }

    std::vector<VkExtensionProperties> instanceExtensionProperties(instanceExtensionPropertyCount);
    ret = vkEnumerateInstanceExtensionProperties(NULL, &instanceExtensionPropertyCount, instanceExtensionProperties.data());
    if (ret != VK_SUCCESS) {
        fprintf(stderr, "vkEnumerateInstanceExtensionProperties failed %d\n", ret);
        return NO;
    }

    static int support_VK_KHR_get_physical_device_properties2 = 0;
    for (uint32_t j=0; j<instanceExtensionPropertyCount; j++) {
        const VkExtensionProperties& exp = instanceExtensionProperties[j];
        if (strcmp(exp.extensionName, "VK_KHR_get_physical_device_properties2") == 0) {
            support_VK_KHR_get_physical_device_properties2 = exp.specVersion;
        }
    }
    if (support_VK_KHR_get_physical_device_properties2) {
        enabledExtensions.push_back("VK_KHR_get_physical_device_properties2");
    }
        
    VkApplicationInfo applicationInfo;
    applicationInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    applicationInfo.pNext = 0;
    applicationInfo.pApplicationName = "Image Super Resolution macOS";
    applicationInfo.applicationVersion = 0;
    applicationInfo.pEngineName = "isrmacos";
    applicationInfo.engineVersion = 20201210;
    applicationInfo.apiVersion = VK_MAKE_VERSION(1, 0, 0);

    VkInstanceCreateInfo instanceCreateInfo;
    instanceCreateInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    instanceCreateInfo.pNext = 0;
    instanceCreateInfo.flags = 0;
    instanceCreateInfo.pApplicationInfo = &applicationInfo;
    instanceCreateInfo.enabledLayerCount = (uint32_t)enabledLayers.size();
    instanceCreateInfo.ppEnabledLayerNames = enabledLayers.data();
    instanceCreateInfo.enabledExtensionCount = (uint32_t)enabledExtensions.size();
    instanceCreateInfo.ppEnabledExtensionNames = enabledExtensions.data();

    ret = vkCreateInstance(&instanceCreateInfo, 0, &self->gpuInstance);
    if (ret != VK_SUCCESS) {
        fprintf(stderr, "vkCreateInstance failed %d\n", ret);
        return NO;
    }
    
    uint32_t physicalDeviceCount = 0;
    ret = vkEnumeratePhysicalDevices(self->gpuInstance, &physicalDeviceCount, 0);
    if (ret != VK_SUCCESS) {
        fprintf(stderr, "vkEnumeratePhysicalDevices failed %d\n", ret);
    }
    
    std::vector<VkPhysicalDevice> physicalDevices(physicalDeviceCount);
    ret = vkEnumeratePhysicalDevices(self->gpuInstance, &physicalDeviceCount, physicalDevices.data());
    if (ret != VK_SUCCESS) {
        fprintf(stderr, "vkEnumeratePhysicalDevices failed %d\n", ret);
    }
    
    NSMutableArray<GPUInfo *> * gpus = [NSMutableArray arrayWithCapacity:physicalDeviceCount];
    for (uint32_t i=0; i<physicalDeviceCount; i++) {
        const VkPhysicalDevice& physicalDevice = physicalDevices[i];
        VkPhysicalDeviceProperties physicalDeviceProperties;
        vkGetPhysicalDeviceProperties(physicalDevice, &physicalDeviceProperties);
        
        GPUInfo * info = [GPUInfo initWithName:[NSString stringWithFormat:@"%s", physicalDeviceProperties.deviceName] deviceID:i physicalDevice:physicalDevice];
        [gpus addObject:info];
    }
    
    self.gpus = [gpus sortedArrayUsingComparator:^NSComparisonResult(GPUInfo *  _Nonnull obj1, GPUInfo *  _Nonnull obj2) {
        if (obj1.deviceID < obj2.deviceID) {
            return NSOrderedAscending;
        } else{
            return NSOrderedDescending;
        };
    }];
    for (int i = 0; i < self.gpus.count; i++) {
        NSString * gpuName = [NSString stringWithFormat:@"GPU: [%u] %@", self.gpus[i].deviceID, self.gpus[i].name];
        NSLog(@"Found %@", gpuName);
        [self.GPUNameLabel setText:gpuName];
    }
    self.currentGPUID = 0;

    [self updateVRAMStaticticsWithTimeInterval:1.0];
    
    return YES;
}

- (void)updateVRAMStaticticsWithTimeInterval:(NSTimeInterval)interval {
    if (self.vramStaticticsTimer) {
        [self.vramStaticticsTimer setFireDate:[NSDate distantFuture]];
        [self.vramStaticticsTimer invalidate];
        self.vramStaticticsTimer = nil;
    }
    self.vramStaticticsTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(updateCurrentGPUVRAMStatictics) userInfo:nil repeats:YES];
    [self.vramStaticticsTimer setFireDate:[NSDate date]];
    [self.vramStaticticsTimer fire];
}

- (void)updateCurrentGPUVRAMStatictics {
    const auto& device = self.gpus[self.currentGPUID].physicalDevice;
    VkPhysicalDeviceProperties deviceProperties;
    vkGetPhysicalDeviceProperties(device, &deviceProperties);
    
    VkPhysicalDeviceMemoryProperties deviceMemoryProperties;
    VkPhysicalDeviceMemoryBudgetPropertiesEXT budget = {
      .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_BUDGET_PROPERTIES_EXT
    };

    VkPhysicalDeviceMemoryProperties2 props = {
      .sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_MEMORY_PROPERTIES_2,
      .pNext = &budget,
      .memoryProperties = deviceMemoryProperties,
    };
    vkGetPhysicalDeviceMemoryProperties2(device, &props);
    
    double total = budget.heapBudget[0];
    double used = budget.heapUsage[0];
    total += used;
    
    total /= 1024.0 * 1024.0;
    used /= 1024.0 * 1024.0;
    [self.VRAMUsageBar setProgress:used/total animated:YES];
    [self.VRAMUsageLabel setText:[NSString stringWithFormat:@"VRAM: %.02lf/%.02lf MB", used, total]];
}

- (IBAction)selectFromPhotoLibrary:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imagePicker = [[UIImagePickerController alloc] init];
        [self.imagePicker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
        [self.imagePicker setDelegate:self];
#ifdef ENABLE_VIDEO
        [self.imagePicker setMediaTypes:@[@"public.image", @"public.movie"]];
#else
        [self.imagePicker setMediaTypes:@[@"public.image"]];
#endif
        [self presentViewController:self.imagePicker animated:YES completion:^{
            [self.startButon setHidden:NO];
        }];
    });
}

- (void)didWriteImage:(UIImage*)img toSavedPhotosAlbumIfError:(NSError *)e contextInfo:(void*)ctx {
    [self.startButon setTitle:@"Start" forState:UIControlStateNormal];
    [self.startButon setEnabled:YES];
    self.startButon.tag = 0;
    
    UIAlertController * alert = [UIAlertController alertControllerWithTitle:@"Succeeded" message:@"New image has been successfully saved" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [alert dismissViewControllerAnimated:YES completion:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.imagePreview setImage:nil];
                self.scaledImage = nil;
            });
        }];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)startStop:(id)sender {
    if (self.startButon.tag == 2) {
        self.startButon.tag = 0;
        UIImageWriteToSavedPhotosAlbum(self.scaledImage, self, @selector(didWriteImage:toSavedPhotosAlbumIfError:contextInfo:), nil);
        return;
    }
    
    if (self.images.count != 1) {
        return;
    }
    NSString * model = self.modelNames[MIN(self.modelIndex, self.modelNames.count)];
    int noise = [(NSNumber *)[@[@(0), @(1), @(2)] objectAtIndex:[self.noiseSelect selectedSegmentIndex]] intValue];
    int scale = [(NSNumber *)[@[@(4), @(2), @(1)] objectAtIndex:[self.scaleSelect selectedSegmentIndex]] intValue];
    BOOL enableTTAMode = [self.ttaSelect selectedSegmentIndex] == 0;
    int tilesize = [(NSNumber *)[@[@(400), @(200), @(100), @(64), @(32)] objectAtIndex:[self.tilesizeSelete selectedSegmentIndex]] intValue];
    
    [self.startButon setTitle:@"Processing..." forState:UIControlStateNormal];
    [self.startButon setEnabled:NO];
    [self.selectButton setEnabled:NO];
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [waifu2xios input:self.images[0]
                    noise:noise
                    scale:scale
                 tilesize:tilesize
                    model:model
                    gpuid:self.currentGPUID
                 tta_mode:enableTTAMode
             load_job_num:1
             proc_job_num:8
                  save_cb:^(ncnn::Mat &scaled_frame, int current, uint64_t total) {
            NSData *data = [NSData dataWithBytes:scaled_frame.data length:scaled_frame.total() * 4];
            CGColorSpaceRef colorSpace;
            CGBitmapInfo bitmapInfo;

            colorSpace = CGColorSpaceCreateDeviceRGB();
            bitmapInfo = kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipLast;
            CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);

            CGImageRef imageRef = CGImageCreate(scaled_frame.w,                         // width
                                                scaled_frame.h,                         // height
                                                8,                                      // bits per component
                                                8 * 4,              // bits per pixel
                                                scaled_frame.w * 4, // bytesPerRow
                colorSpace,                 // colorspace
                bitmapInfo,                 // bitmap info
                provider,                   // CGDataProviderRef
                NULL,                       // decode
                false,                      // should interpolate
                kCGRenderingIntentDefault   // intent
            );
            self.scaledImage = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);
            CGDataProviderRelease(provider);
            CGColorSpaceRelease(colorSpace);
            
            NSData* imageData =  UIImagePNGRepresentation(self.scaledImage);     // get png representation
            self.scaledImage = [UIImage imageWithData:imageData];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.imagePreview setImage:self.scaledImage];
                [self.startButon setTitle:@"Save to Photos" forState:UIControlStateNormal];
                [self.startButon setEnabled:YES];
                [self.startButon setTag:2];
                
                [self.selectButton setEnabled:YES];
                [SVProgressHUD dismissWithDelay:0.3];
            });
        }
                 progress:^(int current, int total, NSString *description) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showProgress:(float)current/total status:description];
                if ([description hasPrefix:@"[ERROR]"]) {
                    [SVProgressHUD dismissWithDelay:1.0 completion:^{
                        [self.selectButton setEnabled:YES];
                        
                        [self.startButon setTitle:@"Start" forState:UIControlStateNormal];
                        [self.startButon setEnabled:YES];
                    }];
                }
                NSLog(@"%@", description);
            });
        }];
    });
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    [self.imagePicker dismissViewControllerAnimated:YES completion:^{
        self.images = @[(UIImage *)[info valueForKey:UIImagePickerControllerOriginalImage]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.imagePreview setImage:self.images[0]];
        });
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    
}

@end
