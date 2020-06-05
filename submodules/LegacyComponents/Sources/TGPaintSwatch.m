#import "TGPaintSwatch.h"

@implementation TGPaintSwatch

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return true;
    
    if (!object || ![object isKindOfClass:[self class]])
        return false;
    
    TGPaintSwatch *swatch = (TGPaintSwatch *)object;
    return [swatch.color isEqual:self.color] && fabs(swatch.colorLocation - self.colorLocation) < FLT_EPSILON && fabs(swatch.brushWeight - self.brushWeight) < FLT_EPSILON;
}

+ (instancetype)swatchWithColor:(UIColor *)color colorLocation:(CGFloat)colorLocation brushWeight:(CGFloat)brushWeight
{
    TGPaintSwatch *swatch = [[TGPaintSwatch alloc] init];
    swatch->_color = color;
    swatch->_colorLocation = colorLocation;
    swatch->_brushWeight = brushWeight;
    
    return swatch;
}

@end
