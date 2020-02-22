#import "TGModernGalleryZoomableScrollView.h"

#import "TGDoubleTapGestureRecognizer.h"

@interface TGModernGalleryZoomableScrollView () <TGDoubleTapGestureRecognizerDelegate>

@end

@implementation TGModernGalleryZoomableScrollView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        TGDoubleTapGestureRecognizer *recognizer = [[TGDoubleTapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapGesture:)];
        recognizer.consumeSingleTap = true;
        [self addGestureRecognizer:recognizer];
        
        _normalZoomScale = 1.0f;
    }
    return self;
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
