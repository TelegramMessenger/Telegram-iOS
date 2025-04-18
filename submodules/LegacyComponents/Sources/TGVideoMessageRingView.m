#import "TGVideoMessageRingView.h"

#import "TGColor.h"

#import "LegacyComponentsInternal.h"

@interface TGVideoMessageShimmerEffectForegroundView : UIView
{
    UIView *_imageContainerView;
    UIView *_imageView;
    
    CGFloat _size;
    bool _hasContainerSize;
    CGRect _absoluteRect;
    CGSize _containerSize;
}

- (instancetype)initWithSize:(CGFloat)size alpha:(CGFloat)alpha;

@end

@implementation TGVideoMessageShimmerEffectForegroundView

- (instancetype)initWithSize:(CGFloat)size alpha:(CGFloat)alpha {
    self = [super initWithFrame:CGRectZero];
    if (self != nil) {
        _size = size;
        
        _imageContainerView = [[UIView alloc] init];
        _imageView = [[UIView alloc] init];
        
        self.clipsToBounds = true;
        
        [_imageContainerView addSubview:_imageView];
        [self addSubview:_imageContainerView];
        
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, 16), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        CGRect bounds = CGRectMake(0, 0, size, 16);
        CGContextClearRect(context, bounds);
        CGContextClipToRect(context, bounds);
        
        UIColor *transparentColor = [UIColor colorWithWhite:1.0 alpha:0.0];
        UIColor *peakColor = [UIColor colorWithWhite:1.0 alpha:alpha];
                
        CGColorRef colors[3] = {
            CGColorRetain(transparentColor.CGColor),
            CGColorRetain(peakColor.CGColor),
            CGColorRetain(transparentColor.CGColor)
        };

        CFArrayRef colorsArray = CFArrayCreate(kCFAllocatorDefault, (const void **)&colors, 3, NULL);
        CGFloat locations[3] = {0.0f, 0.5, 1.0};

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colorsArray, (CGFloat const *)&locations);

        CGContextDrawLinearGradient(context, gradient, CGPointMake(0, 0), CGPointMake(size, 0), kNilOptions);

        CFRelease(colorsArray);
        CFRelease(colors[0]);
        CFRelease(colors[1]);

        CGColorSpaceRelease(colorSpace);
        CFRelease(gradient);
        
        UIImage *image = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:25 topCapHeight:25];
        UIGraphicsEndImageContext();
        
        _imageView.backgroundColor = [UIColor colorWithPatternImage:image];
    }
    return self;
}

- (void)updateAbsoluteRect:(CGRect)absoluteRect containerSize:(CGSize)containerSize {
    _hasContainerSize = true;
    
    CGRect previousAbsoluteRect = _absoluteRect;
    CGSize previousContainerSize = _containerSize;
    _absoluteRect = absoluteRect;
    _containerSize = containerSize;
    
    if (!CGSizeEqualToSize(previousContainerSize, containerSize)) {
        [self setupAnimation];
    }
    
    if (!CGRectEqualToRect(previousAbsoluteRect, absoluteRect)) {
        _imageContainerView.frame = CGRectMake(-absoluteRect.origin.x, -absoluteRect.origin.y, containerSize.width, containerSize.height);
    }
}


- (void)setupAnimation {
    if (!_hasContainerSize) {
        return;
    }
    
    CGFloat gradientHeight = _size;
    _imageView.frame = CGRectMake(-gradientHeight, 0, gradientHeight, _containerSize.height);
    
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position.x"];
    animation.fromValue = @(_imageView.center.x);
    animation.toValue = @(_imageView.center.x + _containerSize.width + gradientHeight);
    animation.duration = 1.3f;
    animation.repeatCount = INFINITY;
    animation.beginTime = 1.0;
    [_imageView.layer addAnimation:animation forKey:@"position"];
}

@end

@interface TGVideoMessageShimmerView ()
{
    TGVideoMessageShimmerEffectForegroundView *_effectView;
    UIImageView *_imageView;
    
    UIView *_borderView;
    UIView *_borderMaskView;
    TGVideoMessageShimmerEffectForegroundView *_borderEffectView;
}
@end

@implementation TGVideoMessageShimmerView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.clipsToBounds = true;
        self.layer.cornerRadius = frame.size.width / 2.0f;
        if (@available(iOS 13.0, *)) {
            self.layer.cornerCurve = kCACornerCurveCircular;
        }
        
        _effectView = [[TGVideoMessageShimmerEffectForegroundView alloc] initWithSize:320 alpha:0.3];
        _effectView.layer.compositingFilter = @"screenBlendMode";
        _effectView.frame = self.bounds;
        
        _borderView = [[UIView alloc] initWithFrame:self.bounds];
        _borderMaskView = [[UIView alloc] initWithFrame:self.bounds];
        _borderMaskView.layer.borderWidth = 1.0;
        _borderMaskView.layer.borderColor = [UIColor whiteColor].CGColor;
        _borderMaskView.layer.cornerRadius = frame.size.width / 2.0f;
        if (@available(iOS 13.0, *)) {
            _borderMaskView.layer.cornerCurve = kCACornerCurveCircular;
        }
        _borderView.maskView = _borderMaskView;
        
        _borderEffectView = [[TGVideoMessageShimmerEffectForegroundView alloc] initWithSize:400 alpha:0.45];
        _borderEffectView.layer.compositingFilter = @"screenBlendMode";
        _borderEffectView.frame = self.bounds;
        
        [self addSubview:_effectView];
        [self addSubview:_borderView];
        [_borderView addSubview:_borderEffectView];
    }
    return self;
}

- (void)updateAbsoluteRect:(CGRect)absoluteRect containerSize:(CGSize)containerSize {
    [_effectView updateAbsoluteRect:absoluteRect containerSize:containerSize];
    [_borderEffectView updateAbsoluteRect:absoluteRect containerSize:containerSize];
}

@end

@interface TGVideoMessageRingView ()
{
    CGFloat _value;
}
@end

@implementation TGVideoMessageRingView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)setValue:(CGFloat)value
{
    _value = value;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    if (_value < DBL_EPSILON)
        return;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, self.accentColor.CGColor);

    CGMutablePathRef path = CGPathCreateMutable();
    CGPoint centerPoint = CGPointMake(rect.size.width / 2.0f, rect.size.height / 2.0f);
    CGFloat lineWidth = 4.0f;
    
    CGPathAddArc(path, NULL, centerPoint.x, centerPoint.y, rect.size.width / 2.0f - lineWidth / 2.0f, -M_PI_2, -M_PI_2 + 2 * M_PI * _value, false);
    
    CGPathRef strokedArc = CGPathCreateCopyByStrokingPath(path, NULL, lineWidth, kCGLineCapRound, kCGLineJoinMiter, 10);
    CGPathRelease(path);
    
    CGContextAddPath(context, strokedArc);
    CGPathRelease(strokedArc);
    
    CGContextFillPath(context);
}

@end
