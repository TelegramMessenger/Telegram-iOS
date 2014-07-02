/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTTimeSyncMessageService.h>

#import <MTTime.h>
#import <MTProtoKit/MTContext.h>
#import <MTProtoKit/MTProto.h>
#import <MTProtoKit/MTSerialization.h>
#import <MTProtoKit/MTOutgoingMessage.h>
#import <MTProtoKit/MTIncomingMessage.h>
#import <MTProtoKit/MTPreparedMessage.h>
#import <MTProtoKit/MTMessageTransaction.h>

#import <MTProtoKit/MTDatacenterSaltInfo.h>

@interface MTTimeSyncMessageService ()
{
    int64_t _currentMessageId;
    id _currentTransactionId;
    MTAbsoluteTime _currentSampleAbsoluteStartTime;
    
    NSUInteger _takenSampleCount;
    NSUInteger _requiredSampleCount;
    NSMutableArray *_takenSamples;
    
    NSMutableArray *_futureSalts;
}

@end

@implementation MTTimeSyncMessageService

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _takenSamples = [[NSMutableArray alloc] init];
        _futureSalts = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)mtProtoDidAddService:(MTProto *)mtProto
{
    [mtProto requestTransportTransaction];
}

- (MTMessageTransaction *)mtProtoMessageTransaction:(MTProto *)mtProto
{
    if (_currentTransactionId == nil)
    {
        _currentMessageId = 0;
        _currentTransactionId = nil;
        _currentSampleAbsoluteStartTime = 0.0;
        
        MTOutgoingMessage *outgoingMessage = [[MTOutgoingMessage alloc] initWithBody:[mtProto.context.serialization getFutureSalts:_futureSalts.count != 0 ? 1 : 32]];
        
        return [[MTMessageTransaction alloc] initWithMessagePayload:@[outgoingMessage] completion:^(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId)
        {
            MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[outgoingMessage.internalId];
            if (preparedMessage != nil && messageInternalIdToTransactionId[outgoingMessage.internalId] != nil)
            {
                _currentMessageId = preparedMessage.messageId;
                _currentTransactionId = messageInternalIdToTransactionId[outgoingMessage.internalId];
                _currentSampleAbsoluteStartTime = MTAbsoluteSystemTime();
            }
        }];
    }
    else
        return nil;
}

- (void)mtProto:(MTProto *)__unused mtProto messageDeliveryFailed:(int64_t)messageId
{
    if (messageId == _currentMessageId)
    {
        _currentMessageId = 0;
        _currentTransactionId = nil;
        _currentSampleAbsoluteStartTime = 0.0;
        
        [mtProto requestTransportTransaction];
    }
}

- (void)mtProto:(MTProto *)mtProto transactionsMayHaveFailed:(NSArray *)transactionIds
{
    if (_currentTransactionId != nil && [transactionIds containsObject:_currentTransactionId])
    {
        _currentTransactionId = nil;
        
        [mtProto requestTransportTransaction];
    }
}

- (void)mtProtoAllTransactionsMayHaveFailed:(MTProto *)mtProto
{
    if (_currentTransactionId != nil)
    {
        _currentTransactionId = nil;
        
        [mtProto requestTransportTransaction];
    }
}

- (void)mtProtoDidChangeSession:(MTProto *)mtProto
{
    _currentMessageId = 0;
    _currentTransactionId = nil;
    _currentSampleAbsoluteStartTime = 0.0;
    
    [mtProto requestTransportTransaction];
}

- (void)mtProtoServerDidChangeSession:(MTProto *)mtProto firstValidMessageId:(int64_t)firstValidMessageId messageIdsInFirstValidContainer:(NSArray *)messageIdsInFirstValidContainer
{
    if (_currentMessageId != 0 && _currentMessageId < firstValidMessageId && ![messageIdsInFirstValidContainer containsObject:@(_currentMessageId)])
    {
        _currentMessageId = 0;
        _currentTransactionId = nil;
        _currentSampleAbsoluteStartTime = 0.0;
        
        [mtProto requestTransportTransaction];
    }
}

- (void)mtProto:(MTProto *)mtProto receivedMessage:(MTIncomingMessage *)message
{
    if ([mtProto.context.serialization isMessageFutureSalts:message.body] && [mtProto.context.serialization futureSaltsRequestMessageId:message.body] == _currentMessageId)
    {
        _currentMessageId = 0;
        _currentTransactionId = nil;
        
        [_futureSalts addObjectsFromArray:[mtProto.context.serialization saltInfoListFromMessage:message.body]];
        
        NSTimeInterval timeDifference = message.messageId / 4294967296.0 - [[NSDate date] timeIntervalSince1970];
        [_takenSamples addObject:@(timeDifference)];
        _takenSampleCount++;
        
        bool requestTransaction = false;
        
        if (_requiredSampleCount == 0)
        {
            if (ABS(MTAbsoluteSystemTime() - _currentSampleAbsoluteStartTime) > 1.0)
            {
                _requiredSampleCount = 6;
                requestTransaction = true;
            }
        }
        
        if (_takenSampleCount >= _requiredSampleCount)
        {
            NSTimeInterval maxSampleAbs = 0.0;
            NSUInteger maxSampleIndex = NSNotFound;
            NSTimeInterval minSampleAbs = 0.0;
            NSUInteger minSampleIndex = NSNotFound;
            
            NSInteger index = -1;
            for (NSNumber *nSample in _takenSamples)
            {
                index++;
                
                if (maxSampleIndex == NSNotFound || ABS([nSample doubleValue]) > maxSampleAbs)
                {
                    maxSampleAbs = ABS([nSample doubleValue]);
                    maxSampleIndex = (NSUInteger)index;
                }
                
                if (minSampleIndex == NSNotFound || ABS([nSample doubleValue]) < minSampleAbs)
                {
                    minSampleAbs = ABS([nSample doubleValue]);
                    minSampleIndex = (NSUInteger)index;
                }
            }
            
            NSMutableIndexSet *indexSet = [[NSMutableIndexSet alloc] init];
            if (maxSampleIndex != NSNotFound)
                [indexSet addIndex:maxSampleIndex];
            if (minSampleIndex != NSNotFound)
                [indexSet addIndex:minSampleIndex];
            [_takenSamples removeObjectsAtIndexes:indexSet];
            
            NSTimeInterval totalTimeDifference = 0.0;
            if (_takenSamples.count != 0)
            {
                NSTimeInterval timeDifferenceSum = 0.0;
                for (NSNumber *nSample in _takenSamples)
                {
                    timeDifferenceSum += [nSample doubleValue];
                }
                totalTimeDifference = timeDifferenceSum / _takenSamples.count;
            }
            else
                totalTimeDifference = timeDifference;
            
            id<MTTimeSyncMessageServiceDelegate> delegate = _delegate;
            if ([delegate respondsToSelector:@selector(timeSyncServiceCompleted:timeDifference:saltList:)])
                [delegate timeSyncServiceCompleted:self timeDifference:totalTimeDifference saltList:_futureSalts];
        }
        else
            requestTransaction = true;
        
        if (requestTransaction)
            [mtProto requestTransportTransaction];
    }
}

@end
