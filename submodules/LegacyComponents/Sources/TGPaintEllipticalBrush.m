#import "TGPaintEllipticalBrush.h"
#import <LegacyComponents/TGPhotoEditorUtils.h>

const CGFloat TGPaintEllipticalBrushHardness = 0.89f;
const CGFloat TGPaintEllipticalBrushAngle = 110.0f;
const CGFloat TGPaintEllipticalBrushRoundness = 0.35f;

@implementation TGPaintEllipticalBrush

- (CGFloat)spacing
{
    return 0.075f;
}

- (CGFloat)alpha
{
    return 0.17f;
}

- (CGFloat)angle
{
    return TGDegreesToRadians(TGPaintEllipticalBrushAngle);
}

- (CGFloat)scale
{
    return 1.5f;
}

- (CGImageRef)generateEllipticalStampForSize:(CGSize)size hardness:(CGFloat)hardness roundness:(CGFloat)roundness
{
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceGray();
    CGContextRef ctx = CGBitmapContextCreate(NULL, (NSInteger)size.width, (NSInteger)size.height, 8, (NSInteger)size.width, colorspace, kCGImageAlphaNone);
    
    CGContextSetGrayFillColor(ctx, 0.4f, 1.0f);
    CGContextFillRect(ctx, CGRectMake(0, 0, size.width, size.height));
    
    CGContextTranslateCTM(ctx, 0.5f * size.width, 0.5f * size.height);
    CGContextScaleCTM(ctx, roundness, 1.0f);
    CGContextTranslateCTM(ctx, -0.5f * size.width, -0.5f * size.height);
    
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
        image = [self generateEllipticalStampForSize:TGPaintBrushTextureSize hardness:TGPaintEllipticalBrushHardness roundness:TGPaintEllipticalBrushRoundness];
    
    return image;
}

- (CGImageRef)previewStampRef
{
    if (_previewStampRef == NULL)
    {
        _previewStampRef = [self generateEllipticalStampForSize:TGPaintBrushPreviewTextureSize hardness:TGPaintEllipticalBrushHardness roundness:TGPaintEllipticalBrushRoundness];
    }
    
    return _previewStampRef;
}

static UIImage *ellipticalBrushPreviewImage = nil;

- (UIImage *)previewImage
{
    return ellipticalBrushPreviewImage;
}

- (void)setPreviewImage:(UIImage *)previewImage
{
    ellipticalBrushPreviewImage = previewImage;
}

@end
