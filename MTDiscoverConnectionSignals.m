#import "MTDiscoverConnectionSignals.h"

#import "MTTcpConnection.h"
#import "MTHttpWorker.h"
#import "MTTransportScheme.h"
#import "MTTcpTransport.h"
#import "MTHttpTransport.h"

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

+ (SSignal *)tcpConnectionWithAddress:(MTDatacenterAddress *)address;
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        MTPayloadData payloadData;
        NSData *data = [self payloadData:&payloadData];
        
        MTTcpConnection *connection = [[MTTcpConnection alloc] initWithAddress:address interface:nil];
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
                MTLog(@"success tcp://%@:%d", address.ip, (int)address.port);
                [subscriber putCompletion];
            }
            else
            {
                MTLog(@"failed tcp://%@:%d", address.ip, (int)address.port);
                [subscriber putError:nil];
            }
        };
        connection.connectionClosed = ^
        {
            if (!received)
                MTLog(@"failed tcp://%@:%d", address.ip, (int)address.port);
            [subscriber putError:nil];
        };
        MTLog(@"trying tcp://%@:%d", address.ip, (int)address.port);
        [connection start];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [connection stop];
        }];
    }];
}

+ (SSignal *)httpConnectionWithAddress:(MTDatacenterAddress *)address
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
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
        
        MTLog(@"trying http://%@:%d", address.ip, (int)address.port);
        MTHttpWorker *httpWorker = [[MTHttpWorker alloc] initWithDelegate:delegate address:address payloadData:data performsLongPolling:false];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [delegate description]; // keep reference
            [httpWorker stop];
        }];
    }];
}

+ (SSignal *)discoverSchemeWithContext:(MTContext *)context addressList:(NSArray *)addressList media:(bool)media
{
    NSMutableArray *bestAddressList = [[NSMutableArray alloc] init];
    
    for (MTDatacenterAddress *address in addressList)
    {
        if (media == address.preferForMedia)
            [bestAddressList addObject:address];
    }
    
    if (bestAddressList.count == 0 && media)
        [bestAddressList addObjectsFromArray:addressList];
    
    NSMutableArray *bestTcp4Signals = [[NSMutableArray alloc] init];
    NSMutableArray *bestTcp6Signals = [[NSMutableArray alloc] init];
    NSMutableArray *bestHttpSignals = [[NSMutableArray alloc] init];
    
    for (MTDatacenterAddress *address in bestAddressList)
    {
        MTTransportScheme *tcpTransportScheme = [[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:address media:media];
        MTTransportScheme *httpTransportScheme = [[MTTransportScheme alloc] initWithTransportClass:[MTHttpTransport class] address:address media:media];
        
        if ([self isIpv6:address.ip])
        {
            SSignal *signal = [[[[self tcpConnectionWithAddress:address] then:[SSignal single:tcpTransportScheme]] timeout:5.0 onQueue:[SQueue concurrentDefaultQueue] orSignal:[SSignal fail:nil]] catch:^SSignal *(__unused id error)
            {
                return [SSignal complete];
            }];
            [bestTcp6Signals addObject:signal];
        }
        else
        {
            SSignal *tcpConnectionWithTimeout = [[[self tcpConnectionWithAddress:address] then:[SSignal single:tcpTransportScheme]] timeout:5.0 onQueue:[SQueue concurrentDefaultQueue] orSignal:[SSignal fail:nil]];
            SSignal *signal = [tcpConnectionWithTimeout catch:^SSignal *(__unused id error)
            {
                return [SSignal complete];
            }];
            [bestTcp4Signals addObject:signal];
        }
        
        SSignal *signal = [[[[self httpConnectionWithAddress:address] then:[SSignal single:httpTransportScheme]] timeout:5.0 onQueue:[SQueue concurrentDefaultQueue] orSignal:[SSignal fail:nil]] catch:^SSignal *(__unused id error)
        {
            return [SSignal complete];
        }];
        [bestHttpSignals addObject:signal];
    }
    
    SSignal *repeatDelaySignal = [[SSignal complete] delay:1.0 onQueue:[SQueue concurrentDefaultQueue]];
    SSignal *optimalDelaySignal = [[SSignal complete] delay:30.0 onQueue:[SQueue concurrentDefaultQueue]];
    
    SSignal *firstTcp4Match = [[[[SSignal mergeSignals:bestTcp4Signals] then:repeatDelaySignal] restart] take:1];
    SSignal *firstTcp6Match = [[[[SSignal mergeSignals:bestTcp6Signals] then:repeatDelaySignal] restart] take:1];
    SSignal *firstHttpMatch = [[[[SSignal mergeSignals:bestHttpSignals] then:repeatDelaySignal] restart] take:1];
    
    SSignal *optimalTcp4Match = [[[[SSignal mergeSignals:bestTcp4Signals] then:optimalDelaySignal] restart] take:1];
    SSignal *optimalTcp6Match = [[[[SSignal mergeSignals:bestTcp6Signals] then:optimalDelaySignal] restart] take:1];
    
    SSignal *anySignal = [[SSignal mergeSignals:@[firstTcp4Match, firstTcp6Match, firstHttpMatch]] take:1];
    SSignal *optimalSignal = [[SSignal mergeSignals:@[optimalTcp4Match, optimalTcp6Match]] take:1];
    
    SSignal *signal = [anySignal mapToSignal:^SSignal *(MTTransportScheme *scheme)
    {
        if (![scheme isOptimal])
        {
            return [[SSignal single:scheme] then:[optimalSignal delay:5.0 onQueue:[SQueue concurrentDefaultQueue]]];
        }
        else
            return [SSignal single:scheme];
    }];
    
    return signal;
}

@end
