#import "TGModernGalleryZoomableScrollViewSwipeGestureRecognizer.h"

#import <UIKit/UIGestureRecognizerSubclass.h>

@interface TGModernGalleryZoomableScrollViewSwipeGestureRecognizer ()
{
    CGPoint _touchStartLocation;
    CGPoint _gestureStartLocation;
    CGFloat _swipeDistance;
    CGFloat _swipeVelocity;
    bool _recognizingGesture;
}

@end

@implementation TGModernGalleryZoomableScrollViewSwipeGestureRecognizer

- (CGFloat)swipeDistance
{
    return _swipeDistance;
}

- (CGFloat)swipeVelocity
{
    return _swipeVelocity;
}

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if (self != nil)
    {
        self.maximumNumberOfTouches = 1;
    }
    return self;
}

- (void)reset
{
    [super reset];
    
    _swipeDistance = 0.0f;
    _swipeVelocity = 0.0f;
    _recognizingGesture = false;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)__unused event
{
    [super touchesBegan:touches withEvent:event];
    
    if (touches.count != 1 || self.state != UIGestureRecognizerStatePossible)
        [self _failGesture];
    else
    {
        UITouch *touch = [touches anyObject];
        _touchStartLocation = [touch locationInView:self.view];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)__unused event
{
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInView:self.view];
    
    if (_recognizingGesture)
    {
        _swipeDistance = touchLocation.y - _gestureStartLocation.y;
        [self _updateGesture];
        
        [super touchesMoved:touches withEvent:event];
    }
    else if (ABS(touchLocation.y - _touchStartLocation.y) > 12.0f)
    {
        _gestureStartLocation = touchLocation;
        _recognizingGesture = true;
    }
    else if (ABS(touchLocation.x - _touchStartLocation.x) > 10.0f)
        [self _failGesture];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    
    [self _failGesture];
}

- (void)touchesEnded:(NSSet *)__unused touches withEvent:(UIEvent *)__unused event
{
    //TGLegacyLog(@"touches ended");
    
    _swipeVelocity = [self velocityInView:self.view].y;
    
    [super touchesEnded:touches withEvent:event];
    
    [self _completeGesture];
}

- (void)_failGesture
{
    self.state = UIGestureRecognizerStateCancelled;
}

- (void)_updateGesture
{
    self.state = UIGestureRecognizerStateChanged;
}

- (void)_completeGesture
{
    self.state = UIGestureRecognizerStateEnded;
}

@end
