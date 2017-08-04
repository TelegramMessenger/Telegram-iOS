#import "TGLocationMapView.h"

@interface TGLocationMapView ()
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

@end
