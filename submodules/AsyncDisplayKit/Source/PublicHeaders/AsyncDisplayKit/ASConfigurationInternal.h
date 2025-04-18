//
//  ASConfigurationInternal.h
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

/// Note this has to be public because it's imported by public header ASThread.h =/
/// It will be private again after exp_unfair_lock ends.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASConfiguration.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Quickly check if an experiment is enabled and notify the delegate
 * that it's been activated.
 *
 * The delegate will be notified asynchronously.
 */
#if DEBUG
#define ASActivateExperimentalFeature(opt) _ASActivateExperimentalFeature(opt)
#else
#define ASActivateExperimentalFeature(opt) ({\
  static BOOL result;\
  static dispatch_once_t onceToken;\
  dispatch_once(&onceToken, ^{ result = _ASActivateExperimentalFeature(opt); });\
  result;\
})
#endif

/**
 * Internal function. Use the macro without the underbar.
 */
AS_EXTERN BOOL _ASActivateExperimentalFeature(ASExperimentalFeatures option);

/**
 * Notify the configuration delegate that the framework initialized, if needed.
 */
AS_EXTERN void ASNotifyInitialized(void);

AS_SUBCLASSING_RESTRICTED
@interface ASConfigurationManager : NSObject

/**
 * No API for now.
 * Just use ASActivateExperimentalFeature to access this efficiently.
 */

/* Exposed for testing purposes only */
+ (void)test_resetWithConfiguration:(nullable ASConfiguration *)configuration;

@end

NS_ASSUME_NONNULL_END
