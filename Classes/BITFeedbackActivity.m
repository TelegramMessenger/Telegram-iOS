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


@interface BITFeedbackActivity()

@property (nonatomic, retain) NSMutableArray *items;

@end


@implementation BITFeedbackActivity

#pragma mark - NSObject

- (id)init {
  if ((self = [super init])) {
    self.items = [NSMutableArray array];;
  }
  
  return self;
}

- (void)dealloc {
  [_items release]; _items = nil;
  
  [super dealloc];
}


#pragma mark - UIActivity

- (NSString *)activityType {
  return @"UIActivityTypePostToHockeySDKFeedback";
}

- (NSString *)activityTitle {
  NSString *appName = bit_appName();
  
  return [NSString stringWithFormat:BITHockeyLocalizedString(@"HockeyFeedbackActivityButtonTitle"), appName];
}

- (UIImage *)activityImage {
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
  // TODO: return compose controller with activity content added
  BITFeedbackComposeViewController *composeViewController = [[BITHockeyManager sharedHockeyManager].feedbackManager feedbackComposeViewController];
  composeViewController.delegate = self;
  [composeViewController prepareWithItems:_items];
  
  UINavigationController *navController = [[[UINavigationController alloc] initWithRootViewController: composeViewController] autorelease];
  navController.modalPresentationStyle = UIModalPresentationFormSheet;  
  navController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
  
  return navController;
}

-(void)feedbackComposeViewControllerDidFinish:(BITFeedbackComposeViewController *)composeViewController {
  [self activityDidFinish:YES];
}


@end
