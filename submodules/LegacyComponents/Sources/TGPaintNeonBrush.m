#import "TGPaintNeonBrush.h"

#import "LegacyComponentsInternal.h"

const CGFloat TGPaintNeonBrushSolidFraction = 0.41f;
const CGFloat TGPaintNeonBrushBorderFraction = 0.036f;

@implementation TGPaintNeonBrush

- (CGFloat)spacing
{
    return 0.07f;
}

- (CGFloat)alpha
{
    return 0.7f;
}

- (CGFloat)angle
{
    return 0.0f;
}

- (CGFloat)scale
{
    return 1.45f;
}

- (bool)lightSaber
{
    return true;
}

- (CGImageRef)generateNeonStampForSize:(CGSize)size
{
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, (NSInteger)size.width, (NSInteger)size.height, 8, (NSInteger)size.width * 4, colorspace, kCGImageAlphaPremultipliedLast);
    
    CGPoint center = CGPointMake(size.width / 2, size.height / 2);
    
    NSArray *redColors = @
    [
        (__bridge id)UIColorRGB(0x440000).CGColor,
        (__bridge id)UIColorRGB(0x440000).CGColor,
        (__bridge id)[UIColor blackColor].CGColor
    ];
    const CGFloat redLocations[] = { 0.0f, 0.54f, 1.0f };
    CGGradientRef gradientRef = CGGradientCreateWithColors(colorspace, (__bridge CFArrayRef)redColors, redLocations);
    CGFloat redMaxRadius = size.width / 2;
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation;
    
    CGContextDrawRadialGradient(ctx, gradientRef, center, 0, center, redMaxRadius, options);
    CGGradientRelease(gradientRef);
    
    CGContextSetBlendMode(ctx, kCGBlendModeScreen);
    
    CGFloat border = floor(size.width / 2 * TGPaintNeonBrushBorderFraction);
    
    CGFloat blueRadius = floor(size.width / 2 * TGPaintNeonBrushSolidFraction - border);
    CGContextSetFillColorWithColor(ctx, [UIColor blueColor].CGColor);
    CGContextAddEllipseInRect(ctx, CGRectMake(size.width / 2.0f - blueRadius, size.height / 2.0f - blueRadius, blueRadius * 2, blueRadius * 2));
    CGContextFillPath(ctx);
    
    CGFloat greenRadius = blueRadius + border + 1;
    CGContextSetLineWidth(ctx, border * 3);
    CGContextSetStrokeColorWithColor(ctx, [UIColor greenColor].CGColor);
    CGContextAddEllipseInRect(ctx, CGRectMake(size.width / 2.0f - greenRadius, size.height / 2.0f - greenRadius, greenRadius * 2, greenRadius * 2));
    CGContextStrokePath(ctx);
    
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorspace);
    
    return image;
}

- (CGImageRef)stampRef
{
    static CGImageRef image = NULL;
    
    if (image == NULL)
    {
        image = [self generateNeonStampForSize:TGPaintBrushTextureSize];
    }
    
    return image;
}

- (CGImageRef)previewStampRef
{
    if (_previewStampRef == NULL)
    {
        _previewStampRef = [self generateNeonStampForSize:TGPaintBrushPreviewTextureSize];
    }
    
    return _previewStampRef;
}

static UIImage *neonBrushPreviewImage = nil;

- (UIImage *)previewImage
{
    return neonBrushPreviewImage;
}

- (void)setPreviewImage:(UIImage *)previewImage
{
    neonBrushPreviewImage = previewImage;
}

@end
