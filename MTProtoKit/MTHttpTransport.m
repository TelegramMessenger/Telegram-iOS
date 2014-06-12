/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTHttpTransport.h>

#import <MTProtoKit/MTQueue.h>
#import <MTProtoKit/MTTimer.h>

#import <MTProtoKit/MTDatacenterAddressSet.h>
#import <MTProtoKit/MTDatacenterAddress.h>

#import <MTProtoKit/MTSerialization.h>
#import <MTProtoKit/MTTransportTransaction.h>
#import <MTProtoKit/MTMessageTransaction.h>
#import <MTProtoKit/MTOutgoingMessage.h>
#import <MtProtoKit/MTIncomingMessage.h>
#import <MtProtoKit/MTPreparedMessage.h>

#import <MTProtoKit/MTHttpWorkerBehaviour.h>
#import <MTProtoKit/MTHttpWorker.h>

@interface MTHttpTransport () <MTHttpWorkerBehaviourDelegate, MTHttpWorkerDelegate, MTContextChangeListener>
{
    MTDatacenterAddress *_address;
    
    bool _willRequestTransactionOnNextQueuePass;
    
    MTHttpWorkerBehaviour *_workerBehaviour;
    NSMutableArray *_workers;
    
    bool _isNetworkAvailable;
    bool _isConnected;
    int64_t _currentActualizationPingId;
    int64_t _currentActualizationPingMessageId;
    
    MTTimer *_connectingStateTimer;
    MTTimer *_connectionWatchdogTimer;
}

@end

@implementation MTHttpTransport

+ (MTQueue *)httpTransportQueue
{
    static MTQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[MTQueue alloc] initWithName:"org.mtproto.httpTransportQueue"];
    });
    return queue;
}

- (instancetype)initWithDelegate:(id<MTTransportDelegate>)delegate context:(MTContext *)context datacenterId:(NSInteger)datacenterId address:(MTDatacenterAddress *)address
{
    self = [super initWithDelegate:delegate context:context datacenterId:datacenterId address:address];
    if (self != nil)
    {
        _address = address;
        
        _workerBehaviour = [[MTHttpWorkerBehaviour alloc] initWithQueue:[MTHttpTransport httpTransportQueue]];
        _workerBehaviour.delegate = self;
        
        _isNetworkAvailable = true;
        _isConnected = false;
        arc4random_buf(&_currentActualizationPingId, 8);
        
        [context addChangeListener:self];
    }
    return self;
}

- (void)dealloc
{
    [self cleanup];
}

- (void)reset
{
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        for (MTHttpWorker *worker in [_workers copy])
        {
            [worker terminateWithFailure];
        }
    }];
}

- (void)stop
{
    [self activeTransactionIds:^(NSArray *activeTransactionId)
    {
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportTransactionsMayHaveFailed:transactionIds:)])
            [delegate transportTransactionsMayHaveFailed:self transactionIds:activeTransactionId];
    }];
    
    [self cleanup];
    
    [super stop];
}

- (void)cleanup
{
    [self.context removeChangeListener:self];
    
    MTTimer *connectingStateTimer = _connectingStateTimer;
    _connectingStateTimer = nil;
    
    MTTimer *connectionWatchdogTimer = _connectionWatchdogTimer;
    _connectionWatchdogTimer = nil;
    
    NSMutableArray *workers = _workers;
    _workers = nil;
    
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        [connectingStateTimer invalidate];
        
        [connectionWatchdogTimer invalidate];
        
        for (MTHttpWorker *worker in workers)
        {
            worker.delegate = nil;
            [worker stop];
        }
    }];
}

- (void)updateConnectionState
{
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportNetworkAvailabilityChanged:isNetworkAvailable:)])
            [delegate transportNetworkAvailabilityChanged:self isNetworkAvailable:_isNetworkAvailable];
        if ([delegate respondsToSelector:@selector(transportConnectionStateChanged:isConnected:)])
            [delegate transportConnectionStateChanged:self isConnected:_isConnected];
        if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
            [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:_currentActualizationPingId != 0];
    }];
}

- (void)startConnectingStateTimerIfNotRunning
{
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        if (_connectingStateTimer == nil)
        {
            __weak MTHttpTransport *weakSelf = self;
            _connectingStateTimer = [[MTTimer alloc] initWithTimeout:4.0 repeat:false completion:^
            {
                __strong MTHttpTransport *strongSelf = weakSelf;
                [strongSelf connectingStateTimerEvent];
            } queue:[MTHttpTransport httpTransportQueue].nativeQueue];
            [_connectingStateTimer start];
        }
    }];
}

- (void)startConnectionWatchdogTimerIfNotRunning
{
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        __weak MTHttpTransport *weakSelf = self;
        _connectionWatchdogTimer = [[MTTimer alloc] initWithTimeout:10.0 repeat:false completion:^
        {
            __strong MTHttpTransport *strongSelf = weakSelf;
            [strongSelf connectionWatchdogTimerEvent];
        } queue:[MTHttpTransport httpTransportQueue].nativeQueue];
        [_connectionWatchdogTimer start];
    }];
}

- (void)connectingStateTimerEvent
{
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        [self stopConnectingStateTimer];
        
        if (_isConnected)
        {
            _isConnected = false;
         
            id<MTTransportDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(transportConnectionStateChanged:isConnected:)])
                [delegate transportConnectionStateChanged:self isConnected:_isConnected];
        }
    }];
}

- (void)connectionWatchdogTimerEvent
{
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        [self stopConnectionWatchdogTimer];
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionProblemsStatusChanged:hasConnectionProblems:isProbablyHttp:)])
            [delegate transportConnectionProblemsStatusChanged:self hasConnectionProblems:true isProbablyHttp:false];
    }];
}

- (void)stopConnectingStateTimer
{
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        if (_connectingStateTimer != nil)
        {
            [_connectingStateTimer invalidate];
            _connectingStateTimer = nil;
        }
    }];
}

- (void)stopConnectionWatchdogTimer
{
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        if (_connectionWatchdogTimer != nil)
        {
            [_connectionWatchdogTimer invalidate];
            _connectionWatchdogTimer = nil;
        }
    }];
}

- (void)setDelegateNeedsTransaction
{
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        if (self.simultaneousTransactionsEnabled || _workers.count == 0)
            [_workerBehaviour setWorkersNeeded];
    }];
}

- (void)httpWorkerBehaviourAllowsNewWorkerCreation:(MTHttpWorkerBehaviour *)__unused behaviour
{
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        if (!_willRequestTransactionOnNextQueuePass)
        {
            _willRequestTransactionOnNextQueuePass = true;
            
            dispatch_async([MTHttpTransport httpTransportQueue].nativeQueue, ^
            {
                _willRequestTransactionOnNextQueuePass = false;
                [self _requestTransactionFromDelegate];
            });
        }
    }];
}

- (void)httpWorkerConnected:(MTHttpWorker *)httpWorker
{
    if (httpWorker == nil)
        return;
 
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        if (!_isConnected)
        {
            [self stopConnectingStateTimer];
            
            _isConnected = true;
            
            id<MTTransportDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(transportConnectionStateChanged:isConnected:)])
                [delegate transportConnectionStateChanged:self isConnected:_isConnected];
        }
        
        [self stopConnectionWatchdogTimer];
        
        [_workerBehaviour workerConnected];
    }];
}

- (void)httpWorker:(MTHttpWorker *)httpWorker completedWithData:(NSData *)data
{
    if (httpWorker == nil)
        return;
    
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        if ([_workers containsObject:httpWorker])
        {
            bool requestTransactionForLongPolling = [self _removeHttpWorker:httpWorker];
            
            //TGLog(@"[MTHttpTransport#%x MTHttpWorker#%x completed with %d bytes, %d active]", (int)self, (int)httpWorker, (int)data.length, _workers.count);
            
            __weak MTHttpTransport *weakSelf = self;
            [self _processIncomingData:data transactionId:httpWorker.internalId requestTransactionAfterProcessing:requestTransactionForLongPolling decodeResult:^(id transactionId, bool success)
            {
                if (success)
                {
                    __strong MTHttpTransport *strongSelf = weakSelf;
                    [strongSelf transactionIsValid:transactionId];
                }
            }];
        }
    }];
}

- (void)httpWorkerFailed:(MTHttpWorker *)httpWorker
{
    if (httpWorker == nil)
        return;
    
    [_workerBehaviour workerDisconnectedWithError];
    
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        arc4random_buf(&_currentActualizationPingId, 8);
        id<MTTransportDelegate> delegate = self.delegate;
        
        if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
            [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:true];
        
        bool anyWorkerConnected = false;
        for (MTHttpWorker *worker in _workers)
        {
            if ([worker isConnected])
            {
                anyWorkerConnected = true;
                
                break;
            }
        }
        if (!anyWorkerConnected)
        {
            [self startConnectingStateTimerIfNotRunning];
            [self startConnectionWatchdogTimerIfNotRunning];
        }
        
        bool requestTransactionForLongPolling = [self _removeHttpWorker:httpWorker];
        
        if ([delegate respondsToSelector:@selector(transportTransactionsMayHaveFailed:transactionIds:)])
            [delegate transportTransactionsMayHaveFailed:self transactionIds:@[httpWorker.internalId]];
        
        if (requestTransactionForLongPolling)
            [self setDelegateNeedsTransaction];
    }];
}

- (void)transactionIsValid:(id)transactionId
{
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        [self stopConnectionWatchdogTimer];
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionProblemsStatusChanged:hasConnectionProblems:isProbablyHttp:)])
            [delegate transportConnectionProblemsStatusChanged:self hasConnectionProblems:false isProbablyHttp:false];
    }];
}

- (bool)_removeHttpWorker:(MTHttpWorker *)httpWorker
{
    if ([_workers containsObject:httpWorker])
    {
        [_workers removeObject:httpWorker];
        
        bool activeWorkersWithLongPollingFound = false;
        for (MTHttpWorker *worker in _workers)
        {
            if (worker.performsLongPolling)
            {
                activeWorkersWithLongPollingFound = true;
                break;
            }
        }
        
        if (!activeWorkersWithLongPollingFound && [self.context authInfoForDatacenterWithId:self.datacenterId] != nil)
            return true;
    }
    
    return false;
}

- (void)_requestTransactionFromDelegate
{
    if (!self.simultaneousTransactionsEnabled && _workers.count != 0)
        return;
    
    id<MTTransportDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(transportReadyForTransaction:transportSpecificTransaction:forceConfirmations:transactionReady:)])
    {
        MTMessageTransaction *transportSpecificTransaction = nil;
        
        bool performsLongPolling = false;
        if ([self.context authInfoForDatacenterWithId:self.datacenterId] != nil)
        {
            bool activeWorkersWithLongPollingFound = false;
            for (MTHttpWorker *worker in _workers)
            {
                if (worker.performsLongPolling)
                {
                    activeWorkersWithLongPollingFound = true;
                    break;
                }
            }
            
            if (_currentActualizationPingId != 0)
            {
                id ping = [self.context.serialization ping:_currentActualizationPingId];
                
                MTOutgoingMessage *outgoingMessage = [[MTOutgoingMessage alloc] initWithBody:ping];
                outgoingMessage.requiresConfirmation = false;
                transportSpecificTransaction = [[MTMessageTransaction alloc] initWithMessagePayload:@[outgoingMessage] completion:nil];
                transportSpecificTransaction.requiresEncryption = true;
            }
            else if (!activeWorkersWithLongPollingFound)
            {
                id httpWait = [self.context.serialization httpWaitWithMaxDelay:50 waitAfter:50 maxWait:25000];
                MTOutgoingMessage *actualizationPingMessage = [[MTOutgoingMessage alloc] initWithBody:httpWait];
                actualizationPingMessage.requiresConfirmation = false;
                transportSpecificTransaction = [[MTMessageTransaction alloc] initWithMessagePayload:@[actualizationPingMessage] completion:^(__unused NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId)
                {
                    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
                    {
                        MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[actualizationPingMessage.internalId];
                        if (preparedMessage != nil)
                            _currentActualizationPingMessageId = preparedMessage.messageId;
                    }];
                }];
                transportSpecificTransaction.requiresEncryption = true;
                
                performsLongPolling = true;
            }
        }
        
        [delegate transportReadyForTransaction:self transportSpecificTransaction:transportSpecificTransaction forceConfirmations:true transactionReady:^(NSArray *transactionList)
        {
            [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
            {
                NSInteger transactionIndex = -1;
                for (MTTransportTransaction *transaction in transactionList)
                {
                    transactionIndex++;
                    
                    if (!self.simultaneousTransactionsEnabled && _workers.count != 0)
                        transaction.completion(false, nil);
                    else if (transaction.payload.length != 0)
                    {
                        MTHttpWorker *worker = [[MTHttpWorker alloc] initWithDelegate:self address:_address payloadData:transaction.payload performsLongPolling:performsLongPolling && transactionIndex == 0];
                        MTLog(@"[MTHttpTransport#%x spawn MTHttpWorker#%x(longPolling: %s), %d active]", (int)self, (int)worker, worker.performsLongPolling ? "1" : "0", _workers.count + 1);
                        worker.delegate = self;
                        
                        if (_workers == nil)
                            _workers = [[NSMutableArray alloc] init];
                        [_workers addObject:worker];
                        
                        transaction.completion(true, worker.internalId);
                    }
                    else if (transaction.completion)
                        transaction.completion(false, nil);
                }
            }];
        }];
    }
}

- (void)contextDatacenterAuthInfoUpdated:(MTContext *)__unused context datacenterId:(NSInteger)datacenterId authInfo:(MTDatacenterAuthInfo *)authInfo
{
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        if (datacenterId == self.datacenterId && authInfo != nil)
        {
            [self setDelegateNeedsTransaction];
        }
    }];
}

- (void)activeTransactionIds:(void (^)(NSArray *))completion
{
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        if (completion != nil && _workers.count != 0)
        {
            NSMutableArray *transactionIds = [[NSMutableArray alloc] initWithCapacity:_workers.count];
            for (MTHttpWorker *worker in _workers)
            {
                [transactionIds addObject:worker.internalId];
            }
            
            completion(transactionIds);
        }
    }];
}

- (void)_networkAvailabilityChanged:(bool)networkAvailable
{
    [super _networkAvailabilityChanged:networkAvailable];
    
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        _isNetworkAvailable = networkAvailable;
        
        if (networkAvailable)
            [_workerBehaviour clearBackoff];
    }];
}

- (void)mtProtoDidChangeSession:(MTProto *)__unused mtProto
{
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        _currentActualizationPingId = 0;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
            [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
    }];
}

- (void)mtProtoServerDidChangeSession:(MTProto *)__unused mtProto firstValidMessageId:(int64_t)firstValidMessageId otherValidMessageIds:(NSArray *)otherValidMessageIds
{
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        _currentActualizationPingId = 0;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
            [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
    }];
}

- (void)mtProto:(MTProto *)__unused mtProto receivedMessage:(MTIncomingMessage *)incomingMessage
{
    if ([self.context.serialization isMessagePong:incomingMessage.body])
    {
        [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
        {
            if (_currentActualizationPingId != 0 && [self.context.serialization pongPingId:incomingMessage.body] == _currentActualizationPingId)
            {
                _currentActualizationPingId = 0;
                
                id<MTTransportDelegate> delegate = self.delegate;
                if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
                    [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
            }
        }];
    }
}

- (void)mtProto:(MTProto *)__unused mtProto messageDeliveryFailed:(int64_t)messageId
{
    [[MTHttpTransport httpTransportQueue] dispatchOnQueue:^
    {
        if (_currentActualizationPingMessageId != 0 && messageId == _currentActualizationPingMessageId)
        {
            _currentActualizationPingId = 0;
            
            id<MTTransportDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
                [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
        }
    }];
}

@end
