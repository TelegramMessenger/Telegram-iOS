#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif
    
typedef enum {
    TGScaleImageFlipVerical = 1,
    TGScaleImageScaleOverlay = 2,
    TGScaleImageRoundCornersByOuterBounds = 4,
    TGScaleImageScaleSharper = 8
} TGScaleImageFlags;

UIImage *TGScaleImage(UIImage *image, CGSize size);
UIImage *TGScaleAndRoundCorners(UIImage *image, CGSize size, CGSize imageSize, int radius, UIImage *overlay, bool opaque, UIColor *backgroundColor);
UIImage *TGScaleAndRoundCornersWithOffset(UIImage *image, CGSize size, CGPoint offset, CGSize imageSize, int radius, UIImage *overlay, bool opaque, UIColor *backgroundColor);
UIImage *TGScaleAndRoundCornersWithOffsetAndFlags(UIImage *image, CGSize size, CGPoint offset, CGSize imageSize, int radius, UIImage *overlay, bool opaque, UIColor *backgroundColor, int flags);
    
inline bool TGEnableBlur() { return false; }
UIImage *TGScaleAndBlurImage(NSData *data, CGSize size, __autoreleasing NSData **blurredData);

UIImage *TGScaleImageToPixelSize(UIImage *image, CGSize size);
UIImage *TGRotateAndScaleImageToPixelSize(UIImage *image, CGSize size);

UIImage *TGFixOrientationAndCrop(UIImage *source, CGRect cropFrame, CGSize imageSize);
UIImage *TGRotateAndCrop(UIImage *source, CGRect cropFrame, CGSize imageSize);
    
UIImage *TGIdenticonImage(NSData *data, NSData *additionalData, CGSize size);
    
UIImage *TGCircleImage(CGFloat radius, UIColor *color);

UIImage *TGImageNamed(NSString *name);
UIImage *TGTintedImage(UIImage *image, UIColor *color);
UIImage *TGTintedWithAlphaImage(UIImage *image, UIColor *color);
    
NSString *TGImageHash(NSData *data);
    
uint32_t TGColorHexCode(UIColor *color);
uint32_t TGColorHexCodeWithAlpha(UIColor *color);
    
NSData *TGJPEGRepresentation(UIImage *image, CGFloat compressionRate);
bool TGWriteJPEGRepresentationToFile(UIImage *image, CGFloat compressionRate, NSString *filePath);
    
#ifdef __cplusplus
}
#endif

@interface UIImage (Preloading)

- (UIImage *)preloadedImage;
- (UIImage *)preloadedImageWithAlpha;
- (void)tgPreload;

- (void)setMediumImage:(UIImage *)image;
- (UIImage *)mediumImage;

- (CGSize)screenSize;
- (CGSize)pixelSize;

@end

#ifdef __cplusplus
extern "C" {
#endif

CGSize TGFitSize(CGSize size, CGSize maxSize);
CGSize TGFitSizeF(CGSize size, CGSize maxSize);
CGSize TGFillSize(CGSize size, CGSize maxSize);
CGSize TGFillSizeF(CGSize size, CGSize maxSize);
CGSize TGCropSize(CGSize size, CGSize maxSize);
CGSize TGScaleToFill(CGSize size, CGSize boundsSize);
CGSize TGScaleToFit(CGSize size, CGSize boundsSize);
    
CGFloat TGRetinaFloor(CGFloat value);
CGFloat TGRetinaCeil(CGFloat value);
CGFloat TGScreenPixelFloor(CGFloat value);
    
bool TGIsRetina();
CGFloat TGScreenScaling();
bool TGIsPad();
    
CGFloat TGSeparatorHeight();

    
CGSize TGScreenSize();
CGSize TGNativeScreenSize();
    
extern CGFloat TGRetinaPixel;
extern CGFloat TGScreenPixel;
    
void TGDrawSvgPath(CGContextRef context, NSString *path);

#ifdef __cplusplus
}
#endif

@interface TGImageBorderPallete : NSObject

@property (nonatomic, readonly) UIColor *borderColor;
@property (nonatomic, readonly) UIColor *shadowColor;

+ (instancetype)palleteWithBorderColor:(UIColor *)borderColor shadowColor:(UIColor *)shadowColor;

@end
