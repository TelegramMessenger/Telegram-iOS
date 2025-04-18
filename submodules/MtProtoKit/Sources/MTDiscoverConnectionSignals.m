#import "MTDiscoverConnectionSignals.h"

#import "MTTcpConnection.h"
#import <MtProtoKit/MTTransportScheme.h>
#import <MtProtoKit/MTTcpTransport.h>
#import <MtProtoKit/MTQueue.h>
#import <MtProtoKit/MTDatacenterAddress.h>
#import <MtProtoKit/MTDisposable.h>
#import <MtProtoKit/MTSignal.h>
#import <MtProtoKit/MTAtomic.h>
#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTApiEnvironment.h>
#import <MtProtoKit/MTLogging.h>
#import <MtProtoKit/MTDatacenterAuthAction.h>

#import <netinet/in.h>
#import <arpa/inet.h>

@implementation MTDiscoverConnectionSignals

+ (NSData *)payloadData:(MTPayloadData *)outPayloadData context:(MTContext *)context address:(MTDatacenterAddress *)address {
    uint8_t reqPqBytes[] = {
        0, 0, 0, 0, 0, 0, 0, 0, // zero * 8
        0, 0, 0, 0, 0, 0, 0, 0, // message id
        20, 0, 0, 0, // message length
        0xf1, 0x8e, 0x7e, 0xbe, // req_pq_multi
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 // nonce
    };
    
    MTPayloadData payloadData;
    arc4random_buf(&payloadData.nonce, 16);
    if (outPayloadData)
        *outPayloadData = payloadData;
    
    int64_t messageId = (int64_t)([[NSDate date] timeIntervalSince1970] * 4294967296);
    memcpy(reqPqBytes + 8, &messageId, 8);
    
    memcpy(reqPqBytes + 8 + 8 + 4 + 4, payloadData.nonce, 16);
    
    NSMutableData *data = [[NSMutableData alloc] initWithBytes:reqPqBytes length:sizeof(reqPqBytes)];
    
    NSData *secret = address.secret;
    if (context.apiEnvironment.socksProxySettings != nil) {
        if (context.apiEnvironment.socksProxySettings.secret != nil) {
            secret = context.apiEnvironment.socksProxySettings.secret;
        }
    }
    
    bool extendedPadding = false;
    if (secret != nil) {
        MTProxySecret *parsedSecret = [MTProxySecret parseData:secret];
        if ([parsedSecret isKindOfClass:[MTProxySecretType1 class]] || [parsedSecret isKindOfClass:[MTProxySecretType2 class]]) {
            extendedPadding = true;
        }
    }
    
    if (extendedPadding) {
        uint32_t paddingSize = arc4random_uniform(128);
        if (paddingSize != 0) {
            uint8_t padding[128];
            arc4random_buf(padding, paddingSize);
            [data appendBytes:padding length:paddingSize];
        }
    }
    return data;
}

+ (bool)isResponseValid:(NSData *)data payloadData:(MTPayloadData)payloadData {
    if (data.length >= 84) {
        uint8_t zero[] = { 0, 0, 0, 0, 0, 0, 0, 0 };
        uint8_t resPq[] = { 0x63, 0x24, 0x16, 0x05 };
        if (memcmp((uint8_t * const)data.bytes, zero, 8) == 0 && memcmp(((uint8_t * const)data.bytes) + 20, resPq, 4) == 0 && memcmp(((uint8_t * const)data.bytes) + 24, payloadData.nonce, 16) == 0) {
            return true;
        }
    }
    
    return false;
}

+ (bool)isIpv6:(NSString *)ip
{
    const char *utf8 = [ip UTF8String];
    int success;
    
    struct in6_addr dst6;
    success = inet_pton(AF_INET6, utf8, &dst6);
    
    return success == 1;
}

+ (MTSignal *)tcpConnectionWithContext:(MTContext *)context datacenterId:(NSUInteger)datacenterId address:(MTDatacenterAddress *)address;
{
    return [[[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        MTPayloadData payloadData;
        NSData *data = [self payloadData:&payloadData context:context address:address];
        
        MTTcpConnection *connection = [[MTTcpConnection alloc] initWithContext:context datacenterId:datacenterId scheme:[[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:address media:false] interface:nil usageCalculationInfo:nil getLogPrefix:nil];
        __weak MTTcpConnection *weakConnection = connection;
        connection.connectionOpened = ^
        {
            __strong MTTcpConnection *strongConnection = weakConnection;
            if (strongConnection != nil)
                [strongConnection sendDatas:@[data] completion:nil requestQuickAck:false expectDataInResponse:true];
        };
        MTAtomic *processedData = [[MTAtomic alloc] initWithValue:@false];
        connection.connectionReceivedData = ^(NSData *data)
        {
            [processedData swap:@true];
            if ([self isResponseValid:data payloadData:payloadData])
            {
                if (MTLogEnabled()) {
                    MTLog(@"success tcp://%@:%d", address.ip, (int)address.port);
                }
                [subscriber putCompletion];
            }
            else
            {
                if (MTLogEnabled()) {
                    MTLog(@"failed tcp://%@:%d (invalid response)", address.ip, (int)address.port);
                }
                [subscriber putError:nil];
            }
        };
        connection.connectionClosed = ^
        {
            __block bool received = false;
            [processedData with:^id (NSNumber *value) {
                received = [value boolValue];
                return nil;
            }];
            if (!received) {
                if (MTLogEnabled()) {
                    MTLog(@"failed tcp://%@:%d (disconnected)", address.ip, (int)address.port);
                }
                [subscriber putError:nil];
            }
        };
        if (MTLogEnabled()) {
            MTLog(@"trying tcp://%@:%d", address.ip, (int)address.port);
        }
        [connection start];
        
        return [[MTBlockDisposable alloc] initWithBlock:^
        {
            [connection stop];
        }];
    }] startOn:[MTTcpConnection tcpQueue]];
}

+ (MTSignal *)discoverSchemeWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId addressList:(NSArray *)addressList media:(bool)media isProxy:(bool)isProxy
{
    NSMutableArray *bestAddressList = [[NSMutableArray alloc] init];
    
    for (MTDatacenterAddress *address in addressList)
    {
        if (media == address.preferForMedia && isProxy == address.preferForProxy) {
            [bestAddressList addObject:address];
        }
    }
    
    if (bestAddressList.count == 0 && media)
        [bestAddressList addObjectsFromArray:addressList];
    
    NSMutableArray *bestTcp4Signals = [[NSMutableArray alloc] init];
    NSMutableArray *bestTcp6Signals = [[NSMutableArray alloc] init];
    NSMutableArray *bestHttpSignals = [[NSMutableArray alloc] init];
    
    NSMutableDictionary *tcpIpsByPort = [[NSMutableDictionary alloc] init];
    
    for (MTDatacenterAddress *address in bestAddressList) {
        NSMutableSet *ips = tcpIpsByPort[@(address.port)];
        if (ips == nil) {
            ips = [[NSMutableSet alloc] init];
            tcpIpsByPort[@(address.port)] = ips;
        }
        [ips addObject:address.ip];
    }
    
    for (MTDatacenterAddress *address in bestAddressList) {
        MTTransportScheme *tcpTransportScheme = [[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:address media:media];
        
        if ([self isIpv6:address.ip])
        {
            MTSignal *signal = [[[[self tcpConnectionWithContext:context datacenterId:datacenterId address:address] then:[MTSignal single:tcpTransportScheme]] timeout:5.0 onQueue:[MTQueue concurrentDefaultQueue] orSignal:[MTSignal fail:nil]] catch:^MTSignal *(__unused id error)
            {
                return [MTSignal complete];
            }];
            [bestTcp6Signals addObject:signal];
        }
        else
        {
            MTSignal *tcpConnectionWithTimeout = [[[self tcpConnectionWithContext:context datacenterId:datacenterId address:address] then:[MTSignal single:tcpTransportScheme]] timeout:5.0 onQueue:[MTQueue concurrentDefaultQueue] orSignal:[MTSignal fail:nil]];
            MTSignal *signal = [tcpConnectionWithTimeout catch:^MTSignal *(__unused id error)
            {
                return [MTSignal complete];
            }];
            [bestTcp4Signals addObject:signal];
            
            NSArray *alternatePorts = @[@80, @5222];
            for (NSNumber *nPort in alternatePorts) {
                NSSet *ipsWithPort = tcpIpsByPort[nPort];
                if (![ipsWithPort containsObject:address.ip]) {
                    MTDatacenterAddress *portAddress = [[MTDatacenterAddress alloc] initWithIp:address.ip port:[nPort intValue] preferForMedia:address.preferForMedia restrictToTcp:address.restrictToTcp cdn:address.cdn preferForProxy:address.preferForProxy secret:address.secret];
                    MTTransportScheme *tcpPortTransportScheme = [[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:portAddress media:media];
                    MTSignal *tcpConnectionWithTimeout = [[[self tcpConnectionWithContext:context datacenterId:datacenterId address:portAddress] then:[MTSignal single:tcpPortTransportScheme]] timeout:5.0 onQueue:[MTQueue concurrentDefaultQueue] orSignal:[MTSignal fail:nil]];
                    tcpConnectionWithTimeout = [tcpConnectionWithTimeout mapToSignal:^(id next) {
                        return [[MTSignal single:next] delay:5.0 onQueue:[MTQueue concurrentDefaultQueue]];
                    }];
                    MTSignal *signal = [tcpConnectionWithTimeout catch:^MTSignal *(__unused id error) {
                        return [MTSignal complete];
                    }];
                    [bestTcp4Signals addObject:signal];
                }
            }
        }
    }
    
    MTSignal *repeatDelaySignal = [[MTSignal complete] delay:1.0 onQueue:[MTQueue concurrentDefaultQueue]];
    MTSignal *optimalDelaySignal = [[MTSignal complete] delay:30.0 onQueue:[MTQueue concurrentDefaultQueue]];
    
    MTSignal *firstTcp4Match = [[[[MTSignal mergeSignals:bestTcp4Signals] then:repeatDelaySignal] restart] take:1];
    MTSignal *firstTcp6Match = [[[[MTSignal mergeSignals:bestTcp6Signals] then:repeatDelaySignal] restart] take:1];
    MTSignal *firstHttpMatch = [[[[MTSignal mergeSignals:bestHttpSignals] then:repeatDelaySignal] restart] take:1];
    
    MTSignal *optimalTcp4Match = [[[[MTSignal mergeSignals:bestTcp4Signals] then:optimalDelaySignal] restart] take:1];
    MTSignal *optimalTcp6Match = [[[[MTSignal mergeSignals:bestTcp6Signals] then:optimalDelaySignal] restart] take:1];
    
    MTSignal *anySignal = [[MTSignal mergeSignals:@[firstTcp4Match, firstTcp6Match, firstHttpMatch]] take:1];
    MTSignal *optimalSignal = [[MTSignal mergeSignals:@[optimalTcp4Match, optimalTcp6Match]] take:1];
    
    MTSignal *signal = [anySignal mapToSignal:^MTSignal *(MTTransportScheme *scheme)
    {
        if (![scheme isOptimal])
        {
            return [[MTSignal single:scheme] then:[optimalSignal delay:5.0 onQueue:[MTQueue concurrentDefaultQueue]]];
        }
        else
            return [MTSignal single:scheme];
    }];
    
    return [signal catch:^MTSignal *(id error) {
        return [MTSignal complete];
    }];
}

+ (MTSignal * _Nonnull)checkIfAuthKeyRemovedWithContext:(MTContext * _Nonnull)context datacenterId:(NSInteger)datacenterId authKey:(MTDatacenterAuthKey *)authKey {
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        MTMetaDisposable *disposable = [[MTMetaDisposable alloc] init];
        
        [[MTContext contextQueue] dispatchOnQueue:^{
            MTDatacenterAuthAction *action = [[MTDatacenterAuthAction alloc] initWithAuthKeyInfoSelector:MTDatacenterAuthInfoSelectorEphemeralMain isCdn:false skipBind:false completion:^(__unused MTDatacenterAuthAction *action, bool success) {
                [subscriber putNext:@(!success)];
                [subscriber putCompletion];
            }];
            [action execute:context datacenterId:datacenterId];
            
            [disposable setDisposable:[[MTBlockDisposable alloc] initWithBlock:^{
                [action cancel];
            }]];
        }];
        
        return disposable;
    }];
}

@end
