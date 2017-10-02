#import "TGLocationMapView.h"

@interface TGLocationMapView () <UIGestureRecognizerDelegate>
{
    UITapGestureRecognizer *_tapGestureRecognizer;
    UILongPressGestureRecognizer *_longPressGestureRecognizer;
}
@end

@implementation TGLocationMapView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _manipulationEnabled = true;
        _allowAnnotationSelectionChanges = true;
        
        _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tg_handleTap:)];
        _tapGestureRecognizer.numberOfTapsRequired = 1;
        _tapGestureRecognizer.numberOfTouchesRequired = 1;
        [self addGestureRecognizer:_tapGestureRecognizer];
        
        _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(tg_handleLongPress:)];
        _longPressGestureRecognizer.enabled = false;
        _longPressGestureRecognizer.minimumPressDuration = 0.2f;
        [self addGestureRecognizer:_longPressGestureRecognizer];
    }
    return self;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    NSString *viewClass = NSStringFromClass([gestureRecognizer.view class]);
    if ([viewClass rangeOfString:@"Compass"].location != NSNotFound)
        return true;
    
    if (self.customAnnotationTap && self.customAnnotationTap([gestureRecognizer locationInView:self]))
        return false;
    
    return self.allowAnnotationSelectionChanges;
}

- (bool)tapEnabled
{
    return _tapGestureRecognizer.enabled;
}

- (void)setTapEnabled:(bool)enabled
{
    _tapGestureRecognizer.enabled = enabled;
}

- (bool)longPressAsTapEnabled
{
    return _longPressGestureRecognizer.enabled;
}

- (void)setLongPressAsTapEnabled:(bool)enabled
{
    _longPressGestureRecognizer.enabled = enabled;
}

- (void)tg_handleTap:(UITapGestureRecognizer *)__unused gestureRecognizer
{
    if (self.singleTap != nil)
        self.singleTap();
}

- (void)tg_handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan)
    {
        if (self.singleTap != nil)
            self.singleTap();
    }
}

- (void)setManipulationEnabled:(bool)enabled
{
    _manipulationEnabled = enabled;
    
    self.scrollEnabled = enabled;
    self.zoomEnabled = enabled;
    if ([self respondsToSelector:@selector(setRotateEnabled:)])
        self.rotateEnabled = enabled;
    if ([self respondsToSelector:@selector(setPitchEnabled:)])
        self.pitchEnabled = enabled;
}

- (void)setCompassInsets:(UIEdgeInsets)compassInsets
{
    _compassInsets = compassInsets;
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (UIEdgeInsetsEqualToEdgeInsets(self.compassInsets, UIEdgeInsetsZero))
        return;
    
    for (UIView *view in self.subviews)
    {
        if ([NSStringFromClass([view class]) rangeOfString:@"Compass"].location != NSNotFound)
        {
            view.frame = CGRectMake(self.frame.size.width - self.compassInsets.right - view.frame.size.width, self.compassInsets.top, view.frame.size.width, view.frame.size.height);
        }
    }
}

@end
