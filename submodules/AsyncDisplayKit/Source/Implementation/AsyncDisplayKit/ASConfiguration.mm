//
//  ASConfiguration.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASConfiguration.h>
#import <AsyncDisplayKit/ASConfigurationInternal.h>

/// Not too performance-sensitive here.

@implementation ASConfiguration

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
  if (self = [super init]) {
    if (dictionary != nil) {
      const auto featureStrings = ASDynamicCast(dictionary[@"experimental_features"], NSArray);
      const auto version = ASDynamicCast(dictionary[@"version"], NSNumber).integerValue;
      if (version != ASConfigurationSchemaCurrentVersion) {
        NSLog(@"Texture warning: configuration schema is old version (%ld vs %ld)", (long)version, (long)ASConfigurationSchemaCurrentVersion);
      }
      self.experimentalFeatures = ASExperimentalFeaturesFromArray(featureStrings);
    } else {
      self.experimentalFeatures = kNilOptions;
    }
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
