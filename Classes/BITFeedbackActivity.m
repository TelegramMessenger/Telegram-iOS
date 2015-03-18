/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_FEEDBACK

#import "HockeySDKPrivate.h"

#import "BITFeedbackActivity.h"

#import "BITHockeyHelper.h"
#import "BITFeedbackManagerPrivate.h"

#import "BITHockeyBaseManagerPrivate.h"
#import "BITHockeyAttachment.h"


@interface BITFeedbackActivity()

@property (nonatomic, strong) NSMutableArray *items;

@end


@implementation BITFeedbackActivity
{
  UIViewController *_activityViewController;
}

#pragma mark - NSObject

- (instancetype)init {
  if ((self = [super init])) {
    _customActivityImage = nil;
    _customActivityTitle = nil;
    
    _items = [NSMutableArray array];
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

  return bit_imageNamed(@"feedbackActivity.png", BITHOCKEYSDK_BUNDLE);
}


- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
  if ([BITHockeyManager sharedHockeyManager].disableFeedbackManager) return NO;

  for (UIActivityItemProvider *item in activityItems) {
    if ([item isKindOfClass:[NSString class]]) {
      return YES;
    } else if ([item isKindOfClass:[UIImage class]]) {
      return YES;
    } else if ([item isKindOfClass:[NSData class]]) {
      return YES;
    } else if ([item isKindOfClass:[BITHockeyAttachment class]]) {
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
        [item isKindOfClass:[UIImage class]] ||
        [item isKindOfClass:[NSData class]] ||
        [item isKindOfClass:[BITHockeyAttachment class]] ||
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
