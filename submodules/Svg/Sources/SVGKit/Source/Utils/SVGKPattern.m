#import "SVGKPattern.h"

@implementation SVGKPattern

@synthesize color;

+ (SVGKPattern *)patternWithColor:(UIColor *)color
{
    SVGKPattern* p = [[SVGKPattern alloc] init];
    p.color = color;
    return p;
}

+ (SVGKPattern*)patternWithImage:(UIImage*)image
{
    UIColor* patternImage = [UIColor colorWithPatternImage:image];
    return [self patternWithColor:patternImage];
}

- (CGColorRef)CGColor
{
    return [self.color CGColor];
}

@end
