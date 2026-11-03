#import "TGBridgeSubscriptions.h"

#import <UIKit/UIKit.h>

#import "TGBridgeImageMediaAttachment.h"
#import "TGBridgeVideoMediaAttachment.h"
#import "TGBridgeDocumentMediaAttachment.h"
#import "TGBridgeLocationMediaAttachment.h"
#import "TGBridgePeerNotificationSettings.h"

NSString *const TGBridgeAudioSubscriptionName = @"media.audio";
NSString *const TGBridgeAudioSubscriptionAttachmentKey = @"attachment";
NSString *const TGBridgeAudioSubscriptionPeerIdKey = @"peerId";
NSString *const TGBridgeAudioSubscriptionMessageIdKey = @"messageId";

@implementation TGBridgeAudioSubscription

- (instancetype)initWithAttachment:(TGBridgeMediaAttachment *)attachment peerId:(int64_t)peerId messageId:(int32_t)messageId
{
    self = [super init];
    if (self != nil)
    {
        _attachment = attachment;
        _peerId = peerId;
        _messageId = messageId;
    }
    return self;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.attachment forKey:TGBridgeAudioSubscriptionAttachmentKey];
    [aCoder encodeInt64:self.peerId forKey:TGBridgeAudioSubscriptionPeerIdKey];
    [aCoder encodeInt32:self.messageId forKey:TGBridgeAudioSubscriptionMessageIdKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _attachment = [aDecoder decodeObjectForKey:TGBridgeAudioSubscriptionAttachmentKey];
    _peerId = [aDecoder decodeInt64ForKey:TGBridgeAudioSubscriptionPeerIdKey];
    _messageId = [aDecoder decodeInt32ForKey:TGBridgeAudioSubscriptionMessageIdKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeAudioSubscriptionName;
}

@end


NSString *const TGBridgeAudioSentSubscriptionName = @"media.audioSent";
NSString *const TGBridgeAudioSentSubscriptionConversationIdKey = @"conversationId";

@implementation TGBridgeAudioSentSubscription

- (instancetype)initWithConversationId:(int64_t)conversationId
{
    self = [super init];
    if (self != nil)
    {
        _conversationId = conversationId;
    }
    return self;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.conversationId forKey:TGBridgeAudioSentSubscriptionConversationIdKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _conversationId = [aDecoder decodeInt64ForKey:TGBridgeAudioSentSubscriptionConversationIdKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeAudioSentSubscriptionName;
}

@end


NSString *const TGBridgeChatListSubscriptionName = @"chats.chatList";
NSString *const TGBridgeChatListSubscriptionLimitKey = @"limit";

@implementation TGBridgeChatListSubscription

- (instancetype)initWithLimit:(int32_t)limit
{
    self = [super init];
    if (self != nil)
    {
        _limit = limit;
    }
    return self;
}

- (bool)dropPreviouslyQueued
{
    return true;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:self.limit forKey:TGBridgeChatListSubscriptionLimitKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _limit = [aDecoder decodeInt32ForKey:TGBridgeChatListSubscriptionLimitKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeChatListSubscriptionName;
}

@end


NSString *const TGBridgeChatMessageListSubscriptionName = @"chats.chatMessageList";
NSString *const TGBridgeChatMessageListSubscriptionPeerIdKey = @"peerId";
NSString *const TGBridgeChatMessageListSubscriptionAtMessageIdKey = @"atMessageId";
NSString *const TGBridgeChatMessageListSubscriptionRangeMessageCountKey = @"rangeMessageCount";

@implementation TGBridgeChatMessageListSubscription

- (instancetype)initWithPeerId:(int64_t)peerId atMessageId:(int32_t)messageId rangeMessageCount:(NSUInteger)rangeMessageCount
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _atMessageId = messageId;
        _rangeMessageCount = rangeMessageCount;
    }
    return self;
}

- (bool)dropPreviouslyQueued
{
    return true;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.peerId forKey:TGBridgeChatMessageListSubscriptionPeerIdKey];
    [aCoder encodeInt32:self.atMessageId forKey:TGBridgeChatMessageListSubscriptionAtMessageIdKey];
    [aCoder encodeInt32:(int32_t)self.rangeMessageCount forKey:TGBridgeChatMessageListSubscriptionRangeMessageCountKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _peerId = [aDecoder decodeInt64ForKey:TGBridgeChatMessageListSubscriptionPeerIdKey];
    _atMessageId = [aDecoder decodeInt32ForKey:TGBridgeChatMessageListSubscriptionAtMessageIdKey];
    _rangeMessageCount = [aDecoder decodeInt32ForKey:TGBridgeChatMessageListSubscriptionRangeMessageCountKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeChatMessageListSubscriptionName;
}

@end


NSString *const TGBridgeChatMessageSubscriptionName = @"chats.message";
NSString *const TGBridgeChatMessageSubscriptionPeerIdKey = @"peerId";
NSString *const TGBridgeChatMessageSubscriptionMessageIdKey = @"mid";

@implementation TGBridgeChatMessageSubscription

- (instancetype)initWithPeerId:(int64_t)peerId messageId:(int32_t)messageId
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _messageId = messageId;
    }
    return self;
}

- (bool)synchronous
{
    return true;
}

- (bool)renewable
{
    return false;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.peerId forKey:TGBridgeChatMessageSubscriptionPeerIdKey];
    [aCoder encodeInt32:self.messageId forKey:TGBridgeChatMessageSubscriptionMessageIdKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _peerId = [aDecoder decodeInt64ForKey:TGBridgeChatMessageSubscriptionPeerIdKey];
    _messageId = [aDecoder decodeInt32ForKey:TGBridgeChatMessageSubscriptionMessageIdKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeChatMessageSubscriptionName;
}

@end


NSString *const TGBridgeReadChatMessageListSubscriptionName = @"chats.readChatMessageList";
NSString *const TGBridgeReadChatMessageListSubscriptionPeerIdKey = @"peerId";
NSString *const TGBridgeReadChatMessageListSubscriptionMessageIdKey = @"mid";

@implementation TGBridgeReadChatMessageListSubscription

- (instancetype)initWithPeerId:(int64_t)peerId messageId:(int32_t)messageId
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _messageId = messageId;
    }
    return self;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.peerId forKey:TGBridgeReadChatMessageListSubscriptionPeerIdKey];
    [aCoder encodeInt32:self.messageId forKey:TGBridgeReadChatMessageListSubscriptionMessageIdKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _peerId = [aDecoder decodeInt64ForKey:TGBridgeReadChatMessageListSubscriptionPeerIdKey];
    _messageId = [aDecoder decodeInt32ForKey:TGBridgeReadChatMessageListSubscriptionMessageIdKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeReadChatMessageListSubscriptionName;
}

@end


NSString *const TGBridgeContactsSubscriptionName = @"contacts.search";
NSString *const TGBridgeContactsSubscriptionQueryKey = @"query";

@implementation TGBridgeContactsSubscription

- (instancetype)initWithQuery:(NSString *)query
{
    self = [super init];
    if (self != nil)
    {
        _query = query;
    }
    return self;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.query forKey:TGBridgeContactsSubscriptionQueryKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _query = [aDecoder decodeObjectForKey:TGBridgeContactsSubscriptionQueryKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeContactsSubscriptionName;
}

@end


NSString *const TGBridgeConversationSubscriptionName = @"chats.conversation";
NSString *const TGBridgeConversationSubscriptionPeerIdKey = @"peerId";

@implementation TGBridgeConversationSubscription

- (instancetype)initWithPeerId:(int64_t)peerId
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
    }
    return self;
}

- (bool)dropPreviouslyQueued
{
    return true;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.peerId forKey:TGBridgeConversationSubscriptionPeerIdKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _peerId = [aDecoder decodeInt64ForKey:TGBridgeConversationSubscriptionPeerIdKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeConversationSubscriptionName;
}

@end


NSString *const TGBridgeNearbyVenuesSubscriptionName = @"location.nearbyVenues";
NSString *const TGBridgeNearbyVenuesSubscriptionLatitudeKey = @"lat";
NSString *const TGBridgeNearbyVenuesSubscriptionLongitudeKey = @"lon";
NSString *const TGBridgeNearbyVenuesSubscriptionLimitKey = @"limit";

@implementation TGBridgeNearbyVenuesSubscription

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate limit:(int32_t)limit
{
    self = [super init];
    if (self != nil)
    {
        _coordinate = coordinate;
        _limit = limit;
    }
    return self;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeDouble:self.coordinate.latitude forKey:TGBridgeNearbyVenuesSubscriptionLatitudeKey];
    [aCoder encodeDouble:self.coordinate.longitude forKey:TGBridgeNearbyVenuesSubscriptionLongitudeKey];
    [aCoder encodeInt32:self.limit forKey:TGBridgeNearbyVenuesSubscriptionLimitKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _coordinate = CLLocationCoordinate2DMake([aDecoder decodeDoubleForKey:TGBridgeNearbyVenuesSubscriptionLatitudeKey],
                                             [aDecoder decodeDoubleForKey:TGBridgeNearbyVenuesSubscriptionLongitudeKey]);
    _limit = [aDecoder decodeInt32ForKey:TGBridgeNearbyVenuesSubscriptionLimitKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeNearbyVenuesSubscriptionName;
}

@end


NSString *const TGBridgeMediaThumbnailSubscriptionName = @"media.thumbnail";
NSString *const TGBridgeMediaThumbnailPeerIdKey = @"peerId";
NSString *const TGBridgeMediaThumbnailMessageIdKey = @"mid";
NSString *const TGBridgeMediaThumbnailSizeKey = @"size";
NSString *const TGBridgeMediaThumbnailNotificationKey = @"notification";

@implementation TGBridgeMediaThumbnailSubscription

- (instancetype)initWithPeerId:(int64_t)peerId messageId:(int32_t)messageId size:(CGSize)size notification:(bool)notification
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _messageId = messageId;
        _size = size;
        _notification = notification;
    }
    return self;
}

- (bool)renewable
{
    return false;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.peerId forKey:TGBridgeMediaThumbnailPeerIdKey];
    [aCoder encodeInt32:self.messageId forKey:TGBridgeMediaThumbnailMessageIdKey];
    [aCoder encodeCGSize:self.size forKey:TGBridgeMediaThumbnailSizeKey];
    [aCoder encodeBool:self.notification forKey:TGBridgeMediaThumbnailNotificationKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _peerId = [aDecoder decodeInt64ForKey:TGBridgeMediaThumbnailPeerIdKey];
    _messageId = [aDecoder decodeInt32ForKey:TGBridgeMediaThumbnailMessageIdKey];
    _size = [aDecoder decodeCGSizeForKey:TGBridgeMediaThumbnailSizeKey];
    _notification = [aDecoder decodeBoolForKey:TGBridgeMediaThumbnailNotificationKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeMediaThumbnailSubscriptionName;
}

@end


NSString *const TGBridgeMediaAvatarSubscriptionName = @"media.avatar";
NSString *const TGBridgeMediaAvatarPeerIdKey = @"peerId";
NSString *const TGBridgeMediaAvatarUrlKey = @"url";
NSString *const TGBridgeMediaAvatarTypeKey = @"type";

@implementation TGBridgeMediaAvatarSubscription

- (instancetype)initWithPeerId:(int64_t)peerId url:(NSString *)url type:(TGBridgeMediaAvatarType)type
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _url = url;
        _type = type;
    }
    return self;
}

- (bool)renewable
{
    return false;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.peerId forKey:TGBridgeMediaAvatarPeerIdKey];
    [aCoder encodeObject:self.url forKey:TGBridgeMediaAvatarUrlKey];
    [aCoder encodeInt32:self.type forKey:TGBridgeMediaAvatarTypeKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _peerId = [aDecoder decodeInt64ForKey:TGBridgeMediaAvatarPeerIdKey];
    _url = [aDecoder decodeObjectForKey:TGBridgeMediaAvatarUrlKey];
    _type = [aDecoder decodeInt32ForKey:TGBridgeMediaAvatarTypeKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeMediaAvatarSubscriptionName;
}

@end


NSString *const TGBridgeMediaStickerSubscriptionName = @"media.sticker";
NSString *const TGBridgeMediaStickerDocumentIdKey = @"documentId";
NSString *const TGBridgeMediaStickerPackIdKey = @"packId";
NSString *const TGBridgeMediaStickerPackAccessHashKey = @"accessHash";
NSString *const TGBridgeMediaStickerPeerIdKey = @"peerId";
NSString *const TGBridgeMediaStickerMessageIdKey = @"mid";
NSString *const TGBridgeMediaStickerNotificationKey = @"notification";
NSString *const TGBridgeMediaStickerSizeKey = @"size";

@implementation TGBridgeMediaStickerSubscription

- (instancetype)initWithDocumentId:(int64_t)documentId stickerPackId:(int64_t)stickerPackId stickerPackAccessHash:(int64_t)stickerPackAccessHash stickerPeerId:(int64_t)stickerPeerId stickerMessageId:(int32_t)stickerMessageId notification:(bool)notification size:(CGSize)size
{
    self = [super init];
    if (self != nil)
    {
        _documentId = documentId;
        _stickerPackId = stickerPackId;
        _stickerPackAccessHash = stickerPackAccessHash;
        _stickerPeerId = stickerPeerId;
        _stickerMessageId = stickerMessageId;
        _notification = notification;
        _size = size;
    }
    return self;
}

- (bool)renewable
{
    return false;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.documentId forKey:TGBridgeMediaStickerDocumentIdKey];
    [aCoder encodeInt64:self.stickerPackId forKey:TGBridgeMediaStickerPackIdKey];
    [aCoder encodeInt64:self.stickerPackAccessHash forKey:TGBridgeMediaStickerPackAccessHashKey];
    [aCoder encodeInt64:self.stickerPeerId forKey:TGBridgeMediaStickerPeerIdKey];
    [aCoder encodeInt32:self.stickerMessageId forKey:TGBridgeMediaStickerMessageIdKey];
    [aCoder encodeBool:self.notification forKey:TGBridgeMediaStickerNotificationKey];
    [aCoder encodeCGSize:self.size forKey:TGBridgeMediaStickerSizeKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _documentId = [aDecoder decodeInt64ForKey:TGBridgeMediaStickerDocumentIdKey];
    _stickerPackId = [aDecoder decodeInt64ForKey:TGBridgeMediaStickerPackIdKey];
    _stickerPackAccessHash = [aDecoder decodeInt64ForKey:TGBridgeMediaStickerPackAccessHashKey];
    _stickerPeerId = [aDecoder decodeInt64ForKey:TGBridgeMediaStickerPeerIdKey];
    _stickerMessageId = [aDecoder decodeInt32ForKey:TGBridgeMediaStickerMessageIdKey];
    _notification = [aDecoder decodeBoolForKey:TGBridgeMediaStickerNotificationKey];
    _size = [aDecoder decodeCGSizeForKey:TGBridgeMediaStickerSizeKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeMediaStickerSubscriptionName;
}

@end


NSString *const TGBridgePeerSettingsSubscriptionName = @"peer.settings";
NSString *const TGBridgePeerSettingsSubscriptionPeerIdKey = @"peerId";

@implementation TGBridgePeerSettingsSubscription

- (instancetype)initWithPeerId:(int64_t)peerId
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
    }
    return self;
}

- (bool)dropPreviouslyQueued
{
    return true;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.peerId forKey:TGBridgePeerSettingsSubscriptionPeerIdKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _peerId = [aDecoder decodeInt64ForKey:TGBridgePeerSettingsSubscriptionPeerIdKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgePeerSettingsSubscriptionName;
}

@end


NSString *const TGBridgePeerUpdateNotificationSettingsSubscriptionName = @"peer.notificationSettings";
NSString *const TGBridgePeerUpdateNotificationSettingsSubscriptionPeerIdKey = @"peerId";

@implementation TGBridgePeerUpdateNotificationSettingsSubscription

- (instancetype)initWithPeerId:(int64_t)peerId
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
    }
    return self;
}

- (bool)renewable
{
    return false;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.peerId forKey:TGBridgePeerUpdateNotificationSettingsSubscriptionPeerIdKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _peerId = [aDecoder decodeInt64ForKey:TGBridgePeerUpdateNotificationSettingsSubscriptionPeerIdKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgePeerUpdateNotificationSettingsSubscriptionName;
}

@end


NSString *const TGBridgePeerUpdateBlockStatusSubscriptionName = @"peer.updateBlocked";
NSString *const TGBridgePeerUpdateBlockStatusSubscriptionPeerIdKey = @"peerId";
NSString *const TGBridgePeerUpdateBlockStatusSubscriptionBlockedKey = @"blocked";

@implementation TGBridgePeerUpdateBlockStatusSubscription

- (instancetype)initWithPeerId:(int64_t)peerId blocked:(bool)blocked
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _blocked = blocked;
    }
    return self;
}

- (bool)renewable
{
    return false;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.peerId forKey:TGBridgePeerUpdateBlockStatusSubscriptionPeerIdKey];
    [aCoder encodeBool:self.blocked forKey:TGBridgePeerUpdateBlockStatusSubscriptionBlockedKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _peerId = [aDecoder decodeInt64ForKey:TGBridgePeerUpdateBlockStatusSubscriptionPeerIdKey];
    _blocked = [aDecoder decodeBoolForKey:TGBridgePeerUpdateBlockStatusSubscriptionBlockedKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgePeerUpdateBlockStatusSubscriptionName;
}

@end


NSString *const TGBridgeRemoteSubscriptionName = @"remote.request";
NSString *const TGBridgeRemotePeerIdKey = @"peerId";
NSString *const TGBridgeRemoteMessageIdKey = @"mid";
NSString *const TGBridgeRemoteTypeKey = @"mediaType";
NSString *const TGBridgeRemoteAutoPlayKey = @"autoPlay";

@implementation TGBridgeRemoteSubscription

- (instancetype)initWithPeerId:(int64_t)peerId messageId:(int32_t)messageId type:(int32_t)type autoPlay:(bool)autoPlay
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _messageId = messageId;
        _type = type;
        _autoPlay = autoPlay;
    }
    return self;
}

- (bool)renewable
{
    return false;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.peerId forKey:TGBridgeRemotePeerIdKey];
    [aCoder encodeInt32:self.messageId forKey:TGBridgeRemoteMessageIdKey];
    [aCoder encodeInt32:self.type forKey:TGBridgeRemoteTypeKey];
    [aCoder encodeBool:self.autoPlay forKey:TGBridgeRemoteAutoPlayKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _peerId = [aDecoder decodeInt64ForKey:TGBridgeRemotePeerIdKey];
    _messageId = [aDecoder decodeInt32ForKey:TGBridgeRemoteMessageIdKey];
    _type = [aDecoder decodeInt32ForKey:TGBridgeRemoteTypeKey];
    _autoPlay = [aDecoder decodeBoolForKey:TGBridgeRemoteAutoPlayKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeRemoteSubscriptionName;
}

@end


NSString *const TGBridgeSendTextMessageSubscriptionName = @"sendMessage.text";
NSString *const TGBridgeSendTextMessageSubscriptionPeerIdKey = @"peerId";
NSString *const TGBridgeSendTextMessageSubscriptionTextKey = @"text";
NSString *const TGBridgeSendTextMessageSubscriptionReplyToMidKey = @"replyToMid";

@implementation TGBridgeSendTextMessageSubscription

- (instancetype)initWithPeerId:(int64_t)peerId text:(NSString *)text replyToMid:(int32_t)replyToMid
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _text = text;
        _replyToMid = replyToMid;
    }
    return self;
}

- (bool)renewable
{
    return false;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.peerId forKey:TGBridgeSendTextMessageSubscriptionPeerIdKey];
    [aCoder encodeObject:self.text forKey:TGBridgeSendTextMessageSubscriptionTextKey];
    [aCoder encodeInt32:self.replyToMid forKey:TGBridgeSendTextMessageSubscriptionReplyToMidKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _peerId = [aDecoder decodeInt64ForKey:TGBridgeSendTextMessageSubscriptionPeerIdKey];
    _text = [aDecoder decodeObjectForKey:TGBridgeSendTextMessageSubscriptionTextKey];
    _replyToMid = [aDecoder decodeInt32ForKey:TGBridgeSendTextMessageSubscriptionReplyToMidKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeSendTextMessageSubscriptionName;
}

@end


NSString *const TGBridgeSendStickerMessageSubscriptionName = @"sendMessage.sticker";
NSString *const TGBridgeSendStickerMessageSubscriptionPeerIdKey = @"peerId";
NSString *const TGBridgeSendStickerMessageSubscriptionDocumentKey = @"document";
NSString *const TGBridgeSendStickerMessageSubscriptionReplyToMidKey = @"replyToMid";

@implementation TGBridgeSendStickerMessageSubscription

- (instancetype)initWithPeerId:(int64_t)peerId document:(TGBridgeDocumentMediaAttachment *)document replyToMid:(int32_t)replyToMid
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _document = document;
        _replyToMid = replyToMid;
    }
    return self;
}

- (bool)renewable
{
    return false;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.peerId forKey:TGBridgeSendStickerMessageSubscriptionPeerIdKey];
    [aCoder encodeObject:self.document forKey:TGBridgeSendStickerMessageSubscriptionDocumentKey];
    [aCoder encodeInt32:self.replyToMid forKey:TGBridgeSendStickerMessageSubscriptionReplyToMidKey];
}


- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _peerId = [aDecoder decodeInt64ForKey:TGBridgeSendStickerMessageSubscriptionPeerIdKey];
    _document = [aDecoder decodeObjectForKey:TGBridgeSendStickerMessageSubscriptionDocumentKey];
    _replyToMid = [aDecoder decodeInt32ForKey:TGBridgeSendStickerMessageSubscriptionReplyToMidKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeSendStickerMessageSubscriptionName;
}

@end


NSString *const TGBridgeSendLocationMessageSubscriptionName = @"sendMessage.location";
NSString *const TGBridgeSendLocationMessageSubscriptionPeerIdKey = @"peerId";
NSString *const TGBridgeSendLocationMessageSubscriptionLocationKey = @"location";
NSString *const TGBridgeSendLocationMessageSubscriptionReplyToMidKey = @"replyToMid";

@implementation TGBridgeSendLocationMessageSubscription

- (instancetype)initWithPeerId:(int64_t)peerId location:(TGBridgeLocationMediaAttachment *)location replyToMid:(int32_t)replyToMid
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _location = location;
        _replyToMid = replyToMid;
    }
    return self;
}

- (bool)renewable
{
    return false;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.peerId forKey:TGBridgeSendLocationMessageSubscriptionPeerIdKey];
    [aCoder encodeObject:self.location forKey:TGBridgeSendLocationMessageSubscriptionLocationKey];
    [aCoder encodeInt32:self.replyToMid forKey:TGBridgeSendLocationMessageSubscriptionReplyToMidKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _peerId = [aDecoder decodeInt64ForKey:TGBridgeSendLocationMessageSubscriptionPeerIdKey];
    _location = [aDecoder decodeObjectForKey:TGBridgeSendLocationMessageSubscriptionLocationKey];
    _replyToMid = [aDecoder decodeInt32ForKey:TGBridgeSendLocationMessageSubscriptionReplyToMidKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeSendLocationMessageSubscriptionName;
}

@end


NSString *const TGBridgeSendForwardedMessageSubscriptionName = @"sendMessage.forward";
NSString *const TGBridgeSendForwardedMessageSubscriptionPeerIdKey = @"peerId";
NSString *const TGBridgeSendForwardedMessageSubscriptionMidKey = @"mid";
NSString *const TGBridgeSendForwardedMessageSubscriptionTargetPeerIdKey = @"targetPeerId";

@implementation TGBridgeSendForwardedMessageSubscription

- (instancetype)initWithPeerId:(int64_t)peerId messageId:(int32_t)messageId targetPeerId:(int64_t)targetPeerId
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
        _messageId = messageId;
        _targetPeerId = targetPeerId;
    }
    return self;
}

- (bool)renewable
{
    return false;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.peerId forKey:TGBridgeSendForwardedMessageSubscriptionPeerIdKey];
    [aCoder encodeInt32:self.messageId forKey:TGBridgeSendForwardedMessageSubscriptionMidKey];
    [aCoder encodeInt64:self.targetPeerId forKey:TGBridgeSendForwardedMessageSubscriptionTargetPeerIdKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _peerId = [aDecoder decodeInt64ForKey:TGBridgeSendForwardedMessageSubscriptionPeerIdKey];
    _messageId = [aDecoder decodeInt32ForKey:TGBridgeSendForwardedMessageSubscriptionMidKey];
    _targetPeerId = [aDecoder decodeInt64ForKey:TGBridgeSendForwardedMessageSubscriptionTargetPeerIdKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeSendForwardedMessageSubscriptionName;
}

@end


NSString *const TGBridgeStateSubscriptionName = @"state.syncState";

@implementation TGBridgeStateSubscription

- (bool)dropPreviouslyQueued
{
    return true;
}

+ (NSString *)subscriptionName
{
    return TGBridgeStateSubscriptionName;
}

@end


NSString *const TGBridgeStickerPacksSubscriptionName = @"stickers.packs";

@implementation TGBridgeStickerPacksSubscription

+ (NSString *)subscriptionName
{
    return TGBridgeStickerPacksSubscriptionName;
}

@end


NSString *const TGBridgeRecentStickersSubscriptionName = @"stickers.recent";
NSString *const TGBridgeRecentStickersSubscriptionLimitKey = @"limit";

@implementation TGBridgeRecentStickersSubscription

- (instancetype)initWithLimit:(int32_t)limit
{
    self = [super init];
    if (self != nil)
    {
        _limit = limit;
    }
    return self;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt32:self.limit forKey:TGBridgeRecentStickersSubscriptionLimitKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _limit = [aDecoder decodeInt32ForKey:TGBridgeRecentStickersSubscriptionLimitKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeRecentStickersSubscriptionName;
}

@end


NSString *const TGBridgeUserInfoSubscriptionName = @"user.userInfo";
NSString *const TGBridgeUserInfoSubscriptionUserIdsKey = @"uids";

@implementation TGBridgeUserInfoSubscription

- (instancetype)initWithUserIds:(NSArray *)userIds
{
    self = [super init];
    if (self != nil)
    {
        _userIds = userIds;
    }
    return self;
}

- (bool)dropPreviouslyQueued
{
    return true;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.userIds forKey:TGBridgeUserInfoSubscriptionUserIdsKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _userIds = [aDecoder decodeObjectForKey:TGBridgeUserInfoSubscriptionUserIdsKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeUserInfoSubscriptionName;
}

@end


NSString *const TGBridgeUserBotInfoSubscriptionName = @"user.botInfo";
NSString *const TGBridgeUserBotInfoSubscriptionUserIdsKey = @"uids";

@implementation TGBridgeUserBotInfoSubscription

- (instancetype)initWithUserIds:(NSArray *)userIds
{
    self = [super init];
    if (self != nil)
    {
        _userIds = userIds;
    }
    return self;
}

- (bool)dropPreviouslyQueued
{
    return true;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.userIds forKey:TGBridgeUserBotInfoSubscriptionUserIdsKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _userIds = [aDecoder decodeObjectForKey:TGBridgeUserBotInfoSubscriptionUserIdsKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeUserBotInfoSubscriptionName;
}

@end


NSString *const TGBridgeBotReplyMarkupSubscriptionName = @"user.botReplyMarkup";
NSString *const TGBridgeBotReplyMarkupPeerIdKey = @"peerId";

@implementation TGBridgeBotReplyMarkupSubscription

- (instancetype)initWithPeerId:(int64_t)peerId
{
    self = [super init];
    if (self != nil)
    {
        _peerId = peerId;
    }
    return self;
}

- (bool)dropPreviouslyQueued
{
    return true;
}

- (void)_serializeParametersWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt64:self.peerId forKey:TGBridgeBotReplyMarkupPeerIdKey];
}

- (void)_unserializeParametersWithCoder:(NSCoder *)aDecoder
{
    _peerId = [aDecoder decodeInt64ForKey:TGBridgeBotReplyMarkupPeerIdKey];
}

+ (NSString *)subscriptionName
{
    return TGBridgeBotReplyMarkupSubscriptionName;
}

@end
