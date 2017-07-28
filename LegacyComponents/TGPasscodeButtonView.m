#import "TGPasscodeButtonView.h"

#import "LegacyComponentsInternal.h"
#import "TGFont.h"
#import "POPAnimation.h"
#import "POPBasicAnimation.h"
#import "TGImageUtils.h"

@interface TGPasscodeButtonView ()
{
    id<TGPasscodeBackground> _background;
    CGFloat _highlightAmount;
    
    UIFont *_titleFont;
    NSString *_title;
    UIFont *_subtitleFont;
    NSString *_subtitle;
    
    CGPoint _absoluteOffset;
    bool _highligted;
}

@end

@implementation TGPasscodeButtonView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.opaque = false;
        self.backgroundColor = nil;
        self.modernHighlight = false;
        
        CGFloat titleFontSize = 0.0f;
        CGFloat subtitleFontSize = 0.0f;
        
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        if (screenSize.width > screenSize.height)
        {
            CGFloat tmp = screenSize.width;
            screenSize.width = screenSize.height;
            screenSize.height = tmp;
        }
        
        if ((int)screenSize.height == 1024 || (int)screenSize.height == 1366)
        {
            titleFontSize = 38.0f;
            subtitleFontSize = 10.0f;
        }
        else
        {
            titleFontSize = 36.0f;
            subtitleFontSize = 9.0f;
        }
        
        _titleFont = TGUltralightSystemFontOfSize(titleFontSize);
        _subtitleFont = TGMediumSystemFontOfSize(subtitleFontSize);
    }
    return self;
}

- (void)setTitle:(NSString *)title subtitle:(NSString *)subtitle
{
    _title = title;
    _subtitle = subtitle;
    [self setNeedsDisplay];
}

- (void)setBackground:(id<TGPasscodeBackground>)background
{
    _background = background;
    [self setNeedsDisplay];
}

- (void)setFrame:(CGRect)frame
{
    bool needsDisplay = !CGSizeEqualToSize(frame.size, self.frame.size);
    [super setFrame:frame];
    if (needsDisplay)
        [self setNeedsDisplay];
}

- (void)setAbsoluteOffset:(CGPoint)absoluteOffset
{
    if (!CGPointEqualToPoint(_absoluteOffset, absoluteOffset))
    {
        _absoluteOffset = absoluteOffset;
        [self setNeedsDisplay];
    }
}

- (void)_setHighligtedAnimated:(bool)highlighted animated:(bool)animated
{
    if (_highligted != highlighted)
    {
        _highligted = highlighted;
        
        [self pop_removeAllAnimations];
        
        if (animated && !highlighted)
        {
            POPBasicAnimation *animation = [POPBasicAnimation animation];
            animation.property = [POPMutableAnimatableProperty propertyWithName:@"highlightAmount" initializer:^(POPMutableAnimatableProperty *prop)
            {
                prop.readBlock = ^(TGPasscodeButtonView *view, CGFloat *values)
                {
                    if (view != nil)
                        values[0] = view->_highlightAmount;
                };
                
                prop.writeBlock = ^(TGPasscodeButtonView *view, CGFloat const *values)
                {
                    if (view != nil)
                    {
                        view->_highlightAmount = values[0];
                        [view setNeedsDisplay];
                    }
                };
            }];
            animation.duration = 0.5;
            animation.fromValue = @(_highlightAmount);
            animation.toValue = @((CGFloat)0.0f);
            [self pop_addAnimation:animation forKey:@"highlightAmount"];
        }
        else
        {
            _highlightAmount = highlighted ? 1.0f : 0.0f;
            [self setNeedsDisplay];
        }
    }
}

- (void)drawRect:(CGRect)__unused rect
{
    static CGFloat topOffset = 0.0f;
    static CGFloat subtitleOffset = 0.0f;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        if (screenSize.width > screenSize.height)
        {
            CGFloat tmp = screenSize.width;
            screenSize.width = screenSize.height;
            screenSize.height = tmp;
        }
        
        if ((int)screenSize.height == 1024 || (int)screenSize.height == 1366)
        {
            topOffset = 1.0f;
            subtitleOffset = 2.0f;
        }
    });

    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGSize size = self.bounds.size;
    
    [[_background backgroundImage] drawInRect:CGRectMake(-_absoluteOffset.x, -_absoluteOffset.y, [_background size].width, [_background size].height) blendMode:kCGBlendModeCopy alpha:1.0f];
    
    CGContextBeginPath(context);
    CGContextAddEllipseInRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    CGContextClip(context);

    [[_background foregroundImage] drawInRect:CGRectMake(-_absoluteOffset.x, -_absoluteOffset.y, [_background size].width, [_background size].height) blendMode:kCGBlendModeNormal alpha:1.0f];
    
    if (_highlightAmount < FLT_EPSILON)
    {
        CGContextSetBlendMode(context, kCGBlendModeCopy);
        CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(1.5f, 1.5f, size.width - 3.0f, size.height - 3.0f));
    }
    else if (_highlightAmount < 1.0f - FLT_EPSILON)
    {
        CGContextSetBlendMode(context, kCGBlendModeDestinationIn);
        CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:0.0f alpha:_highlightAmount].CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(1.5f, 1.5f, size.width - 3.0f, size.height - 3.0f));
    }
    
    CGSize titleSize = [_title sizeWithFont:_titleFont];
    titleSize.width = CGCeil(titleSize.width);
    titleSize.height = CGCeil(titleSize.height);
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    [_title drawAtPoint:CGPointMake(CGFloor((size.width - titleSize.width) / 2.0f), 8.0f + TGRetinaPixel + ([_title isEqualToString:@"0"] ? (7.0f - TGRetinaPixel) : 0.0f) + topOffset) withFont:_titleFont];
    
    if (iosMajorVersion() >= 7)
    {
        NSDictionary *subtitleAttributes = @{NSFontAttributeName: _subtitleFont, NSForegroundColorAttributeName: [UIColor whiteColor], NSKernAttributeName: @(2.0f)};
        CGSize subtitleSize = [_subtitle sizeWithAttributes:subtitleAttributes];
        [_subtitle drawAtPoint:CGPointMake(CGFloor((size.width - subtitleSize.width) / 2.0f) + 1.0f, 48.0f - TGRetinaPixel + topOffset + subtitleOffset) withAttributes:subtitleAttributes];
    }
    else
    {
        CGSize subtitleSize = [_subtitle sizeWithFont:_subtitleFont];
        subtitleSize.width = CGCeil(subtitleSize.width);
        subtitleSize.height = CGCeil(subtitleSize.height);
        [_subtitle drawAtPoint:CGPointMake(CGFloor((size.width - subtitleSize.width) / 2.0f) + 1.0f, 48.0f - TGRetinaPixel + topOffset + subtitleOffset) withFont:_subtitleFont];
    }
}


@end
