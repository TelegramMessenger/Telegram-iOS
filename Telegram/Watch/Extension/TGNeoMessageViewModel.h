#import "TGNeoRenderableViewModel.h"

@class TGBridgeMessage;
@class TGBridgeUser;
@class TGBridgeContext;

typedef enum
{
    TGNeoMessageTypeGeneric,
    TGNeoMessageTypeGroup,
    TGNeoMessageTypeChannel
} TGNeoMessageType;

@interface TGNeoMessageViewModel : TGNeoRenderableViewModel

@property (nonatomic, readonly) int32_t identifier;
@property (nonatomic, readonly) TGNeoMessageType type;
@property (nonatomic, readonly) NSDictionary *additionalLayout;
@property (nonatomic, assign) bool showBubble;

- (instancetype)initWithMessage:(TGBridgeMessage *)message type:(TGNeoMessageType)type users:(NSDictionary *)users context:(TGBridgeContext *)context;

- (void)addAdditionalLayout:(NSDictionary *)layout withKey:(NSString *)key;

+ (TGNeoMessageViewModel *)viewModelForMessage:(TGBridgeMessage *)message type:(TGNeoMessageType)type context:(TGBridgeContext *)context additionalPeers:(NSDictionary *)additionalPeers;

@end

extern NSString *const TGNeoContentInset;

extern NSString *const TGNeoMessageHeaderGroup;
extern NSString *const TGNeoMessageReplyImageGroup;
extern NSString *const TGNeoMessageReplyMediaAttachment;

extern NSString *const TGNeoMessageMediaGroup;
extern NSString *const TGNeoMessageMediaPeerId;
extern NSString *const TGNeoMessageMediaMessageId;
extern NSString *const TGNeoMessageMediaImage;
extern NSString *const TGNeoMessageMediaImageAttachment;
extern NSString *const TGNeoMessageMediaImageSpinner;
extern NSString *const TGNeoMessageMediaPlayButton;
extern NSString *const TGNeoMessageMediaSize;
extern NSString *const TGNeoMessageMediaMap;
extern NSString *const TGNeoMessageMediaMapSize;
extern NSString *const TGNeoMessageMediaMapCoordinate;

extern NSString *const TGNeoMessageMetaGroup;
extern NSString *const TGNeoMessageAvatarGroup;
extern NSString *const TGNeoMessageAvatarIdentifier;
extern NSString *const TGNeoMessageAvatarUrl;
extern NSString *const TGNeoMessageAvatarColor;
extern NSString *const TGNeoMessageAvatarInitials;

extern NSString *const TGNeoMessageAudioButton;
extern NSString *const TGNeoMessageAudioButtonHasBackground;
extern NSString *const TGNeoMessageAudioBackgroundColor;
extern NSString *const TGNeoMessageAudioIcon;
extern NSString *const TGNeoMessageAudioIconTint;
extern NSString *const TGNeoMessageAudioAnimatedIcon;
