#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
extern "C" {
#endif
    
CGSize TGScaleToSize(CGSize size, CGSize maxSize);
CGSize TGScaleToFillSize(CGSize size, CGSize maxSize);
    
CGFloat TGDegreesToRadians(CGFloat degrees);
CGFloat TGRadiansToDegrees(CGFloat radians);
    
UIImage *TGPhotoEditorCrop(UIImage *image, UIImage *paintingImage, UIImageOrientation orientation, CGFloat rotation, CGRect rect, bool mirrored, CGSize maxSize, CGSize originalSize, bool shouldResize);
UIImage *TGPhotoEditorVideoCrop(UIImage *image, UIImage *paintingImage, UIImageOrientation orientation, CGFloat rotation, CGRect rect, bool mirrored, CGSize maxSize, CGSize originalSize, bool shouldResize, bool useImageSize);
UIImage *TGPhotoEditorVideoExtCrop(UIImage *inputImage, UIImage *paintingImage, UIImageOrientation orientation, CGFloat rotation, CGRect rect, bool mirrored, CGSize maxSize, CGSize originalSize, bool shouldResize, bool useImageSize, bool skipImageTransform, bool fillPainting);
UIImage *TGPhotoEditorFitImage(UIImage *image, CGSize maxSize);
CGSize TGRotatedContentSize(CGSize contentSize, CGFloat rotation);

UIImage *TGPhotoEditorPaintingCrop(UIImage *paintingImage, UIImageOrientation orientation, CGFloat rotation, CGRect rect, bool mirrored, CGSize maxSize, CGSize originalSize, bool shouldResize, bool useImageSize, bool skipImageTransform);
    
UIImageOrientation TGNextCWOrientationForOrientation(UIImageOrientation orientation);
UIImageOrientation TGNextCCWOrientationForOrientation(UIImageOrientation orientation);
CGFloat TGRotationForOrientation(UIImageOrientation orientation);
CGFloat TGCounterRotationForOrientation(UIImageOrientation orientation);
CGFloat TGRotationForInterfaceOrientation(UIInterfaceOrientation orientation);
CGAffineTransform TGTransformForVideoOrientation(AVCaptureVideoOrientation orientation, bool mirrored);
    
bool TGOrientationIsSideward(UIImageOrientation orientation, bool *mirrored);
UIImageOrientation TGMirrorSidewardOrientation(UIImageOrientation orientation);
    
UIImageOrientation TGVideoOrientationForAsset(AVAsset *asset, bool *mirrored);
CGAffineTransform TGVideoTransformForOrientation(UIImageOrientation orientation, CGSize size, CGRect cropRect, bool mirror);
CGAffineTransform TGVideoCropTransformForOrientation(UIImageOrientation orientation, CGSize size, bool rotateSize);
CGAffineTransform TGVideoTransformForCrop(UIImageOrientation orientation, CGSize size, bool mirrored);
    
CGSize TGTransformDimensionsWithTransform(CGSize dimensions, CGAffineTransform transform);
    
CGFloat TGRubberBandDistance(CGFloat offset, CGFloat dimension);
    
bool _CGPointEqualToPointWithEpsilon(CGPoint point1, CGPoint point2, CGFloat epsilon);
bool _CGRectEqualToRectWithEpsilon(CGRect rect1, CGRect rect2, CGFloat epsilon);
    
CGSize TGPhotoThumbnailSizeForCurrentScreen();
CGSize TGPhotoEditorScreenImageMaxSize();
    
extern const CGSize TGPhotoEditorResultImageMaxSize;
    
#ifdef __cplusplus
}
#endif
