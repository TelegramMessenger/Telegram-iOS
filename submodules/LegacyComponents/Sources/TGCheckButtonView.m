#import "TGCheckButtonView.h"

#import "TGFont.h"
#import "TGImageUtils.h"

#import "LegacyComponentsGlobals.h"

@interface TGCheckButtonView ()
{
    UIView *_wrapperView;
    
    CALayer *_checkBackground;
    
    TGCheckButtonStyle _style;
    CGSize _size;
    UIImage *_fillImage;
    
    UIView *_checkView;
    UIImageView *_checkFillView;
    UIView *_checkShortFragment;
    UIView *_checkLongFragment;
    
    UILabel *_numberLabel;
    NSInteger _number;
    
    UIColor *_checkColor;
    
    CGAffineTransform TGCheckButtonDefaultTransform;
}
@end

@implementation TGCheckButtonView

+ (void)resetCache {
}

- (instancetype)initWithStyle:(TGCheckButtonStyle)style {
    TGCheckButtonPallete *pallete = nil;
    if ([[LegacyComponentsGlobals provider] respondsToSelector:@selector(checkButtonPallete)])
        pallete = [[LegacyComponentsGlobals provider] checkButtonPallete];
    return [self initWithStyle:style pallete:pallete];
}

- (instancetype)initWithStyle:(TGCheckButtonStyle)style pallete:(TGCheckButtonPallete *)pallete
{
    CGSize size = CGSizeMake(32.0f, 32.0f);
    if (style == TGCheckButtonStyleGallery)
        size = CGSizeMake(39.0f, 39.0f);
    
    self = [super initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    if (self != nil)
    {
        CGFloat screenScale = 2.0f;
        
        TGCheckButtonDefaultTransform = CGAffineTransformMakeRotation(-M_PI_4);
        NSMutableDictionary *backgroundImages = [[NSMutableDictionary alloc] init];
        NSMutableDictionary *fillImages = [[NSMutableDictionary alloc] init];
        screenScale = [UIScreen mainScreen].scale;
        
        int32_t hex = 0x29c519;
        UIColor *greenColor = [[UIColor alloc] initWithRed:(((hex >> 16) & 0xff) / 255.0f) green:(((hex >> 8) & 0xff) / 255.0f) blue:(((hex) & 0xff) / 255.0f) alpha:1.0f];
        
        hex = 0x007aff;
        UIColor *blueColor = [[UIColor alloc] initWithRed:(((hex >> 16) & 0xff) / 255.0f) green:(((hex >> 8) & 0xff) / 255.0f) blue:(((hex) & 0xff) / 255.0f) alpha:1.0f];
        
        hex = 0xcacacf;
        UIColor *borderColor = [[UIColor alloc] initWithRed:(((hex >> 16) & 0xff) / 255.0f) green:(((hex >> 8) & 0xff) / 255.0f) blue:(((hex) & 0xff) / 255.0f) alpha:1.0f];
        
        UIColor *checkColor = [UIColor whiteColor];
        
        UIColor *backgroundColor = [UIColor whiteColor];
        UIColor *chatBorderColor = [UIColor whiteColor];
        
        if (pallete != nil)
        {
            greenColor = pallete.defaultBackgroundColor;
            blueColor = pallete.accentBackgroundColor;
            borderColor = pallete.defaultBorderColor;
            chatBorderColor = pallete.chatBorderColor;
            checkColor = pallete.checkColor;
            backgroundColor = pallete.barBackgroundColor;
        }
        
        _checkColor = checkColor;
        
        CGFloat insideInset = 0.0f;
        switch (style)
        {
            case TGCheckButtonStyleBar:
            {
                insideInset = 2.0f;
            }
                break;
                
            case TGCheckButtonStyleGallery:
            {
                insideInset = 3.5f;
            }
                break;
                
            case TGCheckButtonStyleShare:
            case TGCheckButtonStyleChat:
            case TGCheckButtonStyleMedia:
            {
                insideInset = 4.0f;
            }
                break;
                
            case TGCheckButtonStyleCompact:
            {
                insideInset = 6.0f;
            }
                break;
                
            default:
            {
                insideInset = 5.0f;
            }
                break;
        }
    
        UIImage *backgroundImage = backgroundImages[@(style)];
        if (backgroundImage == nil)
        {
            switch (style)
            {
                case TGCheckButtonStyleGallery:
                {
                    CGRect rect = CGRectMake(0, 0, size.width, size.height);
                    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
                    CGContextRef context = UIGraphicsGetCurrentContext();
                    CGContextSetShadowWithColor(context, CGSizeZero, 2.5f, [UIColor colorWithWhite:0.0f alpha:0.22f].CGColor);
                    
                    CGFloat lineWidth = 1.5f;
                    if (screenScale == 3.0f)
                        lineWidth = 5.0f / 3.0f;
                    CGContextSetLineWidth(context, lineWidth);
                    
                    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
                    CGContextStrokeEllipseInRect(context, CGRectInset(rect, insideInset + 0.5f, insideInset + 0.5f));
                    
                    backgroundImage = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                }
                    break;
                    
                case TGCheckButtonStyleMedia:
                case TGCheckButtonStyleChat:
                {
                    CGRect rect = CGRectMake(0, 0, size.width, size.height);
                    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
                    CGContextRef context = UIGraphicsGetCurrentContext();
                    
                    if (style == TGCheckButtonStyleMedia || [chatBorderColor isEqual:[UIColor whiteColor]])
                        CGContextSetShadowWithColor(context, CGSizeZero, 2.5f, [UIColor colorWithWhite:0.0f alpha:0.22f].CGColor);
                    CGContextSetLineWidth(context, 1.5f);
                    CGContextSetStrokeColorWithColor(context, (style == TGCheckButtonStyleChat ? chatBorderColor : [UIColor whiteColor]).CGColor);
                    CGContextStrokeEllipseInRect(context, CGRectInset(rect, insideInset + 0.5f, insideInset + 0.5f));
                    
                    backgroundImage = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                }
                    break;
                    
                case TGCheckButtonStyleBar:
                {
                    CGRect rect = CGRectMake(0, 0, size.width, size.height);
                    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
                    CGContextRef context = UIGraphicsGetCurrentContext();
                    CGContextSetLineWidth(context, 1.0f);
                    
                    CGContextSetStrokeColorWithColor(context, borderColor.CGColor);
                    CGContextStrokeEllipseInRect(context, CGRectInset(rect, insideInset + 0.5f, insideInset + 0.5f));
                    
                    backgroundImage = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                }
                    break;

                case TGCheckButtonStyleShare:
                {
                    CGRect rect = CGRectMake(0, 0, size.width, size.height);
                    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
                    backgroundImage = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                }
                    break;
                    
                default:
                {
                    CGFloat lineWidth = 1.0f;
                    if (style == TGCheckButtonStyleCompact) {
                        lineWidth = 1.5f;
                    }
                    
                    CGRect rect = CGRectMake(0, 0, size.width, size.height);
                    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
                    CGContextRef context = UIGraphicsGetCurrentContext();
                    CGContextSetLineWidth(context, lineWidth);
                    
                    CGContextSetStrokeColorWithColor(context, borderColor.CGColor);
                    CGContextStrokeEllipseInRect(context, CGRectInset(rect, insideInset + lineWidth / 2.0, insideInset + lineWidth / 2.0));
                    
                    backgroundImage = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                }
                    break;
            }
            
            backgroundImages[@(style)] = backgroundImage;
        }
        
        UIImage *fillImage = fillImages[@(style)];
        if (fillImage == nil)
        {
            switch (style)
            {
                case TGCheckButtonStyleShare:
                case TGCheckButtonStyleChat:
                {
                    CGRect rect = CGRectMake(0, 0, size.width, size.height);
                    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
                    CGContextRef context = UIGraphicsGetCurrentContext();
                    
                    CGContextSetFillColorWithColor(context, blueColor.CGColor);
                    CGFloat inset = (style == TGCheckButtonStyleChat && ![chatBorderColor isEqual:[UIColor whiteColor]]) ? 0.0f : 1.2f;
                    CGContextFillEllipseInRect(context, CGRectInset(rect, insideInset + inset, insideInset + inset));
                    CGContextSetLineWidth(context, 2.0f);
                    if (style == TGCheckButtonStyleShare)
                    {
                        CGContextSetStrokeColorWithColor(context, backgroundColor.CGColor);
                        CGContextStrokeEllipseInRect(context, CGRectInset(rect, insideInset + 1.0f, insideInset + 1.0f));
                    }
                    
                    fillImage = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                }
                    break;
                    
                default:
                {
                    CGRect rect = CGRectMake(0, 0, size.width, size.height);
                    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
                    CGContextRef context = UIGraphicsGetCurrentContext();
                                        
                    UIColor *color = style == TGCheckButtonStyleDefaultBlue ? blueColor : greenColor;
                    CGContextSetFillColorWithColor(context, color.CGColor);
                    CGFloat inset = (style == TGCheckButtonStyleDefault || style == TGCheckButtonStyleDefaultBlue || style == TGCheckButtonStyleCompact) ? 0.0f : 1.2f;
                    CGContextFillEllipseInRect(context, CGRectInset(rect, insideInset + inset, insideInset + inset));
                    
                    fillImage = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                }
                    break;
            }
            
            fillImages[@(style)] = fillImage;
        }
        
        _style = style;
        _size = size;
        _fillImage = fillImage;
        
        _wrapperView = [[UIView alloc] initWithFrame:self.bounds];
        _wrapperView.userInteractionEnabled = false;
        [self addSubview:_wrapperView];
        
        _checkBackground = [[CALayer alloc] init];
        _checkBackground.contents = (__bridge id)(backgroundImage.CGImage);
        _checkBackground.frame = CGRectMake(0.0f, 0.0f, size.width, size.height);
        
        [_wrapperView.layer addSublayer:_checkBackground];
    }
    return self;
}

- (void)_createCheckButtonDetailsIfNeeded
{
    if (_checkFillView != nil)
        return;

    _checkFillView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, _size.width, _size.height)];
    _checkFillView.alpha = 0.0f;
    _checkFillView.image = _fillImage;
    _checkFillView.transform = CGAffineTransformMakeScale(0.01f, 0.01f);
    [_wrapperView addSubview:_checkFillView];
    
    _checkView = [[UIView alloc] initWithFrame:CGRectInset(self.bounds, 4, 4)];
    _checkView.alpha = 0.0f;
    _checkView.userInteractionEnabled = false;
    _checkView.transform = TGCheckButtonDefaultTransform;
    [_wrapperView addSubview:_checkView];
    
    CGRect shortFragmentFrame = CGRectMake(6.5f, 8.5f, 1.5f, 6.0f);
    CGRect longFragmentFrame = CGRectMake(7.5f, 13.0f, 11.0f, 1.5f);
    
    if (_style == TGCheckButtonStyleGallery)
    {
        shortFragmentFrame = CGRectMake(9.0f, 10.5f, 2.0f, 8.0f);
        longFragmentFrame = CGRectMake(9.5f, 16.5f, 14.5f, 2.0f);
    }
    
    _checkShortFragment = [[UIView alloc] init];
    _checkShortFragment.backgroundColor = _checkColor;
    _checkShortFragment.layer.anchorPoint = CGPointMake(0.5f, 0);
    _checkShortFragment.frame = shortFragmentFrame;
    _checkShortFragment.transform = CGAffineTransformMakeScale(1.0f, 0.0f);
    [_checkView addSubview:_checkShortFragment];
    
    _checkLongFragment = [[UIView alloc] init];
    _checkLongFragment.backgroundColor = _checkColor;
    _checkLongFragment.layer.anchorPoint = CGPointMake(0, 0.5f);
    _checkLongFragment.frame = longFragmentFrame;
    _checkLongFragment.transform = CGAffineTransformMakeScale(0.0f, 1.0f);
    [_checkView addSubview:_checkLongFragment];
    
    if (_numberLabel != nil)
    {
        if (_numberLabel.superview == nil)
            [_checkFillView addSubview:_numberLabel];
        else
            [_numberLabel.superview bringSubviewToFront:_numberLabel];
    }
}

- (void)setSelected:(bool)selected animated:(bool)animated
{
    [self setSelected:selected animated:animated bump:false];
}

- (void)setSelected:(bool)selected animated:(bool)animated bump:(bool)bump
{
    [self setSelected:selected animated:animated bump:bump completion:nil];
}

- (void)setSelected:(bool)selected animated:(bool)animated bump:(bool)bump completion:(void (^)())completion
{
    if (selected)
        [self _createCheckButtonDetailsIfNeeded];
    
    if (animated && bump)
        [self setWrapperScale:selected ? 0.77f : 0.87f animated:false];
    
    static dispatch_once_t onceToken;
    static bool inhibitAnimation = false;
    dispatch_once(&onceToken, ^
    {
        inhibitAnimation = ([[[UIDevice currentDevice] systemVersion] compare:@"7" options:NSNumericSearch] == NSOrderedAscending);
    });

    if (inhibitAnimation)
        animated = false;
    
    if (animated)
    {
        if (self.selected == selected) {
            if (completion) {
                completion();
            }
            return;
        }
        
        if (bump)
        {
            if (selected)
                _checkFillView.transform = CGAffineTransformIdentity;
        }
        else
        {
            if (selected)
                _checkFillView.transform = CGAffineTransformMakeScale(0.01f, 0.01f);
            else
                _checkFillView.transform = CGAffineTransformIdentity;
        }
        
        [UIView animateWithDuration:0.19f animations:^
        {
            _checkFillView.alpha = selected ? 1.0f : 0.0f;
            if (!bump || !selected)
                _checkFillView.transform = selected ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.01f, 0.01f);
        }];
        
        if (selected)
        {
            CGFloat duration = 0.4f;
            CGFloat damping = 0.35f;
            CGFloat initialVelocity = 0.8f;
            if (bump)
            {
                duration = 0.5f;
                damping = 0.4f;
                initialVelocity = 0.6f;
            }
            
            [UIView animateWithDuration:duration delay:0.0f usingSpringWithDamping:damping initialSpringVelocity:initialVelocity options:UIViewAnimationOptionBeginFromCurrentState animations:^
             {
                 _wrapperView.transform = CGAffineTransformIdentity;
             } completion:^(__unused BOOL finished) {
                 if (completion) {
                     completion();
                 }
             }];
            
            if (_number == 0)
            {
                _checkView.alpha = 1.0f;
                _checkShortFragment.transform = CGAffineTransformMakeScale(1.0f, 0.0f);
                _checkLongFragment.transform = CGAffineTransformMakeScale(0.0f, 1.0f);
                
                [UIView animateKeyframesWithDuration:0.21f delay:0.0f options:kNilOptions animations:^
                {
                    [UIView addKeyframeWithRelativeStartTime:0.0f relativeDuration:0.333f animations:^
                    {
                        _checkShortFragment.transform = CGAffineTransformIdentity;
                    }];
                    
                    [UIView addKeyframeWithRelativeStartTime:0.333f relativeDuration:0.666f animations:^
                    {
                        _checkLongFragment.transform = CGAffineTransformIdentity;
                    }];
                } completion:^(__unused BOOL finished) {
                }];
            }
        }
        else
        {
            CGFloat duration = 0.17f;
            if (bump)
                duration = 0.15f;
            
            [UIView animateWithDuration:duration animations:^
            {
                if (_number > 0)
                {
                    
                }
                else
                {
                    _checkView.transform = CGAffineTransformScale(_checkView.transform, 0.01f, 0.01f);
                    _checkView.alpha = 0.0f;
                }
                
                if (bump)
                    _wrapperView.transform = CGAffineTransformIdentity;
            } completion:^(__unused BOOL finished)
            {
                _checkView.transform = TGCheckButtonDefaultTransform;
                if (completion) {
                    completion();
                }
            }];
        }
    }
    else
    {
        _checkFillView.alpha = selected ? 1.0f : 0.0f;
        _checkFillView.transform = selected ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.1f, 0.1f);

        if (_number > 0)
        {
            _checkView.alpha = 0.0f;
        }
        else
        {
            _checkView.alpha = selected ? 1.0f : 0.0f;
            _checkView.transform = TGCheckButtonDefaultTransform;
            _checkShortFragment.transform = CGAffineTransformIdentity;
            _checkLongFragment.transform = CGAffineTransformIdentity;
        }
        
        if (completion) {
            completion();
        }
    }
    
    super.selected = selected;
}

- (void)setNumber:(NSUInteger)number
{
    if (number == NSNotFound)
        number = 0;
    
    _number = number;
    if (_numberLabel == nil && number != 0)
    {
        _numberLabel = [[UILabel alloc] init];
        _numberLabel.backgroundColor = [UIColor clearColor];
        _numberLabel.frame = CGRectMake(0.0f, -TGScreenPixel, _wrapperView.bounds.size.width, _wrapperView.bounds.size.height);
        _numberLabel.textColor = _checkColor;
        _numberLabel.textAlignment = NSTextAlignmentCenter;
        _numberLabel.userInteractionEnabled = false;
        _numberLabel.font = [TGFont roundedFontOfSize:_style == TGCheckButtonStyleGallery ? 18.0f : 16.0f];
        [_checkFillView addSubview:_numberLabel];
    }
    
    if (number > 0)
    {
        _checkView.alpha = 0.0f;
        _numberLabel.alpha = 1.0f;
        _numberLabel.text = [NSString stringWithFormat:@"%ld", number];
        if (_style != TGCheckButtonStyleGallery)
            _numberLabel.font = [TGFont roundedFontOfSize:_number < 10 ? 16.0f : 15.0f];
    }
    else
    {
        [UIView animateWithDuration:0.2 animations:^
        {
            _numberLabel.alpha = 0.0f;
        }];
    }
}

#pragma mark -

- (void)setWrapperScale:(CGFloat)scale animated:(bool)animated
{
    void (^change)(void) = ^
    {
        _wrapperView.transform = CGAffineTransformMakeScale(scale, scale);
    };
    
    if (animated)
        [UIView animateWithDuration:0.12 delay:0 options:UIViewAnimationOptionAllowAnimatedContent animations:change completion:nil];
    else
        change();
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    [self setWrapperScale:0.85f animated:true];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    [self setWrapperScale:1.0f animated:true];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    [self setWrapperScale:1.0f animated:true];
}

@end


@implementation TGCheckButtonPallete

+ (instancetype)palleteWithDefaultBackgroundColor:(UIColor *)defaultBackgroundColor accentBackgroundColor:(UIColor *)accentBackgroundColor defaultBorderColor:(UIColor *)defaultBorderColor mediaBorderColor:(UIColor *)mediaBorderColor chatBorderColor:(UIColor *)chatBorderColor checkColor:(UIColor *)checkColor blueColor:(UIColor *)blueColor barBackgroundColor:(UIColor *)barBackgroundColor
{
    TGCheckButtonPallete *pallete = [[TGCheckButtonPallete alloc] init];
    pallete->_defaultBackgroundColor = defaultBackgroundColor;
    pallete->_accentBackgroundColor = accentBackgroundColor;
    pallete->_defaultBorderColor = defaultBorderColor;
    pallete->_mediaBorderColor = mediaBorderColor;
    pallete->_chatBorderColor = chatBorderColor;
    pallete->_checkColor = checkColor;
    pallete->_blueColor = blueColor;
    pallete->_barBackgroundColor = barBackgroundColor;
    return pallete;
}

@end
