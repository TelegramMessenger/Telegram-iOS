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

+ (UIColor *)toolbarIconColor
{
    return [UIColor whiteColor];
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

+ (UIImage *)cropIcon
{
    return TGTintedImage([UIImage imageNamed:@"Editor/Crop"], [self toolbarIconColor]);
}

+ (UIImage *)toolsIcon
{
    return TGTintedImage([UIImage imageNamed:@"Editor/Adjustments"], [self toolbarIconColor]);
}

+ (UIImage *)rotateIcon
{
    return TGTintedImage([UIImage imageNamed:@"Editor/Rotate"], [self toolbarIconColor]);
}

+ (UIImage *)paintIcon
{
    return TGTintedImage([UIImage imageNamed:@"Editor/BrushSelectedPen"], [self toolbarIconColor]);
}

+ (UIImage *)stickerIcon
{
    return TGTintedImage([UIImage imageNamed:@"Editor/AddSticker"], [self toolbarIconColor]);
}

+ (UIImage *)textIcon
{
    return TGTintedImage([UIImage imageNamed:@"Editor/AddText"], [self toolbarIconColor]);
}

+ (UIImage *)eraserIcon
{
    return TGTintedImage([UIImage imageNamed:@"Editor/Eraser"], [self toolbarIconColor]);
}

+ (UIImage *)mirrorIcon
{
    return TGTintedImage([UIImage imageNamed:@"Editor/Flip"], [self toolbarIconColor]);
}

+ (UIImage *)aspectRatioIcon
{
    return TGTintedImage([UIImage imageNamed:@"Editor/AspectRatio"], [self toolbarIconColor]);
}

+ (UIImage *)aspectRatioActiveIcon
{
    return TGTintedImage([UIImage imageNamed:@"Editor/AspectRatio"], [self accentColor]);
}

+ (UIImage *)tintIcon
{
    return TGTintedImage([UIImage imageNamed:@"Editor/Tint"], [self toolbarIconColor]);
}

+ (UIImage *)blurIcon
{
    return TGTintedImage([UIImage imageNamed:@"Editor/Blur"], [self toolbarIconColor]);
}

+ (UIImage *)curvesIcon
{
    return TGTintedImage([UIImage imageNamed:@"Editor/Curves"], [self toolbarIconColor]);
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
        CGContextSetFillColorWithColor(context, UIColorRGBA(0x000000, 0.3f).CGColor);
        CGContextFillEllipseInRect(context, CGRectInset(rect, 3, 3));
        
        muteBackground = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return muteBackground;
}

+ (UIImage *)muteIcon
{
    return TGComponentsImageNamed(@"PhotoEditorMute.png");
}

+ (UIImage *)muteActiveIcon
{
    return TGTintedImage([self gifIcon], [self accentColor]);
}

+ (UIImage *)gifIcon
{
    return TGTintedImage([UIImage imageNamed:@"Editor/Gif"], [self toolbarIconColor]);
}

+ (UIImage *)gifActiveIcon
{
    return TGTintedImage([UIImage imageNamed:@"Editor/Gif"], [self accentColor]);
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
    CGFloat lineWidth = 2.0f - TGScreenPixel;
    
    CGSize size = CGSizeMake(28.0f, 22.0f);
    CGRect rect = CGRectInset(CGRectMake(0.0f, 0.0f, size.width, size.height), lineWidth / 2.0, lineWidth / 2.0);
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0f);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:5.0f];
    
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

    CGContextAddPath(context, path.CGPath);
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, lineWidth);
    CGContextStrokePath(context);
    
    UIFont *font = [TGFont roundedFontOfSize:11];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CGSize textSize = [label sizeWithFont:font];
    [[UIColor whiteColor] setFill];
    [label drawInRect:CGRectMake((size.width - textSize.width) / 2.0f + TGScreenPixel, 4.0f, textSize.width, textSize.height) withFont:font];
#pragma clang diagnostic pop
    
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        CGSize size = [label sizeWithFont:font];
        [label drawInRect:CGRectMake(floor(background.size.width - size.width) / 2.0f, 9.0f, size.width, size.height) withFont:font];
#pragma clang diagnostic pop
        
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
