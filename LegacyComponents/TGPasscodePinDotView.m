#import "TGPasscodePinDotView.h"

@interface TGPasscodePinDotView ()
{
    id<TGPasscodeBackground> _background;
    CGPoint _absoluteOffset;
    bool _filled;
    CGFloat _fillAmount;
}

@end

@implementation TGPasscodePinDotView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.opaque = false;
        self.backgroundColor = nil;
    }
    return self;
}

- (bool)filled
{
    return _filled;
}

- (void)setFilled:(bool)filled
{
    [self setFilled:filled animated:false];
}

- (void)setFilled:(bool)filled animated:(bool)__unused animated
{
    if (_filled != filled)
    {
        _filled = filled;
        _fillAmount = _filled ? 1.0f : 0.0f;
        [self setNeedsDisplay];
    }
}

- (void)setBackground:(id<TGPasscodeBackground>)background
{
    _background = background;
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

- (void)drawRect:(CGRect)__unused rect
{
    CGSize size = self.bounds.size;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    [[_background backgroundImage] drawInRect:CGRectMake(-_absoluteOffset.x, -_absoluteOffset.y, [_background size].width, [_background size].height) blendMode:kCGBlendModeCopy alpha:1.0f];
    
    CGContextBeginPath(context);
    CGContextAddEllipseInRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    CGContextClip(context);
    
    [[_background foregroundImage] drawInRect:CGRectMake(-_absoluteOffset.x, -_absoluteOffset.y, [_background size].width, [_background size].height) blendMode:kCGBlendModeNormal alpha:1.0f];
    
    if (_fillAmount < FLT_EPSILON)
    {
        CGContextSetBlendMode(context, kCGBlendModeCopy);
        CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(1.0f, 1.0f, size.width - 2.0f, size.height - 2.0f));
    }
    else if (_fillAmount < 1.0f - FLT_EPSILON)
    {
        CGContextSetBlendMode(context, kCGBlendModeDestinationIn);
        CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:0.0f alpha:_fillAmount].CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(1.0f, 1.0f, size.width - 2.0f, size.height - 2.0f));
    }
}

@end
