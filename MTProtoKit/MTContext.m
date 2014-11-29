/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTContext.h>

#import <inttypes.h>

#import <MTProtoKit/MTTimer.h>

#import <MTProtoKit/MTQueue.h>
#import <MTProtoKit/MTKeychain.h>

#import <MTProtoKit/MTDatacenterAddressSet.h>
#import <MTProtoKit/MTDatacenterAuthInfo.h>
#import <MTProtoKit/MTDatacenterSaltInfo.h>
#import <MTProtoKit/MTSessionInfo.h>

#import <MTProtoKit/MTDiscoverDatacenterAddressAction.h>
#import <MtProtoKit/MTDiscoverTransportSchemeAction.h>
#import <MTProtoKit/MTDatacenterAuthAction.h>
#import <MTProtoKit/MTDatacenterTransferAuthAction.h>

#import <MTProtoKit/MTTransportScheme.h>
#import <MTProtoKit/MTTcpTransport.h>

#import <libkern/OSAtomic.h>

@implementation MTContextBlockChangeListener

- (void)contextIsPasswordRequiredUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId
{
    if (_contextIsPasswordRequiredUpdated)
        _contextIsPasswordRequiredUpdated(context, datacenterId);
}

@end

@interface MTContext () <MTDiscoverDatacenterAddressActionDelegate, MTDiscoverTransportSchemeActionDelegate, MTDatacenterAuthActionDelegate, MTDatacenterTransferAuthActionDelegate>
{
    int64_t _uniqueId;
    
    NSTimeInterval _globalTimeDifference;
    
    NSMutableDictionary *_datacenterSeedAddressSetById;
    
    NSMutableDictionary *_datacenterAddressSetById;
    NSMutableDictionary *_datacenterTransportSchemeById;
    NSMutableDictionary *_datacenterAuthInfoById;
    
    NSMutableDictionary *_authTokenById;
    
    NSMutableArray *_changeListeners;
    
    NSMutableDictionary *_discoverDatacenterAddressActions;
    NSMutableDictionary *_discoverDatacenterTransportSchemeActions;
    NSMutableDictionary *_datacenterAuthActions;
    NSMutableDictionary *_datacenterTransferAuthActions;
    
    NSMutableDictionary *_cleanupSessionIdsByAuthKeyId;
    NSMutableArray *_currentSessionInfos;
    
    NSMutableDictionary *_periodicTasksTimerByDatacenterId;
    
    volatile OSSpinLock _passwordEntryRequiredLock;
    NSMutableDictionary *_passwordRequiredByDatacenterId;
}

@end

@implementation MTContext

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        NSAssert(false, @"use initWithSerialization:apiEnvironment:");
    }
    return self;
}

- (instancetype)initWithSerialization:(id<MTSerialization>)serialization apiEnvironment:(MTApiEnvironment *)apiEnvironment
{
#ifdef DEBUG
    NSAssert(serialization != nil, @"serialization should not be nil");
    NSAssert(apiEnvironment != nil, @"apiEnvironment should not be nil");
#endif
    
    self = [super init];
    if (self != nil)
    {
        arc4random_buf(&_uniqueId, sizeof(_uniqueId));
        
        _serialization = serialization;
        _apiEnvironment = apiEnvironment;
        
        _datacenterSeedAddressSetById = [[NSMutableDictionary alloc] init];
        
        _datacenterAddressSetById = [[NSMutableDictionary alloc] init];
        _datacenterTransportSchemeById = [[NSMutableDictionary alloc] init];
        _datacenterAuthInfoById = [[NSMutableDictionary alloc] init];
        
        _authTokenById = [[NSMutableDictionary alloc] init];
        
        _changeListeners = [[NSMutableArray alloc] init];
        
        _discoverDatacenterAddressActions = [[NSMutableDictionary alloc] init];
        _discoverDatacenterTransportSchemeActions = [[NSMutableDictionary alloc] init];
        _datacenterAuthActions = [[NSMutableDictionary alloc] init];
        _datacenterTransferAuthActions = [[NSMutableDictionary alloc] init];
        
        _cleanupSessionIdsByAuthKeyId = [[NSMutableDictionary alloc] init];
        _currentSessionInfos = [[NSMutableArray alloc] init];
        
        _passwordRequiredByDatacenterId = [[NSMutableDictionary alloc] init];
        
        [self updatePeriodicTasks];
    }
    return self;
}

- (void)dealloc
{
    [self cleanup];
}

+ (MTQueue *)contextQueue
{
    static MTQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[MTQueue alloc] initWithName:"com.mtproto.MTContextQueue"];
    });
    return queue;
}

- (void)cleanup
{
    NSDictionary *datacenterAuthActions = _datacenterAuthActions;
    _datacenterAuthActions = nil;
    
    NSDictionary *discoverDatacenterAddressActions = _discoverDatacenterAddressActions;
    _discoverDatacenterAddressActions = nil;
    
    NSDictionary *discoverDatacenterTransportSchemeActions = _discoverDatacenterTransportSchemeActions;
    _discoverDatacenterTransportSchemeActions = nil;
    
    NSDictionary *datacenterTransferAuthActions = _datacenterTransferAuthActions;
    _datacenterTransferAuthActions = nil;
    
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        for (NSNumber *nDatacenterId in discoverDatacenterAddressActions)
        {
            MTDiscoverDatacenterAddressAction *action = discoverDatacenterAddressActions[nDatacenterId];
            action.delegate = nil;
            [action cancel];
        }
        
        for (NSNumber *nDatacenterId in discoverDatacenterTransportSchemeActions)
        {
            MTDiscoverTransportSchemeAction *action = discoverDatacenterTransportSchemeActions[nDatacenterId];
            action.delegate = nil;
            [action cancel];
        }

        for (NSNumber *nDatacenterId in datacenterAuthActions)
        {
            MTDatacenterAuthAction *action = datacenterAuthActions[nDatacenterId];
            action.delegate = nil;
            [action cancel];
        }
        
        for (NSNumber *nDatacenterId in datacenterTransferAuthActions)
        {
            MTDatacenterTransferAuthAction *action = datacenterTransferAuthActions[nDatacenterId];
            action.delegate = nil;
            [action cancel];
        }
    }];
}

- (void)performBatchUpdates:(void (^)())block
{
    if (block != nil)
        [[MTContext contextQueue] dispatchOnQueue:block];
}

- (void)setKeychain:(MTKeychain *)keychain
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        _keychain = keychain;
        
        if (_keychain != nil)
        {
            NSNumber *nGlobalTimeDifference = [keychain objectForKey:@"globalTimeDifference" group:@"temp"];
            if (nGlobalTimeDifference != nil)
                _globalTimeDifference = [nGlobalTimeDifference doubleValue];
            
            NSDictionary *datacenterAddressSetById = [keychain objectForKey:@"datacenterAddressSetById" group:@"persistent"];
            if (datacenterAddressSetById != nil)
                _datacenterAddressSetById = [[NSMutableDictionary alloc] initWithDictionary:datacenterAddressSetById];
            
            NSDictionary *datacenterTransportSchemeById = [keychain objectForKey:@"datacenterTransportSchemeById" group:@"persistent"];
            if (datacenterTransportSchemeById != nil)
                _datacenterTransportSchemeById = [[NSMutableDictionary alloc] initWithDictionary:datacenterTransportSchemeById];
            
            NSDictionary *datacenterAuthInfoById = [keychain objectForKey:@"datacenterAuthInfoById" group:@"persistent"];
            if (datacenterAuthInfoById != nil)
                _datacenterAuthInfoById = [[NSMutableDictionary alloc] initWithDictionary:datacenterAuthInfoById];
            
            NSDictionary *authTokenById = [keychain objectForKey:@"authTokenById" group:@"persistent"];
            if (authTokenById != nil)
                _authTokenById = [[NSMutableDictionary alloc] initWithDictionary:authTokenById];
            
            NSDictionary *cleanupSessionIdsByAuthKeyId = [keychain objectForKey:@"cleanupSessionIdsByAuthKeyId" group:@"cleanup"];
            if (cleanupSessionIdsByAuthKeyId != nil)
                _cleanupSessionIdsByAuthKeyId = [[NSMutableDictionary alloc] initWithDictionary:cleanupSessionIdsByAuthKeyId];
        }
    }];
}

- (void)addChangeListener:(id<MTContextChangeListener>)changeListener
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        if (![_changeListeners containsObject:changeListener])
        {
            [_changeListeners addObject:changeListener];
        }
    }];
}

- (void)removeChangeListener:(id<MTContextChangeListener>)changeListener
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        [_changeListeners removeObject:changeListener];
    } synchronous:true];
}

- (NSTimeInterval)globalTime
{
#warning TODO use dispatch_barrier_async for async queue writes
    return [[NSDate date] timeIntervalSince1970] + [self globalTimeDifference];
}

- (NSTimeInterval)globalTimeDifference
{
    __block NSTimeInterval result = 0.0;
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        result = _globalTimeDifference;
    } synchronous:true];
    
    return result;
}

- (NSTimeInterval)globalTimeOffsetFromUTC
{
    return [self globalTimeDifference] + [[NSTimeZone localTimeZone] secondsFromGMT];
}

- (void)setGlobalTimeDifference:(NSTimeInterval)globalTimeDifference
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        _globalTimeDifference = globalTimeDifference;
        
        MTLog(@"[MTContext#%x: global time difference changed: %.1fs]", (int)self, globalTimeDifference);
        
        [_keychain setObject:@(_globalTimeDifference) forKey:@"globalTimeDifference" group:@"temp"];
    }];
}

- (void)setSeedAddressSetForDatacenterWithId:(NSInteger)datacenterId seedAddressSet:(MTDatacenterAddressSet *)seedAddressSet
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        _datacenterSeedAddressSetById[@(datacenterId)] = seedAddressSet;
    }];
}

- (void)updateAddressSetForDatacenterWithId:(NSInteger)datacenterId addressSet:(MTDatacenterAddressSet *)addressSet
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        if (addressSet != nil && datacenterId != 0)
        {
            MTLog(@"[MTContext#%x: address set updated for %d]", (int)self, datacenterId);
            
            bool previousAddressSetWasEmpty = ((MTDatacenterAddressSet *)_datacenterAddressSetById[@(datacenterId)]).addressList.count == 0;
            
            _datacenterAddressSetById[@(datacenterId)] = addressSet;
            [_keychain setObject:_datacenterAddressSetById forKey:@"datacenterAddressSetById" group:@"persistent"];
            
            NSArray *currentListeners = [[NSArray alloc] initWithArray:_changeListeners];
            
            for (id<MTContextChangeListener> listener in currentListeners)
            {
                if ([listener respondsToSelector:@selector(contextDatacenterAddressSetUpdated:datacenterId:addressSet:)])
                    [listener contextDatacenterAddressSetUpdated:self datacenterId:datacenterId addressSet:addressSet];
            }
            
            if (previousAddressSetWasEmpty)
                [self updateTransportSchemeForDatacenterWithId:datacenterId transportScheme:_datacenterTransportSchemeById[@(datacenterId)]];
        }
    }];
}

- (void)addAddressForDatacenterWithId:(NSInteger)datacenterId address:(MTDatacenterAddress *)address
{
    if (address == nil || datacenterId == 0)
        return;
    
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        bool updated = false;
        
        MTDatacenterAddressSet *addressSet = [self addressSetForDatacenterWithId:datacenterId];
        if (addressSet == nil)
        {
            addressSet = [[MTDatacenterAddressSet alloc] initWithAddressList:@[address]];
            updated = true;
        }
        else if (![addressSet.addressList containsObject:address])
        {
            NSMutableArray *updatedAddressList = [[NSMutableArray alloc] init];
            [updatedAddressList addObject:address];
            [updatedAddressList addObjectsFromArray:addressSet.addressList];
            
            addressSet = [[MTDatacenterAddressSet alloc] initWithAddressList:updatedAddressList];
            updated = true;
        }
        
        if (updated)
        {
            MTLog(@"[MTContext#%x: added address %@ for datacenter %d]", (int)self, address, datacenterId);
            
            _datacenterAddressSetById[@(datacenterId)] = addressSet;
            [_keychain setObject:_datacenterAddressSetById forKey:@"datacenterAddressSetById" group:@"persistent"];
            
            NSArray *currentListeners = [[NSArray alloc] initWithArray:_changeListeners];
            
            for (id<MTContextChangeListener> listener in currentListeners)
            {
                if ([listener respondsToSelector:@selector(contextDatacenterAddressSetUpdated:datacenterId:addressSet:)])
                    [listener contextDatacenterAddressSetUpdated:self datacenterId:datacenterId addressSet:addressSet];
            }
        }
    }];
}

- (void)updateAuthInfoForDatacenterWithId:(NSInteger)datacenterId authInfo:(MTDatacenterAuthInfo *)authInfo
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        if (authInfo != nil && datacenterId != 0)
        {
            MTLog(@"[MTContext#%x: auth info updated for %d]", (int)self, datacenterId);
            
            _datacenterAuthInfoById[@(datacenterId)] = authInfo;
            [_keychain setObject:_datacenterAuthInfoById forKey:@"datacenterAuthInfoById" group:@"persistent"];
            
            NSArray *currentListeners = [[NSArray alloc] initWithArray:_changeListeners];
            
            for (id<MTContextChangeListener> listener in currentListeners)
            {
                if ([listener respondsToSelector:@selector(contextDatacenterAuthInfoUpdated:datacenterId:authInfo:)])
                    [listener contextDatacenterAuthInfoUpdated:self datacenterId:datacenterId authInfo:authInfo];
            }
        }
    }];
}

- (bool)isPasswordInputRequiredForDatacenterWithId:(NSInteger)datacenterId
{
    OSSpinLockLock(&_passwordEntryRequiredLock);
    bool currentValue = [_passwordRequiredByDatacenterId[@(datacenterId)] boolValue];
    OSSpinLockUnlock(&_passwordEntryRequiredLock);
    
    return currentValue;
}

- (bool)updatePasswordInputRequiredForDatacenterWithId:(NSInteger)datacenterId required:(bool)required
{
    OSSpinLockLock(&_passwordEntryRequiredLock);
    bool currentValue = [_passwordRequiredByDatacenterId[@(datacenterId)] boolValue];
    bool updated = currentValue != required;
    _passwordRequiredByDatacenterId[@(datacenterId)] = @(required);
    OSSpinLockUnlock(&_passwordEntryRequiredLock);
    
    if (updated)
    {
        [[MTContext contextQueue] dispatchOnQueue:^
        {
            NSArray *currentListeners = [[NSArray alloc] initWithArray:_changeListeners];
            
            for (id<MTContextChangeListener> listener in currentListeners)
            {
                if ([listener respondsToSelector:@selector(contextIsPasswordRequiredUpdated:datacenterId:)])
                    [listener contextIsPasswordRequiredUpdated:self datacenterId:datacenterId];
            }
        }];
    }
    
    return currentValue;
}

- (void)updateTransportSchemeForDatacenterWithId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        if (transportScheme != nil && datacenterId != 0)
        {
            MTTransportScheme *previousScheme = _datacenterTransportSchemeById[@(datacenterId)];
            
            if (transportScheme == nil)
                [_datacenterTransportSchemeById removeObjectForKey:@(datacenterId)];
            else
                _datacenterTransportSchemeById[@(datacenterId)] = transportScheme;
            
            [_keychain setObject:_datacenterTransportSchemeById forKey:@"datacenterTransportSchemeById" group:@"persistent"];
            
            NSArray *currentListeners = [[NSArray alloc] initWithArray:_changeListeners];
            
            MTTransportScheme *currentScheme = transportScheme == nil ? [self defaultTransportSchemeForDatacenterWithId:datacenterId] : transportScheme;
            
            if (currentScheme != nil && (previousScheme == nil || ![previousScheme isEqualToScheme:currentScheme]))
            {
                MTLog(@"[MTContext#%x: transport scheme updated for %d: %@]", (int)self, datacenterId, transportScheme);
                
                for (id<MTContextChangeListener> listener in currentListeners)
                {
                    if ([listener respondsToSelector:@selector(contextDatacenterTransportSchemeUpdated:datacenterId:transportScheme:)])
                        [listener contextDatacenterTransportSchemeUpdated:self datacenterId:datacenterId transportScheme:currentScheme];
                }
            }
        }
    }];
}

- (void)scheduleSessionCleanupForAuthKeyId:(int64_t)authKeyId sessionInfo:(MTSessionInfo *)sessionInfo
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
#warning implement and reenable
        return;
        
        if (authKeyId == 0 || sessionInfo == nil)
            return;
        
        NSMutableArray *sessionIds = _cleanupSessionIdsByAuthKeyId[@(authKeyId)];
        if (sessionIds == nil)
        {
            sessionIds = [[NSMutableArray alloc] init];
            _cleanupSessionIdsByAuthKeyId[@(authKeyId)] = sessionIds;
        }
        else if (![sessionIds respondsToSelector:@selector(setObject:forKey:)])
        {
            sessionIds = [[NSMutableArray alloc] initWithArray:sessionIds];
            _cleanupSessionIdsByAuthKeyId[@(authKeyId)] = sessionIds;
        }
        
        [sessionIds addObject:@(sessionInfo.sessionId)];
        [_currentSessionInfos addObject:sessionInfo];
        
        [_keychain setObject:_cleanupSessionIdsByAuthKeyId forKey:@"cleanupSessionIdsByAuthKeyId" group:@"cleanup"];
    }];
}

- (void)collectSessionIdsForCleanupWithAuthKeyId:(int64_t)authKeyId completion:(void (^)(NSArray *sessionIds))completion
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        NSMutableSet *liveSessionIds = [[NSMutableSet alloc] init];
        for (NSInteger i = (NSInteger)_currentSessionInfos.count - 1; i >= 0; i--)
        {
            MTSessionInfo *sessionInfo = _currentSessionInfos[i];
            if (!sessionInfo.canBeDeleted)
                [liveSessionIds addObject:@(sessionInfo.sessionId)];
            else
                [_currentSessionInfos removeObjectAtIndex:(NSUInteger)i];
        }
        
        NSMutableArray *currentSessionIds = [[NSMutableArray alloc] init];
        for (NSNumber *nSessionId in _cleanupSessionIdsByAuthKeyId[@(authKeyId)])
        {
            if (![liveSessionIds containsObject:nSessionId])
                [currentSessionIds addObject:nSessionId];
        }
        
        if (completion)
            completion(currentSessionIds);
    }];
}

- (void)sessionIdsDeletedForAuthKeyId:(int64_t)authKeyId sessionIds:(NSArray *)sessionIds
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        for (NSInteger i = (NSInteger)_currentSessionInfos.count - 1; i >= 0; i--)
        {
            MTSessionInfo *sessionInfo = _currentSessionInfos[i];
            if ([sessionIds containsObject:@(sessionInfo.sessionId)])
                [_currentSessionInfos removeObjectAtIndex:(NSUInteger)i];
        }
        
        NSMutableArray *cleanupSessionIds = _cleanupSessionIdsByAuthKeyId[@(authKeyId)];
        if (![cleanupSessionIds respondsToSelector:@selector(removeObjectAtIndex:)])
        {
            cleanupSessionIds = [[NSMutableArray alloc] initWithArray:cleanupSessionIds];
            _cleanupSessionIdsByAuthKeyId[@(authKeyId)] = cleanupSessionIds;
        }
        for (NSInteger i = ((NSUInteger)cleanupSessionIds.count) - 1; i >= 0; i--)
        {
            if ([sessionIds containsObject:cleanupSessionIds[(NSUInteger)i]])
                [cleanupSessionIds removeObjectAtIndex:(NSUInteger)i];
        }
        
        [_keychain setObject:_cleanupSessionIdsByAuthKeyId forKey:@"cleanupSessionIdsByAuthKeyId" group:@"cleanup"];
    }];
}

- (NSArray *)knownDatacenterIds
{
    NSMutableSet *datacenterIds = [[NSMutableSet alloc] init];
    
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        for (NSNumber *nDatacenterId in _datacenterSeedAddressSetById.allKeys)
        {
            [datacenterIds addObject:nDatacenterId];
        }
        
        for (NSNumber *nDatacenterId in _datacenterAddressSetById.allKeys)
        {
            [datacenterIds addObject:nDatacenterId];
        }
    } synchronous:true];
    
    return [[datacenterIds allObjects] sortedArrayUsingComparator:^NSComparisonResult(NSNumber *n1, NSNumber *n2)
    {
        return [n1 compare:n2];
    }];
}

- (void)enumerateAddressSetsForDatacenters:(void (^)(NSInteger datacenterId, MTDatacenterAddressSet *addressSet, BOOL *stop))block
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        if (block == nil)
            return;
        
        NSMutableSet *processedDatacenterIds = [[NSMutableSet alloc] init];
        
        [_datacenterAddressSetById enumerateKeysAndObjectsUsingBlock:^(NSNumber *nDatacenterId, MTDatacenterAddressSet *addressSet, BOOL *stop)
        {
            [processedDatacenterIds addObject:nDatacenterId];
            block([nDatacenterId integerValue], addressSet, stop);
        }];
        
        [_datacenterSeedAddressSetById enumerateKeysAndObjectsUsingBlock:^(NSNumber *nDatacenterId, MTDatacenterAddressSet *addressSet, BOOL *stop)
        {
            if (![processedDatacenterIds containsObject:nDatacenterId])
                block([nDatacenterId integerValue], addressSet, stop);
        }];
    } synchronous:true];
}

- (MTDatacenterAddressSet *)addressSetForDatacenterWithId:(NSInteger)datacenterId
{
    __block MTDatacenterAddressSet *result = nil;
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        if (_datacenterAddressSetById[@(datacenterId)] != nil)
            result = _datacenterAddressSetById[@(datacenterId)];
        else
            result = _datacenterSeedAddressSetById[@(datacenterId)];
    } synchronous:true];
    
    return result;
}

- (MTTransportScheme *)transportSchemeForDatacenterWithid:(NSInteger)datacenterId
{
    __block MTTransportScheme *result = nil;
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        MTTransportScheme *candidate = _datacenterTransportSchemeById[@(datacenterId)];
        if (candidate != nil)
            result = candidate;
        else
            result = [self defaultTransportSchemeForDatacenterWithId:datacenterId];
        
        if (result != nil && ![result isOptimal])
        {
            MTDiscoverTransportSchemeAction *action = _discoverDatacenterTransportSchemeActions[@(datacenterId)];
            if (action == nil)
            {
                action = [[MTDiscoverTransportSchemeAction alloc] initWithContext:self datacenterId:datacenterId];
                action.delegate = self;
                _discoverDatacenterTransportSchemeActions[@(datacenterId)] = action;
            }
            
            [action discoverMoreOptimalSchemeThan:result];
        }
    } synchronous:true];
    
    return result;
}

- (MTDatacenterAuthInfo *)authInfoForDatacenterWithId:(NSInteger)datacenterId
{
    __block MTDatacenterAuthInfo *result = nil;
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        result = _datacenterAuthInfoById[@(datacenterId)];
    } synchronous:true];
    
    return result;
}

- (void)removeAllAuthTokens
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        [_authTokenById removeAllObjects];
        [_keychain setObject:_authTokenById forKey:@"authTokenById" group:@"persistent"];
        
        for (NSNumber *nDatacenterId in _datacenterTransferAuthActions)
        {
            MTDatacenterTransferAuthAction *action = _datacenterTransferAuthActions[nDatacenterId];
            action.delegate = nil;
            [action cancel];
        }
        [_datacenterTransferAuthActions removeAllObjects];
    }];
}

- (id)authTokenForDatacenterWithId:(NSInteger)datacenterId
{
    __block id result = nil;
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        result = _authTokenById[@(datacenterId)];
    } synchronous:true];
    
    return result;
}

- (MTTransportScheme *)defaultTransportSchemeForDatacenterWithId:(NSInteger)datacenterId
{
    __block MTTransportScheme *result = nil;
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        MTDatacenterAddressSet *addressSet = [self addressSetForDatacenterWithId:datacenterId];
        if (addressSet != nil && addressSet.addressList.count != 0)
            result = [[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:addressSet.addressList.firstObject];
        else
            [self addressSetForDatacenterWithIdRequired:datacenterId];
    } synchronous:true];
    
    return result;
}

- (void)transportSchemeForDatacenterWithIdRequired:(NSInteger)datacenterId
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        MTDiscoverTransportSchemeAction *action = _discoverDatacenterTransportSchemeActions[@(datacenterId)];
        if (action == nil)
        {
            action = [[MTDiscoverTransportSchemeAction alloc] initWithContext:self datacenterId:datacenterId];
            action.delegate = self;
            _discoverDatacenterTransportSchemeActions[@(datacenterId)] = action;
        }
        
        [action discoverScheme];
    }];
}

- (void)invalidateTransportSchemeForDatacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme isProbablyHttp:(bool)isProbablyHttp
{
    if (transportScheme == nil)
        return;
    
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        MTDiscoverTransportSchemeAction *action = _discoverDatacenterTransportSchemeActions[@(datacenterId)];
        if (action == nil)
        {
            action = [[MTDiscoverTransportSchemeAction alloc] initWithContext:self datacenterId:datacenterId];
            action.delegate = self;
            _discoverDatacenterTransportSchemeActions[@(datacenterId)] = action;
        }
        
        [action invalidateScheme:transportScheme beginWithHttp:isProbablyHttp];
    }];
}

- (void)revalidateTransportSchemeForDatacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        MTDiscoverTransportSchemeAction *action = _discoverDatacenterTransportSchemeActions[@(datacenterId)];
        if (action != nil)
            [action validateScheme:transportScheme];
    }];
}

- (void)discoverTransportSchemeActionCompleted:(MTDiscoverTransportSchemeAction *)action
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        for (NSNumber *nDatacenterId in _discoverDatacenterTransportSchemeActions)
        {
            if (_discoverDatacenterTransportSchemeActions[nDatacenterId] == action)
            {
                [_discoverDatacenterTransportSchemeActions removeObjectForKey:nDatacenterId];
                
                break;
            }
        }
    }];
}

- (void)updateAuthTokenForDatacenterWithId:(NSInteger)datacenterId authToken:(id)authToken
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        if (authToken != nil)
            _authTokenById[@(datacenterId)] = authToken;
        else
            [_authTokenById removeObjectForKey:@(datacenterId)];
        [_keychain setObject:_authTokenById forKey:@"authTokenById" group:@"persistent"];
        
        NSArray *currentListeners = [[NSArray alloc] initWithArray:_changeListeners];
        
        for (id<MTContextChangeListener> listener in currentListeners)
        {
            if ([listener respondsToSelector:@selector(contextDatacenterAuthTokenUpdated:datacenterId:authToken:)])
                [listener contextDatacenterAuthTokenUpdated:self datacenterId:datacenterId authToken:authToken];
        }
    }];
}

- (void)addressSetForDatacenterWithIdRequired:(NSInteger)datacenterId
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        if (_discoverDatacenterAddressActions[@(datacenterId)] == nil)
        {
            MTDiscoverDatacenterAddressAction *discoverAction = [[MTDiscoverDatacenterAddressAction alloc] init];
            discoverAction.delegate = self;
            _discoverDatacenterAddressActions[@(datacenterId)] = discoverAction;
            [discoverAction execute:self datacenterId:datacenterId];
        }
    }];
}

- (void)discoverDatacenterAddressActionCompleted:(MTDiscoverDatacenterAddressAction *)action
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        for (NSNumber *nDatacenterId in _discoverDatacenterAddressActions)
        {
            if (_discoverDatacenterAddressActions[nDatacenterId] == action)
            {
                [_discoverDatacenterAddressActions removeObjectForKey:nDatacenterId];
                
                break;
            }
        }
    }];
}

- (void)authInfoForDatacenterWithIdRequired:(NSInteger)datacenterId
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        if (_datacenterAuthActions[@(datacenterId)] == nil)
        {
            MTDatacenterAuthAction *authAction = [[MTDatacenterAuthAction alloc] init];
            authAction.delegate = self;
            _datacenterAuthActions[@(datacenterId)] = authAction;
            [authAction execute:self datacenterId:datacenterId];
        }
    }];
}

- (void)datacenterAuthActionCompleted:(MTDatacenterAuthAction *)action
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        for (NSNumber *nDatacenterId in _datacenterAuthActions)
        {
            if (_datacenterAuthActions[nDatacenterId] == action)
            {
                [_datacenterAuthActions removeObjectForKey:nDatacenterId];
                
                break;
            }
        }
    }];
}

- (void)authTokenForDatacenterWithIdRequired:(NSInteger)datacenterId authToken:(id)authToken masterDatacenterId:(NSInteger)masterDatacenterId
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        if (authToken == nil)
            return;
        
        if (_datacenterTransferAuthActions[@(datacenterId)] == nil && masterDatacenterId != datacenterId)
        {
            MTDatacenterTransferAuthAction *transferAction = [[MTDatacenterTransferAuthAction alloc] init];
            transferAction.delegate = self;
            _datacenterTransferAuthActions[@(datacenterId)] = transferAction;
            [transferAction execute:self masterDatacenterId:masterDatacenterId destinationDatacenterId:datacenterId authToken:authToken];
        }
    }];
}

- (void)datacenterTransferAuthActionCompleted:(MTDatacenterTransferAuthAction *)action
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        for (NSNumber *nDatacenterId in _datacenterTransferAuthActions)
        {
            if (_datacenterTransferAuthActions[nDatacenterId] == action)
            {
                [_datacenterTransferAuthActions removeObjectForKey:nDatacenterId];
                
                break;
            }
        }
    }];
}

- (void)reportProblemsWithDatacenterAddressForId:(NSInteger)datacenterId address:(MTDatacenterAddress *)address
{
    
}

- (void)updatePeriodicTasks
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        int64_t saltsRequiredAtLeastUntilMessageId = (int64_t)(([self globalTime] + 24 * 60.0 * 60.0) * 4294967296);
        
        [_datacenterAuthInfoById enumerateKeysAndObjectsUsingBlock:^(NSNumber *nDatacenterId, MTDatacenterAuthInfo *authInfo, __unused BOOL *stop)
        {
            if ([authInfo authSaltForMessageId:saltsRequiredAtLeastUntilMessageId == 0])
            {
#warning TODO
            }
        }];
    }];
}

@end
