//
//  ViewController.h
//  waifu2x-ios
//
//  Created by Cocoa on 09/12/2020.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

- (IBAction)selectFromPhotoLibrary:(id)sender;
- (IBAction)startStop:(id)sender;

@property (weak, nonatomic) IBOutlet UITextField *modelSelector;
@property (weak, nonatomic) IBOutlet UILabel *GPUNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *VRAMUsageLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *VRAMUsageBar;
@property (weak, nonatomic) IBOutlet UISegmentedControl *noiseSelect;
@property (weak, nonatomic) IBOutlet UISegmentedControl *scaleSelect;
@property (weak, nonatomic) IBOutlet UISegmentedControl *ttaSelect;
@property (weak, nonatomic) IBOutlet UISegmentedControl *tilesizeSelete;
@property (weak, nonatomic) IBOutlet UIButton *selectButton;
@property (weak, nonatomic) IBOutlet UIButton *startButon;
@property (weak, nonatomic) IBOutlet UIImageView *imagePreview;

@end

