#import "TGPhotoPaintColorPicker.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import <LegacyComponents/TGPaintUtils.h>

#import "TGPaintSwatch.h"

const CGFloat TGPhotoPaintColorWeightGestureRange = 320.0f;
const CGFloat TGPhotoPaintVerticalThreshold = 5.0f;
const CGFloat TGPhotoPaintPreviewOffset = -70.0f;
const CGFloat TGPhotoPaintPreviewScale = 2.0f;
const CGFloat TGPhotoPaintDefaultBrushWeight = 0.08f;
const CGFloat TGPhotoPaintDefaultColorLocation = 0.0f;

@interface TGPhotoPaintColorPickerKnobCircleView : UIView
{
    CGFloat _strokeIntensity;
}

@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) bool strokesLowContrastColors;

@end

@interface TGPhotoPaintColorPickerKnob : UIView
{
    UIView *_wrapperView;
    UIImageView *_shadowView;
    TGPhotoPaintColorPickerKnobCircleView *_backgroundView;
    TGPhotoPaintColorPickerKnobCircleView *_colorView;
    
    bool _dragging;
    CGFloat _weight;
}

- (void)setColor:(UIColor *)color;
- (void)setWeight:(CGFloat)weight;

@property (nonatomic, assign) bool dragging;
@property (nonatomic, assign) bool changingWeight;
@property (nonatomic, assign) UIInterfaceOrientation orientation;

@end

@interface TGPhotoPaintColorPickerBackground : UIView

+ (NSArray *)colors;
+ (NSArray *)locations;

@end

@interface TGPhotoPaintColorPicker () <UIGestureRecognizerDelegate>
{
    TGPhotoPaintColorPickerBackground *_backgroundView;
    TGPhotoPaintColorPickerKnob *_knobView;
    
    UIPanGestureRecognizer *_panGestureRecognizer;
    UILongPressGestureRecognizer *_pressGestureRecognizer;
    UITapGestureRecognizer *_tapGestureRecognizer;
    
    CGPoint _gestureStartLocation;
    
    CGFloat _location;
    bool _dragging;
    
    CGFloat _weight;
}
@end

@implementation TGPhotoPaintColorPicker

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _backgroundView = [[TGPhotoPaintColorPickerBackground alloc] initWithFrame:self.bounds];
        _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_backgroundView];
        
        _knobView = [[TGPhotoPaintColorPickerKnob alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 24.0f, 24.0f)];
        [_knobView setColor:[TGPhotoPaintColorPicker colorForLocation:0.0f]];
        [self addSubview:_knobView];
        
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _panGestureRecognizer.delegate = self;
        [self addGestureRecognizer:_panGestureRecognizer];
        
        _pressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handlePress:)];
        _pressGestureRecognizer.delegate = self;
        _pressGestureRecognizer.minimumPressDuration = 0.1;
        [self addGestureRecognizer:_pressGestureRecognizer];
        
        _tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
        [self addGestureRecognizer:_tapGestureRecognizer];
        
        _location = [self restoreLastColorLocation];
        _weight = TGPhotoPaintDefaultBrushWeight;
    }
    return self;
}

- (CGFloat)restoreLastColorLocation
{
    NSNumber *lastColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"TG_paintLastColorLocation_v0"];
    if (lastColor != nil)
        return [lastColor floatValue];

    return TGPhotoPaintDefaultColorLocation;
}

- (void)storeCurrentColorLocation
{
    [[NSUserDefaults standardUserDefaults] setObject:@(_location) forKey:@"TG_paintLastColorLocation_v0"];
}

- (void)setOrientation:(UIInterfaceOrientation)orientation
{
    _orientation = orientation;
    _knobView.orientation = orientation;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    if (CGRectContainsPoint(CGRectInset(self.bounds, -30.0f, -10.0f), point))
        return true;
    
    return [super pointInside:point withEvent:event];
}

- (TGPaintSwatch *)swatch
{
    return [TGPaintSwatch swatchWithColor:[TGPhotoPaintColorPicker colorForLocation:_location] colorLocation:_location brushWeight:_weight];
}

- (void)setSwatch:(TGPaintSwatch *)swatch
{
    [self setLocation:swatch.colorLocation];
    [self setWeight:swatch.brushWeight];
}

- (UIColor *)color
{
    return [TGPhotoPaintColorPicker colorForLocation:_location];
}

- (void)setLocation:(CGFloat)location
{
    [self setLocation:location animated:false];
}

- (void)setLocation:(CGFloat)location animated:(bool)animated
{
    _location = location;
    [_knobView setColor:[TGPhotoPaintColorPicker colorForLocation:_location]];
    
    if (animated)
    {
        [UIView animateWithDuration:0.3 delay:0.0 usingSpringWithDamping:0.85f initialSpringVelocity:0.0f options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionLayoutSubviews animations:^
        {
            [self layoutSubviews];
        } completion:nil];
    }
    else
    {
        [self setNeedsLayout];
    }
}

- (void)setWeight:(CGFloat)weight
{
    _weight = weight;
    [_knobView setWeight:weight];
}

- (void)setDragging:(bool)dragging
{
    _dragging = dragging;
    [_knobView setDragging:dragging];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)__unused gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)__unused otherGestureRecognizer
{
    return true;
}

- (bool)_hasBeganChangingWeight:(CGPoint)location
{
    switch (self.orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
            if (location.x > self.frame.size.width + TGPhotoPaintVerticalThreshold)
                return true;
            
        case UIInterfaceOrientationLandscapeRight:
            if (location.x < -TGPhotoPaintVerticalThreshold)
                return true;
            
        default:
            if (location.y < -TGPhotoPaintVerticalThreshold)
                return true;
    }
    
    return false;
}

- (CGFloat)_weightLocation:(CGPoint)location
{
    CGFloat weightLocation = 0.0f;
    switch (self.orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
            weightLocation = (location.x - self.frame.size.width - TGPhotoPaintVerticalThreshold) / TGPhotoPaintColorWeightGestureRange;
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            weightLocation = ((location.x * -1) - TGPhotoPaintVerticalThreshold) / TGPhotoPaintColorWeightGestureRange;
            break;
            
        default:
            weightLocation = ((location.y * -1) - TGPhotoPaintVerticalThreshold) / TGPhotoPaintColorWeightGestureRange;
            break;
    }
    
    return MAX(0.0f, MIN(1.0f, weightLocation));
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    CGPoint location = [gestureRecognizer locationInView:gestureRecognizer.view];
    
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            _gestureStartLocation = location;
            [self setDragging:true];
            
            if (self.beganPicking != nil)
                self.beganPicking();
        }
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            CGFloat colorLocation = MAX(0.0f, MIN(1.0f, self.frame.size.width > self.frame.size.height ? location.x / gestureRecognizer.view.frame.size.width : location.y / gestureRecognizer.view.frame.size.height));
            [self setLocation:colorLocation];
            
            if ([self _hasBeganChangingWeight:location])
            {
                [_knobView setChangingWeight:true];
                CGFloat weightLocation = [self _weightLocation:location];
                [self setWeight:weightLocation];
            }
            
            if (self.valueChanged != nil)
                self.valueChanged();
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        {
            [_knobView setChangingWeight:false];
            [self setDragging:false];
            
            if (self.finishedPicking != nil)
                self.finishedPicking();
            
            [self storeCurrentColorLocation];
        }
            break;
            
        case UIGestureRecognizerStateCancelled:
        {
            [_knobView setChangingWeight:false];
        }
            break;
            
        default:
            break;
    }
}

- (void)handlePress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    CGPoint location = [gestureRecognizer locationInView:gestureRecognizer.view];
    
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            if (!CGRectContainsPoint(_knobView.frame, location))
            {
                CGFloat colorLocation = MAX(0.0f, MIN(1.0f, self.frame.size.width > self.frame.size.height ? location.x / gestureRecognizer.view.frame.size.width : location.y / gestureRecognizer.view.frame.size.height));
                [self setLocation:colorLocation animated:true];
            }
            
            [self setDragging:true];
            
            if (self.beganPicking != nil)
                self.beganPicking();
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        {
            [self setDragging:false];
            
            if (self.finishedPicking != nil)
                self.finishedPicking();
            
            [self storeCurrentColorLocation];
        }
            break;
            
        default:
            break;
    }
}

- (void)handleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    CGPoint location = [gestureRecognizer locationInView:gestureRecognizer.view];
    if (!CGRectContainsPoint(_knobView.frame, location))
    {
        CGFloat colorLocation = MAX(0.0f, MIN(1.0f, self.frame.size.width > self.frame.size.height ? location.x / gestureRecognizer.view.frame.size.width : location.y / gestureRecognizer.view.frame.size.height));
        [self setLocation:colorLocation animated:true];
        
        if (self.finishedPicking != nil)
            self.finishedPicking();
        
        [self storeCurrentColorLocation];
    }
}

+ (UIColor *)colorForLocation:(CGFloat)location
{
    NSArray *locations = [TGPhotoPaintColorPickerBackground locations];
    NSArray *colors = [TGPhotoPaintColorPickerBackground colors];
    
    if (location < FLT_EPSILON)
        return [UIColor colorWithCGColor:(CGColorRef)colors.firstObject];
    else if (location > 1 - FLT_EPSILON)
        return [UIColor colorWithCGColor:(CGColorRef)colors.lastObject];
    
    __block NSInteger leftIndex = -1;
    __block NSInteger rightIndex = -1;
    
    [locations enumerateObjectsUsingBlock:^(NSNumber *value, NSUInteger index, BOOL *stop)
    {
        if (index > 0)
        {
            if (value.doubleValue > location)
            {
                leftIndex = index - 1;
                rightIndex = index;
                *stop = true;
            }
        }
    }];
    
    CGFloat leftLocation = [locations[leftIndex] doubleValue];
    UIColor *leftColor = [UIColor colorWithCGColor:(CGColorRef)colors[leftIndex]];
    
    CGFloat rightLocation = [locations[rightIndex] doubleValue];
    UIColor *rightColor = [UIColor colorWithCGColor:(CGColorRef)colors[rightIndex]];
    
    CGFloat factor = (location - leftLocation) / (rightLocation - leftLocation);
    return [self _interpolateColor:leftColor withColor:rightColor factor:factor];
}

+ (void)_colorComponentsForColor:(UIColor *)color red:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue
{
    NSInteger componentsCount = CGColorGetNumberOfComponents(color.CGColor);
    const CGFloat *components = CGColorGetComponents(color.CGColor);
    
    CGFloat r = 0.0f;
    CGFloat g = 0.0f;
    CGFloat b = 0.0f;
    CGFloat a = 1.0f;
    
    if (componentsCount == 4)
    {
        r = components[0];
        g = components[1];
        b = components[2];
        a = components[3];
    }
    else
    {
        r = g = b = components[0];
    }

    *red = r;
    *green = g;
    *blue = b;
}

+ (UIColor *)_interpolateColor:(UIColor *)color1 withColor:(UIColor *)color2 factor:(CGFloat)factor
{
    factor = MIN(MAX(factor, 0.0), 1.0);

    CGFloat r1 = 0, r2 = 0;
    CGFloat g1 = 0, g2 = 0;
    CGFloat b1 = 0, b2 = 0;
    
    [self _colorComponentsForColor:color1 red:&r1 green:&g1 blue:&b1];
    [self _colorComponentsForColor:color2 red:&r2 green:&g2 blue:&b2];
    
    CGFloat r = r1 + (r2 - r1) * factor;
    CGFloat g = g1 + (g2 - g1) * factor;
    CGFloat b = b1 + (b2 - b1) * factor;
    
    return [UIColor colorWithRed:r green:g blue:b alpha:1.0f];
}

- (void)layoutSubviews
{
    CGFloat pos = self.frame.size.width > self.frame.size.height ? -_knobView.frame.size.width / 2.0f + self.frame.size.width * _location : -_knobView.frame.size.height / 2.0f + self.frame.size.height * _location;
    
    _knobView.frame = self.frame.size.width > self.frame.size.height ? CGRectMake(pos, (self.frame.size.height - _knobView.frame.size.height) / 2.0f, _knobView.frame.size.width, _knobView.frame.size.height) : CGRectMake((self.frame.size.width - _knobView.frame.size.width) / 2.0f, pos, _knobView.frame.size.width, _knobView.frame.size.height);
}

@end

@implementation TGPhotoPaintColorPickerKnobCircleView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        self.opaque = false;
    }
    return self;
}

- (void)setColor:(UIColor *)color
{
    _color = color;
    
    if (self.strokesLowContrastColors)
    {
        CGFloat strokeIntensity = 0.0f;
        CGFloat hue;
        CGFloat saturation;
        CGFloat brightness;
        CGFloat alpha;
        
        bool success = [color getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
        if (success && hue < FLT_EPSILON && saturation < FLT_EPSILON && brightness > 0.92f)
            strokeIntensity = (brightness - 0.92f) / 0.08f;
        
        _strokeIntensity = strokeIntensity;
    }
    
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextSetFillColorWithColor(context, self.color.CGColor);
    CGContextFillEllipseInRect(context, rect);
    
    if (_strokeIntensity > FLT_EPSILON)
    {
        CGContextSetLineWidth(context, 1.0f);
        CGContextSetStrokeColorWithColor(context, [UIColor colorWithWhite:0.88f alpha:_strokeIntensity].CGColor);
        CGContextStrokeEllipseInRect(context, CGRectInset(rect, 1.0f, 1.0f));
    }
}

@end


const CGFloat TGPhotoPaintColorSmallCircle = 4.0f;
const CGFloat TGPhotoPaintColorLargeCircle = 20.0f;

@implementation TGPhotoPaintColorPickerKnob

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.userInteractionEnabled = false;
        
        _wrapperView = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:_wrapperView];
        
        static UIImage *shadowImage = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(48.0f, 48.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            
            CGContextSetShadowWithColor(context, CGSizeMake(0, 1.5f), 4.0f, [UIColor colorWithWhite:0.0f alpha:0.7f].CGColor);
            CGContextSetFillColorWithColor(context, UIColorRGBA(0x000000, 1.0f).CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(4.0f, 4.0f, 40.0f, 40.0f));
            shadowImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _shadowView = [[UIImageView alloc] initWithImage:shadowImage];
        _shadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _shadowView.frame = CGRectInset(_wrapperView.bounds, -2, -2);
        [_wrapperView addSubview:_shadowView];
        
        _backgroundView = [[TGPhotoPaintColorPickerKnobCircleView alloc] initWithFrame:self.bounds];
        _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _backgroundView.color = [UIColor whiteColor];
        [_wrapperView addSubview:_backgroundView];
        
        _colorView = [[TGPhotoPaintColorPickerKnobCircleView alloc] init];
        _colorView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        _colorView.center = TGPaintCenterOfRect(self.bounds);
        _colorView.color = [UIColor blueColor];
        _colorView.strokesLowContrastColors = true;
        [self setWeight:0.5f];
        [_wrapperView addSubview:_colorView];
    }
    return self;
}

- (void)setColor:(UIColor *)color
{
    [_colorView setColor:color];
}

- (void)setWeight:(CGFloat)size
{
    _weight = size;
    if (_dragging)
        [self updateLocationAnimated:true updateColorSize:false];
    
    CGFloat diameter = [self _circleDiameterForBrushWeight:size zoomed:_dragging];
    [_colorView setBounds:CGRectMake(0, 0, diameter, diameter)];
}

- (void)setDragging:(bool)dragging
{
    if (dragging == _dragging)
        return;
    
    _dragging = dragging;
    [self updateLocationAnimated:true updateColorSize:true];
}

- (CGFloat)_circleDiameterForBrushWeight:(CGFloat)size zoomed:(bool)zoomed
{
    CGFloat result = TGPhotoPaintColorSmallCircle + (TGPhotoPaintColorLargeCircle - TGPhotoPaintColorSmallCircle) * size;
    result = zoomed ? TGRetinaFloor(result) * TGPhotoPaintPreviewScale : floor(result);
    return result;
}

- (void)updateLocationAnimated:(bool)animated updateColorSize:(bool)updateColorSize
{
    void (^changeBlock)(void) = ^
    {
        CGPoint center = TGPaintCenterOfRect(self.bounds);
        CGFloat scale = 1.0f;
        if (_dragging)
        {
            scale = TGPhotoPaintPreviewScale;
         
            CGFloat offset = TGPhotoPaintPreviewOffset;
            if (self.changingWeight)
                offset -= _weight * TGPhotoPaintColorWeightGestureRange;
            
            switch (self.orientation)
            {
                case UIInterfaceOrientationLandscapeLeft:
                    center.x -= offset;
                    break;
                
                case UIInterfaceOrientationLandscapeRight:
                    center.x += offset;
                    break;
                    
                default:
                    center.y += offset;
                    break;
            }
        }
        
        _wrapperView.center = center;
        _wrapperView.bounds = CGRectMake(0, 0, 24.0f * scale, 24.0f * scale);
        
        if (updateColorSize)
        {
            CGFloat diameter = [self _circleDiameterForBrushWeight:_weight zoomed:_dragging];
            [_colorView setBounds:CGRectMake(0, 0, diameter, diameter)];
        }
    };
    
    if (animated)
    {
        [UIView animateWithDuration:0.3 delay:0.0 usingSpringWithDamping:0.85f initialSpringVelocity:0.0f options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionLayoutSubviews animations:changeBlock completion:nil];
    }
    else
    {
        changeBlock();
    }
}

@end


static void addRoundedRectToPath(CGContextRef context, CGRect rect, CGFloat ovalWidth, CGFloat ovalHeight)
{
    CGFloat fw, fh;
    if (ovalWidth == 0 || ovalHeight == 0)
    {
        CGContextAddRect(context, rect);
        return;
    }
    
    CGContextSaveGState(context);
    CGContextTranslateCTM (context, CGRectGetMinX(rect), CGRectGetMinY(rect));
    CGContextScaleCTM (context, ovalWidth, ovalHeight);
    fw = CGRectGetWidth (rect) / ovalWidth;
    fh = CGRectGetHeight (rect) / ovalHeight;
    CGContextMoveToPoint(context, fw, fh/2);
    CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);
    CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1);
    CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1);
    CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1);
    CGContextClosePath(context);
    CGContextRestoreGState(context);
}

@implementation TGPhotoPaintColorPickerBackground

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
        self.opaque = false;
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGFloat radius = rect.size.width > rect.size.height ? rect.size.height / 2.0f : rect.size.width / 2.0f;
    addRoundedRectToPath(context, self.frame, radius, radius);
    CGContextClip(context);
    
    CFArrayRef colors = (__bridge CFArrayRef)[TGPhotoPaintColorPickerBackground colors];
    CGFloat locations[[TGPhotoPaintColorPickerBackground colors].count];
    [TGPhotoPaintColorPickerBackground fillLocations:locations];
    
    CGColorSpaceRef colorSpc = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpc, colors, locations);
    
    if (rect.size.width > rect.size.height)
    {
        CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, rect.size.height / 2.0f), CGPointMake(rect.size.width, rect.size.height / 2.0f), kCGGradientDrawsAfterEndLocation);
    }
    else
    {
        CGContextDrawLinearGradient(context, gradient, CGPointMake(rect.size.width / 2.0f, 0.0f), CGPointMake(rect.size.width / 2.0f, rect.size.height), kCGGradientDrawsAfterEndLocation);
    }
    
    CGContextSetBlendMode(context, kCGBlendModeClear);
    CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
    
    CGColorSpaceRelease(colorSpc);
    CGGradientRelease(gradient);
}

+ (NSArray *)colors
{
    static dispatch_once_t onceToken;
    static NSArray *colors;
    dispatch_once(&onceToken, ^
    {
        colors = @
        [
            (id)UIColorRGB(0xea2739).CGColor, //red
            (id)UIColorRGB(0xdb3ad2).CGColor, //pink
            (id)UIColorRGB(0x3051e3).CGColor, //blue
            (id)UIColorRGB(0x49c5ed).CGColor, //cyan
            (id)UIColorRGB(0x80c864).CGColor, //green
            (id)UIColorRGB(0xfcde65).CGColor, //yellow
            (id)UIColorRGB(0xfc964d).CGColor, //orange
            (id)UIColorRGB(0x000000).CGColor, //black
            (id)UIColorRGB(0xffffff).CGColor  //white
        ];
    });
    return colors;
}

+ (NSArray *)locations
{
    static dispatch_once_t onceToken;
    static NSArray *locations;
    dispatch_once(&onceToken, ^
    {
        locations = @
        [
            @0.0f,  //red
            @0.14f, //pink
            @0.24f, //blue
            @0.39f, //cyan
            @0.49f, //green
            @0.62f, //yellow
            @0.73f, //orange
            @0.85f, //black
            @1.0f   //white
        ];
    });
    return locations;
}

+ (void)fillLocations:(CGFloat *)buf
{
    NSArray *locations = [self locations];
    [locations enumerateObjectsUsingBlock:^(NSNumber *location, NSUInteger index, __unused BOOL *stop)
    {
        buf[index] = location.doubleValue;
    }];
}

@end
