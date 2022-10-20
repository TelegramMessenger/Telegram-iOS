#import "TGAttachmentGifCell.h"

#import <LegacyComponents/LegacyComponents.h>

NSString *const TGAttachmentGifCellIdentifier = @"AttachmentGifCell";

@implementation TGAttachmentGifCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _typeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _typeLabel.backgroundColor = [UIColor clearColor];
        _typeLabel.font = TGBoldSystemFontOfSize(13);
        _typeLabel.textColor = [UIColor whiteColor];
        _typeLabel.text = @"GIF";
        [self addSubview:_typeLabel];
        
        [_typeLabel sizeToFit];
        
        _gradientView.hidden = false;
        
        [self bringSubviewToFront:_cornersView];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize typeSize = _typeLabel.frame.size;
    _typeLabel.frame = CGRectMake(self.frame.size.width - typeSize.width - 3.0, self.frame.size.height - typeSize.height - 1.0, typeSize.width, typeSize.height);
}

@end
