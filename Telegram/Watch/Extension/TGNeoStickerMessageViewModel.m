#import "TGNeoStickerMessageViewModel.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import "TGNeoLabelViewModel.h"

#import "TGNeoBubbleMessageViewModel.h"

#import "TGGeometry.h"

#import "../Extension/TGStringUtils.h"

@interface TGNeoStickerMessageViewModel ()
{
    int64_t _peerId;
    int32_t _messageId;
    
    TGNeoLabelViewModel *_authorNameModel;
    
    TGBridgeDocumentMediaAttachment *_documentAttachment;
    bool _outgoing;
}
@end

@implementation TGNeoStickerMessageViewModel

- (instancetype)initWithMessage:(TGBridgeMessage *)message type:(TGNeoMessageType)type users:(NSDictionary *)users context:(TGBridgeContext *)context
{
    self = [super initWithMessage:message type:type users:users context:context];
    if (self != nil)
    {
        _peerId = message.cid;
        _messageId = message.identifier;
        
        self.showBubble = false;
        
        TGBridgeDocumentMediaAttachment *documentAttachment = nil;
        for (TGBridgeMediaAttachment *attachment in message.media)
        {
            if ([attachment isKindOfClass:[TGBridgeDocumentMediaAttachment class]])
            {
                documentAttachment = (TGBridgeDocumentMediaAttachment *)attachment;
                break;
            }
        }
        
        _documentAttachment = documentAttachment;
        _outgoing = message.outgoing;
        
        if (message.cid < 0 && !TGPeerIdIsChannel(message.cid) && !message.outgoing)
        {
            _authorNameModel = [[TGNeoLabelViewModel alloc] initWithText:[users[@(message.fromUid)] displayName] font:[UIFont systemFontOfSize:14] color:[TGColor colorForUserId:(int32_t)message.fromUid myUserId:context.userId] attributes:nil];
            [self addSubmodel:_authorNameModel];
        }
    }
    return self;
}

- (CGSize)layoutWithContainerSize:(CGSize)containerSize
{
    CGFloat textTopOffset = 0;
    if (_authorNameModel != nil)
    {
        CGSize nameSize = [_authorNameModel contentSizeWithContainerSize:CGSizeMake(containerSize.width - TGNeoBubbleMessageViewModelInsets.left - TGNeoBubbleMessageViewModelInsets.right, FLT_MAX)];
        _authorNameModel.frame = CGRectMake(TGNeoBubbleMessageViewModelInsets.left, floor(TGNeoBubbleMessageViewModelInsets.top / 2.0), nameSize.width, 16.5f);
        textTopOffset += CGRectGetMaxY(_authorNameModel.frame) + TGNeoBubbleHeaderSpacing;
    }
    
    CGFloat stickerHeight = TGWatchStickerSizeForScreen(TGWatchScreenType()).height;
    CGSize imageSize = TGFitSize(_documentAttachment.imageSize.CGSizeValue, CGSizeMake(containerSize.width / 2, stickerHeight));
    
    UIEdgeInsets inset = UIEdgeInsetsMake(textTopOffset, 0, 0, 0);
    if (_documentAttachment != nil)
    {
        [self addAdditionalLayout:@
        {
            TGNeoContentInset: [NSValue valueWithUIEdgeInsets:inset],
            TGNeoMessageMediaImage: @
            {
                TGNeoMessageMediaPeerId: @(_peerId),
                TGNeoMessageMediaMessageId: @(_messageId),
                TGNeoMessageMediaImageAttachment: _documentAttachment,
                TGNeoMessageMediaSize: [NSValue valueWithCGSize:imageSize]
            }
        } withKey:TGNeoMessageMediaGroup];
    }
    
    self.contentSize = CGSizeMake(MAX(CGRectGetMaxX(_authorNameModel.frame), imageSize.width), ceilf(imageSize.height) + textTopOffset + 2);
    
    return self.contentSize;
}

@end
