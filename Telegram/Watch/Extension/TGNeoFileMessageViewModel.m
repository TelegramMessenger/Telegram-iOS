#import "TGNeoFileMessageViewModel.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGNeoImageViewModel.h"

#import "TGStringUtils.h"

@interface TGNeoFileMessageViewModel ()
{
    TGNeoImageViewModel *_iconModel;
    TGNeoLabelViewModel *_nameModel;
    TGNeoLabelViewModel *_sizeModel;
}
@end

@implementation TGNeoFileMessageViewModel

- (instancetype)initWithMessage:(TGBridgeMessage *)message type:(TGNeoMessageType)type users:(NSDictionary *)users context:(TGBridgeContext *)context
{
    self = [super initWithMessage:message type:type users:users context:context];
    if (self != nil)
    {
        TGBridgeDocumentMediaAttachment *documentAttachment = nil;
        for (TGBridgeMediaAttachment *attachment in message.media)
        {
            if ([attachment isKindOfClass:[TGBridgeDocumentMediaAttachment class]])
            {
                documentAttachment = (TGBridgeDocumentMediaAttachment *)attachment;
                break;
            }
        }
                
        _iconModel = [[TGNeoImageViewModel alloc] initWithImage:[UIImage imageNamed:@"File"] tintColor:[self accentColorForMessage:message type:type]];
        [self addSubmodel:_iconModel];
        
        _nameModel = [[TGNeoLabelViewModel alloc] initWithText:documentAttachment.fileName font:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium] color:[self normalColorForMessage:message type:type] attributes:nil];
        _nameModel.multiline = false;
        [self addSubmodel:_nameModel];
        
        _sizeModel = [[TGNeoLabelViewModel alloc] initWithText:[TGStringUtils stringForFileSize:documentAttachment.fileSize precision:2] font:[UIFont systemFontOfSize:12] color:[self subtitleColorForMessage:message type:type] attributes:nil];
        _sizeModel.multiline = false;
        [self addSubmodel:_sizeModel];
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
    CGSize metaSize = [_sizeModel contentSizeWithContainerSize:contentContainerSize];
    maxContentWidth = MAX(maxContentWidth, MAX(nameSize.width, metaSize.width) + leftOffset);
    
    _iconModel.frame = CGRectMake(TGNeoBubbleMessageViewModelInsets.left - 3, textTopOffset + 1.5f, 26, 26);
    _nameModel.frame = CGRectMake(TGNeoBubbleMessageViewModelInsets.left + leftOffset, textTopOffset, nameSize.width, 14);
    _sizeModel.frame = CGRectMake(TGNeoBubbleMessageViewModelInsets.left + leftOffset, CGRectGetMaxY(_nameModel.frame), metaSize.width, 14);
    
    CGSize contentSize =  CGSizeMake(TGNeoBubbleMessageViewModelInsets.left + TGNeoBubbleMessageViewModelInsets.right + maxContentWidth, CGRectGetMaxY(_sizeModel.frame) + TGNeoBubbleMessageViewModelInsets.bottom);
    
    [super layoutWithContainerSize:contentSize];
    
    return contentSize;
}

@end
