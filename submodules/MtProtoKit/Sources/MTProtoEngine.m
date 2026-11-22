#import <MtProtoKit/MTProtoEngine.h>

#import "Utils/MTQueueLocalObject.h"
#import <MtProtoKit/MTQueue.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTProtoEngineImpl : NSObject {
    MTQueue *_queue;
    id<MTProtoPersistenceInterface> _persistenceInterface;
}

@end

@implementation MTProtoEngineImpl

- (instancetype)initWithQueue:(MTQueue *)queue persistenceInterface:(id<MTProtoPersistenceInterface>)persistenceInterface {
    self = [super init];
    if (self != nil) {
        _queue = queue;
        _persistenceInterface = persistenceInterface;
    }
    return self;
}

@end

@interface MTProtoEngine () {
    MTQueue *_queue;
    MTQueueLocalObject<MTProtoEngineImpl *> *_impl;
}

@end

@implementation MTProtoEngine

- (instancetype)initWithPersistenceInterface:(id<MTProtoPersistenceInterface>)persistenceInterface {
    self = [super init];
    if (self != nil) {
        _queue = [[MTQueue alloc] init];
        __auto_type queue = _queue;
        _impl = [[MTQueueLocalObject<MTProtoEngineImpl
                  *> alloc] initWithQueue:queue generator:^MTProtoEngineImpl *{
            return [[MTProtoEngineImpl alloc] initWithQueue:queue persistenceInterface:persistenceInterface];
        }];
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
