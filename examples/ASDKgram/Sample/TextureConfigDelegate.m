//
//  TextureConfigDelegate.m
//  Texture
//
//  Copyright (c) 2018-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface TextureConfigDelegate : NSObject <ASConfigurationDelegate>

@end

@implementation ASConfiguration (UserProvided)

+ (ASConfiguration *)textureConfiguration
{
  ASConfiguration *config = [[ASConfiguration alloc] init];
  config.experimentalFeatures = ASExperimentalGraphicsContexts | ASExperimentalTextNode;
  config.delegate = [[TextureConfigDelegate alloc] init];
  return config;
}

@end

@implementation TextureConfigDelegate

- (void)textureDidActivateExperimentalFeatures:(ASExperimentalFeatures)features
{
  if (features & ASExperimentalGraphicsContexts) {
    NSLog(@"Texture activated experimental graphics contexts.");
  }
}

@end

