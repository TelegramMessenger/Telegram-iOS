#import "MTDiscoverConnectionSignals.h"

#import "MTTcpConnection.h"
#import "MTHttpWorker.h"

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTTransportScheme.h>
#   import <MTProtoKitDynamic/MTTcpTransport.h>
#   import <MTProtoKitDynamic/MTHttpTransport.h>
#   import <MTProtoKitDynamic/MTQueue.h>
#   import <MTProtoKitDynamic/MTProtoKitDynamic.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTTransportScheme.h>
#   import <MTProtoKitMac/MTTcpTransport.h>
#   import <MTProtoKitMac/MTHttpTransport.h>
#   import <MTProtoKitMac/MTQueue.h>
#   import <MTProtoKitMac/MTProtoKitMac.h>
#else
#   import <MTProtoKit/MTTransportScheme.h>
#   import <MTProtoKit/MTTcpTransport.h>
#   import <MTProtoKit/MTHttpTransport.h>
#   import <MTProtoKit/MTQueue.h>
#   import <MTProtoKit/MTProtoKit.h>
#endif

#import "MTDatacenterAddress.h"

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTDisposable.h>
#   import <MTProtoKitDynamic/MTSignal.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTDisposable.h>
#   import <MTProtoKitMac/MTSignal.h>
#else
#   import <MTProtoKit/MTDisposable.h>
#   import <MTProtoKit/MTSignal.h>
#endif

#import <netinet/in.h>
#import <arpa/inet.h>

typedef struct {
    uint8_t nonce[16];
} MTPayloadData;

@implementation MTDiscoverConnectionSignals

+ (NSData *)payloadData:(MTPayloadData *)outPayloadData;
{
    uint8_t reqPqBytes[] = {
        0, 0, 0, 0, 0, 0, 0, 0, // zero * 8
        0, 0, 0, 0, 0, 0, 0, 0, // message id
        20, 0, 0, 0, // message length
        0x78, 0x97, 0x46, 0x60, // req_pq
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 // nonce
    };
    
    MTPayloadData payloadData;
    arc4random_buf(&payloadData.nonce, 16);
    if (outPayloadData)
        *outPayloadData = payloadData;
    
    arc4random_buf(reqPqBytes + 8, 8);
    memcpy(reqPqBytes + 8 + 8 + 4 + 4, payloadData.nonce, 16);
    
    return [[NSData alloc] initWithBytes:reqPqBytes length:sizeof(reqPqBytes)];
}

+ (bool)isResponseValid:(NSData *)data payloadData:(MTPayloadData)payloadData
{
    if (data.length == 84)
    {
        uint8_t zero[] = { 0, 0, 0, 0, 0, 0, 0, 0 };
        uint8_t length[] = { 0x40, 0, 0, 0 };
        uint8_t resPq[] = { 0x63, 0x24, 0x16, 0x05 };
        if (memcmp((uint8_t * const)data.bytes, zero, 8) == 0 && memcmp(((uint8_t * const)data.bytes) + 16, length, 4) == 0 && memcmp(((uint8_t * const)data.bytes) + 20, resPq, 4) == 0 && memcmp(((uint8_t * const)data.bytes) + 24, payloadData.nonce, 16) == 0)
        {
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
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        MTPayloadData payloadData;
        NSData *data = [self payloadData:&payloadData];
        
        MTTcpConnection *connection = [[MTTcpConnection alloc] initWithContext:context datacenterId:datacenterId address:address interface:nil usageCalculationInfo:nil];
        __weak MTTcpConnection *weakConnection = connection;
        connection.connectionOpened = ^
        {
            __strong MTTcpConnection *strongConnection = weakConnection;
            if (strongConnection != nil)
                [strongConnection sendDatas:@[data] completion:nil requestQuickAck:false expectDataInResponse:true];
        };
        __block bool received = false;
        connection.connectionReceivedData = ^(NSData *data)
        {
            received = true;
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
                    MTLog(@"failed tcp://%@:%d", address.ip, (int)address.port);
                }
                [subscriber putError:nil];
            }
        };
        connection.connectionClosed = ^
        {
            if (!received) {
                if (MTLogEnabled()) {
                    MTLog(@"failed tcp://%@:%d", address.ip, (int)address.port);
                }
            }
            [subscriber putError:nil];
        };
        if (MTLogEnabled()) {
            MTLog(@"trying tcp://%@:%d", address.ip, (int)address.port);
        }
        [connection start];
        
        return [[MTBlockDisposable alloc] initWithBlock:^
        {
            [connection stop];
        }];
    }];
}

+ (MTSignal *)httpConnectionWithAddress:(MTDatacenterAddress *)address
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        MTPayloadData payloadData;
        NSData *data = [self payloadData:&payloadData];
        
        MTHttpWorkerBlockDelegate *delegate = [[MTHttpWorkerBlockDelegate alloc] init];
        
        delegate.completedWithData = ^(NSData *data)
        {
            if ([self isResponseValid:data payloadData:payloadData])
                [subscriber putCompletion];
            else
                [subscriber putError:nil];
        };
        delegate.failed = ^
        {
            [subscriber putError:nil];
        };
        
        if (MTLogEnabled()) {
            MTLog(@"trying http://%@:%d", address.ip, (int)address.port);
        }
        MTHttpWorker *httpWorker = [[MTHttpWorker alloc] initWithDelegate:delegate address:address payloadData:data performsLongPolling:false];
        
        return [[MTBlockDisposable alloc] initWithBlock:^
        {
            [delegate description]; // keep reference
            [httpWorker stop];
        }];
    }];
}

+ (MTSignal *)discoverSchemeWithContext:(MTContext *)context addressList:(NSArray *)addressList media:(bool)media isProxy:(bool)isProxy
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
        MTTransportScheme *httpTransportScheme = [[MTTransportScheme alloc] initWithTransportClass:[MTHttpTransport class] address:address media:media];
        
        if ([self isIpv6:address.ip])
        {
            MTSignal *signal = [[[[self tcpConnectionWithContext:context datacenterId:0 address:address] then:[MTSignal single:tcpTransportScheme]] timeout:5.0 onQueue:[MTQueue concurrentDefaultQueue] orSignal:[MTSignal fail:nil]] catch:^MTSignal *(__unused id error)
            {
                return [MTSignal complete];
            }];
            [bestTcp6Signals addObject:signal];
        }
        else
        {
            MTSignal *tcpConnectionWithTimeout = [[[self tcpConnectionWithContext:context datacenterId:0 address:address] then:[MTSignal single:tcpTransportScheme]] timeout:5.0 onQueue:[MTQueue concurrentDefaultQueue] orSignal:[MTSignal fail:nil]];
            MTSignal *signal = [tcpConnectionWithTimeout catch:^MTSignal *(__unused id error)
            {
                return [MTSignal complete];
            }];
            [bestTcp4Signals addObject:signal];
            
            NSArray *alternatePorts = @[@80, @5222];
            for (NSNumber *nPort in alternatePorts) {
                NSSet *ipsWithPort = tcpIpsByPort[nPort];
                if (![ipsWithPort containsObject:address.ip]) {
                    MTDatacenterAddress *portAddress = [[MTDatacenterAddress alloc] initWithIp:address.ip port:[nPort intValue] preferForMedia:address.preferForMedia restrictToTcp:address.restrictToTcp cdn:address.cdn preferForProxy:address.preferForProxy];
                    MTTransportScheme *tcpPortTransportScheme = [[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:portAddress media:media];
                    MTSignal *tcpConnectionWithTimeout = [[[self tcpConnectionWithContext:context datacenterId:0 address:portAddress] then:[MTSignal single:tcpPortTransportScheme]] timeout:5.0 onQueue:[MTQueue concurrentDefaultQueue] orSignal:[MTSignal fail:nil]];
                    MTSignal *signal = [tcpConnectionWithTimeout catch:^MTSignal *(__unused id error) {
                        return [MTSignal complete];
                    }];
                    [bestTcp4Signals addObject:signal];
                }
            }
        }
        
        if (!address.restrictToTcp && !isProxy) {
            MTSignal *signal = [[[[self httpConnectionWithAddress:address] then:[MTSignal single:httpTransportScheme]] timeout:5.0 onQueue:[MTQueue concurrentDefaultQueue] orSignal:[MTSignal fail:nil]] catch:^MTSignal *(__unused id error)
            {
                return [MTSignal complete];
            }];
            [bestHttpSignals addObject:signal];
            
            if (address.port != 80) {
                MTDatacenterAddress *httpAddress = [[MTDatacenterAddress alloc] initWithIp:address.ip port:80 preferForMedia:address.preferForMedia restrictToTcp:false cdn:address.cdn preferForProxy:address.preferForProxy];
                
                MTTransportScheme *alternateHttpTransportScheme = [[MTTransportScheme alloc] initWithTransportClass:[MTHttpTransport class] address:httpAddress media:media];
                
                [bestHttpSignals addObject:[[[[self httpConnectionWithAddress:httpAddress] then:[MTSignal single:alternateHttpTransportScheme]] timeout:5.0 onQueue:[MTQueue concurrentDefaultQueue] orSignal:[MTSignal fail:nil]] catch:^MTSignal *(__unused id error) {
                    return [MTSignal complete];
                }]];
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
    
    return signal;
}

@end
