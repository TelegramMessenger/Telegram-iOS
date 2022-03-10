#import "TGNeoMessageViewModel.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGNeoTextMessageViewModel.h"
#import "TGNeoSmiliesMessageViewModel.h"
#import "TGNeoMediaMessageViewModel.h"
#import "TGNeoAudioMessageViewModel.h"
#import "TGNeoFileMessageViewModel.h"
#import "TGNeoContactMessageViewModel.h"
#import "TGNeoVenueMessageViewModel.h"
#import "TGNeoStickerMessageViewModel.h"
#import "TGNeoServiceMessageViewModel.h"
#import "TGNeoUnsupportedMessageViewModel.h"

#import "TGNeoConversationRowController.h"
#import "TGNeoConversationMediaRowController.h"
#import "TGNeoConversationStaticRowController.h"

#import "TGStringUtils.h"

#import "TGBridgeUserCache.h"

NSString *const TGNeoContentInset = @"contentInset";

NSString *const TGNeoMessageHeaderGroup = @"header";
NSString *const TGNeoMessageReplyImageGroup = @"replyImage";
NSString *const TGNeoMessageReplyMediaAttachment = @"attachment";

NSString *const TGNeoMessageMediaGroup = @"media";
NSString *const TGNeoMessageMediaPeerId = @"peerId";
NSString *const TGNeoMessageMediaMessageId = @"mid";
NSString *const TGNeoMessageMediaImage = @"image";
NSString *const TGNeoMessageMediaImageAttachment = @"attachment";
NSString *const TGNeoMessageMediaImageSpinner = @"spinner";
NSString *const TGNeoMessageMediaPlayButton = @"button";
NSString *const TGNeoMessageMediaSize = @"size";
NSString *const TGNeoMessageMediaMap = @"map";
NSString *const TGNeoMessageMediaMapSize = @"size";
NSString *const TGNeoMessageMediaMapCoordinate = @"coordinate";

NSString *const TGNeoMessageMetaGroup = @"meta";
NSString *const TGNeoMessageAvatarGroup = @"avatar";
NSString *const TGNeoMessageAvatarIdentifier = @"identifier";
NSString *const TGNeoMessageAvatarUrl = @"url";
NSString *const TGNeoMessageAvatarColor = @"color";
NSString *const TGNeoMessageAvatarInitials = @"initials";

NSString *const TGNeoMessageAudioButton = @"audio";
NSString *const TGNeoMessageAudioButtonHasBackground = @"hasBackground";
NSString *const TGNeoMessageAudioBackgroundColor = @"color";
NSString *const TGNeoMessageAudioIcon = @"icon";
NSString *const TGNeoMessageAudioIconTint = @"tint";
NSString *const TGNeoMessageAudioAnimatedIcon = @"animatedIcon";

@implementation TGNeoMessageViewModel

- (instancetype)initWithMessage:(TGBridgeMessage *)message type:(TGNeoMessageType)type users:(NSDictionary *)users context:(TGBridgeContext *)context
{
    self = [super init];
    if (self != nil)
    {
        _type = type;
        _identifier = message.identifier;
    }
    return self;
}

- (void)addAdditionalLayout:(NSDictionary *)layout withKey:(NSString *)key
{
    if (_additionalLayout != nil)
        [_additionalLayout.mutableCopy addEntriesFromDictionary:@{ key: layout }];
    else
        _additionalLayout = @{ key: layout };
}

+ (TGNeoMessageViewModel *)viewModelForMessage:(TGBridgeMessage *)message type:(TGNeoMessageType)type context:(TGBridgeContext *)context additionalPeers:(NSDictionary *)additionalPeers
{
    Class viewModelClass = [TGNeoTextMessageViewModel class];
    
    bool hasReplyHeader = false;
    bool hasForwardHeader = false;
    
    for (TGBridgeMediaAttachment *attachment in message.media)
    {
        if ([attachment isKindOfClass:[TGBridgeReplyMessageMediaAttachment class]])
            hasReplyHeader = true;
        else if ([attachment isKindOfClass:[TGBridgeForwardedMessageMediaAttachment class]])
            hasForwardHeader = true;
    }
    
    for (TGBridgeMediaAttachment *attachment in message.media)
    {
        if ([attachment isKindOfClass:[TGBridgeImageMediaAttachment class]])
        {
            viewModelClass = [TGNeoMediaMessageViewModel class];
        }
        else if ([attachment isKindOfClass:[TGBridgeVideoMediaAttachment class]])
        {
            viewModelClass = [TGNeoMediaMessageViewModel class];
        }
        else if ([attachment isKindOfClass:[TGBridgeAudioMediaAttachment class]])
        {
            viewModelClass = [TGNeoAudioMessageViewModel class];
        }
        else if ([attachment isKindOfClass:[TGBridgeDocumentMediaAttachment class]])
        {
            TGBridgeDocumentMediaAttachment *documentAttachment = (TGBridgeDocumentMediaAttachment *)attachment;
            if (documentAttachment.isSticker)
                viewModelClass = [TGNeoStickerMessageViewModel class];
            else if (documentAttachment.isAudio)
                viewModelClass = [TGNeoAudioMessageViewModel class];
            else
                viewModelClass = [TGNeoFileMessageViewModel class];;
        }
        else if ([attachment isKindOfClass:[TGBridgeLocationMediaAttachment class]])
        {
            TGBridgeLocationMediaAttachment *locationAttachment = (TGBridgeLocationMediaAttachment *)attachment;
            if (locationAttachment.venue != nil)
                viewModelClass = [TGNeoVenueMessageViewModel class];
            else
                viewModelClass = [TGNeoMediaMessageViewModel class];
        }
        else if ([attachment isKindOfClass:[TGBridgeContactMediaAttachment class]])
        {
            viewModelClass = [TGNeoContactMessageViewModel class];
        }
        else if ([attachment isKindOfClass:[TGBridgeActionMediaAttachment class]])
        {
            viewModelClass = [TGNeoServiceMessageViewModel class];
        }
        else if ([attachment isKindOfClass:[TGBridgeUnsupportedMediaAttachment class]])
        {
            viewModelClass = [TGNeoUnsupportedMessageViewModel class];
        }
    }
    
    if (viewModelClass == [TGNeoTextMessageViewModel class] && !hasForwardHeader && !hasReplyHeader && message.text.length > 0)
    {
        NSUInteger length = 0;
        bool emojiOnly = [TGStringUtils stringContainsEmojiOnly:message.text length:&length];
        if (emojiOnly && length <= 3)
            viewModelClass = [TGNeoSmiliesMessageViewModel class];
    }
    
    NSMutableDictionary *users = [NSMutableDictionary dictionaryWithDictionary:additionalPeers];
    [users addEntriesFromDictionary:[[TGBridgeUserCache instance] usersWithIds:[message involvedUserIds]]];
    
    return [[viewModelClass alloc] initWithMessage:message type:type users:users context:context];
}

@end
