#import "TGVideoMessageRingView.h"

#import "TGColor.h"

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
