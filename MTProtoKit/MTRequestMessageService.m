/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTRequestMessageService.h>

#import <MtProtoKit/MTTime.h>
#import <MtProtoKit/MTTimer.h>
#import <MTProtoKit/MTContext.h>
#import <MTProtoKit/MTSerialization.h>
#import <MTProtoKit/MTProto.h>
#import <MTProtoKit/MTQueue.h>
#import <MTProtoKit/MTMessageTransaction.h>
#import <MTProtoKit/MTIncomingMessage.h>
#import <MTProtoKit/MTOutgoingMessage.h>
#import <MTProtoKit/MTPreparedMessage.h>
#import <MTProtoKit/MTRequest.h>
#import <MTProtoKit/MTRequestContext.h>
#import <MtProtoKit/MTRequestErrorContext.h>
#import <MTProtoKit/MTDropResponseContext.h>
#import <MTProtoKit/MTApiEnvironment.h>
#import <MTProtoKit/MTDatacenterAuthInfo.h>

@interface MTRequestMessageService ()
{
    MTContext *_context;
    
    __weak MTProto *_mtProto;
    MTQueue *_queue;
    id<MTSerialization> _serialization;
    
    NSMutableArray *_requests;
    NSMutableArray *_dropReponseContexts;
    
    MTTimer *_requestsServiceTimer;
}

@end

@implementation MTRequestMessageService

- (instancetype)initWithContext:(MTContext *)context
{
    self = [super init];
    if (self != nil)
    {
        _context = context;
        
        __weak MTRequestMessageService *weakSelf = self;
        MTContextBlockChangeListener *changeListener = [[MTContextBlockChangeListener alloc] init];
        changeListener.contextIsPasswordRequiredUpdated = ^(MTContext *context, NSInteger datacenterId)
        {
            __strong MTRequestMessageService *strongSelf = weakSelf;
            [strongSelf _contextIsPasswordRequiredUpdated:context datacenterId:datacenterId];
        };
        
        [_context addChangeListener:changeListener];
        
        _requests = [[NSMutableArray alloc] init];
        _dropReponseContexts = [[NSMutableArray alloc] init];
        
        _apiEnvironment = context.apiEnvironment;
    }
    return self;
}

- (void)dealloc
{
    if (_requestsServiceTimer != nil)
    {
        [_requestsServiceTimer invalidate];
        _requestsServiceTimer = nil;
    }
}

- (void)addRequest:(MTRequest *)request
{
    [_queue dispatchOnQueue:^
    {
        MTProto *mtProto = _mtProto;
        if (mtProto == nil)
            return;
        
        if (![_requests containsObject:request])
        {
            [_requests addObject:request];
            [mtProto requestTransportTransaction];
        }
    }];
}

- (void)removeRequestByInternalId:(id)internalId
{
    [self removeRequestByInternalId:internalId askForReconnectionOnDrop:false];
}

- (void)removeRequestByInternalId:(id)internalId askForReconnectionOnDrop:(bool)askForReconnectionOnDrop
{
    [_queue dispatchOnQueue:^
    {
        bool anyNewDropRequests = false;
        bool removedAnyRequest = false;
        
        int index = -1;
        for (MTRequest *request in _requests)
        {
            index++;
            
            if ([request.internalId isEqual:internalId])
            {
                if (request.requestContext != nil)
                {
                    [_dropReponseContexts addObject:[[MTDropResponseContext alloc] initWithDropMessageId:request.requestContext.messageId]];
                    anyNewDropRequests = true;
                }
                
                if (request.requestContext.messageId != 0)
                    MTLog(@"[MTRequestMessageService#%x drop %" PRId64 "]", (int)self, request.requestContext.messageId);
                
                request.requestContext = nil;
                [_requests removeObjectAtIndex:(NSUInteger)index];
                removedAnyRequest = true;
                
                break;
            }
        }
        
        if (anyNewDropRequests)
        {
            MTProto *mtProto = _mtProto;
            
            if (askForReconnectionOnDrop)
                [mtProto requestSecureTransportReset];

            [mtProto requestTransportTransaction];
        }
        
        if (removedAnyRequest && _requests.count == 0)
        {
            id<MTRequestMessageServiceDelegate> delegate = _delegate;
            if ([delegate respondsToSelector:@selector(requestMessageServiceDidCompleteAllRequests:)])
                [delegate requestMessageServiceDidCompleteAllRequests:self];
        }
        
        [self updateRequestsTimer];
    }];
}

- (void)requestCount:(void (^)(NSUInteger requestCount))completion
{
    if (completion == nil)
        return;
    
    if (_queue == nil)
        completion(0);
    else
    {
        [_queue dispatchOnQueue:^
        {
            completion(_requests.count);
        }];
    }
}

- (void)_contextIsPasswordRequiredUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId
{
    [_queue dispatchOnQueue:^
    {
        if ([context isPasswordInputRequiredForDatacenterWithId:datacenterId])
            return;
        
        if (context != _context)
            return;
        
        MTProto *mtProto = _mtProto;
        if (datacenterId == mtProto.datacenterId)
            [mtProto requestTransportTransaction];
    }];
}

- (void)updateRequestsTimer
{
    [_queue dispatchOnQueue:^
    {
        MTAbsoluteTime currentTime = MTAbsoluteSystemTime();
        
        MTAbsoluteTime minWaitTime = DBL_MAX;
        bool needTimer = false;
        bool needTransaction = false;
        
        for (MTRequest *request in _requests)
        {
            if (request.errorContext != nil)
            {
                if (request.requestContext == nil)
                {
                    if (request.errorContext.minimalExecuteTime > currentTime + DBL_EPSILON)
                    {
                        needTimer = true;
                        minWaitTime = MIN(minWaitTime, request.errorContext.minimalExecuteTime - currentTime);
                    }
                    else
                    {
                        request.errorContext.minimalExecuteTime = 0.0;
                        needTransaction = true;
                    }
                }
            }
        }
        
        if (needTimer)
        {
            if (_requestsServiceTimer == nil)
            {
                __weak MTRequestMessageService *weakSelf = self;
                _requestsServiceTimer = [[MTTimer alloc] initWithTimeout:minWaitTime repeat:false completion:^
                {
                    __strong MTRequestMessageService *strongSelf = weakSelf;
                    [strongSelf requestTimerEvent];
                } queue:_queue.nativeQueue];
                [_requestsServiceTimer start];
            }
            else
                [_requestsServiceTimer resetTimeout:minWaitTime];
        }
        else if (!needTimer && _requestsServiceTimer != nil)
        {
            [_requestsServiceTimer invalidate];
            _requestsServiceTimer = nil;
        }
        
        if (needTransaction)
        {
            MTProto *mtProto = _mtProto;
            [mtProto requestTransportTransaction];
        }
    }];
}

- (void)requestTimerEvent
{
    if (_requestsServiceTimer != nil)
    {
        [_requestsServiceTimer invalidate];
        _requestsServiceTimer = nil;
    }
    
    MTProto *mtProto = _mtProto;
    [mtProto requestTransportTransaction];
}

- (void)mtProtoWillAddService:(MTProto *)mtProto
{
    _queue = [mtProto messageServiceQueue];
}

- (void)mtProtoDidAddService:(MTProto *)mtProto
{
    _mtProto = mtProto;
    _serialization = mtProto.context.serialization;
}

- (id)decorateRequest:(MTRequest *)request initializeApi:(bool)initializeApi unresolvedDependencyOnRequestInternalId:(__autoreleasing id *)unresolvedDependencyOnRequestInternalId
{    
    id currentBody = request.body;
    
    if ([_serialization isMessageRpcWithLayer:request.body])
    {
        if (initializeApi && _apiEnvironment != nil)
        {
            currentBody = [_serialization wrapInLayer:[_serialization connectionWithApiId:_apiEnvironment.apiId deviceModel:_apiEnvironment.deviceModel systemVersion:_apiEnvironment.systemVersion appVersion:_apiEnvironment.appVersion langCode:_apiEnvironment.langCode query:currentBody]];
        }
    }
    
    if (request.shouldDependOnRequest != nil)
    {
        NSUInteger index = [_requests indexOfObject:request];
        if (index != NSNotFound)
        {
            for (NSInteger i = ((NSInteger)index) - 1; i >= 0; i--)
            {
                MTRequest *anotherRequest = _requests[(NSUInteger)i];
                if (request.shouldDependOnRequest(anotherRequest))
                {
                    if (anotherRequest.requestContext != nil)
                        currentBody = [_serialization invokeAfterMessageId:anotherRequest.requestContext.messageId query:currentBody];
                    else if (unresolvedDependencyOnRequestInternalId != nil)
                        *unresolvedDependencyOnRequestInternalId = anotherRequest.internalId;
                    
                    break;
                }
            }
        }
    }
    
    return currentBody;
}

- (MTMessageTransaction *)mtProtoMessageTransaction:(MTProto *)mtProto
{
    NSMutableArray *messages = nil;
    NSMutableDictionary *requestInternalIdToMessageInternalId = nil;
    
    bool requestsWillInitializeApi = _apiEnvironment != nil && ![_apiEnvironment.apiInitializationHash isEqualToString:[_context authInfoForDatacenterWithId:mtProto.datacenterId].authKeyAttributes[@"apiInitializationHash"]];
    
    MTAbsoluteTime currentTime = MTAbsoluteSystemTime();
    
    for (MTRequest *request in _requests)
    {
        if (request.dependsOnPasswordEntry && [_context isPasswordInputRequiredForDatacenterWithId:mtProto.datacenterId])
            continue;
        
        if (request.errorContext != nil && request.errorContext.minimalExecuteTime > currentTime)
            continue;
        
        if (request.requestContext == nil || (!request.requestContext.delivered && request.requestContext.transactionId == nil))
        {
            if (messages == nil)
                messages = [[NSMutableArray alloc] init];
            if (requestInternalIdToMessageInternalId == nil)
                requestInternalIdToMessageInternalId = [[NSMutableDictionary alloc] init];
            
            __autoreleasing id autoreleasingUnresolvedDependencyOnRequestInternalId = nil;
            
            int64_t messageId = 0;
            int32_t messageSeqNo = 0;
            if (request.requestContext != nil)
            {
                messageId = request.requestContext.messageId;
                messageSeqNo = request.requestContext.messageSeqNo;
            }
            MTOutgoingMessage *outgoingMessage = [[MTOutgoingMessage alloc] initWithBody:[self decorateRequest:request initializeApi:requestsWillInitializeApi unresolvedDependencyOnRequestInternalId:&autoreleasingUnresolvedDependencyOnRequestInternalId] messageId:messageId messageSeqNo:messageSeqNo];
            outgoingMessage.needsQuickAck = request.acknowledgementReceived != nil;
            outgoingMessage.hasHighPriority = request.hasHighPriority;
            
            id unresolvedDependencyOnRequestInternalId = autoreleasingUnresolvedDependencyOnRequestInternalId;
            if (unresolvedDependencyOnRequestInternalId != nil)
            {
                id<MTSerialization> serialization = _serialization;
                
                outgoingMessage.dynamicDecorator = ^id (id currentBody, NSDictionary *messageInternalIdToPreparedMessage)
                {
                    id messageInternalId = requestInternalIdToMessageInternalId[unresolvedDependencyOnRequestInternalId];
                    if (messageInternalId != nil)
                    {
                        MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[messageInternalId];
                        if (preparedMessage != nil)
                            return [serialization invokeAfterMessageId:preparedMessage.messageId query:currentBody];
                    }
                    
                    return currentBody;
                };
            }
            
            requestInternalIdToMessageInternalId[request.internalId] = outgoingMessage.internalId;
            [messages addObject:outgoingMessage];
        }
    }
    
    NSMutableDictionary *dropMessageIdToMessageInternalId = nil;
    for (MTDropResponseContext *dropContext in _dropReponseContexts)
    {
        if (messages == nil)
            messages = [[NSMutableArray alloc] init];
        if (dropMessageIdToMessageInternalId == nil)
            dropMessageIdToMessageInternalId = [[NSMutableDictionary alloc] init];
        
        MTOutgoingMessage *outgoingMessage = [[MTOutgoingMessage alloc] initWithBody:[_serialization dropAnswerToMessageId:dropContext.dropMessageId] messageId:dropContext.messageId messageSeqNo:dropContext.messageSeqNo];
        outgoingMessage.requiresConfirmation = false;
        dropMessageIdToMessageInternalId[@(dropContext.dropMessageId)] = outgoingMessage.internalId;
        [messages addObject:outgoingMessage];
    }
    
    if (messages.count != 0)
    {
        return [[MTMessageTransaction alloc] initWithMessagePayload:messages completion:^(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, NSDictionary *messageInternalIdToQuickAckId)
        {
            for (MTRequest *request in _requests)
            {
                id messageInternalId = requestInternalIdToMessageInternalId[request.internalId];
                if (messageInternalId != nil)
                {
                    MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[messageInternalId];
                    if (preparedMessage != nil && messageInternalIdToTransactionId[messageInternalId] != nil)
                    {
                        MTRequestContext *requestContext = [[MTRequestContext alloc] initWithMessageId:preparedMessage.messageId messageSeqNo:preparedMessage.seqNo transactionId:messageInternalIdToTransactionId[messageInternalId] quickAckId:(int32_t)[messageInternalIdToQuickAckId[messageInternalId] intValue]];
                        requestContext.willInitializeApi = requestsWillInitializeApi;
                        request.requestContext = requestContext;
                    }
                }
            }
            
            for (MTDropResponseContext *dropContext in _dropReponseContexts)
            {
                MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[dropMessageIdToMessageInternalId[@(dropContext.dropMessageId)]];
                if (preparedMessage != nil)
                {
                    dropContext.messageId = preparedMessage.messageId;
                    dropContext.messageSeqNo = preparedMessage.seqNo;
                }
            }
        }];
    }
    
    return nil;
}

- (void)mtProto:(MTProto *)__unused mtProto receivedMessage:(MTIncomingMessage *)message
{
    if ([_serialization isMessageRpcResult:message.body])
    {
        if ([_serialization isRpcDroppedAnswer:message.body])
        {
            NSInteger index = -1;
            for (MTDropResponseContext *dropContext in _dropReponseContexts)
            {
                index++;
                if (dropContext.messageId == [_serialization rpcDropedAnswerDropMessageId:message.body])
                {
                    [_dropReponseContexts removeObjectAtIndex:(NSUInteger)index];
                    break;
                }
            }
        }
        else
        {
            int64_t requestMessageId = 0;
            id rpcResult = [_serialization rpcResultBody:message.body requestMessageId:&requestMessageId];
            
            bool requestFound = false;
            
            int index = -1;
            for (MTRequest *request in _requests)
            {
                index++;
                
                if (request.requestContext != nil && request.requestContext.messageId == requestMessageId)
                {
                    requestFound = true;
                    
                    bool restartRequest = false;
                    
                    bool resultIsError = false;
                    id object = [_serialization rpcResult:rpcResult requestBody:request.body isError:&resultIsError];
                    
                    MTLog(@"[MTRequestMessageService#%p response for %" PRId64 " is %@]", self, request.requestContext.messageId, [object class] == nil ? @"nil" : NSStringFromClass([object class]));
                    
                    if (object != nil && !resultIsError && request.requestContext.willInitializeApi)
                    {
                        MTDatacenterAuthInfo *authInfo = [_context authInfoForDatacenterWithId:mtProto.datacenterId];
                        
                        if (![_apiEnvironment.apiInitializationHash isEqualToString:authInfo.authKeyAttributes[@"apiInitializationHash"]])
                        {
                            NSMutableDictionary *authKeyAttributes = [[NSMutableDictionary alloc] initWithDictionary:authInfo.authKeyAttributes];
                            authKeyAttributes[@"apiInitializationHash"] = _apiEnvironment.apiInitializationHash;
                            
                            authInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:authInfo.authKey authKeyId:authInfo.authKeyId saltSet:authInfo.saltSet authKeyAttributes:authKeyAttributes];
                            [_context updateAuthInfoForDatacenterWithId:mtProto.datacenterId authInfo:authInfo];
                        }
                    }
                    
                    if (resultIsError)
                    {
                        MTLog(@"[MTRequestMessageService#%p in response to %" PRId64 " %@]", self, request.requestContext.messageId, [_serialization rpcErrorDescription:object]);
                        
                        int32_t errorCode = [_serialization rpcErrorCode:object];
                        NSString *errorText = [_serialization rpcErrorText:object];
                        if (errorCode == 401)
                        {
                            if ([errorText rangeOfString:@"SESSION_PASSWORD_NEEDED"].location != NSNotFound)
                            {
                                [_context updatePasswordInputRequiredForDatacenterWithId:mtProto.datacenterId required:true];
                            }
                            else
                            {
                                id<MTRequestMessageServiceDelegate> delegate = _delegate;
                                if ([delegate respondsToSelector:@selector(requestMessageServiceAuthorizationRequired:)])
                                    [delegate requestMessageServiceAuthorizationRequired:self];
                            }
                        }
                        else if (errorCode == -500 || errorCode == 500)
                        {
                            if (request.errorContext == nil)
                                request.errorContext = [[MTRequestErrorContext alloc] init];
                            request.errorContext.internalServerErrorCount++;
                            
                            if (request.shouldContinueExecutionWithErrorContext != nil && request.shouldContinueExecutionWithErrorContext(request.errorContext))
                            {
                                restartRequest = true;
                                request.errorContext.minimalExecuteTime = MAX(request.errorContext.minimalExecuteTime, MTAbsoluteSystemTime() + 2.0);
                            }
                        }
                        else if (errorCode == 420)
                        {
                            if (request.errorContext == nil)
                                request.errorContext = [[MTRequestErrorContext alloc] init];
                            
                            if ([errorText rangeOfString:@"FLOOD_WAIT_"].location != NSNotFound)
                            {
                                int errorWaitTime = 0;
                                
                                NSScanner *scanner = [[NSScanner alloc] initWithString:errorText];
                                [scanner scanUpToString:@"FLOOD_WAIT_" intoString:nil];
                                [scanner scanString:@"FLOOD_WAIT_" intoString:nil];
                                if ([scanner scanInt:&errorWaitTime])
                                {
                                    if (request.shouldContinueExecutionWithErrorContext != nil && request.shouldContinueExecutionWithErrorContext(request.errorContext))
                                    {
                                        restartRequest = true;
                                        request.errorContext.minimalExecuteTime = MAX(request.errorContext.minimalExecuteTime, MTAbsoluteSystemTime() + (MTAbsoluteTime)errorWaitTime);
                                    }
                                    else
                                    {
                                        restartRequest = true;
                                        request.errorContext.minimalExecuteTime = MAX(request.errorContext.minimalExecuteTime, MTAbsoluteSystemTime() + (MTAbsoluteTime)errorWaitTime);
                                    }
                                }
                            }
                        }
                        else if (errorCode == 400 && [errorText rangeOfString:@"CONNECTION_NOT_INITED"].location != NSNotFound)
                        {
                            [_context performBatchUpdates:^
                            {
                                MTDatacenterAuthInfo *authInfo = [_context authInfoForDatacenterWithId:mtProto.datacenterId];
                                
                                NSMutableDictionary *authKeyAttributes = [[NSMutableDictionary alloc] initWithDictionary:authInfo.authKeyAttributes];
                                [authKeyAttributes removeObjectForKey:@"apiInitializationHash"];
                                
                                authInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:authInfo.authKey authKeyId:authInfo.authKeyId saltSet:authInfo.saltSet authKeyAttributes:authKeyAttributes];
                                [_context updateAuthInfoForDatacenterWithId:mtProto.datacenterId authInfo:authInfo];
                            }];
                        }
                        
#warning TODO other service errors
                    }
                    
                    request.requestContext = nil;
                    
                    if (restartRequest)
                    {
                        
                    }
                    else
                    {
                        void (^completed)(id result, NSTimeInterval completionTimestamp, id error) = request.completed;
                        [_requests removeObjectAtIndex:(NSUInteger)index];
                        
                        if (completed)
                            completed(resultIsError ? nil : object, message.timestamp, resultIsError ? object : nil);
                    }
                    
                    break;
                }
            }
            
            if (!requestFound)
                MTLog(@"[MTRequestMessageService#%p response %" PRId64 " didn't match any request]", self, message.messageId);
            else if (_requests.count == 0)
            {
                id<MTRequestMessageServiceDelegate> delegate = _delegate;
                if ([delegate respondsToSelector:@selector(requestMessageServiceDidCompleteAllRequests:)])
                    [delegate requestMessageServiceDidCompleteAllRequests:self];
            }
            
            [self updateRequestsTimer];
        }
    }
}

- (void)mtProto:(MTProto *)__unused mtProto receivedQuickAck:(int32_t)quickAckId
{
    for (MTRequest *request in _requests)
    {
        if (request.requestContext != 0 && request.requestContext.quickAckId == quickAckId)
        {
            if (request.acknowledgementReceived != nil)
                request.acknowledgementReceived();
        }
    }
}

- (void)mtProto:(MTProto *)__unused mtProto messageDeliveryConfirmed:(NSArray *)messageIds
{
    for (NSNumber *nMessageId in messageIds)
    {
        int64_t messageId = (int64_t)[nMessageId longLongValue];
        
        for (MTRequest *request in _requests)
        {
            if (request.requestContext != nil && request.requestContext.messageId == messageId)
            {
                request.requestContext.delivered = true;
                
                break;
            }
        }
    }
}

- (void)mtProto:(MTProto *)mtProto messageDeliveryFailed:(int64_t)messageId
{
    bool requestTransaction = false;
    
    for (MTRequest *request in _requests)
    {
        if (request.requestContext != nil && request.requestContext.messageId == messageId)
        {
            request.requestContext = nil;
            
            break;
        }
    }
    
    for (MTDropResponseContext *dropContext in _dropReponseContexts)
    {
        if (dropContext.messageId == messageId)
        {
            dropContext.messageId = 0;
            dropContext.messageSeqNo = 0;
            
            break;
        }
    }
    
    if (requestTransaction)
        [mtProto requestTransportTransaction];
}

- (void)mtProto:(MTProto *)mtProto transactionsMayHaveFailed:(NSArray *)transactionIds
{
    bool requestTransaction = false;
    
    for (MTRequest *request in _requests)
    {
        if (request.requestContext != nil && request.requestContext.transactionId != nil && [transactionIds containsObject:request.requestContext.transactionId])
        {
            request.requestContext.transactionId = nil;
            requestTransaction = true;
        }
    }
    
    if (requestTransaction)
        [mtProto requestTransportTransaction];
}

- (void)mtProtoAllTransactionsMayHaveFailed:(MTProto *)mtProto
{
    bool requestTransaction = false;
    
    for (MTRequest *request in _requests)
    {
        if (request.requestContext != nil && request.requestContext.transactionId != nil)
        {
            request.requestContext.transactionId = nil;
            requestTransaction = true;
        }
    }
    
    if (requestTransaction)
        [mtProto requestTransportTransaction];
}

- (bool)mtProto:(MTProto *)__unused mtProto shouldRequestMessageInResponseToMessageId:(int64_t)messageId currentTransactionId:(id)currentTransactionId
{
    for (MTRequest *request in _requests)
    {
        if (request.requestContext != nil && request.requestContext.messageId == messageId && (request.requestContext.transactionId == nil || [request.requestContext.transactionId isEqual:currentTransactionId]))
        {
            return true;
        }
    }
    
    return false;
}

- (void)mtProto:(MTProto *)mtProto updateReceiveProgressForToken:(id)progressToken progress:(float)progress packetLength:(NSInteger)packetLength
{
    if ([progressToken respondsToSelector:@selector(longLongValue)])
    {
        int64_t messageId = [(NSNumber *)progressToken longLongValue];
        
        for (MTRequest *request in _requests)
        {
            if (request.requestContext != nil && request.requestContext.messageId == messageId && request.progressUpdated)
                request.progressUpdated(progress, packetLength);
        }
    }
}

- (void)mtProtoDidChangeSession:(MTProto *)mtProto
{
    for (MTRequest *request in _requests)
    {
        request.requestContext = nil;
    }
    
    [_dropReponseContexts removeAllObjects];
    
    if (_requests.count != 0)
        [mtProto requestTransportTransaction];
}

- (void)mtProtoServerDidChangeSession:(MTProto *)mtProto firstValidMessageId:(int64_t)firstValidMessageId otherValidMessageIds:(NSArray *)otherValidMessageIds
{
    bool resendSomeRequests = false;
    for (MTRequest *request in _requests)
    {
        if (request.requestContext != nil && (request.requestContext.messageId < firstValidMessageId && ![otherValidMessageIds containsObject:@(request.requestContext.messageId)]))
        {
            request.requestContext = nil;
            
            resendSomeRequests = true;
        }
    }
    
    if (resendSomeRequests)
        [mtProto requestTransportTransaction];
}

- (int32_t)possibleSignatureForResult:(int64_t)messageId found:(bool *)found
{
    for (MTRequest *request in _requests)
    {
        if (request.requestContext != nil && request.requestContext.messageId == messageId)
        {
            if (found != NULL)
                *found = true;
            
            return [_serialization rpcRequestBodyResponseSignature:request.body];
        }
    }
    
    for (MTDropResponseContext *dropContext in _dropReponseContexts)
    {
        if (dropContext.messageId == messageId)
        {
            if (found != NULL)
                *found = true;
            
            return 0;
        }
    }
    
    return 0;
}

@end
