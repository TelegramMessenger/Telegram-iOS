#import "MTContext.h"

#import <inttypes.h>

#import "MTLogging.h"
#import "MTTimer.h"
#import "MTQueue.h"
#import "MTKeychain.h"

#import "MTDatacenterAddressSet.h"
#import "MTDatacenterAddress.h"
#import "MTDatacenterAuthInfo.h"
#import "MTDatacenterSaltInfo.h"
#import "MTSessionInfo.h"
#import "MTApiEnvironment.h"

#import "MTDiscoverDatacenterAddressAction.h"
#import "MTDatacenterAuthAction.h"
#import "MTDatacenterTransferAuthAction.h"

#import "MTTransportScheme.h"
#import "MTTcpTransport.h"

#import "MTApiEnvironment.h"

#import <libkern/OSAtomic.h>

#import "MTDiscoverConnectionSignals.h"

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

@implementation MTContextBlockChangeListener

- (void)contextIsPasswordRequiredUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId
{
    if (_contextIsPasswordRequiredUpdated)
        _contextIsPasswordRequiredUpdated(context, datacenterId);
}

- (MTSignal *)fetchContextDatacenterPublicKeys:(MTContext *)context datacenterId:(NSInteger)datacenterId {
    if (_fetchContextDatacenterPublicKeys) {
        return _fetchContextDatacenterPublicKeys(context, datacenterId);
    } else {
        return nil;
    }
}

@end

@interface MTContext () <MTDiscoverDatacenterAddressActionDelegate, MTDatacenterAuthActionDelegate, MTDatacenterTransferAuthActionDelegate>
{
    int64_t _uniqueId;
    
    NSTimeInterval _globalTimeDifference;
    
    NSMutableDictionary *_datacenterSeedAddressSetById;
    
    NSMutableDictionary *_datacenterAddressSetById;
    
    NSMutableDictionary *_datacenterGenericTransportSchemeById;
    NSMutableDictionary *_datacenterMediaTransportSchemeById;
    NSMutableDictionary *_datacenterProxyGenericTransportSchemeById;
    NSMutableDictionary *_datacenterProxyMediaTransportSchemeById;
    
    NSMutableDictionary *_datacenterAuthInfoById;
    
    NSMutableDictionary *_datacenterPublicKeysById;
    
    NSMutableDictionary *_authTokenById;
    
    NSMutableArray *_changeListeners;
    
    MTSignal *_discoverBackupAddressListSignal;
    
    NSMutableDictionary *_discoverDatacenterAddressActions;
    NSMutableDictionary *_datacenterAuthActions;
    NSMutableDictionary *_datacenterTempAuthActions;
    NSMutableDictionary *_datacenterTransferAuthActions;
    
    NSMutableDictionary *_cleanupSessionIdsByAuthKeyId;
    NSMutableArray *_currentSessionInfos;
    
    NSMutableDictionary *_periodicTasksTimerByDatacenterId;
    
    volatile OSSpinLock _passwordEntryRequiredLock;
    NSMutableDictionary *_passwordRequiredByDatacenterId;
    
    NSMutableDictionary *_transportSchemeDisposableByDatacenterId;
    id<MTDisposable> _backupAddressListDisposable;
    
    NSMutableDictionary<NSNumber *, id<MTDisposable> > *_fetchPublicKeysActions;
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
        
        _datacenterGenericTransportSchemeById = [[NSMutableDictionary alloc] init];
        _datacenterMediaTransportSchemeById = [[NSMutableDictionary alloc] init];
        _datacenterProxyGenericTransportSchemeById = [[NSMutableDictionary alloc] init];
        _datacenterProxyMediaTransportSchemeById = [[NSMutableDictionary alloc] init];
        
        _datacenterAuthInfoById = [[NSMutableDictionary alloc] init];
        _datacenterPublicKeysById = [[NSMutableDictionary alloc] init];
        
        _authTokenById = [[NSMutableDictionary alloc] init];
        
        _changeListeners = [[NSMutableArray alloc] init];
        
        _discoverDatacenterAddressActions = [[NSMutableDictionary alloc] init];
        _datacenterAuthActions = [[NSMutableDictionary alloc] init];
        _datacenterTempAuthActions = [[NSMutableDictionary alloc] init];
        _datacenterTransferAuthActions = [[NSMutableDictionary alloc] init];
        
        _cleanupSessionIdsByAuthKeyId = [[NSMutableDictionary alloc] init];
        _currentSessionInfos = [[NSMutableArray alloc] init];
        
        _passwordRequiredByDatacenterId = [[NSMutableDictionary alloc] init];
        
        _fetchPublicKeysActions = [[NSMutableDictionary alloc] init];
        
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
    
    NSDictionary *datacenterTempAuthActions = _datacenterTempAuthActions;
    _datacenterTempAuthActions = nil;
    
    NSDictionary *discoverDatacenterAddressActions = _discoverDatacenterAddressActions;
    _discoverDatacenterAddressActions = nil;
    
    NSDictionary *datacenterTransferAuthActions = _datacenterTransferAuthActions;
    _datacenterTransferAuthActions = nil;
    
    NSDictionary *fetchPublicKeysActions = _fetchPublicKeysActions;
    _fetchPublicKeysActions = nil;
    
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        for (NSNumber *nDatacenterId in discoverDatacenterAddressActions)
        {
            MTDiscoverDatacenterAddressAction *action = discoverDatacenterAddressActions[nDatacenterId];
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
        
        for (NSNumber *nDatacenterId in fetchPublicKeysActions)
        {
            id<MTDisposable> disposable = fetchPublicKeysActions[nDatacenterId];
            [disposable dispose];
        }
    }];
}

- (void)performBatchUpdates:(void (^)())block
{
    if (block != nil)
        [[MTContext contextQueue] dispatchOnQueue:block];
}

- (void)setKeychain:(id<MTKeychain>)keychain
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
            
            [_apiEnvironment.datacenterAddressOverrides enumerateKeysAndObjectsUsingBlock:^(NSNumber *nDatacenterId, MTDatacenterAddress *address, __unused BOOL *stop) {
                _datacenterAddressSetById[nDatacenterId] = [[MTDatacenterAddressSet alloc] initWithAddressList:@[address]];
            }];
            
            NSDictionary *datacenterGenericTransportSchemeById = [keychain objectForKey:@"datacenterGenericTransportSchemeById" group:@"persistent"];
            if (datacenterGenericTransportSchemeById != nil)
            {
                _datacenterGenericTransportSchemeById = [[NSMutableDictionary alloc] initWithDictionary:datacenterGenericTransportSchemeById];
            }
            NSDictionary *datacenterMediaTransportSchemeById = [keychain objectForKey:@"datacenterMediaTransportSchemeById" group:@"persistent"];
            if (datacenterMediaTransportSchemeById != nil)
            {
                _datacenterMediaTransportSchemeById = [[NSMutableDictionary alloc] initWithDictionary:datacenterMediaTransportSchemeById];
            }
            
            NSDictionary *datacenterProxyGenericTransportSchemeById = [keychain objectForKey:@"datacenterProxyGenericTransportSchemeById" group:@"persistent"];
            if (datacenterProxyGenericTransportSchemeById != nil)
            {
                _datacenterProxyGenericTransportSchemeById = [[NSMutableDictionary alloc] initWithDictionary:datacenterProxyGenericTransportSchemeById];
            }
            NSDictionary *datacenterProxyMediaTransportSchemeById = [keychain objectForKey:@"datacenterProxyMediaTransportSchemeById" group:@"persistent"];
            if (datacenterProxyMediaTransportSchemeById != nil)
            {
                _datacenterProxyMediaTransportSchemeById = [[NSMutableDictionary alloc] initWithDictionary:datacenterProxyMediaTransportSchemeById];
            }
            
            NSDictionary *datacenterAuthInfoById = [keychain objectForKey:@"datacenterAuthInfoById" group:@"persistent"];
            if (datacenterAuthInfoById != nil)
                _datacenterAuthInfoById = [[NSMutableDictionary alloc] initWithDictionary:datacenterAuthInfoById];
            
            NSDictionary *datacenterPublicKeysById = [keychain objectForKey:@"datacenterPublicKeysById" group:@"ephemeral"];
            if (datacenterPublicKeysById != nil) {
                _datacenterPublicKeysById = [[NSMutableDictionary alloc] initWithDictionary:datacenterPublicKeysById];
            }
            
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

- (void)setDiscoverBackupAddressListSignal:(MTSignal *)signal {
    [[MTContext contextQueue] dispatchOnQueue:^ {
        _discoverBackupAddressListSignal = signal;
    } synchronous:true];
}

- (NSTimeInterval)globalTime
{
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
        
        if (MTLogEnabled()) {
            MTLog(@"[MTContext#%x: global time difference changed: %.1fs]", (int)self, globalTimeDifference);
        }
        
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

- (void)updateAddressSetForDatacenterWithId:(NSInteger)datacenterId addressSet:(MTDatacenterAddressSet *)addressSet forceUpdateSchemes:(bool)forceUpdateSchemes
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        if (addressSet != nil && datacenterId != 0)
        {
            if (MTLogEnabled()) {
                MTLog(@"[MTContext#%x: address set updated for %d]", (int)self, datacenterId);
            }
            
            bool previousAddressSetWasEmpty = ((MTDatacenterAddressSet *)_datacenterAddressSetById[@(datacenterId)]).addressList.count == 0;
            
            _datacenterAddressSetById[@(datacenterId)] = addressSet;
            [_keychain setObject:_datacenterAddressSetById forKey:@"datacenterAddressSetById" group:@"persistent"];
            
            NSArray *currentListeners = [[NSArray alloc] initWithArray:_changeListeners];
            
            for (id<MTContextChangeListener> listener in currentListeners)
            {
                if ([listener respondsToSelector:@selector(contextDatacenterAddressSetUpdated:datacenterId:addressSet:)])
                    [listener contextDatacenterAddressSetUpdated:self datacenterId:datacenterId addressSet:addressSet];
            }
            
            if (previousAddressSetWasEmpty || forceUpdateSchemes)
            {
                [self updateTransportSchemeForDatacenterWithId:datacenterId transportScheme:[self defaultTransportSchemeForDatacenterWithId:datacenterId media:false isProxy:false] media:false isProxy:false];
                [self updateTransportSchemeForDatacenterWithId:datacenterId transportScheme:[self defaultTransportSchemeForDatacenterWithId:datacenterId media:true isProxy:false] media:true isProxy:false];
                [self updateTransportSchemeForDatacenterWithId:datacenterId transportScheme:[self defaultTransportSchemeForDatacenterWithId:datacenterId media:false isProxy:true] media:false isProxy:true];
                [self updateTransportSchemeForDatacenterWithId:datacenterId transportScheme:[self defaultTransportSchemeForDatacenterWithId:datacenterId media:true isProxy:true] media:true isProxy:true];
            }
            
            if (forceUpdateSchemes) {
                id<MTDisposable> disposable = _transportSchemeDisposableByDatacenterId[@(datacenterId)];
                if (disposable != nil) {
                    [disposable dispose];
                    [_transportSchemeDisposableByDatacenterId removeObjectForKey:@(datacenterId)];
                    
                    [self transportSchemeForDatacenterWithIdRequired:datacenterId moreOptimalThan:nil beginWithHttp:false media:false isProxy:_apiEnvironment.socksProxySettings != nil];
                }
            }
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
            if (MTLogEnabled()) {
                MTLog(@"[MTContext#%x: added address %@ for datacenter %d]", (int)self, address, datacenterId);
            }
            
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
            if (MTLogEnabled()) {
                MTLog(@"[MTContext#%x: auth info updated for %d]", (int)self, datacenterId);
            }
            
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

- (void)updateTransportSchemeForDatacenterWithId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme media:(bool)media isProxy:(bool)isProxy
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        if (transportScheme != nil && datacenterId != 0)
        {
            NSMutableDictionary *transportSchemeDict = nil;
            if (isProxy) {
                transportSchemeDict = media ? _datacenterProxyMediaTransportSchemeById : _datacenterProxyGenericTransportSchemeById;
            } else {
                transportSchemeDict = media ? _datacenterMediaTransportSchemeById : _datacenterGenericTransportSchemeById;
            }
            
            MTTransportScheme *previousScheme = transportSchemeDict[@(datacenterId)];
            
            if (transportScheme == nil)
                [transportSchemeDict removeObjectForKey:@(datacenterId)];
            else
                transportSchemeDict[@(datacenterId)] = transportScheme;
            
            if (isProxy) {
                if (media) {
                    [_keychain setObject:_datacenterProxyMediaTransportSchemeById forKey:@"datacenterProxyMediaTransportSchemeById" group:@"persistent"];
                } else {
                    [_keychain setObject:_datacenterProxyGenericTransportSchemeById forKey:@"datacenterProxyGenericTransportSchemeById" group:@"persistent"];
                }
            } else {
                if (media) {
                    [_keychain setObject:_datacenterMediaTransportSchemeById forKey:@"datacenterMediaTransportSchemeById" group:@"persistent"];
                } else {
                    [_keychain setObject:_datacenterGenericTransportSchemeById forKey:@"datacenterGenericTransportSchemeById" group:@"persistent"];
                }
            }
            
            NSArray *currentListeners = [[NSArray alloc] initWithArray:_changeListeners];
            
            MTTransportScheme *currentScheme = transportScheme == nil ? [self defaultTransportSchemeForDatacenterWithId:datacenterId media:media isProxy:_apiEnvironment.socksProxySettings != nil] : transportScheme;
            
            if (currentScheme != nil && (previousScheme == nil || ![previousScheme isEqualToScheme:currentScheme]))
            {
                if (MTLogEnabled()) {
                    MTLog(@"[MTContext#%x: %@ transport scheme updated for %d: %@]", (int)self, media ? @"media" : @"generic", datacenterId, transportScheme);
                }
                
                for (id<MTContextChangeListener> listener in currentListeners)
                {
                    if ([listener respondsToSelector:@selector(contextDatacenterTransportSchemeUpdated:datacenterId:transportScheme:media:)])
                        [listener contextDatacenterTransportSchemeUpdated:self datacenterId:datacenterId transportScheme:currentScheme media:media];
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

- (MTTransportScheme *)transportSchemeForDatacenterWithId:(NSInteger)datacenterId media:(bool)media isProxy:(bool)isProxy
{
    __block MTTransportScheme *result = nil;
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        MTDatacenterAddress *overrideAddress = _apiEnvironment.datacenterAddressOverrides[@(datacenterId)];
        if (overrideAddress != nil) {
            result = [[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:overrideAddress media:false];
        } else {
            MTTransportScheme *candidate = nil;
            if (isProxy) {
                if (media) {
                    candidate = _datacenterProxyMediaTransportSchemeById[@(datacenterId)];
                } else {
                    candidate = _datacenterProxyGenericTransportSchemeById[@(datacenterId)];
                }
            } else {
                if (media) {
                    candidate = _datacenterMediaTransportSchemeById[@(datacenterId)];
                } else {
                    candidate = _datacenterGenericTransportSchemeById[@(datacenterId)];
                }
            }
            
            if (candidate != nil) {
                result = candidate;
            } else {
                result = [self defaultTransportSchemeForDatacenterWithId:datacenterId media:media isProxy:isProxy];
            }
            
            if (result != nil && ![result isOptimal]) {
                if (isProxy) {
                    result = [self defaultTransportSchemeForDatacenterWithId:datacenterId media:media isProxy:isProxy];
                } else {
                    [self transportSchemeForDatacenterWithIdRequired:datacenterId moreOptimalThan:result beginWithHttp:false media:media isProxy:isProxy];
                }
            }
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
    
- (NSArray<NSDictionary *> *)publicKeysForDatacenterWithId:(NSInteger)datacenterId {
    __block NSArray<NSDictionary *> *result = nil;
    [[MTContext contextQueue] dispatchOnQueue:^{
        result = _datacenterPublicKeysById[@(datacenterId)];
    } synchronous:true];
    
    return result;
}
    
- (void)updatePublicKeysForDatacenterWithId:(NSInteger)datacenterId publicKeys:(NSArray<NSDictionary *> *)publicKeys {
    [[MTContext contextQueue] dispatchOnQueue:^{
        if (publicKeys != nil) {
            _datacenterPublicKeysById[@(datacenterId)] = publicKeys;
            [_keychain setObject:_datacenterPublicKeysById forKey:@"datacenterPublicKeysById" group:@"ephemeral"];
            
            for (id<MTContextChangeListener> listener in _changeListeners) {
                if ([listener respondsToSelector:@selector(contextDatacenterPublicKeysUpdated:datacenterId:publicKeys:)]) {
                    [listener contextDatacenterPublicKeysUpdated:self datacenterId:datacenterId publicKeys:publicKeys];
                }
            }
        }
    } synchronous:false];
}
    
- (void)publicKeysForDatacenterWithIdRequired:(NSInteger)datacenterId {
    [[MTContext contextQueue] dispatchOnQueue:^{
        if (_fetchPublicKeysActions[@(datacenterId)] == nil) {
            for (id<MTContextChangeListener> listener in _changeListeners) {
                if ([listener respondsToSelector:@selector(fetchContextDatacenterPublicKeys:datacenterId:)]) {
                    MTSignal *signal = [listener fetchContextDatacenterPublicKeys:self datacenterId:datacenterId];
                    if (signal != nil) {
                        __weak MTContext *weakSelf = self;
                        MTMetaDisposable *disposable = [[MTMetaDisposable alloc] init];
                        _fetchPublicKeysActions[@(datacenterId)] = disposable;
                        [disposable setDisposable:[signal startWithNext:^(NSArray<NSDictionary *> *next) {
                            [[MTContext contextQueue] dispatchOnQueue:^{
                                __strong MTContext *strongSelf = weakSelf;
                                if (strongSelf != nil) {
                                    [strongSelf->_fetchPublicKeysActions removeObjectForKey:@(datacenterId)];
                                    [strongSelf updatePublicKeysForDatacenterWithId:datacenterId publicKeys:next];
                                }
                            } synchronous:false];
                        }]];
                        break;
                    }
                }
            }
        }
    } synchronous:false];
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

- (MTTransportScheme *)defaultTransportSchemeForDatacenterWithId:(NSInteger)datacenterId media:(bool)media isProxy:(bool)isProxy {
    __block MTTransportScheme *result = nil;
    [[MTContext contextQueue] dispatchOnQueue:^ {
        MTDatacenterAddressSet *addressSet = [self addressSetForDatacenterWithId:datacenterId];
        MTDatacenterAddress *selectedAddress = nil;
        
        for (MTDatacenterAddress *address in addressSet.addressList) {
            if (address.preferForMedia == media && address.preferForProxy == isProxy && ![address isIpv6]) {
                selectedAddress = address;
            }
        }
        if ((media || isProxy) && selectedAddress == nil) {
            for (MTDatacenterAddress *address in addressSet.addressList) {
                if (![address isIpv6]) {
                    selectedAddress = address;
                    break;
                }
            }
        }
        
        if (selectedAddress == nil) {
            for (MTDatacenterAddress *address in addressSet.addressList) {
                if (address.preferForMedia == media && address.preferForProxy == isProxy) {
                    selectedAddress = address;
                }
            }
            if ((media || isProxy) && selectedAddress == nil) {
                for (MTDatacenterAddress *address in addressSet.addressList) {
                    selectedAddress = address;
                    break;
                }
            }
        }
        
        if (selectedAddress != nil) {
            result = [[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:selectedAddress media:media];
        } else {
            [self addressSetForDatacenterWithIdRequired:datacenterId];
        }
    } synchronous:true];
    
    return result;
}

- (void)transportSchemeForDatacenterWithIdRequired:(NSInteger)datacenterId media:(bool)media
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        [self transportSchemeForDatacenterWithIdRequired:datacenterId moreOptimalThan:nil beginWithHttp:false media:media isProxy:_apiEnvironment.socksProxySettings != nil];
    }];
}

- (void)transportSchemeForDatacenterWithIdRequired:(NSInteger)datacenterId moreOptimalThan:(MTTransportScheme *)suboptimalScheme beginWithHttp:(bool)beginWithHttp media:(bool)media isProxy:(bool)isProxy
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        if (_transportSchemeDisposableByDatacenterId == nil)
            _transportSchemeDisposableByDatacenterId = [[NSMutableDictionary alloc] init];
        id<MTDisposable> disposable = _transportSchemeDisposableByDatacenterId[@(datacenterId)];
        if (disposable == nil)
        {
            __weak MTContext *weakSelf = self;
            MTDatacenterAddressSet *addressSet = [self addressSetForDatacenterWithId:datacenterId];
            _transportSchemeDisposableByDatacenterId[@(datacenterId)] = [[[MTDiscoverConnectionSignals discoverSchemeWithContext:self addressList:addressSet.addressList media:media isProxy:isProxy] onDispose:^
            {
                __strong MTContext *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    [[MTContext contextQueue] dispatchOnQueue:^
                    {
                        [strongSelf->_transportSchemeDisposableByDatacenterId removeObjectForKey:@(datacenterId)];
                    }];
                }
            }] startWithNext:^(id next)
            {
                if (MTLogEnabled()) {
                    MTLog(@"scheme: %@", next);
                }
                __strong MTContext *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    [strongSelf updateTransportSchemeForDatacenterWithId:datacenterId transportScheme:next media:media isProxy:isProxy];
                }
            } error:^(id error)
            {
                
            } completed:^
            {
                
            }];
        }
    }];
}

- (void)invalidateTransportSchemeForDatacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme isProbablyHttp:(bool)isProbablyHttp media:(bool)media
{
    if (transportScheme == nil)
        return;
    
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        [self transportSchemeForDatacenterWithIdRequired:datacenterId moreOptimalThan:transportScheme beginWithHttp:isProbablyHttp media:media isProxy:_apiEnvironment.socksProxySettings != nil];
        
        if (_backupAddressListDisposable == nil && _discoverBackupAddressListSignal != nil) {
            __weak MTContext *weakSelf = self;
            double delay = 20.0f;
#ifdef DEBUG
            delay = 5.0;
#endif
            _backupAddressListDisposable = [[[_discoverBackupAddressListSignal delay:delay onQueue:[MTQueue mainQueue]] onDispose:^{
                __strong MTContext *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    [strongSelf->_backupAddressListDisposable dispose];
                    strongSelf->_backupAddressListDisposable = nil;
                }
            }] startWithNext:nil];
        }
    }];
}

- (void)revalidateTransportSchemeForDatacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme media:(bool)media
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        if ([transportScheme isOptimal])
        {
            if (_transportSchemeDisposableByDatacenterId == nil)
                _transportSchemeDisposableByDatacenterId = [[NSMutableDictionary alloc] init];
            id<MTDisposable> disposable = _transportSchemeDisposableByDatacenterId[@(datacenterId)];
            [disposable dispose];
            [_transportSchemeDisposableByDatacenterId removeObjectForKey:@(datacenterId)];
        }
        if (_backupAddressListDisposable != nil) {
            [_backupAddressListDisposable dispose];
            _backupAddressListDisposable = nil;
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

- (void)authInfoForDatacenterWithIdRequired:(NSInteger)datacenterId isCdn:(bool)isCdn
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        if (_datacenterAuthActions[@(datacenterId)] == nil)
        {
            MTDatacenterAuthAction *authAction = [[MTDatacenterAuthAction alloc] initWithTempAuth:false];
            authAction.delegate = self;
            _datacenterAuthActions[@(datacenterId)] = authAction;
            [authAction execute:self datacenterId:datacenterId isCdn:isCdn];
        }
    }];
}

- (void)tempAuthKeyForDatacenterWithIdRequired:(NSInteger)datacenterId {
    [[MTContext contextQueue] dispatchOnQueue:^{
        if (_datacenterTempAuthActions[@(datacenterId)] == nil) {
            MTDatacenterAuthAction *authAction = [[MTDatacenterAuthAction alloc] initWithTempAuth:true];
            authAction.delegate = self;
            _datacenterTempAuthActions[@(datacenterId)] = authAction;
            [authAction execute:self datacenterId:datacenterId isCdn:false];
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
    
- (void)updateApiEnvironment:(MTApiEnvironment *(^)(MTApiEnvironment *))f {
    [[MTContext contextQueue] dispatchOnQueue:^{
        MTApiEnvironment *apiEnvironment = f(_apiEnvironment);
        _apiEnvironment = apiEnvironment;
        
        NSArray *currentListeners = [[NSArray alloc] initWithArray:_changeListeners];
        for (id<MTContextChangeListener> listener in currentListeners)
        {
            if ([listener respondsToSelector:@selector(contextApiEnvironmentUpdated:apiEnvironment:)]) {
                [listener contextApiEnvironmentUpdated:self apiEnvironment:apiEnvironment];
            }
        }
    }];
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
