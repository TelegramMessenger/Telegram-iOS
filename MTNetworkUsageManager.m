#import "MTNetworkUsageManager.h"

#import "MTNetworkUsageCalculationInfo.h"
#import "MTTimer.h"
#import "MTQueue.h"
#import "MTSignal.h"
#include <sys/mman.h>
#import <libkern/OSAtomic.h>

@implementation MTNetworkUsageManagerStats

- (instancetype)initWithWWAN:(MTNetworkUsageManagerInterfaceStats)wwan other:(MTNetworkUsageManagerInterfaceStats)other {
    self = [super init];
    if (self != nil) {
        _wwan = wwan;
        _other = other;
    }
    return self;
}

@end

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

static int interfaceOffset(MTNetworkUsageManagerInterface interface) {
    switch (interface) {
        case MTNetworkUsageManagerInterfaceWWAN:
            return 0;
        case MTNetworkUsageManagerInterfaceOther:
            return 8;
    }
}

- (void)addIncomingBytes:(NSUInteger)incomingBytes interface:(MTNetworkUsageManagerInterface)interface {
    [_queue dispatchOnQueue:^{
        if (_map) {
            int64_t *ptr = (int64_t *)(_map + 0 * 16 + interfaceOffset(interface));
            OSAtomicAdd64((int64_t)incomingBytes, ptr);
        }
    }];
}

- (void)addOutgoingBytes:(NSUInteger)outgoingBytes interface:(MTNetworkUsageManagerInterface)interface {
    [_queue dispatchOnQueue:^{
        if (_map) {
            int64_t *ptr = (int64_t *)(_map + 1 * 16 + interfaceOffset(interface));
            OSAtomicAdd64((int64_t)outgoingBytes, ptr);
        }
    }];
}

- (MTSignal *)currentStats {
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        [_queue dispatchOnQueue:^{
            if (_map) {
                int64_t *incomingWan = (int64_t *)(_map + 0 * 16 + interfaceOffset(MTNetworkUsageManagerInterfaceWWAN));
                int64_t *outgoingWan = (int64_t *)(_map + 1 * 16 + interfaceOffset(MTNetworkUsageManagerInterfaceWWAN));
                int64_t *incomingOther = (int64_t *)(_map + 0 * 16 + interfaceOffset(MTNetworkUsageManagerInterfaceOther));
                int64_t *outgoingOther = (int64_t *)(_map + 1 * 16 + interfaceOffset(MTNetworkUsageManagerInterfaceOther));
                
                [subscriber putNext:[[MTNetworkUsageManagerStats alloc] initWithWWAN:(MTNetworkUsageManagerInterfaceStats){.incomingBytes = (NSUInteger)*incomingWan, .outgoingBytes = (NSUInteger)*outgoingWan} other:(MTNetworkUsageManagerInterfaceStats){.incomingBytes = (NSUInteger)*incomingOther, .outgoingBytes = (NSUInteger)*outgoingOther}]];
            } else {
                [subscriber putNext:nil];
            }
            [subscriber putCompletion];
        }];
        return nil;
    }];
}

@end
