#import "TGNeoSmiliesMessageViewModel.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGNeoBubbleMessageViewModel.h"
#import "TGNeoLabelViewModel.h"

#import "TGWatchColor.h"

const CGFloat TGNeoSmiliesMessageHeight = 39;

@interface TGNeoSmiliesMessageViewModel ()
{
    TGNeoLabelViewModel *_authorNameModel;
    TGNeoLabelViewModel *_textModel;
    bool _outgoing;
}
@end

@implementation TGNeoSmiliesMessageViewModel

- (instancetype)initWithMessage:(TGBridgeMessage *)message type:(TGNeoMessageType)type users:(NSDictionary *)users context:(TGBridgeContext *)context
{
    self = [super initWithMessage:message type:type users:users context:context];
    if (self != nil)
    {
        _outgoing = message.outgoing;
        
        if (message.cid < 0 && type != TGNeoMessageTypeChannel && !message.outgoing)
        {
            _authorNameModel = [[TGNeoLabelViewModel alloc] initWithText:[users[@(message.fromUid)] displayName] font:[UIFont systemFontOfSize:14] color:[TGColor colorForUserId:(int32_t)message.fromUid myUserId:context.userId] attributes:nil];
            [self addSubmodel:_authorNameModel];
        }
        
        _textModel = [[TGNeoLabelViewModel alloc] initWithText:message.text font:[UIFont systemFontOfSize:35] color:[UIColor whiteColor] attributes:nil];
        _textModel.multiline = false;
        [self addSubmodel:_textModel];
    }
    return self;
}

- (void)drawInContext:(CGContextRef)context
{
    CGContextSetFillColorWithColor(context, [UIColor grayColor].CGColor);
    CGContextFillRect(context, self.bounds);
    
    [super drawInContext:context];
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
    
    CGSize size = [_textModel contentSizeWithContainerSize:containerSize];
    CGFloat inset = 0; //TGNeoBubbleMessageViewModelInsets.left
    if (_outgoing)
        size.width += inset;
    
    _textModel.frame = CGRectMake(_outgoing ? 0 : inset, textTopOffset, size.width, size.height);
    
    self.contentSize = CGSizeMake(MAX(CGRectGetMaxX(_authorNameModel.frame), size.width), TGNeoSmiliesMessageHeight + textTopOffset);
    
    return self.contentSize;
}

@end
