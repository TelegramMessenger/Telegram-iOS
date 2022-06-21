#import <MtProtoKit/MTProxyConnectivity.h>

#import <MtProtoKit/MTSignal.h>
#import <MtProtoKit/MTQueue.h>
#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTApiEnvironment.h>
#import <MtProtoKit/MTDatacenterAddressSet.h>
#import <MtProtoKit/MTDatacenterAddress.h>
#import "MTTcpConnection.h"
#import <MtProtoKit/MTTransportScheme.h>
#import "MTDiscoverConnectionSignals.h"

@implementation MTProxyConnectivityStatus

- (instancetype)initWithReachable:(bool)reachable roundTripTime:(NSTimeInterval)roundTripTime {
    self = [super init];
    if (self != nil) {
        _reachable = reachable;
        _roundTripTime = roundTripTime;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[MTProxyConnectivityStatus class]]) {
        return false;
    }
    MTProxyConnectivityStatus *other = object;
    if (_reachable != other.reachable) {
        return false;
    }
    if (_roundTripTime != other.roundTripTime) {
        return false;
    }
    return true;
}

@end

@implementation MTProxyConnectivity

+ (bool)isResponseValid:(NSData *)data payloadData:(MTPayloadData)payloadData
{
    if (data.length >= 84)
    {
        uint8_t zero[] = { 0, 0, 0, 0, 0, 0, 0, 0 };
        uint8_t resPq[] = { 0x63, 0x24, 0x16, 0x05 };
        if (memcmp((uint8_t * const)data.bytes, zero, 8) == 0 && memcmp(((uint8_t * const)data.bytes) + 20, resPq, 4) == 0 && memcmp(((uint8_t * const)data.bytes) + 24, payloadData.nonce, 16) == 0)
        {
            return true;
        }
    }
    
    return false;
}

+ (MTSignal *)pingWithAddress:(MTDatacenterAddress *)address datacenterId:(NSUInteger)datacenterId settings:(MTSocksProxySettings *)settings context:(MTContext *)context {
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        MTQueue *queue = [[MTQueue alloc] init];
        
        MTMetaDisposable *disposable = [[MTMetaDisposable alloc] init];
        [queue dispatchOnQueue:^{
            [subscriber putNext:[NSNull null]];
            MTPayloadData payloadData;
            NSData *data = [MTDiscoverConnectionSignals payloadData:&payloadData context:context address:address];
            
            MTContext *proxyContext = [[MTContext alloc] initWithSerialization:context.serialization encryptionProvider:context.encryptionProvider apiEnvironment:[[context apiEnvironment] withUpdatedSocksProxySettings:settings]  isTestingEnvironment:context.isTestingEnvironment useTempAuthKeys:false];
            
            MTTcpConnection *connection = [[MTTcpConnection alloc] initWithContext:proxyContext datacenterId:datacenterId scheme:[[MTTransportScheme alloc] initWithTransportClass:[MTTcpConnection class] address:address media:false] interface:nil usageCalculationInfo:nil getLogPrefix:nil];
            __weak MTTcpConnection *weakConnection = connection;
            __block NSTimeInterval startTime = CFAbsoluteTimeGetCurrent();
            connection.connectionOpened = ^ {
                __strong MTTcpConnection *strongConnection = weakConnection;
                if (strongConnection != nil) {
                    startTime = CFAbsoluteTimeGetCurrent();
                    [strongConnection sendDatas:@[data] completion:nil requestQuickAck:false expectDataInResponse:true];
                }
            };
            __block bool received = false;
            connection.connectionReceivedData = ^(NSData *data) {
                received = true;
                if ([self isResponseValid:data payloadData:payloadData]) {
                    NSTimeInterval roundTripTime = CFAbsoluteTimeGetCurrent() - startTime;
                    [subscriber putNext:[[MTProxyConnectivityStatus alloc] initWithReachable:true roundTripTime:roundTripTime]];
                } else {
                    [subscriber putNext:[[MTProxyConnectivityStatus alloc] initWithReachable:false roundTripTime:0.0]];
                }
                [subscriber putCompletion];
            };
            connection.connectionClosed = ^
            {
                if (!received) {
                    [subscriber putNext:[[MTProxyConnectivityStatus alloc] initWithReachable:false roundTripTime:0.0]];
                    [subscriber putCompletion];
                }
            };
            [connection start];
            
            [disposable setDisposable:[[MTBlockDisposable alloc] initWithBlock:^{
                [queue dispatchOnQueue:^{
                    [connection stop];
                    __unused id desc = [proxyContext description];
                }];
            }]];
        }];
        
        return disposable;
    }];
}

+ (MTSignal *)pingProxyWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId settings:(MTSocksProxySettings *)settings {
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        MTDatacenterAddressSet *addressSet = [context addressSetForDatacenterWithId:datacenterId];
        NSMutableArray *signals = [[NSMutableArray alloc] init];
        for (MTDatacenterAddress *address in addressSet.addressList) {
            if (!address.isIpv6) {
                [signals addObject:[self pingWithAddress:address datacenterId:datacenterId settings:settings context:context]];
            }
            if (address.isIpv6) {
                [signals addObject:[self pingWithAddress:address datacenterId:datacenterId settings:settings context:context]];
            }
        }
        
        if (signals.count == 0) {
            [subscriber putNext:[[MTProxyConnectivityStatus alloc] initWithReachable:false roundTripTime:0.0]];
            [subscriber putCompletion];
            return nil;
        }
        
        return [[MTSignal combineSignals:signals] startWithNext:^(NSArray *results) {
            bool allStatusesAreValid = true;
            for (MTProxyConnectivityStatus *status in results) {
                if ([status isKindOfClass:[MTProxyConnectivityStatus class]]) {
                    if (status.reachable) {
                        [subscriber putNext:status];
                        [subscriber putCompletion];
                        return;
                    }
                } else {
                    allStatusesAreValid = false;
                }
            }
            if (allStatusesAreValid) {
                [subscriber putNext:[[MTProxyConnectivityStatus alloc] initWithReachable:false roundTripTime:0.0]];
                [subscriber putCompletion];
            }
        }];
    }];
}

@end
