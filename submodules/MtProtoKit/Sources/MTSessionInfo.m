#import <MtProtoKit/MTSessionInfo.h>

#import <MtProtoKit/MTLogging.h>
#import <MtProtoKit/MTContext.h>

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
    
    NSMutableSet *_processedMessageIdsSet;
    NSMutableArray *_scheduledMessageConfirmations;
    NSMutableDictionary *_containerMessagesMappingDict;
    NSMutableSet *_sentMessageIdsSet;
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
        
        _processedMessageIdsSet = [[NSMutableSet alloc] init];
        _sentMessageIdsSet = [[NSMutableSet alloc] init];
        _containerMessagesMappingDict = [[NSMutableDictionary alloc] init];
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
    return [_processedMessageIdsSet containsObject:@(messageId)];
}

- (void)setMessageProcessed:(int64_t)messageId
{
    [_processedMessageIdsSet addObject:@(messageId)];
}

- (bool)wasMessageSentOnce:(int64_t)messageId {
    return [_sentMessageIdsSet containsObject:@(messageId)];
}

- (void)setMessageWasSentOnce:(int64_t)messageId {
    [_sentMessageIdsSet addObject:@(messageId)];
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
    _containerMessagesMappingDict[@(containerMessageId)] = childMessageIds;
}

- (NSArray *)messageIdsInContainer:(int64_t)containerMessageId
{
    return _containerMessagesMappingDict[@(containerMessageId)];
}

- (NSArray *)messageIdsInContainersAfterMessageId:(int64_t)firstMessageId
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    [_containerMessagesMappingDict enumerateKeysAndObjectsUsingBlock:^(NSNumber *nContainerMessageId, NSArray *messageIds, __unused BOOL *stop)
    {
        int64_t containerMessageId = (int64_t)[nContainerMessageId longLongValue];
        for (NSNumber *nMessageId in messageIds)
        {
            if (containerMessageId >= firstMessageId || ((int64_t)[nMessageId longLongValue]) >= firstMessageId)
            {
                [array addObject:nMessageId];
            }
        }
    }];
    
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
