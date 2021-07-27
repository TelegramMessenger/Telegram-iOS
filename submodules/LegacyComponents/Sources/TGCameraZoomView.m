#import "TGCameraZoomView.h"
#import "TGCameraInterfaceAssets.h"

#import "TGModernButton.h"
#import "TGImageUtils.h"
#import "TGPhotoEditorUtils.h"

#import "LegacyComponentsInternal.h"

@interface TGCameraZoomView ()
{
    UIView *_clipView;
    UIView *_wrapperView;
    
    UIView *_minusIconView;
    UIView *_plusIconView;

    UIView *_leftLine;
    UIView *_rightLine;
    UIImageView *_knobView;
}
@end

@implementation TGCameraZoomView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.userInteractionEnabled = false;
        
        _clipView = [[UIView alloc] init];
        _clipView.clipsToBounds = true;
        [self addSubview:_clipView];
        
        _wrapperView = [[UIView alloc] initWithFrame:self.bounds];
        [_clipView addSubview:_wrapperView];
        
        _leftLine = [[UIView alloc] initWithFrame:CGRectMake(-1000, (12.5f - 1.5f) / 2, 1000, 1.5f)];
        _leftLine.backgroundColor = [TGCameraInterfaceAssets normalColor];
        [_wrapperView addSubview:_leftLine];
        
        _rightLine = [[UIView alloc] initWithFrame:CGRectMake(12.5f, (12.5 - 1.5f) / 2, 1000, 1.5f)];
        _rightLine.backgroundColor = [TGCameraInterfaceAssets normalColor];
        [_wrapperView addSubview:_rightLine];
        
        static UIImage *knobImage = nil;

        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(12.5f, 12.5f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();

            CGContextSetStrokeColorWithColor(context, [TGCameraInterfaceAssets accentColor].CGColor);
            CGContextSetLineWidth(context, 1.0f);
            CGContextStrokeEllipseInRect(context, CGRectMake(0.75f, 0.75f, 12.5f - 1.5f, 12.5f - 1.5f));

            knobImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _knobView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 12.5f, 12.5f)];
        _knobView.image = knobImage;
        [_wrapperView addSubview:_knobView];
        
        _minusIconView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 9.5f, 1.5f)];
        _minusIconView.backgroundColor = [TGCameraInterfaceAssets normalColor];
        _minusIconView.layer.cornerRadius = 1;
        [self addSubview:_minusIconView];
        
        _plusIconView = [[UIView alloc] initWithFrame:CGRectMake(frame.size.width - 9.5f, 0, 9.5f, 1.5f)];
        _plusIconView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _plusIconView.backgroundColor = [TGCameraInterfaceAssets normalColor];
        _plusIconView.layer.cornerRadius = 1;
        [self addSubview:_plusIconView];
        
        CALayer *plusVertLayer = [[CALayer alloc] init];
        plusVertLayer.backgroundColor = [TGCameraInterfaceAssets normalColor].CGColor;
        plusVertLayer.cornerRadius = 1;
        plusVertLayer.frame = CGRectMake((9.5f - 1.5f) / 2, -(9.5f - 1.5f) / 2, 1.5f, 9.5f);
        [_plusIconView.layer addSublayer:plusVertLayer];
        
        [self hideAnimated:false];
    }
    return self;
}

- (void)setZoomLevel:(CGFloat)zoomLevel
{
    [self setZoomLevel:zoomLevel displayNeeded:true];
}

- (void)setZoomLevel:(CGFloat)zoomLevel displayNeeded:(bool)displayNeeded
{
    _zoomLevel = zoomLevel;
    [self setNeedsLayout];
    
    if (displayNeeded)
    {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideAnimated) object:nil];
        
        if (self.alpha < FLT_EPSILON)
            [self showAnimated:true];
    }
}

- (bool)isActive
{
    return (self.alpha > FLT_EPSILON);
}

- (void)showAnimated:(bool)animated
{
    if (self.activityChanged != nil)
        self.activityChanged(true);
    
    if (animated)
    {
        [UIView animateWithDuration:0.3f animations:^
        {
            self.alpha = 1.0f;
        }];
    }
    else
    {
        self.alpha = 1.0f;
    }
}

- (void)hideAnimated:(bool)animated
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideAnimated) object:nil];
    
    if (animated)
    {
        [UIView animateWithDuration:0.3f animations:^
        {
            self.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            if (finished)
            {
                if (self.activityChanged != nil)
                    self.activityChanged(false);
            }
        }];
    }
    else
    {
        self.alpha = 0.0f;
        
        if (self.activityChanged != nil)
            self.activityChanged(false);
    }
}

- (void)hideAnimated
{
    [self hideAnimated:true];
}

- (void)interactionEnded
{
    [self performSelector:@selector(hideAnimated) withObject:nil afterDelay:4.0f];
}

- (void)layoutSubviews
{
    _clipView.frame = CGRectMake(22, (self.frame.size.height - 12.5f) / 2, self.frame.size.width - 44, 12.5f);
    
    CGFloat zoomLevel = self.zoomLevel;
    zoomLevel = MAX(1.0, zoomLevel);
    CGFloat factor = zoomLevel / 8.0;
    
    CGFloat position = (_clipView.frame.size.width - _knobView.frame.size.width) * factor;
    if (self.zoomLevel < 1.0f - FLT_EPSILON)
        position = CGFloor(position);
    
    _wrapperView.frame = CGRectMake(position, 0, _wrapperView.frame.size.width, _wrapperView.frame.size.height);
}

@end

@interface TGCameraZoomModeItemView: TGModernButton
{
    UIImageView *_backgroundView;
    UILabel *_label;
}
@end

@implementation TGCameraZoomModeItemView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _backgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(3, 3, 37, 37)];
        _backgroundView.image = TGCircleImage(37, [UIColor colorWithWhite:0.0 alpha:0.4]);
        
        _label = [[UILabel alloc] initWithFrame:self.bounds];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.font = [TGCameraInterfaceAssets boldFontOfSize:13.0];
        
        [self addSubview:_backgroundView];
        [self addSubview:_label];
    }
    return self;
}

- (void)setValue:(NSString *)value selected:(bool)selected animated:(bool)animated {
    CGFloat scale = selected ? 1.0 : 0.7;
    CGFloat textScale = selected ? 1.0 : 0.85;
    
    _label.text = value;
    _label.textColor = selected ? [TGCameraInterfaceAssets accentColor] : [UIColor whiteColor];
    
    if (animated) {
        [UIView animateWithDuration:0.3f animations:^
        {
            _backgroundView.transform = CGAffineTransformMakeScale(scale, scale);
            _label.transform = CGAffineTransformMakeScale(textScale, textScale);
        }];
    } else {
        _backgroundView.transform = CGAffineTransformMakeScale(scale, scale);
        _label.transform = CGAffineTransformMakeScale(textScale, textScale);
    }
}

@end

@interface TGCameraZoomModeView () <UIGestureRecognizerDelegate>
{
    CGFloat _minZoomLevel;
    CGFloat _maxZoomLevel;
    
    UIView *_backgroundView;
    
    bool _hasUltrawideCamera;
    bool _hasTelephotoCamera;
    
    bool _beganFromPress;

    TGCameraZoomModeItemView *_leftItem;
    TGCameraZoomModeItemView *_centerItem;
    TGCameraZoomModeItemView *_rightItem;
    
    bool _lockedOn;
}
@end

@implementation TGCameraZoomModeView

- (instancetype)initWithFrame:(CGRect)frame hasUltrawideCamera:(bool)hasUltrawideCamera hasTelephotoCamera:(bool)hasTelephotoCamera minZoomLevel:(CGFloat)minZoomLevel maxZoomLevel:(CGFloat)maxZoomLevel
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _hasUltrawideCamera = hasUltrawideCamera;
        _hasTelephotoCamera = hasTelephotoCamera;
        _minZoomLevel = minZoomLevel;
        _maxZoomLevel = maxZoomLevel;
        
        _backgroundView = [[UIView alloc] initWithFrame:self.bounds];
        _backgroundView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.15];
        _backgroundView.layer.cornerRadius = self.bounds.size.height / 2.0;
        
        _leftItem = [[TGCameraZoomModeItemView alloc] initWithFrame:CGRectMake(0, 0, 43, 43)];
        [_leftItem addTarget:self action:@selector(leftPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _centerItem = [[TGCameraZoomModeItemView alloc] initWithFrame:CGRectMake(43, 0, 43, 43)];
        [_centerItem addTarget:self action:@selector(centerPressed) forControlEvents:UIControlEventTouchUpInside];
        
        _rightItem = [[TGCameraZoomModeItemView alloc] initWithFrame:CGRectMake(86, 0, 43, 43)];
        [_rightItem addTarget:self action:@selector(rightPressed) forControlEvents:UIControlEventTouchUpInside];
        
        [self addSubview:_backgroundView];
        [self addSubview:_centerItem];
        if (hasTelephotoCamera && hasUltrawideCamera) {
            [self addSubview:_leftItem];
            [self addSubview:_rightItem];
        }
        
        UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesture:)];
        panGestureRecognizer.delegate = self;
        [self addGestureRecognizer:panGestureRecognizer];
        
        UILongPressGestureRecognizer *pressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pressGesture:)];
        pressGestureRecognizer.delegate = self;
        [self addGestureRecognizer:pressGestureRecognizer];
    }
    return self;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer.view == self && otherGestureRecognizer.view == self) {
        return true;
    } else {
        return false;
    }
}

- (void)pressGesture:(UILongPressGestureRecognizer *)gestureRecognizer {
    switch (gestureRecognizer.state) {
    case UIGestureRecognizerStateBegan:
        _beganFromPress = true;
        self.zoomChanged(_zoomLevel, false, false);
        break;
    case UIGestureRecognizerStateEnded:
        self.zoomChanged(_zoomLevel, true, false);
        break;
    case UIGestureRecognizerStateCancelled:
        self.zoomChanged(_zoomLevel, true, false);
        break;
    default:
        break;
    }
}

- (void)panGesture:(UIPanGestureRecognizer *)gestureRecognizer {
    CGPoint translation = [gestureRecognizer translationInView:self];
    
    switch (gestureRecognizer.state) {
    case UIGestureRecognizerStateChanged:
    {
        if (_lockedOn) {
            if (ABS(translation.x) > 8.0) {
                _lockedOn = false;
                [gestureRecognizer setTranslation:CGPointZero inView:self];
                
                CGFloat delta = translation.x > 0 ? -0.06 : 0.06;
                CGFloat newLevel = MAX(_minZoomLevel, MIN(_maxZoomLevel, _zoomLevel + delta));
                _zoomLevel = newLevel;
                self.zoomChanged(newLevel, false, false);
                return;
            } else {
                return;
            }
        }
        
        CGFloat previousLevel = _zoomLevel;
        
        CGFloat delta = -translation.x / 60.0;
        if (_zoomLevel > 2.0) {
            delta *= 3.5;
        }
        CGFloat newLevel = MAX(_minZoomLevel, MIN(_maxZoomLevel, _zoomLevel + delta));
        
        CGFloat near = floor(newLevel);
        if (near <= 2.0 && ABS(newLevel - near) < 0.05 && previousLevel != near && translation.x < 15.0) {
            newLevel = near;
            _lockedOn = true;
            
            [gestureRecognizer setTranslation:CGPointZero inView:self];
        }
        
        _zoomLevel = newLevel;
        self.zoomChanged(newLevel, false, false);
    }
        break;
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
    {
        if (gestureRecognizer.view != self || !_beganFromPress) {
            self.zoomChanged(_zoomLevel, true, false);
        }
        _beganFromPress = false;
    }
        break;
    default:
        break;
    }
    
    if (!_lockedOn) {
        [gestureRecognizer setTranslation:CGPointZero inView:self];
    }
}

- (void)leftPressed {
    if (_zoomLevel != 0.5) {
        [self setZoomLevel:0.5 animated:true];
        self.zoomChanged(0.5, true, true);
    }
}

- (void)centerPressed {
    if (!(_hasTelephotoCamera && _hasUltrawideCamera)) {
        if (_zoomLevel == 1.0) {
            if (_hasUltrawideCamera) {
                [self setZoomLevel:0.5 animated:true];
                self.zoomChanged(0.5, true, true);
            } else if (_hasTelephotoCamera) {
                [self setZoomLevel:2.0 animated:true];
                self.zoomChanged(2.0, true, true);
            }
        } else {
            [self setZoomLevel:1.0 animated:true];
            self.zoomChanged(1.0, true, true);
        }
    } else {
        if (_zoomLevel != 1.0) {
            [self setZoomLevel:1.0 animated:true];
            self.zoomChanged(1.0, true, true);
        }
    }
}

- (void)rightPressed {
    if (_zoomLevel != 2.0) {
        [self setZoomLevel:2.0 animated:true];
        self.zoomChanged(2.0, true, true);
    }
}

- (void)setZoomLevel:(CGFloat)zoomLevel {
    [self setZoomLevel:zoomLevel animated:false];
}

- (void)setZoomLevel:(CGFloat)zoomLevel animated:(bool)animated
{
    _zoomLevel = zoomLevel;
    if (zoomLevel < 1.0) {
        NSString *value = [NSString stringWithFormat:@"%.1f×", zoomLevel];
        value = [value stringByReplacingOccurrencesOfString:@"." withString:@","];
        if ([value isEqual:@"1,0×"] || [value isEqual:@"1×"]) {
            value = @"0,9×";
        }
        if (_leftItem.superview != nil) {
            [_leftItem setValue:value selected:true animated:animated];
            [_centerItem setValue:@"1" selected:false animated:animated];
        } else {
            [_centerItem setValue:value selected:false animated:animated];
        }
        [_rightItem setValue:@"2" selected:false animated:animated];
    } else if (zoomLevel < 2.0) {
        [_leftItem setValue:@"0,5" selected:false animated:animated];
        bool selected = _hasTelephotoCamera && _hasUltrawideCamera;
        if ((zoomLevel - 1.0) < 0.025) {
            [_centerItem setValue:@"1×" selected:true animated:animated];
        } else {
            NSString *value = [NSString stringWithFormat:@"%.1f×", zoomLevel];
            value = [value stringByReplacingOccurrencesOfString:@"." withString:@","];
            value = [value stringByReplacingOccurrencesOfString:@",0×" withString:@"×"];
            if ([value isEqual:@"2×"]) {
                value = @"1,9×";
            }
            [_centerItem setValue:value selected:selected animated:animated];
        }
        [_rightItem setValue:@"2" selected:false animated:animated];
    } else {
        [_leftItem setValue:@"0,5" selected:false animated:animated];
          
        NSString *value = [[NSString stringWithFormat:@"%.1f×", zoomLevel] stringByReplacingOccurrencesOfString:@"." withString:@","];
        value = [value stringByReplacingOccurrencesOfString:@",0×" withString:@"×"];
        
        if (_rightItem.superview != nil) {
            [_centerItem setValue:@"1" selected:false animated:animated];
            [_rightItem setValue:value selected:true animated:animated];
        } else {
            [_centerItem setValue:value selected:true animated:animated];
        }
    }
}

- (void)setHidden:(BOOL)hidden
{
    self.alpha = hidden ? 0.0f : 1.0f;
    super.hidden = hidden;
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        super.hidden = false;
        self.userInteractionEnabled = false;
        
        [UIView animateWithDuration:0.25f animations:^
        {
            self.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            self.userInteractionEnabled = true;
             
            if (finished)
                self.hidden = hidden;
        }];
    }
    else
    {
        self.alpha = hidden ? 0.0f : 1.0f;
        super.hidden = hidden;
    }
}

- (void)layoutSubviews
{
    if (_leftItem.superview == nil && _rightItem.superview == nil) {
        _backgroundView.frame = CGRectMake(43, 0, 43, 43);
    } else if (_leftItem.superview != nil && _rightItem.superview == nil) {
        _backgroundView.frame = CGRectMake(21 + TGScreenPixel, 0, 86, 43);
        _leftItem.frame = CGRectMake(21 + TGScreenPixel, 0, 43, 43);
        _centerItem.frame = CGRectMake(21 + TGScreenPixel + 43, 0, 43, 43);
    } else if (_leftItem.superview == nil && _rightItem.superview != nil) {
        _backgroundView.frame = CGRectMake(21 + TGScreenPixel, 0, 86, 43);
        _centerItem.frame = CGRectMake(21 + TGScreenPixel, 0, 43, 43);
        _rightItem.frame = CGRectMake(21 + TGScreenPixel + 43, 0, 43, 43);
    } else {
        _leftItem.frame = CGRectMake(0, 0, 43, 43.0);
        _centerItem.frame = CGRectMake(43, 0, 43, 43.0);
        _rightItem.frame = CGRectMake(86, 0, 43, 43.0);
    }
}

- (void)setInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    _interfaceOrientation = interfaceOrientation;
    _leftItem.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(interfaceOrientation));
    _centerItem.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(interfaceOrientation));
    _rightItem.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(interfaceOrientation));
}

@end


@interface TGCameraZoomWheelView ()
{
    bool _hasUltrawideCamera;
    bool _hasTelephotoCamera;
    UIView *_containerView;
    UIImageView *_backgroundView;
    UIImageView *_scaleView;
    UIImageView *_maskView;
    UIImageView *_arrowView;
    
    UILabel *_valueLabel;
    UILabel *_05Label;
    UILabel *_1Label;
    UILabel *_2Label;
    UILabel *_8Label;
    
    UIPanGestureRecognizer *_gestureRecognizer;
    
    UISelectionFeedbackGenerator *_feedbackGenerator;
}
@end

@implementation TGCameraZoomWheelView

- (void)_drawLineInContext:(CGContextRef)context side:(CGFloat)side atAngle:(CGFloat)angle lineLength:(CGFloat)lineLength lineWidth:(CGFloat)lineWidth opaque:(bool)opaque {
    CGContextSaveGState(context);
    
    CGContextTranslateCTM(context, side / 2.0, side / 2.0);
    CGContextRotateCTM(context, angle);
    CGContextTranslateCTM(context, -side / 2.0, -side / 2.0);
    
    CGContextSetLineWidth(context, lineWidth);
    CGContextSetStrokeColorWithColor(context, [UIColor colorWithWhite:1.0 alpha:opaque ? 1.0 : 0.5].CGColor);
    CGContextMoveToPoint(context, side / 2.0, 4.0);
    CGContextAddLineToPoint(context, side / 2.0, 4.0 + lineLength);
    CGContextStrokePath(context);
    
    CGContextRestoreGState(context);
}

- (NSArray *)ultraLines {
    return @[
        @[@0.5, @-19.6, @3],
        @[@0.6, @-14.4, @1],
        @[@0.7, @-10.0, @1],
        @[@0.8, @-6.3, @1],
        @[@0.9, @-3.0, @1]
    ];
}

- (NSArray *)lines {
    return @[
        @[@1.0, @0.0, @3],
        
        @[@1.1, @2.7, @1],
        @[@1.2, @5.2, @1],
        @[@1.3, @7.4, @1],
        @[@1.4, @9.6, @1],
        @[@1.5, @11.5, @1],
        @[@1.6, @13.3, @1],
        @[@1.7, @15.0, @1],
        @[@1.8, @16.7, @1],
        @[@1.9, @18.2, @1],
        @[@2.0, @19.6, _hasTelephotoCamera ? @3 : @2],
        
        @[@2.1, @21.0, @1],
        @[@2.2, @22.4, @1],
        @[@2.3, @23.7, @1],
        @[@2.4, @24.8, @1],
        @[@2.5, @26.0, @1],
        @[@2.6, @27.1, @1],
        @[@2.7, @28.2, @1],
        @[@2.8, @29.2, @1],
        @[@2.9, @30.2, @1],
        @[@3.0, @31.1, @2],
        
        @[@3.1, @32.0, @1],
        @[@3.2, @32.9, @1],
        @[@3.3, @33.8, @1],
        @[@3.4, @34.7, @1],
        @[@3.5, @35.5, @1],
        @[@3.6, @36.34, @1],
        @[@3.7, @37.1, @1],
        @[@3.8, @37.85, @1],
        @[@3.9, @38.55, @1],
        @[@4.0, @39.3, @2],
        
        @[@4.1, @40.0, @1],
        @[@4.2, @40.77, @1],
        @[@4.3, @41.4, @1],
        @[@4.4, @42.05, @1],
        @[@4.5, @42.63, @1],
        @[@4.6, @43.3, @1],
        @[@4.7, @43.89, @1],
        @[@4.8, @44.42, @1],
        @[@4.9, @45.05, @1],
        @[@5.0, @45.6, @2],
        
        @[@5.1, @46.17, @1],
        @[@5.2, @46.77, @1],
        @[@5.3, @47.31, @1],
        @[@5.4, @47.78, @1],
        @[@5.5, @48.34, @1],
        @[@5.6, @48.8, @1],
        @[@5.7, @49.31, @1],
        @[@5.8, @49.85, @1],
        @[@5.9, @50.3, @1],
        @[@6.0, @50.8, @2],
        
        @[@6.1, @51.25, @1],
        @[@6.2, @51.7, @1],
        @[@6.3, @52.18, @1],
        @[@6.4, @52.63, @1],
        @[@6.5, @53.12, @1],
        @[@6.6, @53.49, @1],
        @[@6.7, @53.88, @1],
        @[@6.8, @54.28, @1],
        @[@6.9, @54.71, @1],
        @[@7.0, @55.15, @2],
        
        @[@7.1, @55.53, @1],
        @[@7.2, @55.91, @1],
        @[@7.3, @56.36, @1],
        @[@7.4, @56.74, @1],
        @[@7.5, @57.09, @1],
        @[@7.6, @57.52, @1],
        @[@7.7, @57.89, @1],
        @[@7.8, @58.19, @1],
        @[@7.9, @58.56, @1],
        @[@8.0, @58.93, @3],
    ];
}

- (instancetype)initWithFrame:(CGRect)frame hasUltrawideCamera:(bool)hasUltrawideCamera hasTelephotoCamera:(bool)hasTelephotoCamera
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        TGIsRetina();
        
        if (iosMajorVersion() >= 10) {
            _feedbackGenerator = [[UISelectionFeedbackGenerator alloc] init];
        }
        
        _hasUltrawideCamera = hasUltrawideCamera;
        _hasTelephotoCamera = hasTelephotoCamera;
                                  
        CGFloat side = floor(frame.size.width * 1.1435);
        CGFloat length = 17.0;
        CGFloat smallWidth = MAX(0.5, 1.0 - TGScreenPixel);
        CGFloat mediumWidth = smallWidth;
        CGFloat bigWidth = 1.0;
        
        _backgroundView = [[UIImageView alloc] initWithImage:TGCircleImage(side, [UIColor colorWithWhite:0.0 alpha:0.5])];
        _backgroundView.frame = CGRectMake(TGScreenPixelFloor((frame.size.width - side) / 2.0), 0.0, side, side);
        [self addSubview:_backgroundView];

        UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        NSArray *ultraLines = [self ultraLines];
        NSArray *lines = [self lines];
        
        if (_hasUltrawideCamera) {
            for (NSArray *values in ultraLines) {
                CGFloat angle = [values[1] floatValue];
                CGFloat width = [values[2] intValue];
                
                CGFloat lineWidth = smallWidth;
                if (width == 2) {
                    lineWidth = mediumWidth;
                } else if (width == 3) {
                    lineWidth = bigWidth;
                }
                [self _drawLineInContext:context side:side atAngle:TGDegreesToRadians(angle) lineLength:length lineWidth:lineWidth opaque:width > 1];
            }
        }
        for (NSArray *values in lines) {
            CGFloat angle = [values[1] floatValue];
            CGFloat width = [values[2] intValue];
            
            CGFloat lineWidth = smallWidth;
            if (width == 2) {
                lineWidth = mediumWidth;
            } else if (width == 3) {
                lineWidth = bigWidth;
            }
            
            [self _drawLineInContext:context side:side atAngle:TGDegreesToRadians(angle) lineLength:length lineWidth:lineWidth opaque:width > 1];
        }
       
        UIImage *scaleImage = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:25 topCapHeight:25];
        UIGraphicsEndImageContext();
        
        _containerView = [[UIView alloc] initWithFrame:CGRectMake(TGScreenPixelFloor((frame.size.width - side) / 2.0), 0.0, side, frame.size.height)];
        _containerView.userInteractionEnabled = false;
        [self addSubview:_containerView];
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, frame.size.height), false, 0.0f);
        context = UIGraphicsGetCurrentContext();

        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(0, 0, side, side));
        
        CGContextSetBlendMode(context, kCGBlendModeClear);
        CGContextMoveToPoint(context, side / 2.0 - 7.0, 0);
        CGContextAddLineToPoint(context, side / 2.0 + 7.0, 0);
        CGContextAddLineToPoint(context, side / 2.0 + 2.0, 22);
        CGContextAddLineToPoint(context, side / 2.0 - 2.0, 22);
        CGContextClosePath(context);
        CGContextFillPath(context);
        
        CGContextFillRect(context, CGRectMake(side / 2.0 - 1.0, 20, 2.0, 7.0));
        CGContextFillEllipseInRect(context, CGRectMake(side / 2.0 - 17.0, 21.0, 34.0, 34.0));
        
        UIImage *maskImage = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:25 topCapHeight:25];
        UIGraphicsEndImageContext();
        
        _maskView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, side, frame.size.height)];
        _maskView.image = maskImage;
        _containerView.maskView = _maskView;
        
        _scaleView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, side, side)];
        _scaleView.image = scaleImage;
        [_containerView addSubview:_scaleView];
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(4, 10), false, 0.0f);
        context = UIGraphicsGetCurrentContext();

        CGContextSetFillColorWithColor(context, [TGCameraInterfaceAssets accentColor].CGColor);
        CGContextMoveToPoint(context, 0, 0);
        CGContextAddLineToPoint(context, 4, 0);
        CGContextAddLineToPoint(context, 2 + TGScreenPixel, 10);
        CGContextAddLineToPoint(context, 2 - TGScreenPixel, 10);
        CGContextClosePath(context);
        CGContextFillPath(context);
        
        UIImage *arrowImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        _arrowView = [[UIImageView alloc] initWithFrame:CGRectMake(floor((frame.size.width - 4) / 2.0), 4, 4, 10)];
        _arrowView.image = arrowImage;
        _arrowView.userInteractionEnabled = false;
        [self addSubview:_arrowView];
        
        _valueLabel = [[UILabel alloc] init];
        _valueLabel.font = [TGCameraInterfaceAssets boldFontOfSize:13.0];
        _valueLabel.textColor = [TGCameraInterfaceAssets accentColor];
        _valueLabel.userInteractionEnabled = false;
        [self addSubview:_valueLabel];
        
        CGFloat radius = side / 2.0;
        if (_hasUltrawideCamera) {
            _05Label = [[UILabel alloc] init];
            _05Label.text = @"0,5";
            _05Label.font = [TGCameraInterfaceAssets boldFontOfSize:13.0];
            _05Label.textColor = [UIColor whiteColor];
            [_05Label sizeToFit];
            [_scaleView addSubview:_05Label];
            
            _05Label.center = CGPointMake(radius - sin(TGDegreesToRadians(19.6)) * (radius - 38.0), radius - cos(TGDegreesToRadians(19.6)) * (radius - 38.0));
            _05Label.transform = CGAffineTransformMakeRotation(TGDegreesToRadians(-19.6));
        }
        
        _1Label = [[UILabel alloc] init];
        _1Label.text = @"1";
        _1Label.font = [TGCameraInterfaceAssets boldFontOfSize:13.0];
        _1Label.textColor = [UIColor whiteColor];
        [_1Label sizeToFit];
        _1Label.frame = CGRectMake(TGScreenPixelFloor((_scaleView.bounds.size.width - _1Label.frame.size.width) / 2.0), 30.0, _1Label.frame.size.width, _1Label.frame.size.height);
        [_scaleView addSubview:_1Label];
        
        if (_hasTelephotoCamera) {
            _2Label = [[UILabel alloc] init];
            _2Label.text = @"2";
            _2Label.font = [TGCameraInterfaceAssets boldFontOfSize:13.0];
            _2Label.textColor = [UIColor whiteColor];
            [_2Label sizeToFit];
            [_scaleView addSubview:_2Label];
            
            _2Label.center = CGPointMake(radius - sin(TGDegreesToRadians(-19.6)) * (radius - 38.0), radius - cos(TGDegreesToRadians(-19.6)) * (radius - 38.0));
            _2Label.transform = CGAffineTransformMakeRotation(TGDegreesToRadians(19.6));
        }
        
        _8Label = [[UILabel alloc] init];
        _8Label.text = @"8";
        _8Label.font = [TGCameraInterfaceAssets boldFontOfSize:13.0];
        _8Label.textColor = [UIColor whiteColor];
        [_8Label sizeToFit];
        [_scaleView addSubview:_8Label];
        
        _8Label.center = CGPointMake(radius - sin(TGDegreesToRadians(-58.93)) * (radius - 38.0), radius - cos(TGDegreesToRadians(-58.93)) * (radius - 38.0));
        _8Label.transform = CGAffineTransformMakeRotation(TGDegreesToRadians(58.93));
        
        _gestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesture:)];
        [self addGestureRecognizer:_gestureRecognizer];
    }
    return self;
}

- (void)panGesture:(UIPanGestureRecognizer *)gestureRecognizer {
    if (self.panGesture != nil) {
        self.panGesture(gestureRecognizer);
    }
}


- (void)setZoomLevel:(CGFloat)zoomLevel {
    [self setZoomLevel:zoomLevel panning:false];
}

- (void)setZoomLevel:(CGFloat)zoomLevel panning:(bool)panning {
    zoomLevel = MAX(0.5, zoomLevel);
    _zoomLevel = zoomLevel;
    
    NSArray *ultraLines = [self ultraLines];
    NSArray *lines = [self lines];
    
    CGFloat finalAngle = 0.0;
    NSArray *allLines = [ultraLines arrayByAddingObjectsFromArray:lines];
    NSArray *previous = nil;
    for (NSArray *values in allLines) {
        CGFloat value = [values[0] floatValue];
        CGFloat angle = [values[1] floatValue];
        
        if (previous == nil && zoomLevel <= value) {
            finalAngle = angle;
            break;
        }

        if (previous != nil && zoomLevel <= value) {
            if (zoomLevel == value) {
                finalAngle = angle;
                break;
            } else {
                CGFloat previousValue = [previous[0] floatValue];
                CGFloat previousAngle = [previous[1] floatValue];
                
                if (zoomLevel > previousValue) {
                    CGFloat factor = (zoomLevel - previousValue) / (value - previousValue);
                    finalAngle = previousAngle + (angle - previousAngle) * factor;
                    break;
                }
            }
        }
        previous = values;
    }
    finalAngle = -TGDegreesToRadians(finalAngle);
    
    _scaleView.transform = CGAffineTransformMakeRotation(finalAngle);
    
    NSString *value = [NSString stringWithFormat:@"%.1f×", zoomLevel];
    value = [value stringByReplacingOccurrencesOfString:@"." withString:@","];
    value = [value stringByReplacingOccurrencesOfString:@",0×" withString:@"×"];

    NSString *previousValue = _valueLabel.text;
    _valueLabel.text = value;
    [_valueLabel sizeToFit];
    
    if (panning && ![previousValue isEqualToString:value] && ([value isEqualToString:@"0,5×"] || ![value containsString:@","])) {
        [_feedbackGenerator selectionChanged];
    }
    
    CGRect valueLabelFrame = CGRectMake(TGScreenPixelFloor((self.frame.size.width - _valueLabel.bounds.size.width) / 2.0), 30.0, _valueLabel.bounds.size.width, _valueLabel.bounds.size.height);
    _valueLabel.bounds = CGRectMake(0, 0, valueLabelFrame.size.width, valueLabelFrame.size.height);
    _valueLabel.center = CGPointMake(valueLabelFrame.origin.x + valueLabelFrame.size.width / 2.0, valueLabelFrame.origin.y + valueLabelFrame.size.height / 2.0);
}

- (void)setInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    _interfaceOrientation = interfaceOrientation;
 
    CGFloat delta = 0.0f;
    switch (interfaceOrientation) {
        case UIInterfaceOrientationLandscapeLeft:
            delta = -90.0f;
            break;
        case UIInterfaceOrientationLandscapeRight:
            delta = 90.0f;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            delta = 180.0f;
        default:
            break;
    }
    _valueLabel.transform = CGAffineTransformMakeRotation(TGDegreesToRadians(delta));
    _05Label.transform = CGAffineTransformMakeRotation(TGDegreesToRadians(-19.6 + delta));
    _1Label.transform = CGAffineTransformMakeRotation(TGDegreesToRadians(delta));
    _2Label.transform = CGAffineTransformMakeRotation(TGDegreesToRadians(19.6 + delta));
    _8Label.transform = CGAffineTransformMakeRotation(TGDegreesToRadians(58.93 + delta));
}

- (void)setHidden:(BOOL)hidden
{
    self.alpha = hidden ? 0.0f : 1.0f;
    super.hidden = hidden;
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        super.hidden = false;
        self.userInteractionEnabled = false;
        
        [UIView animateWithDuration:0.25f animations:^
        {
            self.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            self.userInteractionEnabled = true;
             
            if (finished)
                self.hidden = hidden;
        }];
    }
    else
    {
        self.alpha = hidden ? 0.0f : 1.0f;
        super.hidden = hidden;
    }
}

@end

