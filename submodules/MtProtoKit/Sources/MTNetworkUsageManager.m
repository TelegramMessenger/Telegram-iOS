#import <MtProtoKit/MTNetworkUsageManager.h>

#include <sys/mman.h>
#import <os/lock.h>

#import <MtProtoKit/MTNetworkUsageCalculationInfo.h>
#import <MtProtoKit/MTSignal.h>
#import <MtProtoKit/MTTimer.h>
#import <MtProtoKit/MTQueue.h>
#import <MtProtoKit/MTAtomic.h>

static int offsetForInterface(MTNetworkUsageCalculationInfo *info, MTNetworkUsageManagerInterface interface, bool incoming) {
    switch (interface) {
        case MTNetworkUsageManagerInterfaceWWAN:
            if (incoming) {
                return info.incomingWWANKey * 8;
            } else {
                return info.outgoingWWANKey * 8;
            }
        case MTNetworkUsageManagerInterfaceOther:
            if (incoming) {
                return info.incomingOtherKey * 8;
            } else {
                return info.outgoingOtherKey * 8;
            }
    }
}

@interface MTNetworkUsageManagerImpl : NSObject {
    MTQueue *_queue;
    MTNetworkUsageCalculationInfo *_info;
    
    NSMutableDictionary<NSNumber *, NSNumber *> *_pendingIncomingBytes;
    NSMutableDictionary<NSNumber *, NSNumber *> *_pendingOutgoingBytes;
    MTTimer *_timer;
}

@end

@implementation MTNetworkUsageManagerImpl

- (instancetype)initWithQueue:(MTQueue *)queue info:(MTNetworkUsageCalculationInfo *)info {
    self = [super init];
    if (self != nil) {
        _queue = queue;
        _info = info;
        
        _pendingIncomingBytes = [[NSMutableDictionary alloc] init];
        _pendingOutgoingBytes = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc {
    [self sync];
}

- (void)scheduleSync {
    if (_timer == nil) {
        __weak MTNetworkUsageManagerImpl *weakSelf = self;
        _timer = [[MTTimer alloc] initWithTimeout:1.0 repeat:false completion:^{
            __strong MTNetworkUsageManagerImpl *strongSelf = weakSelf;
            [strongSelf sync];
        } queue:_queue.nativeQueue];
        [_timer start];
    }
}

- (void)sync {
    [_timer invalidate];
    _timer = nil;
    
    int32_t fd = open([_info.filePath UTF8String], O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
    if (fd >= 0) {
        [_pendingIncomingBytes enumerateKeysAndObjectsUsingBlock:^(NSNumber * nInterface, NSNumber *nValue, __unused BOOL *stop) {
            off_t offset = offsetForInterface(_info, (MTNetworkUsageManagerInterface)[nInterface intValue], true);
            lseek(fd, offset, SEEK_SET);
            int64_t currentValue = 0;
            read(fd, &currentValue, 8);
            currentValue += (int64_t)[nValue intValue];
            lseek(fd, offset, SEEK_SET);
            write(fd, &currentValue, 8);
        }];
        [_pendingOutgoingBytes enumerateKeysAndObjectsUsingBlock:^(NSNumber * nInterface, NSNumber *nValue, __unused BOOL *stop) {
            off_t offset = offsetForInterface(_info, (MTNetworkUsageManagerInterface)[nInterface intValue], false);
            lseek(fd, offset, SEEK_SET);
            int64_t currentValue = 0;
            read(fd, &currentValue, 8);
            currentValue += (int64_t)[nValue intValue];
            lseek(fd, offset, SEEK_SET);
            write(fd, &currentValue, 8);
        }];
        close(fd);
    }
    
    [_pendingIncomingBytes removeAllObjects];
    [_pendingOutgoingBytes removeAllObjects];
}

- (void)addIncomingBytes:(NSUInteger)incomingBytes interface:(MTNetworkUsageManagerInterface)interface {
    _pendingIncomingBytes[@(interface)] = @([_pendingIncomingBytes[@(interface)] unsignedIntegerValue] + incomingBytes);
    [self scheduleSync];
}

- (void)addOutgoingBytes:(NSUInteger)outgoingBytes interface:(MTNetworkUsageManagerInterface)interface {
    _pendingOutgoingBytes[@(interface)] = @([_pendingOutgoingBytes[@(interface)] unsignedIntegerValue] + outgoingBytes);
    [self scheduleSync];
}

- (void)resetKeys:(NSArray<NSNumber *> *)keys setKeys:(NSDictionary<NSNumber *, NSNumber *> *)setKeys completion:(void (^)())completion {
    [self sync];
    int32_t fd = open([_info.filePath UTF8String], O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
    if (fd >= 0) {
        for (NSNumber *nKey in keys) {
            lseek(fd, [nKey intValue] * 8, SEEK_SET);
            int64_t currentValue = 0;
            write(fd, &currentValue, 8);
        }
        [setKeys enumerateKeysAndObjectsUsingBlock:^(NSNumber *nKey, NSNumber *nValue, __unused BOOL *stop) {
            lseek(fd, [nKey intValue] * 8, SEEK_SET);
            int64_t currentValue = [nValue longLongValue];
            write(fd, &currentValue, 8);
        }];
        close(fd);
    }
    if (completion) {
        completion();
    }
}

- (NSDictionary *)currentStatsForKeys:(NSArray<NSNumber *> *)keys {
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    [self sync];
    int32_t fd = open([_info.filePath UTF8String], O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
    if (fd >= 0) {
        for (NSNumber *nKey in keys) {
            lseek(fd, [nKey intValue] * 8, SEEK_SET);
            int64_t currentValue = 0;
            read(fd, &currentValue, 8);
            result[nKey] = @(currentValue);
        }
        int64_t currentValue = 0;
        read(fd, &currentValue, 8);
        close(fd);
    }
    return result;
}

@end

@interface MTNetworkUsageManagerImplHolder: NSObject

@property (nonatomic) void *impl;
@property (nonatomic) bool deallocated;

@end

@implementation MTNetworkUsageManagerImplHolder

@end

@interface MTNetworkUsageManager () {
    MTQueue *_queue;
    MTAtomic *_holder;
}

@end

@implementation MTNetworkUsageManager

- (instancetype)initWithInfo:(MTNetworkUsageCalculationInfo *)info {
    self = [super init];
    if (self != nil) {
        _queue = [[MTQueue alloc] init];
        _holder = [[MTAtomic alloc] initWithValue:[[MTNetworkUsageManagerImplHolder alloc] init]];
        [_queue dispatchOnQueue:^{
            [_holder with:^id (MTNetworkUsageManagerImplHolder *holder) {
                if (!holder.deallocated) {
                    holder.impl = (void *)CFBridgingRetain([[MTNetworkUsageManagerImpl alloc] initWithQueue:_queue info:info]);
                }
                return nil;
            }];
        }];
    }
    return self;
}

- (void)dealloc {
    MTAtomic *holder = _holder;
    [holder with:^id (MTNetworkUsageManagerImplHolder *holder) {
        holder.deallocated = true;
        return nil;
    }];
    [_queue dispatchOnQueue:^{
        __block void *impl = nil;
        [holder with:^id (MTNetworkUsageManagerImplHolder *holder) {
            impl = holder.impl;
            holder.impl = nil;
            return nil;
        }];
        CFBridgingRelease(impl);
    }];
}

- (void)with:(void (^)(MTNetworkUsageManagerImpl *))f {
    [_queue dispatchOnQueue:^{
        __block __strong MTNetworkUsageManagerImpl *impl = nil;
        [_holder with:^id (MTNetworkUsageManagerImplHolder *holder) {
            impl = (__bridge MTNetworkUsageManagerImpl *)holder.impl;
            return nil;
        }];
        f(impl);
    }];
}

- (void)addIncomingBytes:(NSUInteger)incomingBytes interface:(MTNetworkUsageManagerInterface)interface {
    [self with:^(MTNetworkUsageManagerImpl *impl) {
        [impl addIncomingBytes:incomingBytes interface:interface];
    }];
}

- (void)addOutgoingBytes:(NSUInteger)outgoingBytes interface:(MTNetworkUsageManagerInterface)interface {
    [self with:^(MTNetworkUsageManagerImpl *impl) {
        [impl addOutgoingBytes:outgoingBytes interface:interface];
    }];
}

- (void)resetKeys:(NSArray<NSNumber *> *)keys setKeys:(NSDictionary<NSNumber *, NSNumber *> *)setKeys completion:(void (^)())completion {
    [self with:^(MTNetworkUsageManagerImpl *impl) {
        [impl resetKeys:keys setKeys:setKeys completion:completion];
    }];
}

- (MTSignal *)currentStatsForKeys:(NSArray<NSNumber *> *)keys {
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        [self with:^(MTNetworkUsageManagerImpl *impl) {
            NSDictionary *result = [impl currentStatsForKeys:keys];
            [subscriber putNext:result];
            [subscriber putCompletion];
        }];
        return nil;
    }];
}

@end
