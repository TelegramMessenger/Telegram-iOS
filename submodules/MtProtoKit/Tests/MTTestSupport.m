#import "MTTestSupport.h"

#import <os/lock.h>

#import <MtProtoKit/MTApiEnvironment.h>
#import <MtProtoKit/MTDatacenterAddress.h>
#import <MtProtoKit/MTDatacenterAddressSet.h>
#import <MtProtoKit/MTDatacenterSaltInfo.h>
#import <MtProtoKit/MTSerialization.h>

bool MTTestWaitUntil(NSTimeInterval timeout, bool (^condition)(void)) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    while (!condition()) {
        if ([deadline timeIntervalSinceNow] <= 0.0) {
            return condition();
        }
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    return true;
}

@interface MTTestSerialization : NSObject <MTSerialization>
@end

@implementation MTTestSerialization

- (NSUInteger)currentLayer {
    return 0;
}

- (id)parseMessage:(NSData *)data {
    return nil;
}

- (MTExportAuthorizationResponseParser)exportAuthorization:(int32_t)datacenterId data:(__autoreleasing NSData **)data {
    return nil;
}

- (NSData *)importAuthorization:(int64_t)authId bytes:(NSData *)bytes {
    return nil;
}

- (MTRequestDatacenterAddressListParser)requestDatacenterAddressWithData:(__autoreleasing NSData **)data {
    return nil;
}

- (MTRequestNoopParser)requestNoop:(__autoreleasing NSData **)data {
    return nil;
}

@end

MTContext *MTTestMakeContext(bool useTempAuthKeys) {
    // The encryption provider is only reached once a connection exchanges
    // messages; these connections never get that far.
    id<EncryptionProvider> encryptionProvider = (id<EncryptionProvider>)[[NSObject alloc] init];
    return MTTestMakeContextWithEncryptionProvider(useTempAuthKeys, encryptionProvider);
}

MTContext *MTTestMakeContextWithEncryptionProvider(bool useTempAuthKeys, id<EncryptionProvider> encryptionProvider) {
    return [[MTContext alloc] initWithSerialization:[[MTTestSerialization alloc] init] encryptionProvider:encryptionProvider apiEnvironment:[[MTApiEnvironment alloc] init] isTestingEnvironment:true useTempAuthKeys:useTempAuthKeys];
}

MTDatacenterAuthInfo *MTTestMakeAuthInfo(void) {
    NSMutableData *authKey = [[NSMutableData alloc] initWithLength:256];
    arc4random_buf(authKey.mutableBytes, authKey.length);
    int64_t authKeyId = 0;
    arc4random_buf(&authKeyId, sizeof(authKeyId));
    return [[MTDatacenterAuthInfo alloc] initWithAuthKey:authKey authKeyId:authKeyId validUntilTimestamp:INT32_MAX saltSet:@[[[MTDatacenterSaltInfo alloc] initWithSalt:0 firstValidMessageId:0 lastValidMessageId:INT64_MAX]] authKeyAttributes:nil];
}

MTDatacenterAddress *MTTestMakeAddress(bool preferForMedia) {
    return [[MTDatacenterAddress alloc] initWithIp:@"127.0.0.1" port:1 preferForMedia:preferForMedia restrictToTcp:false cdn:false preferForProxy:false secret:nil];
}

void MTTestSetAddress(MTContext *context, NSInteger datacenterId, bool preferForMedia) {
    [context updateAddressSetForDatacenterWithId:datacenterId addressSet:[[MTDatacenterAddressSet alloc] initWithAddressList:@[MTTestMakeAddress(preferForMedia)]] forceUpdateSchemes:false];
}

void MTTestOnManagerQueue(dispatch_block_t block) {
    [[MTProto managerQueue] dispatchOnQueue:block synchronous:true];
}

bool MTTestIsWaiting(MTProto *proto) {
    __block bool result = false;
    MTTestOnManagerQueue(^{
        result = ![proto canAskForServiceTransactions];
    });
    return result;
}

@implementation MTTestTransferAuthAction {
    __weak MTContext *_context;
    id _authToken;
    void (^_onExecute)(MTTestTransferAuthAction *);
}

- (instancetype)initWithOnExecute:(void (^)(MTTestTransferAuthAction *))onExecute {
    self = [super init];
    if (self != nil) {
        _onExecute = [onExecute copy];
    }
    return self;
}

- (void)execute:(MTContext *)context masterDatacenterId:(NSInteger)masterDatacenterId destinationDatacenterId:(NSInteger)destinationDatacenterId authToken:(id)authToken {
    _context = context;
    _destinationDatacenterId = destinationDatacenterId;
    _authToken = authToken;
    _onExecute(self);
}

- (void)succeed {
    [_context updateAuthTokenForDatacenterWithId:_destinationDatacenterId authToken:_authToken];
    [self complete];
}

- (void)failWithError {
    [self fail];
}

@end

@implementation MTTestAuthAction {
    __weak MTContext *_context;
    void (^_onExecute)(MTTestAuthAction *);
}

- (instancetype)initWithSelector:(MTDatacenterAuthInfoSelector)selector completion:(void (^)(MTDatacenterAuthAction *, bool))completion onExecute:(void (^)(MTTestAuthAction *))onExecute {
    self = [super initWithAuthKeyInfoSelector:selector isCdn:false skipBind:false completion:completion];
    if (self != nil) {
        _selector = selector;
        _onExecute = [onExecute copy];
    }
    return self;
}

- (void)execute:(MTContext *)context datacenterId:(NSInteger)datacenterId {
    _context = context;
    _datacenterId = datacenterId;
    _onExecute(self);
}

- (void)succeed {
    [_context updateAuthInfoForDatacenterWithId:_datacenterId authInfo:MTTestMakeAuthInfo() selector:_selector];
    [self complete];
}

- (void)failWithBindError:(MTRpcError *)error {
    self.bindError = error;
    [self fail];
}

@end

@implementation MTTestActionRecorder {
    os_unfair_lock _lock;
    NSMutableArray<MTTestTransferAuthAction *> *_transfers;
    NSMutableArray<MTTestAuthAction *> *_authActions;
}

- (instancetype)initWithContext:(MTContext *)context {
    self = [super init];
    if (self != nil) {
        _lock = OS_UNFAIR_LOCK_INIT;
        _transfers = [[NSMutableArray alloc] init];
        _authActions = [[NSMutableArray alloc] init];

        __weak MTTestActionRecorder *weakSelf = self;
        context.transferAuthActionFactory = ^MTDatacenterTransferAuthAction *{
            return [[MTTestTransferAuthAction alloc] initWithOnExecute:^(MTTestTransferAuthAction *action) {
                MTTestActionRecorder *strongSelf = weakSelf;
                if (strongSelf == nil) {
                    return;
                }
                os_unfair_lock_lock(&strongSelf->_lock);
                [strongSelf->_transfers addObject:action];
                os_unfair_lock_unlock(&strongSelf->_lock);
            }];
        };
        context.authActionFactory = ^MTDatacenterAuthAction *(MTDatacenterAuthInfoSelector selector, __unused bool isCdn, __unused bool skipBind, void (^completion)(MTDatacenterAuthAction *, bool)) {
            return [[MTTestAuthAction alloc] initWithSelector:selector completion:completion onExecute:^(MTTestAuthAction *action) {
                MTTestActionRecorder *strongSelf = weakSelf;
                if (strongSelf == nil) {
                    return;
                }
                os_unfair_lock_lock(&strongSelf->_lock);
                [strongSelf->_authActions addObject:action];
                os_unfair_lock_unlock(&strongSelf->_lock);
            }];
        };
    }
    return self;
}

- (NSUInteger)transferCount {
    os_unfair_lock_lock(&_lock);
    NSUInteger count = _transfers.count;
    os_unfair_lock_unlock(&_lock);
    return count;
}

- (MTTestTransferAuthAction *)transferAtIndex:(NSUInteger)index {
    os_unfair_lock_lock(&_lock);
    MTTestTransferAuthAction *action = _transfers[index];
    os_unfair_lock_unlock(&_lock);
    return action;
}

- (bool)waitForTransferCount:(NSUInteger)count timeout:(NSTimeInterval)timeout {
    return MTTestWaitUntil(timeout, ^bool{
        return [self transferCount] >= count;
    });
}

- (NSUInteger)authActionCount {
    os_unfair_lock_lock(&_lock);
    NSUInteger count = _authActions.count;
    os_unfair_lock_unlock(&_lock);
    return count;
}

- (MTTestAuthAction *)authActionAtIndex:(NSUInteger)index {
    os_unfair_lock_lock(&_lock);
    MTTestAuthAction *action = _authActions[index];
    os_unfair_lock_unlock(&_lock);
    return action;
}

- (bool)waitForAuthActionCount:(NSUInteger)count timeout:(NSTimeInterval)timeout {
    return MTTestWaitUntil(timeout, ^bool{
        return [self authActionCount] >= count;
    });
}

@end

@implementation MTTestProtoObserver {
    os_unfair_lock _lock;
    bool _hasTransport;
}

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _lock = OS_UNFAIR_LOCK_INIT;
    }
    return self;
}

- (void)mtProtoConnectionStateChanged:(MTProto *)mtProto state:(MTProtoConnectionState *)state {
    os_unfair_lock_lock(&_lock);
    _hasTransport = state != nil;
    os_unfair_lock_unlock(&_lock);
}

- (bool)hasTransport {
    os_unfair_lock_lock(&_lock);
    bool result = _hasTransport;
    os_unfair_lock_unlock(&_lock);
    return result;
}

@end
