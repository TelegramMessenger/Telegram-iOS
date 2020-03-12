#import <WatchCommon/TGBridgeCommon.h>

#import <CoreLocation/CoreLocation.h>
#import <CoreGraphics/CoreGraphics.h>

@class TGBridgeMediaAttachment;
@class TGBridgeImageMediaAttachment;
@class TGBridgeVideoMediaAttachment;
@class TGBridgeDocumentMediaAttachment;
@class TGBridgeLocationMediaAttachment;
@class TGBridgePeerNotificationSettings;

@interface TGBridgeAudioSubscription : TGBridgeSubscription

@property (nonatomic, readonly) TGBridgeMediaAttachment *attachment;
@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) int32_t messageId;

- (instancetype)initWithAttachment:(TGBridgeMediaAttachment *)attachment peerId:(int64_t)peerId messageId:(int32_t)messageId;

@end


@interface TGBridgeAudioSentSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t conversationId;

- (instancetype)initWithConversationId:(int64_t)conversationId;

@end


@interface TGBridgeChatListSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int32_t limit;

- (instancetype)initWithLimit:(int32_t)limit;

@end


@interface TGBridgeChatMessageListSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) int32_t atMessageId;
@property (nonatomic, readonly) NSUInteger rangeMessageCount;

- (instancetype)initWithPeerId:(int64_t)peerId atMessageId:(int32_t)messageId rangeMessageCount:(NSUInteger)rangeMessageCount;

@end


@interface TGBridgeChatMessageSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) int32_t messageId;

- (instancetype)initWithPeerId:(int64_t)peerId messageId:(int32_t)messageId;

@end


@interface TGBridgeReadChatMessageListSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) int32_t messageId;

- (instancetype)initWithPeerId:(int64_t)peerId messageId:(int32_t)messageId;

@end


@interface TGBridgeContactsSubscription : TGBridgeSubscription

@property (nonatomic, readonly) NSString *query;

- (instancetype)initWithQuery:(NSString *)query;

@end


@interface TGBridgeConversationSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t peerId;

- (instancetype)initWithPeerId:(int64_t)peerId;

@end


@interface TGBridgeNearbyVenuesSubscription : TGBridgeSubscription

@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (nonatomic, readonly) int32_t limit;

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate limit:(int32_t)limit;

@end


@interface TGBridgeMediaThumbnailSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) int32_t messageId;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) bool notification;

- (instancetype)initWithPeerId:(int64_t)peerId messageId:(int32_t)messageId size:(CGSize)size notification:(bool)notification;

@end


typedef NS_ENUM(NSUInteger, TGBridgeMediaAvatarType) {
    TGBridgeMediaAvatarTypeSmall,
    TGBridgeMediaAvatarTypeProfile,
    TGBridgeMediaAvatarTypeLarge
};

@interface TGBridgeMediaAvatarSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) NSString *url;
@property (nonatomic, readonly) TGBridgeMediaAvatarType type;

- (instancetype)initWithPeerId:(int64_t)peerId url:(NSString *)url type:(TGBridgeMediaAvatarType)type;

@end

@interface TGBridgeMediaStickerSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t documentId;
@property (nonatomic, readonly) int64_t stickerPackId;
@property (nonatomic, readonly) int64_t stickerPackAccessHash;
@property (nonatomic, readonly) int64_t stickerPeerId;
@property (nonatomic, readonly) int32_t stickerMessageId;
@property (nonatomic, readonly) bool notification;
@property (nonatomic, readonly) CGSize size;

- (instancetype)initWithDocumentId:(int64_t)documentId stickerPackId:(int64_t)stickerPackId stickerPackAccessHash:(int64_t)stickerPackAccessHash stickerPeerId:(int64_t)stickerPeerId stickerMessageId:(int32_t)stickerMessageId notification:(bool)notification size:(CGSize)size;

@end


@interface TGBridgePeerSettingsSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t peerId;

- (instancetype)initWithPeerId:(int64_t)peerId;

@end

@interface TGBridgePeerUpdateNotificationSettingsSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t peerId;

- (instancetype)initWithPeerId:(int64_t)peerId;

@end

@interface TGBridgePeerUpdateBlockStatusSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) bool blocked;

- (instancetype)initWithPeerId:(int64_t)peerId blocked:(bool)blocked;

@end


@interface TGBridgeRemoteSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) int32_t messageId;
@property (nonatomic, readonly) int32_t type;
@property (nonatomic, readonly) bool autoPlay;

- (instancetype)initWithPeerId:(int64_t)peerId messageId:(int32_t)messageId type:(int32_t)type autoPlay:(bool)autoPlay;

@end


@interface TGBridgeSendTextMessageSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) NSString *text;
@property (nonatomic, readonly) int32_t replyToMid;

- (instancetype)initWithPeerId:(int64_t)peerId text:(NSString *)text replyToMid:(int32_t)replyToMid;

@end


@interface TGBridgeSendStickerMessageSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) TGBridgeDocumentMediaAttachment *document;
@property (nonatomic, readonly) int32_t replyToMid;

- (instancetype)initWithPeerId:(int64_t)peerId document:(TGBridgeDocumentMediaAttachment *)document replyToMid:(int32_t)replyToMid;

@end


@interface TGBridgeSendLocationMessageSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) TGBridgeLocationMediaAttachment *location;
@property (nonatomic, readonly) int32_t replyToMid;

- (instancetype)initWithPeerId:(int64_t)peerId location:(TGBridgeLocationMediaAttachment *)location replyToMid:(int32_t)replyToMid;

@end


@interface TGBridgeSendForwardedMessageSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) int32_t messageId;
@property (nonatomic, readonly) int64_t targetPeerId;

- (instancetype)initWithPeerId:(int64_t)peerId messageId:(int32_t)messageId targetPeerId:(int64_t)targetPeerId;

@end


@interface TGBridgeStateSubscription : TGBridgeSubscription

@end


@interface TGBridgeStickerPacksSubscription : TGBridgeSubscription

@end


@interface TGBridgeRecentStickersSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int32_t limit;

- (instancetype)initWithLimit:(int32_t)limit;

@end


@interface TGBridgeUserInfoSubscription : TGBridgeSubscription

@property (nonatomic, readonly) NSArray *userIds;

- (instancetype)initWithUserIds:(NSArray *)userIds;

@end


@interface TGBridgeUserBotInfoSubscription : TGBridgeSubscription

@property (nonatomic, readonly) NSArray *userIds;

- (instancetype)initWithUserIds:(NSArray *)userIds;

@end

@interface TGBridgeBotReplyMarkupSubscription : TGBridgeSubscription

@property (nonatomic, readonly) int64_t peerId;

- (instancetype)initWithPeerId:(int64_t)peerId;

@end
