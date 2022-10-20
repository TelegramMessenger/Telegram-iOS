#import "TGPhotoEditorLinearBlurView.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGPhotoEditorUtils.h>

const CGFloat TGLinearBlurInsetProximity = 20;
const CGFloat TGLinearBlurMinimumFalloff = 0.1f;
const CGFloat TGLinearBlurMinimumDifference = 0.02f;
const CGFloat TGLinearBlurViewCenterInset = 30.0f;
const CGFloat TGLinearBlurViewRadiusInset = 30.0f;

typedef enum {
    TGLinearBlurViewActiveControlNone,
    TGLinearBlurViewActiveControlCenter,
    TGLinearBlurViewActiveControlInnerRadius,
    TGLinearBlurViewActiveControlOuterRadius,
    TGLinearBlurViewActiveControlWholeArea,
    TGLinearBlurViewActiveControlRotation
} TGLinearBlurViewActiveControl;

@interface TGPhotoEditorLinearBlurView () <UIGestureRecognizerDelegate>
{
    UILongPressGestureRecognizer *_pressGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
    UIPinchGestureRecognizer *_pinchGestureRecognizer;
    
    TGLinearBlurViewActiveControl _activeControl;
    CGPoint _startCenterPoint;
    CGFloat _startDistance;
    CGFloat _startRadius;
}
@end

@implementation TGPhotoEditorLinearBlurView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        
        self.centerPoint = CGPointMake(0.5f, 0.5f);
        self.falloff = 0.15f;
        self.size = 0.35f;
        
        _pressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handlePress:)];
        _pressGestureRecognizer.delegate = self;
        _pressGestureRecognizer.minimumPressDuration = 0.1f;
        [self addGestureRecognizer:_pressGestureRecognizer];
        
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _panGestureRecognizer.delegate = self;
        [self addGestureRecognizer:_panGestureRecognizer];
        
        _pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
        _pinchGestureRecognizer.delegate = self;
        [self addGestureRecognizer:_pinchGestureRecognizer];
    }
    return self;
}

- (void)handlePress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
            [self setSelected:true animated:true];
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            [self setSelected:false animated:true];
            break;
            
        default:
            break;
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    CGPoint location = [gestureRecognizer locationInView:self];
    CGPoint centerPoint = [self _actualCenterPoint];
    CGPoint delta = CGPointMake(location.x - centerPoint.x, location.y - centerPoint.y);
    CGFloat radialDistance = CGSqrt(delta.x * delta.x + delta.y * delta.y);
    CGFloat distance = ABS(delta.x * CGCos(self.angle + (CGFloat)M_PI_2) + delta.y * CGSin(self.angle + (CGFloat)M_PI_2));
    
    CGFloat shorterSide = (self.actualAreaSize.width > self.actualAreaSize.height) ? self.actualAreaSize.height : self.actualAreaSize.width;
    
    CGFloat innerRadius = shorterSide * self.falloff;
    CGFloat outerRadius = shorterSide * self.size;
    
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            bool close = ABS(outerRadius - innerRadius) < TGLinearBlurInsetProximity;
            CGFloat innerRadiusOuterInset = close ? 0 : TGLinearBlurViewRadiusInset;
            CGFloat outerRadiusInnerInset = close ? 0 : TGLinearBlurViewRadiusInset;
            
            if (radialDistance < TGLinearBlurViewCenterInset)
            {
                _activeControl = TGLinearBlurViewActiveControlCenter;
                _startCenterPoint = centerPoint;
            }
            else if (distance > innerRadius - TGLinearBlurViewRadiusInset && distance < innerRadius + innerRadiusOuterInset)
            {
                _activeControl = TGLinearBlurViewActiveControlInnerRadius;
                _startDistance = distance;
                _startRadius = innerRadius;
            }
            else if (distance > outerRadius - outerRadiusInnerInset && distance < outerRadius + TGLinearBlurViewRadiusInset)
            {
                _activeControl = TGLinearBlurViewActiveControlOuterRadius;
                _startDistance = distance;
                _startRadius = outerRadius;
            }
            else if (distance <= innerRadius - TGLinearBlurViewRadiusInset || distance >= outerRadius + TGLinearBlurViewRadiusInset)
            {
                _activeControl = TGLinearBlurViewActiveControlRotation;
            }
            
            [self setSelected:true animated:true];
        }
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            switch (_activeControl)
            {
                case TGLinearBlurViewActiveControlCenter:
                {
                    CGPoint translation = [gestureRecognizer translationInView:self];
                    
                    CGRect actualArea = CGRectMake((self.frame.size.width - self.actualAreaSize.width) / 2, (self.frame.size.height - self.actualAreaSize.height) / 2, self.actualAreaSize.width, self.actualAreaSize.height);
                    
                    CGPoint newPoint = CGPointMake(MAX(CGRectGetMinX(actualArea), MIN(CGRectGetMaxX(actualArea), _startCenterPoint.x + translation.x)),
                                                   MAX(CGRectGetMinY(actualArea), MIN(CGRectGetMaxY(actualArea), _startCenterPoint.y + translation.y)));
                    
                    CGPoint offset = CGPointMake(0, (self.actualAreaSize.width - self.actualAreaSize.height) / 2);
                    CGPoint actualPoint = CGPointMake(newPoint.x - actualArea.origin.x, newPoint.y - actualArea.origin.y);
                    self.centerPoint = CGPointMake((actualPoint.x + offset.x) / self.actualAreaSize.width, (actualPoint.y + offset.y) / self.actualAreaSize.width);
                }
                    break;
                    
                case TGLinearBlurViewActiveControlInnerRadius:
                {
                    CGFloat delta = distance - _startDistance;
                    self.falloff = MIN(MAX(TGLinearBlurMinimumFalloff, (_startRadius + delta) / shorterSide), self.size - TGLinearBlurMinimumDifference);
                }
                    break;
                    
                case TGLinearBlurViewActiveControlOuterRadius:
                {
                    CGFloat delta = distance - _startDistance;
                    self.size = MAX(self.falloff + TGLinearBlurMinimumDifference, (_startRadius + delta) / shorterSide);
                }
                    break;
                    
                case TGLinearBlurViewActiveControlRotation:
                {
                    CGPoint translation = [gestureRecognizer translationInView:self];
                    bool clockwise = false;
                    
                    bool right = location.x > centerPoint.x;
                    bool bottom = location.y > centerPoint.y;
                    
                    if (!right && !bottom)
                    {
                        if (ABS(translation.y) > ABS(translation.x))
                        {
                            if (translation.y < 0)
                                clockwise = true;
                        }
                        else
                        {
                            if (translation.x > 0)
                                clockwise = true;
                        }
                    }
                    else if (right && !bottom)
                    {
                        if (ABS(translation.y) > ABS(translation.x))
                        {
                            if (translation.y > 0)
                                clockwise = true;
                        }
                        else
                        {
                            if (translation.x > 0)
                                clockwise = true;
                        }
                    }
                    else if (right && bottom)
                    {
                        if (ABS(translation.y) > ABS(translation.x))
                        {
                            if (translation.y > 0)
                                clockwise = true;
                        }
                        else
                        {
                            if (translation.x < 0)
                                clockwise = true;
                        }
                    }
                    else
                    {
                        if (ABS(translation.y) > ABS(translation.x))
                        {
                            if (translation.y < 0)
                                clockwise = true;
                        }
                        else
                        {
                            if (translation.x < 0)
                                clockwise = true;
                        }
                    }
                    
                    CGFloat delta = CGSqrt(translation.x * translation.x + translation.y * translation.y);
                    
                    CGFloat angleInDegrees = TGRadiansToDegrees(_angle);
                    CGFloat newAngleInDegrees = angleInDegrees + delta * (clockwise * 2 - 1) / (CGFloat)M_PI / 1.15f;
                    
                    _angle = TGDegreesToRadians(newAngleInDegrees);
                    
                    [gestureRecognizer setTranslation:CGPointZero inView:self];
                }
                    break;
                    
                default:
                    break;
            }
            
            [self setNeedsDisplay];
            
            if (self.valueChanged != nil)
                self.valueChanged(self.centerPoint, self.falloff, self.size, self.angle);
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        {
            _activeControl = TGLinearBlurViewActiveControlNone;
            
            [self setSelected:false animated:true];
            
            if (self.interactionEnded != nil)
                self.interactionEnded();
        }
            break;
            
        default:
            break;
    }
}

- (void)handlePinch:(UIPinchGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            _activeControl = TGLinearBlurViewActiveControlWholeArea;
            
            [self setSelected:true animated:true];
        }
        case UIGestureRecognizerStateChanged:
        {
            CGFloat scale = gestureRecognizer.scale;
            
            self.falloff = MAX(TGLinearBlurMinimumFalloff, self.falloff * scale);
            self.size = MAX(self.falloff + TGLinearBlurMinimumDifference, self.size * scale);
            
            gestureRecognizer.scale = 1.0f;
            
            [self setNeedsDisplay];
            
            if (self.valueChanged != nil)
                self.valueChanged(self.centerPoint, self.falloff, self.size, self.angle);
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        {
            _activeControl = TGLinearBlurViewActiveControlNone;
            
            [self setSelected:false animated:true];
        }
            break;
            
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        {
            _activeControl = TGLinearBlurViewActiveControlNone;
            
            [self setSelected:false animated:true];
        }
            break;
            
        default:
            break;
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == _pressGestureRecognizer || gestureRecognizer == _panGestureRecognizer)
    {
        CGPoint location = [gestureRecognizer locationInView:self];
        CGPoint centerPoint = [self _actualCenterPoint];
        CGPoint delta = CGPointMake(location.x - centerPoint.x, location.y - centerPoint.y);
        CGFloat radialDistance = CGSqrt(delta.x * delta.x + delta.y * delta.y);
        CGFloat distance = ABS(delta.x * CGCos(self.angle + (CGFloat)M_PI_2) + delta.y * CGSin(self.angle + (CGFloat)M_PI_2));
        
        CGFloat innerRadius = [self _actualInnerRadius];
        CGFloat outerRadius = [self _actualOuterRadius];
        
        bool close = ABS(outerRadius - innerRadius) < TGLinearBlurInsetProximity;
        CGFloat innerRadiusOuterInset = close ? 0 : TGLinearBlurViewRadiusInset;
        CGFloat outerRadiusInnerInset = close ? 0 : TGLinearBlurViewRadiusInset;
        
        if (radialDistance < TGLinearBlurViewCenterInset && gestureRecognizer == _panGestureRecognizer)
            return true;
        else if (distance > innerRadius - TGLinearBlurViewRadiusInset && distance < innerRadius + innerRadiusOuterInset)
            return true;
        else if (distance > outerRadius - outerRadiusInnerInset && distance < outerRadius + TGLinearBlurViewRadiusInset)
            return true;
        else if ((distance <= innerRadius - TGLinearBlurViewRadiusInset) || distance >= outerRadius + TGLinearBlurViewRadiusInset)
            return true;
        
        return false;
    }
    
    return true;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer == _pressGestureRecognizer || otherGestureRecognizer == _pressGestureRecognizer)
        return true;
    
    return false;
}

- (void)setSelected:(bool)selected animated:(bool)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.16f delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            self.alpha = selected ? 0.6f : 1.0f;
        } completion:nil];
    }
    else
    {
        self.alpha = selected ? 0.6f : 1.0f;
    }
}

- (void)drawRect:(CGRect)__unused rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGPoint centerPoint = [self _actualCenterPoint];
    CGFloat innerRadius = [self _actualInnerRadius];
    CGFloat outerRadius = [self _actualOuterRadius];
    
    CGContextTranslateCTM(context, centerPoint.x, centerPoint.y);
    CGContextRotateCTM(context, self.angle);
    
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetShadowWithColor(context, CGSizeZero, 2.5f, [UIColor colorWithWhite:0.0f alpha:0.3f].CGColor);
    
    CGFloat space = 6.0f;
    CGFloat length = 12.0f;
    CGFloat thickness = 1.5f;
    for (NSInteger i = 0; i < 30; i++)
    {
        CGContextAddRect(context, CGRectMake(i * (length + space), -innerRadius, length, thickness));
        CGContextAddRect(context, CGRectMake(-i * (length + space) - space - length, -innerRadius, length, thickness));
        
        CGContextAddRect(context, CGRectMake(i * (length + space), innerRadius, length, thickness));
        CGContextAddRect(context, CGRectMake(-i * (length + space) - space - length, innerRadius, length, thickness));
    }
    
    length = 6.0f;
    thickness = 1.5f;
    for (NSInteger i = 0; i < 64; i++)
    {
        CGContextAddRect(context, CGRectMake(i * (length + space), -outerRadius, length, thickness));
        CGContextAddRect(context, CGRectMake(-i * (length + space) - space - length, -outerRadius, length, thickness));
        
        CGContextAddRect(context, CGRectMake(i * (length + space), outerRadius, length, thickness));
        CGContextAddRect(context, CGRectMake(-i * (length + space) - space - length, outerRadius, length, thickness));
    }
    
    CGContextFillPath(context);
    
    CGContextFillEllipseInRect(context, CGRectMake(-16 / 2, - 16 / 2, 16, 16));
}

- (CGPoint)_actualCenterPoint
{
    CGRect actualArea = CGRectMake((self.frame.size.width - self.actualAreaSize.width) / 2, (self.frame.size.height - self.actualAreaSize.height) / 2, self.actualAreaSize.width, self.actualAreaSize.height);
    CGPoint offset = CGPointMake(0, (self.actualAreaSize.width - self.actualAreaSize.height) / 2);
    return CGPointMake(actualArea.origin.x - offset.x + self.centerPoint.x * self.actualAreaSize.width, actualArea.origin.y - offset.y + self.centerPoint.y * self.actualAreaSize.width);
}

- (CGFloat)_actualInnerRadius
{
    CGFloat shorterSide = (self.actualAreaSize.width > self.actualAreaSize.height) ? self.actualAreaSize.height : self.actualAreaSize.width;
    return shorterSide * self.falloff;;
}

- (CGFloat)_actualOuterRadius
{
    CGFloat shorterSide = (self.actualAreaSize.width > self.actualAreaSize.height) ? self.actualAreaSize.height : self.actualAreaSize.width;
    return shorterSide * self.size;
}

@end
