//
//  BITFeedbackActivity.h
//  HockeySDK
//
//  Created by Andreas Linde on 15.10.12.
//
//

#import <UIKit/UIKit.h>

#import "BITFeedbackComposeViewControllerDelegate.h"

/**
 UIActivity subclass allowing to use the feedback interface to share content with the developer

 This activity can be added into an UIActivityViewController and it will use the activity data
 objects to prefill the content of `BITFeedbackComposeViewController`.
 
 This can be useful if you present some data that users can not only share but also
 report back to the developer because they have some problems, e.g. webcams not working
 any more.
 
 The activity provide a default title and image that can be further customized
 via `customActivityImage` and `customActivityTitle`.

 */

@interface BITFeedbackActivity : UIActivity <BITFeedbackComposeViewControllerDelegate>

///-----------------------------------------------------------------------------
/// @name BITFeedbackActivity customisation
///-----------------------------------------------------------------------------


/**
 Define the image shown when using `BITFeedbackActivity`
 
 If not set a default icon is being used.
 
 @see customActivityTitle
 */
@property (nonatomic, strong) UIImage *customActivityImage;


/**
 Define the title shown when using `BITFeedbackActivity`
 
 If not set, a default string is shown by using the apps name
 and adding the localized string "Feedback" to it.
 
 @see customActivityImage
 */
@property (nonatomic, strong) NSString *customActivityTitle;

@end
