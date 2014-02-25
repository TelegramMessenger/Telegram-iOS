/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <MTProtoKit/MTSessionInfo.h>

#import <MTProtoKit/MTContext.h>

#import <set>
#import <vector>
#import <map>

@interface MTScheduledMessageConfirmation : NSObject

@property (nonatomic) int64_t messageId;
@property (nonatomic) NSInteger size;
@property (nonatomic, strong) NSMutableArray *transactionIds;

@end

@implementation MTScheduledMessageConfirmation

- (instancetype)initWithMessageId:(int64_t)messageId size:(NSInteger)size
{
    self = [super init];
    if (self != nil)
    {
        _messageId = messageId;
        _size = size;
    }
    return self;
}

- (void)addTransactionId:(id)transactionId
{
    if (_transactionIds == nil)
        _transactionIds = [[NSMutableArray alloc] init];
    if (![_transactionIds containsObject:transactionId])
        [_transactionIds addObject:transactionId];
}

- (bool)containedInTransactionId:(id)transactionId
{
    return [_transactionIds containsObject:transactionId];
}

@end

@interface MTSessionInfo ()
{
    int64_t _sessionId;
    MTContext *_context;
    
    int64_t _lastClientMessageId;
    int32_t _seqNo;
    
    int64_t _lastServerMessageId;
    
    std::set<int64_t> _processedMessageIds;
    NSMutableArray *_scheduledMessageConfirmations;
    std::map<int64_t, NSArray *> _containerMessagesMapping;
}

@end

@implementation MTSessionInfo

- (instancetype)initWithRandomSessionIdAndContext:(MTContext *)context
{
    int64_t randomId = 0;
    arc4random_buf(&randomId, sizeof(randomId));
    return [self initWithSessionId:randomId context:context];
}

- (instancetype)initWithSessionId:(int64_t)sessionId context:(MTContext *)context
{
    self = [super init];
    if (self != nil)
    {
        _sessionId = sessionId;
        _context = context;
        
        _scheduledMessageConfirmations = [[NSMutableArray alloc] init];
    }
    return self;
}

- (int64_t)sessionId
{
    return _sessionId;
}

- (int64_t)generateClientMessageId:(bool *)monotonityViolated
{
    int64_t messageId = (int64_t)([_context globalTime] * 4294967296);
    
    if (messageId < _lastClientMessageId)
    {
        if (monotonityViolated != NULL)
            *monotonityViolated = true;
    }
    
    if (messageId == _lastClientMessageId)
        messageId = _lastClientMessageId + 1;
    
    while (messageId % 4 != 0)
        messageId++;
    
    _lastClientMessageId = messageId;
    return messageId;
}

- (int64_t)actualClientMessagId
{
    int64_t messageId = (int64_t)([_context globalTime] * 4294967296);
    
    while (messageId % 4 != 0)
        messageId++;
    
    return messageId;
}

- (int64_t)generateServerMessageId
{
    int64_t messageId = (int64_t)(([_context globalTime]) * 4294967296);
    if (messageId == _lastServerMessageId)
        messageId++;
    while (messageId % 4 != 1)
        messageId++;
    
    _lastServerMessageId = messageId;
    return messageId;
}

- (bool)messageProcessed:(int64_t)messageId
{
    return _processedMessageIds.find(messageId) != _processedMessageIds.end();
}

- (void)setMessageProcessed:(int64_t)messageId
{
    _processedMessageIds.insert(messageId);
}

- (void)scheduleMessageConfirmation:(int64_t)messageId size:(NSInteger)size
{
    bool found = false;
    for (MTScheduledMessageConfirmation *confirmation in _scheduledMessageConfirmations)
    {
        if (confirmation.messageId == messageId)
        {
            found = true;
            break;
        }
    }
    
    if (!found)
        [_scheduledMessageConfirmations addObject:[[MTScheduledMessageConfirmation alloc] initWithMessageId:messageId size:size]];
}

- (NSArray *)scheduledMessageConfirmations
{
    if (_scheduledMessageConfirmations.count == 0)
        return nil;
    
    NSMutableArray *filteredConfirmations = [[NSMutableArray alloc] init];
    
    for (MTScheduledMessageConfirmation *confirmation in _scheduledMessageConfirmations)
    {
        [filteredConfirmations addObject:@(confirmation.messageId)];
    }
    
    return filteredConfirmations;
}

- (bool)scheduledMessageConfirmationsExceedSize:(NSInteger)sizeLimit orCount:(NSUInteger)countLimit
{
    if (_scheduledMessageConfirmations.count > countLimit)
        return true;
    
    if (_scheduledMessageConfirmations.count == 0)
        return false;
    
    NSInteger completeSize = 0;
    for (MTScheduledMessageConfirmation *confirmation in _scheduledMessageConfirmations)
    {
        completeSize += confirmation.size;
    }
    
    if (completeSize <= sizeLimit)
        return false;
    
    return true;
}

- (void)removeScheduledMessageConfirmationsWithIds:(NSArray *)messageIds
{
    for (NSNumber *nMessageId in messageIds)
    {
        int64_t messageId = (int64_t)[nMessageId longLongValue];
        
        NSInteger count = (NSInteger)_scheduledMessageConfirmations.count;
        for (NSInteger i = 0; i < count; i++)
        {
            if (((MTScheduledMessageConfirmation *)_scheduledMessageConfirmations[(NSUInteger)i]).messageId == messageId)
            {
                [_scheduledMessageConfirmations removeObjectAtIndex:(NSUInteger)i];
                
                break;
            }
        }
    }
}

- (void)assignTransactionId:(id)transactionId toScheduledMessageConfirmationsWithIds:(NSArray *)messageIds
{
    for (MTScheduledMessageConfirmation *confirmation in _scheduledMessageConfirmations)
    {
        if ([messageIds containsObject:@(confirmation.messageId)])
            [confirmation addTransactionId:transactionId];
    }
}

- (void)removeScheduledMessageConfirmationsWithTransactionIds:(NSArray *)transactionIds
{
    NSInteger count = (NSInteger)_scheduledMessageConfirmations.count;
    for (NSInteger i = 0; i < count; i++)
    {
        for (id transactionId in transactionIds)
        {
            if ([((MTScheduledMessageConfirmation *)_scheduledMessageConfirmations[(NSUInteger)i]) containedInTransactionId:transactionId])
            {
                [_scheduledMessageConfirmations removeObjectAtIndex:(NSUInteger)i];
                i--;
                count--;
                
                break;
            }
        }
    }
}

- (void)addContainerMessageIdMapping:(int64_t)containerMessageId childMessageIds:(NSArray *)childMessageIds
{
    _containerMessagesMapping[containerMessageId] = childMessageIds;
}

- (NSArray *)messageIdsInContainer:(int64_t)containerMessageId
{
    auto it = _containerMessagesMapping.find(containerMessageId);
    if (it != _containerMessagesMapping.end())
        return it->second;
    
    return nil;
}

- (NSArray *)messageIdsInContainersAfterMessageId:(int64_t)firstMessageId
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    for (auto it = _containerMessagesMapping.begin(); it != _containerMessagesMapping.end(); it++)
    {
        for (NSNumber *nMessageId in it->second)
        {
            if (it->first >= firstMessageId || ((int64_t)[nMessageId longLongValue]) >= firstMessageId)
            {
                [array addObject:nMessageId];
            }
        }
    }
    
    return array;
}

- (int32_t)takeSeqNo:(bool)messageIsMeaningful
{
    int32_t seqNo = 0;
    
    if (messageIsMeaningful)
    {
        seqNo = _seqNo + 1;
        _seqNo += 2;
    }
    else
        seqNo = _seqNo;
    
    return seqNo;
}

@end
