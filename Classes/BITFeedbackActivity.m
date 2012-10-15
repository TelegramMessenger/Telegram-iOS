//
//  BITFeedbackActivity.m
//  HockeySDK
//
//  Created by Andreas Linde on 15.10.12.
//
//

#import "BITFeedbackActivity.h"

#import "HockeySDKPrivate.h"
#import "HockeySDK.h"
#import "BITFeedbackManagerPrivate.h"

@implementation BITFeedbackActivity

- (NSString *)activityType {
  return @"UIActivityTypePostToHockeySDKFeedback";
}

- (NSString *)activityTitle {
  return BITHockeyLocalizedString(@"HockeyFeedbackActivityButtonTitle");
}

- (UIImage *)activityImage {
  return [UIImage imageNamed:@"instagram.png"];
}


- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
  if ([BITHockeyManager sharedHockeyManager].disableFeedbackManager) return NO;

  // we can present the user data screen on top of the compose screen
  // so for now only allow this if all required user data is available
  BITFeedbackManager *feedbackManager = [BITHockeyManager sharedHockeyManager].feedbackManager;
  if ([feedbackManager askManualUserDataAvailable] &&
      ([feedbackManager requireManualUserDataMissing])
      )
      return NO;

  for (UIActivityItemProvider *item in activityItems) {
    if ([item isKindOfClass:[UIImage class]]) {
      return YES;
    } else if ([item isKindOfClass:[NSString class]]) {
      return YES;
    } else if ([item isKindOfClass:[NSString class]]) {
      return YES;
    }
  }
  return NO;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems {
  for (id item in activityItems) {
    if ([item isKindOfClass:[UIImage class]]) {
      self.shareImage = item;
    } else if ([item isKindOfClass:[NSString class]]) {
      self.shareString = [(self.shareString ? self.shareString : @"") stringByAppendingFormat:@"%@%@",(self.shareString ? @" " : @""),item];
    } else if ([item isKindOfClass:[NSURL class]]) {
      self.shareString = [(self.shareString ? self.shareString : @"") stringByAppendingFormat:@"%@%@",(self.shareString ? @" " : @""),[(NSURL *)item absoluteString]];
    } else {
      BITHockeyLog(@"Unknown item type %@", item);
    }
  }
}

- (UIViewController *)activityViewController {
  // TODO: return compose controller with activity content added
  BITFeedbackComposeViewController *composeViewController = [[BITHockeyManager sharedHockeyManager].feedbackManager feedbackComposeViewControllerWithDelegate:self];
  composeViewController.modalPresentationStyle = UIModalPresentationFormSheet;
  return composeViewController;
}

-(void)feedbackComposeViewControllerDidFinish:(BITFeedbackComposeViewController *)composeViewController {
  [self activityDidFinish:YES];
}


@end
