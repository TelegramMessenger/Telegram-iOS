/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTDiscoverTransportSchemeAction.h"

#import <MtProtoKit/MTQueue.h>
#import <MtProtoKit/MTTimer.h>
#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTDatacenterAddressSet.h>
#import <MtProtoKit/MTTransportScheme.h>

#import <MtProtoKit/MTTcpTransport.h>
#import <MtProtoKit/MTTcpConnection.h>

#import <MTProtoKit/MTHttpTransport.h>
#import <MTProtoKit/MTHttpWorker.h>
#import <MTProtoKit/MTNetworkAvailability.h>

#import <arpa/inet.h>
#import <ifaddrs.h>
#import <net/if.h>

typedef enum {
    MTDiscoverTransportSchemeActionStatePaused = 0,
    MTDiscoverTransportSchemeActionStatePrimaryDiscovery = 1,
    MTDiscoverTransportSchemeActionStateRefineDiscovery = 2,
} MTDiscoverTransportSchemeActionState;

@interface MTDiscoverTransportSchemeAction () <MTNetworkAvailabilityDelegate, MTContextChangeListener, MTTcpConnectionDelegate, MTHttpWorkerDelegate>
{
    NSInteger _datacenterId;
    __weak MTContext *_context;
    
    MTNetworkAvailability *_networkAvailability;
    
    uint8_t _nonce[16];
    
    MTDatacenterAddressSet *_addressSet;

    MTTimer *_discoveryRestartTimer;
    
    MTTransportScheme *_savedNonOptimalScheme;
    MTTimer *_nonOptimalSchemeApplyTimer;
    
    MTDiscoverTransportSchemeActionState _state;
    NSArray *_currentlyScheduledSchemes;
    NSMutableArray *_activeConnections;
}

@end

@implementation MTDiscoverTransportSchemeAction

+ (MTQueue *)discoverTransportSchemeQueue
{
    static MTQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[MTQueue alloc] initWithName:"org.mtproto.discoverTransportSchemeQueue"];
    });
    return queue;
}

- (instancetype)initWithContext:(MTContext *)context datacenterId:(NSInteger)datacenterId
{
    self = [super init];
    if (self != nil)
    {
        arc4random_buf(_nonce, 16);
        
        _context = context;
        [context addChangeListener:self];
        
        _datacenterId = datacenterId;
        
        _networkAvailability = [[MTNetworkAvailability alloc] initWithDelegate:self];
        
        _activeConnections = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [(MTContext *)_context removeChangeListener:self];
}

- (void)setState:(MTDiscoverTransportSchemeActionState)state
{
    [[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue] dispatchOnQueue:^
    {
        if (_state != state)
        {
            _state = state;
            MTLog(@"[MTDiscoverTransportSchemeAction#%p state %d]", self, (int)_state);
            
            if (_state == MTDiscoverTransportSchemeActionStatePaused)
            {
                [_discoveryRestartTimer invalidate];
                _discoveryRestartTimer = nil;
                
                [_nonOptimalSchemeApplyTimer invalidate];
                _nonOptimalSchemeApplyTimer = nil;
                
                [self _closeActiveConnections];
            }
        }
    }];
}

- (NSArray *)interfaceList
{
    NSMutableArray *list = [[NSMutableArray alloc] init];
    
    struct ifaddrs *addrs = NULL;
    const struct ifaddrs *cursor = NULL;
    
    bool success = getifaddrs(&addrs) == 0;
    if (success)
    {
        cursor = addrs;
        while (cursor != NULL)
        {
            if (cursor->ifa_addr->sa_family == AF_INET && (cursor->ifa_flags & IFF_LOOPBACK) == 0)
            {
                NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
                if (name != nil)
                    [list addObject:name];
            }
            
            cursor = cursor->ifa_next;
        }
        freeifaddrs(addrs);
    }
    
    return list;
}

- (void)networkAvailabilityChanged:(MTNetworkAvailability *)networkAvailability networkIsAvailable:(bool)networkIsAvailable
{
    [[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue] dispatchOnQueue:^
    {
        if (networkIsAvailable)
        {
            if (_state == MTDiscoverTransportSchemeActionStatePrimaryDiscovery || _state == MTDiscoverTransportSchemeActionStateRefineDiscovery)
            {
                [_discoveryRestartTimer invalidate];
                _discoveryRestartTimer = nil;
                
                [_nonOptimalSchemeApplyTimer invalidate];
                _nonOptimalSchemeApplyTimer = nil;
                
                [self _closeActiveConnections];
                
                __weak MTDiscoverTransportSchemeAction *weakSelf = self;
                _discoveryRestartTimer = [[MTTimer alloc] initWithTimeout:10.0 repeat:false completion:^
                {
                    __strong MTDiscoverTransportSchemeAction *strongSelf = weakSelf;
                    [strongSelf _beginDiscoveryWithCurrentlyScheduledSchemes];
                } queue:[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue].nativeQueue];
                [_discoveryRestartTimer start];
            }
        }
    }];
}

- (void)discoverScheme
{
    [self _discoverSchemesInvalidatingOne:nil moreOptimalThan:nil];
}

- (void)discoverMoreOptimalSchemeThan:(MTTransportScheme *)scheme
{
    [self _discoverSchemesInvalidatingOne:nil moreOptimalThan:scheme];
}

- (void)invalidateScheme:(MTTransportScheme *)scheme beginWithHttp:(bool)beginWithHttp
{
    if (scheme == nil)
        return;
    
    [[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue] dispatchOnQueue:^
    {
        MTLog(@"[MTDiscoverTransportSchemeAction#%p externally invalidated scheme %@]", self, scheme);
        
        [self _discoverSchemesInvalidatingOne:scheme moreOptimalThan:nil];
    }];
}

- (void)_discoverSchemesInvalidatingOne:(MTTransportScheme *)scheme moreOptimalThan:(MTTransportScheme *)moreOptimalThanScheme
{
    [[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue] dispatchOnQueue:^
    {
        if (_state == MTDiscoverTransportSchemeActionStatePaused)
        {
            [self setState:moreOptimalThanScheme == nil ? MTDiscoverTransportSchemeActionStatePrimaryDiscovery : MTDiscoverTransportSchemeActionStateRefineDiscovery];
            
            NSArray *schemes = [self _createSchemeListExcludingSchemes:scheme == nil ? @[] : @[scheme] moreOptimalThanScheme:moreOptimalThanScheme];
            if (schemes.count == 0)
                [(MTContext *)_context addressSetForDatacenterWithIdRequired:_datacenterId];
            else
            {
                _currentlyScheduledSchemes = schemes;
                [self _beginDiscoveryWithCurrentlyScheduledSchemes];
            }
        }
        else if (_state == MTDiscoverTransportSchemeActionStatePrimaryDiscovery)
        {
            
        }
        else if (_state == MTDiscoverTransportSchemeActionStateRefineDiscovery)
        {
            
        }
    }];
}
            
- (void)_beginDiscoveryWithCurrentlyScheduledSchemes
{
    if (_currentlyScheduledSchemes.count != 0)
        [self _beginValidatingScheme:_currentlyScheduledSchemes[0]];
}

- (void)validateScheme:(MTTransportScheme *)scheme
{
    if (scheme == nil)
        return;
    
    [[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue] dispatchOnQueue:^
    {
        switch (_state)
        {
            case MTDiscoverTransportSchemeActionStatePaused:
                break;
            case MTDiscoverTransportSchemeActionStatePrimaryDiscovery:
            case MTDiscoverTransportSchemeActionStateRefineDiscovery:
            {
                if ([scheme isOptimal] || (_state == MTDiscoverTransportSchemeActionStatePrimaryDiscovery))
                {
                    MTLog(@"[MTDiscoverTransportSchemeAction#%p externally validated scheme %@]", self, scheme);
                    
                    [_discoveryRestartTimer invalidate];
                    _discoveryRestartTimer = nil;
                    
                    [_nonOptimalSchemeApplyTimer invalidate];
                    _nonOptimalSchemeApplyTimer = nil;
                    
                    [self _closeActiveConnections];
                    
                    if (![scheme isOptimal] && _state == MTDiscoverTransportSchemeActionStatePrimaryDiscovery)
                    {
                        _savedNonOptimalScheme = scheme;
                        [self setState:MTDiscoverTransportSchemeActionStateRefineDiscovery];
                        
                        __weak MTDiscoverTransportSchemeAction *weakSelf = self;
                        _nonOptimalSchemeApplyTimer = [[MTTimer alloc] initWithTimeout:6.0 repeat:false completion:^
                        {
                            __strong MTDiscoverTransportSchemeAction *strongSelf = weakSelf;
                            [strongSelf _applyNonOptimalScheme];
                        } queue:[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue].nativeQueue];
                        [_nonOptimalSchemeApplyTimer start];
                        
                        _currentlyScheduledSchemes = [self _createSchemeListExcludingSchemes:@[] moreOptimalThanScheme:scheme];
                    }
                    else
                    {
                        [self setState:MTDiscoverTransportSchemeActionStatePaused];
                        
                        [(MTContext *)_context updateTransportSchemeForDatacenterWithId:_datacenterId transportScheme:scheme];
                    }
                }
                
                break;
            }
            default:
                break;
        }
    }];
}

- (void)contextDatacenterAddressSetUpdated:(MTContext *)__unused context datacenterId:(NSInteger)datacenterId addressSet:(MTDatacenterAddressSet *)addressSet
{
    [[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue] dispatchOnQueue:^
    {
        if (datacenterId == _datacenterId)
        {
            if (_state == MTDiscoverTransportSchemeActionStatePaused)
            {
            }
            else if (_state == MTDiscoverTransportSchemeActionStatePrimaryDiscovery || _state == MTDiscoverTransportSchemeActionStateRefineDiscovery)
            {
                NSMutableArray *schemes = [[NSMutableArray alloc] initWithArray:[self _createSchemeListExcludingSchemes:@[] moreOptimalThanScheme:_state == MTDiscoverTransportSchemeActionStateRefineDiscovery ? _savedNonOptimalScheme : nil]];
                
                bool schemesUpdated = schemes.count != _currentlyScheduledSchemes.count;
                
                if (!schemesUpdated)
                {
                    for (MTTransportScheme *scheme in _currentlyScheduledSchemes)
                    {
                        if ([schemes indexOfObject:scheme] == NSNotFound)
                        {
                            schemesUpdated = true;
                            break;
                        }
                    }
                    
                    for (MTTransportScheme *scheme in schemes)
                    {
                        if ([_currentlyScheduledSchemes indexOfObject:scheme] == NSNotFound)
                        {
                            schemesUpdated = true;
                            break;
                        }
                    }
                }
                
                if (schemesUpdated)
                {
                    bool beginDiscovery = _currentlyScheduledSchemes.count == 0;
                    _currentlyScheduledSchemes = schemes;
                    
                    MTLog(@"[MTDiscoverTransportSchemeAction#%p address set updated, restarting with %d schemes]", self, schemes.count);
                    
                    if (beginDiscovery && _currentlyScheduledSchemes.count != 0)
                    {
                        [(MTContext *)_context updateTransportSchemeForDatacenterWithId:_datacenterId transportScheme:_currentlyScheduledSchemes[0]];
                        
                        [self _beginDiscoveryWithCurrentlyScheduledSchemes];
                    }
                }
            }
        }
    }];
}

- (NSArray *)_createSchemeListExcludingSchemes:(NSArray *)excludedSchemes moreOptimalThanScheme:(MTTransportScheme *)upperBoundScheme
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    for (MTDatacenterAddress *address in [(MTContext *)_context addressSetForDatacenterWithId:_datacenterId].addressList)
    {
        MTDatacenterAddress *actualAddress = address;
        
        MTTransportScheme *scheme = [[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:actualAddress];
        if (![excludedSchemes containsObject:scheme] && (upperBoundScheme == nil || [scheme compareToScheme:upperBoundScheme] == NSOrderedAscending))
            [array addObject:scheme];
    }
    
    NSMutableArray *httpAddresses = [[NSMutableArray alloc] init];
    for (MTDatacenterAddress *address in [(MTContext *)_context addressSetForDatacenterWithId:_datacenterId].addressList)
    {
        MTDatacenterAddress *actualAddress = [[MTDatacenterAddress alloc] initWithIp:address.ip port:80];
        if (![httpAddresses containsObject:actualAddress])
        {
            [httpAddresses addObject:httpAddresses];
            
            MTTransportScheme *scheme = [[MTTransportScheme alloc] initWithTransportClass:[MTHttpTransport class] address:actualAddress];
            
            if (![excludedSchemes containsObject:scheme] && (upperBoundScheme == nil || [scheme compareToScheme:upperBoundScheme] == NSOrderedAscending))
                [array addObject:scheme];
        }
    }
    
    return array;
}

- (void)_beginValidatingScheme:(MTTransportScheme *)scheme
{
    MTLog(@"[MTDiscoverTransportSchemeAction#%p trying %@]", self, scheme);
    
    if ([scheme.transportClass isEqual:[MTTcpTransport class]])
    {
        MTTcpConnection *connection = [[MTTcpConnection alloc] initWithAddress:scheme.address interface:nil];
        connection.delegate = self;
        
        [_activeConnections addObject:@{
            @"connection": connection,
            @"scheme": scheme
        }];
        
        [connection start];
    }
    else if ([scheme.transportClass isEqual:[MTHttpTransport class]])
    {
        MTHttpWorker *worker = [[MTHttpWorker alloc] initWithDelegate:self address:scheme.address payloadData:[self payloadData] performsLongPolling:false];
        
        [_activeConnections addObject:@{
            @"connection": worker,
            @"scheme": scheme
        }];
    }
}

- (NSDictionary *)_connectionContext:(id)connection
{
    if (connection == nil)
        return nil;
    
    for (NSDictionary *dict in _activeConnections)
    {
        if (dict[@"connection"] == connection)
            return dict;
    }
    
    return nil;
}

- (void)_removeActiveConnection:(id)connection
{
    if (connection == nil)
        return;
    
    int index = -1;
    for (NSDictionary *dict in _activeConnections)
    {
        index++;
        
        if (dict[@"connection"] == connection)
        {
            [_activeConnections removeObjectAtIndex:(NSUInteger)index];
            
            break;
        }
    }
}

- (NSData *)payloadData
{
    uint8_t reqPqBytes[] = {
        0, 0, 0, 0, 0, 0, 0, 0, // zero * 8
        0, 0, 0, 0, 0, 0, 0, 0, // message id
        20, 0, 0, 0, // message length
        0x78, 0x97, 0x46, 0x60, // req_pq
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 // nonce
    };
    
    arc4random_buf(reqPqBytes + 8, 8);
    memcpy(reqPqBytes + 8 + 8 + 4 + 4, _nonce, 16);
    
    return [[NSData alloc] initWithBytes:reqPqBytes length:sizeof(reqPqBytes)];
}

- (bool)isResponseValid:(NSData *)data
{
    if (data.length == 84)
    {
        uint8_t zero[] = { 0, 0, 0, 0, 0, 0, 0, 0 };
        uint8_t length[] = { 0x40, 0, 0, 0 };
        uint8_t resPq[] = { 0x63, 0x24, 0x16, 0x05 };
        if (memcmp((uint8_t * const)data.bytes, zero, 8) == 0 && memcmp(((uint8_t * const)data.bytes) + 16, length, 4) == 0 && memcmp(((uint8_t * const)data.bytes) + 20, resPq, 4) == 0 && memcmp(((uint8_t * const)data.bytes) + 24, _nonce, 16) == 0)
        {
            return true;
        }
    }
    
    return false;
}

- (void)tcpConnectionOpened:(MTTcpConnection *)connection
{
    [[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue] dispatchOnQueue:^
    {
        if ([self _connectionContext:connection] == nil)
            return;
        
        [connection sendDatas:@[[self payloadData]] completion:nil requestQuickAck:false expectDataInResponse:true];
    }];
}

- (void)tcpConnectionClosed:(MTTcpConnection *)connection
{
    [[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue] dispatchOnQueue:^
    {
        NSDictionary *connectionContext = [self _connectionContext:connection];
        if (connectionContext == nil)
            return;
        
        connection.delegate = nil;
        [self _removeActiveConnection:connection];
        
        MTLog(@"[MTDiscoverTransportSchemeAction#%p scheme failed: %@]", self, connectionContext[@"scheme"]);
        
        [self _schemeValidationCompleted:connectionContext[@"scheme"] success:false];
    }];
}

- (void)tcpConnectionReceivedData:(MTTcpConnection *)connection data:(NSData *)data
{
    [[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue] dispatchOnQueue:^
    {
        NSDictionary *connectionContext = [self _connectionContext:connection];
        if (connectionContext == nil)
            return;
        
        bool success = [self isResponseValid:data];
        
        connection.delegate = nil;
        [self _removeActiveConnection:connection];
        
        if (success)
            MTLog(@"[MTDiscoverTransportSchemeAction#%p scheme success: %@]", self, connectionContext[@"scheme"]);
        else
            MTLog(@"[MTDiscoverTransportSchemeAction#%p scheme failed: %@]", self, connectionContext[@"scheme"]);
        
        [self _schemeValidationCompleted:connectionContext[@"scheme"] success:success];
    }];
}

- (void)httpWorkerFailed:(MTHttpWorker *)httpWorker
{
    [[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue] dispatchOnQueue:^
    {
        NSDictionary *connectionContext = [self _connectionContext:httpWorker];
        if (connectionContext == nil)
            return;
        
        httpWorker.delegate = nil;
        [self _removeActiveConnection:httpWorker];
        
        MTLog(@"[MTDiscoverTransportSchemeAction#%p scheme failed: %@]", self, connectionContext[@"scheme"]);
        
        [self _schemeValidationCompleted:connectionContext[@"scheme"] success:false];
    }];
}

- (void)httpWorker:(MTHttpWorker *)httpWorker completedWithData:(NSData *)data
{
    [[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue] dispatchOnQueue:^
    {
        NSDictionary *connectionContext = [self _connectionContext:httpWorker];
        if (connectionContext == nil)
            return;
        
        bool success = [self isResponseValid:data];
        
        httpWorker.delegate = nil;
        [self _removeActiveConnection:httpWorker];
        
        if (success)
            MTLog(@"[MTDiscoverTransportSchemeAction#%p scheme success: %@]", self, connectionContext[@"scheme"]);
        else
            MTLog(@"[MTDiscoverTransportSchemeAction#%p scheme failed: %@]", self, connectionContext[@"scheme"]);
        
        [self _schemeValidationCompleted:connectionContext[@"scheme"] success:success];
    }];
}

- (void)_schemeValidationCompleted:(MTTransportScheme *)scheme success:(bool)success
{
    [[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue] dispatchOnQueue:^
    {
        if (_state == MTDiscoverTransportSchemeActionStatePrimaryDiscovery || _state == MTDiscoverTransportSchemeActionStateRefineDiscovery)
        {
            if (success)
            {
                if (_state == MTDiscoverTransportSchemeActionStateRefineDiscovery || [scheme isOptimal])
                {
                    [self setState:MTDiscoverTransportSchemeActionStatePaused];
                    
                    [(MTContext *)_context updateTransportSchemeForDatacenterWithId:_datacenterId transportScheme:scheme];
                }
                else
                {
                    _savedNonOptimalScheme = scheme;
                    
                    [self setState:MTDiscoverTransportSchemeActionStateRefineDiscovery];
                    
                    __weak MTDiscoverTransportSchemeAction *weakSelf = self;
                    _nonOptimalSchemeApplyTimer = [[MTTimer alloc] initWithTimeout:6.0 repeat:false completion:^
                    {
                        __strong MTDiscoverTransportSchemeAction *strongSelf = weakSelf;
                        [strongSelf _applyNonOptimalScheme];
                    } queue:[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue].nativeQueue];
                    [_nonOptimalSchemeApplyTimer start];
                    
                    _currentlyScheduledSchemes = [self _createSchemeListExcludingSchemes:@[] moreOptimalThanScheme:scheme];
                    [self _beginDiscoveryWithCurrentlyScheduledSchemes];
                }
            }
            else
            {
                NSUInteger index = [_currentlyScheduledSchemes indexOfObject:scheme];
                if (index != NSNotFound)
                {
                    if (index + 1 == _currentlyScheduledSchemes.count)
                    {
                        [_discoveryRestartTimer invalidate];
                        
                        NSTimeInterval retryTimeout = _state == MTDiscoverTransportSchemeActionStateRefineDiscovery ? 30.0 : 2.0;
                        
                        __weak MTDiscoverTransportSchemeAction *weakSelf = self;
                        _discoveryRestartTimer = [[MTTimer alloc] initWithTimeout:retryTimeout repeat:false completion:^
                        {
                            __strong MTDiscoverTransportSchemeAction *strongSelf = weakSelf;
                            [strongSelf _beginDiscoveryWithCurrentlyScheduledSchemes];
                        } queue:[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue].nativeQueue];
                        [_discoveryRestartTimer start];
                    }
                    else
                        [self _beginValidatingScheme:_currentlyScheduledSchemes[index + 1]];
                }
                else
                {
                    MTLog(@"[MTDiscoverTransportSchemeAction#%p validated scheme %@ was not found in current list]", self, scheme);
                    
                    [self _closeActiveConnections];
                    [self setState:MTDiscoverTransportSchemeActionStatePaused];
                }
            }
        }
    }];
}

- (void)_applyNonOptimalScheme
{
    [[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue] dispatchOnQueue:^
    {
        if (_state == MTDiscoverTransportSchemeActionStateRefineDiscovery && _savedNonOptimalScheme != nil)
        {
            [(MTContext *)_context updateTransportSchemeForDatacenterWithId:_datacenterId transportScheme:_savedNonOptimalScheme];
        }
    }];
}

- (void)_closeActiveConnections
{
    [[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue] dispatchOnQueue:^
    {
        if (_activeConnections.count != 0)
            MTLog(@"[MTDiscoverTransportSchemeAction#%p forcing %d connections to close]", self, (int)_activeConnections.count);
        
        NSArray *activeConnections = [_activeConnections copy];
        [_activeConnections removeAllObjects];
        
        for (NSDictionary *dict in activeConnections)
        {
            id connection = dict[@"connection"];
            if ([connection isKindOfClass:[MTTcpConnection class]])
            {
                MTTcpConnection *tcpConnection = connection;
                tcpConnection.delegate = nil;
                [tcpConnection stop];
            }
            else if ([connection isKindOfClass:[MTHttpWorker class]])
            {
                MTHttpWorker *httpWorker = connection;
                httpWorker.delegate = nil;
                [httpWorker stop];
            }
        }
    }];
}

- (void)cancel
{
    [[MTDiscoverTransportSchemeAction discoverTransportSchemeQueue] dispatchOnQueue:^
    {
        [_discoveryRestartTimer invalidate];
        _discoveryRestartTimer = nil;
        
        [_nonOptimalSchemeApplyTimer invalidate];
        _nonOptimalSchemeApplyTimer = nil;
        
        [self _closeActiveConnections];
    }];
}

@end
