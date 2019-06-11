#import "TGLocationLiveElapsedView.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"
#import "TGFont.h"

@interface TGLocationLiveElapsedView ()
{
    UIColor *_color;
    CGFloat _progress;
    NSString *_string;
}
@end

@implementation TGLocationLiveElapsedView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _color = TGAccentColor();
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)setColor:(UIColor *)color
{
    _color = color;
    [self setNeedsDisplay];
}

- (void)setRemaining:(int32_t)remaining period:(int32_t)period;
{
    NSString *string = nil;
    int32_t minutes = ceil(remaining / 60.0f);
    if (minutes >= 60)
    {
        int32_t hours = ceil(remaining / 3600.0f);
        string = [[NSString alloc] initWithFormat:TGLocalized(@"Map.LiveLocationShortHour"), [[NSString alloc] initWithFormat:@"%d", hours]];
    }
    else
    {
        string = [[NSString alloc] initWithFormat:@"%d", minutes];
    }
    _progress = remaining / (CGFloat)period;
    if (_progress > 1.0f - FLT_EPSILON)
        _progress = 0.999f;
    _string = string;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGRect allRect = self.bounds;
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, _color.CGColor);
    CGContextSetStrokeColorWithColor(context, _color.CGColor);
    CGContextSetLineWidth(context, 1.5f);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinMiter);
    CGContextSetMiterLimit(context, 10);
    
    CGPoint center = CGPointMake(allRect.size.width / 2, allRect.size.height / 2);
    CGFloat radius = 13.0f;
    
    CGContextSetAlpha(context, 0.2f);
    CGContextStrokeEllipseInRect(context, CGRectMake(center.x - radius, center.y - radius, radius * 2, radius * 2));
    CGContextSetAlpha(context, 1.0f);
                                 
    CGFloat startAngle = -M_PI_2;
    CGFloat endAngle = -M_PI_2 + 2 * M_PI * (1.0f - _progress);
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddArc(path, NULL, center.x, center.y, radius, startAngle, endAngle, true);
    CGContextAddPath(context, path);
    CGPathRelease(path);
    CGContextStrokePath(context);
    
    UIFont *font = [TGFont roundedFontOfSize:14.0f];
    if (font == nil) {
        font = [UIFont systemFontOfSize:14.0];
    }
    NSDictionary *attributes = @{ NSFontAttributeName: font, NSForegroundColorAttributeName: _color };
    CGSize size = iosMajorVersion() >= 7 ? [_string sizeWithAttributes:attributes] : [_string sizeWithFont:attributes[NSFontAttributeName]];
    if (iosMajorVersion() >= 7)
    {
        [_string drawAtPoint:CGPointMake((allRect.size.width - size.width) / 2.0f, floor((allRect.size.height - size.height) / 2.0f)) withAttributes:attributes];
    }
    else
    {
        CGContextSetFillColorWithColor(context, _color.CGColor);
        [_string drawAtPoint:CGPointMake((allRect.size.width - size.width) / 2.0f, floor((allRect.size.height - size.height) / 2.0f)) forWidth:FLT_MAX withFont:font lineBreakMode:NSLineBreakByWordWrapping];
    }
}

@end

