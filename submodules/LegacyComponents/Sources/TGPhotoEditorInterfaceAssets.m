#import "TGPhotoEditorInterfaceAssets.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGFont.h"

#import "TGMediaAssetsController.h"

@implementation TGPhotoEditorInterfaceAssets

+ (UIColor *)toolbarBackgroundColor
{
    return [UIColor blackColor];
}

+ (UIColor *)toolbarTransparentBackgroundColor
{
    return UIColorRGBA(0x000000, 0.9f);
}

+ (UIColor *)cropTransparentOverlayColor
{
    return UIColorRGBA(0x000000, 0.7f);
}

+ (UIColor *)accentColor
{
    TGMediaAssetsPallete *pallete = nil;
    if ([[LegacyComponentsGlobals provider] respondsToSelector:@selector(mediaAssetsPallete)])
        pallete = [[LegacyComponentsGlobals provider] mediaAssetsPallete];
    
    return pallete.maybeAccentColor ?: UIColorRGB(0x65b3ff);
}

+ (UIColor *)panelBackgroundColor
{
    return UIColorRGBA(0x000000, 0.9f);
}

+ (UIColor *)selectedImagesPanelBackgroundColor
{
    return UIColorRGBA(0x000000, 0.9f); //UIColorRGBA(0x191919, 0.9f);
}

+ (UIColor *)editorButtonSelectionBackgroundColor
{
    return UIColorRGB(0xd1d1d1);
}

+ (UIImage *)captionIcon
{
    return TGComponentsImageNamed(@"PhotoEditorCaption.png");
}

+ (UIImage *)cropIcon
{
    return TGComponentsImageNamed(@"PhotoEditorCrop.png");
}

+ (UIImage *)toolsIcon
{
    return TGComponentsImageNamed(@"PhotoEditorTools.png");
}

+ (UIImage *)rotateIcon
{
    return TGComponentsImageNamed(@"PhotoEditorRotateIcon.png");
}

+ (UIImage *)paintIcon
{
    return TGComponentsImageNamed(@"PhotoEditorPaint.png");
}

+ (UIImage *)stickerIcon
{
    return TGComponentsImageNamed(@"PaintStickersIcon.png");
}

+ (UIImage *)textIcon
{
    return TGComponentsImageNamed(@"PaintTextIcon.png");
}

+ (UIImage *)eraserIcon
{
    return TGComponentsImageNamed(@"PaintEraserIcon.png");
}

+ (UIImage *)mirrorIcon
{
    return TGComponentsImageNamed(@"PhotoEditorMirrorIcon.png");
}

+ (UIImage *)aspectRatioIcon
{
    return TGComponentsImageNamed(@"PhotoEditorAspectRatioIcon.png");
}

+ (UIImage *)aspectRatioActiveIcon
{
    return TGTintedImage(TGComponentsImageNamed(@"PhotoEditorAspectRatioIcon.png"), [self accentColor]);
}

+ (UIImage *)tintIcon
{
    return TGComponentsImageNamed(@"PhotoEditorTintIcon.png");
}

+ (UIImage *)blurIcon
{
    return TGComponentsImageNamed(@"PhotoEditorBlurIcon.png");
}

+ (UIImage *)curvesIcon
{
    return TGComponentsImageNamed(@"PhotoEditorCurvesIcon.png");
}

+ (UIImage *)gifBackgroundImage
{
    static dispatch_once_t onceToken;
    static UIImage *muteBackground;
    dispatch_once(&onceToken, ^
    {
        CGRect rect = CGRectMake(0, 0, 39.0f, 39.0f);
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, UIColorRGBA(0x000000, 0.6f).CGColor);
        CGContextFillEllipseInRect(context, CGRectInset(rect, 3, 3));
        
        muteBackground = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return muteBackground;
}

+ (UIImage *)gifIcon
{
    return TGComponentsImageNamed(@"PhotoEditorMute.png");
}

+ (UIImage *)gifActiveIcon
{
    return TGTintedImage([self gifIcon], [self accentColor]);
}

+ (UIImage *)groupIcon
{
    return TGTintedImage(TGComponentsImageNamed(@"PhotoEditorGroupPhotosIcon.png"), UIColorRGB(0x4cb4ff));
}

+ (UIImage *)ungroupIcon
{
    return TGComponentsImageNamed(@"PhotoEditorGroupPhotosIcon.png");
}

+ (UIImage *)groupIconBackground
{
    static dispatch_once_t onceToken;
    static UIImage *backgroundImage;
    dispatch_once(&onceToken, ^
    {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(38.0f, 38.0f), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, UIColorRGBA(0x000000, 0.7f).CGColor);
        
        CGContextFillEllipseInRect(context, CGRectMake(3.5f, 1.0f, 31.0f, 31.0f));
        
        CGFloat lineWidth = 1.5f;
        if (TGScreenScaling() == 3.0f)
            lineWidth = 5.0f / 3.0f;
        CGContextSetLineWidth(context, lineWidth);
        CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextStrokeEllipseInRect(context, CGRectMake(3.0f, 1.0f, 31.0f, 31.0f));
        
        backgroundImage = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(38.0f / 4.0f, 38.0f / 4.0f, 38.0f / 4.0f, 38.0f / 4.0f)];
        UIGraphicsEndImageContext();
    });
    return backgroundImage;
}
                         
+ (UIImage *)groupIconBackgroundActive
{
    static dispatch_once_t onceToken;
    static UIImage *backgroundImage;
    dispatch_once(&onceToken, ^
    {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(38.0f, 38.0f), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, UIColorRGBA(0x000000, 0.7f).CGColor);
        
        CGContextFillEllipseInRect(context, CGRectMake(3.5f, 1.0f, 31.0f, 31.0f));
        
        CGFloat lineWidth = 1.5f;
        if (TGScreenScaling() == 3.0f)
            lineWidth = 5.0f / 3.0f;
        CGContextSetLineWidth(context, lineWidth);
        CGContextSetStrokeColorWithColor(context, UIColorRGB(0x4cb4ff).CGColor);
        CGContextStrokeEllipseInRect(context, CGRectMake(3.0f, 1.0f, 31.0f, 31.0f));
        
        backgroundImage = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(38.0f / 4.0f, 38.0f / 4.0f, 38.0f / 4.0f, 38.0f / 4.0f)];
        UIGraphicsEndImageContext();
    });
    return backgroundImage;
}

+ (UIImage *)qualityIconForPreset:(TGMediaVideoConversionPreset)preset
{
    UIImage *background = TGComponentsImageNamed(@"PhotoEditorQuality");
    
    UIGraphicsBeginImageContextWithOptions(background.size, false, 0.0f);
    
    NSString *label = @"";
    switch (preset)
    {
        case TGMediaVideoConversionPresetCompressedVeryLow:
            label = @"240";
            break;
            
        case TGMediaVideoConversionPresetCompressedLow:
            label = @"360";
            break;
            
        case TGMediaVideoConversionPresetCompressedMedium:
            label = @"480";
            break;
            
        case TGMediaVideoConversionPresetCompressedHigh:
            label = @"720";
            break;
            
        case TGMediaVideoConversionPresetCompressedVeryHigh:
            label = @"HD";
            break;
            
        default:
            label = @"480";
            break;
    }

    [background drawAtPoint:CGPointZero];

    UIFont *font = [TGFont roundedFontOfSize:11];
    CGSize size = [label sizeWithFont:font];
    [[UIColor whiteColor] setFill];
    [label drawInRect:CGRectMake(floor(background.size.width - size.width) / 2.0f, 8.0f, size.width, size.height) withFont:font];
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

+ (UIImage *)timerIconForValue:(NSInteger)value
{
    if (value < FLT_EPSILON)
    {
        return TGComponentsImageNamed(@"PhotoEditorTimer0");
    }
    else
    {
        UIImage *background = TGComponentsImageNamed(@"PhotoEditorTimer");
        
        UIGraphicsBeginImageContextWithOptions(background.size, false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        [background drawAtPoint:CGPointZero];
        
        CGContextSetBlendMode (context, kCGBlendModeSourceAtop);
        CGContextSetFillColorWithColor(context, [self accentColor].CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, background.size.width, background.size.height));
        
        CGContextSetBlendMode(context, kCGBlendModeNormal);
        
        NSString *label = [NSString stringWithFormat:@"%ld", value];
        
        UIFont *font = [TGFont roundedFontOfSize:11];
        CGSize size = [label sizeWithFont:font];
        [label drawInRect:CGRectMake(floor(background.size.width - size.width) / 2.0f, 9.0f, size.width, size.height) withFont:font];
        
        UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return result;
    }
}

+ (UIColor *)toolbarSelectedIconColor
{
    return UIColorRGB(0x171717);
}

+ (UIColor *)toolbarAppliedIconColor
{
    return [self accentColor];
}

+ (UIColor *)editorItemTitleColor
{
    return UIColorRGB(0x808080);
}

+ (UIColor *)editorActiveItemTitleColor
{
    return UIColorRGB(0xffffff);
}

+ (UIFont *)editorItemTitleFont
{
    return [TGFont systemFontOfSize:14];
}

+ (UIColor *)filterSelectionColor
{
    return [UIColor whiteColor];
}

+ (UIColor *)sliderBackColor
{
    return UIColorRGBA(0x808080, 0.6f);
}

+ (UIColor *)sliderTrackColor
{
    return UIColorRGB(0xcccccc);
}

+ (UIImage *)cameraIcon
{
    static dispatch_once_t onceToken;
    static UIImage *image;
    dispatch_once(&onceToken, ^
    {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(30.0f, 30.0f), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, UIColorRGBA(0x000000, 0.7f).CGColor);
        
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.5f, 0.5f, 29.0f, 29.0f) cornerRadius:8.5f];
        CGContextAddPath(context, path.CGPath);
        CGContextFillPath(context);
        
        [TGComponentsImageNamed(@"PhotoEditorCamera.png") drawAtPoint:CGPointZero];
        
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    
    return image;
}

@end
