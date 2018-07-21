//
//  ASConfigurationInternal.h
//  Texture
//
//  Copyright (c) 2018-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

/// Note this has to be public because it's imported by public header ASThread.h =/
/// It will be private again after exp_unfair_lock ends.

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASConfiguration.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Quickly check if an experiment is enabled and notify the delegate
 * that it's been activated.
 *
 * The delegate will be notified asynchronously.
 */
AS_EXTERN BOOL ASActivateExperimentalFeature(ASExperimentalFeatures option);

AS_SUBCLASSING_RESTRICTED
@interface ASConfigurationManager : NSObject

/**
 * No API for now.
 * Just use ASActivateExperimentalFeature to access this efficiently.
 */

@end

NS_ASSUME_NONNULL_END
