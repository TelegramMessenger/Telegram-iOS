#import <UIKit/UIKit.h>

@class TGTemporaryImage;

UIImage *TGAverageColorImage(UIColor *color);
UIImage *TGAverageColorRoundImage(UIColor *color, CGSize size);
UIImage *TGAverageColorAttachmentImage(UIColor *color, bool attachmentBorder, int position);
UIImage *TGAverageColorAttachmentWithCornerRadiusImage(UIColor *color, bool attachmentBorder, int cornerRadius, int position);
UIImage *TGBlurredAttachmentImage(UIImage *source, CGSize size, uint32_t *averageColor, bool attachmentBorder, int position);
UIImage *TGSecretBlurredAttachmentImage(UIImage *source, CGSize size, uint32_t *averageColor, bool attachmentBorder, int position);
UIImage *TGBlurredFileImage(UIImage *source, CGSize size, uint32_t *averageColor, int borderRadius);
UIImage *TGLoadedAttachmentImage(UIImage *source, CGSize size, uint32_t *averageColor, bool attachmentBorder, int position);
UIImage *TGAnimationFrameAttachmentImage(UIImage *source, CGSize size, CGSize renderSize);
UIImage *TGLoadedFileImage(UIImage *source, CGSize size, uint32_t *averageColor, int borderRadius);
UIImage *TGReducedAttachmentImage(UIImage *source, CGSize originalSize, bool attachmentBorder, int position);
UIImage *TGBlurredBackgroundImage(UIImage *source, CGSize size);
UIImage *TGRoundImage(UIImage *source, CGSize size);
UIImage *TGBlurredAlphaImage(UIImage *source, CGSize size);
UIImage *TGBlurredRectangularImage(UIImage *source, bool more, CGSize size, CGSize renderSize, uint32_t *averageColor, void (^pixelProcessingBlock)(void *, int, int, int));

UIImage *TGCropBackdropImage(UIImage *source, CGSize size);
UIImage *TGCameraPositionSwitchImage(UIImage *source, CGSize size);
UIImage *TGCameraModeSwitchImage(UIImage *source, CGSize size);

UIImage *TGBlurredAttachmentWithCornerRadiusImage(UIImage *source, CGSize size, uint32_t *averageColor, bool attachmentBorder, int cornerRadius, int position);
UIImage *TGLoadedAttachmentWithCornerRadiusImage(UIImage *source, CGSize size, uint32_t *averageColor, bool attachmentBorder, int cornerRadius, int inset, int position);
UIImage *TGReducedAttachmentWithCornerRadiusImage(UIImage *source, CGSize originalSize, bool attachmentBorder, int cornerRadius, int position);
UIImage *TGSecretBlurredAttachmentWithCornerRadiusImage(UIImage *source, CGSize size, uint32_t *averageColor, bool attachmentBorder, CGFloat cornerRadius, int position);

void TGPlainImageAverageColor(UIImage *source, uint32_t *averageColor);
UIImage *TGScaleAndCropImageToPixelSize(UIImage *source, CGSize size, CGSize renderSize, uint32_t *averageColor, void (^pixelProcessingBlock)(void *, int, int, int));

NSArray *TGBlurredBackgroundImages(UIImage *source, CGSize size);

void TGAddImageCorners(void *memory, const unsigned int width, const unsigned int height, const unsigned int stride, int radius, int position);

void telegramFastBlur(int imageWidth, int imageHeight, int imageStride, void *pixels);
