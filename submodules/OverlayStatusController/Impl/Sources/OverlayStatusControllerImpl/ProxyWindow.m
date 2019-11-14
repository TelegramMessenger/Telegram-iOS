#import "ProxyWindow.h"

#define UIColorRGB(rgb) ([[UIColor alloc] initWithRed:(((rgb >> 16) & 0xff) / 255.0f) green:(((rgb >> 8) & 0xff) / 255.0f) blue:(((rgb) & 0xff) / 255.0f) alpha:1.0f])
#define UIColorRGBA(rgb,a) ([[UIColor alloc] initWithRed:(((rgb >> 16) & 0xff) / 255.0f) green:(((rgb >> 8) & 0xff) / 255.0f) blue:(((rgb) & 0xff) / 255.0f) alpha:a])

#ifdef __LP64__
#   define CGFloor floor
#else
#   define CGFloor floorf
#endif

static inline void dispatchAfter(double delay, dispatch_queue_t queue, dispatch_block_t block)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((delay) * NSEC_PER_SEC)), queue, block);
}

static UIFont *mediumSystemFontOfSize(CGFloat size) {
    static bool useSystem = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        useSystem = [[[UIDevice currentDevice] systemVersion] intValue] >= 9;
    });
    
    if (useSystem) {
        return [UIFont systemFontOfSize:size weight:UIFontWeightMedium];
    } else {
        return [UIFont fontWithName:@"HelveticaNeue-Medium" size:size];
    }
}


static bool readCGFloat(NSString *string, int *position, CGFloat *result) {
    int start = *position;
    bool seenDot = false;
    int length = (int)string.length;
    while (*position < length) {
        unichar c = [string characterAtIndex:*position];
        (*position)++;
        
        if (c == '.') {
            if (seenDot) {
                return false;
            } else {
                seenDot = true;
            }
        } else if ((c < '0' || c > '9') && c != '-') {
            if (*position == start) {
                *result = 0.0f;
                return true;
            } else {
                *result = [[string substringWithRange:NSMakeRange(start, *position - start)] floatValue];
                return true;
            }
        }
    }
    if (*position == start) {
        *result = 0.0f;
        return true;
    } else {
        *result = [[string substringWithRange:NSMakeRange(start, *position - start)] floatValue];
        return true;
    }
    return true;
}

static void drawSvgPath(CGContextRef context, NSString *path) {
    int position = 0;
    int length = (int)path.length;
    
    while (position < length) {
        unichar c = [path characterAtIndex:position];
        position++;
        
        if (c == ' ') {
            continue;
        }
        
        if (c == 'M') { // M
            CGFloat x = 0.0f;
            CGFloat y = 0.0f;
            readCGFloat(path, &position, &x);
            readCGFloat(path, &position, &y);
            CGContextMoveToPoint(context, x, y);
        } else if (c == 'L') { // L
            CGFloat x = 0.0f;
            CGFloat y = 0.0f;
            readCGFloat(path, &position, &x);
            readCGFloat(path, &position, &y);
            CGContextAddLineToPoint(context, x, y);
        } else if (c == 'C') { // C
            CGFloat x1 = 0.0f;
            CGFloat y1 = 0.0f;
            CGFloat x2 = 0.0f;
            CGFloat y2 = 0.0f;
            CGFloat x = 0.0f;
            CGFloat y = 0.0f;
            readCGFloat(path, &position, &x1);
            readCGFloat(path, &position, &y1);
            readCGFloat(path, &position, &x2);
            readCGFloat(path, &position, &y2);
            readCGFloat(path, &position, &x);
            readCGFloat(path, &position, &y);
            
            CGContextAddCurveToPoint(context, x1, y1, x2, y2, x, y);
        } else if (c == 'Z') { // Z
            CGContextClosePath(context);
            CGContextFillPath(context);
            CGContextBeginPath(context);
        } else if (c == 'S') { // Z
            CGContextClosePath(context);
            CGContextStrokePath(context);
            CGContextBeginPath(context);
        } else if (c == 'U') { // Z
            CGContextStrokePath(context);
            CGContextBeginPath(context);
        }
    }
}

static bool ProxyWindowIsLight = true;

@interface ProxySpinnerView : UIView

@property (nonatomic, copy) void (^onSuccess)(void);

- (instancetype)initWithFrame:(CGRect)frame light:(bool)light;

- (void)setSucceed;

@end

@interface ProxyWindowController ()
{
    bool _light;
    NSString *_text;
    UIImage *_icon;
    bool _isShield;
    bool _showCheck;
    UIVisualEffectView *_effectView;
    UIView *_backgroundView;
    ProxySpinnerView *_spinner;
    UIImageView *_shield;
    UILabel *_label;
}

@property (nonatomic, weak) UIWindow *weakWindow;
@property (nonatomic, strong) UIView *containerView;

@end

@implementation ProxyWindowController

+ (UIImage *)generateShieldImage:(bool)isLight {
    UIColor *color = isLight ? UIColorRGB(0x5a5a5a) : [UIColor whiteColor];
    
    NSString *code = @"M100,6.56393754 L6,48.2657557 L6,110.909091 C6,169.509174 46.3678836,223.966692 100,237.814087 C153.632116,223.966692 194,169.509174 194,110.909091 L194,48.2657557 L100,6.56393754 S";
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(67, 82), false, 0.0f);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context, 0.333333f, 0.333333f);
    CGContextSetLineWidth(context, 12.0f);
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    drawSvgPath(context, code);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (instancetype)initWithLight:(bool)light text:(NSString *)text icon:(UIImage *)icon isShield:(bool)isShield showCheck:(bool)showCheck {
    self = [super init];
    if (self != nil) {
        _light = light;
        _text = text;
        _icon = icon;
        _isShield = isShield;
        _showCheck = showCheck;
    }
    return self;
}

- (void)loadView
{
    [super loadView];
    
    if (self.view.bounds.size.width > FLT_EPSILON) {
        [self updateLayout];
    }
}

- (void)updateLayout {
    CGSize spinnerSize = CGSizeMake(48.0, 48.0);
    CGSize containerSize = CGSizeMake(156.0, 176.0);
    if (_icon == nil) {
        containerSize = CGSizeMake(207.0, 177.0);
        spinnerSize = CGSizeMake(40.0, 40.0);
    }
    
    if (_text.length != 0) {
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.lineBreakMode = NSLineBreakByWordWrapping;
        style.lineSpacing = 2.0f;
        style.alignment = NSTextAlignmentCenter;
        
        NSDictionary *attributes = @{NSForegroundColorAttributeName:_light ? UIColorRGB(0x5a5a5a) : [UIColor whiteColor], NSFontAttributeName:mediumSystemFontOfSize(17.0f), NSParagraphStyleAttributeName:style};
        NSAttributedString *string = [[NSAttributedString alloc] initWithString:_text attributes:attributes];
        
        UILabel *label = [[UILabel alloc] init];
        label.font = [UIFont systemFontOfSize:15.0f];
        label.numberOfLines = 0;
        label.textAlignment = NSTextAlignmentCenter;
        label.attributedText = string;
        CGSize labelSize = [label sizeThatFits:CGSizeMake(containerSize.width - 10.0 * 2.0, CGFLOAT_MAX)];
        
        containerSize.height += labelSize.height - 38.0;
    }
    
    CGRect spinnerFrame = CGRectMake((containerSize.width - spinnerSize.width) / 2.0f, _icon != nil ? 40.0f : 45.0, spinnerSize.width, spinnerSize.height);
    if (_containerView == nil) {
        _containerView = [[UIView alloc] initWithFrame:CGRectMake(CGFloor(self.view.frame.size.width - containerSize.width) / 2, CGFloor(self.view.frame.size.height - containerSize.height) / 2, containerSize.width, containerSize.height)];
        _containerView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
        _containerView.alpha = 0.0f;
        _containerView.clipsToBounds = true;
        _containerView.layer.cornerRadius = 20.0f;
        [self.view addSubview:_containerView];
        
        if ([[[UIDevice currentDevice] systemVersion] intValue] >= 9) {
            _effectView = [[UIVisualEffectView alloc] initWithEffect:_light ? [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight] : [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
            _effectView.frame = _containerView.bounds;
            [_containerView addSubview:_effectView];
            
            if (_light)
            {
                UIView *tintView = [[UIView alloc] initWithFrame:_effectView.bounds];
                tintView.backgroundColor = UIColorRGBA(0xf4f4f4, 0.75f);
                [_containerView addSubview:tintView];
            }
        } else {
            _backgroundView = [[UIView alloc] initWithFrame:_containerView.bounds];
            _backgroundView.backgroundColor = _light ? UIColorRGBA(0xeaeaea, 0.92f) : UIColorRGBA(0x000000, 0.9f);
            [_containerView addSubview:_backgroundView];
        }
        
        UIColor *color = _light ? UIColorRGB(0x5a5a5a) : [UIColor whiteColor];
        
        UIImage *image = nil;
        if (_icon != nil) {
            image = _icon;
        } else {
            CGSize size = CGSizeMake(66.0, 66.0);
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetStrokeColorWithColor(context, color.CGColor);
            CGFloat lineWidth = 4.0f;
            CGContextSetLineWidth(context, lineWidth);
            CGContextStrokeEllipseInRect(context, CGRectMake(lineWidth / 2.0f, lineWidth / 2.0f, size.width - lineWidth, size.height - lineWidth));
            image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
        _shield = [[UIImageView alloc] initWithImage:image];
        _shield.frame = CGRectMake((_containerView.frame.size.width - _shield.frame.size.width) / 2.0f, _isShield ? 23.0f : 30.0, _shield.frame.size.width, _shield.frame.size.height);
        [_containerView addSubview:_shield];
        
        _spinner = [[ProxySpinnerView alloc] initWithFrame:spinnerFrame light:_light];
        [_containerView addSubview:_spinner];
        
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.lineBreakMode = NSLineBreakByWordWrapping;
        style.lineSpacing = 2.0f;
        style.alignment = NSTextAlignmentCenter;
        
        NSDictionary *attributes = @{NSForegroundColorAttributeName:_light ? UIColorRGB(0x5a5a5a) : [UIColor whiteColor], NSFontAttributeName:mediumSystemFontOfSize(17.0f), NSParagraphStyleAttributeName:style};
        NSAttributedString *string = [[NSAttributedString alloc] initWithString:_text attributes:attributes];
        
        UILabel *label = [[UILabel alloc] init];
        label.font = [UIFont systemFontOfSize:15.0f];
        label.numberOfLines = 0;
        label.textAlignment = NSTextAlignmentCenter;
        label.attributedText = string;
        _label = label;
        CGSize labelSize = [label sizeThatFits:CGSizeMake(_containerView.frame.size.width - 10.0 * 2.0, CGFLOAT_MAX)];
        label.frame = CGRectMake((_containerView.frame.size.width - labelSize.width) / 2.0f, _containerView.frame.size.height - labelSize.height - 18.0f, labelSize.width, labelSize.height);
        [_containerView addSubview:label];
    } else {
        _containerView.frame = CGRectMake(CGFloor(self.view.frame.size.width - containerSize.width) / 2, CGFloor(self.view.frame.size.height - containerSize.width) / 2, containerSize.width, containerSize.height);
        _effectView.frame = _containerView.bounds;
        _backgroundView.frame = _containerView.bounds;
        _spinner.frame = spinnerFrame;
        _shield.frame = CGRectMake((_containerView.frame.size.width - _shield.frame.size.width) / 2.0f, _isShield ? 23.0f : 30.0, _shield.frame.size.width, _shield.frame.size.height);
        [_label sizeToFit];
        _label.frame = CGRectMake((_containerView.frame.size.width - _label.frame.size.width) / 2.0f, _containerView.frame.size.height - _label.frame.size.height - 18.0f, _label.frame.size.width, _label.frame.size.height);
    }
}

- (void)dismissWithSuccess:(void (^)(void))completion increasedDelay:(bool)increasedDelay
{
    void (^dismissBlock)(void) = ^{
        [UIView animateWithDuration:0.3 delay:increasedDelay ? 2.1 : 0.55 options:0 animations:^{
            _containerView.alpha = 0.0f;
        } completion:^(__unused BOOL finished) {
            if (completion) {
                completion();
            }
        }];
    };
    
    _containerView.transform = CGAffineTransformMakeScale(0.6f, 0.6f);

    [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^{
        _containerView.transform = CGAffineTransformIdentity;
    } completion:nil];
    
    [UIView animateWithDuration:0.3f animations:^{
        _containerView.alpha = 1.0f;
    } completion:^(__unused BOOL finished) {
        dismissBlock();
    }];
    
    if (_isShield || _showCheck) {
        dispatchAfter(0.15, dispatch_get_main_queue(), ^{
            [_spinner setSucceed];
        });
    }
}

- (BOOL)canBecomeFirstResponder {
    return false;
}

@end

@interface ProxySpinnerViewInternal : UIView

@property (nonatomic, copy) void (^onDraw)(void);
@property (nonatomic, copy) void (^onSuccess)(void);

- (instancetype)initWithFrame:(CGRect)frame light:(bool)light;

- (void)setSucceed:(bool)fromRotation progress:(CGFloat)progress;

@end

@interface ProxySpinnerView ()
{
    ProxySpinnerViewInternal *_internalView;
    
    bool _progressing;
}
@end

@implementation ProxySpinnerView

- (instancetype)initWithFrame:(CGRect)frame light:(bool)light {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = false;
        self.userInteractionEnabled = false;
        
        _internalView = [[ProxySpinnerViewInternal alloc] initWithFrame:self.bounds light:light];
        _internalView.hidden = true;
        [self addSubview:_internalView];
    }
    return self;
}

- (void)setSucceed {
    _internalView.hidden = false;
    
    [_internalView setSucceed:false progress:0.0f];
}

@end

@interface ProxySpinnerViewInternal ()
{
    CADisplayLink *_displayLink;
    
    bool _light;
    
    bool _isProgressing;
    CGFloat _rotationValue;
    bool _isRotating;
    
    CGFloat _checkValue;
    bool _delay;
    bool _isSucceed;
    bool _isChecking;
    
    NSTimeInterval _previousTime;
}
@end

@implementation ProxySpinnerViewInternal

- (instancetype)initWithFrame:(CGRect)frame light:(bool)light {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _light = light;
        
        self.backgroundColor = [UIColor clearColor];
        self.opaque = false;
        self.userInteractionEnabled = false;
    }
    return self;
}

- (void)dealloc {
    _displayLink.paused = true;
    [_displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (CADisplayLink *)displayLink {
    if (_displayLink == nil) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkUpdate)];
        _displayLink.paused = true;
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return _displayLink;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGPoint centerPoint = CGPointMake(rect.size.width / 2.0f, rect.size.height / 2.0f);
    CGFloat lineWidth = 4.0f;
    CGFloat inset = 3.0f;
    if (rect.size.width < 44.0) {
        inset = 0.0f;
    }
    
    UIColor *foregroundColor = _light ? UIColorRGB(0x5a5a5a) : [UIColor whiteColor];
    CGContextSetFillColorWithColor(context, foregroundColor.CGColor);
    CGContextSetStrokeColorWithColor(context, foregroundColor.CGColor);
    
    if (_isProgressing)
    {
        CGMutablePathRef path = CGPathCreateMutable();
        CGFloat offset = -_rotationValue * 2.0f * M_PI;
        CGPathAddArc(path, NULL, centerPoint.x, centerPoint.y, (rect.size.width - inset * 2.0f - lineWidth) / 2.0f, offset, offset + (3.0f * M_PI_2) * (1.0f - _checkValue), false);
        CGPathRef strokedArc = CGPathCreateCopyByStrokingPath(path, NULL, lineWidth, kCGLineCapRound, kCGLineJoinMiter, 10);
        CGContextAddPath(context, strokedArc);
        CGPathRelease(strokedArc);
        CGPathRelease(path);
        
        CGContextFillPath(context);
    }
    
    if (_checkValue > FLT_EPSILON)
    {
        CGContextSetLineWidth(context, 4.0f);
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineJoin(context, kCGLineJoinRound);
        CGContextSetMiterLimit(context, 10);
        
        CGFloat firstSegment = MIN(1.0f, _checkValue * 3.0f);
        CGPoint s = CGPointMake(inset + 5.0f, centerPoint.y + 1.0f);
        CGPoint p1 = CGPointMake(10.0f, 10.0f);
        CGPoint p2 = CGPointMake(23.0f, -23.0f);
        if (rect.size.width < 44.0) {
            p1 = CGPointMake(9.0f, 9.0f);
            p2 = CGPointMake(23.0f, -23.0f);
        }
        
        if (firstSegment < 1.0f)
        {
            CGContextMoveToPoint(context, s.x + p1.x * firstSegment, s.y + p1.y * firstSegment);
            CGContextAddLineToPoint(context, s.x, s.y);
        }
        else
        {
            CGFloat secondSegment = (_checkValue - 0.33f) * 1.5f;
            if (rect.size.width < 44.0) {
                secondSegment = (_checkValue - 0.33f) * 1.35f;
            }
            CGContextMoveToPoint(context, s.x + p1.x + p2.x * secondSegment, s.y + p1.y + p2.y * secondSegment);
            CGContextAddLineToPoint(context, s.x + p1.x, s.y + p1.y);
            CGContextAddLineToPoint(context, s.x, s.y);
        }
        
        CGContextStrokePath(context);
    }
}

- (void)displayLinkUpdate
{
    NSTimeInterval previousTime = _previousTime;
    NSTimeInterval currentTime = CACurrentMediaTime();
    _previousTime = currentTime;
    
    NSTimeInterval delta = previousTime > DBL_EPSILON ? currentTime - previousTime : 0.0;
    if (delta < DBL_EPSILON)
        return;
    
    if (_isRotating)
    {
        _rotationValue += delta * 1.35f;
    }
    
    if (_isSucceed && _isRotating && !_delay && _rotationValue >= 0.5f)
    {
        _rotationValue = 0.5f;
        _isRotating = false;
        _isChecking = true;
    }
    
    if (_isChecking)
        _checkValue += delta * M_PI * 1.6f;
    
    if (_rotationValue > 1.0f)
    {
        _rotationValue = 0.0f;
        _delay = false;
    }
    
    if (_checkValue > 1.0f)
    {
        _checkValue = 1.0f;
        [self displayLink].paused = true;
        
        if (self.onSuccess != nil)
        {
            void (^onSuccess)(void) = [self.onSuccess copy];
            self.onSuccess = nil;
            onSuccess();
        }
    }
    
    [self setNeedsDisplay];
    
    if (self.onDraw != nil)
    {
        void (^onDraw)(void) = [self.onDraw copy];
        self.onDraw = nil;
        onDraw();
    }
}

- (void)setProgress {
    _isRotating = true;
    _isProgressing = true;
    
    [self displayLink].paused = false;
}

- (void)setSucceed:(bool)fromRotation progress:(CGFloat)progress {
    if (_isSucceed)
        return;
    
    if (fromRotation) {
        _isRotating = true;
        _isProgressing = true;
        _rotationValue = progress;
    }
    
    _isSucceed = true;
    
    if (!_isRotating)
        _isChecking = true;
    else if (_rotationValue > 0.5f)
        _delay = true;
    
    [self displayLink].paused = false;
}

- (bool)isSucceed
{
    return _isSucceed;
}

@end


