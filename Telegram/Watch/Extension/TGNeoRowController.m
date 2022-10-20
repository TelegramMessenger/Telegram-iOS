#import "TGNeoRowController.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import "TGNeoConversationRowController.h"
#import "TGNeoConversationSimpleRowController.h"
#import "TGNeoConversationMediaRowController.h"
#import "TGNeoConversationStaticRowController.h"

#import "TGStringUtils.h"
#import "TGLocationUtils.h"

#import "TGNeoMessageViewModel.h"
#import "TGNeoBubbleMessageViewModel.h"
#import "TGNeoStickerMessageViewModel.h"

#import "WKInterfaceGroup+Signals.h"
#import "TGBridgeMediaSignals.h"

@interface TGNeoRowController ()
{
    TGNeoMessageViewModel *_viewModel;
    SMetaDisposable *_renderDisposable;
    
    bool _pendingRendering;
    
    bool _processing;
    NSString *_normalIconName;
    NSString *_processingIconName;
}
@end

@implementation TGNeoRowController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _renderDisposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_renderDisposable dispose];
}

+ (CGSize)containerSizeForMessage:(TGBridgeMessage *)message
{
    if (message.outgoing)
    {
        static dispatch_once_t onceToken;
        static CGSize containerSize;
        dispatch_once(&onceToken, ^
        {
            CGSize screenSize = [[WKInterfaceDevice currentDevice] screenBounds].size;
            containerSize = CGSizeMake(screenSize.width - 5, screenSize.height);
        });
        return containerSize;
    }
    else
    {
        static dispatch_once_t onceToken;
        static CGSize containerSize;
        dispatch_once(&onceToken, ^
        {
            containerSize = [[WKInterfaceDevice currentDevice] screenBounds].size;
        });
        return containerSize;
    }
}

- (void)updateWithMessage:(TGBridgeMessage *)message context:(TGBridgeContext *)context index:(NSInteger)index type:(TGNeoMessageType)type
{
    bool isChannelMessage = (type == TGNeoMessageTypeChannel);
    
    if (!isChannelMessage)
        [self updateStatusWithMessage:message];
    
    if ([self renderIfNeeded])
        return;
    
    if (_viewModel != nil)
        return;
    
    _viewModel = [TGNeoMessageViewModel viewModelForMessage:message type:type context:context additionalPeers:self.additionalPeers];
    
    CGSize containerSize = [TGNeoRowController containerSizeForMessage:message];
    CGSize contentSize = [_viewModel layoutWithContainerSize:containerSize];
    
    if (_viewModel.showBubble)
    {
        if (isChannelMessage)
        {
            [self.bubbleGroup setBackgroundImageNamed:@"ChatBubbleChannel"];
        }
        else
        {
            if (message.outgoing)
                [self.bubbleGroup setBackgroundImageNamed:@"ChatBubbleOutgoing"];
            else
                [self.bubbleGroup setBackgroundImageNamed:@"ChatBubbleIncoming"];
        }
    }
    
    if (!isChannelMessage && message.outgoing)
    {
        [self.bubbleGroup setHorizontalAlignment:WKInterfaceObjectHorizontalAlignmentRight];
        
        if (!_viewModel.showBubble)
            [self.statusGroup setContentInset:UIEdgeInsetsMake(4, 0, 0, 0)];
    }
    
    self.bubbleGroup.width = contentSize.width;
    self.bubbleGroup.height = contentSize.height;
    
    self.contentGroup.width = contentSize.width;
    self.contentGroup.height = contentSize.height;
    
    [self applyAdditionalLayoutForViewModel:_viewModel];
    
    bool shouldRender = true;
    if (self.shouldRenderContent != nil)
        shouldRender = self.shouldRenderContent();
    
    if (shouldRender)
        [self _render];
    else
        _pendingRendering = true;
}

- (void)_render
{
    _pendingRendering = false;
    
    bool onMainThread = true;    
    SSignal *signal = [TGNeoRenderableViewModel renderSignalForViewModel:_viewModel];
    if (!onMainThread)
        signal = [[signal startOn:[SQueue concurrentDefaultQueue]] deliverOn:[SQueue mainQueue]];
    
    __weak TGNeoRowController *weakSelf = self;
    [_renderDisposable setDisposable:[signal startWithNext:^(UIImage *image)
    {
        __strong TGNeoRowController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf.contentGroup setBackgroundImage:image];
    }]];
}

- (bool)renderIfNeeded
{
    if (!_pendingRendering)
        return false;
    
    [self _render];
    
    return true;
}

- (void)updateStatusWithMessage:(TGBridgeMessage *)message
{
    if (message.outgoing)
    {
        bool failed = (message.deliveryState == TGBridgeMessageDeliveryStateFailed);
        bool unread = (message.deliveryState == TGBridgeMessageDeliveryStatePending || (message.deliveryState == TGBridgeMessageDeliveryStateDelivered && message.unread));

        bool dotHidden = !failed && !unread;
        self.statusGroup.hidden = dotHidden;

        if (!dotHidden)
        {
            if (failed)
                [self.statusIcon setTintColor:[UIColor hexColor:0xff4a5c]];
            else if (unread)
                [self.statusIcon setTintColor:[UIColor hexColor:0x2ba2e7]];
        }
    }
}

- (void)applyAdditionalLayoutForViewModel:(TGNeoMessageViewModel *)viewModel
{
    NSDictionary *layout = viewModel.additionalLayout;
    
    NSDictionary *headerGroupLayout = layout[TGNeoMessageHeaderGroup];
    if (headerGroupLayout != nil)
    {
        self.headerWrapperGroup.hidden = false;
        
        NSDictionary *imageLayout = headerGroupLayout[TGNeoMessageReplyImageGroup];
        if (imageLayout != nil)
        {
            TGBridgeMediaAttachment *attachment = imageLayout[TGNeoMessageReplyMediaAttachment];
            if (attachment != nil)
            {
                int64_t peerId = [imageLayout[TGNeoMessageMediaPeerId] int64Value];
                int32_t messageId = [imageLayout[TGNeoMessageMediaMessageId] int32Value];
                
                CGSize imageSize = CGSizeMake(26, 26);
                [self.replyImageGroup setBackgroundImageSignal:[TGBridgeMediaSignals thumbnailWithPeerId:peerId messageId:messageId size:imageSize notification:false] isVisible:self.isVisible];
            }
        }
        
        NSValue *insetValue = headerGroupLayout[TGNeoContentInset];
        if (insetValue != nil)
        {
            UIEdgeInsets inset = insetValue.UIEdgeInsetsValue;
            [self.headerWrapperGroup setContentInset:inset];
        }
    }
    
    NSDictionary *mediaGroupLayout = layout[TGNeoMessageMediaGroup];
    if (mediaGroupLayout != nil)
    {
        self.mediaWrapperGroup.hidden = false;
        
        if (![viewModel isKindOfClass:[TGNeoStickerMessageViewModel class]])
            [self.imageGroup setCornerRadius:viewModel.showBubble ? 12 : 13];
        
        NSDictionary *imageGroup = mediaGroupLayout[TGNeoMessageMediaImage];
        NSDictionary *mapGroup = mediaGroupLayout[TGNeoMessageMediaMap];
        if (imageGroup != nil)
        {
            self.imageGroup.hidden = false;
            TGBridgeMediaAttachment *attachment = imageGroup[TGNeoMessageMediaImageAttachment];
            int64_t peerId = [imageGroup[TGNeoMessageMediaPeerId] int64Value];
            int32_t messageId = [imageGroup[TGNeoMessageMediaMessageId] int32Value];
            
            CGSize size = CGSizeMake(100, 100);
            NSValue *imageSizeValue = imageGroup[TGNeoMessageMediaSize];
            if (imageSizeValue != nil)
            {
                size = imageSizeValue.CGSizeValue;
                self.imageGroup.width = size.width;
                self.imageGroup.height = size.height;
                
                if ([attachment isKindOfClass:[TGBridgeVideoMediaAttachment class]] && ((TGBridgeVideoMediaAttachment *)attachment).round) {
                    self.imageGroup.cornerRadius = size.width / 2.0f;
                }
            }
            
            bool hasPlayButton = [imageGroup[TGNeoMessageMediaPlayButton] boolValue];
            bool hasSpinner = [imageGroup[TGNeoMessageMediaImageSpinner] boolValue];
            
            if (hasSpinner)
                self.spinnerImage.hidden = false;
            
            __weak TGNeoRowController *weakSelf = self;
            if ([attachment isKindOfClass:[TGBridgeImageMediaAttachment class]])
            {
                [self.imageGroup setBackgroundImageSignal:[[TGBridgeMediaSignals thumbnailWithPeerId:peerId messageId:messageId size:size notification:false] onNext:^(id next)
                {
                    __strong TGNeoRowController *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    strongSelf.spinnerImage.hidden = true;
                }] isVisible:self.isVisible];
            }
            else if ([attachment isKindOfClass:[TGBridgeVideoMediaAttachment class]])
            {
                [self.imageGroup setBackgroundImageSignal:[[TGBridgeMediaSignals thumbnailWithPeerId:peerId messageId:messageId size:size notification:false] onNext:^(id next)
                {
                    __strong TGNeoRowController *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                                                               
                    strongSelf.spinnerImage.hidden = true;
                    if (hasPlayButton)
                        strongSelf.videoButton.hidden = false;
                }] isVisible:self.isVisible];
            }
            else if ([attachment isKindOfClass:[TGBridgeDocumentMediaAttachment class]])
            {
                TGBridgeDocumentMediaAttachment *document = (TGBridgeDocumentMediaAttachment *)attachment;
                [self.imageGroup setBackgroundImageSignal:[TGBridgeMediaSignals stickerWithDocumentId:document.documentId peerId:peerId messageId:messageId type:TGMediaStickerImageTypeNormal notification:false] isVisible:self.isVisible];
            }
        }
        else if (mapGroup != nil)
        {
            self.map.hidden = false;
            
            CGSize size;
            NSValue *imageSizeValue = mapGroup[TGNeoMessageMediaSize];
            if (imageSizeValue != nil)
            {
                size = imageSizeValue.CGSizeValue;
                self.map.width = size.width;
                self.map.height = size.height;
            }
            
            NSValue *coordinateValue = mapGroup[TGNeoMessageMediaMapCoordinate];
            if (coordinateValue != nil)
            {
                CLLocationCoordinate2D coordinate = [coordinateValue MKCoordinateValue];
                CLLocationCoordinate2D regionCoordinate = CLLocationCoordinate2DMake([TGLocationUtils adjustGMapLatitude:coordinate.latitude withPixelOffset:-10 zoom:15], coordinate.longitude);
                
                self.map.region = MKCoordinateRegionMake(regionCoordinate, MKCoordinateSpanMake(0.003, 0.003));
                self.map.centerPinCoordinate = coordinate;
            }
        }
        
        NSValue *insetValue = mediaGroupLayout[TGNeoContentInset];
        if (insetValue != nil)
        {
            UIEdgeInsets inset = insetValue.UIEdgeInsetsValue;
            [self.mediaWrapperGroup setContentInset:inset];
        }
    }
    
    NSDictionary *metaGroupLayout = layout[TGNeoMessageMetaGroup];
    if (metaGroupLayout != nil)
    {
        self.metaWrapperGroup.hidden = false;
        
        NSDictionary *audioLayout = metaGroupLayout[TGNeoMessageAudioButton];
        if (audioLayout != nil)
        {
            self.audioButton.hidden = false;
            
            NSNumber *hasBackground = audioLayout[TGNeoMessageAudioButtonHasBackground] ?: @true;
            if (hasBackground.boolValue) {
                UIColor *color = audioLayout[TGNeoMessageAudioBackgroundColor];
                if (color != nil) {
                    [self.audioButtonGroup setBackgroundColor:color];
                } else {
                    [self.audioButtonGroup setBackgroundColor:[UIColor hexColor:0x6bbeee]];
                }
            }
            else
                [self.audioButtonGroup setBackgroundColor:[UIColor clearColor]];
            
            NSString *audioIcon = audioLayout[TGNeoMessageAudioIcon];
            if (audioIcon != nil)
            {
                _normalIconName = audioIcon;
                [self.audioIcon setImageNamed:audioIcon];
            }
            
            NSString *audioAnimatedIcon = audioLayout[TGNeoMessageAudioAnimatedIcon];
            if (audioAnimatedIcon != nil)
                _processingIconName = audioAnimatedIcon;
            
            UIColor *iconColor = audioLayout[TGNeoMessageAudioIconTint];
            if (iconColor != nil)
                [self.audioIcon setTintColor:iconColor];
        }
        
        NSDictionary *avatarLayout = metaGroupLayout[TGNeoMessageAvatarGroup];
        if (avatarLayout != nil)
        {
            self.avatarGroup.hidden = false;
            
            int64_t identifier = [avatarLayout[TGNeoMessageAvatarIdentifier] int64Value];
            NSString *avatarUrl = avatarLayout[TGNeoMessageAvatarUrl];
            if (avatarUrl.length > 0)
            {
                [self.avatarGroup setBackgroundImageSignal:[TGBridgeMediaSignals avatarWithPeerId:identifier url:avatarUrl type:TGBridgeMediaAvatarTypeSmall] isVisible:self.isVisible];
            }
            else
            {
                NSString *initials = avatarLayout[TGNeoMessageAvatarInitials];
                UIColor *color = avatarLayout[TGNeoMessageAvatarColor];
                
                self.avatarLabel.hidden = false;
                self.avatarLabel.text = initials;
                [self.avatarGroup setBackgroundColor:color];
            }
        }
        
        NSValue *insetValue = metaGroupLayout[TGNeoContentInset];
        if (insetValue != nil)
        {
            UIEdgeInsets inset = insetValue.UIEdgeInsetsValue;
            [self.metaWrapperGroup setContentInset:inset];
        }
    }
}

- (IBAction)remotePressedAction
{
    if (self.buttonPressed != nil)
        self.buttonPressed();
}

- (void)setProcessingState:(bool)processing
{
    if (processing == _processing)
        return;
    
    _processing = processing;
    
    if (processing)
    {
        [self.audioIcon setImageNamed:_processingIconName];
        [self.audioIcon startAnimatingWithImagesInRange:NSMakeRange(0, 39) duration:0.65 repeatCount:0];
    }
    else
    {
        [self.audioIcon stopAnimating];
        [self.audioIcon setImageNamed:_normalIconName];
    }
}

+ (Class)rowControllerClassForMessage:(TGBridgeMessage *)message
{
    Class class = [TGNeoConversationRowController class];
    
    bool hasReplyHeader = false;
    bool hasAttachments = false;
    
    for (TGBridgeMediaAttachment *attachment in message.media)
    {
        if ([attachment isKindOfClass:[TGBridgeImageMediaAttachment class]])
        {
            hasAttachments = true;
            class = [TGNeoConversationMediaRowController class];
        }
        else if ([attachment isKindOfClass:[TGBridgeVideoMediaAttachment class]])
        {
            hasAttachments = true;
            class = [TGNeoConversationMediaRowController class];
        }
        else if ([attachment isKindOfClass:[TGBridgeDocumentMediaAttachment class]])
        {
            hasAttachments = true;
            TGBridgeDocumentMediaAttachment *documentAttachment = (TGBridgeDocumentMediaAttachment *)attachment;
            if (documentAttachment.isSticker)
                class = [TGNeoConversationMediaRowController class];
        }
        else if ([attachment isKindOfClass:[TGBridgeLocationMediaAttachment class]])
        {
            hasAttachments = true;
            if (((TGBridgeLocationMediaAttachment *)attachment).venue == nil)
                class = [TGNeoConversationMediaRowController class];
        }
        else if ([attachment isKindOfClass:[TGBridgeAudioMediaAttachment class]])
        {
            hasAttachments = true;
        }
        else if ([attachment isKindOfClass:[TGBridgeUnsupportedMediaAttachment class]])
        {
            hasAttachments = true;
        }
        else if ([attachment isKindOfClass:[TGBridgeActionMediaAttachment class]])
        {
            class = [TGNeoConversationStaticRowController class];
        }
        else if ([attachment isKindOfClass:[TGBridgeForwardedMessageMediaAttachment class]])
        {
        }
        else if ([attachment isKindOfClass:[TGBridgeReplyMessageMediaAttachment class]])
        {
            hasReplyHeader = true;
        }
    }
    
    if (class == [TGNeoConversationRowController class] && !hasReplyHeader && !hasAttachments)
        class = [TGNeoConversationSimpleRowController class];
    
    return class;
}

@end
