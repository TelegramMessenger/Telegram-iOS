#import "TGModernGalleryZoomableScrollView.h"

#import "TGDoubleTapGestureRecognizer.h"

@interface TGModernGalleryZoomableScrollView () <TGDoubleTapGestureRecognizerDelegate>
{
    bool _hasDoubleTap;
}
@end

@implementation TGModernGalleryZoomableScrollView

- (instancetype)initWithFrame:(CGRect)frame hasDoubleTap:(bool)hasDoubleTap
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _hasDoubleTap = hasDoubleTap;
        if (hasDoubleTap) {
            TGDoubleTapGestureRecognizer *recognizer = [[TGDoubleTapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapGesture:)];
            recognizer.consumeSingleTap = true;
            [self addGestureRecognizer:recognizer];
        } else {
            self.panGestureRecognizer.minimumNumberOfTouches = 2;
        }
        
        _normalZoomScale = 1.0f;
    }
    return self;
}

- (void)setContentInset:(UIEdgeInsets)contentInset {
    if (_hasDoubleTap) {
        [super setContentInset:contentInset];
    } else {
        [super setContentInset:UIEdgeInsetsZero];
    }
}

- (UIEdgeInsets)adjustedContentInset {
    if (_hasDoubleTap) {
        return [super adjustedContentInset];
    } else {
        return UIEdgeInsetsZero;
    }
}

- (void)doubleTapGesture:(TGDoubleTapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        if (recognizer.doubleTapped)
        {
            if (_doubleTapped)
                _doubleTapped([recognizer locationInView:self]);
        }
        else
        {
            if (_singleTapped)
                _singleTapped();
        }
    }
}

- (void)doubleTapGestureRecognizerSingleTapped:(TGDoubleTapGestureRecognizer *)__unused recognizer
{
    if (_singleTapped)
        _singleTapped();
}

@end
