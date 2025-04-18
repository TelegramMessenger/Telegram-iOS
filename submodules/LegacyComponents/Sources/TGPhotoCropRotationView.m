#import "TGPhotoCropRotationView.h"

#import "LegacyComponentsInternal.h"
#import "POPSpringAnimation.h"

#import <LegacyComponents/TGPhotoEditorUtils.h>

const CGFloat TGPhotoCropRotationViewMaximumAngle = 45;

@interface TGPhotoCropRotationView () <UIGestureRecognizerDelegate>
{
    UIImageView *_wheelView;
    UIImageView *_needleView;
    
    UILongPressGestureRecognizer *_pressGestureRecognizer;
    UIPanGestureRecognizer *_panGestureRecognizer;
    
    bool _animating;
    bool _beganInteraction;
    bool _endedInteraction;
    
    bool _isTracking;
}
@end

@implementation TGPhotoCropRotationView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.clipsToBounds = true;

        _wheelView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 400, 400)];
        _wheelView.alpha = 0.9f;
        _wheelView.image = TGComponentsImageNamed(@"PhotoEditorRotationWheel");
        [self addSubview:_wheelView];
        
        _needleView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _needleView.alpha = 0.9f;
        _needleView.contentMode = UIViewContentModeCenter;
        _needleView.image = TGComponentsImageNamed(@"PhotoEditorRotationNeedle");
        [self addSubview:_needleView];
        
        _pressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handlePress:)];
        _pressGestureRecognizer.minimumPressDuration = 0.1f;
        [self addGestureRecognizer:_pressGestureRecognizer];
        
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _panGestureRecognizer.delegate = self;
        [self addGestureRecognizer:_panGestureRecognizer];
    }
    return self;
}

- (bool)isTracking
{
    return _isTracking;
}

- (void)handlePress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            if (_beganInteraction)
                return;
            
            _isTracking = true;
            
            if (self.didBeginChanging != nil)
                self.didBeginChanging();
            
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
            
            if (self.didEndChanging != nil)
                self.didEndChanging();
            
            _endedInteraction = true;
        }
            break;
            
        default:
            break;
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            if (_beganInteraction)
                return;
            
            _isTracking = true;
            
            if (self.didBeginChanging != nil)
                self.didBeginChanging();
            
            _endedInteraction = false;
            _beganInteraction = true;
        }
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            CGFloat translation = 0;
            
            switch (self.interfaceOrientation)
            {
                case UIInterfaceOrientationLandscapeLeft:
                    translation = [gestureRecognizer translationInView:self].y;
                    break;
                case UIInterfaceOrientationLandscapeRight:
                    translation = [gestureRecognizer translationInView:self].y * -1;
                    break;
                    
                default:
                    translation = [gestureRecognizer translationInView:self].x;
                    break;
            }
            
            CGFloat angleInDegrees = TGRadiansToDegrees(_angle);
            CGFloat newAngleInDegrees = MIN(TGPhotoCropRotationViewMaximumAngle, MAX(-TGPhotoCropRotationViewMaximumAngle, angleInDegrees - translation / (CGFloat)M_PI / 1.15f));
            
            if (ABS(newAngleInDegrees - angleInDegrees) > FLT_EPSILON)
            {
                _angle = TGDegreesToRadians(newAngleInDegrees);
                
                if (self.angleChanged != nil)
                    self.angleChanged(_angle, false);
                
                [self setNeedsLayout];
            }
            
            [gestureRecognizer setTranslation:CGPointZero inView:self];
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            _beganInteraction = false;
            
            if (_endedInteraction)
                return;
            
            _isTracking = false;
            
            if (self.didEndChanging != nil)
                self.didEndChanging();
            
            _endedInteraction = true;
        }
            break;
            
        default:
            break;
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)__unused gestureRecognizer
{
    bool shouldBegin = true;
    if (self.shouldBeginChanging != nil)
        shouldBegin = self.shouldBeginChanging();
        
    return !_animating && shouldBegin;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)__unused gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)__unused otherGestureRecognizer
{
    return true;
}

- (void)resetAnimated:(bool)animated
{
    if (animated)
    {
        _animating = true;
        
        POPSpringAnimation *animation = [POPSpringAnimation animation];
        POPAnimatableProperty *angleProperty = [POPAnimatableProperty propertyWithName:@"org.telegram.rotationAngle" initializer:^(POPMutableAnimatableProperty *prop)
        {
            prop.readBlock = ^(id obj, CGFloat values[])
            {
                values[0] = TGRadiansToDegrees([obj angle]);
            };
            prop.writeBlock = ^(id obj, const CGFloat values[])
            {
                [obj setAngle:TGDegreesToRadians(values[0])];
            };
        }];
        animation.property = angleProperty;
        animation.fromValue = @(TGRadiansToDegrees(self.angle));
        animation.toValue = @(0.0f);
        animation.springSpeed = 5;
        animation.springBounciness = 2;
        animation.completionBlock = ^(__unused POPAnimation *animation, __unused BOOL finished)
        {
            _animating = false;
        };

        [self pop_addAnimation:animation forKey:@"angle"];
    }
    else
    {
        [self setAngle:0.0f];
    }
}

- (void)setAngle:(CGFloat)angle
{
    _angle = angle;
    [self setNeedsLayout];
}

- (void)setAngle:(CGFloat)angle animated:(bool)animated
{
    if (ABS(angle - TGRadiansToDegrees(self.angle)) < FLT_EPSILON)
        return;
    
    if (animated)
    {
        _animating = true;
        
        if (self.didBeginChanging != nil)
            self.didBeginChanging();
        
        POPSpringAnimation *animation = [POPSpringAnimation animation];
        POPAnimatableProperty *angleProperty = [POPAnimatableProperty propertyWithName:@"org.telegram.rotationAngle" initializer:^(POPMutableAnimatableProperty *prop)
        {
            prop.readBlock = ^(id obj, CGFloat values[])
            {
                values[0] = TGRadiansToDegrees([obj angle]);
            };
            prop.writeBlock = ^(id obj, const CGFloat values[])
            {
                TGPhotoCropRotationView *view = (TGPhotoCropRotationView *)obj;
                [view setAngle:TGDegreesToRadians(values[0])];
                if (view.angleChanged != nil)
                    view.angleChanged(view->_angle, false);
            };
        }];
        animation.property = angleProperty;
        animation.fromValue = @(TGRadiansToDegrees(self.angle));
        animation.toValue = @(angle);
        animation.springSpeed = 5;
        animation.springBounciness = 2;
        animation.completionBlock = ^(__unused POPAnimation *animation, __unused BOOL finished)
        {
            _animating = false;
            
            if (self.didEndChanging != nil)
                self.didEndChanging();
        };
        
        [self pop_addAnimation:animation forKey:@"angle"];
    }
    else
    {
        [self setAngle:angle];
    }
}

- (void)layoutSubviews
{
    [UIView performWithoutAnimation:^
    {
        switch (self.interfaceOrientation)
        {
            case UIInterfaceOrientationLandscapeLeft:
            {
                _wheelView.image = TGComponentsImageNamed(@"PhotoEditorRotationWheelLeft");
                _wheelView.center = CGPointMake(52 + 200, self.frame.size.height / 2);

                _needleView.frame = CGRectMake(43, (self.frame.size.height - 10) / 2, 10, 10);
                _needleView.transform = CGAffineTransformMakeRotation((CGFloat)M_PI_2);
            }
                break;
                
            case UIInterfaceOrientationLandscapeRight:
            {
                _wheelView.image = TGComponentsImageNamed(@"PhotoEditorRotationWheelRight");
                _wheelView.center = CGPointMake(-152, self.frame.size.height / 2);
                
                _needleView.frame = CGRectMake(self.frame.size.width - 53, (self.frame.size.height - 10) / 2, 10, 10);
                _needleView.transform = CGAffineTransformMakeRotation(-(CGFloat)M_PI_2);
            }
                break;
                
            default:
            {
                _wheelView.image = TGComponentsImageNamed(@"PhotoEditorRotationWheel");
                _wheelView.center = CGPointMake(self.frame.size.width / 2, -152);
                
                _needleView.frame = CGRectMake((self.frame.size.width - 10) / 2, 47, 10, 10);
                _needleView.transform = CGAffineTransformIdentity;
            }
                break;
        }
    }];
    
    _wheelView.transform = CGAffineTransformMakeRotation(_angle);
}

@end
