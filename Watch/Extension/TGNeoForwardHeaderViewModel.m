#import "TGNeoForwardHeaderViewModel.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"
#import "TGNeoLabelViewModel.h"

const CGFloat TGNeoForwardHeaderHeight = 29;

@interface TGNeoForwardHeaderViewModel ()
{
    TGNeoLabelViewModel *_forwardedModel;
    TGNeoLabelViewModel *_authorNameModel;
}
@end

@implementation TGNeoForwardHeaderViewModel

- (instancetype)initWithOutgoing:(bool)outgoing
{
    self = [super init];
    if (self != nil)
    {
        _forwardedModel = [[TGNeoLabelViewModel alloc] initWithText:TGLocalized(@"Watch.Message.ForwardedFrom") font:[UIFont systemFontOfSize:12] color:[self subtitleColorForOutgoing:outgoing] attributes:nil];
        _forwardedModel.multiline = false;
        [self addSubmodel:_forwardedModel];
    }
    return self;
}

- (instancetype)initWithForwardAttachment:(TGBridgeForwardedMessageMediaAttachment *)attachment user:(TGBridgeUser *)user outgoing:(bool)outgoing
{
    self = [self initWithOutgoing:outgoing];
    if (self != nil)
    {
        _authorNameModel = [[TGNeoLabelViewModel alloc] initWithText:[user displayName] font:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium] color:[self normalColorForOutgoing:outgoing] attributes:nil];
        _authorNameModel.multiline = false;
        [self addSubmodel:_authorNameModel];
    }
    return self;
}

- (instancetype)initWithForwardAttachment:(TGBridgeForwardedMessageMediaAttachment *)attachment chat:(TGBridgeChat *)chat outgoing:(bool)outgoing
{
    self = [self initWithOutgoing:outgoing];
    if (self != nil)
    {
        _authorNameModel = [[TGNeoLabelViewModel alloc] initWithText:chat.groupTitle font:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium] color:[self normalColorForOutgoing:outgoing] attributes:nil];
        _authorNameModel.multiline = false;
        [self addSubmodel:_authorNameModel];
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

- (UIColor *)subtitleColorForOutgoing:(bool)outgoing
{
    if (outgoing)
        return [UIColor whiteColor];
    else
        return [UIColor blackColor];
}

- (CGSize)contentSizeWithContainerSize:(CGSize)containerSize
{
    CGSize forwardedSize = [_forwardedModel contentSizeWithContainerSize:containerSize];
    CGSize nameSize = [_authorNameModel contentSizeWithContainerSize:containerSize];
    
    return CGSizeMake(MIN(MAX(forwardedSize.width, nameSize.width), containerSize.width), TGNeoForwardHeaderHeight);
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    _forwardedModel.frame = CGRectMake(0, 0, frame.size.width, 20);
    _authorNameModel.frame = CGRectMake(0, 14.5f, frame.size.width, 20);
}

@end
