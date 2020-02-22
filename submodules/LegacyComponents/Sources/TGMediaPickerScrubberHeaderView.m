#import "TGMediaPickerScrubberHeaderView.h"

@implementation TGMediaPickerScrubberHeaderView

- (void)setSafeAreaInset:(UIEdgeInsets)safeAreaInset
{
    _safeAreaInset = safeAreaInset;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    _scrubberView.frame = CGRectMake(_safeAreaInset.left, _scrubberView.frame.origin.y, self.frame.size.width - _safeAreaInset.left - _safeAreaInset.right, _scrubberView.frame.size.height);
}

@end
