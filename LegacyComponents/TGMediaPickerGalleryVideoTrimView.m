#import "TGMediaPickerGalleryVideoTrimView.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGImageUtils.h>
#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>

#import "TGPhotoEditorInterfaceAssets.h"

@interface TGMediaPickerGalleryVideoTrimView () <UIGestureRecognizerDelegate>
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

@implementation TGMediaPickerGalleryVideoTrimView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -25, -5, -25);
        
        UIColor *normalColor = UIColorRGB(0x4d4d4d);
        UIColor *accentColor = [TGPhotoEditorInterfaceAssets accentColor];
        
        static dispatch_once_t onceToken;
        static UIImage *handle;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(12.0f, 36.0f), false, 0.0f);
            
            [normalColor setFill];
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.0f, 0.0f, 12.0f, 36.0f) byRoundingCorners:UIRectCornerTopLeft | UIRectCornerBottomLeft cornerRadii:CGSizeMake(4.0f, 4.0f)] fill];
            
            handle = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        UIImage *leftImage = handle;
        UIImage *leftHighlightedImage = TGTintedImage(handle, accentColor);
        UIImage *rightImage = [UIImage imageWithCGImage:handle.CGImage scale:handle.scale orientation:UIImageOrientationUpMirrored];
        UIImage *rightHighlightedImage = [UIImage imageWithCGImage:leftHighlightedImage.CGImage scale:handle.scale orientation:UIImageOrientationUpMirrored];
        
        _leftSegmentView = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 12, 36)];
        _leftSegmentView.adjustsImageWhenHighlighted = false;
        [_leftSegmentView setBackgroundImage:leftImage forState:UIControlStateNormal];
        [_leftSegmentView setBackgroundImage:leftHighlightedImage forState:UIControlStateSelected];
        [_leftSegmentView setBackgroundImage:leftHighlightedImage forState:UIControlStateSelected | UIControlStateHighlighted];
        _leftSegmentView.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -25, -5, -10);
        [self addSubview:_leftSegmentView];
        
        _rightSegmentView = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 12, 36)];
        _rightSegmentView.adjustsImageWhenHighlighted = false;
        [_rightSegmentView setBackgroundImage:rightImage forState:UIControlStateNormal];
        [_rightSegmentView setBackgroundImage:rightHighlightedImage forState:UIControlStateSelected];
        [_rightSegmentView setBackgroundImage:rightHighlightedImage forState:UIControlStateSelected | UIControlStateHighlighted];
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
    
    _leftSegmentView.hidden = !trimmingEnabled;
    _rightSegmentView.hidden = !trimmingEnabled;
    
    [self setNeedsLayout];
}

- (void)setTrimming:(bool)trimming animated:(bool)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.15f animations:^
         {
             [_leftSegmentView setSelected:trimming];
             [_rightSegmentView setSelected:trimming];
         }];
    }
    else
    {
        [_leftSegmentView setSelected:trimming];
        [_rightSegmentView setSelected:trimming];
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
    CGFloat handleWidth = 12.0f;
    
    _leftSegmentView.frame = CGRectMake(0, 0, handleWidth, self.frame.size.height);
    _rightSegmentView.frame = CGRectMake(self.frame.size.width - handleWidth, 0, handleWidth, self.frame.size.height);
}

@end
