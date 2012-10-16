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
#import "BITHockeyHelper.h"
#import "BITFeedbackManagerPrivate.h"

@implementation BITFeedbackActivity

- (NSString *)activityType {
  return @"UIActivityTypePostToHockeySDKFeedback";
}

- (NSString *)activityTitle {
  NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];

  return [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackActivityButtonTitle"), appName];
}

- (UIImage *)activityImage {
  return bit_imageNamed(@"feedbackActiviy.png", BITHOCKEYSDK_BUNDLE);
}


- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
  if ([BITHockeyManager sharedHockeyManager].disableFeedbackManager) return NO;

  for (UIActivityItemProvider *item in activityItems) {
    if ([item isKindOfClass:[UIImage class]]) {
      return YES;
    } else if ([item isKindOfClass:[NSString class]]) {
      return YES;
    } else if ([item isKindOfClass:[NSURL class]]) {
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
  BITFeedbackComposeViewController *composeViewController = [[BITHockeyManager sharedHockeyManager].feedbackManager feedbackComposeViewControllerWithScreenshot:NO delegate:self];
  
  UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController: composeViewController] autorelease];
  navController.modalPresentationStyle = UIModalPresentationFormSheet;  
  navController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
  
  return navController;
}

-(void)feedbackComposeViewControllerDidFinish:(BITFeedbackComposeViewController *)composeViewController {
  [self activityDidFinish:YES];
}


@end
