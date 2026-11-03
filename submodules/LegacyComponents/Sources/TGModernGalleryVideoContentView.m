#import "TGModernGalleryVideoContentView.h"

@implementation TGModernGalleryVideoContentView

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    CGAffineTransform transform = _button.transform;
    _button.transform = CGAffineTransformIdentity;
    _button.frame = (CGRect){{((frame.size.width - _button.frame.size.width) / 2.0f), ((frame.size.height - _button.frame.size.height) / 2.0f)}, _button.frame.size};
    _button.transform = transform;
}

@end
