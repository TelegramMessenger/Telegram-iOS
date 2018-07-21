//
//  ASConfiguration.m
//  Texture
//
//  Copyright (c) 2018-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASConfiguration.h>
#import <AsyncDisplayKit/ASConfigurationInternal.h>

/// Not too performance-sensitive here.

/// Get this from C++, without the extra exception handling.
#define autotype __auto_type

@implementation ASConfiguration

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
  if (self = [super init]) {
    autotype featureStrings = ASDynamicCast(dictionary[@"experimental_features"], NSArray);
    autotype version = ASDynamicCast(dictionary[@"version"], NSNumber).integerValue;
    if (version != ASConfigurationSchemaCurrentVersion) {
      NSLog(@"Texture warning: configuration schema is old version (%zd vs %zd)", version, ASConfigurationSchemaCurrentVersion);
    }
    self.experimentalFeatures = ASExperimentalFeaturesFromArray(featureStrings);
  }
  return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  ASConfiguration *config = [[ASConfiguration alloc] initWithDictionary:nil];
  config.experimentalFeatures = self.experimentalFeatures;
  config.delegate = self.delegate;
  return config;
}

@end

//#define AS_FIXED_CONFIG_JSON "{ \"version\" : 1, \"experimental_features\": [ \"exp_text_node\" ] }"

#ifdef AS_FIXED_CONFIG_JSON

@implementation ASConfiguration (UserProvided)

+ (ASConfiguration *)textureConfiguration NS_RETURNS_RETAINED
{
  NSData *data = [@AS_FIXED_CONFIG_JSON dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error;
  NSDictionary *d = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
  if (!d) {
    NSAssert(NO, @"Error parsing fixed config string '%s': %@", AS_FIXED_CONFIG_JSON, error);
    return nil;
  } else {
    return [[ASConfiguration alloc] initWithDictionary:d];
  }
}

@end

#endif // AS_FIXED_CONFIG_JSON
