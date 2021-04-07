#import "TGPaintArrowBrush.h"

const CGFloat TGPaintArrowBrushHardness = 0.92f;

@implementation TGPaintArrowBrush

- (CGFloat)spacing
{
    return 0.15f;
}

- (CGFloat)alpha
{
    return 0.85f;
}

- (CGFloat)angle
{
    return 0.0f;
}

//- (CGFloat)dynamic
//{
//    return 0.75f;
//}

- (bool)arrow
{
    return true;
}

- (CGImageRef)generateRadialStampForSize:(CGSize)size hardness:(CGFloat)hardness
{
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceGray();
    CGContextRef ctx = CGBitmapContextCreate(NULL, (NSInteger)size.width, (NSInteger)size.height, 8, (NSInteger)size.width, colorspace, kCGImageAlphaNone);
    
    CGContextSetGrayFillColor(ctx, 0.0f, 1.0f);
    CGContextFillRect(ctx, CGRectMake(0, 0, size.width, size.height));
    
    NSArray *colors = @[(__bridge id) [UIColor whiteColor].CGColor, (__bridge id) [UIColor blackColor].CGColor];
    const CGFloat locations[] = {0.0, 1.0};
    
    CGGradientRef gradientRef = CGGradientCreateWithColors(colorspace, (__bridge CFArrayRef) colors, locations);
    CGPoint center = CGPointMake(size.width / 2, size.height / 2);
    
    CGFloat maxRadius = size.width / 2;
    CGFloat hFactor = hardness * 0.99;
    CGGradientDrawingOptions options = kCGGradientDrawsBeforeStartLocation |kCGGradientDrawsAfterEndLocation;
    CGContextDrawRadialGradient(ctx, gradientRef, center, hFactor * maxRadius, center, maxRadius, options);
    
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorspace);
    CGGradientRelease(gradientRef);
    
    return image;
}

- (CGImageRef)stampRef
{
    static CGImageRef image = NULL;
    
    if (image == NULL)
        image = [self generateRadialStampForSize:TGPaintBrushTextureSize hardness:TGPaintArrowBrushHardness];
    
    return image;
}

- (CGImageRef)previewStampRef
{
    if (_previewStampRef == NULL)
        _previewStampRef = [self generateRadialStampForSize:TGPaintBrushPreviewTextureSize hardness:TGPaintArrowBrushHardness];
    
    return _previewStampRef;
}

static UIImage *radialBrushPreviewImage = nil;

- (UIImage *)previewImage
{
    return radialBrushPreviewImage;
}

- (void)setPreviewImage:(UIImage *)previewImage
{
    radialBrushPreviewImage = previewImage;
}

@end
