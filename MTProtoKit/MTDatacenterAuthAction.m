#import "MTDatacenterAuthAction.h"

#import "MTContext.h"
#import "MTProto.h"
#import "MTRequest.h"
#import "MTDatacenterSaltInfo.h"
#import "MTDatacenterAuthInfo.h"

#import "MTDatacenterAuthMessageService.h"
#import "MTRequestMessageService.h"

#import "MTBuffer.h"

@interface MTDatacenterAuthAction () <MTDatacenterAuthMessageServiceDelegate>
{
    bool _tempAuth;
    
    NSInteger _datacenterId;
    __weak MTContext *_context;
    
    bool _awaitingAddresSetUpdate;
    MTProto *_authMtProto;
    
    MTContext *_bindContext;
    MTProto *_bindMtProto;
}

@end

@implementation MTDatacenterAuthAction

- (instancetype)initWithTempAuth:(bool)tempAuth {
    self = [super init];
    if (self != nil) {
        _tempAuth = tempAuth;
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
    
    if (_datacenterId != 0 && context != nil)
    {
        bool alreadyCompleted = false;
        MTDatacenterAuthInfo *currentAuthInfo = [context authInfoForDatacenterWithId:_datacenterId];
        if (currentAuthInfo != nil) {
            if (_tempAuth) {
                if (currentAuthInfo.tempAuthKey != nil) {
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
            
            MTDatacenterAuthMessageService *authService = [[MTDatacenterAuthMessageService alloc] initWithContext:context tempAuth:_tempAuth];
            authService.delegate = self;
            [_authMtProto addMessageService:authService];
        }
    }
    else
        [self fail];
}

- (void)authMessageServiceCompletedWithAuthKey:(MTDatacenterAuthKey *)authKey timestamp:(int64_t)timestamp
{
    if (_tempAuth) {
        MTContext *mainContext = _context;
        MTDatacenterAuthInfo *mainAuthInfo = [mainContext authInfoForDatacenterWithId:_datacenterId];
        if (mainContext != nil && mainAuthInfo != nil) {
            _bindContext = [[MTContext alloc] initWithSerialization:mainContext.serialization apiEnvironment:mainContext.apiEnvironment];
            [_bindContext updateAddressSetForDatacenterWithId:_datacenterId addressSet:[mainContext addressSetForDatacenterWithId:_datacenterId] forceUpdateSchemes:true];
            
            MTDatacenterAuthInfo *authInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:authKey.authKey authKeyId:authKey.authKeyId saltSet:@[[[MTDatacenterSaltInfo alloc] initWithSalt:0 firstValidMessageId:((int64_t)timestamp) * 4294967296 lastValidMessageId:((int64_t)(timestamp + 29.0 * 60.0)) * 4294967296]] authKeyAttributes:nil tempAuthKey:nil];
            [_bindContext updateAuthInfoForDatacenterWithId:_datacenterId authInfo:authInfo];
            _bindMtProto = [[MTProto alloc] initWithContext:_bindContext datacenterId:_datacenterId usageCalculationInfo:nil];
            
            MTRequestMessageService *requestService = [[MTRequestMessageService alloc] initWithContext:_bindContext];
            [_bindMtProto addMessageService:requestService];
            
            __weak MTDatacenterAuthAction *weakSelf = self;
            [_bindMtProto bindToPersistentKey:[[MTDatacenterAuthKey alloc] initWithAuthKey:mainAuthInfo.authKey authKeyId:mainAuthInfo.authKeyId] completion:^{
                __strong MTDatacenterAuthAction *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    MTContext *context = _context;
                    [context performBatchUpdates:^{
                        MTDatacenterAuthInfo *authInfo = [context authInfoForDatacenterWithId:strongSelf->_datacenterId];
                        authInfo = [authInfo withUpdatedTempAuthKey:authKey];
                        [context updateAuthInfoForDatacenterWithId:strongSelf->_datacenterId authInfo:authInfo];
                    }];
                    [self complete];
                }
            }];
        }
    } else {
        MTDatacenterAuthInfo *authInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:authKey.authKey authKeyId:authKey.authKeyId saltSet:@[[[MTDatacenterSaltInfo alloc] initWithSalt:0 firstValidMessageId:((int64_t)timestamp) * 4294967296 lastValidMessageId:((int64_t)(timestamp + 29.0 * 60.0)) * 4294967296]] authKeyAttributes:nil tempAuthKey:nil];
        
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
