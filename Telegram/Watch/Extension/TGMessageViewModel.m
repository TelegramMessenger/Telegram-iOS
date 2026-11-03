#import "TGMessageViewModel.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import "TGStringUtils.h"
#import "TGGeometry.h"

#import "WKInterfaceImage+Signals.h"
#import "WKInterfaceGroup+Signals.h"

#import "TGBridgeUserCache.h"

#import "TGBridgeMediaSignals.h"

@implementation TGMessageViewModel

+ (void)imageBubbleSizeForImageSize:(CGSize)imageSize minSize:(CGSize)minSize maxSize:(CGSize)maxSize thumbnailSize:(out CGSize *)thumbnailSize renderSize:(out CGSize *)renderSize
{
    CGSize imageTargetMaxSize = maxSize;
    CGSize imageScalingMaxSize = CGSizeMake(imageTargetMaxSize.width - 18.0f, imageTargetMaxSize.height - 18.0f);
    CGSize imageTargetMinSize = minSize;
    
    CGFloat imageAspect = 1.0f;
    if (imageSize.width > 1.0f - FLT_EPSILON && imageSize.height > 1.0f - FLT_EPSILON)
        imageAspect = imageSize.width / imageSize.height;
    
    if (imageSize.width < imageScalingMaxSize.width || imageSize.height < imageScalingMaxSize.height)
    {
        if (imageSize.width <= FLT_EPSILON || imageSize.height <= FLT_EPSILON)
            imageSize = imageTargetMinSize;
    }
    else
    {
        if (imageSize.width > imageTargetMaxSize.width)
        {
            imageSize.width = imageTargetMaxSize.width;
            imageSize.height = floorf(imageTargetMaxSize.width / imageAspect);
        }
        
        if (imageSize.height > imageTargetMaxSize.height)
        {
            imageSize.width = floorf(imageTargetMaxSize.height * imageAspect);
            imageSize.height = imageTargetMaxSize.height;
        }
    }
    
    if (renderSize != NULL)
        *renderSize = imageSize;
    
    imageSize.width = MIN(imageTargetMaxSize.width, imageSize.width);
    imageSize.height = MIN(imageTargetMaxSize.height, imageSize.height);
    
    imageSize.width = MAX(imageTargetMinSize.width, imageSize.width);
    imageSize.height = MAX(imageTargetMinSize.height, imageSize.height);
    
    if (thumbnailSize != NULL)
        *thumbnailSize = imageSize;
}

+ (void)updateAuthorLabel:(WKInterfaceLabel *)authorLabel isOutgoing:(bool)isOutgoing isGroup:(bool)isGroup user:(TGBridgeUser *)user ownUserId:(int32_t)ownUserId
{
    if (isGroup && !isOutgoing)
    {
        authorLabel.hidden = false;
        authorLabel.text = user.displayName;
        authorLabel.textColor = [TGColor colorForUserId:(int32_t)user.identifier myUserId:ownUserId];
    }
    else
    {
        authorLabel.hidden = true;
    }
}

+ (void)updateMediaGroup:(WKInterfaceGroup *)mediaGroup activityIndicator:(WKInterfaceImage *)activityIndicator attachment:(TGBridgeMediaAttachment *)mediaAttachment message:(TGBridgeMessage *)message notification:(bool)notification currentPhoto:(int64_t *)currentPhoto standalone:(bool)standalone margin:(CGFloat)margin imageSize:(CGSize *)imageSize isVisible:(bool (^)(void))isVisible completion:(void (^)(void))completion
{
    CGSize targetImageSize = CGSizeZero;
    
    if ([mediaAttachment isKindOfClass:[TGBridgeImageMediaAttachment class]])
        targetImageSize = ((TGBridgeImageMediaAttachment *)mediaAttachment).dimensions;
    else if ([mediaAttachment isKindOfClass:[TGBridgeVideoMediaAttachment class]])
        targetImageSize = ((TGBridgeVideoMediaAttachment *)mediaAttachment).dimensions;
    
    CGSize screenSize = TGWatchScreenSize();
    
    CGSize mediaGroupSize = CGSizeZero;
    if (standalone)
    {
        mediaGroupSize = TGFitSize(targetImageSize, CGSizeMake(screenSize.width - margin * 2, FLT_MAX));
    }
    else
    {
        CGSize maxSize = CGSizeMake(screenSize.width - 15, screenSize.width);
        CGSize minSize = CGSizeMake(screenSize.width / 1.25f, screenSize.width / 2);
        [self imageBubbleSizeForImageSize:targetImageSize minSize:minSize maxSize:maxSize thumbnailSize:&mediaGroupSize renderSize:NULL];
    }
    
    mediaGroupSize = CGSizeMake(ceilf(mediaGroupSize.width), ceilf(mediaGroupSize.height));
    
    if (imageSize != NULL)
        *imageSize = CGSizeMake(mediaGroupSize.width, mediaGroupSize.height);
    
    if ([mediaAttachment isKindOfClass:[TGBridgeImageMediaAttachment class]])
    {
        TGBridgeImageMediaAttachment *imageAttachment = (TGBridgeImageMediaAttachment *)mediaAttachment;
        
        if (currentPhoto == NULL || imageAttachment.imageId != *currentPhoto)
        {
            if (currentPhoto != NULL)
                *currentPhoto = imageAttachment.imageId;
            
            [mediaGroup setBackgroundImageSignal:[[[TGBridgeMediaSignals thumbnailWithPeerId:message.cid messageId:message.identifier size:mediaGroupSize notification:notification] onNext:^(id next)
            {
                if (next != nil)
                    activityIndicator.hidden = true;
                
                if (completion != nil)
                    completion();
            }] onError:^(id error)
            {
                if (currentPhoto != NULL)
                    *currentPhoto = 0;
                
                if (completion != nil)
                    completion();
            }] isVisible:isVisible];
        }
    }
    else if ([mediaAttachment isKindOfClass:[TGBridgeVideoMediaAttachment class]])
    {
        activityIndicator.hidden = true;
        
        TGBridgeVideoMediaAttachment *videoAttachment = (TGBridgeVideoMediaAttachment *)mediaAttachment;
        
        if (currentPhoto == NULL || videoAttachment.videoId != *currentPhoto)
        {
            if (currentPhoto != NULL)
                *currentPhoto = videoAttachment.videoId;
            
            [mediaGroup setBackgroundImageSignal:[[[TGBridgeMediaSignals thumbnailWithPeerId:message.cid messageId:message.identifier size:mediaGroupSize notification:false] onNext:^(id next)
            {
                if (next != nil)
                    activityIndicator.hidden = true;
                
                if (completion != nil)
                    completion();
            }] onError:^(id error)
            {
                if (currentPhoto != NULL)
                    *currentPhoto = 0;
                
                if (completion != nil)
                    completion();
            }] isVisible:isVisible];
        }
    }
}

+ (void)updateForwardHeaderGroup:(WKInterfaceGroup *)forwardHeaderGroup titleLabel:(WKInterfaceLabel *)titleLabel fromLabel:(WKInterfaceLabel *)fromLabel forwardAttachment:(TGBridgeForwardedMessageMediaAttachment *)forwardAttachment forwardPeer:(id)forwardPeer textColor:(UIColor *)textColor
{
    forwardHeaderGroup.hidden = (forwardAttachment == nil);
    if (forwardHeaderGroup.hidden)
        return;
    
    titleLabel.text = TGLocalized(@"Watch.Message.ForwardedFrom");

    NSString *authorName = nil;
    if ([forwardPeer isKindOfClass:[TGBridgeUser class]])
        authorName = ((TGBridgeUser *)forwardPeer).displayName;
    else if ([forwardPeer isKindOfClass:[TGBridgeChat class]])
        authorName = ((TGBridgeChat *)forwardPeer).groupTitle;
    
    if (authorName == nil)
        authorName = @"";
    
    NSMutableAttributedString *forwardAttributedText = [[NSMutableAttributedString alloc] initWithString:authorName attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:12], NSForegroundColorAttributeName:textColor }];
    
    NSRange formatNameRange = NSMakeRange(0, authorName.length);
    if (formatNameRange.location != NSNotFound)
    {
        [forwardAttributedText addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium] range:NSMakeRange(formatNameRange.location, authorName.length)];
    }
    
    fromLabel.attributedText = forwardAttributedText;
}

+ (void)updateReplyHeaderGroup:(WKInterfaceGroup *)replyHeaderGroup authorLabel:(WKInterfaceLabel *)authorLabel imageGroup:(WKInterfaceGroup *)imageGroup textLabel:(WKInterfaceLabel *)textLabel titleColor:(UIColor *)titleColor subtitleColor:(UIColor *)subtitleColor replyAttachment:(TGBridgeReplyMessageMediaAttachment *)replyAttachment currentReplyPhoto:(int64_t *)currentReplyPhoto isVisible:(bool (^)(void))isVisible completion:(void (^)(void))completion
{
    TGBridgeMessage *message = replyAttachment.message;
    replyHeaderGroup.hidden = (message == nil);
    if (replyHeaderGroup.hidden)
        return;
    
    bool hasAttachment = false;
    bool hasImagePreview = false;
    NSString *messageText = nil;
    UIColor *textColor = nil;
    TGBridgeImageMediaAttachment *imageAttachment = nil;
    TGBridgeVideoMediaAttachment *videoAttachment = nil;
    
    for (TGBridgeMediaAttachment *attachment in message.media)
    {
        if ([attachment isKindOfClass:[TGBridgeImageMediaAttachment class]])
        {
            hasAttachment = true;
            hasImagePreview = true;
            messageText = TGLocalized(@"Message.Photo");
            imageAttachment = (TGBridgeImageMediaAttachment *)attachment;
        }
        else if ([attachment isKindOfClass:[TGBridgeVideoMediaAttachment class]])
        {
            hasAttachment = true;
            hasImagePreview = true;
            messageText = TGLocalized(@"Message.Video");
            videoAttachment = (TGBridgeVideoMediaAttachment *)attachment;
        }
        else if ([attachment isKindOfClass:[TGBridgeAudioMediaAttachment class]])
        {
            hasAttachment = true;
            messageText = TGLocalized(@"Message.Audio");
        }
        else if ([attachment isKindOfClass:[TGBridgeDocumentMediaAttachment class]])
        {
            hasAttachment = true;
            TGBridgeDocumentMediaAttachment *documentAttachment = (TGBridgeDocumentMediaAttachment *)attachment;
            
            if (documentAttachment.isSticker)
            {
                if (documentAttachment.stickerAlt.length > 0)
                    messageText = [NSString stringWithFormat:@"%@ %@", documentAttachment.stickerAlt, TGLocalized(@"Message.Sticker")];
                else
                    messageText = TGLocalized(@"Message.Sticker");
            }
            else
            {
                if (documentAttachment.fileName.length > 0)
                    messageText = documentAttachment.fileName;
                else
                    messageText = TGLocalized(@"Message.File");
            }
        }
        else if ([attachment isKindOfClass:[TGBridgeLocationMediaAttachment class]])
        {
            hasAttachment = true;
            messageText = TGLocalized(@"Message.Location");
        }
        else if ([attachment isKindOfClass:[TGBridgeContactMediaAttachment class]])
        {
            hasAttachment = true;
            messageText = TGLocalized(@"Message.Contact");
        }
        else if ([attachment isKindOfClass:[TGBridgeActionMediaAttachment class]])
        {
            hasAttachment = true;
            
            TGBridgeActionMediaAttachment *actionAttachment = (TGBridgeActionMediaAttachment *)attachment;
            [self stringForActionAttachment:actionAttachment message:message users:nil forChannel:false];
        }
    }
    
    if (!hasAttachment)
    {
        messageText = message.text;
        textColor = titleColor;
    }
    else
    {
        textColor = subtitleColor;
    }
    
    authorLabel.text = [[[TGBridgeUserCache instance] userWithId:(int32_t)message.fromUid] displayName];
    imageGroup.hidden = !hasImagePreview;
    textLabel.text = messageText;
    textLabel.textColor = textColor;
    
    if (imageGroup != nil && imageAttachment != nil)
    {
        if (currentReplyPhoto == NULL || imageAttachment.imageId != *currentReplyPhoto)
        {
            if (currentReplyPhoto != NULL)
                *currentReplyPhoto = imageAttachment.imageId;
            
            [imageGroup setBackgroundImageSignal:[[[TGBridgeMediaSignals thumbnailWithPeerId:message.cid messageId:message.identifier size:CGSizeMake(26, 26) notification:false] onNext:^(id next)
            {
                if (completion != nil)
                    completion();
            }] onError:^(id error)
            {
                if (currentReplyPhoto != NULL)
                    *currentReplyPhoto = 0;
                
                if (completion != nil)
                    completion();
            }] isVisible:isVisible];
        }
    }
    else if (imageGroup != nil && videoAttachment != nil)
    {
        if (currentReplyPhoto == NULL || videoAttachment.videoId != *currentReplyPhoto)
        {
            if (currentReplyPhoto != NULL)
                *currentReplyPhoto = videoAttachment.videoId;
            
            [imageGroup setBackgroundImageSignal:[[[TGBridgeMediaSignals thumbnailWithPeerId:message.cid messageId:message.identifier size:CGSizeMake(26, 26) notification:false] onNext:^(id next)
            {
                if (completion != nil)
                    completion();
            }] onError:^(id error)
            {
                if (currentReplyPhoto != NULL)
                    *currentReplyPhoto = 0;
                
                if (completion != nil)
                    completion();
            }] isVisible:isVisible];
        }
    }
    else
    {
        if (completion != nil)
            completion();
    }
}

+ (NSString *)stringForActionAttachment:(TGBridgeActionMediaAttachment *)actionAttachment message:(TGBridgeMessage *)message users:(NSDictionary *)users forChannel:(bool)forChannel
{
    NSString *messageText = nil;
    TGBridgeUser *author = (users != nil) ? users[@(message.fromUid)] : [[TGBridgeUserCache instance] userWithId:(int32_t)message.fromUid];
    
    switch (actionAttachment.actionType)
    {
        case TGBridgeMessageActionChatEditTitle:
        {
            if (forChannel)
            {
                messageText = TGLocalized(@"Notification.RenamedChannel");
            }
            else
            {
                NSString *authorName = [TGStringUtils initialsForFirstName:author.firstName lastName:author.lastName single:false];
                NSString *formatString = TGLocalized(@"Notification.RenamedChat");
                
                messageText = [NSString stringWithFormat:formatString, authorName];
            }
        }
            break;
            
        case TGBridgeMessageActionChatEditPhoto:
        {
            NSString *authorName = [TGStringUtils initialsForFirstName:author.firstName lastName:author.lastName single:false];
            bool changed = actionAttachment.actionData[@"photo"];
            
            if (forChannel)
            {
                messageText = changed ? TGLocalized(@"Channel.MessagePhotoUpdated") : TGLocalized(@"Channel.MessagePhotoRemoved");
            }
            else
            {
                NSString *formatString = changed ? TGLocalized(@"Notification.ChangedGroupPhoto") : TGLocalized(@"Notification.RemovedGroupPhoto");
                
                messageText = [NSString stringWithFormat:formatString, authorName];
            }
        }
            break;
            
        case TGBridgeMessageActionUserChangedPhoto:
        {
            
        }
            break;
            
        case TGBridgeMessageActionChatAddMember:
        case TGBridgeMessageActionChatDeleteMember:
        {
            NSString *authorName = [TGStringUtils initialsForFirstName:author.firstName lastName:author.lastName single:false];
            TGBridgeUser *user = (users != nil) ? users[actionAttachment.actionData[@"uid"]] : [[TGBridgeUserCache instance] userWithId:[actionAttachment.actionData[@"uid"] int32Value]];
            
            if (user.identifier == author.identifier)
            {
                NSString *formatString = (actionAttachment.actionType == TGBridgeMessageActionChatAddMember) ? TGLocalized(@"Notification.JoinedChat") : TGLocalized(@"Notification.LeftChat");
                messageText = [[NSString alloc] initWithFormat:formatString, authorName];
            }
            else
            {
                NSString *userName = [TGStringUtils initialsForFirstName:user.firstName lastName:user.lastName single:false];
                NSString *formatString = (actionAttachment.actionType == TGBridgeMessageActionChatAddMember) ? TGLocalized(@"Notification.Invited") : TGLocalized(@"Notification.Kicked");
                messageText = [[NSString alloc] initWithFormat:formatString, authorName, userName];
            }
        }
            break;
            
        case TGBridgeMessageActionJoinedByLink:
        {
            NSString *authorName = [TGStringUtils initialsForFirstName:author.firstName lastName:author.lastName single:false];
            NSString *formatString = TGLocalized(@"Notification.JoinedGroupByLink");
            messageText = [[NSString alloc] initWithFormat:formatString, authorName, actionAttachment.actionData[@"title"]];
        }
            break;
            
        case TGBridgeMessageActionCreateChat:
        {
            NSString *authorName = [TGStringUtils initialsForFirstName:author.firstName lastName:author.lastName single:false];
            NSString *formatString = TGLocalized(@"Notification.CreatedChatWithTitle");
            messageText = [[NSString alloc] initWithFormat:formatString, authorName, actionAttachment.actionData[@"title"]];
        }
            break;
            
        case TGBridgeMessageActionContactRegistered:
        {
            messageText = TGLocalized(@"Watch.Notification.Joined");
        }
            break;
            
        case TGBridgeMessageActionChannelCreated:
        {
            messageText = TGLocalized(@"Notification.CreatedChannel");
        }
            break;
            
        case TGBridgeMessageActionChannelInviter:
        {
            TGBridgeUser *user = (users != nil) ? users[actionAttachment.actionData[@"uid"]] : [[TGBridgeUserCache instance] userWithId:[actionAttachment.actionData[@"uid"] int32Value]];
            NSString *authorName = [TGStringUtils initialsForFirstName:user.firstName lastName:user.lastName single:false];
            NSString *formatString = TGLocalized(@"Notification.ChannelInviter");
            
            messageText = [[NSString alloc] initWithFormat:formatString, authorName];
        }
            break;
            
        case TGBridgeMessageActionGroupMigratedTo:
        {
            messageText = TGLocalized(@"Notification.ChannelMigratedFrom");
        }
            break;
            
        case TGBridgeMessageActionGroupActivated:
        {
            messageText = TGLocalized(@"Notification.GroupActivated");
        }
            break;
            
        case TGBridgeMessageActionGroupDeactivated:
        {
            messageText = TGLocalized(@"Notification.GroupDeactivated");
        }
            break;
            
        case TGBridgeMessageActionChannelMigratedFrom:
        {
            messageText = TGLocalized(@"Notification.ChannelMigratedFrom");
        }
            break;
            
        default:
            break;
    }

    return messageText;
}

+ (NSAttributedString *)attributedTextForMessage:(TGBridgeMessage *)message fontSize:(CGFloat)fontSize textColor:(UIColor *)textColor
{
    NSArray *textCheckingResults = [message textCheckingResults];
    
    NSString *messageText = message.text ?: @"";
    
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] initWithString:messageText attributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:fontSize], NSForegroundColorAttributeName: textColor }];
    
    for (TGBridgeTextCheckingResult *result in textCheckingResults)
    {
        if (result.type == TGBridgeTextCheckingResultTypeBold)
            [string addAttributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:fontSize weight:UIFontWeightMedium] } range:result.range];
        else if (result.type == TGBridgeTextCheckingResultTypeItalic)
            [string addAttributes:@{ NSFontAttributeName: [UIFont italicSystemFontOfSize:fontSize] } range:result.range];
        else if (result.type == TGBridgeTextCheckingResultTypeCode || result.type == TGBridgeTextCheckingResultTypePre)
            [string addAttributes:@{ NSFontAttributeName: [UIFont fontWithName:@"Courier" size:fontSize] } range:result.range];
    }
    
    return string;
}

@end


@implementation TGStickerViewModel

+ (void)updateWithMessage:(TGBridgeMessage *)message notification:(bool)notification isGroup:(bool)isGroup context:(TGBridgeContext *)context currentDocumentId:(int64_t *)currentDocumentId authorLabel:(WKInterfaceLabel *)authorLabel imageGroup:(WKInterfaceGroup *)imageGroup isVisible:(bool (^)(void))isVisible completion:(void (^)(void))completion
{
    [TGMessageViewModel updateAuthorLabel:authorLabel isOutgoing:message.outgoing isGroup:isGroup user:[[TGBridgeUserCache instance] userWithId:(int32_t)message.fromUid] ownUserId:context.userId];
    
    for (TGBridgeMediaAttachment *attachment in message.media)
    {
        if ([attachment isKindOfClass:[TGBridgeDocumentMediaAttachment class]])
        {
            TGBridgeDocumentMediaAttachment *documentAttachment = (TGBridgeDocumentMediaAttachment *)attachment;
            
            if (currentDocumentId == NULL || *currentDocumentId != documentAttachment.documentId)
            {
                if (currentDocumentId != NULL)
                    *currentDocumentId = documentAttachment.documentId;
                
                [imageGroup setBackgroundImageSignal:[[[TGBridgeMediaSignals stickerWithDocumentId:documentAttachment.documentId peerId:message.cid messageId:message.identifier type:TGMediaStickerImageTypeNormal notification:notification] onNext:^(id next)
                {
                    if (completion != nil)
                        completion();
                }] onError:^(id error)
                {
                    if (currentDocumentId != NULL)
                        *currentDocumentId = 0;
                    
                    if (completion != nil)
                        completion();
                }] isVisible:isVisible];
            }
            break;
        }
    }
}

@end
