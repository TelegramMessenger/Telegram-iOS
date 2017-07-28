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
        _typeLabel.font = TGSystemFontOfSize(12);
        _typeLabel.textColor = [UIColor whiteColor];
        _typeLabel.text = @"GIF";
        [self addSubview:_typeLabel];
        
        [_typeLabel sizeToFit];
        
        CGSize typeSize = CGSizeMake(ceil(_typeLabel.frame.size.width), ceil(_typeLabel.frame.size.height));
        _typeLabel.frame = CGRectMake(4, self.frame.size.height - typeSize.height - 2, typeSize.width, typeSize.height);
        
        _gradientView.hidden = false;
        
        [self bringSubviewToFront:_cornersView];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _typeLabel.frame = CGRectMake(4, self.frame.size.height - _typeLabel.frame.size.height - 2, _typeLabel.frame.size.width, _typeLabel.frame.size.height);
}

@end
