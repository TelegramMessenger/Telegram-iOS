//
//  BITAttachmentGalleryViewController.h
//  HockeySDK
//
//  Created by Moritz Haarmann on 06.03.14.
//
//

#import <UIKit/UIKit.h>

@class BITFeedbackMessageAttachment;

@interface BITAttachmentGalleryViewController : UIViewController

@property (nonatomic, strong) NSArray *messages;

@property (nonatomic, strong) BITFeedbackMessageAttachment *preselectedAttachment;

@end
