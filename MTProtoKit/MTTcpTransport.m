/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTTcpTransport.h>

#import <MTProtoKit/MTQueue.h>
#import <MTProtoKit/MTTimer.h>
#import <MTProtoKit/MTTime.h>

#import <MTProtoKit/MTDatacenterAddressSet.h>

#import <MTProtoKit/MTTransportTransaction.h>
#import <MTProtoKit/MTOutgoingMessage.h>
#import <MTProtoKit/MTIncomingMessage.h>
#import <MTProtoKit/MTMessageTransaction.h>
#import <MTProtoKit/MTPreparedMessage.h>

#import <MTProtoKit/MTTcpConnection.h>
#import <MTProtoKit/MTTcpConnectionBehaviour.h>

#import <MTProtoKit/MTSerialization.h>

static const NSTimeInterval MTTcpTransportSleepWatchdogTimeout = 60.0;

@interface MTTcpTransport () <MTTcpConnectionDelegate, MTTcpConnectionBehaviourDelegate>
{
    MTDatacenterAddress *_address;
    
    MTTcpConnection *_connection;
    bool _connectionConnected;
    bool _connectionIsValid;
    MTTcpConnectionBehaviour *_connectionBehaviour;
    bool _stopped;
    
    bool _isNetworkAvailable;
    
    bool _willRequestTransactionOnNextQueuePass;
    
    NSTimeInterval _transactionLockTime;
    bool _isWaitingForTransactionToBecomeReady;
    bool _requestAnotherTransactionWhenReady;
    
    bool _didSendActualizationPingAfterConnection;
    int64_t _currentActualizationPingMessageId;
    MTTimer *_actualizationPingResendTimer;
    
    MTTimer *_connectionWatchdogTimer;
    MTTimer *_sleepWatchdogTimer;
    CFAbsoluteTime _sleepWatchdogTimerLastTime;
}

@end

@implementation MTTcpTransport

+ (MTQueue *)tcpTransportQueue
{
    static MTQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[MTQueue alloc] initWithName:"org.mtproto.tcpTransportQueue"];
    });
    return queue;
}

- (instancetype)initWithDelegate:(id<MTTransportDelegate>)delegate context:(MTContext *)context datacenterId:(NSInteger)datacenterId address:(MTDatacenterAddress *)address
{
#ifdef DEBUG
    NSAssert(context != nil, @"context should not be nil");
    NSAssert(datacenterId != 0, @"datacenterId should not be nil");
    NSAssert(address != nil, @"address should not be nil");
#endif
    
    self = [super initWithDelegate:delegate context:context datacenterId:datacenterId address:address];
    if (self != nil)
    {
        _address = address;
        
        _connectionBehaviour = [[MTTcpConnectionBehaviour alloc] initWithQueue:[MTTcpTransport tcpTransportQueue]];
        _connectionBehaviour.delegate = self;
        
        _isNetworkAvailable = true;
    }
    return self;
}

- (void)dealloc
{
    MTTcpConnection *connection = _connection;
    _connection = nil;
    
    MTTcpConnectionBehaviour *connectionBehaviour = _connectionBehaviour;
    _connectionBehaviour = nil;
    
    MTTimer *actualizationPingResendTimer = _actualizationPingResendTimer;
    _actualizationPingResendTimer = nil;
    
    MTTimer *connectionWatchdogTimer = _connectionWatchdogTimer;
    _connectionWatchdogTimer = nil;
    MTTimer *sleepWatchdogTimer = _sleepWatchdogTimer;
    _sleepWatchdogTimer = nil;
    
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        connection.delegate = nil;
        
        connectionBehaviour.needsReconnection = false;
        connectionBehaviour.delegate = nil;
        
        [actualizationPingResendTimer invalidate];
        
        [connectionWatchdogTimer invalidate];
        [sleepWatchdogTimer invalidate];
    }];
}

- (bool)needsParityCorrection
{
    return true;
}

- (void)updateConnectionState
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportNetworkAvailabilityChanged:isNetworkAvailable:)])
            [delegate transportNetworkAvailabilityChanged:self isNetworkAvailable:_isNetworkAvailable];
        if ([delegate respondsToSelector:@selector(transportConnectionStateChanged:isConnected:)])
            [delegate transportConnectionStateChanged:self isConnected:_connectionConnected];
        if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
            [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:_currentActualizationPingMessageId != 0];
    }];
}

- (void)setDelegateNeedsTransaction
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (!_willRequestTransactionOnNextQueuePass)
        {
            _willRequestTransactionOnNextQueuePass = true;
            
            dispatch_async([MTTcpTransport tcpTransportQueue].nativeQueue, ^
            {
                _willRequestTransactionOnNextQueuePass = false;
                
                if (_connection == nil)
                    [_connectionBehaviour requestConnection];
                else if (_connectionConnected)
                    [self _requestTransactionFromDelegate];
            });
        }
    }];
}

- (void)startIfNeeded
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (_connection == nil)
        {
            [self startConnectionWatchdogTimer];
            [self startSleepWatchdogTimer];
            
            _connection = [[MTTcpConnection alloc] initWithAddress:_address interface:nil];
            _connection.delegate = self;
            [_connection start];
        }
    }];
}

- (void)reset
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [_connection stop];
    }];
}

- (void)stop
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [self activeTransactionIds:^(NSArray *activeTransactionId)
        {
            id<MTTransportDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(transportTransactionsMayHaveFailed:transactionIds:)])
                [delegate transportTransactionsMayHaveFailed:self transactionIds:activeTransactionId];
        }];
        
        _stopped = true;
        _connectionConnected = false;
        _connectionIsValid = false;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionStateChanged:isConnected:)])
            [delegate transportConnectionStateChanged:self isConnected:false];
        
        _connectionBehaviour.needsReconnection = false;
        
        _connection.delegate = nil;
        [_connection stop];
        _connection = nil;
        
        [self stopConnectionWatchdogTimer];
        [self stopSleepWatchdogTimer];
        
        [_actualizationPingResendTimer invalidate];
        _actualizationPingResendTimer = nil;
    }];
}

- (void)startSleepWatchdogTimer
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
#if !TARGET_OS_IPHONE
        if (_sleepWatchdogTimer == nil)
        {
            _sleepWatchdogTimerLastTime = MTAbsoluteSystemTime();
            
            __weak MTTcpTransport *weakSelf = self;
            _sleepWatchdogTimer = [[MTTimer alloc] initWithTimeout:MTTcpTransportSleepWatchdogTimeout repeat:true completion:^
            {
                CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
                
                __strong MTTcpTransport *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    if (ABS(currentTime - strongSelf->_sleepWatchdogTimerLastTime) > MTTcpTransportSleepWatchdogTimeout * 2.0)
                    {
                        MTLog(@"[MTTcpTransport#%p system sleep detected, resetting connection]", strongSelf);
                        [strongSelf reset];
                    }
                    strongSelf->_sleepWatchdogTimerLastTime = currentTime;
                }
            } queue:[MTTcpConnection tcpQueue].nativeQueue];
            [_sleepWatchdogTimer start];
        }
#endif
    }];
}

- (void)restartSleepWatchdogTimer
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [_sleepWatchdogTimer resetTimeout:MTTcpTransportSleepWatchdogTimeout];
    }];
}

- (void)stopSleepWatchdogTimer
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [_sleepWatchdogTimer invalidate];
        _sleepWatchdogTimer = nil;
    }];
}

- (void)startConnectionWatchdogTimer
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (_connectionWatchdogTimer == nil)
        {
            __weak MTTcpTransport *weakSelf = self;
            _connectionWatchdogTimer = [[MTTimer alloc] initWithTimeout:10.0 repeat:false completion:^
            {
                __strong MTTcpTransport *strongSelf = weakSelf;
                [strongSelf connectionWatchdogTimeout];
            } queue:[MTTcpTransport tcpTransportQueue].nativeQueue];
            [_connectionWatchdogTimer start];
        }
    }];
}

- (void)stopConnectionWatchdogTimer
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [_connectionWatchdogTimer invalidate];
        _connectionWatchdogTimer = nil;
    }];
}

- (void)connectionWatchdogTimeout
{
    [_connectionWatchdogTimer invalidate];
    _connectionWatchdogTimer = nil;
    
    id<MTTransportDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(transportConnectionProblemsStatusChanged:hasConnectionProblems:isProbablyHttp:)])
        [delegate transportConnectionProblemsStatusChanged:self hasConnectionProblems:true isProbablyHttp:false];
}

- (void)startActualizationPingResendTimer
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (_actualizationPingResendTimer != nil)
            [_actualizationPingResendTimer invalidate];
        
        __weak MTTcpTransport *weakSelf = self;
        _actualizationPingResendTimer = [[MTTimer alloc] initWithTimeout:3 repeat:false completion:^
        {
            __strong MTTcpTransport *strongSelf = weakSelf;
            [strongSelf resendActualizationPing];
        } queue:[MTTcpTransport tcpTransportQueue].nativeQueue];
        [_actualizationPingResendTimer start];
    }];
}

- (void)stopActualizationPingResendTimer
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (_actualizationPingResendTimer != nil)
        {
            [_actualizationPingResendTimer invalidate];
            _actualizationPingResendTimer = nil;
        }
    }];
}

- (void)resendActualizationPing
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [self stopActualizationPingResendTimer];
        
        if (_currentActualizationPingMessageId != 0)
        {
            _didSendActualizationPingAfterConnection = false;
            _currentActualizationPingMessageId = 0;
            
            [self _requestTransactionFromDelegate];
        }
    }];
}

- (void)tcpConnectionOpened:(MTTcpConnection *)connection
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (_connection != connection)
            return;
        
        _connectionConnected = true;
        _connectionIsValid = false;
        [_connectionBehaviour connectionOpened];
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionStateChanged:isConnected:)])
            [delegate transportConnectionStateChanged:self isConnected:true];
        
        _didSendActualizationPingAfterConnection = false;
        _currentActualizationPingMessageId = 0;
        
        [self _requestTransactionFromDelegate];
    }];
}

- (void)tcpConnectionClosed:(MTTcpConnection *)connection
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (_connection != connection)
            return;
        
        _connectionConnected = false;
        _connectionIsValid = false;
        _connection.delegate = nil;
        _connection = nil;
        
        [_connectionBehaviour connectionClosed];
        
        _didSendActualizationPingAfterConnection = false;
        _currentActualizationPingMessageId = 0;
        
        [self restartSleepWatchdogTimer];
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionStateChanged:isConnected:)])
            [delegate transportConnectionStateChanged:self isConnected:false];
        
        if ([delegate respondsToSelector:@selector(transportTransactionsMayHaveFailed:transactionIds:)])
            [delegate transportTransactionsMayHaveFailed:self transactionIds:@[connection.internalId]];
    }];
}

- (void)tcpConnectionReceivedData:(MTTcpConnection *)connection data:(NSData *)data
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (_connection != connection)
            return;
        
        if (_currentActualizationPingMessageId != 0 && _actualizationPingResendTimer == nil)
            [self startActualizationPingResendTimer];
        
        __weak MTTcpTransport *weakSelf = self;
        [self _processIncomingData:data transactionId:connection.internalId requestTransactionAfterProcessing:false decodeResult:^(id transactionId, bool success)
        {
            if (success)
            {
                __strong MTTcpTransport *strongSelf = weakSelf;
                [strongSelf connectionIsValid:transactionId];
            }
            else
            {
                __strong MTTcpTransport *strongSelf = weakSelf;
                [strongSelf connectionIsInvalid];
            }
        }];
    }];
}

- (void)connectionIsValid:(id)transactionId
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (_connection != nil && [_connection.internalId isEqual:transactionId])
        {
            _connectionIsValid = true;
            [_connectionBehaviour connectionValidDataReceived];
        }
        
        [self stopConnectionWatchdogTimer];
    }];
}

- (void)connectionIsInvalid
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionProblemsStatusChanged:hasConnectionProblems:isProbablyHttp:)])
            [delegate transportConnectionProblemsStatusChanged:self hasConnectionProblems:true isProbablyHttp:true];
    }];
}

- (void)tcpConnectionReceivedQuickAck:(MTTcpConnection *)connection quickAck:(int32_t)quickAck
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (_connection != connection)
            return;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportReceivedQuickAck:quickAckId:)])
            [delegate transportReceivedQuickAck:self quickAckId:quickAck];
    }];
}

- (void)tcpConnectionDecodePacketProgressToken:(MTTcpConnection *)connection data:(NSData *)data token:(int64_t)token completion:(void (^)(int64_t token, id packetProgressToken))completion
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (_connection != connection)
            return;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportDecodeProgressToken:data:token:completion:)])
            [delegate transportDecodeProgressToken:self data:data token:token completion:completion];
    }];
}

- (void)tcpConnectionProgressUpdated:(MTTcpConnection *)connection packetProgressToken:(id)packetProgressToken packetLength:(NSUInteger)packetLength progress:(float)progress
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (_connection != connection)
            return;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportUpdatedDataReceiveProgress:progressToken:packetLength:progress:)])
            [delegate transportUpdatedDataReceiveProgress:self progressToken:packetProgressToken packetLength:packetLength progress:progress];
    }];
}

- (void)tcpConnectionBehaviourRequestsReconnection:(MTTcpConnectionBehaviour *)behaviour
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (_connectionBehaviour != behaviour)
            return;
        
        if (!_stopped)
            [self startIfNeeded];
    }];
}

- (void)_requestTransactionFromDelegate
{
    if (_isWaitingForTransactionToBecomeReady)
    {
        if (!_didSendActualizationPingAfterConnection)
        {
            MTLog(@"[MTTcpTransport#%x unlocking transaction processing due to connection context update task]", (int)self);
            _isWaitingForTransactionToBecomeReady = false;
            _transactionLockTime = 0.0;
        }
        else if (CFAbsoluteTimeGetCurrent() > _transactionLockTime + 1.0)
        {
            MTLog(@"[MTTcpTransport#%x unlocking transaction processing due to timeout]", (int)self);
            _isWaitingForTransactionToBecomeReady = false;
            _transactionLockTime = 0.0;
        }
        else
        {
            MTLog(@"[MTTcpTransport#%x skipping transaction request]", (int)self);
            _requestAnotherTransactionWhenReady = true;
            
            return;
        }
    }
    
    id<MTTransportDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(transportReadyForTransaction:transportSpecificTransaction:forceConfirmations:transactionReady:)])
    {
        _isWaitingForTransactionToBecomeReady = true;
        _transactionLockTime = CFAbsoluteTimeGetCurrent();
        
        MTMessageTransaction *transportSpecificTransaction = nil;
        if (!_didSendActualizationPingAfterConnection)
        {
            _didSendActualizationPingAfterConnection = true;
            
            int64_t randomId = 0;
            arc4random_buf(&randomId, 8);
            MTOutgoingMessage *outgoingMessage = [[MTOutgoingMessage alloc] initWithBody:[self.context.serialization ping:randomId]];
            outgoingMessage.requiresConfirmation = false;
            
            __weak MTTcpTransport *weakSelf = self;
            transportSpecificTransaction = [[MTMessageTransaction alloc] initWithMessagePayload:@[outgoingMessage] completion:^(__unused NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId)
            {
                MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[outgoingMessage.internalId];
                [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
                {
                    if (preparedMessage != nil)
                    {
                        _currentActualizationPingMessageId = preparedMessage.messageId;
                        
                        __strong MTTcpTransport *strongSelf = weakSelf;
                        id<MTTransportDelegate> delegate = strongSelf.delegate;
                        if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
                            [delegate transportConnectionContextUpdateStateChanged:strongSelf isUpdatingConnectionContext:true];
                    }
                }];
            }];
            transportSpecificTransaction.requiresEncryption = true;
        }
        
        [delegate transportReadyForTransaction:self transportSpecificTransaction:transportSpecificTransaction forceConfirmations:transportSpecificTransaction != nil transactionReady:^(NSArray *transactionList)
        {
            [[MTTcpConnection tcpQueue] dispatchOnQueue:^
            {
                for (MTTransportTransaction *transaction in transactionList)
                {
                    if (transaction.payload.length != 0)
                    {
                        if (_connection != nil)
                        {
                            id transactionId = _connection.internalId;
                            [_connection sendDatas:@[transaction.payload] completion:^(bool success)
                            {
                                if (transaction.completion)
                                    transaction.completion(success, transactionId);
                            } requestQuickAck:transaction.needsQuickAck expectDataInResponse:transaction.expectsDataInResponse];
                        }
                        else if (transaction.completion != nil)
                            transaction.completion(false, nil);
                    }
                }
                
                [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
                {
                    _isWaitingForTransactionToBecomeReady = false;
                    
                    if (_requestAnotherTransactionWhenReady)
                    {
                        _requestAnotherTransactionWhenReady = false;
                        [self _requestTransactionFromDelegate];
                    }
                }];
            }];
        }];
    }
}

- (void)activeTransactionIds:(void (^)(NSArray *activeTransactionId))completion
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (completion && _connection != nil)
            completion(@[_connection.internalId]);
    }];
}

- (void)_networkAvailabilityChanged:(bool)networkAvailable
{
    [super _networkAvailabilityChanged:networkAvailable];
    
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        _isNetworkAvailable = networkAvailable;
        
        if (networkAvailable)
            [_connectionBehaviour clearBackoff];
        
        [_connection stop];
    }];
}

- (void)mtProtoDidChangeSession:(MTProto *)__unused mtProto
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [self stopActualizationPingResendTimer];
        _currentActualizationPingMessageId = 0;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
            [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
    }];
}

- (void)mtProtoServerDidChangeSession:(MTProto *)__unused mtProto firstValidMessageId:(int64_t)firstValidMessageId otherValidMessageIds:(NSArray *)otherValidMessageIds
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (_currentActualizationPingMessageId != 0 && (_currentActualizationPingMessageId < firstValidMessageId && ![otherValidMessageIds containsObject:@(_currentActualizationPingMessageId)]))
        {
            [self stopActualizationPingResendTimer];
            
            _currentActualizationPingMessageId = 0;
            
            id<MTTransportDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
                [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
        }
    }];
}

- (void)mtProto:(MTProto *)__unused mtProto receivedMessage:(MTIncomingMessage *)incomingMessage
{
    if ([self.context.serialization isMessagePong:incomingMessage.body])
    {
        [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
        {
            if (_currentActualizationPingMessageId != 0 && [self.context.serialization pongMessageId:incomingMessage.body] == _currentActualizationPingMessageId)
            {
                [self stopActualizationPingResendTimer];
                
                _currentActualizationPingMessageId = 0;
                
                id<MTTransportDelegate> delegate = self.delegate;
                if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
                    [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
            }
        }];
    }
}

- (void)mtProto:(MTProto *)__unused mtProto messageDeliveryFailed:(int64_t)messageId
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (_currentActualizationPingMessageId != 0 && messageId == _currentActualizationPingMessageId)
        {
            [self stopActualizationPingResendTimer];
            _currentActualizationPingMessageId = 0;
            
            id<MTTransportDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
                [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
        }
    }];
}

@end
