//
//  ASConfigurationInternal.m
//  Texture
//
//  Copyright (c) 2018-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import "ASConfigurationInternal.h"
#import <AsyncDisplayKit/ASConfiguration.h>
#import <AsyncDisplayKit/ASConfigurationDelegate.h>
#import <stdatomic.h>

#define ASGetSharedConfigMgr() (__bridge ASConfigurationManager *)ASConfigurationManager.sharedInstance

@implementation ASConfigurationManager {
  ASConfiguration *_config;
  dispatch_queue_t _delegateQueue;
  _Atomic(ASExperimentalFeatures) _activatedExperiments;
}

/// Return CFTypeRef to avoid retain/release on this singleton.
+ (CFTypeRef)sharedInstance
{
  static CFTypeRef inst;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    inst = (__bridge_retained CFTypeRef)[[ASConfigurationManager alloc] init];
  });
  return inst;
}

+ (ASConfiguration *)defaultConfiguration NS_RETURNS_RETAINED
{
  ASConfiguration *config = [[ASConfiguration alloc] init];
  // TODO(wsdwsd0829): Fix #788 before enabling it.
  // config.experimentalFeatures = ASExperimentalInterfaceStateCoalescing;
  return config;
}

- (instancetype)init
{
  if (self = [super init]) {
    _delegateQueue = dispatch_queue_create("org.TextureGroup.Texture.ConfigNotifyQueue", DISPATCH_QUEUE_SERIAL);
    if ([ASConfiguration respondsToSelector:@selector(textureConfiguration)]) {
      _config = [[ASConfiguration textureConfiguration] copy];
    } else {
      _config = [ASConfigurationManager defaultConfiguration];
    }
  }
  return self;
}

- (BOOL)activateExperimentalFeature:(ASExperimentalFeatures)requested
{
  if (_config == nil) {
    return NO;
  }
  
  NSAssert(__builtin_popcount(requested) == 1, @"Cannot activate multiple features at once with this method.");
  
  // We need to call out, whether it's enabled or not.
  // A/B testing requires even "control" users to be activated.
  ASExperimentalFeatures enabled = requested & _config.experimentalFeatures;
  ASExperimentalFeatures prevTriggered = atomic_fetch_or(&_activatedExperiments, requested);
  ASExperimentalFeatures newlyTriggered = requested & ~prevTriggered;
  
  // Notify delegate if needed.
  if (newlyTriggered != 0) {
    __unsafe_unretained id<ASConfigurationDelegate> del = _config.delegate;
    dispatch_async(_delegateQueue, ^{
      [del textureDidActivateExperimentalFeatures:newlyTriggered];
    });
  }
  
  return (enabled != 0);
}

// Define this even when !DEBUG, since we may run our tests in release mode.
+ (void)test_resetWithConfiguration:(ASConfiguration *)configuration
{
  ASConfigurationManager *inst = ASGetSharedConfigMgr();
  inst->_config = configuration ?: [self defaultConfiguration];
  atomic_store(&inst->_activatedExperiments, 0);
}

@end

BOOL ASActivateExperimentalFeature(ASExperimentalFeatures feature)
{
  return [ASGetSharedConfigMgr() activateExperimentalFeature:feature];
}
