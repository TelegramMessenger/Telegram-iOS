#import <MtProtoKit/MTContext.h>

#import <inttypes.h>

#import <MtProtoKit/MTLogging.h>
#import <MtProtoKit/MTTimer.h>
#import <MtProtoKit/MTQueue.h>
#import <MtProtoKit/MTKeychain.h>
#import <MtProtoKit/MTDatacenterAddressSet.h>
#import <MtProtoKit/MTDatacenterAddress.h>
#import <MtProtoKit/MTDatacenterAuthInfo.h>
#import <MtProtoKit/MTDatacenterSaltInfo.h>
#import <MtProtoKit/MTSessionInfo.h>
#import <MtProtoKit/MTApiEnvironment.h>

#import "MTDiscoverDatacenterAddressAction.h"
#import <MtProtoKit/MTDatacenterAuthAction.h>
#import <MtProtoKit/MTDatacenterTransferAuthAction.h>

#import <MtProtoKit/MTTransportScheme.h>
#import <MtProtoKit/MTTcpTransport.h>

#import <MtProtoKit/MTApiEnvironment.h>

#import <libkern/OSAtomic.h>

#import "MTDiscoverConnectionSignals.h"

#import "MTTransportSchemeStats.h"

#import <MtProtoKit/MTDisposable.h>
#import <MtProtoKit/MTSignal.h>

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

- (MTSignal *)isContextNetworkAccessAllowed:(MTContext *)context {
    if (_isContextNetworkAccessAllowed) {
        return _isContextNetworkAccessAllowed(context);
    } else {
        return nil;
    }
}

@end

@interface MTTransportSchemeKey : NSObject<NSCoding, NSCopying>

@property (nonatomic, readonly) NSInteger datacenterId;
@property (nonatomic, readonly) bool isProxy;
@property (nonatomic, readonly) bool isMedia;

@end

@implementation MTTransportSchemeKey

- (instancetype)initWithDatacenterId:(NSInteger)datacenterId isProxy:(bool)isProxy isMedia:(bool)isMedia {
    self = [super init];
    if (self != nil) {
        _datacenterId = datacenterId;
        _isProxy = isProxy;
        _isMedia = isMedia;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithDatacenterId:[aDecoder decodeIntegerForKey:@"datacenterId"] isProxy:[aDecoder decodeBoolForKey:@"isProxy"] isMedia:[aDecoder decodeBoolForKey:@"isMedia"]];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInteger:_datacenterId forKey:@"datacenterId"];
    [aCoder encodeBool:_isProxy forKey:@"isProxy"];
    [aCoder encodeBool:_isMedia forKey:@"isMedia"];
}

- (instancetype)copyWithZone:(NSZone *)__unused zone {
    return self;
}

- (NSUInteger)hash {
    return _datacenterId * 31 * 31 + (_isProxy ? 1 : 0) * 31 + (_isMedia ? 1 : 0);
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[MTTransportSchemeKey class]]) {
        return false;
    }
    MTTransportSchemeKey *other = (MTTransportSchemeKey *)object;
    if (_datacenterId != other->_datacenterId) {
        return false;
    }
    if (_isProxy != other->_isProxy) {
        return false;
    }
    if (_isMedia != other->_isMedia) {
        return false;
    }
    return true;
}

@end

typedef int64_t MTDatacenterAuthInfoMapKey;

typedef struct {
    int32_t datacenterId;
    MTDatacenterAuthInfoSelector selector;
} MTDatacenterAuthInfoMapKeyStruct;

static MTDatacenterAuthInfoMapKey authInfoMapKey(int32_t datacenterId, MTDatacenterAuthInfoSelector selector) {
    int64_t result = (((int64_t)(selector)) << 32) | ((int64_t)(datacenterId));
    return result;
}

static NSNumber *authInfoMapIntegerKey(int32_t datacenterId, MTDatacenterAuthInfoSelector selector) {
    return [NSNumber numberWithLongLong:authInfoMapKey(datacenterId, selector)];
}

static MTDatacenterAuthInfoMapKeyStruct parseAuthInfoMapKey(int64_t key) {
    MTDatacenterAuthInfoMapKeyStruct result;
    result.datacenterId = (int32_t)(key & 0x7fffffff);
    result.selector = (int32_t)(((key >> 32) & 0x7fffffff));
    return result;
}

static MTDatacenterAuthInfoMapKeyStruct parseAuthInfoMapKeyInteger(NSNumber *key) {
    return parseAuthInfoMapKey([key longLongValue]);
}

@interface MTContext () <MTDiscoverDatacenterAddressActionDelegate, MTDatacenterTransferAuthActionDelegate>
{
    int64_t _uniqueId;
    
    NSTimeInterval _globalTimeDifference;
    
    NSMutableDictionary *_datacenterSeedAddressSetById;
    NSMutableDictionary *_datacenterAddressSetById;
    NSMutableDictionary<MTTransportSchemeKey *, MTTransportScheme *> *_datacenterManuallySelectedSchemeById;
    
    NSMutableDictionary<NSNumber *, NSMutableDictionary<MTDatacenterAddress *, MTTransportSchemeStats *> *> *_transportSchemeStats;
    MTTimer *_schemeStatsSyncTimer;
    
    NSMutableDictionary<NSNumber *, MTDatacenterAuthInfo *> *_datacenterAuthInfoById;
    
    NSMutableDictionary *_datacenterPublicKeysById;
    
    NSMutableDictionary *_authTokenById;
    
    NSMutableArray *_changeListeners;
    
    MTSignal *_discoverBackupAddressListSignal;
    
    NSMutableDictionary *_discoverDatacenterAddressActions;
    NSMutableDictionary<NSNumber *, MTDatacenterAuthAction *> *_datacenterAuthActions;
    NSMutableDictionary *_datacenterTransferAuthActions;
    
    NSMutableDictionary<NSNumber *, NSNumber *> *_datacenterCheckKeyRemovedActionTimestamps;
    NSMutableDictionary<NSNumber *, id<MTDisposable> > *_datacenterCheckKeyRemovedActions;
    
    NSMutableDictionary *_cleanupSessionIdsByAuthKeyId;
    NSMutableArray *_currentSessionInfos;
    
    NSMutableDictionary *_periodicTasksTimerByDatacenterId;
    
    volatile OSSpinLock _passwordEntryRequiredLock;
    NSMutableDictionary *_passwordRequiredByDatacenterId;
    
    NSMutableDictionary *_transportSchemeDisposableByDatacenterId;
    id<MTDisposable> _backupAddressListDisposable;
    
    NSMutableDictionary<NSNumber *, id<MTDisposable> > *_fetchPublicKeysActions;
    
    MTDisposableSet *_cleanupSessionInfoDisposables;
}

@end

static int32_t fixedTimeDifferenceValue = 0;

@implementation MTContext

+ (int32_t)fixedTimeDifference {
    return fixedTimeDifferenceValue;
}

+ (void)setFixedTimeDifference:(int32_t)fixedTimeDifference {
    fixedTimeDifferenceValue = fixedTimeDifference;
}

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        NSAssert(false, @"use initWithSerialization:apiEnvironment:");
    }
    return self;
}

- (instancetype)initWithSerialization:(id<MTSerialization>)serialization encryptionProvider:(id<EncryptionProvider>)encryptionProvider apiEnvironment:(MTApiEnvironment *)apiEnvironment isTestingEnvironment:(bool)isTestingEnvironment useTempAuthKeys:(bool)useTempAuthKeys
{
    NSAssert(serialization != nil, @"serialization should not be nil");
    NSAssert(apiEnvironment != nil, @"apiEnvironment should not be nil");
    NSAssert(encryptionProvider != nil, @"encryptionProvider should not be nil");
    
    self = [super init];
    if (self != nil)
    {
        arc4random_buf(&_uniqueId, sizeof(_uniqueId));
        
        _serialization = serialization;
        _encryptionProvider = encryptionProvider;
        _apiEnvironment = apiEnvironment;
        _isTestingEnvironment = isTestingEnvironment;
        _useTempAuthKeys = useTempAuthKeys;
#if DEBUG
        _tempKeyExpiration = 1 * 60 * 60;
#else
        _tempKeyExpiration = 24 * 60 * 60;
#endif
        
        _datacenterSeedAddressSetById = [[NSMutableDictionary alloc] init];
        
        _datacenterAddressSetById = [[NSMutableDictionary alloc] init];
        _datacenterManuallySelectedSchemeById = [[NSMutableDictionary alloc] init];
        
        _transportSchemeStats = [[NSMutableDictionary alloc] init];
        
        _datacenterAuthInfoById = [[NSMutableDictionary alloc] init];
        _datacenterPublicKeysById = [[NSMutableDictionary alloc] init];
        
        _authTokenById = [[NSMutableDictionary alloc] init];
        
        _changeListeners = [[NSMutableArray alloc] init];
        
        _discoverDatacenterAddressActions = [[NSMutableDictionary alloc] init];
        _datacenterAuthActions = [[NSMutableDictionary alloc] init];
        _datacenterTransferAuthActions = [[NSMutableDictionary alloc] init];
        _datacenterCheckKeyRemovedActionTimestamps = [[NSMutableDictionary alloc] init];
        _datacenterCheckKeyRemovedActions = [[NSMutableDictionary alloc] init];
        
        _cleanupSessionIdsByAuthKeyId = [[NSMutableDictionary alloc] init];
        _currentSessionInfos = [[NSMutableArray alloc] init];
        
        _passwordRequiredByDatacenterId = [[NSMutableDictionary alloc] init];
        
        _fetchPublicKeysActions = [[NSMutableDictionary alloc] init];
        
        _cleanupSessionInfoDisposables = [[MTDisposableSet alloc] init];
        
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

+ (void)performWithObjCTry:(dispatch_block_t _Nonnull)block {
    @try {
        block();
    } @finally {
    }
}

- (void)cleanup
{
    NSDictionary *datacenterAuthActions = _datacenterAuthActions;
    _datacenterAuthActions = nil;
    
    NSDictionary *discoverDatacenterAddressActions = _discoverDatacenterAddressActions;
    _discoverDatacenterAddressActions = nil;
    
    NSDictionary *datacenterTransferAuthActions = _datacenterTransferAuthActions;
    _datacenterTransferAuthActions = nil;
    
    NSDictionary *datacenterCheckKeyRemovedActions = _datacenterCheckKeyRemovedActions;
    _datacenterCheckKeyRemovedActions = nil;
    
    NSDictionary *fetchPublicKeysActions = _fetchPublicKeysActions;
    _fetchPublicKeysActions = nil;
    
    id<MTDisposable> cleanupSessionInfoDisposables = _cleanupSessionInfoDisposables;
    
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        for (NSNumber *nDatacenterId in discoverDatacenterAddressActions)
        {
            MTDiscoverDatacenterAddressAction *action = discoverDatacenterAddressActions[nDatacenterId];
            action.delegate = nil;
            [action cancel];
        }

        for (NSNumber *key in datacenterAuthActions)
        {
            MTDatacenterAuthAction *action = datacenterAuthActions[key];
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
        
        for (NSNumber *nDatacenterId in datacenterCheckKeyRemovedActions) {
            [datacenterCheckKeyRemovedActions[nDatacenterId] dispose];
        }
        
        [cleanupSessionInfoDisposables dispose];
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
            if (datacenterAddressSetById != nil) {
                _datacenterAddressSetById = [[NSMutableDictionary alloc] initWithDictionary:datacenterAddressSetById];
                if (MTLogEnabled()) {
                    MTLog(@"[MTContext loaded datacenterAddressSetById: %@]", _datacenterAddressSetById);
                }
            }
            
            NSDictionary *datacenterManuallySelectedSchemeById = [keychain objectForKey:@"datacenterManuallySelectedSchemeById_v1" group:@"persistent"];
            if (datacenterManuallySelectedSchemeById != nil) {
                _datacenterManuallySelectedSchemeById = [[NSMutableDictionary alloc] initWithDictionary:datacenterManuallySelectedSchemeById];
                if (MTLogEnabled()) {
                    MTLog(@"[MTContext loaded datacenterManuallySelectedSchemeById: %@]", _datacenterManuallySelectedSchemeById);
                }
            }
            
            [_apiEnvironment.datacenterAddressOverrides enumerateKeysAndObjectsUsingBlock:^(NSNumber *nDatacenterId, MTDatacenterAddress *address, __unused BOOL *stop) {
                _datacenterAddressSetById[nDatacenterId] = [[MTDatacenterAddressSet alloc] initWithAddressList:@[address]];
            }];
            
            NSDictionary *datacenterAuthInfoById = [keychain objectForKey:@"datacenterAuthInfoById" group:@"persistent"];
            if (datacenterAuthInfoById != nil) {
                _datacenterAuthInfoById = [[NSMutableDictionary alloc] initWithDictionary:datacenterAuthInfoById];
/*#if DEBUG
                NSArray<NSNumber *> *keys = [_datacenterAuthInfoById allKeys];
                for (NSNumber *key in keys) {
                    if (parseAuthInfoMapKeyInteger(key).selector != MTDatacenterAuthInfoSelectorPersistent) {
                        [_datacenterAuthInfoById removeObjectForKey:key];
                    }
                }
#endif*/
            }
            
            NSDictionary *datacenterPublicKeysById = [keychain objectForKey:@"datacenterPublicKeysById" group:@"ephemeral"];
            if (datacenterPublicKeysById != nil) {
                _datacenterPublicKeysById = [[NSMutableDictionary alloc] initWithDictionary:datacenterPublicKeysById];
            }
            
            NSDictionary *transportSchemeStats = [keychain objectForKey:@"transportSchemeStats_v1" group:@"temp"];
            if (transportSchemeStats != nil) {
                [_transportSchemeStats removeAllObjects];
                [transportSchemeStats enumerateKeysAndObjectsUsingBlock:^(NSNumber *nDatacenterId, NSDictionary<MTDatacenterAddress *, MTTransportSchemeStats *> *values, __unused BOOL *stop) {
                    _transportSchemeStats[nDatacenterId] = [[NSMutableDictionary alloc] initWithDictionary:values];
                }];
                if (MTLogEnabled()) {
                    MTLog(@"[MTContext] loaded transportSchemeStats:\n%@", [MTTransportSchemeStats formatStats:_transportSchemeStats]);
                }
            }
            
            NSDictionary *authTokenById = [keychain objectForKey:@"authTokenById" group:@"persistent"];
            if (authTokenById != nil)
                _authTokenById = [[NSMutableDictionary alloc] initWithDictionary:authTokenById];
            
            NSDictionary *cleanupSessionIdsByAuthKeyId = [keychain objectForKey:@"cleanupSessionIdsByAuthKeyId" group:@"cleanup"];
            if (cleanupSessionIdsByAuthKeyId != nil)
                _cleanupSessionIdsByAuthKeyId = [[NSMutableDictionary alloc] initWithDictionary:cleanupSessionIdsByAuthKeyId];
            
            if (MTLogEnabled()) {
                MTLog(@"[MTContext#%" PRIxPTR ": received keychain globalTimeDifference:%f datacenterAuthInfoById:%@]", (intptr_t)self, _globalTimeDifference, _datacenterAuthInfoById);
            }
        } else {
            if (MTLogEnabled()) {
                MTLog(@"[MTContext#%" PRIxPTR ": received keychain nil]", (intptr_t)self);
            }
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
            MTLog(@"[MTContext#%" PRIxPTR ": global time difference changed: %.1fs]", (intptr_t)self, globalTimeDifference);
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
                MTLog(@"[MTContext#%" PRIxPTR ": address set updated for %d]", (intptr_t)self, datacenterId);
            }
            
            bool updateSchemes = forceUpdateSchemes;
            
            bool previousAddressSetWasEmpty = ((MTDatacenterAddressSet *)_datacenterAddressSetById[@(datacenterId)]).addressList.count == 0;
            
            _datacenterAddressSetById[@(datacenterId)] = addressSet;
            [_keychain setObject:_datacenterAddressSetById forKey:@"datacenterAddressSetById" group:@"persistent"];
            
            NSArray *currentListeners = [[NSArray alloc] initWithArray:_changeListeners];
            
            for (id<MTContextChangeListener> listener in currentListeners)
            {
                if ([listener respondsToSelector:@selector(contextDatacenterAddressSetUpdated:datacenterId:addressSet:)])
                    [listener contextDatacenterAddressSetUpdated:self datacenterId:datacenterId addressSet:addressSet];
            }
            
            if (true) {
                bool shouldReset = previousAddressSetWasEmpty || updateSchemes;
                for (id<MTContextChangeListener> listener in currentListeners) {
                    if ([listener respondsToSelector:@selector(contextDatacenterTransportSchemesUpdated:datacenterId:shouldReset:)]) {
                        [listener contextDatacenterTransportSchemesUpdated:self datacenterId:datacenterId shouldReset:shouldReset];
                    }
                }
            } else {
                /*for (NSNumber *nMedia in @[@false, @true]) {
                    for (NSNumber *nIsProxy in @[@false, @true]) {
                        MTDatacenterAddress *address = [self transportSchemeForDatacenterWithId:datacenterId media:[nMedia boolValue] isProxy:[nIsProxy boolValue]].address;
                        bool matches = false;
                        if (address != nil) {
                            for (MTDatacenterAddress *listAddress in addressSet.addressList) {
                                if ([listAddress.ip isEqualToString:address.ip]) {
                                    if (listAddress.secret != nil && address.secret != nil && [listAddress.secret isEqualToData:address.secret]) {
                                        matches = true;
                                    } else if (listAddress.secret == nil && address.secret == nil) {
                                        matches = true;
                                    }
                                }
                            }
                        }
                        if (!matches) {
                            if (MTLogEnabled()) {
                                MTLog(@"[MTContext#%x: updated address set for %d doesn't contain current %@, updating]", (int)self, datacenterId, address);
                            }
                            
                            [self updateTransportSchemeForDatacenterWithId:datacenterId transportScheme:[self defaultTransportSchemeForDatacenterWithId:datacenterId media:[nMedia boolValue] isProxy:[nIsProxy boolValue]] media:[nMedia boolValue] isProxy:[nIsProxy boolValue]];
                        }
                    }
                }*/
            }
            
            if (updateSchemes) {
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
                MTLog(@"[MTContext#%" PRIxPTR ": added address %@ for datacenter %d]", (intptr_t)self, address, datacenterId);
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

- (void)updateAuthInfoForDatacenterWithId:(NSInteger)datacenterId authInfo:(MTDatacenterAuthInfo *)authInfo selector:(MTDatacenterAuthInfoSelector)selector
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        if (datacenterId != 0)
        {
            NSNumber *infoKey = authInfoMapIntegerKey((int32_t)datacenterId, selector);
            
            bool wasNil = _datacenterAuthInfoById[infoKey] == nil;
            
            if (authInfo != nil) {
                _datacenterAuthInfoById[infoKey] = authInfo;
            } else {
                if (_datacenterAuthInfoById[infoKey] == nil) {
                    return;
                }
                [_datacenterAuthInfoById removeObjectForKey:infoKey];
            }
            
            if (MTLogEnabled()) {
                MTDatacenterAuthInfo *persistentInfo = _datacenterAuthInfoById[authInfoMapIntegerKey((int32_t)datacenterId, MTDatacenterAuthInfoSelectorPersistent)];
                
                MTLog(@"[MTContext#%" PRIxPTR ": auth info updated for %d selector %d to %@ (persistent key id is %llu)]", (intptr_t)self, datacenterId, selector, authInfo, persistentInfo.authKeyId);
            }
            
            [_keychain setObject:_datacenterAuthInfoById forKey:@"datacenterAuthInfoById" group:@"persistent"];
            
            NSArray *currentListeners = [[NSArray alloc] initWithArray:_changeListeners];
            
            for (id<MTContextChangeListener> listener in currentListeners)
            {
                if ([listener respondsToSelector:@selector(contextDatacenterAuthInfoUpdated:datacenterId:authInfo:selector:)])
                    [listener contextDatacenterAuthInfoUpdated:self datacenterId:datacenterId authInfo:authInfo selector:selector];
            }
            
            if (wasNil && authInfo != nil && selector == MTDatacenterAuthInfoSelectorPersistent) {
                for (NSNumber *key in _datacenterAuthActions) {
                    MTDatacenterAuthInfoMapKeyStruct parsedKey = parseAuthInfoMapKeyInteger(key);
                    if (parsedKey.datacenterId == datacenterId && parsedKey.selector != MTDatacenterAuthInfoSelectorPersistent) {
                        [_datacenterAuthActions[key] execute:self datacenterId:datacenterId];
                    }
                }
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

- (void)updateTransportSchemeForDatacenterWithId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme media:(bool)media isProxy:(bool)isProxy {
    [[MTContext contextQueue] dispatchOnQueue:^ {
        if (transportScheme != nil && datacenterId != 0) {
            _datacenterManuallySelectedSchemeById[[[MTTransportSchemeKey alloc] initWithDatacenterId:datacenterId isProxy:isProxy isMedia:media]] = transportScheme;
            [_keychain setObject:_datacenterManuallySelectedSchemeById forKey:@"datacenterManuallySelectedSchemeById_v1" group:@"persistent"];
            
            [self reportTransportSchemeSuccessForDatacenterId:datacenterId transportScheme:transportScheme];
            [self _withTransportSchemeStatsForDatacenterId:datacenterId transportScheme:transportScheme process:^MTTransportSchemeStats *(MTTransportSchemeStats *current) {
                current = [current withUpdatedLastFailureTimestamp:0];
                current = [current withUpdatedLastResponseTimestamp:(int32_t)CFAbsoluteTimeGetCurrent()];
                return current;
            }];
            
            NSArray *currentListeners = [[NSArray alloc] initWithArray:_changeListeners];
            
            if (MTLogEnabled()) {
                MTLog(@"[MTContext#%" PRIxPTR ": %@ transport scheme updated for %d: %@]", (intptr_t)self, media ? @"media" : @"generic", datacenterId, transportScheme);
            }
            
            for (id<MTContextChangeListener> listener in currentListeners) {
                if ([listener respondsToSelector:@selector(contextDatacenterTransportSchemesUpdated:datacenterId:shouldReset:)])
                    [listener contextDatacenterTransportSchemesUpdated:self datacenterId:datacenterId shouldReset:true];
            }
        }
    }];
}

- (void)scheduleSessionCleanupForAuthKeyId:(int64_t)authKeyId sessionInfo:(MTSessionInfo *)sessionInfo {
    [[MTContext contextQueue] dispatchOnQueue:^{
        return;
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
        MTDatacenterAddressSet *addressSet = _datacenterAddressSetById[@(datacenterId)];
        if (addressSet != nil && addressSet.addressList.count != 0) {
            result = _datacenterAddressSetById[@(datacenterId)];
        } else {
            result = _datacenterSeedAddressSetById[@(datacenterId)];
        }
    } synchronous:true];
    
    return result;
}

- (MTTransportScheme * _Nullable)chooseTransportSchemeForConnectionToDatacenterId:(NSInteger)datacenterId schemes:(NSArray<MTTransportScheme *> * _Nonnull)schemes {
    __block MTTransportScheme *result = nil;
    
    [[MTContext contextQueue] dispatchOnQueue:^{
        __block MTTransportScheme *schemeWithEarliestFailure = nil;
        __block int32_t earliestFailure = INT32_MAX;
        
        int32_t timestamp = (int32_t)CFAbsoluteTimeGetCurrent();
        __block bool scanIpv6 = false;
        for (MTTransportScheme *scheme in schemes) {
            if (scheme.address.isIpv6) {
                [self _withTransportSchemeStatsForDatacenterId:datacenterId transportScheme:scheme process:^MTTransportSchemeStats *(MTTransportSchemeStats *current) {
                    if (scheme.address.isIpv6 && current.lastResponseTimestamp > timestamp - 60 * 60) {
                        scanIpv6 = true;
                    }
                    return current;
                }];
            }
        }
        
        for (MTTransportScheme *scheme in schemes.reverseObjectEnumerator) {
            if (scheme.address.isIpv6 && !scanIpv6) {
                continue;
            }
            [self _withTransportSchemeStatsForDatacenterId:datacenterId transportScheme:scheme process:^MTTransportSchemeStats *(MTTransportSchemeStats *current) {
                if (schemeWithEarliestFailure == nil) {
                    schemeWithEarliestFailure = scheme;
                    earliestFailure = current.lastFailureTimestamp;
                } else if (earliestFailure > current.lastFailureTimestamp) {
                    earliestFailure = current.lastFailureTimestamp;
                    schemeWithEarliestFailure = scheme;
                }
                return current;
            }];
        }
        if (MTLogEnabled()) {
            MTLog(@"[MTContext has chosen a scheme for DC%d: %@]", datacenterId, schemeWithEarliestFailure);
        }
        result = schemeWithEarliestFailure;
    } synchronous:true];
    
    return result;
}

- (NSArray<MTTransportScheme *> * _Nonnull)transportSchemesForDatacenterWithId:(NSInteger)datacenterId media:(bool)media enforceMedia:(bool)enforceMedia isProxy:(bool)isProxy
{
    __block NSMutableArray <MTTransportScheme *> *results = [[NSMutableArray alloc] init];
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        MTDatacenterAddress *overrideAddress = _apiEnvironment.datacenterAddressOverrides[@(datacenterId)];
        if (overrideAddress != nil) {
            [results addObject:[[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:overrideAddress media:false]];
        } else {
            [results addObjectsFromArray:[self _allTransportSchemesForDatacenterWithId:datacenterId]];
        }
        MTTransportScheme *manualScheme = _datacenterManuallySelectedSchemeById[[[MTTransportSchemeKey alloc] initWithDatacenterId:datacenterId isProxy:isProxy isMedia:media]];
        if (manualScheme != nil && ![results containsObject:manualScheme]) {
            [results addObject:manualScheme];
        }
    } synchronous:true];
    
    for (int i = (int)(results.count - 1); i >= 0; i--) {
        if (enforceMedia && !results[i].address.preferForMedia) {
            [results removeObjectAtIndex:i];
        } else if (!media && results[i].address.preferForMedia) {
            [results removeObjectAtIndex:i];
        }
    }
    
    return results;
}

- (MTDatacenterAuthInfo *)authInfoForDatacenterWithId:(NSInteger)datacenterId selector:(MTDatacenterAuthInfoSelector)selector {
    __block MTDatacenterAuthInfo *result = nil;
    [[MTContext contextQueue] dispatchOnQueue:^{
        NSNumber *infoKey = authInfoMapIntegerKey((int32_t)datacenterId, selector);
        result = _datacenterAuthInfoById[infoKey];
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

- (void)removeTokenForDatacenterWithId:(NSInteger)datacenterId
{
    [[MTContext contextQueue] dispatchOnQueue:^{
        [_authTokenById removeObjectForKey:@(datacenterId)];
        [_keychain setObject:_authTokenById forKey:@"authTokenById" group:@"persistent"];
        
        MTDatacenterTransferAuthAction *action = _datacenterTransferAuthActions[@(datacenterId)];
        if (action != nil) {
            action.delegate = nil;
            [action cancel];
            [_datacenterTransferAuthActions removeObjectForKey:@(datacenterId)];
        }
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

- (NSArray<MTTransportScheme *> * _Nonnull)_allTransportSchemesForDatacenterWithId:(NSInteger)datacenterId {
    NSMutableArray<MTTransportScheme *> *result = [[NSMutableArray alloc] init];
    MTDatacenterAddressSet *addressSet = [self addressSetForDatacenterWithId:datacenterId];
    if (addressSet == nil) {
        [self addressSetForDatacenterWithIdRequired:datacenterId];
    } else {
        for (MTDatacenterAddress *address in addressSet.addressList) {
            [result addObject:[[MTTransportScheme alloc] initWithTransportClass:[MTTcpTransport class] address:address media:address.preferForMedia]];
        }
    }
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
            MTDatacenterAddressSet *initialAddressSet = [self addressSetForDatacenterWithId:datacenterId];
            NSMutableArray *addressList = [[NSMutableArray alloc] initWithArray:initialAddressSet.addressList];
            MTDatacenterAddressSet *seedAddress = _datacenterSeedAddressSetById[@(datacenterId)];
            if (seedAddress != nil) {
                for (MTDatacenterAddress *address in seedAddress.addressList) {
                    if (![addressList containsObject:address]) {
                        [addressList addObject:address];
                    }
                }
            }
            MTDatacenterAddressSet *addressSet = [[MTDatacenterAddressSet alloc] initWithAddressList:addressList];
            MTSignal *discoverSignal = [MTDiscoverConnectionSignals discoverSchemeWithContext:self datacenterId:datacenterId addressList:addressSet.addressList media:media isProxy:isProxy];
            MTSignal *conditionSignal = [MTSignal single:@(true)];
            for (id<MTContextChangeListener> listener in _changeListeners) {
                if ([listener respondsToSelector:@selector(isContextNetworkAccessAllowed:)]) {
                    MTSignal *signal = [listener isContextNetworkAccessAllowed:self];
                    if (signal != nil) {
                        conditionSignal = signal;
                    }
                }
            }
            MTSignal *filteredSignal = [[conditionSignal mapToSignal:^(NSNumber *value) {
                if ([value boolValue]) {
                    return discoverSignal;
                } else {
                    return [MTSignal never];
                }
            }] take:1];

            _transportSchemeDisposableByDatacenterId[@(datacenterId)] = [[filteredSignal onDispose:^
            {
                __strong MTContext *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    [[MTContext contextQueue] dispatchOnQueue:^
                    {
                        [strongSelf->_transportSchemeDisposableByDatacenterId removeObjectForKey:@(datacenterId)];
                    }];
                }
            }] startWithNext:^(MTTransportScheme *next)
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

- (void)_withTransportSchemeStatsForDatacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme process:(MTTransportSchemeStats * (^)(MTTransportSchemeStats *))process {
    NSAssert([[MTContext contextQueue] isCurrentQueue], @"[[MTContext contextQueue] isCurrentQueue]");
    if (_transportSchemeStats[@(datacenterId)] == nil) {
        _transportSchemeStats[@(datacenterId)] = [[NSMutableDictionary alloc] init];
    }
    MTTransportSchemeStats *current = _transportSchemeStats[@(datacenterId)][transportScheme.address];
    if (current == nil) {
        current = [[MTTransportSchemeStats alloc] initWithLastFailureTimestamp:0 lastResponseTimestamp:0];
    }
    MTTransportSchemeStats *updated = process(current);
    if (updated == nil || ![updated isEqual:current]) {
        if (updated == nil) {
            [_transportSchemeStats[@(datacenterId)] removeObjectForKey:transportScheme.address];
        } else {
            if (MTLogEnabled()) {
                //MTLog(@"Updated stats for %@: %@", transportScheme.address, updated);
            }
            _transportSchemeStats[@(datacenterId)][transportScheme.address] = updated;
        }
        [self _scheduleSyncTransportSchemeStats];
    }
}

- (void)_scheduleSyncTransportSchemeStats {
    NSAssert([[MTContext contextQueue] isCurrentQueue], @"[[MTContext contextQueue] isCurrentQueue]");
    if (_schemeStatsSyncTimer == nil) {
        __weak MTContext *weakSelf = self;
        _schemeStatsSyncTimer = [[MTTimer alloc] initWithTimeout:5.0 repeat:false completion:^{
            __strong MTContext *strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }
            strongSelf->_schemeStatsSyncTimer = nil;
            [strongSelf _syncTransportSchemeStats];
        } queue:[MTContext contextQueue].nativeQueue];
        [_schemeStatsSyncTimer start];
    }
}

- (void)_syncTransportSchemeStats {
    NSAssert([[MTContext contextQueue] isCurrentQueue], @"[[MTContext contextQueue] isCurrentQueue]");
    [_keychain setObject:_transportSchemeStats forKey:@"transportSchemeStats_v1" group:@"temp"];
}

- (void)reportTransportSchemeFailureForDatacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme {
    [[MTContext contextQueue] dispatchOnQueue:^{
        [self _withTransportSchemeStatsForDatacenterId:datacenterId transportScheme:transportScheme process:^(MTTransportSchemeStats *current) {
            return [current withUpdatedLastFailureTimestamp:(int32_t)CFAbsoluteTimeGetCurrent()];
        }];
    }];
}

- (void)reportTransportSchemeSuccessForDatacenterId:(NSInteger)datacenterId transportScheme:(MTTransportScheme *)transportScheme {
    [[MTContext contextQueue] dispatchOnQueue:^{
        [self _withTransportSchemeStatsForDatacenterId:datacenterId transportScheme:transportScheme process:^(MTTransportSchemeStats *current) {
            return [current withUpdatedLastResponseTimestamp:(int32_t)CFAbsoluteTimeGetCurrent()];
        }];
    }];
}

- (void)invalidateTransportSchemesForDatacenterIds:(NSArray<NSNumber *> * _Nonnull)datacenterIds {
    [[MTContext contextQueue] dispatchOnQueue:^{
        for (NSNumber *datacenterId in datacenterIds) {
            [self transportSchemeForDatacenterWithIdRequired:[datacenterId integerValue] moreOptimalThan:nil beginWithHttp:false media:false isProxy:_apiEnvironment.socksProxySettings != nil];
        }
    }];
}

- (void)invalidateTransportSchemesForKnownDatacenterIds {
    [[MTContext contextQueue] dispatchOnQueue:^{
        NSMutableSet *datacenterIds = [[NSMutableSet alloc] init];

        for (NSNumber *nId in _datacenterAddressSetById.allKeys) {
            [datacenterIds addObject:nId];
        }
        
        for (NSNumber *nId in _datacenterSeedAddressSetById.allKeys) {
            [datacenterIds addObject:nId];
        }
        
        for (NSNumber *datacenterId in datacenterIds) {
            [self transportSchemeForDatacenterWithIdRequired:[datacenterId integerValue] moreOptimalThan:nil beginWithHttp:false media:false isProxy:_apiEnvironment.socksProxySettings != nil];
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
        
        double delay = 20.0f;
        if (_apiEnvironment.networkSettings == nil || _apiEnvironment.networkSettings.reducedBackupDiscoveryTimeout) {
            delay = 5.0;
        }
        [self _beginBackupAddressDiscoveryWithDelay:delay];
    }];
}

- (void)_beginBackupAddressDiscoveryWithDelay:(double)delay {
    if (_backupAddressListDisposable == nil && _discoverBackupAddressListSignal != nil) {
        __weak MTContext *weakSelf = self;
        _backupAddressListDisposable = [[[_discoverBackupAddressListSignal delay:delay onQueue:[MTQueue mainQueue]] onDispose:^{
            __strong MTContext *strongSelf = weakSelf;
            if (strongSelf != nil) {
                [strongSelf->_backupAddressListDisposable dispose];
                strongSelf->_backupAddressListDisposable = nil;
            }
        }] startWithNext:nil];
    }
}

- (void)beginExplicitBackupAddressDiscovery {
    [[MTContext contextQueue] dispatchOnQueue:^{
        [_backupAddressListDisposable dispose];
        _backupAddressListDisposable = nil;
        [self _beginBackupAddressDiscoveryWithDelay:0.0];
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

- (void)authInfoForDatacenterWithIdRequired:(NSInteger)datacenterId isCdn:(bool)isCdn selector:(MTDatacenterAuthInfoSelector)selector allowUnboundEphemeralKeys:(bool)allowUnboundEphemeralKeys
{
    [[MTContext contextQueue] dispatchOnQueue:^
    {
        NSNumber *infoKey = authInfoMapIntegerKey((int32_t)datacenterId, selector);
        
        if (_datacenterAuthActions[infoKey] == nil)
        {
            __weak MTContext *weakSelf = self;
            MTDatacenterAuthAction *authAction = [[MTDatacenterAuthAction alloc] initWithAuthKeyInfoSelector:selector isCdn:isCdn skipBind:allowUnboundEphemeralKeys completion:^(MTDatacenterAuthAction *action, __unused bool success) {
                [[MTContext contextQueue] dispatchOnQueue:^{
                    __strong MTContext *strongSelf = weakSelf;
                    if (strongSelf == nil) {
                        return;
                    }
                    
                    for (NSNumber *key in _datacenterAuthActions) {
                        if (_datacenterAuthActions[key] == action) {
                            [_datacenterAuthActions removeObjectForKey:key];
                            break;
                        }
                    }
                }];
            }];
            _datacenterAuthActions[infoKey] = authAction;
            
            switch (selector) {
                case MTDatacenterAuthInfoSelectorEphemeralMain:
                case MTDatacenterAuthInfoSelectorEphemeralMedia: {
                    if ([self authInfoForDatacenterWithId:datacenterId selector:MTDatacenterAuthInfoSelectorPersistent] == nil && !allowUnboundEphemeralKeys) {
                        [self authInfoForDatacenterWithIdRequired:datacenterId isCdn:false selector:MTDatacenterAuthInfoSelectorPersistent allowUnboundEphemeralKeys:false];
                    } else {
                        [authAction execute:self datacenterId:datacenterId];
                    }
                    break;
                }
                default: {
                    [authAction execute:self datacenterId:datacenterId];
                    break;
                }
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
        if (apiEnvironment != nil) {
            _apiEnvironment = apiEnvironment;
            
            NSArray *currentListeners = [[NSArray alloc] initWithArray:_changeListeners];
            for (id<MTContextChangeListener> listener in currentListeners)
            {
                if ([listener respondsToSelector:@selector(contextApiEnvironmentUpdated:apiEnvironment:)]) {
                    [listener contextApiEnvironmentUpdated:self apiEnvironment:apiEnvironment];
                }
            }
        }
    }];
}

- (void)updatePeriodicTasks
{
}

- (void)checkIfLoggedOut:(NSInteger)datacenterId {
    [[MTContext contextQueue] dispatchOnQueue:^{
        MTDatacenterAuthInfo *authInfo = [self authInfoForDatacenterWithId:datacenterId selector:MTDatacenterAuthInfoSelectorPersistent];
        if (authInfo == nil || authInfo.authKey == nil) {
            return;
        }
        
        int32_t timestamp = (int32_t)CFAbsoluteTimeGetCurrent();
        NSNumber *currentTimestamp = _datacenterCheckKeyRemovedActionTimestamps[@(datacenterId)];
        if (currentTimestamp == nil || [currentTimestamp intValue] + 60 < timestamp) {
            _datacenterCheckKeyRemovedActionTimestamps[@(datacenterId)] = currentTimestamp;
            [_datacenterCheckKeyRemovedActions[@(datacenterId)] dispose];
            __weak MTContext *weakSelf = self;
            _datacenterCheckKeyRemovedActions[@(datacenterId)] = [[MTDiscoverConnectionSignals checkIfAuthKeyRemovedWithContext:self datacenterId:datacenterId authKey:[[MTDatacenterAuthKey alloc] initWithAuthKey:authInfo.authKey authKeyId:authInfo.authKeyId notBound:false]] startWithNext:^(NSNumber* isRemoved) {
                [[MTContext contextQueue] dispatchOnQueue:^{
                    __strong MTContext *strongSelf = weakSelf;
                    if (strongSelf == nil) {
                        return;
                    }
                    
                    if ([isRemoved boolValue]) {
                        NSArray *currentListeners = [[NSArray alloc] initWithArray:strongSelf->_changeListeners];
                        for (id<MTContextChangeListener> listener in currentListeners) {
                            if ([listener respondsToSelector:@selector(contextLoggedOut:)])
                                [listener contextLoggedOut:strongSelf];
                        }
                    }
                }];
            }];
        }
    }];
}

@end
