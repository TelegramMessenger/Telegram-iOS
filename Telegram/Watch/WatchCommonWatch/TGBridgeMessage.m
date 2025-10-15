#import "TGBridgeMessage.h"
//#import "TGWatchCommon.h"
#import "TGBridgePeerIdAdapter.h"

NSString *const TGBridgeMessageIdentifierKey = @"identifier";
NSString *const TGBridgeMessageDateKey = @"date";
NSString *const TGBridgeMessageRandomIdKey = @"randomId";
NSString *const TGBridgeMessageFromUidKey = @"fromUid";
NSString *const TGBridgeMessageCidKey = @"cid";
NSString *const TGBridgeMessageTextKey = @"text";
NSString *const TGBridgeMessageUnreadKey = @"unread";
NSString *const TGBridgeMessageOutgoingKey = @"outgoing";
NSString *const TGBridgeMessageMediaKey = @"media";
NSString *const TGBridgeMessageDeliveryStateKey = @"deliveryState";
NSString *const TGBridgeMessageForceReplyKey = @"forceReply";

NSString *const TGBridgeMessageKey = @"message";
NSString *const TGBridgeMessagesArrayKey = @"messages";

@interface TGBridgeMessage ()
{
    NSArray *_textCheckingResults;
}
@end

@implementation TGBridgeMessage

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _identifier = [aDecoder decodeInt32ForKey:TGBridgeMessageIdentifierKey];
        _date = [aDecoder decodeDoubleForKey:TGBridgeMessageDateKey];
        _randomId = [aDecoder decodeInt64ForKey:TGBridgeMessageRandomIdKey];
        _fromUid = [aDecoder decodeInt64ForKey:TGBridgeMessageFromUidKey];
        _cid = [aDecoder decodeInt64ForKey:TGBridgeMessageCidKey];
        _text = [aDecoder decodeObjectForKey:TGBridgeMessageTextKey];
        _outgoing = [aDecoder decodeBoolForKey:TGBridgeMessageOutgoingKey];
        _unread = [aDecoder decodeBoolForKey:TGBridgeMessageUnreadKey];
        _deliveryState = [aDecoder decodeInt32ForKey:TGBridgeMessageDeliveryStateKey];
        _media = [aDecoder decodeObjectForKey:TGBridgeMessageMediaKey];
        _forceReply = [aDecoder decodeBoolForKey:TGBridgeMessageForceReplyKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:self.identifier forKey:TGBridgeMessageIdentifierKey];
    [aCoder encodeDouble:self.date forKey:TGBridgeMessageDateKey];
    [aCoder encodeInt64:self.randomId forKey:TGBridgeMessageRandomIdKey];
    [aCoder encodeInt64:self.fromUid forKey:TGBridgeMessageFromUidKey];
    [aCoder encodeInt64:self.cid forKey:TGBridgeMessageCidKey];
    [aCoder encodeObject:self.text forKey:TGBridgeMessageTextKey];
    [aCoder encodeBool:self.outgoing forKey:TGBridgeMessageOutgoingKey];
    [aCoder encodeBool:self.unread forKey:TGBridgeMessageUnreadKey];
    [aCoder encodeInt32:self.deliveryState forKey:TGBridgeMessageDeliveryStateKey];
    [aCoder encodeObject:self.media forKey:TGBridgeMessageMediaKey];
    [aCoder encodeBool:self.forceReply forKey:TGBridgeMessageForceReplyKey];
}

- (NSArray<NSNumber *> *)involvedUserIds
{
    NSMutableSet<NSNumber *> *userIds = [[NSMutableSet alloc] init];
    if (!TGPeerIdIsChannel(self.fromUid))
        [userIds addObject:[NSNumber numberWithLongLong:self.fromUid]];
    
    for (TGBridgeMediaAttachment *attachment in self.media)
    {
        if ([attachment isKindOfClass:[TGBridgeContactMediaAttachment class]])
        {
            TGBridgeContactMediaAttachment *contactAttachment = (TGBridgeContactMediaAttachment *)attachment;
            if (contactAttachment.uid != 0)
                [userIds addObject:[NSNumber numberWithLongLong:contactAttachment.uid]];
        }
        else if ([attachment isKindOfClass:[TGBridgeForwardedMessageMediaAttachment class]])
        {
            TGBridgeForwardedMessageMediaAttachment *forwardAttachment = (TGBridgeForwardedMessageMediaAttachment *)attachment;
            if (forwardAttachment.peerId != 0 && !TGPeerIdIsChannel(forwardAttachment.peerId))
                [userIds addObject:[NSNumber numberWithLongLong:forwardAttachment.peerId]];
        }
        else if ([attachment isKindOfClass:[TGBridgeReplyMessageMediaAttachment class]])
        {
            TGBridgeReplyMessageMediaAttachment *replyAttachment = (TGBridgeReplyMessageMediaAttachment *)attachment;
            if (replyAttachment.message != nil && !TGPeerIdIsChannel(replyAttachment.message.fromUid))
                [userIds addObject:[NSNumber numberWithLongLong:replyAttachment.message.fromUid]];
        }
        else if ([attachment isKindOfClass:[TGBridgeActionMediaAttachment class]])
        {
            TGBridgeActionMediaAttachment *actionAttachment = (TGBridgeActionMediaAttachment *)attachment;
            if (actionAttachment.actionData[@"uid"] != nil)
                [userIds addObject:[NSNumber numberWithLongLong:[actionAttachment.actionData[@"uid"] intValue]]];
        }
    }
    
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (NSNumber *object in userIds) {
        [result addObject:object];
    }
    return result;
}

- (NSArray *)textCheckingResults
{
    if (_textCheckingResults == nil)
    {
        NSMutableArray *results = [[NSMutableArray alloc] init];
        
        NSArray *entities = nil;
        for (TGBridgeMediaAttachment *attachment in self.media)
        {
            if ([attachment isKindOfClass:[TGBridgeMessageEntitiesAttachment class]])
            {
                entities = ((TGBridgeMessageEntitiesAttachment *)attachment).entities;
                break;
            }
        }
        
        for (TGBridgeMessageEntity *entity in entities)
        {
            TGBridgeTextCheckingResult *result = [[TGBridgeTextCheckingResult alloc] init];
            result.range = entity.range;
            
            if ([entity isKindOfClass:[TGBridgeMessageEntityBold class]])
                result.type = TGBridgeTextCheckingResultTypeBold;
            else if ([entity isKindOfClass:[TGBridgeMessageEntityItalic class]])
                result.type = TGBridgeTextCheckingResultTypeItalic;
            else if ([entity isKindOfClass:[TGBridgeMessageEntityCode class]])
                result.type = TGBridgeTextCheckingResultTypeCode;
            else if ([entity isKindOfClass:[TGBridgeMessageEntityPre class]])
                result.type = TGBridgeTextCheckingResultTypePre;
        
            if (result.type != TGBridgeTextCheckingResultTypeUndefined)
                [results addObject:result];
        }
        
        _textCheckingResults = results;
    }
    
    return _textCheckingResults;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    
    TGBridgeMessage *message = (TGBridgeMessage *)object;
    
    if (self.randomId != 0)
        return self.randomId == message.randomId;
    else
        return self.identifier == message.identifier;
}

+ (instancetype)temporaryNewMessageForText:(NSString *)text userId:(int32_t)userId
{
    return [self temporaryNewMessageForText:text userId:userId replyToMessage:nil];
}

+ (instancetype)temporaryNewMessageForText:(NSString *)text userId:(int32_t)userId replyToMessage:(TGBridgeMessage *)replyToMessage
{
    int64_t randomId = 0;
    arc4random_buf(&randomId, 8);
    
    int32_t messageId = 0;
    arc4random_buf(&messageId, 4);
    
    TGBridgeMessage *message = [[TGBridgeMessage alloc] init];
    message->_identifier = -abs(messageId);
    message->_fromUid = userId;
    message->_randomId = randomId;
    message->_unread = true;
    message->_outgoing = true;
    message->_deliveryState = TGBridgeMessageDeliveryStatePending;
    message->_text = text;
    message->_date = [[NSDate date] timeIntervalSince1970];
    
    if (replyToMessage != nil)
    {
        TGBridgeReplyMessageMediaAttachment *replyAttachment = [[TGBridgeReplyMessageMediaAttachment alloc] init];
        replyAttachment.mid = replyToMessage.identifier;
        replyAttachment.message = replyToMessage;
        
        message->_media = @[ replyToMessage ];
    }
    
    return message;
}

+ (instancetype)temporaryNewMessageForSticker:(TGBridgeDocumentMediaAttachment *)sticker userId:(int32_t)userId
{
    return [self _temporaryNewMessageForMediaAttachment:sticker userId:userId];
}

+ (instancetype)temporaryNewMessageForLocation:(TGBridgeLocationMediaAttachment *)location userId:(int32_t)userId
{
    return [self _temporaryNewMessageForMediaAttachment:location userId:userId];
}

+ (instancetype)temporaryNewMessageForAudioWithDuration:(int32_t)duration userId:(int32_t)userId localAudioId:(int64_t)localAudioId
{
    TGBridgeDocumentMediaAttachment *document = [[TGBridgeDocumentMediaAttachment alloc] init];
    document.isAudio = true;
    document.isVoice = true;
    document.localDocumentId = localAudioId;
    document.duration = duration;
    
    return [self _temporaryNewMessageForMediaAttachment:document userId:userId];
}

+ (instancetype)_temporaryNewMessageForMediaAttachment:(TGBridgeMediaAttachment *)attachment userId:(int32_t)userId
{
    int64_t randomId = 0;
    arc4random_buf(&randomId, 8);
    
    int32_t messageId = 0;
    arc4random_buf(&messageId, 4);
    
    TGBridgeMessage *message = [[TGBridgeMessage alloc] init];
    message->_identifier = -abs(messageId);
    message->_fromUid = userId;
    message->_unread = true;
    message->_outgoing = true;
    message->_deliveryState = TGBridgeMessageDeliveryStatePending;
    message->_date = [[NSDate date] timeIntervalSince1970];
    
    message->_media = @[ attachment ];
    
    return message;
}

@end


@implementation TGBridgeTextCheckingResult

@end
