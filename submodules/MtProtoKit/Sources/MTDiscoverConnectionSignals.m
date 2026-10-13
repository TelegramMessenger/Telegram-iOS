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
#import "MTInternalInterfaces.h"

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

+ (NSArray<MTDatacenterAddress *> *)probeAddressesForAddressList:(NSArray *)addressList media:(bool)media isProxy:(bool)isProxy proxySettings:(MTSocksProxySettings *)proxySettings
{
    // `isProxy` keeps the existing preferForProxy filter contract and `proxySettings`
    // decides the collapse below; every caller derives the former from the latter
    // (`socksProxySettings != nil`), and they must agree.
    NSMutableArray *bestAddressList = [[NSMutableArray alloc] init];

    for (MTDatacenterAddress *address in addressList)
    {
        if (media == address.preferForMedia && isProxy == address.preferForProxy) {
            [bestAddressList addObject:address];
        }
    }

    if (bestAddressList.count == 0) {
        // Nothing matched both preferences. A datacenter whose config carries no `static`
        // (proxy-preferred) address hits this with a proxy on, and the list used to stay
        // empty: zero probes, so discovery ticked on its retry timer forever and never
        // produced a scheme. MTProto still had schemes to dial (the transport uses every
        // non-media address regardless of the proxy flag), so this was not the outage; the
        // cost is that with an alive SOCKS proxy the datacenter never converged on a
        // probed, known-good address, and the gain of probing here is that trade against
        // one (MTProxy) or a few (SOCKS5) probe connections per backoff round through a
        // proxy that may itself be down.
        //
        // Relax in two stages. First drop only the proxy preference and keep the media
        // match: the scheme this produces keeps the probed address, and
        // transportSchemesForDatacenterWithId discards a media-only address for a
        // non-media connection (and MTTcpConnection derives the MTProxy datacenter tag
        // from it), so a media address winning a non-media probe would be discovery
        // succeeding with nothing usable.
        for (MTDatacenterAddress *address in addressList) {
            if (media == address.preferForMedia) {
                [bestAddressList addObject:address];
            }
        }
    }
    if (bestAddressList.count == 0) {
        // Second stage, the whole list. This is the fallback media discovery always had.
        [bestAddressList addObjectsFromArray:addressList];
    }

    if (proxySettings != nil && (proxySettings.secret != nil || proxySettings.webProxy)) {
        // An MTProxy chooses the datacenter from the obfuscated header and a WEB relay
        // ignores the address it is handed, so every probe through either lands in the
        // same place: N of them carry exactly the information of one, and each one is a
        // connection opened through the proxy. When the proxy is unreachable that fan-out
        // (addresses x ports, every round) was most of the retry storm the notification
        // extension produced (bugs.telegram.org/c/64534). Probe a single address, IPv4
        // first because IPv6 reachability is not otherwise known here.
        MTDatacenterAddress *chosen = nil;
        for (MTDatacenterAddress *address in bestAddressList) {
            if (![self isIpv6:address.ip]) {
                chosen = address;
                break;
            }
        }
        if (chosen == nil) {
            chosen = bestAddressList.firstObject;
        }
        return chosen == nil ? @[] : @[chosen];
    }

    return bestAddressList;
}

+ (NSArray<NSNumber *> *)alternatePortsForProxySettings:(MTSocksProxySettings *)proxySettings
{
    // Ports 80 and 5222 exist to get past local port filtering. A proxy already does that,
    // and through one they only triple the connections each discovery round opens.
    if (proxySettings != nil) {
        return @[];
    }
    return @[@80, @5222];
}

+ (void)_startBackoffRoundOf:(MTSignal *)signal delay:(NSTimeInterval)delay maxDelay:(NSTimeInterval)maxDelay queue:(MTQueue *)queue subscriber:(MTSubscriber *)subscriber currentDisposable:(MTMetaDisposable *)currentDisposable isDisposed:(MTAtomic *)isDisposed
{
    if ([[isDisposed value] boolValue]) {
        return;
    }
    NSTimeInterval nextDelay = MIN(delay * 2.0, maxDelay);
    MTSignal *round = [signal then:[[MTSignal complete] delay:delay onQueue:queue]];
    // The recursion happens from the delay timer's completion, so it never grows the stack,
    // and `currentDisposable` disposes immediately if the outer subscription went away in
    // between (MTMetaDisposable keeps its disposed state).
    [currentDisposable setDisposable:[round startWithNext:^(id next) {
        [subscriber putNext:next];
    } error:^(id error) {
        [subscriber putError:error];
    } completed:^{
        [self _startBackoffRoundOf:signal delay:nextDelay maxDelay:maxDelay queue:queue subscriber:subscriber currentDisposable:currentDisposable isDisposed:isDisposed];
    }]];
}

+ (MTSignal *)repeatSignal:(MTSignal *)signal withBackoffFrom:(NSTimeInterval)initialDelay upTo:(NSTimeInterval)maxDelay onQueue:(MTQueue *)queue
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber) {
        MTAtomic *isDisposed = [[MTAtomic alloc] initWithValue:@false];
        MTMetaDisposable *currentDisposable = [[MTMetaDisposable alloc] init];
        [self _startBackoffRoundOf:signal delay:initialDelay maxDelay:maxDelay queue:queue subscriber:subscriber currentDisposable:currentDisposable isDisposed:isDisposed];
        return [[MTBlockDisposable alloc] initWithBlock:^{
            [isDisposed swap:@true];
            [currentDisposable dispose];
        }];
    }];
}

+ (MTSignal *)discoverSchemeWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId addressList:(NSArray *)addressList media:(bool)media isProxy:(bool)isProxy
{
    MTSocksProxySettings *proxySettings = context.apiEnvironment.socksProxySettings;
    NSArray<MTDatacenterAddress *> *bestAddressList = [self probeAddressesForAddressList:addressList media:media isProxy:isProxy proxySettings:proxySettings];
    NSArray<NSNumber *> *alternatePorts = [self alternatePortsForProxySettings:proxySettings];

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
    
    // A round that finds nothing used to be retried after a fixed second, forever. While
    // the network (or the proxy) is down that is a probe per address per ~6 s with no end,
    // so the pause between rounds now doubles from 1 s up to 15 s. Each discovery is a
    // fresh signal, so the backoff resets whenever discovery is restarted.
    MTQueue *retryQueue = [MTQueue concurrentDefaultQueue];
    NSTimeInterval const initialRetryDelay = 1.0;
    NSTimeInterval const maxRetryDelay = 15.0;
    MTSignal *optimalDelaySignal = [[MTSignal complete] delay:30.0 onQueue:[MTQueue concurrentDefaultQueue]];

    MTSignal *firstTcp4Match = [[self repeatSignal:[MTSignal mergeSignals:bestTcp4Signals] withBackoffFrom:initialRetryDelay upTo:maxRetryDelay onQueue:retryQueue] take:1];
    MTSignal *firstTcp6Match = [[self repeatSignal:[MTSignal mergeSignals:bestTcp6Signals] withBackoffFrom:initialRetryDelay upTo:maxRetryDelay onQueue:retryQueue] take:1];
    MTSignal *firstHttpMatch = [[self repeatSignal:[MTSignal mergeSignals:bestHttpSignals] withBackoffFrom:initialRetryDelay upTo:maxRetryDelay onQueue:retryQueue] take:1];
    
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
            MTDatacenterAuthAction *action = [context makeAuthActionWithSelector:MTDatacenterAuthInfoSelectorEphemeralMain isCdn:false skipBind:false completion:^(MTDatacenterAuthAction *action, bool success) {
                // Only ENCRYPTED_MESSAGE_INVALID means the server no longer knows
                // the permanent key. Any other failed bind (a 500, a dropped
                // connection) says nothing about it, and reporting it would log
                // the user out.
                [subscriber putNext:@(!success && [MTDatacenterAuthAction bindErrorMeansPermanentKeyIsUnknown:action.bindError])];
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
