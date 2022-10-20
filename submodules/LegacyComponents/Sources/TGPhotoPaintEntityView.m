#import "TGPhotoPaintEntityView.h"

#import "TGPhotoEntitiesContainerView.h"
#import <LegacyComponents/TGPaintUtils.h>

const CGFloat TGPhotoPaintEntityMinScale = 0.12f;

@interface TGPhotoPaintEntityView () <UIGestureRecognizerDelegate>
{
    UIPanGestureRecognizer *_panGestureRecognizer;
    
    bool _measuring;
    CGFloat _realScale;
    CGAffineTransform _realTransform;
}
@end

@implementation TGPhotoPaintEntityView

@dynamic entity;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.contentScaleFactor = MIN(2.0f, self.contentScaleFactor);
        
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _panGestureRecognizer.delegate = self;
        [self addGestureRecognizer:_panGestureRecognizer];
    }
    return self;
}

- (NSInteger)entityUUID
{
    return _entityUUID;
}

- (void)_pushIdentityTransformForMeasurement
{
    if (_measuring)
        return;
    
    _measuring = true;
    _realTransform = self.transform;
    _realScale = [[self.layer valueForKeyPath:@"transform.scale.x"] floatValue];
    self.transform = CGAffineTransformIdentity;
}

- (void)_popIdentityTransformForMeasurement
{
    if (!_measuring)
        return;
    
    _measuring = false;
    self.transform = _realTransform;
    
    _realTransform = CGAffineTransformIdentity;
    _realScale = 1.0f;
}

- (CGFloat)angle
{
    return atan2(self.transform.b, self.transform.a);
}

- (CGFloat)scale
{
    if (_measuring)
        return _realScale;
    
    return [[self.layer valueForKeyPath:@"transform.scale.x"] floatValue];
}

- (void)_notifyOfChange
{
    if (self.entityChanged != nil)
        self.entityChanged(self);
}

- (void)pan:(CGPoint)point absolute:(bool)absolute
{
    if (absolute)
        self.center = point;
    else
        self.center = TGPaintAddPoints(self.center, point);
    
    [self _notifyOfChange];
}

- (void)rotate:(CGFloat)angle absolute:(bool)absolute
{
    CGFloat deltaAngle = angle;
    if (absolute)
        deltaAngle = angle - self.angle;
    self.transform = CGAffineTransformRotate(self.transform, deltaAngle);
    
    [self _notifyOfChange];
}

- (void)scale:(CGFloat)scale absolute:(bool)__unused absolute
{
    CGFloat newScale = self.scale * scale;
    
    if (newScale < TGPhotoPaintEntityMinScale)
        scale = self.scale / TGPhotoPaintEntityMinScale;
    
    self.transform = CGAffineTransformScale(self.transform, scale, scale);
    
    [self _notifyOfChange];
}

- (bool)inhibitGestures
{
    return _panGestureRecognizer.enabled;
}

- (void)setInhibitGestures:(bool)inhibitGestures
{
    _panGestureRecognizer.enabled = !inhibitGestures;
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            if (self.entityBeganDragging != nil)
                self.entityBeganDragging(self);
        }
        case UIGestureRecognizerStateChanged:
        {
            CGPoint translation = [gestureRecognizer translationInView:self.superview];
            [self pan:translation absolute:false];
            [gestureRecognizer setTranslation:CGPointZero inView:self.superview];
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        {
            [self _notifyOfChange];
        }
            break;
            
        default:
            break;
    }
}

- (bool)precisePointInside:(CGPoint)point
{
    return [self pointInside:point withEvent:nil];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)__unused gestureRecognizer
{
    if (self.shouldTouchEntity != nil)
        return self.shouldTouchEntity(self);
    
    return true;
}

- (CGRect)selectionBounds
{
    return self.bounds;
}

- (TGPhotoPaintEntitySelectionView *)createSelectionView
{
    return nil;
}

- (bool)isTracking
{
    bool panTracking = (_panGestureRecognizer.state == UIGestureRecognizerStateBegan || _panGestureRecognizer.state == UIGestureRecognizerStateChanged);
    bool selectionTracking = self.selectionView.isTracking;
    
    return panTracking || selectionTracking;
}

@end


@implementation TGPhotoPaintEntitySelectionView

- (void)update
{
    TGPhotoPaintEntityView *entityView = self.entityView;
    
    [entityView _pushIdentityTransformForMeasurement];
    self.transform = CGAffineTransformIdentity;
    CGRect bounds = entityView.selectionBounds;
    CGPoint center = TGPaintCenterOfRect(bounds);
    
    CGFloat scale = [[entityView.superview.superview.layer valueForKeyPath:@"transform.scale.x"] floatValue];
    self.center = [entityView convertPoint:center toView:self.superview];
    self.bounds = CGRectMake(0.0f, 0.0f, bounds.size.width * scale, bounds.size.height * scale);
    [entityView _popIdentityTransformForMeasurement];
    
    self.transform = CGAffineTransformMakeRotation(entityView.angle);
}

- (void)fadeIn
{
    self.alpha = 0.0f;
    [UIView animateWithDuration:0.18 animations:^
    {
        self.alpha = 1.0f;
    }];
}

- (void)fadeOut
{
    [UIView animateWithDuration:0.18 animations:^
    {
        self.alpha = 0.0f;
    }];
}

@end

@implementation UIView (PixelColor)

- (UIColor *)colorAtPoint:(CGPoint)point
{
    if (point.x > self.bounds.size.width || point.y > self.bounds.size.height)
        return nil;
    
    unsigned char pixel[4] = {0};
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, colorSpace, kCGBitmapAlphaInfoMask & kCGImageAlphaPremultipliedLast);
    
    CGContextTranslateCTM(context, -point.x, -point.y);
    
    [self.layer renderInContext:context];
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    return [UIColor colorWithRed:pixel[0] / 255.0 green:pixel[1] / 255.0 blue:pixel[2] / 255.0 alpha:pixel[3] / 255.0];
}

@end
