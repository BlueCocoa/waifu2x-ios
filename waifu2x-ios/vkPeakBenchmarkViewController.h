//
//  vkPeakBenchmarkViewController.h
//  waifu2x-ios
//
//  Created by Cocoa on 27/12/2020.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface vkPeakBenchmarkViewController : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *GPUNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *MACs8xLabel;
@property (weak, nonatomic) IBOutlet UILabel *countLabel;
@property (weak, nonatomic) IBOutlet UILabel *loopsLabel;
@property (weak, nonatomic) IBOutlet UILabel *fp32ScalarLabel;
@property (weak, nonatomic) IBOutlet UILabel *fp32Vec4Label;
@property (weak, nonatomic) IBOutlet UILabel *fp32Vec8Label;
@property (weak, nonatomic) IBOutlet UILabel *fp16pVec4Label;
@property (weak, nonatomic) IBOutlet UILabel *fp16pVec8Label;
@property (weak, nonatomic) IBOutlet UILabel *fp16sScalarLabel;
@property (weak, nonatomic) IBOutlet UILabel *fp16sVec4Label;
@property (weak, nonatomic) IBOutlet UILabel *fp16sVec8Label;
@property (weak, nonatomic) IBOutlet UIButton *runBenchmarkButton;
@property (weak, nonatomic) IBOutlet UITextField *MACs8xSelector;
@property (weak, nonatomic) IBOutlet UITextField *countSelector;
@property (weak, nonatomic) IBOutlet UITextField *loopsSelector;

@property (assign) NSString * GPUName;
- (IBAction)runBenchmark:(id)sender;
@end

NS_ASSUME_NONNULL_END
