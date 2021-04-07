#import "TGNotificationController.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import "TGStringUtils.h"
#import "TGLocationUtils.h"
#import "WKInterfaceImage+Signals.h"

#import "TGInputController.h"

#import "TGMessageViewModel.h"

#import "TGBridgeMediaSignals.h"
#import "TGBridgeClient.h"
#import "TGBridgeUserCache.h"

#import <WatchConnectivity/WatchConnectivity.h>
#import <UserNotifications/UserNotifications.h>

@interface TGNotificationController()
{
    NSString *_currentAvatarPhoto;
    SMetaDisposable *_disposable;
}
@end

@implementation TGNotificationController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _disposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_disposable dispose];
}

- (void)didReceiveNotification:(UNNotification *)notification
{
    UNNotificationContent *content = notification.request.content;
    NSString *titleText = content.title;
    NSString *bodyText = content.body;
    
    if (titleText > 0){
        self.nameLabel.hidden = false;
        self.nameLabel.text = titleText;
    }
    self.messageTextLabel.text = bodyText;
    
    [self processMessageWithUserInfo:content.userInfo defaultTitle:titleText defaultBody:bodyText completion:nil];
}

- (void)didReceiveLocalNotification:(UILocalNotification *)localNotification withCompletion:(void (^)(WKUserNotificationInterfaceType))completionHandler
{
    [self processMessageWithUserInfo:localNotification.userInfo defaultTitle:localNotification.alertTitle defaultBody:localNotification.alertBody completion:completionHandler];
}

- (void)didReceiveRemoteNotification:(NSDictionary *)remoteNotification withCompletion:(void (^)(WKUserNotificationInterfaceType))completionHandler
{
    NSString *titleText = nil;
    NSString *bodyText = nil;
    if ([remoteNotification[@"aps"] respondsToSelector:@selector(objectForKey:)]) {
        NSDictionary *aps = remoteNotification[@"aps"];
        if ([aps[@"alert"] respondsToSelector:@selector(objectForKey:)]) {
            NSDictionary *alert = aps[@"alert"];
            if ([alert[@"body"] respondsToSelector:@selector(characterAtIndex:)]) {
                bodyText = alert[@"body"];
                if ([alert[@"title"] respondsToSelector:@selector(characterAtIndex:)]) {
                    titleText = alert[@"title"];
                }
            }
        } else if ([aps[@"alert"] respondsToSelector:@selector(characterAtIndex:)]) {
            NSString *alert = aps[@"alert"];
            NSUInteger colonLocation = [alert rangeOfString:@": "].location;
            if (colonLocation != NSNotFound) {
                titleText = [alert substringToIndex:colonLocation];
                bodyText = [alert substringFromIndex:colonLocation + 2];
            } else {
                bodyText = alert;
            }
        }
    }
    [self processMessageWithUserInfo:remoteNotification defaultTitle:titleText defaultBody:bodyText completion:completionHandler];
}

- (void)processMessageWithUserInfo:(NSDictionary *)userInfo defaultTitle:(NSString *)defaultTitle defaultBody:(NSString *)defaultBody completion:(void (^)(WKUserNotificationInterfaceType))completionHandler
{
    NSString *fromId = userInfo[@"from_id"];
    NSString *chatId = userInfo[@"chat_id"];
    NSString *channelId = userInfo[@"channel_id"];
    NSString *mid = userInfo[@"msg_id"];
    
    int64_t peerId = 0;
    if (fromId != nil) {
        peerId = [fromId longLongValue];
    } else if (chatId != nil) {
        peerId = TGPeerIdFromGroupId([chatId integerValue]);
    } else if (channelId != nil) {
        peerId = TGPeerIdFromChannelId([channelId integerValue]);
    }
    int32_t messageId = [mid intValue];
    
    if (true || peerId == 0 || messageId == 0)
    {
        if (defaultTitle.length > 0){
            self.nameLabel.hidden = false;
            self.nameLabel.text = defaultTitle;
        }
        self.messageTextLabel.text = defaultBody;
        if (completionHandler != nil)
            completionHandler(WKUserNotificationInterfaceTypeCustom);
        return;
    }
    
    NSLog(@"[Notification] processing message peerId: %lld mid: %d", peerId, messageId);
    TGBridgeChatMessageSubscription *subscription = [[TGBridgeChatMessageSubscription alloc] initWithPeerId:peerId messageId:messageId];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:subscription];

    __weak TGNotificationController *weakSelf = self;
    SSignal *signal = [[TGBridgeClient instance] sendMessageData:data];
    [_disposable setDisposable:[[signal timeout:4.5 onQueue:[SQueue mainQueue] orSignal:[SSignal single:@0]] startWithNext:^(NSData *messageData) {
        __strong TGNotificationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if ([messageData isKindOfClass:[NSData class]]) {
            NSLog(@"[Notification] Received message data, applying");
            
            TGBridgeResponse *response = [NSKeyedUnarchiver unarchiveObjectWithData:messageData];
            NSDictionary *message = response.next;
            [strongSelf updateWithMessage:message[TGBridgeMessageKey] users:message[TGBridgeUsersDictionaryKey] chat:message[TGBridgeChatKey] completion:completionHandler];
        }
        else {
            NSLog(@"[Notification] 4.5 sec timeout, fallback to apns data");
            
            strongSelf.nameLabel.hidden = false;
            strongSelf.nameLabel.text = defaultTitle;
            strongSelf.messageTextLabel.text = defaultBody;
            if (completionHandler != nil)
                completionHandler(WKUserNotificationInterfaceTypeCustom);
        }
    } error:^(id error)
    {
        __strong TGNotificationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        NSLog(@"[Notification] getMessage error, fallback to apns data");
        
        strongSelf.nameLabel.hidden = false;
        strongSelf.nameLabel.text = defaultTitle;
        strongSelf.messageTextLabel.text = defaultBody;
        if (completionHandler != nil)
            completionHandler(WKUserNotificationInterfaceTypeCustom);
    } completed:nil]];
}

- (void)updateWithMessage:(TGBridgeMessage *)message users:(NSDictionary *)users chat:(TGBridgeChat *)chat completion:(void (^)(WKUserNotificationInterfaceType))completionHandler
{
    [[TGBridgeUserCache instance] storeUsers:[users allValues]];
    
    bool mediaGroupHidden = true;
    bool mapGroupHidden = true;
    bool fileGroupHidden = true;
    bool stickerGroupHidden = true;
    bool captionGroupHidden = true;
    
    TGBridgeForwardedMessageMediaAttachment *forwardAttachment = nil;
    TGBridgeReplyMessageMediaAttachment *replyAttachment = nil;
    NSString *messageText = nil;
    
    __block NSInteger completionCount = 1;
    void (^completionBlock)(void) = ^
    {
        completionCount--;
        if (completionCount == 0 && completionHandler != nil)
            completionHandler(WKUserNotificationInterfaceTypeCustom);
    };
    
    for (TGBridgeMediaAttachment *attachment in message.media)
    {
        if ([attachment isKindOfClass:[TGBridgeForwardedMessageMediaAttachment class]])
        {
            forwardAttachment = (TGBridgeForwardedMessageMediaAttachment *)attachment;
        }
        else if ([attachment isKindOfClass:[TGBridgeReplyMessageMediaAttachment class]])
        {
            replyAttachment = (TGBridgeReplyMessageMediaAttachment *)attachment;
        }
        else if ([attachment isKindOfClass:[TGBridgeImageMediaAttachment class]])
        {
            mediaGroupHidden = false;
            
            TGBridgeImageMediaAttachment *imageAttachment = (TGBridgeImageMediaAttachment *)attachment;
            
            completionCount++;
            
            CGSize imageSize = CGSizeZero;
            [TGMessageViewModel updateMediaGroup:self.mediaGroup activityIndicator:nil attachment:imageAttachment message:message notification:true currentPhoto:NULL standalone:true margin:1.5f imageSize:&imageSize isVisible:nil completion:completionBlock];
            
            self.mediaGroup.width = imageSize.width;
            self.mediaGroup.height = imageSize.height;
            
            self.durationGroup.hidden = true;
        }
        else if ([attachment isKindOfClass:[TGBridgeVideoMediaAttachment class]])
        {
            mediaGroupHidden = false;
            
            TGBridgeVideoMediaAttachment *videoAttachment = (TGBridgeVideoMediaAttachment *)attachment;
            
            completionCount++;
            
            CGSize imageSize = CGSizeZero;
            [TGMessageViewModel updateMediaGroup:self.mediaGroup activityIndicator:nil attachment:videoAttachment message:message notification:true currentPhoto:NULL standalone:true margin:1.5f imageSize:&imageSize isVisible:nil completion:completionBlock];
            
            self.mediaGroup.width = imageSize.width;
            self.mediaGroup.height = imageSize.height;
            if (videoAttachment.round)
                self.mediaGroup.cornerRadius = imageSize.width / 2.0f;
            
            self.durationGroup.hidden = false;
            
            NSInteger durationMinutes = floor(videoAttachment.duration / 60.0);
            NSInteger durationSeconds = videoAttachment.duration % 60;
            self.durationLabel.text = [NSString stringWithFormat:@"%ld:%02ld", (long)durationMinutes, (long)durationSeconds];
        }
        else if ([attachment isKindOfClass:[TGBridgeDocumentMediaAttachment class]])
        {
            TGBridgeDocumentMediaAttachment *documentAttachment = (TGBridgeDocumentMediaAttachment *)attachment;
            
            if (documentAttachment.isSticker)
            {
                stickerGroupHidden = false;
                
                completionCount++;
                
                [TGStickerViewModel updateWithMessage:message notification:true isGroup:false context:nil currentDocumentId:NULL authorLabel:nil imageGroup:self.stickerGroup isVisible:nil completion:completionBlock];
            }
            else if (documentAttachment.isAudio && documentAttachment.isVoice)
            {
                fileGroupHidden = false;
                
                self.titleLabel.text = TGLocalized(@"Message.Audio");
                
                NSInteger durationMinutes = floor(documentAttachment.duration / 60.0);
                NSInteger durationSeconds = documentAttachment.duration % 60;
                self.subtitleLabel.text = [NSString stringWithFormat:@"%ld:%02ld", (long)durationMinutes, (long)durationSeconds];
                
                self.audioGroup.hidden = false;
                self.fileIconGroup.hidden = true;
                self.venueIcon.hidden = true;
            }
            else
            {
                fileGroupHidden = false;
                
                self.titleLabel.text = documentAttachment.fileName;
                self.subtitleLabel.text = [TGStringUtils stringForFileSize:documentAttachment.fileSize precision:2];
                
                self.fileIconGroup.hidden = false;
                self.audioGroup.hidden = true;
                self.venueIcon.hidden = true;
            }
        }
        else if ([attachment isKindOfClass:[TGBridgeAudioMediaAttachment class]])
        {
            fileGroupHidden = false;
            
            TGBridgeAudioMediaAttachment *audioAttachment = (TGBridgeAudioMediaAttachment *)attachment;
            
            self.titleLabel.text = TGLocalized(@"Message.Audio");
            
            NSInteger durationMinutes = floor(audioAttachment.duration / 60.0);
            NSInteger durationSeconds = audioAttachment.duration % 60;
            self.subtitleLabel.text = [NSString stringWithFormat:@"%ld:%02ld", (long)durationMinutes, (long)durationSeconds];
            
            self.audioGroup.hidden = false;
            self.fileIconGroup.hidden = true;
            self.venueIcon.hidden = true;
        }
        else if ([attachment isKindOfClass:[TGBridgeLocationMediaAttachment class]])
        {
            mapGroupHidden = false;
            
            TGBridgeLocationMediaAttachment *locationAttachment = (TGBridgeLocationMediaAttachment *)attachment;
            
            CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake([TGLocationUtils adjustGMapLatitude:locationAttachment.latitude withPixelOffset:-10 zoom:15], locationAttachment.longitude);
            self.map.region = MKCoordinateRegionMake(coordinate, MKCoordinateSpanMake(0.003, 0.003));
            self.map.centerPinCoordinate = CLLocationCoordinate2DMake(locationAttachment.latitude, locationAttachment.longitude);
            
            if (locationAttachment.venue != nil)
            {
                fileGroupHidden = false;
                
                self.titleLabel.text = locationAttachment.venue.title;
                self.subtitleLabel.text = locationAttachment.venue.address;
            }
            
            self.audioGroup.hidden = true;
            self.fileIconGroup.hidden = true;
            self.venueIcon.hidden = false;
        }
        else if ([attachment isKindOfClass:[TGBridgeContactMediaAttachment class]])
        {
            fileGroupHidden = false;
            
            TGBridgeContactMediaAttachment *contactAttachment = (TGBridgeContactMediaAttachment *)attachment;
            
            self.audioGroup.hidden = true;
            self.fileIconGroup.hidden = true;
            self.venueIcon.hidden = true;
            
            self.titleLabel.text = [contactAttachment displayName];
            self.subtitleLabel.text = contactAttachment.prettyPhoneNumber;
        }
        else if ([attachment isKindOfClass:[TGBridgeActionMediaAttachment class]])
        {
            messageText = [TGMessageViewModel stringForActionAttachment:(TGBridgeActionMediaAttachment *)attachment message:message users:users forChannel:(chat.isChannel && !chat.isChannelGroup)];
        }
        else if ([attachment isKindOfClass:[TGBridgeUnsupportedMediaAttachment class]])
        {
            fileGroupHidden = false;
            
            TGBridgeUnsupportedMediaAttachment *unsupportedAttachment = (TGBridgeUnsupportedMediaAttachment *)attachment;
            
            self.titleLabel.text = unsupportedAttachment.title;
            self.subtitleLabel.text = unsupportedAttachment.subtitle;
            
            self.fileIconGroup.hidden = true;
            self.audioGroup.hidden = true;
            self.venueIcon.hidden = true;
        }
    }
    
    if (messageText == nil)
        messageText = message.text;
    
    id forwardPeer = nil;
    if (forwardAttachment != nil)
    {
        if (TGPeerIdIsChannel(forwardAttachment.peerId))
            forwardPeer = users[@(forwardAttachment.peerId)];
        else
            forwardPeer = [[TGBridgeUserCache instance] userWithId:(int32_t)forwardAttachment.peerId];
    }
    [TGMessageViewModel updateForwardHeaderGroup:self.forwardHeaderGroup titleLabel:self.forwardTitleLabel fromLabel:self.forwardFromLabel forwardAttachment:forwardAttachment forwardPeer:forwardPeer textColor:[UIColor blackColor]];
    
    if (replyAttachment != nil)
    {
        self.replyHeaderImageGroup.hidden = true;
        completionCount++;
    }
    
    [TGMessageViewModel updateReplyHeaderGroup:self.replyHeaderGroup authorLabel:self.replyAuthorNameLabel imageGroup:nil textLabel:self.replyMessageTextLabel titleColor:[UIColor blackColor] subtitleColor:[UIColor hexColor:0x7e7e81] replyAttachment:replyAttachment currentReplyPhoto:NULL isVisible:nil completion:completionBlock];
    
    self.mediaGroup.hidden = mediaGroupHidden;
    self.mapGroup.hidden = mapGroupHidden;
    self.fileGroup.hidden = fileGroupHidden;
    self.captionGroup.hidden = captionGroupHidden;
    self.stickerGroup.hidden = stickerGroupHidden;
    self.stickerWrapperGroup.hidden = stickerGroupHidden;
    
    self.wrapperGroup.hidden = (self.mediaGroup.hidden && self.mapGroup.hidden && self.fileGroup.hidden && self.stickerGroup.hidden);
    
    if (chat.isGroup || chat.isChannelGroup)
    {
        self.chatTitleLabel.text = chat.groupTitle;
        self.chatTitleLabel.hidden = false;
    }
    
    self.nameLabel.hidden = false;
    if (chat.isChannel && !chat.isChannelGroup)
        self.nameLabel.text = chat.groupTitle;
    else
        self.nameLabel.text = [users[@(message.fromUid)] displayName];
    
    self.messageTextLabel.hidden = (messageText.length == 0);
    if (!self.messageTextLabel.hidden)
        self.messageTextLabel.text = messageText;
    
    completionBlock();
}

- (NSArray<NSString *> *)suggestionsForResponseToActionWithIdentifier:(NSString *)identifier forNotification:(UNNotification *)notification inputLanguage:(NSString *)inputLanguage
{
    return [TGInputController suggestionsForText:nil];
}

- (NSArray<NSString *> *)suggestionsForResponseToActionWithIdentifier:(NSString *)identifier forLocalNotification:(UILocalNotification *)localNotification inputLanguage:(NSString *)inputLanguage
{
    return [TGInputController suggestionsForText:nil];
}

- (NSArray<NSString *> *)suggestionsForResponseToActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)remoteNotification inputLanguage:(NSString *)inputLanguage
{
    return [TGInputController suggestionsForText:nil];
}

@end
