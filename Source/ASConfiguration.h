//
//  ASConfiguration.h
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
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASExperimentalFeatures.h>

@protocol ASConfigurationDelegate;

NS_ASSUME_NONNULL_BEGIN

static NSInteger const ASConfigurationSchemaCurrentVersion = 1;

AS_SUBCLASSING_RESTRICTED
@interface ASConfiguration : NSObject <NSCopying>

/**
 * Initialize this configuration with the provided dictionary,
 * or nil to create an empty configuration.
 *
 * The schema is located in `schemas/configuration.json`.
 */
- (instancetype)initWithDictionary:(nullable NSDictionary *)dictionary;

/**
 * The delegate for configuration-related events.
 * Delegate methods are called from a serial queue.
 */
@property (nonatomic, nullable) id<ASConfigurationDelegate> delegate;

/**
 * The experimental features to enable in Texture.
 * See ASExperimentalFeatures for functions to convert to/from a string array.
 */
@property (nonatomic) ASExperimentalFeatures experimentalFeatures;

@end

/**
 * Implement this method in a category to make your
 * configuration available to Texture. It will be read
 * only once and copied.
 *
 * NOTE: To specify your configuration at compile-time, you can
 * define AS_FIXED_CONFIG_JSON as a C-string of JSON. This method
 * will then be implemented to parse that string and generate
 * a configuration.
 */
@interface ASConfiguration (UserProvided)
+ (ASConfiguration *)textureConfiguration NS_RETURNS_RETAINED;
@end

NS_ASSUME_NONNULL_END
