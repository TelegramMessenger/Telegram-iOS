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
    
    _coverScrubberView.frame = CGRectMake(_safeAreaInset.left, _scrubberView.frame.origin.y + 16.0, self.frame.size.width - _safeAreaInset.left - _safeAreaInset.right, _scrubberView.frame.size.height);
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    CGRect bounds = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height + 16.0);
    return CGRectContainsPoint(bounds, point);
}

@end
