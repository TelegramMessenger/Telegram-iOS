#import "TGPhotoCropScrollView.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGPhotoEditorAnimation.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>

typedef struct {
    CGPoint tl, tr, bl, br;
} TGPhotoCropRectangle;

@interface TGPhotoCropScrollView () <UIGestureRecognizerDelegate>
{
    UIView *_wrapperView;
    
    UILongPressGestureRecognizer *_pressGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
    UIPinchGestureRecognizer *_pinchGestureRecognizer;
    
    UIView *_snapshotClipView;
    UIImageView *_snapshotView;
    UIImageView *_paintingImageView;
    
    UIImage *_paintingImage;
    
    bool _beganInteraction;
    bool _endedInteraction;
    bool _fitted;
    bool _isTracking;
    
    CGPoint _touchCenter;
    CGPoint _pinchCenter;
    
    CGFloat _pinchStartScale;
    
    CGFloat _rotationStartScale;
    bool _mirrored;
}
@end

@implementation TGPhotoCropScrollView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor blackColor];
        
        _maximumZoomScale = 10.0f;
        
        _wrapperView = [[UIView alloc] initWithFrame:CGRectZero];
        if (iosMajorVersion() >= 7)
            _wrapperView.layer.allowsEdgeAntialiasing = true;
        [self addSubview:_wrapperView];
        
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

#pragma mark - Content

- (void)setHidden:(BOOL)hidden
{
    [super setHidden:hidden];
    _snapshotClipView.hidden = hidden;
}

- (void)setContentSize:(CGSize)contentSize
{
    _contentSize = contentSize;
    _wrapperView.frame = CGRectMake(0, 0, contentSize.width, contentSize.height);
}

- (CGFloat)contentRotation
{
    return [[_wrapperView.layer valueForKeyPath:@"transform.rotation.z"] floatValue];
}

- (CGFloat)contentScale
{
    return [[_wrapperView.layer valueForKeyPath:@"transform.scale.x"] floatValue];
}

- (CGAffineTransform)cropTransform
{
    CATransform3D transform3d = _wrapperView.layer.transform;
    CGAffineTransform currentTransform = CGAffineTransformMake(transform3d.m11, transform3d.m12,
                                                               transform3d.m21, transform3d.m22,
                                                               transform3d.m41, transform3d.m42);
    return currentTransform;
}

- (void)setContentRotation:(CGFloat)contentRotation
{
    [self setContentRotation:contentRotation maximize:false resetting:false];
}

- (void)setContentRotation:(CGFloat)contentRotation maximize:(bool)maximize resetting:(bool)resetting
{
    CGPoint rotationCenter = [self convertPoint:CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2) toView:_wrapperView];
    
    CGPoint delta = CGPointMake(rotationCenter.x - _wrapperView.bounds.size.width / 2,
                                rotationCenter.y - _wrapperView.bounds.size.height / 2);
    
    CATransform3D transform = CATransform3DTranslate(_wrapperView.layer.transform, delta.x, delta.y, 0.0f);
    transform = CATransform3DRotate(transform, contentRotation - self.contentRotation, 0.0f, 0.0f, 1.0f);
    transform = CATransform3DTranslate(transform, -delta.x, -delta.y, 0.0f);
    
    _wrapperView.layer.transform = transform;
    _snapshotView.superview.layer.transform = transform;
    
    if (!resetting)
        [self fitContentInsideBoundsAllowScale:true maximize:maximize animated:false completion:nil];
}

- (void)setContentMirrored:(bool)mirrored
{
    _mirrored = mirrored;
    _contentView.transform = CGAffineTransformMakeScale(mirrored ? -1.0f : 1.0f, 1.0f);
}

- (void)setContentView:(UIView *)contentView
{
    [_contentView removeFromSuperview];
    
    _contentView = contentView;
    [_wrapperView addSubview:contentView];
    
    _contentView.frame = CGRectMake(0, 0, _contentSize.width, _contentSize.height);
    
    if (_mirrored)
        _contentView.transform = CGAffineTransformMakeScale(-1.0f, 1.0f);
    
    [self resetAndSetBounds:true];
}

- (CGRect)availableRect
{
    if (ABS(self.contentRotation) < FLT_EPSILON)
        return CGRectMake(0, 0, _contentSize.width, _contentSize.height);
    else
        return self.zoomedRect;
}

- (CGRect)zoomedRect
{
    CGSize rotatedContentSize = TGRotatedContentSize(_contentSize, self.contentRotation);
    CGSize rotationScaleRatios = CGSizeMake(rotatedContentSize.width / _contentSize.width,
                                            rotatedContentSize.height / _contentSize.height);
    
    UIView *convertView = [[UIView alloc] initWithFrame:CGRectMake((self.bounds.size.width - _contentSize.width) / 2,
                                                                   (self.bounds.size.height - _contentSize.height) / 2,
                                                                   _contentSize.width,
                                                                   _contentSize.height)];
    
    CGAffineTransform transform = CGAffineTransformMakeScale(_wrapperView.frame.size.width / _contentSize.width / rotationScaleRatios.width, _wrapperView.frame.size.height / _contentSize.height / rotationScaleRatios.height);
    convertView.transform = transform;
    convertView.frame = CGRectOffset(convertView.frame, _wrapperView.frame.origin.x - convertView.frame.origin.x, _wrapperView.frame.origin.y - convertView.frame.origin.y);
    [self addSubview:convertView];
    
    CGRect rect = [self convertRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height) toView:convertView];
    [convertView removeFromSuperview];

    return rect;
}

- (void)translateContentViewWithOffset:(CGPoint)offset
{
    CGFloat scale = self.contentScale;
    offset.x /= scale;
    offset.y /= scale;
    
    CGPoint xComp = CGPointMake(CGSin((CGFloat)M_PI_2 + self.contentRotation) * offset.x,
                                CGCos((CGFloat)M_PI_2 + self.contentRotation) * offset.x);
    CGPoint yComp = CGPointMake(CGCos((CGFloat)M_PI_2 - self.contentRotation) * offset.y,
                                CGSin((CGFloat)M_PI_2 - self.contentRotation) * offset.y);

    _wrapperView.transform = CGAffineTransformTranslate(_wrapperView.transform, xComp.x + yComp.x, xComp.y + yComp.y);
    _snapshotView.superview.transform = _wrapperView.transform;
}

- (void)fitContentInsideBoundsAllowScale:(bool)allowScale animated:(bool)animated completion:(void (^)(void))completion
{
    [self fitContentInsideBoundsAllowScale:allowScale maximize:false animated:animated completion:completion];
}

- (void)fitContentInsideBoundsAllowScale:(bool)allowScale maximize:(bool)maximize animated:(bool)animated completion:(void (^)(void))completion
{
    CGRect boundsRect = [self boundingBoxForRect:self.bounds withRotation:self.contentRotation];
    CGRect initialRect = CGRectMake(0, 0, _contentSize.width, _contentSize.height);
    CGPoint initialOffset = CGPointMake((self.bounds.size.width - _contentSize.width) / 2, (self.bounds.size.height - _contentSize.height) / 2);
    
    CGAffineTransform currentTransform = self.cropTransform;
    
    CGPoint centerOffset = CGPointMake(_wrapperView.center.x - CGRectGetMidX(boundsRect), _wrapperView.center.y - CGRectGetMidY(boundsRect));
    
    CGPoint xComp = CGPointMake(CGSin((CGFloat)M_PI_2 + self.contentRotation) * centerOffset.x,
                                CGCos((CGFloat)M_PI_2 + self.contentRotation) * centerOffset.x);
    CGPoint yComp = CGPointMake(CGCos((CGFloat)M_PI_2 - self.contentRotation) * centerOffset.y,
                                CGSin((CGFloat)M_PI_2 - self.contentRotation) * centerOffset.y);
    
    CGFloat contentScale = self.contentScale;
    TGPhotoCropRectangle r2 = [self applyTransform:CGAffineTransformTranslate(currentTransform,
                                                                              (initialOffset.x + xComp.x + yComp.x) / contentScale,
                                                                              (initialOffset.y + xComp.y + yComp.y) / contentScale) toRect:initialRect];
    
    CGAffineTransform t = CGAffineTransformMakeTranslation(_contentSize.width / 2, _contentSize.height / 2);
    t = CGAffineTransformRotate(t, -self.contentRotation);
    t = CGAffineTransformTranslate(t, -_contentSize.width / 2, -_contentSize.height / 2);
    
    TGPhotoCropRectangle r3 = [self applyTransform:t toRectangle:r2];
    __block CGRect contentRect = [self CGRectFromRectangle:r3];
    
    __block CGPoint targetTranslation = [[_wrapperView.layer valueForKeyPath:@"transform.translation"] CGPointValue];
    __block CGFloat targetScale = contentScale;
    __block CATransform3D targetTransform = _wrapperView.layer.transform;
    
    void (^fitScaleBlock)(CGFloat) = ^(CGFloat ratio)
    {
        CGSize scaledSize = CGSizeMake(contentRect.size.width * ratio, contentRect.size.height * ratio);
        CGPoint scaledOffset = CGPointMake((contentRect.size.width - scaledSize.width) / 2, (contentRect.size.height - scaledSize.height) / 2);
        contentRect = CGRectMake(contentRect.origin.x + scaledOffset.x, contentRect.origin.y + scaledOffset.y, scaledSize.width, scaledSize.height);
    
        targetTransform = CATransform3DScale(targetTransform, ratio, ratio, 1.0f);
        
        targetScale *= ratio;
    };
    
    void (^fitTranslationBlock)(void) = ^
    {
        CGPoint contentTL = CGPointMake(CGRectGetMinX(contentRect), CGRectGetMinY(contentRect));
        CGPoint contentBR = CGPointMake(CGRectGetMaxX(contentRect), CGRectGetMaxY(contentRect));
        
        CGPoint frameTL = CGPointMake(CGRectGetMinX(boundsRect), CGRectGetMinY(boundsRect));
        CGPoint frameBR = CGPointMake(CGRectGetMaxX(boundsRect), CGRectGetMaxY(boundsRect));
        
        if (contentTL.x > frameTL.x)
            frameTL.x = contentTL.x;
        if (contentTL.y > frameTL.y)
            frameTL.y = contentTL.y;
        
        if (contentBR.x < frameBR.x)
            frameTL.x += contentBR.x - frameBR.x;
        if (contentBR.y < frameBR.y)
            frameTL.y += contentBR.y - frameBR.y;
        
        CGRect validBoundsRect = CGRectMake(frameTL.x, frameTL.y, boundsRect.size.width, boundsRect.size.height);
        CGPoint delta = CGPointMake(CGRectGetMidX(boundsRect) - CGRectGetMidX(validBoundsRect),
                                    CGRectGetMidY(boundsRect) - CGRectGetMidY(validBoundsRect));
        
        targetTransform = CATransform3DTranslate(targetTransform, delta.x / targetScale, delta.y / targetScale, 0.0f);
        
        CGPoint xComp = CGPointMake(CGSin((CGFloat)M_PI_2 - self.contentRotation) * delta.x,
                                    CGCos((CGFloat)M_PI_2 - self.contentRotation) * delta.x);
        CGPoint yComp = CGPointMake(CGCos((CGFloat)M_PI_2 + self.contentRotation) * delta.y,
                                    CGSin((CGFloat)M_PI_2 + self.contentRotation) * delta.y);
        
        targetTranslation.x += xComp.x + yComp.x;
        targetTranslation.y += xComp.y + yComp.y;
    };
    
    void (^applyBlock)(void) = ^
    {
        if (animated)
        {
            CGPoint translation = [[_wrapperView.layer valueForKeyPath:@"transform.translation"] CGPointValue];
            POPSpringAnimation *translationAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerTranslationXY];
            translationAnimation.fromValue = [NSValue valueWithCGPoint:translation];
            translationAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(targetTranslation.x, targetTranslation.y)];
            translationAnimation.springSpeed = 7;
            translationAnimation.springBounciness = 1;
            
            POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
            scaleAnimation.fromValue = [NSValue valueWithCGSize:CGSizeMake(self.contentScale, self.contentScale)];
            scaleAnimation.toValue = [NSValue valueWithCGSize:CGSizeMake(targetScale, targetScale)];
            scaleAnimation.springSpeed = 7;
            scaleAnimation.springBounciness = 1;
            
            POPSpringAnimation *snapshotTranslationAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerTranslationXY];
            snapshotTranslationAnimation.fromValue = [NSValue valueWithCGPoint:translation];
            snapshotTranslationAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(targetTranslation.x, targetTranslation.y)];
            snapshotTranslationAnimation.springSpeed = 7;
            snapshotTranslationAnimation.springBounciness = 1;
            
            POPSpringAnimation *snapshotScaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
            snapshotScaleAnimation.fromValue = [NSValue valueWithCGSize:CGSizeMake(self.contentScale, self.contentScale)];
            snapshotScaleAnimation.toValue = [NSValue valueWithCGSize:CGSizeMake(targetScale, targetScale)];
            snapshotScaleAnimation.springSpeed = 7;
            snapshotScaleAnimation.springBounciness = 1;
            
            _animating = true;
            [TGPhotoEditorAnimation performBlock:^(__unused bool allFinished)
            {
                _animating = false;
                
                if (completion != nil)
                    completion();
            } whenCompletedAllAnimations:@[ translationAnimation, scaleAnimation ]];
            
            [_wrapperView.layer pop_addAnimation:translationAnimation forKey:@"translation"];
            [_wrapperView.layer pop_addAnimation:scaleAnimation forKey:@"scale"];
            
            _snapshotView.superview.layer.transform = _wrapperView.layer.transform;
            [_snapshotView.superview.layer pop_addAnimation:snapshotTranslationAnimation forKey:@"translation"];
            [_snapshotView.superview.layer pop_addAnimation:snapshotScaleAnimation forKey:@"scale"];
        }
        else
        {
            _wrapperView.layer.transform = targetTransform;
            _snapshotView.superview.layer.transform = targetTransform;
            
            if (completion != nil)
                completion();
        }
    };
    
    if (!CGRectContainsRect(contentRect, boundsRect))
    {
        if (allowScale && (boundsRect.size.width > contentRect.size.width || boundsRect.size.height > contentRect.size.height))
            fitScaleBlock(boundsRect.size.width / TGScaleToSize(boundsRect.size, contentRect.size).width);
        
        fitTranslationBlock();
        applyBlock();
    }
    else
    {
        if (maximize && _rotationStartScale > FLT_EPSILON)
        {
            CGFloat ratio = boundsRect.size.width / TGScaleToSize(boundsRect.size, contentRect.size).width;
            CGFloat newScale = self.contentScale * ratio;
            if (newScale < _rotationStartScale)
                ratio = 1.0f;

            fitScaleBlock(ratio);
            fitTranslationBlock();
        }
        applyBlock();
    }
}

- (TGPhotoCropRectangle)rectangleFromCGRect:(CGRect)rect
{
    return (TGPhotoCropRectangle)
    {
        .tl = (CGPoint){ rect.origin.x, rect.origin.y },
        .tr = (CGPoint){ CGRectGetMaxX(rect), rect.origin.y },
        .br = (CGPoint){ CGRectGetMaxX(rect), CGRectGetMaxY(rect) },
        .bl = (CGPoint){ rect.origin.x, CGRectGetMaxY(rect) }
    };
}

- (CGRect)CGRectFromRectangle:(TGPhotoCropRectangle)rect
{
    return (CGRect)
    {
        .origin = rect.tl,
        .size = (CGSize){ .width = rect.tr.x - rect.tl.x, .height = rect.bl.y - rect.tl.y }
    };
}

- (CGRect)boundingBoxForRect:(CGRect)rect withRotation:(CGFloat)rotation
{
    CGAffineTransform t = CGAffineTransformMakeTranslation(CGRectGetMidX(rect), CGRectGetMidY(rect));
    t = CGAffineTransformRotate(t, rotation);
    t = CGAffineTransformTranslate(t, -CGRectGetMidX(rect), -CGRectGetMidY(rect));
    return CGRectApplyAffineTransform(rect, t);
}

- (TGPhotoCropRectangle)applyTransform:(CGAffineTransform)transform toRect:(CGRect)rect
{
    CGAffineTransform t = CGAffineTransformMakeTranslation(CGRectGetMidX(rect), CGRectGetMidY(rect));
    t = CGAffineTransformConcat(transform, t);
    t = CGAffineTransformTranslate(t, -CGRectGetMidX(rect), -CGRectGetMidY(rect));
    
    TGPhotoCropRectangle r = [self rectangleFromCGRect:rect];
    return (TGPhotoCropRectangle)
    {
        .tl = CGPointApplyAffineTransform(r.tl, t),
        .tr = CGPointApplyAffineTransform(r.tr, t),
        .br = CGPointApplyAffineTransform(r.br, t),
        .bl = CGPointApplyAffineTransform(r.bl, t)
    };
}

- (TGPhotoCropRectangle)applyTransform:(CGAffineTransform)t toRectangle:(TGPhotoCropRectangle)r
{
    return (TGPhotoCropRectangle)
    {
        .tl = CGPointApplyAffineTransform(r.tl, t),
        .tr = CGPointApplyAffineTransform(r.tr, t),
        .br = CGPointApplyAffineTransform(r.br, t),
        .bl = CGPointApplyAffineTransform(r.bl, t)
    };
}

- (bool)isTracking
{
    return _animating || _isTracking;
}

#pragma mark - Gesture Recognizing

- (void)handlePress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            if (!_beganInteraction && self.didBeginChanging != nil)
                self.didBeginChanging();
            
            _isTracking = true;
            _endedInteraction = false;
            _beganInteraction = true;
            _fitted = false;
            
            [self _stopAllContentAnimations];
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            _beganInteraction = false;
            
            if (!_endedInteraction && self.didEndChanging != nil)
                self.didEndChanging();
            
            if (!_fitted)
            {
                [self fitContentInsideBoundsAllowScale:true animated:true completion:nil];
                _fitted = true;
            }
            
            _isTracking = false;
            _endedInteraction = true;
        }
            break;
            
        default:
            break;
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    CGPoint translation = [gestureRecognizer translationInView:_wrapperView];
    //CGPoint velocity = [gestureRecognizer velocityInView:self];
    
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            if (!_beganInteraction && self.didBeginChanging != nil)
                self.didBeginChanging();
            
            _isTracking = true;
            _endedInteraction = false;
            _beganInteraction = true;
            _fitted = false;
            
            [self _stopAllContentAnimations];
        }
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            _wrapperView.layer.transform = CATransform3DTranslate(_wrapperView.layer.transform, translation.x, translation.y, 0);
            _snapshotView.superview.layer.transform = _wrapperView.layer.transform;
        
            [gestureRecognizer setTranslation:CGPointZero inView:self];
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            _beganInteraction = false;
            
            if (!_endedInteraction && self.didBeginChanging != nil)
                self.didEndChanging();
            
            if (!_fitted)
            {
                [self fitContentInsideBoundsAllowScale:true animated:true completion:nil];
                _fitted = true;
            }
            
            _isTracking = false;
            _endedInteraction = true;
        }
            break;
            
        default:
            break;
    }
}

- (void)handlePinch:(UIPinchGestureRecognizer *)gestureRecognizer
{
    CGFloat scale = gestureRecognizer.scale;
    CGFloat contentScale = self.contentScale;
    
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            _pinchCenter = _touchCenter;
            _pinchStartScale = contentScale;
            
            if (!_beganInteraction && self.didBeginChanging != nil)
                self.didBeginChanging();
            
            _isTracking = true;
            _endedInteraction = false;
            _beganInteraction = true;
            _fitted = false;
            
            [self _stopAllContentAnimations];
        }
        case UIGestureRecognizerStateChanged:
        {
            CGPoint delta = CGPointMake(_pinchCenter.x - _wrapperView.bounds.size.width / 2.0f, _pinchCenter.y - _wrapperView.bounds.size.height / 2.0f);
            
            if (_pinchStartScale / self.minimumZoomScale * scale > self.maximumZoomScale)
                scale = self.maximumZoomScale / _pinchStartScale * self.minimumZoomScale;
            
            CGFloat size = _contentSize.width * _pinchStartScale;
            CGFloat newSize = size * scale;
            CGFloat constrainedSize = MAX(self.minimumZoomScale * _contentSize.width,
                                          MIN(newSize, self.maximumZoomScale * _contentSize.width));
            CGFloat sizeDimension = self.maximumZoomScale * _contentSize.width - self.minimumZoomScale * _contentSize.width;
            CGFloat rubberBandedSize = TGRubberBandDistance(newSize - constrainedSize, sizeDimension);
            CGFloat finalSize = MAX(self.minimumZoomScale * _contentSize.width * 0.25f, constrainedSize + rubberBandedSize);
            
            CATransform3D transform = CATransform3DTranslate(_wrapperView.layer.transform, delta.x, delta.y, 0.0f);
            
            CGFloat scale = finalSize / (_contentSize.width * contentScale);
            transform = CATransform3DScale(transform, scale, scale, 1.0f);
            
            transform = CATransform3DTranslate(transform, -delta.x, -delta.y, 0);
            _wrapperView.layer.transform = transform;
            _snapshotView.superview.layer.transform = transform;
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            _beganInteraction = false;
            
            if (!_endedInteraction && self.didEndChanging != nil)
                self.didEndChanging();
            
            if (!_fitted)
            {
                [self fitContentInsideBoundsAllowScale:true animated:true completion:nil];
                _fitted = true;
            }
         
            _isTracking = false;
            _endedInteraction = true;
        }
            break;
            
        default:
            break;
    }
}

- (void)handleTouches:(NSSet *)touches
{
    _touchCenter = CGPointZero;
    if (touches.count < 2)
        return;
    
    [touches enumerateObjectsUsingBlock:^(UITouch *touch, __unused BOOL *stop)
    {
        CGPoint location = [touch locationInView:_wrapperView];
        _touchCenter = CGPointMake(_touchCenter.x + location.x, _touchCenter.y + location.y);
    }];
    
    _touchCenter = CGPointMake(_touchCenter.x / touches.count, _touchCenter.y / touches.count);
}

- (void)touchesBegan:(NSSet *)__unused touches withEvent:(UIEvent *)event
{
    [self handleTouches:event.allTouches];
}

- (void)touchesMoved:(NSSet *)__unused touches withEvent:(UIEvent *)event
{
    [self handleTouches:event.allTouches];
}

- (void)touchesEnded:(NSSet *)__unused touches withEvent:(UIEvent *)event
{
    [self handleTouches:event.allTouches];
}

- (void)touchesCancelled:(NSSet *)__unused touches withEvent:(UIEvent *)event
{
    [self handleTouches:event.allTouches];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)__unused gestureRecognizer
{
    bool shouldBegin = true;
    if (self.shouldBeginChanging)
        shouldBegin = self.shouldBeginChanging();
    
    return shouldBegin;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)__unused gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)__unused otherGestureRecognizer
{
    return YES;
}

#pragma mark - Zoom

- (void)resetAndSetBounds:(bool)setBounds
{
    if (CGSizeEqualToSize(_contentSize, CGSizeZero) || CGSizeEqualToSize(self.frame.size, CGSizeZero))
        return;
    
    if (setBounds)
    {
        _wrapperView.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
        _wrapperView.bounds = CGRectMake(0, 0, _contentSize.width, _contentSize.height);
    }
    
    CGFloat sourceAspect = _contentSize.height / _contentSize.width;
    CGFloat cropAspect = self.frame.size.height / self.frame.size.width;
    CGFloat scale = 1.0f;
    
    if(sourceAspect > cropAspect)
        scale = self.frame.size.width / _contentSize.width;
    else
        scale = self.frame.size.height / _contentSize.height;
    
    _minimumZoomScale = scale;
    
    _wrapperView.layer.transform = CATransform3DMakeScale(scale, scale, 1);
    _snapshotView.superview.layer.transform = _wrapperView.layer.transform;
}

- (void)reset
{
    [self resetAndSetBounds:true];
}

- (void)resetAnimatedWithFrame:(CGRect)frame completion:(void (^)(void))completion
{
    CGRect bounds = CGRectMake(0, 0, frame.size.width, frame.size.height);
    
    CGFloat sourceAspect = _contentSize.height / _contentSize.width;
    CGFloat cropAspect = frame.size.height / frame.size.width;
    CGFloat scale = 1.0f;
    
    if(sourceAspect > cropAspect)
        scale = frame.size.width / _contentSize.width;
    else
        scale = frame.size.height / _contentSize.height;
    
    POPSpringAnimation *centerAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewCenter];
    centerAnimation.fromValue = [NSValue valueWithCGPoint:_wrapperView.center];
    centerAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds))];
    centerAnimation.springSpeed = 7;
    centerAnimation.springBounciness = 1;
    
    POPSpringAnimation *translationAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerTranslationXY];
    translationAnimation.fromValue = [_wrapperView.layer valueForKeyPath:@"transform.translation"];
    translationAnimation.toValue = [NSValue valueWithCGPoint:CGPointZero];
    translationAnimation.springSpeed = 7;
    translationAnimation.springBounciness = 1;
    
    CGFloat fromScale = self.contentScale;
    POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scaleAnimation.fromValue = [NSValue valueWithCGSize:CGSizeMake(fromScale, fromScale)];
    scaleAnimation.toValue = [NSValue valueWithCGSize:CGSizeMake(scale, scale)];
    scaleAnimation.springSpeed = 7;
    scaleAnimation.springBounciness = 1;

    POPSpringAnimation *rotationAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerRotation];
    rotationAnimation.fromValue = @(self.contentRotation);
    rotationAnimation.toValue = @0;
    rotationAnimation.springSpeed = 7;
    rotationAnimation.springBounciness = 1;

    _wrapperView.userInteractionEnabled = false;
    [TGPhotoEditorAnimation performBlock:^(__unused bool allFinished)
    {
        _wrapperView.userInteractionEnabled = true;
        if (completion != nil)
            completion();
    } whenCompletedAllAnimations:@[ centerAnimation, translationAnimation, scaleAnimation, rotationAnimation ]];
    
    [_wrapperView pop_addAnimation:centerAnimation forKey:@"position"];
    [_wrapperView.layer pop_addAnimation:translationAnimation forKey:@"translation"];
    [_wrapperView.layer pop_addAnimation:scaleAnimation forKey:@"scale"];
    [_wrapperView.layer pop_addAnimation:rotationAnimation forKey:@"rotation"];
}

- (void)zoomToRect:(CGRect)rect withFrame:(CGRect)frame animated:(bool)animated completion:(void (^)(void))completion
{
    CGFloat contentRotation = self.contentRotation;
    
    if (!animated)
        [self resetAndSetBounds:true];
    
    CGFloat sourceAspect = rect.size.height / rect.size.width;
    CGFloat cropAspect = frame.size.height / frame.size.width;
    CGFloat scale = 1.0f;
    
    if(sourceAspect > cropAspect)
        scale = frame.size.width / rect.size.width;
    else
        scale = frame.size.height / rect.size.height;
    
    CGSize rotatedContentSize = TGRotatedContentSize(_contentSize, contentRotation);
    CGRect bounds = CGRectMake(0, 0, frame.size.width, frame.size.height);
    
    if (animated)
    {
        POPSpringAnimation *centerAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewCenter];
        centerAnimation.fromValue = [NSValue valueWithCGPoint:_wrapperView.center];
        centerAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds))];
        centerAnimation.springSpeed = 7;
        centerAnimation.springBounciness = 1;
        
        POPSpringAnimation *translationAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerTranslationXY];
        translationAnimation.fromValue = [_wrapperView.layer valueForKeyPath:@"transform.translation"];
        translationAnimation.toValue = [NSValue valueWithCGPoint:CGPointMake((rotatedContentSize.width / 2 - CGRectGetMidX(rect)) * scale, (rotatedContentSize.height / 2 - CGRectGetMidY(rect)) * scale)];
        translationAnimation.springSpeed = 7;
        translationAnimation.springBounciness = 1;

        CGFloat fromScale = self.contentScale;
        POPSpringAnimation *scaleAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
        scaleAnimation.fromValue = [NSValue valueWithCGSize:CGSizeMake(fromScale, fromScale)];
        scaleAnimation.toValue = [NSValue valueWithCGSize:CGSizeMake(scale, scale)];
        scaleAnimation.springSpeed = 7;
        scaleAnimation.springBounciness = 1;

        _wrapperView.userInteractionEnabled = false;
        
        [TGPhotoEditorAnimation performBlock:^(__unused bool allFinished)
        {
            _wrapperView.userInteractionEnabled = true;
            if (completion != nil)
                completion();
        } whenCompletedAllAnimations:@[ centerAnimation, translationAnimation, scaleAnimation ]];
        
        [_wrapperView pop_addAnimation:centerAnimation forKey:@"position"];
        [_wrapperView.layer pop_addAnimation:translationAnimation forKey:@"translation"];
        [_wrapperView.layer pop_addAnimation:scaleAnimation forKey:@"scale"];
    }
    else
    {
        _wrapperView.center = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
        
        CATransform3D transform = CATransform3DIdentity;
        transform = CATransform3DScale(transform, scale, scale, 1.0f);
        transform = CATransform3DTranslate(transform, (rotatedContentSize.width / 2 - CGRectGetMidX(rect)), (rotatedContentSize.height / 2 - CGRectGetMidY(rect)), 0);
        transform = CATransform3DRotate(transform, contentRotation, 0.0f, 0.0f, 1.0f);
        _wrapperView.layer.transform = transform;
        
        _snapshotView.superview.layer.transform = _wrapperView.layer.transform;
        _snapshotView.superview.center = _wrapperView.center;
        
        if (completion != nil)
            completion();
    }
}

#pragma mark - 

- (void)storeRotationStartValues
{
    if (_rotationStartScale < FLT_EPSILON)
        _rotationStartScale = self.contentScale;
}

- (void)resetRotationStartValues
{
    _rotationStartScale = 0.0f;
}

#pragma mark - Misc

- (void)setPaintingImage:(UIImage *)paintingImage
{
    _paintingImage = paintingImage;
}

- (UIView *)setSnapshotViewEnabled:(bool)enabled
{
    if (enabled)
    {
        [_snapshotClipView removeFromSuperview];
        [_snapshotView removeFromSuperview];
        
        _snapshotClipView = [[UIView alloc] initWithFrame:self.bounds];
        _snapshotClipView.clipsToBounds = true;
        _snapshotClipView.userInteractionEnabled = false;
    
        CGRect contentFrame = CGRectMake(0, 0, _contentSize.width, _contentSize.height);
        
        UIView *snapshotWrapperView = [[UIView alloc] initWithFrame:contentFrame];
        [_snapshotClipView addSubview:snapshotWrapperView];
        
        _snapshotView = [[UIImageView alloc] initWithFrame:contentFrame];
        _snapshotView.image = self.imageView.image;
        _snapshotView.transform = CGAffineTransformMakeScale(_mirrored ? -1.0f : 1.0f, 1.0f);
        [snapshotWrapperView addSubview:_snapshotView];
        
        _paintingImageView = [[UIImageView alloc] initWithFrame:contentFrame];
        _paintingImageView.image = _paintingImage;
        [snapshotWrapperView addSubview:_paintingImageView];
        
        snapshotWrapperView.center = _wrapperView.center;
        snapshotWrapperView.layer.transform = _wrapperView.layer.transform;
    }
    else
    {
        [_snapshotView removeFromSuperview];
        _snapshotView = nil;
        
        [_snapshotClipView removeFromSuperview];
        _snapshotClipView = nil;
    }
    
    return _snapshotClipView;
}

- (void)_stopAllContentAnimations
{
    [_wrapperView.layer pop_removeAnimationForKey:@"translation"];
    [_wrapperView.layer pop_removeAnimationForKey:@"scale"];
    _animating = false;
}

@end
