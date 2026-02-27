#import "TGNeoVenueMessageViewModel.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGNeoImageViewModel.h"

@interface TGNeoVenueMessageViewModel ()
{
    TGNeoImageViewModel *_iconModel;
    TGNeoLabelViewModel *_nameModel;
    TGNeoLabelViewModel *_addressModel;
}
@end

@implementation TGNeoVenueMessageViewModel

- (instancetype)initWithMessage:(TGBridgeMessage *)message type:(TGNeoMessageType)type users:(NSDictionary *)users context:(TGBridgeContext *)context
{
    self = [super initWithMessage:message type:type users:users context:context];
    if (self != nil)
    {
        TGBridgeLocationMediaAttachment *locationAttachment = nil;
        for (TGBridgeMediaAttachment *attachment in message.media)
        {
            if ([attachment isKindOfClass:[TGBridgeLocationMediaAttachment class]])
            {
                locationAttachment = (TGBridgeLocationMediaAttachment *)attachment;
                break;
            }
        }
        
        _iconModel = [[TGNeoImageViewModel alloc] initWithImage:[UIImage imageNamed:@"Location"] tintColor:[self accentColorForMessage:message type:type]];
        [self addSubmodel:_iconModel];
        
        TGBridgeVenueAttachment *venue = locationAttachment.venue;
        
        _nameModel = [[TGNeoLabelViewModel alloc] initWithText:venue.title font:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium] color:[self normalColorForMessage:message type:type] attributes:nil];
        _nameModel.multiline = false;
        [self addSubmodel:_nameModel];
        
        _addressModel = [[TGNeoLabelViewModel alloc] initWithText:venue.address font:[UIFont systemFontOfSize:12] color:[self subtitleColorForMessage:message type:type] attributes:nil];
        _addressModel.multiline = false;
        [self addSubmodel:_addressModel];
    }
    return self;
}

- (CGSize)layoutWithContainerSize:(CGSize)containerSize
{
    CGSize contentContainerSize = [self contentContainerSizeWithContainerSize:containerSize];
    
    CGSize headerSize = [self layoutHeaderModelsWithContainerSize:contentContainerSize];
    CGFloat maxContentWidth = headerSize.width;
    CGFloat textTopOffset = headerSize.height;
    
    CGFloat leftOffset = 20 + TGNeoBubbleMessageMetaSpacing;
    contentContainerSize = CGSizeMake(containerSize.width - TGNeoBubbleMessageViewModelInsets.left - TGNeoBubbleMessageViewModelInsets.right - leftOffset, FLT_MAX);
    
    CGSize nameSize = [_nameModel contentSizeWithContainerSize:contentContainerSize];
    CGSize addressSize = [_addressModel contentSizeWithContainerSize:contentContainerSize];
    maxContentWidth = MAX(maxContentWidth, MAX(nameSize.width, addressSize.width) + leftOffset);
    
    _iconModel.frame = CGRectMake(TGNeoBubbleMessageViewModelInsets.left - 3, textTopOffset + 1.5f, 26, 26);
    _nameModel.frame = CGRectMake(TGNeoBubbleMessageViewModelInsets.left + leftOffset, textTopOffset, nameSize.width, 14);
    _addressModel.frame = CGRectMake(TGNeoBubbleMessageViewModelInsets.left + leftOffset, CGRectGetMaxY(_nameModel.frame), addressSize.width, 14);
    
    CGSize contentSize =  CGSizeMake(TGNeoBubbleMessageViewModelInsets.left + TGNeoBubbleMessageViewModelInsets.right + maxContentWidth, CGRectGetMaxY(_addressModel.frame) + TGNeoBubbleMessageViewModelInsets.bottom);
    
    [super layoutWithContainerSize:contentSize];
    
    return contentSize;
}

@end
