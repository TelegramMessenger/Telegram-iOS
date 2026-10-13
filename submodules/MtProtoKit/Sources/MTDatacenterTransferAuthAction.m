

#import <MtProtoKit/MTDatacenterTransferAuthAction.h>

#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTSerialization.h>
#import <MtProtoKit/MTProto.h>
#import <MtProtoKit/MTRequestMessageService.h>
#import <MtProtoKit/MTRequest.h>
#import <MtProtoKit/MTRequestErrorContext.h>
#import "MTBuffer.h"
#import "MTInternalInterfaces.h"

@interface MTDatacenterTransferAuthAction () <MTContextChangeListener>
{
    id _authToken;
    
    MTProto *_sourceDatacenterMtProto;
    
    NSInteger _destinationDatacenterId;
    MTProto *_destinationDatacenterMtProto;
    
    __weak MTContext *_context;
}

@end

@implementation MTDatacenterTransferAuthAction

+ (void)applyRetryPolicyToRequest:(MTRequest *)request {
    // The policy TelegramCore gives every API request: MTRequestMessageService
    // retries a 500 after a delay and waits out a FLOOD_WAIT. Without it the
    // first 500 fails the transfer, and a brief inter-DC outage on the master
    // datacenter (500 INTERDC_x_CALL_ERROR) is enough for that.
    request.shouldContinueExecutionWithErrorContext = ^bool(__unused MTRequestErrorContext *errorContext) {
        return true;
    };
}

- (void)dealloc
{
    [self cleanup];
}

- (void)cleanup
{
    MTContext *context = _context;
    [context removeChangeListener:self];
    
    [_sourceDatacenterMtProto stop];
    _sourceDatacenterMtProto = nil;
    
    [_destinationDatacenterMtProto stop];
    _destinationDatacenterMtProto = nil;
}

- (void)execute:(MTContext *)context masterDatacenterId:(NSInteger)masterDatacenterId destinationDatacenterId:(NSInteger)destinationDatacenterId authToken:(id)authToken
{
    _destinationDatacenterId = destinationDatacenterId;
    _context = context;
    _authToken = authToken;
    
    if (_destinationDatacenterId != 0 && context != nil && _authToken != nil)
    {
        if ([_authToken isEqual:[context authTokenForDatacenterWithId:_destinationDatacenterId]])
            [self complete];
        else
            [self beginTransferFromDatacenterId:masterDatacenterId];
    }
    else
        [self fail];
}

- (void)contextDatacenterAuthTokenUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId authToken:(id)authToken
{
    MTContext *currentContext = _context;
    if (currentContext == nil || context != currentContext)
        return;
    
    if (authToken != nil && [_authToken isEqual:authToken])
    {
        if (datacenterId == _destinationDatacenterId)
            [self complete];
        else
            [self beginTransferFromDatacenterId:datacenterId];
    }
}

- (void)beginTransferFromDatacenterId:(NSInteger)sourceDatacenterId
{
    MTContext *context = _context;
    if (context == nil)
    {
        [self fail];
        
        return;
    }
    
    _sourceDatacenterMtProto = [[MTProto alloc] initWithContext:context datacenterId:sourceDatacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
    _sourceDatacenterMtProto.useTempAuthKeys = context.useTempAuthKeys;
    
    MTRequestMessageService *requestService = [[MTRequestMessageService alloc] initWithContext:context];
    requestService.forceBackgroundRequests = true;
    [_sourceDatacenterMtProto addMessageService:requestService];
    
    [_sourceDatacenterMtProto resume];
    
    MTRequest *request = [[MTRequest alloc] init];
    
    NSData *exportAuthRequestData = nil;
    MTExportAuthorizationResponseParser responseParser = [[context.serialization exportAuthorization:(int32_t)_destinationDatacenterId data:&exportAuthRequestData] copy];
    
    [request setPayload:exportAuthRequestData metadata:@"exportAuthorization" shortMetadata:@"exportAuthorization" responseParser:responseParser];
    [MTDatacenterTransferAuthAction applyRetryPolicyToRequest:request];
    
    __weak MTDatacenterTransferAuthAction *weakSelf = self;
    [request setCompleted:^(MTExportedAuthorizationData *result, __unused MTRequestResponseInfo *info, id error)
    {
        __strong MTDatacenterTransferAuthAction *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (error == nil)
        {
            [strongSelf beginTransferWithId:result.authorizationId data:result.authorizationBytes];
        }
        else
            [strongSelf fail];
    }];
    
    [requestService addRequest:request];
}

- (void)beginTransferWithId:(int64_t)dataId data:(NSData *)authData
{
    [_sourceDatacenterMtProto stop];
    _sourceDatacenterMtProto = nil;
    
    MTContext *context = _context;
    _destinationDatacenterMtProto = [[MTProto alloc] initWithContext:context datacenterId:_destinationDatacenterId usageCalculationInfo:nil requiredAuthToken:nil authTokenMasterDatacenterId:0];
    _destinationDatacenterMtProto.canResetAuthData = true;
    _destinationDatacenterMtProto.useTempAuthKeys = context.useTempAuthKeys;
    
    MTRequestMessageService *requestService = [[MTRequestMessageService alloc] initWithContext:context];
    requestService.forceBackgroundRequests = true;
    [_destinationDatacenterMtProto addMessageService:requestService];
    
    [_destinationDatacenterMtProto resume];
    
    MTRequest *request = [[MTRequest alloc] init];
    
    NSData *importAuthRequestData = [_context.serialization importAuthorization:dataId bytes:authData];
    
    [request setPayload:importAuthRequestData metadata:@"importAuthorization" shortMetadata:@"importAuthorization" responseParser:^id (NSData *data)
    {
        return @true;
    }];
    [MTDatacenterTransferAuthAction applyRetryPolicyToRequest:request];
    
    NSInteger destinationDatacenterId = _destinationDatacenterId;
    id authToken = _authToken;
    
    __weak MTDatacenterTransferAuthAction *weakSelf = self;
    [request setCompleted:^(__unused id result, __unused MTRequestResponseInfo *info, id error)
    {
        __strong MTDatacenterTransferAuthAction *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (error == nil)
        {
            [context updateAuthTokenForDatacenterWithId:destinationDatacenterId authToken:authToken];
            
            [strongSelf complete];
        }
        else
            [strongSelf fail];
    }];
    
    [requestService addRequest:request];
}

- (void)cancel
{
    [self cleanup];
    
    [self fail];
}

- (void)complete
{
    id<MTDatacenterTransferAuthActionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(datacenterTransferAuthActionCompleted:)])
        [delegate datacenterTransferAuthActionCompleted:self];
}

- (void)fail
{
    id<MTDatacenterTransferAuthActionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(datacenterTransferAuthActionFailed:)])
        [delegate datacenterTransferAuthActionFailed:self];
    else if ([delegate respondsToSelector:@selector(datacenterTransferAuthActionCompleted:)])
        [delegate datacenterTransferAuthActionCompleted:self];
}

@end
