#import "TGNeoReplyHeaderViewModel.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import "TGNeoLabelViewModel.h"
#import "TGNeoAttachmentViewModel.h"

const CGFloat TGNeoReplyHeaderHeight = 29.0f;
const CGFloat TGNeoReplyHeaderLineWidth = 2.0f;
const CGFloat TGNeoReplyHeaderSpacing = 4.0f;
const CGFloat TGNeoReplyHeaderImageWidth = 26.0f;

@interface TGNeoReplyHeaderViewModel ()
{
    TGNeoLabelViewModel *_authorNameModel;
    TGNeoLabelViewModel *_textNameModel;
    TGNeoAttachmentViewModel *_attachmentModel;
    
    bool _outgoing;
}
@end

@implementation TGNeoReplyHeaderViewModel

- (instancetype)initWithReplyAttachment:(TGBridgeReplyMessageMediaAttachment *)attachment users:(NSDictionary *)users outgoing:(bool)outgoing
{
    self = [super init];
    if (self != nil)
    {
        _outgoing = outgoing;
        _replyMessage = attachment.message;
        
        NSString *name = nil;
        id peer = users[@(attachment.message.fromUid)];
        if ([peer isKindOfClass:[TGBridgeUser class]])
            name = [peer displayName];
        else if ([peer isKindOfClass:[TGBridgeChat class]])
            name = [peer groupTitle];
        
        _authorNameModel = [[TGNeoLabelViewModel alloc] initWithText:name font:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium] color:[self normalColorForOutgoing:outgoing] attributes:nil];
        _authorNameModel.multiline = false;
        [self addSubmodel:_authorNameModel];
        
        _attachmentModel = [[TGNeoAttachmentViewModel alloc] initWithAttachments:attachment.message.media author:nil forChannel:false users:nil font:[UIFont systemFontOfSize:12] subTitleColor:[self subtitleColorForOutgoing:outgoing] normalColor:[self textColorForOutgoing:outgoing] compact:true caption:attachment.message.text];
        
        for (TGBridgeMediaAttachment *media in attachment.message.media)
        {
            if ([media isKindOfClass:[TGBridgeImageMediaAttachment class]]
                || [media isKindOfClass:[TGBridgeVideoMediaAttachment class]])
            {
                _mediaAttachment = media;
            }
        }
        
        if (_attachmentModel != nil)
        {
            [self addSubmodel:_attachmentModel];
        }
        else
        {
            _textNameModel = [[TGNeoLabelViewModel alloc] initWithText:attachment.message.text font:[UIFont systemFontOfSize:12] color:[self textColorForOutgoing:outgoing] attributes:nil];
            _textNameModel.multiline = false;
            [self addSubmodel:_textNameModel];
        }
    }
    return self;
}

- (UIColor *)normalColorForOutgoing:(bool)outgoing
{
    if (outgoing)
        return [UIColor whiteColor];
    else
        return [UIColor hexColor:0x1f97f8];
}

- (UIColor *)textColorForOutgoing:(bool)outgoing
{
    if (outgoing)
        return [UIColor whiteColor];
    else
        return [UIColor blackColor];
}

- (UIColor *)subtitleColorForOutgoing:(bool)outgoing
{
    if (outgoing)
        return [UIColor hexColor:0xbeddf6];
    else
        return [UIColor hexColor:0x7e7e81];
}

- (CGSize)contentSizeWithContainerSize:(CGSize)containerSize
{
    CGSize nameSize = [_authorNameModel contentSizeWithContainerSize:containerSize];
    CGSize textSize = [_textNameModel contentSizeWithContainerSize:containerSize];
    
    CGFloat maxWidth = MAX(textSize.width, nameSize.width);
    maxWidth += TGNeoReplyHeaderLineWidth + TGNeoReplyHeaderSpacing;
    
    if (_mediaAttachment != nil)
        maxWidth += TGNeoReplyHeaderImageWidth + TGNeoReplyHeaderSpacing;
    
    return CGSizeMake(MIN(maxWidth, containerSize.width), TGNeoReplyHeaderHeight);
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    CGFloat xOffset = TGNeoReplyHeaderLineWidth + TGNeoReplyHeaderSpacing;
    if (_mediaAttachment != nil)
        xOffset += TGNeoReplyHeaderImageWidth + TGNeoReplyHeaderSpacing;
    
    _authorNameModel.frame = CGRectMake(xOffset, 0, frame.size.width - xOffset, 20);
    _textNameModel.frame = CGRectMake(xOffset, 14.5f, frame.size.width - xOffset, 20);
    _attachmentModel.frame = CGRectMake(xOffset, 14.5f, frame.size.width - xOffset, 20);
}

- (void)drawInContext:(CGContextRef)context
{
    [super drawInContext:context];
    
    CGContextSetFillColorWithColor(context, [self normalColorForOutgoing:_outgoing].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, TGNeoReplyHeaderLineWidth, self.frame.size.height));
}

@end
