#import "MTConnectionProbing.h"

#import <MtProtoKit/MTSignal.h>
#import <MtProtoKit/MTQueue.h>
#import <MtProtoKit/MTAtomic.h>
#import <MtProtoKit/MTHttpRequestOperation.h>
#import <MtProtoKit/MTEncryption.h>
#import <MtProtoKit/MTRequestMessageService.h>
#import <MtProtoKit/MTRequest.h>
#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTApiEnvironment.h>
#import <MtProtoKit/MTDatacenterAddress.h>
#import <MtProtoKit/MTDatacenterAddressSet.h>
#import <MtProtoKit/MTProto.h>
#import <MtProtoKit/MTSerialization.h>
#import <MtProtoKit/MTLogging.h>
#import <MtProtoKit/MTProxyConnectivity.h>

#import "PingFoundation.h"

@interface MTPingHelper : NSObject <PingFoundationDelegate> {
    void (^_success)();
    PingFoundation *_ping;
}

@end

@implementation MTPingHelper
    
+ (void)runLoopThreadFunc {
    while (true) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantFuture]];
    }
}
    
+ (NSThread *)runLoopThread {
    static NSThread *thread = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        thread = [[NSThread alloc] initWithTarget:self selector:@selector(runLoopThreadFunc) object:nil];
        thread.name = @"MTPingHelper";
        [thread start];
    });
    return thread;
}
    
+ (void)dispatchOnRunLoopThreadImpl:(void (^)())f {
    if (f) {
        f();
    }
}
    
+ (void)dispatchOnRunLoopThread:(void (^)())block {
    [self performSelector:@selector(dispatchOnRunLoopThreadImpl:) onThread:[self runLoopThread] withObject:[block copy] waitUntilDone:false];
}

- (instancetype)initWithSuccess:(void (^)())success {
    self = [super init];
    if (self != nil) {
        _success = [success copy];
        
        NSArray *hosts = @[
            @"google.com",
            @"8.8.8.8"
        ];
        
        NSString *host = hosts[(int)(arc4random_uniform((uint32_t)hosts.count))];
        
        _ping = [[PingFoundation alloc] initWithHostName:host];
        _ping.delegate = self;
        [_ping start];
    }
    return self;
}

- (void)dealloc {
#if DEBUG
    assert(_ping.delegate == nil);
#endif
    if (_ping.delegate != nil) {
        _ping.delegate = nil;
        [_ping stop];
    }
}

- (void)stop {
    _ping.delegate = nil;
    [_ping stop];
}

- (void)pingFoundation:(PingFoundation *)pinger didReceivePingResponsePacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber {
    if (_success) {
        _success();
    }
}

- (void)pingFoundation:(PingFoundation *)pinger didStartWithAddress:(NSData *)__unused address {
    [pinger sendPingWithData:nil];
}

@end

@implementation MTConnectionProbing

+ (MTSignal *)pingAddress {
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        MTMetaDisposable *disposable = [[MTMetaDisposable alloc] init];
        
        [MTPingHelper dispatchOnRunLoopThread:^{
            MTPingHelper *helper = [[MTPingHelper alloc] initWithSuccess:^{
                [subscriber putNext:@true];
                [subscriber putCompletion];
            }];
            
            [disposable setDisposable:[[MTBlockDisposable alloc] initWithBlock:^{
                [MTPingHelper dispatchOnRunLoopThread:^{
                    [helper stop];
                }];
            }]];
        }];
        
        return disposable;
    }];
}

+ (MTSignal *)probeProxyWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId settings:(MTSocksProxySettings *)settings {
    MTSignal *proxyAvailable = [[[MTProxyConnectivity pingProxyWithContext:context datacenterId:datacenterId settings:settings] map:^id(MTProxyConnectivityStatus *status) {
        return @(status.reachable);
    }] timeout:10.0 onQueue:[MTQueue concurrentDefaultQueue] orSignal:[MTSignal single:@false]];
    MTSignal *referenceAvailable = [[self pingAddress] timeout:10.0 onQueue:[MTQueue concurrentDefaultQueue] orSignal:[MTSignal single:@false]];
    MTSignal *combined = [[MTSignal combineSignals:@[proxyAvailable, referenceAvailable]] map:^id(NSArray *values) {
        NSNumber *proxy = values[0];
        NSNumber *ping = values[1];
        if (![proxy boolValue] && [ping boolValue]) {
            return @true;
        } else {
            return @false;
        }
    }];
    return combined;
}

@end
