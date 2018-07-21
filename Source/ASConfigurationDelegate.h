//
//  ASConfigurationDelegate.h
//  Texture
//
//  Copyright (c) 2018-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASConfiguration.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Used to communicate configuration-related events to the client.
 */
@protocol ASConfigurationDelegate <NSObject>

/**
 * Texture performed its first behavior related to the feature(s).
 * This can be useful for tracking the impact of the behavior (A/B testing).
 */
- (void)textureDidActivateExperimentalFeatures:(ASExperimentalFeatures)features;

@end

NS_ASSUME_NONNULL_END
