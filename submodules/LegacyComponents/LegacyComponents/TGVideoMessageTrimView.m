#import "TGVideoMessageTrimView.h"

#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>
#import "LegacyComponentsInternal.h"

@interface TGVideoMessageTrimView () <UIGestureRecognizerDelegate>
{
    UIButton *_leftSegmentView;
    UIButton *_rightSegmentView;
    
    UILongPressGestureRecognizer *_startHandlePressGestureRecognizer;
    UILongPressGestureRecognizer *_endHandlePressGestureRecognizer;
    
    UIPanGestureRecognizer *_startHandlePanGestureRecognizer;
    UIPanGestureRecognizer *_endHandlePanGestureRecognizer;
    
    bool _beganInteraction;
    bool _endedInteraction;
    
    bool _isTracking;
}
@end

@implementation TGVideoMessageTrimView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -25, -5, -25);
        
        _leftSegmentView = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 16, 33)];
        _leftSegmentView.exclusiveTouch = true;
        _leftSegmentView.adjustsImageWhenHighlighted = false;
        [_leftSegmentView setBackgroundImage:TGComponentsImageNamed(@"VideoMessageLeftHandle") forState:UIControlStateNormal];
        _leftSegmentView.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -25, -5, -10);
        [self addSubview:_leftSegmentView];
        
        _rightSegmentView = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 16, 33)];
        _rightSegmentView.exclusiveTouch = true;
        _rightSegmentView.adjustsImageWhenHighlighted = false;
        [_rightSegmentView setBackgroundImage:TGComponentsImageNamed(@"VideoMessageRightHandle") forState:UIControlStateNormal];
        _rightSegmentView.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -10, -5, -25);
        [self addSubview:_rightSegmentView];
        
        _startHandlePressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleHandlePress:)];
        _startHandlePressGestureRecognizer.delegate = self;
        _startHandlePressGestureRecognizer.minimumPressDuration = 0.1f;
        [_leftSegmentView addGestureRecognizer:_startHandlePressGestureRecognizer];
        
        _endHandlePressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleHandlePress:)];
        _endHandlePressGestureRecognizer.delegate = self;
        _endHandlePressGestureRecognizer.minimumPressDuration = 0.1f;
        [_rightSegmentView addGestureRecognizer:_endHandlePressGestureRecognizer];
        
        _startHandlePanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleHandlePan:)];
        _startHandlePanGestureRecognizer.delegate = self;
        [_leftSegmentView addGestureRecognizer:_startHandlePanGestureRecognizer];
        
        _endHandlePanGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleHandlePan:)];
        _endHandlePanGestureRecognizer.delegate = self;
        [_rightSegmentView addGestureRecognizer:_endHandlePanGestureRecognizer];
    }
    return self;
}

- (void)setTrimmingEnabled:(bool)trimmingEnabled
{
    _trimmingEnabled = trimmingEnabled;
    
    _leftSegmentView.userInteractionEnabled = trimmingEnabled;
    _rightSegmentView.userInteractionEnabled = trimmingEnabled;

    [self setNeedsLayout];
}

- (void)setLeftHandleImage:(UIImage *)leftHandleImage rightHandleImage:(UIImage *)rightHandleImage
{
    [_leftSegmentView setBackgroundImage:leftHandleImage forState:UIControlStateNormal];
    [_rightSegmentView setBackgroundImage:rightHandleImage forState:UIControlStateNormal];
}

- (void)setTrimming:(bool)__unused trimming animated:(bool)__unused animated
{
}

- (void)handleHandlePress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            if (_beganInteraction)
                return;
            
            _isTracking = true;
            
            if (self.didBeginEditing != nil)
                self.didBeginEditing(gestureRecognizer.view == _leftSegmentView);
            
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
            
            _isTracking = false;
            
            if (self.didEndEditing != nil)
                self.didEndEditing(gestureRecognizer.view == _leftSegmentView);
            
            _endedInteraction = true;
        }
            break;
            
        default:
            break;
    }
}

- (void)handleHandlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    CGPoint translation = [gestureRecognizer translationInView:self];
    [gestureRecognizer setTranslation:CGPointZero inView:self];
    
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            if (_beganInteraction)
                return;
            
            _isTracking = true;
            
            if (self.didBeginEditing != nil)
                self.didBeginEditing(gestureRecognizer.view == _leftSegmentView);
            
            _endedInteraction = false;
            _beganInteraction = true;
        }
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            if (gestureRecognizer == _startHandlePanGestureRecognizer && self.startHandleMoved != nil)
                self.startHandleMoved(translation);
            else if (gestureRecognizer == _endHandlePanGestureRecognizer && self.endHandleMoved != nil)
                self.endHandleMoved(translation);
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            _beganInteraction = false;
            
            if (_endedInteraction)
                return;
            
            _isTracking = false;
            
            if (self.didEndEditing != nil)
                self.didEndEditing(gestureRecognizer.view == _leftSegmentView);
            
            _endedInteraction = true;
        }
            break;
            
        default:
            break;
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer.view != otherGestureRecognizer.view)
        return false;
    
    return true;
}

- (void)layoutSubviews
{
    CGFloat handleWidth = self.trimmingEnabled ? 16.0f : 2.0f;
    
    _leftSegmentView.frame = CGRectMake(0, 0, handleWidth, self.frame.size.height);
    _rightSegmentView.frame = CGRectMake(self.frame.size.width - handleWidth, 0, handleWidth, self.frame.size.height);
}

@end
