#import "TGMediaPickerGalleryVideoTrimView.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGImageUtils.h>
#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>

#import <LegacyComponents/TGPhotoEditorInterfaceAssets.h>

@interface TGMediaPickerGalleryVideoTrimView () <UIGestureRecognizerDelegate>
{
    UIButton *_leftSegmentView;
    UIButton *_rightSegmentView;
    UIImageView *_borderView;
    
    UIImageView *_leftCapsuleView;
    UIImageView *_rightCapsuleView;
    
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
        
        UIColor *normalColor = UIColorRGB(0xffffff);
        UIColor *accentColor = UIColorRGB(0xf8d74a);
        
        static dispatch_once_t onceToken;
        static UIImage *handle;
        static UIImage *border;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(12.0f, 40.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            
            CGContextSetFillColorWithColor(context, normalColor.CGColor);
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 40, 40) cornerRadius:9.0];
            CGContextAddPath(context, path.CGPath);
            CGContextFillPath(context);
            
            CGContextSetBlendMode(context, kCGBlendModeClear);
            
            CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
            path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(11.0f, 1.0f + TGSeparatorHeight(), 20, 40.0f - (1.0f + TGSeparatorHeight()) * 2.0) cornerRadius:2.0];
            CGContextAddPath(context, path.CGPath);
            CGContextFillPath(context);
            
            handle = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, 40.0f), false, 0.0f);
            context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, normalColor.CGColor);
            CGContextFillRect(context, CGRectMake(0, 0, 1, 1.0 + TGSeparatorHeight()));
            CGContextFillRect(context, CGRectMake(0, 40.0 - 1.0 - TGSeparatorHeight(), 1, 1.0 + TGSeparatorHeight()));
            border = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        UIImage *leftImage = handle;
        UIImage *leftHighlightedImage = TGTintedImage(handle, accentColor);
        UIImage *rightImage = [UIImage imageWithCGImage:handle.CGImage scale:handle.scale orientation:UIImageOrientationUpMirrored];
        UIImage *rightHighlightedImage = [UIImage imageWithCGImage:leftHighlightedImage.CGImage scale:handle.scale orientation:UIImageOrientationUpMirrored];
        UIImage *borderHighlightedImage = TGTintedImage(border, accentColor);
        
        _leftSegmentView = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 12, 40)];
        _leftSegmentView.adjustsImageWhenHighlighted = false;
        [_leftSegmentView setBackgroundImage:leftImage forState:UIControlStateNormal];
        [_leftSegmentView setBackgroundImage:leftHighlightedImage forState:UIControlStateSelected];
        [_leftSegmentView setBackgroundImage:leftHighlightedImage forState:UIControlStateSelected | UIControlStateHighlighted];
        _leftSegmentView.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -25, -5, -10);
        [self addSubview:_leftSegmentView];
        
        _rightSegmentView = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 12, 40)];
        _rightSegmentView.adjustsImageWhenHighlighted = false;
        [_rightSegmentView setBackgroundImage:rightImage forState:UIControlStateNormal];
        [_rightSegmentView setBackgroundImage:rightHighlightedImage forState:UIControlStateSelected];
        [_rightSegmentView setBackgroundImage:rightHighlightedImage forState:UIControlStateSelected | UIControlStateHighlighted];
        _rightSegmentView.hitTestEdgeInsets = UIEdgeInsetsMake(-5, -10, -5, -25);
        [self addSubview:_rightSegmentView];
        
        _borderView = [[UIImageView alloc] initWithImage:border];
        _borderView.highlightedImage = borderHighlightedImage;
        [self addSubview:_borderView];
        
        _leftCapsuleView = [[UIImageView alloc] initWithFrame:CGRectMake(5.0 - TGSeparatorHeight(), 14.0 + TGSeparatorHeight(), 2.0, 11.0)];
        _leftCapsuleView.backgroundColor = UIColorRGB(0x343436);
        _leftCapsuleView.clipsToBounds = true;
        _leftCapsuleView.layer.cornerRadius = 1.0;
        [_leftSegmentView addSubview:_leftCapsuleView];
        
        _rightCapsuleView = [[UIImageView alloc] initWithFrame:CGRectMake(12.0 - 3.0 - 4.0 + TGSeparatorHeight(), 14.0 + TGSeparatorHeight(), 2.0, 11.0)];
        _rightCapsuleView.backgroundColor = UIColorRGB(0x343436);
        _rightCapsuleView.clipsToBounds = true;
        _rightCapsuleView.layer.cornerRadius = 1.0;
        [_rightSegmentView addSubview:_rightCapsuleView];
        
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
    _borderView.hidden = !trimmingEnabled;
    
    [self setNeedsLayout];
}

- (void)setTrimmingEnabled:(bool)trimmingEnabled animated:(bool)animated {
    _trimmingEnabled = trimmingEnabled;
    
    CGFloat alpha = trimmingEnabled ? 1.0 : 0.0;
    
    [UIView animateWithDuration:0.2 animations:^{
        _leftSegmentView.alpha = alpha;
        _rightSegmentView.alpha = alpha;
        _borderView.alpha = alpha;
    }];
}

- (void)setTrimming:(bool)trimming animated:(bool)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.15f animations:^
         {
            [_leftSegmentView setSelected:trimming];
            [_rightSegmentView setSelected:trimming];
            [_borderView setHighlighted:trimming];
        }];
    }
    else
    {
        [_leftSegmentView setSelected:trimming];
        [_rightSegmentView setSelected:trimming];
        [_borderView setHighlighted:trimming];
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
    _borderView.frame = CGRectMake(handleWidth, 0, self.frame.size.width - handleWidth * 2.0, self.frame.size.height);
}

@end
