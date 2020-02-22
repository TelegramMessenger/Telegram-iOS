#import "TGCameraZoomView.h"
#import "TGCameraInterfaceAssets.h"

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
