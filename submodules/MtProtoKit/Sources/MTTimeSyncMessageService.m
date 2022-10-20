#import <MtProtoKit/MTTimeSyncMessageService.h>

#import <MtProtoKit/MTTime.h>
#import <MtProtoKit/MTContext.h>
#import <MtProtoKit/MTProto.h>
#import <MtProtoKit/MTSerialization.h>
#import <MtProtoKit/MTOutgoingMessage.h>
#import <MtProtoKit/MTIncomingMessage.h>
#import <MtProtoKit/MTPreparedMessage.h>
#import <MtProtoKit/MTMessageTransaction.h>
#import <MtProtoKit/MTDatacenterSaltInfo.h>
#import "MTBuffer.h"
#import "MTFutureSaltsMessage.h"

@interface MTTimeSyncMessageService ()
{
    int64_t _currentMessageId;
    id _currentTransactionId;
    CFAbsoluteTime _currentSampleAbsoluteStartTime;
    
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

- (MTMessageTransaction *)mtProtoMessageTransaction:(MTProto *)mtProto authInfoSelector:(MTDatacenterAuthInfoSelector)authInfoSelector sessionInfo:(MTSessionInfo *)sessionInfo scheme:(MTTransportScheme *)scheme
{
    if (_currentTransactionId == nil)
    {
        _currentMessageId = 0;
        _currentTransactionId = nil;
        _currentSampleAbsoluteStartTime = 0.0;
        
        MTBuffer *getFutureSaltsBuffer = [[MTBuffer alloc] init];
        [getFutureSaltsBuffer appendInt32:(int32_t)0xb921bd04];
        [getFutureSaltsBuffer appendInt32:_futureSalts.count != 0 ? 1 : 32];
        
        MTOutgoingMessage *outgoingMessage = [[MTOutgoingMessage alloc] initWithData:getFutureSaltsBuffer.data metadata:@"getFutureSalts" additionalDebugDescription:nil shortMetadata:@"getFutureSalts"];
        
        return [[MTMessageTransaction alloc] initWithMessagePayload:@[outgoingMessage] prepared:nil failed:nil completion:^(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId)
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

- (void)mtProto:(MTProto *)mtProto receivedMessage:(MTIncomingMessage *)message authInfoSelector:(MTDatacenterAuthInfoSelector)authInfoSelector
{
    if ([message.body isKindOfClass:[MTFutureSaltsMessage class]] && ((MTFutureSaltsMessage *)message.body).requestMessageId == _currentMessageId)
    {
        _currentMessageId = 0;
        _currentTransactionId = nil;
        
        NSMutableArray *saltList = [[NSMutableArray alloc] init];
        for (MTFutureSalt *futureSalt in ((MTFutureSaltsMessage *)message.body).salts)
        {
            [saltList addObject:[[MTDatacenterSaltInfo alloc] initWithSalt:futureSalt.salt firstValidMessageId:futureSalt.validSince * 4294967296 lastValidMessageId:futureSalt.validUntil * 4294967296]];
        }
        
        [_futureSalts addObjectsFromArray:saltList];
        
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
