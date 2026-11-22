#import "TGNeoMediaMessageViewModel.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"

#import "TGGeometry.h"

#import "TGMessageViewModel.h"

const UIEdgeInsets TGNeoMediaMessageViewModelInsets = { 1.5, 1.5, 5.0, 1.5 };
const CGFloat TGNeoMediaCaptionSpacing = 3.0f;

@interface TGNeoMediaMessageViewModel ()
{
    TGNeoLabelViewModel *_textModel;
    
    int64_t _peerId;
    int32_t _messageId;
    TGBridgeImageMediaAttachment *_imageAttachment;
    TGBridgeVideoMediaAttachment *_videoAttachment;
    TGBridgeLocationMediaAttachment *_locationAttachment;
}
@end

@implementation TGNeoMediaMessageViewModel

- (instancetype)initWithMessage:(TGBridgeMessage *)message type:(TGNeoMessageType)type users:(NSDictionary *)users context:(TGBridgeContext *)context
{
    self = [super initWithMessage:message type:type users:users context:context];
    if (self != nil)
    {
        _peerId = message.cid;
        _messageId = message.identifier;
        
        bool hasHeader = (self.forwardHeaderModel != nil || self.replyHeaderModel != nil);
        for (TGBridgeMediaAttachment *attachment in message.media)
        {
            if ([attachment isKindOfClass:[TGBridgeImageMediaAttachment class]])
            {
                _imageAttachment = (TGBridgeImageMediaAttachment *)attachment;
            }
            else if ([attachment isKindOfClass:[TGBridgeVideoMediaAttachment class]])
            {
                _videoAttachment = (TGBridgeVideoMediaAttachment *)attachment;
            }
            else if ([attachment isKindOfClass:[TGBridgeLocationMediaAttachment class]])
            {
                _locationAttachment = (TGBridgeLocationMediaAttachment *)attachment;
            }
        }
        
        if (message.text.length > 0)
        {
            _textModel = [[TGNeoLabelViewModel alloc] initWithText:message.text font:[UIFont systemFontOfSize:[TGNeoBubbleMessageViewModel bodyTextFontSize]] color:[self normalColorForMessage:message type:type] attributes:nil];
            [self addSubmodel:_textModel];
        }
        
        self.showBubble = (_textModel != nil) || hasHeader;
    }
    return self;
}

- (CGSize)contentContainerSizeWithImageSize:(CGSize)imageSize
{
    return CGSizeMake(imageSize.width + TGNeoMediaMessageViewModelInsets.left + TGNeoMediaMessageViewModelInsets.right - TGNeoBubbleMessageViewModelInsets.left - TGNeoBubbleMessageViewModelInsets.right, FLT_MAX);
}

- (CGSize)layoutWithContainerSize:(CGSize)containerSize
{
    CGSize imageSize;
    if (_imageAttachment != nil)
    {
        imageSize = [self imageSizeForAttachment:_imageAttachment containerSize:containerSize];
    }
    else if (_videoAttachment != nil)
    {
        imageSize = [self imageSizeForAttachment:_videoAttachment containerSize:containerSize];
    }
    else
    {
        switch (TGWatchScreenType())
        {
            case TGScreenType42mm:
                imageSize = CGSizeMake(142, 92);
                break;
                
            default:
                imageSize = CGSizeMake(125, 92);
                break;
        }
    }
    
    CGSize contentContainerSize = self.showBubble ? [self contentContainerSizeWithImageSize:imageSize] : containerSize;
    
    CGSize headerSize = [self layoutHeaderModelsWithContainerSize:contentContainerSize];
    CGFloat textTopOffset = headerSize.height;
    CGSize contentSize = CGSizeZero;
    
    if (self.forwardHeaderModel == nil && self.replyHeaderModel == nil && self.authorNameModel == nil)
    {
        textTopOffset = TGNeoMediaMessageViewModelInsets.top;
    }
    else if (self.showBubble)
    {
        textTopOffset += TGNeoBubbleHeaderSpacing;
    }
    else if (!self.showBubble)
    {
        if (self.authorNameModel != nil)
            textTopOffset += TGNeoBubbleHeaderSpacing;
        else
            textTopOffset = 0;
    }
    
    UIEdgeInsets contentInsets = self.showBubble ? TGNeoMediaMessageViewModelInsets : UIEdgeInsetsZero;
    
    UIEdgeInsets inset = UIEdgeInsetsMake(textTopOffset, contentInsets.left, 0, 0);
    if (_imageAttachment != nil || _videoAttachment != nil)
    {
        TGBridgeMediaAttachment *attachment = _imageAttachment ?: _videoAttachment;
        
        [self addAdditionalLayout:@
        {
            TGNeoContentInset: [NSValue valueWithUIEdgeInsets:inset],
            TGNeoMessageMediaImage: @
            {
                TGNeoMessageMediaPeerId: @(_peerId),
                TGNeoMessageMediaMessageId: @(_messageId),
                TGNeoMessageMediaImageSpinner: @true,
                TGNeoMessageMediaPlayButton: @(_videoAttachment != nil),
                TGNeoMessageMediaImageAttachment: attachment,
                TGNeoMessageMediaSize: [NSValue valueWithCGSize:imageSize]
            }
        } withKey:TGNeoMessageMediaGroup];
    }
    else if (_locationAttachment != nil)
    {
        [self addAdditionalLayout:@
        {
            TGNeoContentInset: [NSValue valueWithUIEdgeInsets:inset],
            TGNeoMessageMediaMap: @
            {
                TGNeoMessageMediaMapCoordinate: [NSValue valueWithMKCoordinate:CLLocationCoordinate2DMake(_locationAttachment.latitude, _locationAttachment.longitude)],
                TGNeoMessageMediaSize: [NSValue valueWithCGSize:imageSize]
            }
        } withKey:TGNeoMessageMediaGroup];
    }
    
    contentSize.width = imageSize.width + contentInsets.left + contentInsets.right;
    
    if (_textModel != nil)
    {
        CGSize textSize = [_textModel contentSizeWithContainerSize:contentContainerSize];
        _textModel.frame = CGRectMake(TGNeoBubbleMessageViewModelInsets.left, textTopOffset + imageSize.height + TGNeoMediaCaptionSpacing, textSize.width, textSize.height);
        
        contentSize.height = CGRectGetMaxY(_textModel.frame) + TGNeoBubbleMessageViewModelInsets.bottom;
    }
    else
    {
        contentSize.height = textTopOffset + imageSize.height + contentInsets.bottom;
    }
    
    if (!self.showBubble)
    {
        //contentSize.width = containerSize.width;
        contentSize.height += 3.5f;
    }
    
    [super layoutWithContainerSize:contentSize];
    
    return contentSize;
}

- (CGSize)imageSizeForAttachment:(TGBridgeMediaAttachment *)attachment containerSize:(CGSize)containerSize
{
    CGSize targetImageSize = CGSizeZero;
    
    if ([attachment isKindOfClass:[TGBridgeImageMediaAttachment class]])
        targetImageSize = ((TGBridgeImageMediaAttachment *)attachment).dimensions;
    else if ([attachment isKindOfClass:[TGBridgeVideoMediaAttachment class]])
        targetImageSize = ((TGBridgeVideoMediaAttachment *)attachment).dimensions;
    
    CGSize screenSize = containerSize;
    
    CGSize mediaGroupSize = CGSizeZero;
    CGSize maxSize = CGSizeMake(screenSize.width - 15, screenSize.width);
    CGSize minSize = CGSizeMake(screenSize.width / 1.25f, screenSize.width / 2);
    [TGMessageViewModel imageBubbleSizeForImageSize:targetImageSize minSize:minSize maxSize:maxSize thumbnailSize:&mediaGroupSize renderSize:NULL];
    
    mediaGroupSize = CGSizeMake(ceilf(mediaGroupSize.width), ceilf(mediaGroupSize.height));
    
    return mediaGroupSize;
}

@end
