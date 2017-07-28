#import "TGPhotoEditorInterfaceAssets.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGFont.h"

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
    return UIColorRGB(0x65b3ff);
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
    return [UIImage imageNamed:@"PhotoEditorCaption.png"];
}

+ (UIImage *)cropIcon
{
    return [UIImage imageNamed:@"PhotoEditorCrop.png"];
}

+ (UIImage *)toolsIcon
{
    return [UIImage imageNamed:@"PhotoEditorTools.png"];
}

+ (UIImage *)rotateIcon
{
    return [UIImage imageNamed:@"PhotoEditorRotateIcon.png"];
}

+ (UIImage *)paintIcon
{
    return [UIImage imageNamed:@"PhotoEditorPaint.png"];
}

+ (UIImage *)stickerIcon
{
    return [UIImage imageNamed:@"PaintStickersIcon.png"];
}

+ (UIImage *)textIcon
{
    return [UIImage imageNamed:@"PaintTextIcon.png"];
}

+ (UIImage *)eraserIcon
{
    return [UIImage imageNamed:@"PaintEraserIcon.png"];
}

+ (UIImage *)mirrorIcon
{
    return [UIImage imageNamed:@"PhotoEditorMirrorIcon.png"];
}

+ (UIImage *)aspectRatioIcon
{
    return [UIImage imageNamed:@"PhotoEditorAspectRatioIcon.png"];
}

+ (UIImage *)aspectRatioActiveIcon
{
    return TGTintedImage([UIImage imageNamed:@"PhotoEditorAspectRatioIcon.png"], [self accentColor]);
}

+ (UIImage *)tintIcon
{
    return [UIImage imageNamed:@"PhotoEditorTintIcon.png"];
}

+ (UIImage *)blurIcon
{
    return [UIImage imageNamed:@"PhotoEditorBlurIcon.png"];
}

+ (UIImage *)curvesIcon
{
    return [UIImage imageNamed:@"PhotoEditorCurvesIcon.png"];
}

+ (UIImage *)gifIcon
{
    return [UIImage imageNamed:@"PhotoEditorMute.png"];
}

+ (UIImage *)gifActiveIcon
{
    return [UIImage imageNamed:@"PhotoEditorMuteActive.png"];
}

+ (UIImage *)qualityIconForPreset:(TGMediaVideoConversionPreset)preset
{
    UIImage *background = [UIImage imageNamed:@"PhotoEditorQuality"];
    
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
        return [UIImage imageNamed:@"PhotoEditorTimer0"];
    }
    else
    {
        UIImage *background = [UIImage imageNamed:@"PhotoEditorTimer"];
        
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

@end
