#import "TGItemPreviewView.h"

#import "LegacyComponentsInternal.h"

@interface TGItemPreviewView ()
{
    bool _disappearing;
}
@end

@implementation TGItemPreviewView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _dimView = [[UIView alloc] init];
        _dimView.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.7f];
        _dimView.alpha = 0.0f;
        [self addSubview:_dimView];
        
        _wrapperView = [[UIView alloc] init];
        _wrapperView.alpha = 0.0f;
        [self addSubview:_wrapperView];
    }
    return self;
}

- (void)animateAppear
{
    _wrapperView.frame = self.bounds;
    
    CGPoint transitionInPoint = CGPointZero;
    if (self.sourcePointForItem != nil)
        transitionInPoint = self.sourcePointForItem(self.item);
    
    bool animatedCenter = false;
    if (!CGPointEqualToPoint(transitionInPoint, CGPointZero))
    {
        _wrapperView.center = transitionInPoint;
        animatedCenter = true;
    }
    
    _dimView.alpha = 0.0f;
    _wrapperView.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
    
    void (^changeBlock)(void) = ^
    {
        _dimView.alpha = 1.0f;
        _wrapperView.alpha = 1.0f;
        _wrapperView.transform = CGAffineTransformIdentity;
        
        if (animatedCenter)
            _wrapperView.center = [self _wrapperViewContainerCenter];
    };
    
    void (^completionBlock)(BOOL) = ^(__unused BOOL finished)
    {
        if (finished && !_disappearing)
            [self _didAppear];
    };
    
    if (iosMajorVersion() < 8)
    {
        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:changeBlock completion:completionBlock];
    }
    else
    {
        [UIView animateWithDuration:0.5 delay:0.0 usingSpringWithDamping:0.72f initialSpringVelocity:0.0f options:0 animations:changeBlock completion:completionBlock];
    }
}

- (void)animateDismiss:(void (^)())completion
{
    CGPoint transitionOutPoint = CGPointZero;
    if (self.sourcePointForItem != nil)
        transitionOutPoint = self.sourcePointForItem(self.item);
    
    [self _willDisappear];
    
    _disappearing = true;
    
    [UIView animateWithDuration:0.2 animations:^
    {
        _dimView.alpha = 0.0f;
        _wrapperView.transform = CGAffineTransformMakeScale(0.3f, 0.3f);
        _wrapperView.alpha = 0.0f;
        
        if (!CGPointEqualToPoint(transitionOutPoint, CGPointZero))
            _wrapperView.center = transitionOutPoint;
     } completion:^(__unused BOOL finished)
     {
         if (completion)
             completion();
     }];
}

- (void)_didAppear
{
    
}

- (void)_willDisappear
{
    
}

- (CGPoint)_wrapperViewContainerCenter
{
    CGRect bounds = self.bounds;
    
    CGFloat y = bounds.size.height / 2.0f;
    if (bounds.size.height > bounds.size.width && self.eccentric)
        y = bounds.size.height / 3.0f;
    
    return CGPointMake(bounds.size.width / 2.0f, y);
}

- (void)_handlePanOffset:(CGFloat)__unused offset
{
    
}

- (void)_handlePressEnded
{
    
}

- (bool)_maybeLockWithVelocity:(CGFloat)__unused velocity
{
    return false;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect previousBounds = _dimView.bounds;
    if (!CGRectEqualToRect(self.bounds, previousBounds))
    {
        _dimView.frame = self.bounds;
        _wrapperView.center = [self _wrapperViewContainerCenter];
    }
}

@end
