#import "TGNeoUnsupportedMessageViewModel.h"
#import "TGWatchCommon.h"
#import <WatchCommonWatch/WatchCommonWatch.h>

@interface TGNeoUnsupportedMessageViewModel ()
{
    TGNeoLabelViewModel *_titleModel;
    TGNeoLabelViewModel *_subtitleModel;
    
    UIColor *_buttonTint;
    UIColor *_iconTint;
}
@end

@implementation TGNeoUnsupportedMessageViewModel

- (instancetype)initWithMessage:(TGBridgeMessage *)message type:(TGNeoMessageType)type users:(NSDictionary *)users context:(TGBridgeContext *)context
{
    self = [super initWithMessage:message type:type users:users context:context];
    if (self != nil)
    {
        TGBridgeUnsupportedMediaAttachment *unsupportedAttachment = nil;
    
        for (TGBridgeMediaAttachment *attachment in message.media)
        {
            if ([attachment isKindOfClass:[TGBridgeUnsupportedMediaAttachment class]])
            {
                unsupportedAttachment = (TGBridgeUnsupportedMediaAttachment *)attachment;
                break;
            }
        }
        
        NSString *title = unsupportedAttachment.title;
        NSString *subtitle = unsupportedAttachment.subtitle;
        
        _titleModel = [[TGNeoLabelViewModel alloc] initWithText:title font:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium] color:[self normalColorForMessage:message type:type] attributes:nil];
        _titleModel.multiline = false;
        [self addSubmodel:_titleModel];
        
        _subtitleModel = [[TGNeoLabelViewModel alloc] initWithText:subtitle font:[UIFont systemFontOfSize:12] color:[self subtitleColorForMessage:message type:type] attributes:nil];
        _subtitleModel.multiline = false;
        [self addSubmodel:_subtitleModel];
        
        _buttonTint = [self accentColorForMessage:message type:type];
        _iconTint = [self contrastAccentColorForMessage:message type:type];
    }
    return self;
}

- (CGSize)layoutWithContainerSize:(CGSize)containerSize
{
    CGSize contentContainerSize = [self contentContainerSizeWithContainerSize:containerSize];
    
    CGSize headerSize = [self layoutHeaderModelsWithContainerSize:contentContainerSize];
    CGFloat maxContentWidth = headerSize.width;
    CGFloat textTopOffset = headerSize.height;
    
    CGFloat leftOffset = 26 + TGNeoBubbleMessageMetaSpacing;
    
    UIEdgeInsets inset = UIEdgeInsetsMake(textTopOffset + 1.5f, TGNeoBubbleMessageViewModelInsets.left, 0, 0);
    NSDictionary *openButtonDictionary = _titleModel.text.length == 0 ? @{} : @{
        TGNeoMessageAudioIcon: @"RemotePhone",
        TGNeoMessageAudioIconTint: _iconTint,
        TGNeoMessageAudioBackgroundColor: _buttonTint,
        TGNeoMessageAudioButtonHasBackground: @true };
    
    if (openButtonDictionary.count > 0)
    {
        inset.left -= 4;
        leftOffset -= 5;
    }
    else
    {
        
    }
    
    contentContainerSize = CGSizeMake(containerSize.width - TGNeoBubbleMessageViewModelInsets.left - TGNeoBubbleMessageViewModelInsets.right - leftOffset, FLT_MAX);
    
    CGSize nameSize = [_titleModel contentSizeWithContainerSize:contentContainerSize];
    CGSize durationSize = [_subtitleModel contentSizeWithContainerSize:contentContainerSize];
    maxContentWidth = MAX(maxContentWidth, MAX(nameSize.width, durationSize.width) + leftOffset);
    
    _titleModel.frame = CGRectMake(TGNeoBubbleMessageViewModelInsets.left + leftOffset, textTopOffset, nameSize.width, 14);
    _subtitleModel.frame = CGRectMake(TGNeoBubbleMessageViewModelInsets.left + leftOffset, CGRectGetMaxY(_titleModel.frame), durationSize.width, 14);
    
    [self addAdditionalLayout:@{ TGNeoContentInset: [NSValue valueWithUIEdgeInsets:inset], TGNeoMessageAudioButton: openButtonDictionary } withKey:TGNeoMessageMetaGroup];
    
    CGSize contentSize = CGSizeMake(inset.left + TGNeoBubbleMessageViewModelInsets.right + maxContentWidth, CGRectGetMaxY(_subtitleModel.frame) + TGNeoBubbleMessageViewModelInsets.bottom);
    
    [super layoutWithContainerSize:contentSize];
    
    return contentSize;
}

@end
