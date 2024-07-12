//
//  Created by Adam Stragner
//

#import <TonProxyBridge/TPBTunnel.h>
#import <TonProxyBridge/TPBTunnelParameters.h>

#import <tonutilsproxy/tonutilsproxy.h>

NSErrorDomain const TPBErrorDomain = @"TPBErrorDomain";

@interface TPBTunnel ()

@property (nonatomic, retain) TPBTunnelParameters * _Nullable _parameters;
@property (nonatomic, retain) dispatch_queue_t queue;

@end

@implementation TPBTunnel

- (instancetype)init_ {
    self = [super init];
    if (self) {
        _queue = dispatch_queue_create("tonutils-proxy", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

+ (instancetype)sharedTunnel {
    static dispatch_once_t onceToken;
    static TPBTunnel *sharedTunnel = nil;
    dispatch_once(&onceToken, ^{
        sharedTunnel = [[TPBTunnel alloc] init_];
    });
    return sharedTunnel;
}

- (void)startWithPort:(UInt16)port completionBlock:(void (^ _Nullable)(TPBTunnelParameters * _Nullable parameters, NSError * _Nullable error))completionBlock {
    dispatch_async(_queue, ^{
        TPBTunnelParameters *parameters = self._parameters;
        if (parameters != nil) {
            if (completionBlock) {
                completionBlock(parameters, nil);
            }
            return;
        }
        
        char *result = StartProxy(port);
        NSError *error = [self errorWithResult:result];
        
        if (error == nil) {
            parameters = [[TPBTunnelParameters alloc] initWithHost:@"127.0.0.1" port:port];
            completionBlock(parameters, nil);
        } else {
            completionBlock(nil, error);
        }
        
        self._parameters = parameters;
    });
}

- (void)stopWithCompletionBlock:(void (^ _Nullable)(NSError * _Nullable error))completionBlock {
    dispatch_async(_queue, ^{
        if (self._parameters == nil) {
            if (completionBlock) {
                completionBlock(nil);
            }
            return;
        }
        
        char *result = StopProxy();
        self._parameters = nil;
        
        if (completionBlock) {
            completionBlock([self errorWithResult:result]);
        }
    });
}

- (NSError * _Nullable)errorWithResult:(char *)result {
    NSString *string = [NSString stringWithUTF8String:result];
    if ([string isEqualToString:@"OK"]) {
        return nil;
    } else {
        return [[NSError alloc] initWithDomain:TPBErrorDomain code:0 userInfo:@{
            NSLocalizedDescriptionKey : [string copy]
        }];
    }
}

#pragma Setters & Getters

- (TPBTunnelParameters * _Nullable)parameters {
    __block TPBTunnelParameters *parameters = nil;
    dispatch_sync(_queue, ^{
        parameters = self._parameters;
    });
    return parameters;
}

- (BOOL)isRunning {
    return [self parameters] != nil;
}

@end
