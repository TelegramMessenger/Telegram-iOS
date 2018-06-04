#import "MTDatacenterAuthAction.h"

#import "MTLogging.h"
#import "MTContext.h"
#import "MTProto.h"
#import "MTRequest.h"
#import "MTDatacenterSaltInfo.h"
#import "MTDatacenterAuthInfo.h"
#import "MTApiEnvironment.h"
#import "MTSerialization.h"
#import "MTDatacenterAddressSet.h"

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTSignal.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTSignal.h>
#else
#   import <MTProtoKit/MTSignal.h>
#endif

#import "MTDatacenterAuthMessageService.h"
#import "MTRequestMessageService.h"

#import "MTBuffer.h"

@interface MTDatacenterAuthAction () <MTDatacenterAuthMessageServiceDelegate>
{
    bool _isCdn;
    MTDatacenterAuthTempKeyType _tempAuthKeyType;
    
    NSInteger _datacenterId;
    __weak MTContext *_context;
    
    bool _awaitingAddresSetUpdate;
    MTProto *_authMtProto;
    
    MTMetaDisposable *_verifyDisposable;
}

@end

@implementation MTDatacenterAuthAction

- (instancetype)initWithTempAuth:(bool)tempAuth tempAuthKeyType:(MTDatacenterAuthTempKeyType)tempAuthKeyType {
    self = [super init];
    if (self != nil) {
        _tempAuth = tempAuth;
        _tempAuthKeyType = tempAuthKeyType;
        _verifyDisposable = [[MTMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [self cleanup];
}

- (void)execute:(MTContext *)context datacenterId:(NSInteger)datacenterId isCdn:(bool)isCdn
{
    _datacenterId = datacenterId;
    _context = context;
    _isCdn = isCdn;
    
    if (_datacenterId != 0 && context != nil)
    {
        bool alreadyCompleted = false;
        MTDatacenterAuthInfo *currentAuthInfo = [context authInfoForDatacenterWithId:_datacenterId];
        if (currentAuthInfo != nil) {
            if (_tempAuth) {
                if ([currentAuthInfo tempAuthKeyWithType:_tempAuthKeyType] != nil) {
                    alreadyCompleted = true;
                }
            } else {
                alreadyCompleted = true;
            }
        }
        
        if (alreadyCompleted) {
            [self complete];
        } else {
            _authMtProto = [[MTProto alloc] initWithContext:context datacenterId:_datacenterId usageCalculationInfo:nil];
            _authMtProto.cdn = isCdn;
            _authMtProto.useUnauthorizedMode = true;
            if (_tempAuth) {
                switch (_tempAuthKeyType) {
                    case MTDatacenterAuthTempKeyTypeMain:
                        _authMtProto.media = false;
                        break;
                    case MTDatacenterAuthTempKeyTypeMedia:
                        _authMtProto.media = true;
                        _authMtProto.enforceMedia = true;
                        break;
                    default:
                        break;
                }
            }
            
            MTDatacenterAuthMessageService *authService = [[MTDatacenterAuthMessageService alloc] initWithContext:context tempAuth:_tempAuth];
            authService.delegate = self;
            [_authMtProto addMessageService:authService];
        }
    }
    else
        [self fail];
}

- (void)authMessageServiceCompletedWithAuthKey:(MTDatacenterAuthKey *)authKey timestamp:(int64_t)timestamp {
    [self completeWithAuthKey:authKey timestamp:timestamp];
}

- (void)completeWithAuthKey:(MTDatacenterAuthKey *)authKey timestamp:(int64_t)timestamp {
    if (_tempAuth) {
        MTContext *mainContext = _context;
        if (mainContext != nil) {
            MTContext *context = _context;
            [context performBatchUpdates:^{
                MTDatacenterAuthInfo *authInfo = [context authInfoForDatacenterWithId:_datacenterId];
                if (authInfo != nil) {
                    authInfo = [authInfo withUpdatedTempAuthKeyWithType:_tempAuthKeyType key:authKey];
                    [context updateAuthInfoForDatacenterWithId:_datacenterId authInfo:authInfo];
                }
            }];
            [self complete];
        }
    } else {
        MTDatacenterAuthInfo *authInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:authKey.authKey authKeyId:authKey.authKeyId saltSet:@[[[MTDatacenterSaltInfo alloc] initWithSalt:0 firstValidMessageId:timestamp lastValidMessageId:timestamp + (29.0 * 60.0) * 4294967296]] authKeyAttributes:nil mainTempAuthKey:nil mediaTempAuthKey:nil];
        
        MTContext *context = _context;
        [context updateAuthInfoForDatacenterWithId:_datacenterId authInfo:authInfo];
        [self complete];
    }
}

- (void)cleanup
{
    MTProto *authMtProto = _authMtProto;
    _authMtProto = nil;
    
    [authMtProto stop];
    
    [_verifyDisposable dispose];
}

- (void)cancel
{
    [self cleanup];
    [self fail];
}

- (void)complete
{
    id<MTDatacenterAuthActionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(datacenterAuthActionCompleted:)])
        [delegate datacenterAuthActionCompleted:self];
}

- (void)fail
{
    id<MTDatacenterAuthActionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(datacenterAuthActionCompleted:)])
        [delegate datacenterAuthActionCompleted:self];
}

@end
