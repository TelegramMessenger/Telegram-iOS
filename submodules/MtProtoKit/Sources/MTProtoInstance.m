#import <MtProtoKit/MTProtoInstance.h>

#import <MtProtoKit/MTQueue.h>
#import "Utils/MTQueueLocalObject.h"

@interface MTProtoInstanceImpl : NSObject {
    MTQueue *_queue;
    MTProtoEngine *_engine;
}

@end

@implementation MTProtoInstanceImpl

- (instancetype)initWithQueue:(MTQueue *)queue engine:(MTProtoEngine *)engine {
    self = [super init];
    if (self != nil) {
        _queue = queue;
        _engine = engine;
    }
    return self;
}

@end

@interface MTProtoInstance () {
    MTQueue *_queue;
    MTQueueLocalObject<MTProtoInstanceImpl *> *_impl;
}

@end

@implementation MTProtoInstance

- (instancetype)initWithEngine:(MTProtoEngine *)engine {
    self = [super init];
    if (self != nil) {
        _queue = [[MTQueue alloc] init];
        __auto_type queue = _queue;
        _impl = [[MTQueueLocalObject<MTProtoInstanceImpl
                  *> alloc] initWithQueue:queue generator:^MTProtoInstanceImpl *{
            return [[MTProtoInstanceImpl alloc] initWithQueue:queue engine:engine];
        }];
    }
    return self;
}

@end
