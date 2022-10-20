#import "TGPhotoEditorRadialBlurView.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGPhotoEditorUtils.h>

const CGFloat TGRadialBlurInsetProximity = 20;
const CGFloat TGRadialBlurMinimumFalloff = 0.1f;
const CGFloat TGRadialBlurMinimumDifference = 0.02f;
const CGFloat TGRadialBlurViewCenterInset = 30.0f;
const CGFloat TGRadialBlurViewRadiusInset = 30.0f;

typedef enum {
    TGRadialBlurViewActiveControlNone,
    TGRadialBlurViewActiveControlCenter,
    TGRadialBlurViewActiveControlInnerRadius,
    TGRadialBlurViewActiveControlOuterRadius,
    TGRadialBlurViewActiveControlWholeArea
} TGRadialBlurViewActiveControl;

@interface TGPhotoEditorRadialBlurView () <UIGestureRecognizerDelegate>
{
    UILongPressGestureRecognizer *_pressGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
    UIPinchGestureRecognizer *_pinchGestureRecognizer;
    
    TGRadialBlurViewActiveControl _activeControl;
    CGPoint _startCenterPoint;
    CGFloat _startDistance;
    CGFloat _startRadius;
}
@end

@implementation TGPhotoEditorRadialBlurView

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
    CGFloat distance = CGSqrt(delta.x * delta.x + delta.y * delta.y);
    
    CGFloat shorterSide = (self.actualAreaSize.width > self.actualAreaSize.height) ? self.actualAreaSize.height : self.actualAreaSize.width;
    
    CGFloat innerRadius = shorterSide * self.falloff;
    CGFloat outerRadius = shorterSide * self.size;
    
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            bool close = ABS(outerRadius - innerRadius) < TGRadialBlurInsetProximity;
            CGFloat innerRadiusOuterInset = close ? 0 : TGRadialBlurViewRadiusInset;
            CGFloat outerRadiusInnerInset = close ? 0 : TGRadialBlurViewRadiusInset;
            
            if (distance < TGRadialBlurViewCenterInset)
            {
                _activeControl = TGRadialBlurViewActiveControlCenter;
                _startCenterPoint = centerPoint;
            }
            else if (distance > innerRadius - TGRadialBlurViewRadiusInset && distance < innerRadius + innerRadiusOuterInset)
            {
                _activeControl = TGRadialBlurViewActiveControlInnerRadius;
                _startDistance = distance;
                _startRadius = innerRadius;
            }
            else if (distance > outerRadius - outerRadiusInnerInset && distance < outerRadius + TGRadialBlurViewRadiusInset)
            {
                _activeControl = TGRadialBlurViewActiveControlOuterRadius;
                _startDistance = distance;
                _startRadius = outerRadius;
            }
            
            [self setSelected:true animated:true];
        }
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            switch (_activeControl)
            {
                case TGRadialBlurViewActiveControlCenter:
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
                    
                case TGRadialBlurViewActiveControlInnerRadius:
                {
                    CGFloat delta = distance - _startDistance;
                    self.falloff = MIN(MAX(TGRadialBlurMinimumFalloff, (_startRadius + delta) / shorterSide), self.size - TGRadialBlurMinimumDifference);
                }
                    break;
                    
                case TGRadialBlurViewActiveControlOuterRadius:
                {
                    CGFloat delta = distance - _startDistance;
                    self.size = MAX(self.falloff + TGRadialBlurMinimumDifference, (_startRadius + delta) / shorterSide);
                }
                    break;
                    
                default:
                    break;
            }
            
            [self setNeedsDisplay];
            
            if (self.valueChanged != nil)
                self.valueChanged(self.centerPoint, self.falloff, self.size);
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        {
            _activeControl = TGRadialBlurViewActiveControlNone;
            
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
            _activeControl = TGRadialBlurViewActiveControlWholeArea;
            
            [self setSelected:true animated:true];
        }
        case UIGestureRecognizerStateChanged:
        {
            CGFloat scale = gestureRecognizer.scale;
            
            self.falloff = MAX(TGRadialBlurMinimumFalloff, self.falloff * scale);
            self.size = MAX(self.falloff + TGRadialBlurMinimumDifference, self.size * scale);
            
            gestureRecognizer.scale = 1.0f;
            
            [self setNeedsDisplay];
            
            if (self.valueChanged != nil)
                self.valueChanged(self.centerPoint, self.falloff, self.size);
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        {
            _activeControl = TGRadialBlurViewActiveControlNone;
            
            [self setSelected:false animated:true];
        }
            break;
            
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
        {
            _activeControl = TGRadialBlurViewActiveControlNone;
            
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
        
        CGFloat distance = CGSqrt(delta.x * delta.x + delta.y * delta.y);
        
        CGFloat innerRadius = [self _actualInnerRadius];
        CGFloat outerRadius = [self _actualOuterRadius];
        
        bool close = ABS(outerRadius - innerRadius) < TGRadialBlurInsetProximity;
        CGFloat innerRadiusOuterInset = close ? 0 : TGRadialBlurViewRadiusInset;
        CGFloat outerRadiusInnerInset = close ? 0 : TGRadialBlurViewRadiusInset;
        
        if (distance < TGRadialBlurViewCenterInset && gestureRecognizer == _panGestureRecognizer)
            return true;
        else if (distance > innerRadius - TGRadialBlurViewRadiusInset && distance < innerRadius + innerRadiusOuterInset)
            return true;
        else if (distance > outerRadius - outerRadiusInnerInset && distance < outerRadius + TGRadialBlurViewRadiusInset)
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
        
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetShadowWithColor(context, CGSizeZero, 2.5f, [UIColor colorWithWhite:0.0f alpha:0.3f].CGColor);
    
    CGFloat radSpace = TGDegreesToRadians(6.15f);
    CGFloat radLen = TGDegreesToRadians(10.2f);
    for (NSInteger i = 0; i < 22; i++)
    {
        CGMutablePathRef path = CGPathCreateMutable();
        CGPathAddArc(path, NULL, centerPoint.x, centerPoint.y, innerRadius,
                     i * (radSpace + radLen), i * (radSpace + radLen) + radLen, false);
        
        CGPathRef strokedArc = CGPathCreateCopyByStrokingPath(path, NULL, 1.5f, kCGLineCapButt, kCGLineJoinMiter, 10);
        
        CGContextAddPath(context, strokedArc);
        
        CGPathRelease(strokedArc);
        CGPathRelease(path);
    }
    
    radSpace = TGDegreesToRadians(2.02f);
    radLen = TGDegreesToRadians(3.6f);
    for (NSInteger i = 0; i < 64; i++)
    {
        CGMutablePathRef path = CGPathCreateMutable();
        
        CGPathAddArc(path, NULL, centerPoint.x, centerPoint.y, outerRadius,
                     i * (radSpace + radLen), i * (radSpace + radLen) + radLen, false);
        
        CGPathRef strokedArc = CGPathCreateCopyByStrokingPath(path, NULL, 1.5f, kCGLineCapButt, kCGLineJoinMiter, 10);
        
        CGContextAddPath(context, strokedArc);
        
        CGPathRelease(strokedArc);
        CGPathRelease(path);
    }
    
    CGContextFillPath(context);
    
    CGContextFillEllipseInRect(context, CGRectMake(centerPoint.x - 16 / 2, centerPoint.y - 16 / 2, 16, 16));
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
