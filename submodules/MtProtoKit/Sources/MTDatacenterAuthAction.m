#import <MtProtoKit/MTDatacenterAuthAction.h>

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
#import "MTBuffer.h"

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
}

@end

@implementation MTDatacenterAuthAction

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
        if (currentAuthInfo != nil) {
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

- (void)authMessageServiceCompletedWithAuthKey:(MTDatacenterAuthKey *)authKey timestamp:(int64_t)timestamp {
    [self completeWithAuthKey:authKey timestamp:timestamp];
}

- (void)completeWithAuthKey:(MTDatacenterAuthKey *)authKey timestamp:(int64_t)timestamp {
    if (MTLogEnabled()) {
        MTLog(@"[MTDatacenterAuthAction#%p@%p: completeWithAuthKey %lld selector %d]", self, _context, authKey.authKeyId, _authKeyInfoSelector);
    }
    
    switch (_authKeyInfoSelector) {
        case MTDatacenterAuthInfoSelectorPersistent: {
            MTDatacenterAuthInfo *authInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:authKey.authKey authKeyId:authKey.authKeyId saltSet:@[[[MTDatacenterSaltInfo alloc] initWithSalt:0 firstValidMessageId:timestamp lastValidMessageId:timestamp + (29.0 * 60.0) * 4294967296]] authKeyAttributes:nil];
            
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
                    MTDatacenterAuthInfo *authInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:authKey.authKey authKeyId:authKey.authKeyId saltSet:@[[[MTDatacenterSaltInfo alloc] initWithSalt:0 firstValidMessageId:timestamp lastValidMessageId:timestamp + (29.0 * 60.0) * 4294967296]] authKeyAttributes:nil];
                    
                    [_context updateAuthInfoForDatacenterWithId:_datacenterId authInfo:authInfo selector:_authKeyInfoSelector];
                    
                    [self complete];
                } else {
                    MTDatacenterAuthInfo *persistentAuthInfo = [mainContext authInfoForDatacenterWithId:_datacenterId selector:MTDatacenterAuthInfoSelectorPersistent];
                    if (persistentAuthInfo != nil) {
                        _bindMtProto = [[MTProto alloc] initWithContext:mainContext datacenterId:_datacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
                        _bindMtProto.cdn = false;
                        _bindMtProto.useUnauthorizedMode = false;
                        _bindMtProto.useTempAuthKeys = true;
                        _bindMtProto.useExplicitAuthKey = authKey;
                        
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
                        [_bindMtProto addMessageService:[[MTBindKeyMessageService alloc] initWithPersistentKey:[[MTDatacenterAuthKey alloc] initWithAuthKey:persistentAuthInfo.authKey authKeyId:persistentAuthInfo.authKeyId notBound:false] ephemeralKey:authKey completion:^(bool success) {
                            __strong MTDatacenterAuthAction *strongSelf = weakSelf;
                            if (strongSelf == nil) {
                                return;
                            }
                            [strongSelf->_bindMtProto stop];
                            
                            if (success) {
                                MTDatacenterAuthInfo *authInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:authKey.authKey authKeyId:authKey.authKeyId saltSet:@[[[MTDatacenterSaltInfo alloc] initWithSalt:0 firstValidMessageId:timestamp lastValidMessageId:timestamp + (29.0 * 60.0) * 4294967296]] authKeyAttributes:nil];
                                
                                [strongSelf->_context updateAuthInfoForDatacenterWithId:strongSelf->_datacenterId authInfo:authInfo selector:strongSelf->_authKeyInfoSelector];
                                
                                [strongSelf complete];
                            } else {
                                [strongSelf fail];
                            }
                        }]];
                        [_bindMtProto resume];
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

- (void)cleanup
{
    MTProto *authMtProto = _authMtProto;
    _authMtProto = nil;
    
    [authMtProto stop];
    
    MTProto *bindMtProto = _bindMtProto;
    _bindMtProto = nil;
    
    [bindMtProto stop];
}

- (void)cancel
{
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
