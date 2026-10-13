#import <MtProtoKit/MTDatacenterAuthAction.h>

#import <stdatomic.h>

#import <MtProtoKit/MTLogging.h>
#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTProto.h>
#import <MtProtoKit/MTRequest.h>
#import <MtProtoKit/MTDatacenterSaltInfo.h>
#import <MtProtoKit/MTDatacenterAuthInfo.h>
#import <MtProtoKit/MTApiEnvironment.h>
#import <MtProtoKit/MTSerialization.h>
#import <MtProtoKit/MTDatacenterAddressSet.h>
#import <MtProtoKit/MTSignal.h>
#import <MtProtoKit/MTDatacenterAuthMessageService.h>
#import <MtProtoKit/MTRequestMessageService.h>
#import <MtProtoKit/MTBindKeyMessageService.h>
#import <MtProtoKit/MTRpcError.h>
#import <MtProtoKit/MTTimer.h>
#import <MtProtoKit/MTQueue.h>
#import "MTBuffer.h"
#import "MTInternalInterfaces.h"

@interface MTDatacenterAuthAction () <MTDatacenterAuthMessageServiceDelegate>
{
    void (^_completion)(MTDatacenterAuthAction *, bool);
    
    bool _isCdn;
    bool _skipBind;
    MTDatacenterAuthInfoSelector _authKeyInfoSelector;
    
    NSInteger _datacenterId;
    __weak MTContext *_context;
    
    bool _awaitingAddresSetUpdate;
    MTProto *_authMtProto;
    MTProto *_bindMtProto;
    NSUInteger _bindAttempts;
    MTTimer *_bindRetryTimer;
    atomic_bool _cancelled;
}

@end

@implementation MTDatacenterAuthAction

+ (bool)bindErrorMeansPermanentKeyIsUnknown:(MTRpcError *)bindError {
    return bindError != nil && bindError.errorCode == 400 && [bindError.errorDescription isEqualToString:@"ENCRYPTED_MESSAGE_INVALID"];
}

+ (bool)bindErrorIsTransient:(MTRpcError *)bindError {
    return bindError != nil && (bindError.errorCode >= 500 || bindError.errorCode == 420);
}

- (instancetype)initWithAuthKeyInfoSelector:(MTDatacenterAuthInfoSelector)authKeyInfoSelector isCdn:(bool)isCdn skipBind:(bool)skipBind completion:(void (^)(MTDatacenterAuthAction *, bool))completion {
    self = [super init];
    if (self != nil) {
        _authKeyInfoSelector = authKeyInfoSelector;
        _isCdn = isCdn;
        _skipBind = skipBind;
        _completion = [completion copy];
    }
    return self;
}

- (void)dealloc {
    [self cleanup];
}

- (void)execute:(MTContext *)context datacenterId:(NSInteger)datacenterId {
    _datacenterId = datacenterId;
    _context = context;
    
    if (_datacenterId != 0 && context != nil)
    {
        bool alreadyCompleted = false;
        
        MTDatacenterAuthInfo *currentAuthInfo = [context authInfoForDatacenterWithId:_datacenterId selector:_authKeyInfoSelector];
        if (currentAuthInfo != nil && !self.replacesExistingKey) {
            alreadyCompleted = true;
        }
        
        if (alreadyCompleted) {
            [self complete];
        } else {
            _authMtProto = [[MTProto alloc] initWithContext:context datacenterId:_datacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
            _authMtProto.cdn = _isCdn;
            _authMtProto.useUnauthorizedMode = true;
            bool tempAuth = false;
            switch (_authKeyInfoSelector) {
                case MTDatacenterAuthInfoSelectorEphemeralMain:
                    tempAuth = true;
                    _authMtProto.media = false;
                    break;
                case MTDatacenterAuthInfoSelectorEphemeralMedia:
                    tempAuth = true;
                    _authMtProto.media = true;
                    _authMtProto.enforceMedia = true;
                    break;
                default:
                    break;
            }
            
            MTDatacenterAuthMessageService *authService = [[MTDatacenterAuthMessageService alloc] initWithContext:context tempAuth:tempAuth];
            authService.delegate = self;
            [_authMtProto addMessageService:authService];
            
            [_authMtProto resume];
        }
    }
    else
        [self fail];
}

- (void)authMessageServiceCompletedWithAuthKey:(MTDatacenterAuthKey *)authKey timestamp:(int64_t)timestamp serverSalt:(int64_t)serverSalt {
    [self completeWithAuthKey:authKey timestamp:timestamp serverSalt:serverSalt];
}

- (void)completeWithAuthKey:(MTDatacenterAuthKey *)authKey timestamp:(int64_t)timestamp serverSalt:(int64_t)serverSalt {
    if (MTLogEnabled()) {
        MTLog(@"[MTDatacenterAuthAction#%p@%p: completeWithAuthKey %lld selector %d]", self, _context, authKey.authKeyId, _authKeyInfoSelector);
    }
    
    switch (_authKeyInfoSelector) {
        case MTDatacenterAuthInfoSelectorPersistent: {
            MTDatacenterAuthInfo *authInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:authKey.authKey authKeyId:authKey.authKeyId validUntilTimestamp:INT32_MAX saltSet:@[[[MTDatacenterSaltInfo alloc] initWithSalt:serverSalt firstValidMessageId:timestamp lastValidMessageId:timestamp + (29.0 * 60.0) * 4294967296]] authKeyAttributes:nil];
            
            MTContext *context = _context;
            [context updateAuthInfoForDatacenterWithId:_datacenterId authInfo:authInfo selector:_authKeyInfoSelector];
            [self complete];
        }
        break;
            
        case MTDatacenterAuthInfoSelectorEphemeralMain:
        case MTDatacenterAuthInfoSelectorEphemeralMedia: {
            MTContext *mainContext = _context;
            if (mainContext != nil) {
                if (_skipBind) {
                    MTDatacenterAuthInfo *authInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:authKey.authKey authKeyId:authKey.authKeyId validUntilTimestamp:authKey.validUntilTimestamp saltSet:@[[[MTDatacenterSaltInfo alloc] initWithSalt:serverSalt firstValidMessageId:timestamp lastValidMessageId:timestamp + (29.0 * 60.0) * 4294967296]] authKeyAttributes:nil];
                    
                    [_context updateAuthInfoForDatacenterWithId:_datacenterId authInfo:authInfo selector:_authKeyInfoSelector];
                    
                    [self complete];
                } else {
                    MTDatacenterAuthInfo *persistentAuthInfo = [mainContext authInfoForDatacenterWithId:_datacenterId selector:MTDatacenterAuthInfoSelectorPersistent];
                    if (persistentAuthInfo != nil) {
                        _bindAttempts = 0;
                        [self bindAuthKey:authKey persistentAuthInfo:persistentAuthInfo timestamp:timestamp serverSalt:serverSalt connection:[_authMtProto takeConnectionForReusing]];
                    } else {
                        if (MTLogEnabled()) {
                            MTLog(@"[MTDatacenterAuthAction#%p@%p: no persistent key to bind %lld to]", self, _context, authKey.authKeyId);
                        }
                        [self fail];
                    }
                }
            }
        }
        break;
            
        default:
            assert(false);
            break;
    }
}

- (void)bindAuthKey:(MTDatacenterAuthKey *)authKey persistentAuthInfo:(MTDatacenterAuthInfo *)persistentAuthInfo timestamp:(int64_t)timestamp serverSalt:(int64_t)serverSalt connection:(id)connection {
    MTContext *context = _context;
    if (context == nil || atomic_load(&_cancelled)) {
        return;
    }
    _bindAttempts += 1;
    
    _bindMtProto = [[MTProto alloc] initWithContext:context datacenterId:_datacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
    _bindMtProto.cdn = false;
    _bindMtProto.useUnauthorizedMode = false;
    _bindMtProto.useTempAuthKeys = true;
    _bindMtProto.useExplicitAuthKey = authKey;
    _bindMtProto.tempConnectionForReuse = connection;
    
    switch (_authKeyInfoSelector) {
        case MTDatacenterAuthInfoSelectorEphemeralMain:
            _bindMtProto.media = false;
            break;
        case MTDatacenterAuthInfoSelectorEphemeralMedia:
            _bindMtProto.media = true;
            _bindMtProto.enforceMedia = true;
            break;
        default:
            break;
    }
    
    __weak MTDatacenterAuthAction *weakSelf = self;
    [_bindMtProto addMessageService:[[MTBindKeyMessageService alloc] initWithPersistentKey:[[MTDatacenterAuthKey alloc] initWithAuthKey:persistentAuthInfo.authKey authKeyId:persistentAuthInfo.authKeyId validUntilTimestamp:persistentAuthInfo.validUntilTimestamp notBound:false] ephemeralKey:authKey completion:^(bool success, MTRpcError *error) {
        __strong MTDatacenterAuthAction *strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        MTProto *bindMtProto = strongSelf->_bindMtProto;
        strongSelf->_bindMtProto = nil;
        [bindMtProto stop];
        
        if (success) {
            MTDatacenterAuthInfo *authInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:authKey.authKey authKeyId:authKey.authKeyId validUntilTimestamp:authKey.validUntilTimestamp saltSet:@[[[MTDatacenterSaltInfo alloc] initWithSalt:serverSalt firstValidMessageId:timestamp lastValidMessageId:timestamp + (29.0 * 60.0) * 4294967296]] authKeyAttributes:nil];
            
            [strongSelf->_context updateAuthInfoForDatacenterWithId:strongSelf->_datacenterId authInfo:authInfo selector:strongSelf->_authKeyInfoSelector];
            
            [strongSelf complete];
        } else if ([MTDatacenterAuthAction bindErrorIsTransient:error] && strongSelf->_bindAttempts < 3 && !atomic_load(&strongSelf->_cancelled)) {
            NSTimeInterval delay = (NSTimeInterval)strongSelf->_bindAttempts;
            if (MTLogEnabled()) {
                MTLog(@"[MTDatacenterAuthAction#%p: bind of %lld failed with %d %@, binding the same key again in %.0f s]", strongSelf, authKey.authKeyId, (int)error.errorCode, error.errorDescription, delay);
            }
            [strongSelf->_bindRetryTimer invalidate];
            strongSelf->_bindRetryTimer = [[MTTimer alloc] initWithTimeout:delay repeat:false completion:^{
                __strong MTDatacenterAuthAction *retrySelf = weakSelf;
                if (retrySelf == nil) {
                    return;
                }
                retrySelf->_bindRetryTimer = nil;
                [retrySelf bindAuthKey:authKey persistentAuthInfo:persistentAuthInfo timestamp:timestamp serverSalt:serverSalt connection:nil];
            } queue:[MTProto managerQueue].nativeQueue];
            [strongSelf->_bindRetryTimer start];
        } else {
            strongSelf.bindError = error;
            [strongSelf fail];
        }
    }]];
    [_bindMtProto resume];
}

- (void)cleanup
{
    [_bindRetryTimer invalidate];
    _bindRetryTimer = nil;
    
    MTProto *authMtProto = _authMtProto;
    _authMtProto = nil;
    
    [authMtProto stop];
    
    MTProto *bindMtProto = _bindMtProto;
    _bindMtProto = nil;
    
    [bindMtProto stop];
}

- (void)cancel
{
    atomic_store(&_cancelled, true);
    [self cleanup];
}

- (void)complete {
    if (_completion) {
        _completion(self, true);
    }
}

- (void)fail
{
    if (_completion) {
        _completion(self, false);
    }
}

@end
