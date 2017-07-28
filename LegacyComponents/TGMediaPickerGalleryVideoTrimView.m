#import "TGMediaPickerGalleryVideoTrimView.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>

@interface TGMediaPickerGalleryVideoTrimView () <UIGestureRecognizerDelegate>
{
    UIControl *_leftSegmentView;
    UIView *_topSegmentView;
    UIControl *_rightSegmentView;
    UIView *_bottomSegmentView;

    UIView *_topShadowView;
    
    UIImageView *_leftHandleView;
    UIImageView *_rightHandleView;
    
    UILongPressGestureRecognizer *_startHandlePressGestureRecognizer;
    UILongPressGestureRecognizer *_endHandlePressGestureRecognizer;
    
    UIPanGestureRecognizer *_startHandlePanGestureRecognizer;
    UIPanGestureRecognizer *_endHandlePanGestureRecognizer;
    
    bool _beganInteraction;
    bool _endedInteraction;
    
    bool _isTracking;
}
@end

@implementation TGMediaPickerGalleryVideoTrimView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -25, -5, -25);
        
        UIColor *trimBackgroundColor = UIColorRGB(0x4d4d4d);
        
        _topShadowView = [[UIView alloc] initWithFrame:CGRectMake(12, 2, 0, 1)];
        _topShadowView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.3f];
        [self addSubview:_topShadowView];
        
        _leftSegmentView = [[UIControl alloc] initWithFrame:CGRectMake(0, 0, 12, 36)];
        _leftSegmentView.backgroundColor = trimBackgroundColor;
        _leftSegmentView.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -25, -5, -10);
        [self addSubview:_leftSegmentView];
        
        _topSegmentView = [[UIView alloc] initWithFrame:CGRectMake(12, 0, 0, 2)];
        _topSegmentView.backgroundColor = trimBackgroundColor;
        [self addSubview:_topSegmentView];
        
        _rightSegmentView = [[UIControl alloc] initWithFrame:CGRectMake(0, 0, 12, 36)];
        _rightSegmentView.backgroundColor = trimBackgroundColor;
        _rightSegmentView.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -10, -5, -25);
        [self addSubview:_rightSegmentView];
        
        _bottomSegmentView = [[UIView alloc] initWithFrame:CGRectMake(12, 0, 0, 2)];
        _bottomSegmentView.backgroundColor = trimBackgroundColor;
        [self addSubview:_bottomSegmentView];
        
        _leftHandleView = [[UIImageView alloc] initWithFrame:_leftSegmentView.bounds];
        _leftHandleView.contentMode = UIViewContentModeCenter;
        _leftHandleView.image = [UIImage imageNamed:@"VideoScrubberLeftArrow"];
        [_leftSegmentView addSubview:_leftHandleView];
        
        _rightHandleView = [[UIImageView alloc] initWithFrame:_rightSegmentView.bounds];
        _rightHandleView.contentMode = UIViewContentModeCenter;
        _rightHandleView.image = [UIImage imageNamed:@"VideoScrubberRightArrow"];
        [_rightSegmentView addSubview:_rightHandleView];
        
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
    
    _leftHandleView.hidden = !trimmingEnabled;
    _rightHandleView.hidden = !trimmingEnabled;
    
    [self setNeedsLayout];
}

- (void)setTrimming:(bool)trimming animated:(bool)animated
{
    UIColor *backgroundColor = trimming ? UIColorRGB(0x5cc0ff) : UIColorRGB(0x4d4d4d);
    
    if (animated)
    {
        [UIView animateWithDuration:0.15f animations:^
        {
            _leftSegmentView.backgroundColor = backgroundColor;
            _topSegmentView.backgroundColor = backgroundColor;
            _rightSegmentView.backgroundColor = backgroundColor;
            _bottomSegmentView.backgroundColor = backgroundColor;
        }];
    }
    else
    {
        _leftSegmentView.backgroundColor = backgroundColor;
        _topSegmentView.backgroundColor = backgroundColor;
        _rightSegmentView.backgroundColor = backgroundColor;
        _bottomSegmentView.backgroundColor = backgroundColor;
    }
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
                self.didEndEditing();
            
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
                self.didEndEditing();
            
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
    CGFloat handleWidth = self.trimmingEnabled ? 12.0f : 2.0f;
    
    _leftSegmentView.frame = CGRectMake(0, 0, handleWidth, self.frame.size.height);
    _rightSegmentView.frame = CGRectMake(self.frame.size.width - handleWidth, 0, handleWidth, self.frame.size.height);
 
    _topSegmentView.frame = CGRectMake(_leftSegmentView.frame.size.width, 0, self.frame.size.width - _leftSegmentView.frame.size.width - _rightSegmentView.frame.size.width, 2);
    _bottomSegmentView.frame = CGRectMake(_leftSegmentView.frame.size.width, self.frame.size.height - _bottomSegmentView.frame.size.height, self.frame.size.width - _leftSegmentView.frame.size.width - _rightSegmentView.frame.size.width, 2);
    _topShadowView.frame = CGRectMake(_topSegmentView.frame.origin.x, _topSegmentView.frame.size.height, _topSegmentView.frame.size.width, _topShadowView.frame.size.height);
}

@end
