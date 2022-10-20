#import "TGMessageViewMessageRowController.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import "TGExtensionDelegate.h"

#import "TGDateUtils.h"
#import "TGStringUtils.h"
#import "TGLocationUtils.h"

#import "WKInterfaceGroup+Signals.h"
#import "TGMessageViewModel.h"

#import "TGBridgeMediaSignals.h"

#import "TGBridgeUserCache.h"

NSString *const TGMessageViewMessageRowIdentifier = @"TGMessageViewMessageRow";

@interface TGMessageViewMessageRowController ()
{
    NSString *_currentAvatarPhoto;
    int64_t _currentDocumentId;
    int64_t _currentPhotoId;
    int64_t _currentReplyPhotoId;
    
    bool _processing;
}
@end

@implementation TGMessageViewMessageRowController

- (IBAction)forwardButtonPressedAction
{
    if (self.forwardPressed != nil)
        self.forwardPressed();
}

- (IBAction)playButtonPressedAction
{
    if (self.playPressed != nil)
        self.playPressed();
}

- (IBAction)contactButtonPressedAction
{
    if (self.contactPressed != nil)
        self.contactPressed();
}

- (void)updateWithMessage:(TGBridgeMessage *)message context:(TGBridgeContext *)context additionalPeers:(NSDictionary *)additionalPeers
{
    bool mediaGroupHidden = true;
    bool mapGroupHidden = true;
    bool fileGroupHidden = true;
    bool stickerGroupHidden = true;
    bool contactButtonHidden = true;
    
    TGBridgeForwardedMessageMediaAttachment *forwardAttachment = nil;
    TGBridgeReplyMessageMediaAttachment *replyAttachment = nil;
    id messageText = nil;
    CGFloat fontSize = [TGMessageViewMessageRowController textFontSize];
    
    bool inhibitForwardHeader = false;
    
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
            
            if (message.text.length > 0)
                messageText = message.text;
            
            CGSize imageSize = CGSizeZero;
            
            [TGMessageViewModel updateMediaGroup:self.mediaGroup activityIndicator:self.activityIndicator attachment:imageAttachment message:message notification:false currentPhoto:&_currentPhotoId standalone:true margin:0 imageSize:&imageSize isVisible:self.isVisible completion:nil];
            
            self.mediaGroup.width = imageSize.width;
            self.mediaGroup.height = imageSize.height;
            
            self.playButton.hidden = true;
            self.durationGroup.hidden = true;
        }
        else if ([attachment isKindOfClass:[TGBridgeVideoMediaAttachment class]])
        {
            mediaGroupHidden = false;

            TGBridgeVideoMediaAttachment *videoAttachment = (TGBridgeVideoMediaAttachment *)attachment;
            
            if (message.text.length > 0)
                messageText = message.text;
            
            CGSize imageSize = CGSizeZero;
            
            [TGMessageViewModel updateMediaGroup:self.mediaGroup activityIndicator:self.activityIndicator attachment:videoAttachment message:message notification:false currentPhoto:NULL standalone:true margin:0 imageSize:&imageSize isVisible:self.isVisible completion:nil];
            
            self.mediaGroup.width = imageSize.width;
            self.mediaGroup.height = imageSize.height;
            
            self.playButton.hidden = false;
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
                
                [TGStickerViewModel updateWithMessage:message notification:false isGroup:false context:context currentDocumentId:&_currentDocumentId authorLabel:nil imageGroup:self.stickerGroup isVisible:self.isVisible completion:nil];
            }
            else if (documentAttachment.isAudio && documentAttachment.isVoice)
            {
                fileGroupHidden = false;
                
                if (documentAttachment.isAudio && message.text.length > 0)
                    messageText = message.text;
                
                self.titleLabel.text = TGLocalized(@"Message.Audio");
                
                NSInteger durationMinutes = floor(documentAttachment.duration / 60.0);
                NSInteger durationSeconds = documentAttachment.duration % 60;
                self.subtitleLabel.text = [NSString stringWithFormat:@"%ld:%02ld", (long)durationMinutes, (long)durationSeconds];
                
                self.audioButton.hidden = false;
                self.fileIconGroup.hidden = true;
                self.venueIcon.hidden = true;
                
                inhibitForwardHeader = true;
            }
            else
            {
                fileGroupHidden = false;
                
                if (message.text.length > 0)
                    messageText = message.text;
                
                self.titleLabel.text = documentAttachment.fileName;
                self.subtitleLabel.text = [TGStringUtils stringForFileSize:documentAttachment.fileSize precision:2];
                
                self.fileIconGroup.hidden = false;
                self.audioButton.hidden = true;
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
            
            self.audioButton.hidden = false;
            self.fileIconGroup.hidden = true;
            self.venueIcon.hidden = true;
            
            inhibitForwardHeader = true;
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
            
            self.audioButton.hidden = true;
            self.fileIconGroup.hidden = true;
            self.venueIcon.hidden = false;
        }
        else if ([attachment isKindOfClass:[TGBridgeContactMediaAttachment class]])
        {
            contactButtonHidden = false;
            
            TGBridgeContactMediaAttachment *contactAttachment = (TGBridgeContactMediaAttachment *)attachment;
            
            TGBridgeUser *user = [[TGBridgeUserCache instance] userWithId:contactAttachment.uid];
            
            self.avatarGroup.hidden = false;
            
            if (user != nil)
            {
                self.contactButton.enabled = true;
                
                if (user.photoSmall.length > 0)
                {
                    self.avatarInitialsLabel.hidden = true;
                    self.avatarGroup.backgroundColor = [UIColor hexColor:0x222223];
                    if (![_currentAvatarPhoto isEqualToString:user.photoSmall])
                    {
                        _currentAvatarPhoto = user.photoSmall;
                        
                        __weak TGMessageViewMessageRowController *weakSelf = self;
                        [self.avatarGroup setBackgroundImageSignal:[[TGBridgeMediaSignals avatarWithPeerId:user.identifier url:_currentAvatarPhoto type:TGBridgeMediaAvatarTypeSmall] onError:^(id next)
                        {
                            __strong TGMessageViewMessageRowController *strongSelf = weakSelf;
                            if (strongSelf != nil)
                                strongSelf->_currentAvatarPhoto = nil;
                        }] isVisible:self.isVisible];
                    }
                }
                else
                {
                    self.avatarInitialsLabel.hidden = false;
                    self.avatarGroup.backgroundColor = [TGColor colorForUserId:(int32_t)user.identifier myUserId:context.userId];
                    self.avatarInitialsLabel.text = [TGStringUtils initialsForFirstName:user.firstName lastName:user.lastName single:true];
                    
                    [self.avatarGroup setBackgroundImageSignal:nil isVisible:self.isVisible];
                    _currentAvatarPhoto = nil;
                }
            }
            else
            {
                self.contactButton.enabled = false;

                self.avatarInitialsLabel.hidden = false;                
                self.avatarGroup.backgroundColor = [UIColor grayColor];
                self.avatarInitialsLabel.text = [TGStringUtils initialsForFirstName:contactAttachment.firstName lastName:contactAttachment.lastName single:true];
            }
            
            self.nameLabel.text = [contactAttachment displayName];
            self.phoneLabel.text = contactAttachment.prettyPhoneNumber;
        }
        else if ([attachment isKindOfClass:[TGBridgeUnsupportedMediaAttachment class]])
        {
            fileGroupHidden = false;
            
            TGBridgeUnsupportedMediaAttachment *unsupportedAttachment = (TGBridgeUnsupportedMediaAttachment *)attachment;
            
            self.titleLabel.text = unsupportedAttachment.title;
            self.subtitleLabel.text = unsupportedAttachment.subtitle;
            
            self.fileIconGroup.hidden = true;
            self.audioButton.hidden = true;
            self.venueIcon.hidden = true;
        }
    }
    
    if (messageText == nil)
        messageText = [TGMessageViewModel attributedTextForMessage:message fontSize:fontSize textColor:[UIColor whiteColor]];
    
    if (inhibitForwardHeader)
        forwardAttachment = nil;

    id forwardPeer = nil;
    if (forwardAttachment != nil)
    {
        if (TGPeerIdIsChannel(forwardAttachment.peerId))
            forwardPeer = additionalPeers[@(forwardAttachment.peerId)];
        else
            forwardPeer = [[TGBridgeUserCache instance] userWithId:(int32_t)forwardAttachment.peerId];
    }
    
    [TGMessageViewModel updateForwardHeaderGroup:self.forwardHeaderButton titleLabel:self.forwardTitleLabel fromLabel:self.forwardFromLabel forwardAttachment:forwardAttachment forwardPeer:forwardPeer textColor:[UIColor whiteColor]];
    
    [TGMessageViewModel updateReplyHeaderGroup:self.replyHeaderGroup authorLabel:self.replyAuthorNameLabel imageGroup:self.replyHeaderImageGroup textLabel:self.replyMessageTextLabel titleColor:[UIColor whiteColor] subtitleColor:[UIColor hexColor:0x7e7e81] replyAttachment:replyAttachment currentReplyPhoto:&_currentReplyPhotoId isVisible:self.isVisible completion:nil];
    
    self.mediaGroup.hidden = mediaGroupHidden;
    self.mapGroup.hidden = mapGroupHidden;
    self.fileGroup.hidden = fileGroupHidden;
    self.contactButton.hidden = contactButtonHidden;
    self.stickerGroup.hidden = stickerGroupHidden;
    
    self.messageTextLabel.hidden = (((NSString *)messageText).length == 0);
    if (!self.messageTextLabel.hidden)
    {
        if ([messageText isKindOfClass:[NSString class]])
        {
            if (fontSize == 16.0f)
                self.messageTextLabel.text = messageText;
            else
                self.messageTextLabel.attributedText = [TGMessageViewModel attributedTextForMessage:message fontSize:fontSize textColor:[UIColor whiteColor]];
        }
        else if ([messageText isKindOfClass:[NSAttributedString class]])
        {
            self.messageTextLabel.attributedText = messageText;
        }
    }
}

- (void)setProcessingState:(bool)processing
{
    if (processing == _processing)
        return;
    
    _processing = processing;
    
    if (processing)
    {
        [self.audioIcon setImageNamed:@"BubbleSpinner"];
        [self.audioIcon startAnimatingWithImagesInRange:NSMakeRange(0, 39) duration:0.65 repeatCount:0];
    }
    else
    {
        [self.audioIcon stopAnimating];
        [self.audioIcon setImageNamed:@"MediaAudioPlay"];
    }
}

- (void)notifyVisiblityChange
{
    [self.replyHeaderImageGroup updateIfNeeded];
    [self.mediaGroup updateIfNeeded];
    [self.avatarGroup updateIfNeeded];
    [self.stickerGroup updateIfNeeded];
}

+ (CGFloat)textFontSize
{
    TGContentSizeCategory category = [TGExtensionDelegate instance].contentSizeCategory;
    
    switch (category)
    {
        case TGContentSizeCategoryXS:
            return 14.0f;
            
        case TGContentSizeCategoryS:
            return 15.0f;
            
        case TGContentSizeCategoryL:
            return 16.0f;
            
        case TGContentSizeCategoryXL:
            return 17.0f;
            
        case TGContentSizeCategoryXXL:
            return 18.0f;
            
        case TGContentSizeCategoryXXXL:
            return 19.0f;
            
        default:
            break;
    }
    
    return 16.0f;
}

+ (NSString *)identifier
{
    return TGMessageViewMessageRowIdentifier;
}

@end
