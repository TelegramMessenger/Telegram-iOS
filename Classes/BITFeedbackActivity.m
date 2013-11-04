//
//  BITFeedbackActivity.m
//  HockeySDK
//
//  Created by Andreas Linde on 15.10.12.
//
//

#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_FEEDBACK

#import "HockeySDKPrivate.h"

#import "BITFeedbackActivity.h"

#import "BITHockeyHelper.h"
#import "BITFeedbackManagerPrivate.h"

#import "BITHockeyBaseManagerPrivate.h"


@interface BITFeedbackActivity()

@property (nonatomic, strong) NSMutableArray *items;

@end


@implementation BITFeedbackActivity
{
  UIViewController *_activityViewController;
}

#pragma mark - NSObject

- (id)init {
  if ((self = [super init])) {
    _customActivityImage = nil;
    _customActivityTitle = nil;
    
    self.items = [NSMutableArray array];;
  }
  
  return self;
}



#pragma mark - UIActivity

- (NSString *)activityType {
  return @"UIActivityTypePostToHockeySDKFeedback";
}

- (NSString *)activityTitle {
  if (self.customActivityTitle)
    return self.customActivityTitle;
  
  NSString *appName = bit_appName(BITHockeyLocalizedString(@"HockeyFeedbackActivityAppPlaceholder"));
  
  return [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackActivityButtonTitle"), appName];
}

- (UIImage *)activityImage {
  if (self.customActivityImage)
    return self.customActivityImage;

  return bit_imageNamed(@"feedbackActiviy.png", BITHOCKEYSDK_BUNDLE);
}


- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
  if ([BITHockeyManager sharedHockeyManager].disableFeedbackManager) return NO;

  for (UIActivityItemProvider *item in activityItems) {
    if ([item isKindOfClass:[NSString class]]) {
      return YES;
    } else if ([item isKindOfClass:[NSURL class]]) {
      return YES;
    }
  }
  return NO;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems {
  for (id item in activityItems) {
    if ([item isKindOfClass:[NSString class]] ||
        [item isKindOfClass:[NSURL class]]) {
      [_items addObject:item];
    } else {
      BITHockeyLog(@"Unknown item type %@", item);
    }
  }
}

- (UIViewController *)activityViewController {
  if (!_activityViewController) {
    // TODO: return compose controller with activity content added
    BITFeedbackManager *manager = [BITHockeyManager sharedHockeyManager].feedbackManager;
    
    BITFeedbackComposeViewController *composeViewController = [manager feedbackComposeViewController];
    composeViewController.delegate = self;
    [composeViewController prepareWithItems:_items];
    
    _activityViewController = [manager customNavigationControllerWithRootViewController:composeViewController
                                                                      presentationStyle:UIModalPresentationFormSheet];
    _activityViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
  }
  return _activityViewController;
}

- (void)feedbackComposeViewController:(BITFeedbackComposeViewController *)composeViewController didFinishWithResult:(BITFeedbackComposeResult)composeResult {
  [self activityDidFinish:composeResult == BITFeedbackComposeResultSubmitted];
}


@end

#endif /* HOCKEYSDK_FEATURE_FEEDBACK */
