//
//  ASConfigurationInternal.mm
//  Texture
//
//  Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <AsyncDisplayKit/ASConfigurationInternal.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASConfiguration.h>
#import <AsyncDisplayKit/ASConfigurationDelegate.h>
#import <stdatomic.h>

static ASConfigurationManager *ASSharedConfigurationManager;
static dispatch_once_t ASSharedConfigurationManagerOnceToken;

NS_INLINE ASConfigurationManager *ASConfigurationManagerGet() {
  dispatch_once(&ASSharedConfigurationManagerOnceToken, ^{
    ASSharedConfigurationManager = [[ASConfigurationManager alloc] init];
  });
  return ASSharedConfigurationManager;
}

@implementation ASConfigurationManager {
  ASConfiguration *_config;
  dispatch_queue_t _delegateQueue;
  BOOL _frameworkInitialized;
  _Atomic(ASExperimentalFeatures) _activatedExperiments;
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

- (void)frameworkDidInitialize
{
  ASDisplayNodeAssertMainThread();
  if (_frameworkInitialized) {
    ASDisplayNodeFailAssert(@"Framework initialized twice.");
    return;
  }
  _frameworkInitialized = YES;
  
  const auto delegate = _config.delegate;
  if ([delegate respondsToSelector:@selector(textureDidInitialize)]) {
    [delegate textureDidInitialize];
  }
}

- (BOOL)activateExperimentalFeature:(ASExperimentalFeatures)requested
{
  if (_config == nil) {
    return NO;
  }
  
  NSAssert(__builtin_popcountl(requested) == 1, @"Cannot activate multiple features at once with this method.");
  
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
  ASConfigurationManager *inst = ASConfigurationManagerGet();
  inst->_config = configuration ?: [self defaultConfiguration];
  atomic_store(&inst->_activatedExperiments, 0);
}

@end

BOOL _ASActivateExperimentalFeature(ASExperimentalFeatures feature)
{
  return [ASConfigurationManagerGet() activateExperimentalFeature:feature];
}

void ASNotifyInitialized()
{
  [ASConfigurationManagerGet() frameworkDidInitialize];
}
