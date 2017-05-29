#import "MTNetworkUsageManager.h"

#include <sys/mman.h>
#import <libkern/OSAtomic.h>

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTNetworkUsageCalculationInfo.h>
#   import <MTProtoKitDynamic/MTSignal.h>
#   import <MTProtoKitDynamic/MTTimer.h>
#   import <MTProtoKitDynamic/MTQueue.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTNetworkUsageCalculationInfo.h>
#   import <MTProtoKitMac/MTSignal.h>
#   import <MTProtoKitMac/MTTimer.h>
#   import <MTProtoKitMac/MTQueue.h>
#else
#   import <MTProtoKit/MTNetworkUsageCalculationInfo.h>
#   import <MTProtoKit/MTSignal.h>
#   import <MTProtoKit/MTTimer.h>
#   import <MTProtoKit/MTQueue.h>
#endif

@interface MTNetworkUsageManager () {
    MTQueue *_queue;
    MTNetworkUsageCalculationInfo *_info;
    
    NSUInteger _pendingIncomingBytes;
    NSUInteger _pendingOutgoingBytes;
    
    int _fd;
    void *_map;
}

@end

@implementation MTNetworkUsageManager

- (instancetype)initWithInfo:(MTNetworkUsageCalculationInfo *)info {
    self = [super init];
    if (self != nil) {
        _queue = [[MTQueue alloc] init];
        _info = info;
        
        [_queue dispatchOnQueue:^{
            NSString *path = info.filePath;
            int32_t fd = open([path UTF8String], O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
            if (fd >= 0) {
                _fd = fd;
                ftruncate(fd, 4096);
                void *map = mmap(0, 4096, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
                if (map != MAP_FAILED) {
                    _map = map;
                }
            }
        }];
    }
    return self;
}

- (void)dealloc {
    void *map = _map;
    int32_t fd = _fd;
    [_queue dispatchOnQueue:^{
        if (map) {
            munmap(map, 4096);
        }
        if (fd > 0) {
            close(fd);
        }
    }];
}

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

- (void)addIncomingBytes:(NSUInteger)incomingBytes interface:(MTNetworkUsageManagerInterface)interface {
    [_queue dispatchOnQueue:^{
        if (_map) {
            int64_t *ptr = (int64_t *)(_map + offsetForInterface(_info, interface, true));
            OSAtomicAdd64((int64_t)incomingBytes, ptr);
        }
    }];
}

- (void)addOutgoingBytes:(NSUInteger)outgoingBytes interface:(MTNetworkUsageManagerInterface)interface {
    [_queue dispatchOnQueue:^{
        if (_map) {
            int64_t *ptr = (int64_t *)(_map + offsetForInterface(_info, interface, false));
            OSAtomicAdd64((int64_t)outgoingBytes, ptr);
        }
    }];
}

- (void)resetKeys:(NSArray<NSNumber *> *)keys setKeys:(NSDictionary<NSNumber *, NSNumber *> *)setKeys completion:(void (^)())completion {
    [_queue dispatchOnQueue:^{
        if (_map) {
            for (NSNumber *key in keys) {
                int64_t *ptr = (int64_t *)(_map + [key intValue] * 8);
                *ptr = 0;
            }
            [setKeys enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSNumber *value, __unused BOOL *stop) {
                int64_t *ptr = (int64_t *)(_map + [key intValue] * 8);
                *ptr = [value longLongValue];
            }];
            if (completion) {
                completion();
            }
        }
    }];
}

- (MTSignal *)currentStatsForKeys:(NSArray<NSNumber *> *)keys {
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        [_queue dispatchOnQueue:^{
            if (_map) {
                NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
                for (NSNumber *key in keys) {
                    int64_t *ptr = (int64_t *)(_map + [key intValue] * 8);
                    result[key] = @(*ptr);
                }
                
                [subscriber putNext:result];
            } else {
                [subscriber putNext:nil];
            }
            [subscriber putCompletion];
        }];
        return nil;
    }];
}

@end
