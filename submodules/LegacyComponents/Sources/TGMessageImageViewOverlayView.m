#import "TGMessageImageViewOverlayView.h"

#import "POPBasicAnimation.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGColor.h"

typedef enum {
    TGMessageImageViewOverlayViewTypeNone = 0,
    TGMessageImageViewOverlayViewTypeDownload = 1,
    TGMessageImageViewOverlayViewTypeProgress = 2,
    TGMessageImageViewOverlayViewTypeProgressCancel = 3,
    TGMessageImageViewOverlayViewTypeProgressNoCancel = 4,
    TGMessageImageViewOverlayViewTypePlay = 5,
    TGMessageImageViewOverlayViewTypeSecret = 6,
    TGMessageImageViewOverlayViewTypeSecretViewed = 7,
    TGMessageImageViewOverlayViewTypeSecretProgress = 8,
    TGMessageImageViewOverlayViewTypePlayMedia = 9,
    TGMessageImageViewOverlayViewTypePauseMedia = 10,
    TGMessageImageViewOverlayViewTypeCompleted = 11
} TGMessageImageViewOverlayViewType;

@interface TGMessageImageViewOverlayParticle : NSObject
{
@public
    CGPoint _position;
    CGPoint _direction;
    CGFloat _velocity;
    
    CGFloat _alpha;
    CGFloat _lifeTime;
    CGFloat _currentTime;
}
@end

const NSInteger TGMessageImageViewOverlayParticlesCount = 40;

@interface TGMessageImageViewOverlayLayer : CALayer
{
    NSMutableArray<TGMessageImageViewOverlayParticle *> *_particlesPool;
    NSMutableArray<TGMessageImageViewOverlayParticle *> *_particles;
    NSMutableIndexSet *_particlesToRelease;
    
    CGFloat _previousTime;
}

@property (nonatomic, strong) UIColor *incomingColor;
@property (nonatomic, strong) UIColor *outgoingColor;

@property (nonatomic, strong) UIColor *incomingIconColor;
@property (nonatomic, strong) UIColor *outgoingIconColor;

@property (nonatomic) CGFloat radius;
@property (nonatomic) int overlayStyle;
@property (nonatomic) CGFloat progress;
@property (nonatomic) int type;
@property (nonatomic, strong) UIColor *overlayBackgroundColorHint;

@property (nonatomic) CGFloat afterProgressRotation;
@property (nonatomic) CGFloat checkProgress;

@property (nonatomic, strong) UIImage *blurredBackgroundImage;

@end

@implementation TGMessageImageViewOverlayLayer

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
    }
    return self;
}

- (void)setOverlayBackgroundColorHint:(UIColor *)overlayBackgroundColorHint
{
    if (_overlayBackgroundColorHint != overlayBackgroundColorHint)
    {
        _overlayBackgroundColorHint = overlayBackgroundColorHint;
        [self setNeedsDisplay];
    }
}

- (void)setOverlayStyle:(int)overlayStyle
{
    if (_overlayStyle != overlayStyle)
    {
        _overlayStyle = overlayStyle;
        [self setNeedsDisplay];
    }
}

- (void)setIncomingColor:(UIColor *)incomingColor
{
    _incomingColor = incomingColor;
    [self setNeedsDisplay];
}

- (void)setNone
{
    _type = TGMessageImageViewOverlayViewTypeNone;
    
    [self pop_removeAnimationForKey:@"progress"];
    [self pop_removeAnimationForKey:@"progressAmbient"];
    [self pop_removeAnimationForKey:@"completion"];
    _progress = 0.0f;
    _checkProgress = 0.0f;
    
    [self setNeedsDisplay];
}

- (void)setDownload
{
    if (_type != TGMessageImageViewOverlayViewTypeDownload)
    {
        [self pop_removeAnimationForKey:@"progress"];
        [self pop_removeAnimationForKey:@"progressAmbient"];
        
        _type = TGMessageImageViewOverlayViewTypeDownload;
        [self setNeedsDisplay];
    }
}

- (void)setPlay
{
    if (_type != TGMessageImageViewOverlayViewTypePlay)
    {
        [self pop_removeAnimationForKey:@"progress"];
        [self pop_removeAnimationForKey:@"progressAmbient"];
        [self pop_removeAnimationForKey:@"comlpetion"];
        
        _type = TGMessageImageViewOverlayViewTypePlay;
        [self setNeedsDisplay];
    }
}

- (void)setPlayMedia
{
    if (_type != TGMessageImageViewOverlayViewTypePlayMedia)
    {
        [self pop_removeAnimationForKey:@"progress"];
        [self pop_removeAnimationForKey:@"progressAmbient"];
        
        _type = TGMessageImageViewOverlayViewTypePlayMedia;
        [self setNeedsDisplay];
    }
}

- (void)setPauseMedia
{
    if (_type != TGMessageImageViewOverlayViewTypePauseMedia)
    {
        [self pop_removeAnimationForKey:@"progress"];
        [self pop_removeAnimationForKey:@"progressAmbient"];
        
        _type = TGMessageImageViewOverlayViewTypePauseMedia;
        [self setNeedsDisplay];
    }
}

- (void)setProgressCancel
{
    if (_type != TGMessageImageViewOverlayViewTypeProgressCancel)
    {
        [self pop_removeAnimationForKey:@"progress"];
        [self pop_removeAnimationForKey:@"progressAmbient"];
        
        _type = TGMessageImageViewOverlayViewTypeProgressCancel;
        [self setNeedsDisplay];
    }
}

- (void)setProgressNoCancel
{
    if (_type != TGMessageImageViewOverlayViewTypeProgressNoCancel)
    {
        [self pop_removeAnimationForKey:@"progress"];
        [self pop_removeAnimationForKey:@"progressAmbient"];
        
        _type = TGMessageImageViewOverlayViewTypeProgressNoCancel;
        [self setNeedsDisplay];
    }
}

- (void)setSecret:(bool)isViewed
{
    int newType = 0;
    if (isViewed)
        newType = TGMessageImageViewOverlayViewTypeSecretViewed;
    else
        newType = TGMessageImageViewOverlayViewTypeSecret;
    
    if (_type != newType)
    {
        [self pop_removeAnimationForKey:@"progress"];
        [self pop_removeAnimationForKey:@"progressAmbient"];
        
        _type = newType;
        [self setNeedsDisplay];
    }
}

- (void)setProgress:(CGFloat)progress
{
    _progress = progress;
    [self setNeedsDisplay];
}

+ (void)_addAmbientProgressAnimation:(TGMessageImageViewOverlayLayer *)layer
{
    POPBasicAnimation *ambientProgress = [self pop_animationForKey:@"progressAmbient"];
    
    ambientProgress = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerRotation];
    ambientProgress.fromValue = @((CGFloat)0.0f);
    ambientProgress.toValue = @((CGFloat)M_PI * 2.0f);
    ambientProgress.duration = 3.0;
    ambientProgress.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    ambientProgress.repeatForever = true;
    
    [layer pop_addAnimation:ambientProgress forKey:@"progressAmbient"];
}

- (void)setProgress:(CGFloat)progress animated:(bool)animated
{
    [self setProgress:progress animated:animated duration:0.5];
}

- (void)setProgress:(CGFloat)progress animated:(bool)animated duration:(NSTimeInterval)duration
{
    if (_type != TGMessageImageViewOverlayViewTypeProgress || ABS(_progress - progress) > FLT_EPSILON)
    {
        if (_type != TGMessageImageViewOverlayViewTypeProgress)
            _progress = 0.0f;
        
        if ([self pop_animationForKey:@"progressAmbient"] == nil)
            [TGMessageImageViewOverlayLayer _addAmbientProgressAnimation:self];
        
        _type = TGMessageImageViewOverlayViewTypeProgress;
        
        if (animated)
        {
            POPBasicAnimation *animation = [self pop_animationForKey:@"progress"];
            if (animation != nil)
            {
                animation.toValue = @((CGFloat)progress);
            }
            else
            {
                animation = [POPBasicAnimation animation];
                animation.property = [POPAnimatableProperty propertyWithName:@"progress" initializer:^(POPMutableAnimatableProperty *prop)
                {
                    prop.readBlock = ^(TGMessageImageViewOverlayLayer *layer, CGFloat values[])
                    {
                        values[0] = layer.progress;
                    };
                    
                    prop.writeBlock = ^(TGMessageImageViewOverlayLayer *layer, const CGFloat values[])
                    {
                        layer.progress = values[0];
                    };
                    
                    prop.threshold = 0.01f;
                }];
                animation.fromValue = @(_progress);
                animation.toValue = @(progress);
                animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
                animation.duration = duration;
                [self pop_addAnimation:animation forKey:@"progress"];
            }
        }
        else
        {
            _progress = progress;
            
            [self setNeedsDisplay];
        }
    }
}

- (void)setCheckProgress:(CGFloat)checkProgress
{
    _checkProgress = checkProgress;
    [self setNeedsDisplay];
}

- (void)setCompletedAnimated:(bool)animated
{
    if (_type == TGMessageImageViewOverlayViewTypeCompleted)
        return;
    
    _type = TGMessageImageViewOverlayViewTypeCompleted;
    
    if (animated)
    {
        POPBasicAnimation *animation = [self pop_animationForKey:@"completion"];
        if (animation == nil)
        {
            _checkProgress = 0.0f;
            [self setNeedsDisplay];
            
            animation = [POPBasicAnimation animation];
            animation.property = [POPAnimatableProperty propertyWithName:@"completion" initializer:^(POPMutableAnimatableProperty *prop)
            {
                prop.readBlock = ^(TGMessageImageViewOverlayLayer *layer, CGFloat values[])
                {
                    values[0] = layer.checkProgress;
                };
                
                prop.writeBlock = ^(TGMessageImageViewOverlayLayer *layer, const CGFloat values[])
                {
                    layer.checkProgress = values[0];
                };
                
                prop.threshold = 0.01f;
            }];
            animation.beginTime = CACurrentMediaTime() + 0.08;
            animation.fromValue = @0;
            animation.toValue = @1;
            animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            animation.duration = 0.25;
            [self pop_addAnimation:animation forKey:@"completion"];
        }
    }
    else
    {
        _checkProgress = 1.0f;
        [self setNeedsDisplay];
    }
}

- (void)particlesTick:(NSTimeInterval)dt
{
    NSUInteger i = -1;
    for (TGMessageImageViewOverlayParticle *particle in _particles)
    {
        i++;
        
        if (particle->_currentTime > particle->_lifeTime)
        {
            if (_particlesPool.count < TGMessageImageViewOverlayParticlesCount)
                [_particlesPool addObject:particle];
            
            [_particlesToRelease addIndex:i];
            continue;
        }
        
        CGFloat input = particle->_currentTime / particle->_lifeTime;
        CGFloat decelerated = (1.0f - (1.0f - input) * (1.0f - input));
        particle->_alpha = 1.0f - decelerated;
        
        CGPoint p = particle->_position;
        CGPoint d = particle->_direction;
        CGFloat v = particle->_velocity;
        p = CGPointMake(p.x + d.x * v * dt / 1000.0f, p.y + d.y * v * dt / 1000.0f);
        particle->_position = p;
        
        particle->_currentTime += dt;
    }
    
    [_particles removeObjectsAtIndexes:_particlesToRelease];
    [_particlesToRelease removeAllIndexes];
}

- (void)setSecretProgress:(CGFloat)progress completeDuration:(NSTimeInterval)completeDuration animated:(bool)animated
{
    if (_particlesPool == nil)
    {
        _particlesPool = [[NSMutableArray alloc] init];
        _particles = [[NSMutableArray alloc] init];
        _particlesToRelease = [[NSMutableIndexSet alloc] init];
        
        for (NSUInteger i = 0; i < TGMessageImageViewOverlayParticlesCount; i++)
        {
            [_particlesPool addObject:[[TGMessageImageViewOverlayParticle alloc] init]];
        }
    }
    
    if (_type != TGMessageImageViewOverlayViewTypeSecretProgress || ABS(_progress - progress) > FLT_EPSILON)
    {
        if (_type != TGMessageImageViewOverlayViewTypeSecretProgress)
        {
            _progress = 0.0f;
            [self setNeedsDisplay];
        }
        
        _type = TGMessageImageViewOverlayViewTypeSecretProgress;
        
        if (animated)
        {
            POPBasicAnimation *animation = [self pop_animationForKey:@"progress"];
            if (animation != nil)
            {
            }
            else
            {
                animation = [POPBasicAnimation animation];
                animation.property = [POPAnimatableProperty propertyWithName:@"progress" initializer:^(POPMutableAnimatableProperty *prop)
                {
                    prop.readBlock = ^(TGMessageImageViewOverlayLayer *layer, CGFloat values[])
                    {
                        values[0] = layer.progress;
                    };
                    
                    prop.writeBlock = ^(TGMessageImageViewOverlayLayer *layer, const CGFloat values[])
                    {
                        layer.progress = values[0];
                    };
                    
                    prop.threshold = 0.01f;
                }];
                animation.fromValue = @(_progress);
                animation.toValue = @(0.0);
                animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
                animation.duration = completeDuration * _progress;
                [self pop_addAnimation:animation forKey:@"progress"];
            }
        }
        else
        {
            _progress = progress;
            
            [self setNeedsDisplay];
        }
    }
}

- (void)drawInContext:(CGContextRef)context
{
    UIGraphicsPushContext(context);
    
    static UIImage *fireIconMask = nil;
    static UIImage *fireIcon = nil;
    static UIImage *viewedIconMask = nil;
    static UIImage *viewedIcon = nil;
    static UIImage *progressFireIcon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        fireIconMask = TGImageNamed(@"SecretPhotoFireMask.png");
        fireIcon = TGImageNamed(@"SecretPhotoFire.png");
        viewedIconMask = TGImageNamed(@"SecretPhotoCheckMask.png");
        viewedIcon = TGImageNamed(@"SecretPhotoCheck.png");
        progressFireIcon = TGTintedImage(fireIcon, [UIColor whiteColor]);
    });
    
    UIColor *incomingButtonColor = self.incomingColor ?: TGAccentColor();
    UIColor *outgoingButtonColor = self.outgoingColor ?: UIColorRGB(0x3fc33b);
    UIColor *incomingIconColor = self.incomingIconColor ?: [UIColor whiteColor];
    UIColor *outgoingIconColor = self.outgoingIconColor ?: UIColorRGB(0xe1ffc7);
    
    switch (_type)
    {
        case TGMessageImageViewOverlayViewTypeDownload:
        {
            CGFloat diameter = _overlayStyle == TGMessageImageViewOverlayStyleList ? 30.0f : self.radius;
            CGFloat lineWidth = _overlayStyle == TGMessageImageViewOverlayStyleList ? 1.4f : 2.0f;
            CGFloat height = _overlayStyle == TGMessageImageViewOverlayStyleList ? 18.0f : (ceil(self.radius / 2.0f) - 1.0f);
            CGFloat width = _overlayStyle == TGMessageImageViewOverlayStyleList ? 17.0f : ceil(self.radius / 2.5f);
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            if (_overlayStyle == TGMessageImageViewOverlayStyleDefault)
            {
                CGContextSetFillColorWithColor(context, TGColorWithHexAndAlpha(0xffffffff, 0.8f).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
            }
            else if (_overlayStyle == TGMessageImageViewOverlayStyleAccent)
            {
                CGContextSetStrokeColorWithColor(context, TGColorWithHex(0xeaeaea).CGColor);
                CGContextSetLineWidth(context, 1.5f);
                CGContextStrokeEllipseInRect(context, CGRectMake(1.5f / 2.0f, 1.5f / 2.0f, diameter - 1.5f, diameter - 1.5f));
            }
            else if (_overlayStyle == TGMessageImageViewOverlayStyleList)
            {
            }
            else if (_overlayStyle == TGMessageImageViewOverlayStyleIncoming)
            {
                CGContextSetFillColorWithColor(context, incomingButtonColor.CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
            }
            else if (_overlayStyle == TGMessageImageViewOverlayStyleOutgoing)
            {
                CGContextSetFillColorWithColor(context, outgoingButtonColor.CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
            }
            
            if (_overlayStyle == TGMessageImageViewOverlayStyleDefault)
                CGContextSetStrokeColorWithColor(context, TGColorWithHexAndAlpha(0xff000000, 0.55f).CGColor);
            else if (_overlayStyle == TGMessageImageViewOverlayStyleIncoming) {
                CGContextSetStrokeColorWithColor(context, [UIColor clearColor].CGColor);
            }
            else if (_overlayStyle == TGMessageImageViewOverlayStyleOutgoing) {
                CGContextSetStrokeColorWithColor(context, [UIColor clearColor].CGColor);
            }
            else
                CGContextSetStrokeColorWithColor(context, TGAccentColor().CGColor);
            
            CGContextSetLineCap(context, kCGLineCapRound);
            CGContextSetLineWidth(context, lineWidth);
            
            CGPoint mainLine[] = {
                CGPointMake((diameter - lineWidth) / 2.0f + lineWidth / 2.0f, (diameter - height) / 2.0f + lineWidth / 2.0f),
                CGPointMake((diameter - lineWidth) / 2.0f + lineWidth / 2.0f, (diameter + height) / 2.0f - lineWidth / 2.0f)
            };
            
            CGPoint arrowLine[] = {
                CGPointMake((diameter - lineWidth) / 2.0f + lineWidth / 2.0f - width / 2.0f, (diameter + height) / 2.0f + lineWidth / 2.0f - width / 2.0f),
                CGPointMake((diameter - lineWidth) / 2.0f + lineWidth / 2.0f, (diameter + height) / 2.0f + lineWidth / 2.0f),
                CGPointMake((diameter - lineWidth) / 2.0f + lineWidth / 2.0f, (diameter + height) / 2.0f + lineWidth / 2.0f),
                CGPointMake((diameter - lineWidth) / 2.0f + lineWidth / 2.0f + width / 2.0f, (diameter + height) / 2.0f + lineWidth / 2.0f - width / 2.0f),
            };
            
            if (_overlayStyle == TGMessageImageViewOverlayStyleDefault)
                CGContextSetStrokeColorWithColor(context, [UIColor clearColor].CGColor);
            CGContextStrokeLineSegments(context, mainLine, sizeof(mainLine) / sizeof(mainLine[0]));
            CGContextStrokeLineSegments(context, arrowLine, sizeof(arrowLine) / sizeof(arrowLine[0]));
            
            if (_overlayStyle == TGMessageImageViewOverlayStyleDefault)
            {
                CGContextSetBlendMode(context, kCGBlendModeNormal);
                CGContextSetStrokeColorWithColor(context, TGColorWithHexAndAlpha(0x000000, 0.55f).CGColor);
                CGContextStrokeLineSegments(context, arrowLine, sizeof(arrowLine) / sizeof(arrowLine[0]));
                
                CGContextSetBlendMode(context, kCGBlendModeCopy);
                CGContextStrokeLineSegments(context, mainLine, sizeof(mainLine) / sizeof(mainLine[0]));
            }
            
            break;
        }
        case TGMessageImageViewOverlayViewTypeProgressCancel:
        case TGMessageImageViewOverlayViewTypeProgressNoCancel:
        {
            CGFloat diameter = _overlayStyle == TGMessageImageViewOverlayStyleList ? 30.0f : self.radius;
            CGFloat inset = 0.0f;
            CGFloat lineWidth = _overlayStyle == TGMessageImageViewOverlayStyleList ? 1.5f : 2.0f;
            CGFloat crossSize = _overlayStyle == TGMessageImageViewOverlayStyleList ? 10.0f : 14.0f;
            
            if (ABS(diameter - 37.0f) < 0.1) {
                crossSize = 10.0f;
                inset = 2.0;
            } else if (ABS(diameter - 32.0f) < 0.1) {
                crossSize = 10.0f;
                inset = 0.0;
            }
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            if (_overlayStyle == TGMessageImageViewOverlayStyleDefault)
            {
                if (_overlayBackgroundColorHint != nil)
                    CGContextSetFillColorWithColor(context, _overlayBackgroundColorHint.CGColor);
                else
                    CGContextSetFillColorWithColor(context, TGColorWithHexAndAlpha(0x000000, 0.7f).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(inset, inset, diameter - inset * 2.0f, diameter - inset * 2.0f));
            }
            else if (_overlayStyle == TGMessageImageViewOverlayStyleIncoming)
            {
                CGContextSetFillColorWithColor(context, incomingButtonColor.CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
            }
            else if (_overlayStyle == TGMessageImageViewOverlayStyleOutgoing)
            {
                CGContextSetFillColorWithColor(context, outgoingButtonColor.CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
            }
            else if (_overlayStyle == TGMessageImageViewOverlayStyleAccent)
            {
                CGContextSetStrokeColorWithColor(context, TGColorWithHex(0xeaeaea).CGColor);
                CGContextSetLineWidth(context, 1.5f);
                CGContextStrokeEllipseInRect(context, CGRectMake(1.5f / 2.0f, 1.5f / 2.0f, diameter - 1.5f, diameter - 1.5f));
            }
            
            CGContextSetLineCap(context, kCGLineCapRound);
            CGContextSetLineWidth(context, lineWidth);
            
            CGPoint crossLine[] = {
                CGPointMake((diameter - crossSize) / 2.0f, (diameter - crossSize) / 2.0f),
                CGPointMake((diameter + crossSize) / 2.0f, (diameter + crossSize) / 2.0f),
                CGPointMake((diameter + crossSize) / 2.0f, (diameter - crossSize) / 2.0f),
                CGPointMake((diameter - crossSize) / 2.0f, (diameter + crossSize) / 2.0f),
            };
            
            if (_overlayStyle == TGMessageImageViewOverlayStyleDefault)
                CGContextSetStrokeColorWithColor(context, [UIColor clearColor].CGColor);
            else if (_overlayStyle == TGMessageImageViewOverlayStyleIncoming) {
                CGContextSetStrokeColorWithColor(context, incomingIconColor.CGColor);
            }
            else if (_overlayStyle == TGMessageImageViewOverlayStyleOutgoing) {
                CGContextSetStrokeColorWithColor(context, outgoingIconColor.CGColor);
            }
            else
                CGContextSetStrokeColorWithColor(context, TGAccentColor().CGColor);
            
            if (_type == TGMessageImageViewOverlayViewTypeProgressCancel)
                CGContextStrokeLineSegments(context, crossLine, sizeof(crossLine) / sizeof(crossLine[0]));
            
            if (_overlayStyle == TGMessageImageViewOverlayStyleDefault)
            {
                CGContextSetBlendMode(context, kCGBlendModeNormal);
                CGContextSetStrokeColorWithColor(context, TGColorWithHexAndAlpha(0xffffff, 1.0f).CGColor);
                if (_type == TGMessageImageViewOverlayViewTypeProgressCancel)
                    CGContextStrokeLineSegments(context, crossLine, sizeof(crossLine) / sizeof(crossLine[0]));
            }
            
            break;
        }
        case TGMessageImageViewOverlayViewTypeProgress:
        {
            const CGFloat diameter = _overlayStyle == TGMessageImageViewOverlayStyleList ? 30.0f : self.radius;
            const CGFloat lineWidth = _overlayStyle == TGMessageImageViewOverlayStyleList ? 1.0f : 2.0f;
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            CGContextSetLineCap(context, kCGLineCapRound);
            CGContextSetLineWidth(context, lineWidth);
            
            if (_overlayStyle == TGMessageImageViewOverlayStyleDefault)
                CGContextSetStrokeColorWithColor(context, [UIColor clearColor].CGColor);
            else if (_overlayStyle == TGMessageImageViewOverlayStyleIncoming) {
                CGContextSetStrokeColorWithColor(context, incomingIconColor.CGColor);
            }
            else if (_overlayStyle == TGMessageImageViewOverlayStyleOutgoing) {
                CGContextSetStrokeColorWithColor(context, outgoingIconColor.CGColor);
            }
            else
                CGContextSetStrokeColorWithColor(context, TGAccentColor().CGColor);
            
            if (_overlayStyle == TGMessageImageViewOverlayStyleDefault)
            {
                CGContextSetBlendMode(context, kCGBlendModeNormal);
                CGContextSetStrokeColorWithColor(context, TGColorWithHexAndAlpha(0xffffff, 1.0f).CGColor);
            }
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            CGFloat start_angle = 2.0f * ((CGFloat)M_PI) * 0.0f - ((CGFloat)M_PI_2);
            CGFloat end_angle = 2.0f * ((CGFloat)M_PI) * _progress - ((CGFloat)M_PI_2);
            
            CGFloat pathLineWidth = _overlayStyle == TGMessageImageViewOverlayStyleDefault ? 2.0f : 2.0f;
            if (_overlayStyle == TGMessageImageViewOverlayStyleList)
                pathLineWidth = 1.4f;
            CGFloat pathDiameter = diameter - pathLineWidth;
            
            if (ABS(diameter - 37.0f) < 0.1) {
                pathLineWidth = 2.5f;
                pathDiameter = diameter - pathLineWidth * 2.0 - 1.5f;
            } else if (ABS(diameter - 32.0f) < 0.1) {
                pathLineWidth = 2.0f;
                pathDiameter = diameter - pathLineWidth * 2.0 - 1.5f;
            } else {
                pathLineWidth = 2.5f;
                pathDiameter = diameter - pathLineWidth * 2.0 - 1.5f;
            }
            
            UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(diameter / 2.0f, diameter / 2.0f) radius:pathDiameter / 2.0f startAngle:start_angle endAngle:end_angle clockwise:true];
            path.lineWidth = pathLineWidth;
            path.lineCapStyle = kCGLineCapRound;
            [path stroke];
            
            break;
        }
        case TGMessageImageViewOverlayViewTypePlay:
        {
            const CGFloat diameter = self.radius;
            CGFloat offset = round(diameter * 0.06f);
            CGFloat verticalOffset = 0.0f;
            CGFloat alpha = 0.8f;
            UIColor *iconColor = TGColorWithHexAndAlpha(0xffffffff, 1.0f);
            if (diameter <= 25.0f + FLT_EPSILON) {
                offset = round(50.0f * 0.06f) - 1.0f;
                verticalOffset += 0.5f;
                alpha = 1.0f;
                iconColor = TGColorWithHex(0x434344);
            }
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            if (_overlayStyle == TGMessageImageViewOverlayStyleIncoming)
            {
                CGContextSetFillColorWithColor(context, incomingButtonColor.CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                
                UIImage *iconImage = TGTintedImage(TGImageNamed(@"ModernMessageDocumentIconIncoming.png"), incomingIconColor);
                [iconImage drawAtPoint:CGPointMake(floor((diameter - iconImage.size.width) / 2.0f), floor((diameter - iconImage.size.height) / 2.0f)) blendMode:kCGBlendModeNormal alpha:1.0f];
            }
            else if (_overlayStyle == TGMessageImageViewOverlayStyleOutgoing)
            {
                CGContextSetFillColorWithColor(context, outgoingButtonColor.CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                
                UIImage *iconImage = TGTintedImage(TGImageNamed(@"ModernMessageDocumentIconIncoming.png"), outgoingIconColor);
                [iconImage drawAtPoint:CGPointMake(floor((diameter - iconImage.size.width) / 2.0f), floor((diameter - iconImage.size.height) / 2.0f)) blendMode:kCGBlendModeNormal alpha:1.0f];
            }
            else
            {
                CGContextSetFillColorWithColor(context, TGColorWithHexAndAlpha(0x00000000, 0.3).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                                
                UIImage *iconImage = TGTintedImage([UIImage imageNamed:@"Editor/Play"], iconColor);
                [iconImage drawAtPoint:CGPointMake(floor((diameter - iconImage.size.width) / 2.0f), floor((diameter - iconImage.size.height) / 2.0f)) blendMode:kCGBlendModeNormal alpha:1.0f];
            }
            
            break;
        }
        case TGMessageImageViewOverlayViewTypePlayMedia:
        {
            const CGFloat diameter = self.radius;
            const CGFloat width = 20.0f;
            const CGFloat height = width + 4.0f;
            const CGFloat offset = 3.0f;
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            if (_overlayStyle == TGMessageImageViewOverlayStyleIncoming)
            {
                CGContextSetFillColorWithColor(context, incomingButtonColor.CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                
                CGContextSetBlendMode(context, kCGBlendModeCopy);
                CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
                
                if (ABS(diameter - 37.0f) < 0.1) {
                    CGContextTranslateCTM(context, -TGRetinaPixel, TGRetinaPixel);
                    CGFloat factor = 28.0f / 34.0f;
                    CGContextScaleCTM(context, 0.5f * factor, 0.5f * factor);
                    
                    TGDrawSvgPath(context, @"M39.4267651,27.0560591 C37.534215,25.920529 36,26.7818508 36,28.9948438 L36,59.0051562 C36,61.2114475 37.4877047,62.0081969 39.3251488,60.7832341 L62.6748512,45.2167659 C64.5112802,43.9924799 64.4710515,42.0826309 62.5732349,40.9439409 L39.4267651,27.0560591 Z");
                } else {
                    CGContextBeginPath(context);
                    CGContextMoveToPoint(context, 17.0f, 13.0f);
                    CGContextAddLineToPoint(context, 32.0f, 22.0f);
                    CGContextAddLineToPoint(context, 17.0f, 32.0f);
                    CGContextClosePath(context);
                    CGContextFillPath(context);
                }
            }
            else if (_overlayStyle == TGMessageImageViewOverlayStyleOutgoing)
            {
                CGContextSetFillColorWithColor(context, outgoingButtonColor.CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
                CGContextSetBlendMode(context, kCGBlendModeCopy);
                
                if (ABS(diameter - 37.0f) < 0.1) {
                    CGContextTranslateCTM(context, -TGRetinaPixel, TGRetinaPixel);
                    CGFloat factor = 28.0f / 34.0f;
                    CGContextScaleCTM(context, 0.5f * factor, 0.5f * factor);
                    
                    TGDrawSvgPath(context, @"M39.4267651,27.0560591 C37.534215,25.920529 36,26.7818508 36,28.9948438 L36,59.0051562 C36,61.2114475 37.4877047,62.0081969 39.3251488,60.7832341 L62.6748512,45.2167659 C64.5112802,43.9924799 64.4710515,42.0826309 62.5732349,40.9439409 L39.4267651,27.0560591 Z");
                } else {
                    CGContextBeginPath(context);
                    CGContextMoveToPoint(context, 17.0f, 13.0f);
                    CGContextAddLineToPoint(context, 32.0f, 22.0f);
                    CGContextAddLineToPoint(context, 17.0f, 32.0f);
                    CGContextClosePath(context);
                    CGContextFillPath(context);
                }
            }
            else
            {
                CGContextSetFillColorWithColor(context, TGColorWithHexAndAlpha(0xffffffff, 0.8f).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                
                CGContextBeginPath(context);
                CGContextMoveToPoint(context, offset + floor((diameter - width) / 2.0f), floor((diameter - height) / 2.0f));
                CGContextAddLineToPoint(context, offset + floor((diameter - width) / 2.0f) + width, floor(diameter / 2.0f));
                CGContextAddLineToPoint(context, offset + floor((diameter - width) / 2.0f), floor((diameter + height) / 2.0f));
                CGContextClosePath(context);
                CGContextSetFillColorWithColor(context, TGColorWithHexAndAlpha(0xff000000, 0.45f).CGColor);
                CGContextFillPath(context);
            }
            
            break;
        }
        case TGMessageImageViewOverlayViewTypePauseMedia:
        {
            const CGFloat diameter = self.radius;
            const CGFloat width = 20.0f;
            const CGFloat height = width + 4.0f;
            const CGFloat offset = 3.0f;
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            if (_overlayStyle == TGMessageImageViewOverlayStyleIncoming)
            {
                CGContextSetFillColorWithColor(context, incomingButtonColor.CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                
                CGContextSetBlendMode(context, kCGBlendModeCopy);
                CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
                
                if (ABS(diameter - 37.0f) < 0.1) {
                    CGFloat factor = 28.0f / 34.0f;
                    CGContextTranslateCTM(context, TGRetinaPixel, TGRetinaPixel);
                    CGContextScaleCTM(context, 0.5f * factor, 0.5f * factor);
                    
                    TGDrawSvgPath(context, @"M29,30.0017433 C29,28.896211 29.8874333,28 30.999615,28 L37.000385,28 C38.1047419,28 39,28.8892617 39,30.0017433 L39,57.9982567 C39,59.103789 38.1125667,60 37.000385,60 L30.999615,60 C29.8952581,60 29,59.1107383 29,57.9982567 L29,30.0017433 Z M49,30.0017433 C49,28.896211 49.8874333,28 50.999615,28 L57.000385,28 C58.1047419,28 59,28.8892617 59,30.0017433 L59,57.9982567 C59,59.103789 58.1125667,60 57.000385,60 L50.999615,60 C49.8952581,60 49,59.1107383 49,57.9982567 L49,30.0017433 Z");
                } else {
                    CGContextFillRect(context, CGRectMake(15.5f, 14.5f, 4.0f, 15.0f));
                    CGContextFillRect(context, CGRectMake(24.5f, 14.5f, 4.0f, 15.0f));
                }
            }
            else if (_overlayStyle == TGMessageImageViewOverlayStyleOutgoing)
            {
                CGContextSetFillColorWithColor(context, outgoingButtonColor.CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
                
                if (ABS(diameter - 37.0f) < 0.1) {
                    CGFloat factor = 28.0f / 34.0f;
                    CGContextTranslateCTM(context, TGRetinaPixel, TGRetinaPixel);
                    CGContextScaleCTM(context, 0.5f * factor, 0.5f * factor);
                    
                    TGDrawSvgPath(context, @"M29,30.0017433 C29,28.896211 29.8874333,28 30.999615,28 L37.000385,28 C38.1047419,28 39,28.8892617 39,30.0017433 L39,57.9982567 C39,59.103789 38.1125667,60 37.000385,60 L30.999615,60 C29.8952581,60 29,59.1107383 29,57.9982567 L29,30.0017433 Z M49,30.0017433 C49,28.896211 49.8874333,28 50.999615,28 L57.000385,28 C58.1047419,28 59,28.8892617 59,30.0017433 L59,57.9982567 C59,59.103789 58.1125667,60 57.000385,60 L50.999615,60 C49.8952581,60 49,59.1107383 49,57.9982567 L49,30.0017433 Z");
                } else {
                    CGContextFillRect(context, CGRectMake(15.5f, 14.5f, 4.0f, 15.0f));
                    CGContextFillRect(context, CGRectMake(24.5f, 14.5f, 4.0f, 15.0f));
                }
            }
            else
            {
                CGContextSetFillColorWithColor(context, TGColorWithHexAndAlpha(0xffffffff, 0.8f).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
                
                CGContextBeginPath(context);
                CGContextMoveToPoint(context, offset + floor((diameter - width) / 2.0f), floor((diameter - height) / 2.0f));
                CGContextAddLineToPoint(context, offset + floor((diameter - width) / 2.0f) + width, floor(diameter / 2.0f));
                CGContextAddLineToPoint(context, offset + floor((diameter - width) / 2.0f), floor((diameter + height) / 2.0f));
                CGContextClosePath(context);
                CGContextSetFillColorWithColor(context, TGColorWithHexAndAlpha(0xff000000, 0.45f).CGColor);
                CGContextFillPath(context);
            }
            
            break;
        }
        case TGMessageImageViewOverlayViewTypeSecret:
        case TGMessageImageViewOverlayViewTypeSecretViewed:
        {
            const CGFloat diameter = self.radius;
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            CGContextSetFillColorWithColor(context, TGColorWithHexAndAlpha(0xffffffff, 0.7f).CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, diameter, diameter));
            
            CGFloat factor = 1.0f;
            if (diameter < 33.0f)
            {
                CGContextScaleCTM(context, 0.64f, 0.64f);
                factor = 1.5625;
            }
            
            if (_type == TGMessageImageViewOverlayViewTypeSecret)
            {
                [fireIconMask drawAtPoint:CGPointMake(floor((diameter * factor - fireIcon.size.width) / 2.0f), floor((diameter * factor - fireIcon.size.height) / 2.0f)) blendMode:kCGBlendModeDestinationIn alpha:1.0f];
                [fireIcon drawAtPoint:CGPointMake(floor((diameter * factor - fireIcon.size.width) / 2.0f), floor((diameter * factor - fireIcon.size.height) / 2.0f)) blendMode:kCGBlendModeNormal alpha:0.4f];
            }
            else
            {
                CGPoint offset = CGPointMake(1.0f, 2.0f);
                [viewedIconMask drawAtPoint:CGPointMake(offset.x + floor((diameter * factor - viewedIcon.size.width) / 2.0f), offset.y + floor((diameter * factor - viewedIcon.size.height) / 2.0f)) blendMode:kCGBlendModeDestinationIn alpha:1.0f];
                [viewedIcon drawAtPoint:CGPointMake(offset.x + floor((diameter * factor - viewedIcon.size.width) / 2.0f), offset.y + floor((diameter * factor - viewedIcon.size.height) / 2.0f)) blendMode:kCGBlendModeNormal alpha:0.3f];
            }
            
            break;
        }
        case TGMessageImageViewOverlayViewTypeSecretProgress:
        {
            const CGFloat diameter = _overlayStyle == TGMessageImageViewOverlayStyleList ? 30.0f : self.radius;
            const CGFloat lineWidth = _overlayStyle == TGMessageImageViewOverlayStyleList ? 1.0f : 2.0f;
            CGFloat inset = 0.0f;
            
            if (ABS(diameter - 37.0f) < 0.1) {
                inset = 2.0;
            }
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            if (_overlayBackgroundColorHint != nil)
                CGContextSetFillColorWithColor(context, _overlayBackgroundColorHint.CGColor);
            else
                CGContextSetFillColorWithColor(context, TGColorWithHexAndAlpha(0x000000, 0.48f).CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(inset, inset, diameter - inset * 2.0f, diameter - inset * 2.0f));
            
            CGContextSetLineCap(context, kCGLineCapRound);
            CGContextSetLineWidth(context, lineWidth);
            
            if (_overlayStyle == TGMessageImageViewOverlayStyleDefault)
                CGContextSetStrokeColorWithColor(context, [UIColor clearColor].CGColor);
            else if (_overlayStyle == TGMessageImageViewOverlayStyleIncoming) {
                CGContextSetStrokeColorWithColor(context, incomingIconColor.CGColor);
            }
            else if (_overlayStyle == TGMessageImageViewOverlayStyleOutgoing) {
                CGContextSetStrokeColorWithColor(context, outgoingIconColor.CGColor);
            }
            else
                CGContextSetStrokeColorWithColor(context, TGAccentColor().CGColor);
            
            if (_overlayStyle == TGMessageImageViewOverlayStyleDefault)
            {
                CGContextSetBlendMode(context, kCGBlendModeNormal);
                CGContextSetStrokeColorWithColor(context, TGColorWithHexAndAlpha(0xffffff, 1.0f).CGColor);
            }
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            CGFloat start_angle = 2.0f * ((CGFloat)M_PI) * 0.0f - ((CGFloat)M_PI_2);
            CGFloat end_angle = 2.0f * ((CGFloat)M_PI) * (1.0f - _progress) - ((CGFloat)M_PI_2);
            
            CGFloat pathLineWidth = _overlayStyle == TGMessageImageViewOverlayStyleDefault ? 2.0f : 2.0f;
            if (_overlayStyle == TGMessageImageViewOverlayStyleList)
                pathLineWidth = 1.4f;
            CGFloat pathDiameter = diameter - pathLineWidth;
            
            if (ABS(diameter - 37.0f) < 0.1) {
                pathLineWidth = 2.5f;
                pathDiameter = diameter - pathLineWidth * 2.0 - 1.5f;
            } else {
                pathLineWidth = 2.5f;
                pathDiameter = diameter - pathLineWidth * 2.0 - 1.5f;
            }
            
            UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(diameter / 2.0f, diameter / 2.0f) radius:pathDiameter / 2.0f startAngle:start_angle endAngle:end_angle clockwise:false];
            path.lineWidth = pathLineWidth;
            path.lineCapStyle = kCGLineCapRound;
            [path stroke];
            
            CGContextSaveGState(context);
            CGFloat factor = 1.0f;
            if (diameter < 33.0f)
            {
                CGContextScaleCTM(context, 0.64f, 0.64f);
                factor = 1.5625;
            }
            
            [progressFireIcon drawAtPoint:CGPointMake(floor((diameter * factor - progressFireIcon.size.width) / 2.0f), floor((diameter * factor - progressFireIcon.size.height) / 2.0f))];
            
            CGContextRestoreGState(context);
            CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
            
            for (TGMessageImageViewOverlayParticle *particle in _particles)
            {
                CGFloat size = 1.5f;
                CGContextSetAlpha(context, particle->_alpha);
                CGContextFillEllipseInRect(context, CGRectMake(particle->_position.x - size / 2.0f, particle->_position.y - size / 2.0f, size, size));
            }
            
            CGFloat radius = diameter / 2.0f - 3.0f;
            CGPoint center = CGPointMake(diameter / 2.0f, diameter / 2.0f);
            CGPoint v = CGPointMake(sin(end_angle), -cos(end_angle));
            CGPoint c = CGPointMake(-v.y * radius + center.x, v.x * radius + center.y);
            
            const NSInteger newParticlesCount = 1;
            for (NSInteger i = 0; i < newParticlesCount; i++)
            {
                TGMessageImageViewOverlayParticle *newParticle = nil;
                if (_particlesPool.count > 0)
                {
                    newParticle = [_particlesPool lastObject];
                    [_particlesPool removeLastObject];
                }
                else
                {
                    newParticle = [[TGMessageImageViewOverlayParticle alloc] init];
                }
                
                newParticle->_position = c;
                
                CGFloat degrees = (CGFloat)arc4random_uniform(140) - 70.0f;
                CGFloat angle = degrees * (CGFloat)M_PI / 180.0f;
                
                newParticle->_direction = CGPointMake(v.x * cos(angle) - v.y * sin(angle), v.x * sin(angle) + v.y * cos(angle));
                
                newParticle->_alpha = 1.0f;
                newParticle->_currentTime = 0;
                
                newParticle->_lifeTime = 400 + arc4random_uniform(100);
                newParticle->_velocity = 20.0f + (double)arc4random() / UINT32_MAX * 4.0f;
                
                [_particles addObject:newParticle];
            }
            
            CGFloat currentTime = CFAbsoluteTimeGetCurrent() * 1000.0f;
            if (_previousTime > DBL_EPSILON)
                [self particlesTick:currentTime - _previousTime];
            _previousTime = currentTime;
            
            break;
        }
            
        case TGMessageImageViewOverlayViewTypeCompleted:
        {
            CGFloat diameter = _overlayStyle == TGMessageImageViewOverlayStyleList ? 30.0f : self.radius;
            CGFloat inset = 0.0f;
            CGFloat crossSize = _overlayStyle == TGMessageImageViewOverlayStyleList ? 10.0f : 14.0f;
            
            if (ABS(diameter - 37.0f) < 0.1) {
                crossSize = 10.0f;
                inset = 2.0;
            } else if (ABS(diameter - 32.0f) < 0.1) {
                crossSize = 10.0f;
                inset = 0.0;
            }
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            if (_overlayStyle == TGMessageImageViewOverlayStyleDefault)
            {
                if (_overlayBackgroundColorHint != nil)
                    CGContextSetFillColorWithColor(context, _overlayBackgroundColorHint.CGColor);
                else
                    CGContextSetFillColorWithColor(context, TGColorWithHexAndAlpha(0x000000, 0.7f).CGColor);
                CGContextFillEllipseInRect(context, CGRectMake(inset, inset, diameter - inset * 2.0f, diameter - inset * 2.0f));
            }
            
            CGContextSetLineCap(context, kCGLineCapRound);
            
            if (_overlayStyle == TGMessageImageViewOverlayStyleDefault)
            {
                CGContextSetBlendMode(context, kCGBlendModeNormal);
                CGContextSetStrokeColorWithColor(context, TGColorWithHexAndAlpha(0xffffff, 1.0f).CGColor);
            }
            
            CGContextSetBlendMode(context, kCGBlendModeCopy);
            
            CGFloat pathLineWidth = 2.0f;
            CGFloat pathDiameter = diameter - pathLineWidth;

            if (ABS(diameter - 37.0f) < 0.1) {
                pathLineWidth = 2.5f;
                pathDiameter = diameter - pathLineWidth * 2.0 - 1.5f;
            } else if (ABS(diameter - 32.0f) < 0.1) {
                pathLineWidth = 2.0f;
                pathDiameter = diameter - pathLineWidth * 2.0 - 1.5f;
            } else {
                pathLineWidth = 2.5f;
                pathDiameter = diameter - pathLineWidth * 2.0 - 1.5f;
            }

            CGPoint center = CGPointMake(diameter / 2.0f, diameter / 2.0f);
            
            CGContextSetLineWidth(context, pathLineWidth);
            CGContextSetLineCap(context, kCGLineCapRound);
            CGContextSetLineJoin(context, kCGLineJoinRound);
            CGContextSetMiterLimit(context, 10);
            
            CGFloat firstSegment = MAX(0.0f, MIN(1.0f, _checkProgress * 3.0f));
            
            CGPoint s = CGPointMake(center.x - 10.0f, center.y + 1.0f);
            CGPoint p1 = CGPointMake(7.0f, 7.0f);
            CGPoint p2 = CGPointMake(15.0f, -16.0f);
            
            if (diameter < 36.0f)
            {
                s = CGPointMake(center.x - 7.0f, center.y + 1.0f);
                p1 = CGPointMake(4.5f, 4.5f);
                p2 = CGPointMake(10.0f, -11.0f);
            }
            
            if (firstSegment > FLT_EPSILON)
            {
                if (firstSegment < 1.0f)
                {
                    CGContextMoveToPoint(context, s.x + p1.x * firstSegment, s.y + p1.y * firstSegment);
                    CGContextAddLineToPoint(context, s.x, s.y);
                }
                else
                {
                    CGFloat secondSegment = (_checkProgress - 0.33f) * 1.5f;
                    CGContextMoveToPoint(context, s.x + p1.x + p2.x * secondSegment, s.y + p1.y + p2.y * secondSegment);
                    CGContextAddLineToPoint(context, s.x + p1.x, s.y + p1.y);
                    CGContextAddLineToPoint(context, s.x, s.y);
                }
            }
            CGContextStrokePath(context);
        }
            break;
            
        default:
            break;
    }
    
    UIGraphicsPopContext();
}

@end

@interface TGMessageImageViewOverlayView ()
{
    CALayer *_blurredBackgroundLayer;
    TGMessageImageViewOverlayLayer *_contentLayer;
    TGMessageImageViewOverlayLayer *_progressLayer;
    bool _blurless;
}

@end

@implementation TGMessageImageViewOverlayView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.opaque = false;
        self.backgroundColor = [UIColor clearColor];
        
        _blurredBackgroundLayer = [[CALayer alloc] init];
        _blurredBackgroundLayer.frame = CGRectMake(0.5f + 0.125f, 0.5f + 0.125f, 50.0f - 0.25f - 1.0f, 50.0f - 0.25f - 1.0f);
        [self.layer addSublayer:_blurredBackgroundLayer];
        
        _contentLayer = [[TGMessageImageViewOverlayLayer alloc] init];
        _contentLayer.radius = 50.0f;
        _contentLayer.frame = CGRectMake(0.0f, 0.0f, 50.0f, 50.0f);
        _contentLayer.contentsScale = [UIScreen mainScreen].scale;
        [self.layer addSublayer:_contentLayer];
        
        _progressLayer = [[TGMessageImageViewOverlayLayer alloc] init];
        _progressLayer.radius = 50.0f;
        _progressLayer.frame = CGRectMake(0.0f, 0.0f, 50.0f, 50.0f);
        _progressLayer.anchorPoint = CGPointMake(0.5f, 0.5f);
        _progressLayer.contentsScale = [UIScreen mainScreen].scale;
        _progressLayer.hidden = true;
        [self.layer addSublayer:_progressLayer];
    }
    return self;
}

- (void)setIncomingColor:(UIColor *)incomingColor
{
    _incomingColor = incomingColor;
    _contentLayer.incomingColor = incomingColor;
    _progressLayer.incomingColor = incomingColor;
}

- (void)setOutgoingColor:(UIColor *)outgoingColor
{
    _outgoingColor = outgoingColor;
    _contentLayer.outgoingColor = outgoingColor;
    _progressLayer.outgoingColor = outgoingColor;
}

- (void)setIncomingIconColor:(UIColor *)incomingColor
{
    _incomingIconColor = incomingColor;
    _contentLayer.incomingIconColor = incomingColor;
    _progressLayer.incomingIconColor = incomingColor;
}

- (void)setOutgoingIconColor:(UIColor *)outgoingColor
{
    _outgoingIconColor = outgoingColor;
    _contentLayer.outgoingIconColor = outgoingColor;
    _progressLayer.outgoingIconColor = outgoingColor;
}

- (void)setBlurless:(bool)blurless
{
    _blurless = blurless;
    _blurredBackgroundLayer.hidden = blurless;
}

- (void)setRadius:(CGFloat)radius
{
    _blurredBackgroundLayer.frame = CGRectMake(0.5f + 0.125f, 0.5f + 0.125f, radius - 0.25f - 1.0f, radius - 0.25f - 1.0f);
    _contentLayer.radius = radius;
    _contentLayer.frame = CGRectMake(0.0f, 0.0f, radius, radius);
    
    CATransform3D transform = _progressLayer.transform;
    _progressLayer.transform = CATransform3DIdentity;
    _progressLayer.radius = radius;
    _progressLayer.frame = CGRectMake(0.0f, 0.0f, radius, radius);
    _progressLayer.transform = transform;
}

- (void)setOverlayBackgroundColorHint:(UIColor *)overlayBackgroundColorHint
{
    [_contentLayer setOverlayBackgroundColorHint:overlayBackgroundColorHint];
}

- (void)setOverlayStyle:(TGMessageImageViewOverlayStyle)overlayStyle
{
    [_contentLayer setOverlayStyle:overlayStyle];
    [_progressLayer setOverlayStyle:overlayStyle];
    
    if (overlayStyle == TGMessageImageViewOverlayStyleList)
    {
        _contentLayer.frame = CGRectMake(0.0f, 0.0f, 30.0f, 30.0f);
        _progressLayer.frame = CGRectMake(0.0f, 0.0f, 30.0f, 30.0f);
        _progressLayer.anchorPoint = CGPointMake(0.5f, 0.5f);
    }
    else
    {
        _contentLayer.frame = CGRectMake(0.0f, 0.0f, _contentLayer.radius, _contentLayer.radius);
        _progressLayer.frame = CGRectMake(0.0f, 0.0f, _progressLayer.radius, _progressLayer.radius);
        _progressLayer.anchorPoint = CGPointMake(0.5f, 0.5f);
    }
}

- (void)setBlurredBackgroundImage:(UIImage *)blurredBackgroundImage
{
    _blurredBackgroundLayer.contents = (__bridge id)blurredBackgroundImage.CGImage;
    _contentLayer.blurredBackgroundImage = blurredBackgroundImage;
    if (_contentLayer.type == TGMessageImageViewOverlayViewTypeSecretProgress)
        [_contentLayer setNeedsDisplay];
}

- (void)setDownload
{
    [_contentLayer setDownload];
    [_progressLayer setNone];
    _progressLayer.hidden = true;
    _blurredBackgroundLayer.hidden = _blurless;
}

- (void)setPlay
{
    [_contentLayer setPlay];
    [_progressLayer setNone];
    _progressLayer.hidden = true;
    _blurredBackgroundLayer.hidden = _blurless;
}

- (void)setPlayMedia
{
    [_contentLayer setPlayMedia];
    [_progressLayer setNone];
    _progressLayer.hidden = true;
    _blurredBackgroundLayer.hidden = _blurless;
}

- (void)setPauseMedia
{
    [_contentLayer setPauseMedia];
    [_progressLayer setNone];
    _progressLayer.hidden = true;
    _blurredBackgroundLayer.hidden = _blurless;
}

- (void)setSecret:(bool)isViewed
{
    [_contentLayer setSecret:isViewed];
    [_progressLayer setNone];
    _progressLayer.hidden = true;
    _blurredBackgroundLayer.hidden = _blurless;
}

- (void)setNone
{
    [_contentLayer setNone];
    [_progressLayer setNone];
    _progressLayer.hidden = true;
    _blurredBackgroundLayer.hidden = _blurless;
}

- (void)setProgress:(CGFloat)progress animated:(bool)animated
{
    [self setProgress:progress cancelEnabled:true animated:animated];
}

- (void)setProgress:(CGFloat)progress cancelEnabled:(bool)cancelEnabled animated:(bool)animated
{
    if (progress > FLT_EPSILON)
        progress = MAX(progress, 0.027f);
    _blurredBackgroundLayer.hidden = _blurless;
    _progressLayer.hidden = false;
    
    if (!animated)
    {
        _progressLayer.transform = CATransform3DIdentity;
        _progressLayer.frame = CGRectMake(0.0f, 0.0f, _contentLayer.frame.size.width, _contentLayer.frame.size.height);
    }
    
    _progress = progress;
    
    [_progressLayer setProgress:progress animated:animated];
    
    if (cancelEnabled)
        [_contentLayer setProgressCancel];
    else
        [_contentLayer setProgressNoCancel];
}

- (void)setProgressAnimated:(CGFloat)progress duration:(NSTimeInterval)duration cancelEnabled:(bool)cancelEnabled
{
    if (progress > FLT_EPSILON)
        progress = MAX(progress, 0.027f);
    _blurredBackgroundLayer.hidden = _blurless;
    _progressLayer.hidden = false;
    
    _progress = progress;
    
    [_progressLayer setProgress:progress animated:true duration:duration];
    
    if (cancelEnabled)
        [_contentLayer setProgressCancel];
    else
        [_contentLayer setProgressNoCancel];
}

- (void)setSecretProgress:(CGFloat)progress completeDuration:(NSTimeInterval)completeDuration animated:(bool)animated
{
    _blurredBackgroundLayer.hidden = _blurless;
    [_progressLayer setNone];
    _progressLayer.hidden = true;
    
    [_contentLayer setSecretProgress:progress completeDuration:completeDuration animated:animated];
}

- (void)setCompletedAnimated:(bool)animated;
{
    [_contentLayer setCompletedAnimated:animated];
    [_progressLayer setNone];
    _blurredBackgroundLayer.hidden = _blurless;
}

@end


@implementation  TGMessageImageViewOverlayParticle

@end
