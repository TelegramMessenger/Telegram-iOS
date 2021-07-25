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
            CGContextSetLineWidth(context, 1.5f);
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
    
    CGFloat position = (_clipView.frame.size.width - _knobView.frame.size.width) * self.zoomLevel;
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
    _label.font = [TGCameraInterfaceAssets boldFontOfSize:13.0];
    
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

@interface TGCameraZoomModeView ()
{
    UIView *_backgroundView;
    
    bool _hasUltrawideCamera;
    bool _hasTelephotoCamera;

    TGCameraZoomModeItemView *_leftItem;
    TGCameraZoomModeItemView *_centerItem;
    TGCameraZoomModeItemView *_rightItem;
}
@end

@implementation TGCameraZoomModeView

- (instancetype)initWithFrame:(CGRect)frame hasUltrawideCamera:(bool)hasUltrawideCamera hasTelephotoCamera:(bool)hasTelephotoCamera
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _hasUltrawideCamera = hasUltrawideCamera;
        _hasTelephotoCamera = hasTelephotoCamera;
        
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
        if (hasUltrawideCamera) {
            [self addSubview:_leftItem];
        }
        [self addSubview:_centerItem];
        if (hasTelephotoCamera) {
            [self addSubview:_rightItem];
        }
        
        UIPanGestureRecognizer *gestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesture:)];
//        [self addGestureRecognizer:gestureRecognizer];
    }
    return self;
}


- (void)panGesture:(UIPanGestureRecognizer *)gestureRecognizer {
    CGPoint translation = [gestureRecognizer translationInView:self];
    
    switch (gestureRecognizer.state) {
    case UIGestureRecognizerStateBegan:
        self.zoomChanged(_zoomLevel, false);
        break;
        
    case UIGestureRecognizerStateChanged:
        _zoomLevel = MAX(0.5, MIN(10.0, _zoomLevel - translation.x / 100.0));
        self.zoomChanged(_zoomLevel, false);
        break;
        
    case UIGestureRecognizerStateEnded:
        self.zoomChanged(_zoomLevel, true);
        break;
        
    case UIGestureRecognizerStateCancelled:
        self.zoomChanged(_zoomLevel, true);
        break;
        
    default:
        break;
    }
    
    [gestureRecognizer setTranslation:CGPointZero inView:self];
}

- (void)leftPressed {
    [self setZoomLevel:0.5 animated:true];
    self.zoomChanged(0.5, true);
}

- (void)centerPressed {
    [self setZoomLevel:1.0 animated:true];
    self.zoomChanged(1.0, true);
}

- (void)rightPressed {
    [self setZoomLevel:2.0 animated:true];
    self.zoomChanged(2.0, true);
}

- (void)setZoomLevel:(CGFloat)zoomLevel {
    [self setZoomLevel:zoomLevel animated:false];
}

- (void)setZoomLevel:(CGFloat)zoomLevel animated:(bool)animated
{
    _zoomLevel = zoomLevel;
    if (zoomLevel < 1.0) {
        NSString *value = [NSString stringWithFormat:@"%.1fx", zoomLevel];
        if ([value isEqual:@"1.0x"]) {
            value = @"0.9x";
        }
        [_leftItem setValue:value selected:true animated:animated];
        [_centerItem setValue:@"1" selected:false animated:animated];
        [_rightItem setValue:@"2" selected:false animated:animated];
    } else if (zoomLevel < 2.0) {
        [_leftItem setValue:@"0.5" selected:false animated:animated];
        if ((zoomLevel - 1.0) < 0.1) {
            [_centerItem setValue:@"1x" selected:true animated:animated];
        } else {
            NSString *value = [NSString stringWithFormat:@"%.1fx", zoomLevel];
            if ([value isEqual:@"1.0x"]) {
                value = @"1x";
            }
            [_centerItem setValue:value selected:true animated:animated];
        }
        [_rightItem setValue:@"2" selected:false animated:animated];
    } else {
        [_leftItem setValue:@"0.5" selected:false animated:animated];
        [_centerItem setValue:@"1" selected:false animated:animated];
        
        CGFloat near = round(zoomLevel);
        if (ABS(zoomLevel - near) < 0.1) {
            [_rightItem setValue:[NSString stringWithFormat:@"%dx", (int)zoomLevel] selected:true animated:animated];
        } else {
            [_rightItem setValue:[NSString stringWithFormat:@"%.1fx", zoomLevel] selected:true animated:animated];
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
    if (_rightItem.superview == nil) {
        _backgroundView.frame = CGRectMake(43, 0, 43, 43);
    } else if (_leftItem.superview == nil) {
        _backgroundView.frame = CGRectMake(21 + TGScreenPixel, 0, 86, 43);
        _centerItem.frame = CGRectMake(21 + TGScreenPixel, 0, 43, 43);
        _rightItem.frame = CGRectMake(21 + TGScreenPixel + 43, 0, 43, 43);
    } else {
        _leftItem.frame = CGRectMake(0, 0, 43, 43.0);
        _centerItem.frame = CGRectMake(43, 0, 43, 43.0);
        _rightItem.frame = CGRectMake(86, 0, 43, 43.0);
    }
}

@end


@interface TGCameraZoomWheelView ()
{
    UIImageView *_backgroundView;
}
@end

@implementation TGCameraZoomWheelView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.clipsToBounds = true;
        
        _backgroundView = [[UIImageView alloc] initWithFrame:CGRectMake(-28.0, 0.0, 446.0, 446.0)];
        _backgroundView.alpha = 0.75;

        [self addSubview:_backgroundView];
    }
    return self;
}

- (void)setZoomLevel:(CGFloat)zoomLevel {
    zoomLevel = MAX(0.5, zoomLevel);
    _zoomLevel = zoomLevel;
    
    CGFloat angle = 0.0;
    if (zoomLevel < 1.0) {
        CGFloat delta = (zoomLevel - 0.5) / 0.5;
        angle = TGDegreesToRadians(20.8) * (1.0 - delta);
    } else if (zoomLevel < 2.0) {
        CGFloat delta = zoomLevel - 1.0;
        angle = TGDegreesToRadians(-22.0) * delta;
    } else if (zoomLevel < 10.0) {
        CGFloat delta = (zoomLevel - 2.0) / 8.0;
        angle = TGDegreesToRadians(-22.0) + TGDegreesToRadians(-68.0) * delta;
    }
    
    _backgroundView.transform = CGAffineTransformMakeRotation(angle);
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

