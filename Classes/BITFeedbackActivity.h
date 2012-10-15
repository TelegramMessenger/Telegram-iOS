//
//  BITFeedbackActivity.h
//  HockeySDK
//
//  Created by Andreas Linde on 15.10.12.
//
//

#import <UIKit/UIKit.h>

#import "BITFeedbackComposeViewControllerDelegate.h"

@interface BITFeedbackActivity : UIActivity <BITFeedbackComposeViewControllerDelegate>

@property (nonatomic, retain) UIImage *shareImage;
@property (nonatomic, retain) NSString *shareString;

@end
