#import "TGPhotoCropControl.h"

#import "LegacyComponentsInternal.h"

@interface TGPhotoCropControl () <UIGestureRecognizerDelegate>
{
    UIPanGestureRecognizer *_panGestureRecognizer;
    UILongPressGestureRecognizer *_pressGestureRecognizer;
    
    bool _beganInteraction;
    bool _endedInteraction;
}
@end

@implementation TGPhotoCropControl

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.exclusiveTouch = YES;
        
        _pressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handlePress:)];
        _pressGestureRecognizer.delegate = self;
        _pressGestureRecognizer.minimumPressDuration = 0.1f;
        [self addGestureRecognizer:_pressGestureRecognizer];
        
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _panGestureRecognizer.delegate = self;
        [self addGestureRecognizer:_panGestureRecognizer];
    }
    return self;
}

- (void)handlePress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            if (_beganInteraction)
                return;
            
            if (self.didBeginResizing != nil)
                self.didBeginResizing(self);
            
            _endedInteraction = false;
            _beganInteraction = true;
        }
            break;

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            _beganInteraction = false;
            
            if (_endedInteraction)
                return;
            
            if (self.didEndResizing != nil)
                self.didEndResizing(self);
            
            _endedInteraction = true;
        }
            break;

            
        default:
            break;
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    CGPoint translation = [gestureRecognizer translationInView:self.superview];
    translation = CGPointMake(CGRound(translation.x), translation.y);
    
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            if (_beganInteraction)
                return;
            
            if (self.didBeginResizing != nil)
                self.didBeginResizing(self);
            
            _endedInteraction = false;
            _beganInteraction = true;
        }
        case UIGestureRecognizerStateChanged:
        {
            if (self.didResize != nil)
                self.didResize(self, translation);
            
            [gestureRecognizer setTranslation:CGPointZero inView:self.superview];
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            _beganInteraction = false;
            
            if (_endedInteraction)
                return;
            
            if (self.didEndResizing != nil)
                self.didEndResizing(self);
            
            _endedInteraction = true;
        }
            break;
        
        default:
            break;
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)__unused gestureRecognizer
{
    if (self.shouldBeginResizing != nil)
        return self.shouldBeginResizing(self);
    
    return true;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)__unused gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)__unused otherGestureRecognizer
{
    return true;
}

@end
