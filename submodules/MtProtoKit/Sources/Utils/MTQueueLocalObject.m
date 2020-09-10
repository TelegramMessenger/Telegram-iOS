#import "MTQueueLocalObject.h"
#import <MtProtoKit/MTQueue.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTQueueLocalObjectHolder : NSObject

@property (nonatomic, assign) CFTypeRef impl;

@end

@implementation MTQueueLocalObjectHolder

@end

@interface MTQueueLocalObject () {
    MTQueue *_queue;
    MTQueueLocalObjectHolder *_holder;
}

@end

@implementation MTQueueLocalObject

- (instancetype)initWithQueue:(MTQueue *)queue generator:(id(^)())generator {
    self = [super init];
    if (self != nil) {
        _queue = queue;
        _holder = [[MTQueueLocalObjectHolder alloc] init];
        __auto_type holder = _holder;
        [queue dispatchOnQueue:^{
            id value = generator();
            holder.impl = CFBridgingRetain(value);
        } synchronous:false];
    }
    return self;
}

- (void)dealloc {
    __auto_type holder = _holder;
    [_queue dispatchOnQueue:^{
        CFBridgingRelease(holder.impl);
    } synchronous:false];
}

- (void)with:(void (^)(id))f {
    __auto_type holder = _holder;
    [_queue dispatchOnQueue:^{
        id value = (__bridge id)holder.impl;
        f(value);
    } synchronous:false];
}

@end

NS_ASSUME_NONNULL_END
