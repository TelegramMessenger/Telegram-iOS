#import "TGPhotoEditorUtils.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"

#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>

const CGSize TGPhotoEditorResultImageMaxSize = { 1280, 1280 };
const CGSize TGPhotoEditorScreenImageHardLimitSize = { 1280, 1280 };
const CGSize TGPhotoEditorScreenImageHardLimitLegacySize = { 750, 750 };

CGSize TGPhotoEditorScreenImageMaxSize()
{
    CGSize screenSize = TGScreenSize();
    CGSize limitSize = screenSize.width == 320 ? TGPhotoEditorScreenImageHardLimitLegacySize : TGPhotoEditorScreenImageHardLimitSize;
    return limitSize;
}

CGSize TGPhotoThumbnailSizeForCurrentScreen()
{
    CGSize screenSize = TGScreenSize();
    CGFloat widescreenWidth = MAX(screenSize.width, screenSize.height);
    
    if ([UIScreen mainScreen].scale >= 2.0f - FLT_EPSILON)
    {
        if (widescreenWidth >= 926.0f - FLT_EPSILON)
        {
            return CGSizeMake(141.0f + TGScreenPixel, 141.0 + TGScreenPixel);
        }
        if (widescreenWidth >= 896.0f - FLT_EPSILON)
        {
            return CGSizeMake(137.0f - TGScreenPixel, 137.0f - TGScreenPixel);
        }
        else if (widescreenWidth >= 844.0f - FLT_EPSILON)
        {
            return CGSizeMake(129.0f - TGScreenPixel, 129.0f - TGScreenPixel);
        }
        else if (widescreenWidth >= 812.0f - FLT_EPSILON)
        {
            return CGSizeMake(124.0f - TGScreenPixel, 124.0f - TGScreenPixel);
        }
        else if (widescreenWidth >= 736.0f - FLT_EPSILON)
        {
            return CGSizeMake(137.0f - TGScreenPixel, 137.0f - TGScreenPixel);
        }
        else if (widescreenWidth >= 667.0f - FLT_EPSILON)
        {
            return CGSizeMake(124.0f - TGScreenPixel, 124.0f - TGScreenPixel);
        }
        else
        {
            return CGSizeMake(106.0f - TGScreenPixel, 106.0f - TGScreenPixel);
        }
    }
    
    return CGSizeMake(106.0f, 106.0f);
}

CGSize TGScaleToSize(CGSize size, CGSize maxSize)
{    
    CGSize newSize = size;
    newSize.width = maxSize.width;
    newSize.height = CGFloor(newSize.width * size.height / size.width);
    
    if (newSize.height > maxSize.height)
    {
        newSize.height = maxSize.height;
        newSize.width = CGFloor(newSize.height * size.width / size.height);
    }
    
    return newSize;
}

CGSize TGScaleToFillSize(CGSize size, CGSize maxSize)
{
    if (size.width < 1)
        size.width = 1;
    
    if (size.height < 1)
        size.height = 1;
    
    if (size.height > size.width)
    {
        size.height = CGFloor(maxSize.width * size.height / MAX(1.0f, size.width));
        size.width = maxSize.width;
    }
    else
    {
        size.width = CGFloor(maxSize.height * size.width / MAX(1.0f, size.height));
        size.height = maxSize.height;
    }
    
    return size;
}

CGFloat TGDegreesToRadians(CGFloat degrees)
{
    return degrees * (CGFloat)M_PI / 180.0f;
}

CGFloat TGRadiansToDegrees(CGFloat radians)
{
    return radians * 180.0f / (CGFloat)M_PI;
}

CGImageRef TGPhotoLanczosResize(UIImage *image, CGSize targetSize)
{
    if (TGOrientationIsSideward(image.imageOrientation, NULL))
        targetSize = CGSizeMake(targetSize.height, targetSize.width);
    
    CGImageRef sourceRef = image.CGImage;
    vImage_Buffer srcBuffer;
    vImage_CGImageFormat format =
    {
        .bitsPerComponent = 8,
        .bitsPerPixel = 32,
        .colorSpace = NULL,
        .bitmapInfo = (CGBitmapInfo)kCGImageAlphaFirst,
        .version = 0,
        .decode = NULL,
        .renderingIntent = kCGRenderingIntentDefault,
    };
    vImage_Error ret = vImageBuffer_InitWithCGImage(&srcBuffer, &format, NULL, sourceRef, kvImageNoFlags);
    if (ret != kvImageNoError)
    {
        free(srcBuffer.data);
        return nil;
    }
    
    NSUInteger bytesPerPixel = 4;
    NSUInteger dstBytesPerRow = bytesPerPixel * (NSUInteger)targetSize.width;
    uint8_t *dstData = (uint8_t *)calloc((NSUInteger)targetSize.height * (NSInteger)targetSize.width * bytesPerPixel, sizeof(uint8_t));
    vImage_Buffer dstBuffer =
    {
        .data = dstData,
        .height = (NSUInteger)targetSize.height,
        .width = (NSUInteger)targetSize.width,
        .rowBytes = dstBytesPerRow
    };
    
    ret = vImageScale_ARGB8888(&srcBuffer, &dstBuffer, NULL, kvImageHighQualityResampling);
    free(srcBuffer.data);
    if (ret != kvImageNoError)
    {
        free(dstData);
        return nil;
    }
    
    ret = kvImageNoError;
    CGImageRef destRef = vImageCreateCGImageFromBuffer(&dstBuffer, &format, NULL, NULL, kvImageNoFlags, &ret);
    free(dstData);
    
    return destRef;
}

UIImage *TGPhotoEditorFitImage(UIImage *image, CGSize maxSize)
{
    CGSize fittedImageSize = TGFitSize(image.size, maxSize);
    
    if (iosMajorVersion() >= 7)
    {
        CGImageRef imageRef = TGPhotoLanczosResize(image, fittedImageSize);
        
        UIImage *resizedImage = [[UIImage alloc] initWithCGImage:imageRef scale:image.scale orientation:image.imageOrientation];
        CGImageRelease(imageRef);
        
        return resizedImage;
    }
    else
    {
        UIGraphicsBeginImageContextWithOptions(fittedImageSize, true, 1.0f);
        
        [image drawInRect:CGRectMake(0, 0, fittedImageSize.width, fittedImageSize.height)];
        
        UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return resizedImage;
    }
}

UIImage *TGPhotoEditorLegacyCrop(UIImage *image, UIImage *paintingImage, UIImageOrientation orientation, CGFloat rotation, CGRect rect, bool mirrored, CGSize maxSize, bool shouldResize)
{
    CGSize fittedImageSize = shouldResize ? TGFitSize(rect.size, maxSize) : rect.size;
    
    CGSize outputImageSize = fittedImageSize;
    outputImageSize.width = CGFloor(outputImageSize.width);
    outputImageSize.height = CGFloor(outputImageSize.height);
    if (TGOrientationIsSideward(orientation, NULL))
        outputImageSize = CGSizeMake(outputImageSize.height, outputImageSize.width);
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(outputImageSize.width, outputImageSize.height), true, 1.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, outputImageSize.width, outputImageSize.height));
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    
    CGSize rotatedContentSize = TGRotatedContentSize(image.size, rotation);
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformTranslate(transform, outputImageSize.width / 2, outputImageSize.height / 2);
    
    transform = CGAffineTransformScale(transform, fittedImageSize.width / rect.size.width, fittedImageSize.height / rect.size.height);
    transform = CGAffineTransformRotate(transform, TGRotationForOrientation(orientation));
    transform = CGAffineTransformTranslate(transform, rotatedContentSize.width / 2 - CGRectGetMidX(rect), rotatedContentSize.height / 2 - CGRectGetMidY(rect));
    transform = CGAffineTransformRotate(transform, rotation);
    CGContextConcatCTM(context, transform);
    
    if (mirrored)
        CGContextScaleCTM(context, -1.0f, 1.0f);
    
    CGRect frame = CGRectMake(CGCeil(-image.size.width / 2), CGCeil(-image.size.height / 2), image.size.width, image.size.height);
    [image drawInRect:frame];
    if (paintingImage != nil)
        [paintingImage drawInRect:frame];
    
    UIImage *croppedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return croppedImage;
}

UIImage *TGPhotoEditorCrop(UIImage *inputImage, UIImage *paintingImage, UIImageOrientation orientation, CGFloat rotation, CGRect rect, bool mirrored, CGSize maxSize, CGSize originalSize, bool shouldResize)
{
    return TGPhotoEditorVideoCrop(inputImage, paintingImage, orientation, rotation, rect, mirrored, maxSize, originalSize, shouldResize, false);
}

UIImage *TGPhotoEditorVideoCrop(UIImage *inputImage, UIImage *paintingImage, UIImageOrientation orientation, CGFloat rotation, CGRect rect, bool mirrored, CGSize maxSize, CGSize originalSize, bool shouldResize, bool useImageSize) {
    return TGPhotoEditorVideoExtCrop(inputImage, paintingImage, orientation, rotation, rect, mirrored, maxSize, originalSize, shouldResize, useImageSize, false, false);
}

UIImage *TGPhotoEditorVideoExtCrop(UIImage *inputImage, UIImage *paintingImage, UIImageOrientation orientation, CGFloat rotation, CGRect rect, bool mirrored, CGSize maxSize, CGSize originalSize, bool shouldResize, bool useImageSize, bool skipImageTransform, bool fillPainting)
{
    if (iosMajorVersion() < 7)
        return TGPhotoEditorLegacyCrop(inputImage, paintingImage, orientation, rotation, rect, mirrored, maxSize, shouldResize);
    
    CGSize fittedOriginalSize = originalSize;
    if (useImageSize)
    {
        CGFloat ratio = inputImage.size.width / originalSize.width;
        if (skipImageTransform) {
            
        }
        rect.origin.x = rect.origin.x * ratio;
        rect.origin.y = rect.origin.y * ratio;
        rect.size.width = rect.size.width * ratio;
        rect.size.height = rect.size.height * ratio;
        
        fittedOriginalSize = CGSizeMake(originalSize.width * ratio, originalSize.height * ratio);
    }
    
    CGSize fittedImageSize = shouldResize ? TGFitSize(rect.size, maxSize) : rect.size;
    
    CGSize outputImageSize = fittedImageSize;
    outputImageSize.width = CGFloor(outputImageSize.width);
    outputImageSize.height = CGFloor(outputImageSize.height);
    if (TGOrientationIsSideward(orientation, NULL))
        outputImageSize = CGSizeMake(outputImageSize.height, outputImageSize.width);
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(outputImageSize.width, outputImageSize.height), true, 1.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSaveGState(context);
    
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, outputImageSize.width, outputImageSize.height));
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
        
    UIImage *image = nil;
    CGSize imageSize = inputImage.size;
    if (shouldResize)
    {
        CGSize referenceSize = useImageSize ? inputImage.size : originalSize;
        CGSize resizedSize = CGSizeMake(referenceSize.width * fittedImageSize.width / rect.size.width, referenceSize.height * fittedImageSize.height / rect.size.height);
        CGImageRef resizedImage = TGPhotoLanczosResize(inputImage, resizedSize);
        image = [UIImage imageWithCGImage:resizedImage scale:0.0f orientation:inputImage.imageOrientation];
        CGImageRelease(resizedImage);
        
        if (skipImageTransform) {
            imageSize = CGSizeMake(image.size.width * fittedOriginalSize.width / rect.size.width, image.size.height * fittedOriginalSize.height / rect.size.height);
        } else {
            imageSize = image.size;
        }
    }
    else
    {
        image = inputImage;
        imageSize = image.size;
    }
    
    if (skipImageTransform) {
        [image drawInRect:CGRectMake(0.0, 0.0, outputImageSize.width, outputImageSize.height)];
    }
    
    CGSize scales = CGSizeMake(fittedImageSize.width / rect.size.width, fittedImageSize.height / rect.size.height);
    CGSize rotatedContentSize = TGRotatedContentSize(inputImage.size, rotation);
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformTranslate(transform, outputImageSize.width / 2, outputImageSize.height / 2);
    transform = CGAffineTransformRotate(transform, TGRotationForOrientation(orientation));
    transform = CGAffineTransformTranslate(transform, (rotatedContentSize.width / 2 - CGRectGetMidX(rect)) * scales.width, (rotatedContentSize.height / 2 - CGRectGetMidY(rect)) * scales.height);
    transform = CGAffineTransformRotate(transform, rotation);
    CGContextConcatCTM(context, transform);
    
    if (mirrored)
        CGContextScaleCTM(context, -1.0f, 1.0f);
    
    if (!skipImageTransform) {
        [image drawAtPoint:CGPointMake(-image.size.width / 2, -image.size.height / 2)];
    }
    
    if (paintingImage != nil)
    {
        if (fillPainting) {
            CGContextRestoreGState(context);
            [paintingImage drawInRect:CGRectMake(0.0, 0.0, outputImageSize.width, outputImageSize.height)];
        } else {
            if (mirrored)
                CGContextScaleCTM(context, -1.0f, 1.0f);
                
            [paintingImage drawInRect:CGRectMake(-imageSize.width / 2, -imageSize.height / 2, imageSize.width, imageSize.height)];
        }
    }
    
    UIImage *croppedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return croppedImage;
}

UIImage *TGPhotoEditorPaintingCrop(UIImage *paintingImage, UIImageOrientation orientation, CGFloat rotation, CGRect rect, bool mirrored, CGSize maxSize, CGSize originalSize, bool shouldResize, bool useImageSize, bool skipImageTransform)
{
    CGSize fittedOriginalSize = originalSize;
    if (useImageSize)
    {
        CGFloat ratio = paintingImage.size.width / originalSize.width;
        if (skipImageTransform) {
            
        }
        rect.origin.x = rect.origin.x * ratio;
        rect.origin.y = rect.origin.y * ratio;
        rect.size.width = rect.size.width * ratio;
        rect.size.height = rect.size.height * ratio;
        
        fittedOriginalSize = CGSizeMake(originalSize.width * ratio, originalSize.height * ratio);
    }
    
    CGSize fittedImageSize = shouldResize ? TGFitSize(rect.size, maxSize) : rect.size;
    
    CGSize outputImageSize = fittedImageSize;
    outputImageSize.width = CGFloor(outputImageSize.width);
    outputImageSize.height = CGFloor(outputImageSize.height);
    if (TGOrientationIsSideward(orientation, NULL))
        outputImageSize = CGSizeMake(outputImageSize.height, outputImageSize.width);
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(outputImageSize.width, outputImageSize.height), false, 1.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();

    UIImage *image = nil;
    CGSize imageSize = paintingImage.size;
    if (shouldResize)
    {
        CGSize referenceSize = useImageSize ? paintingImage.size : originalSize;
        CGSize resizedSize = CGSizeMake(referenceSize.width * fittedImageSize.width / rect.size.width, referenceSize.height * fittedImageSize.height / rect.size.height);
        
        UIGraphicsBeginImageContextWithOptions(resizedSize, false, 1.0f);
        [image drawInRect:CGRectMake(0, 0, resizedSize.width, resizedSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    
        if (skipImageTransform) {
            imageSize = CGSizeMake(image.size.width * fittedOriginalSize.width / rect.size.width, image.size.height * fittedOriginalSize.height / rect.size.height);
        } else {
            imageSize = image.size;
        }
    }
    else
    {
        image = paintingImage;
        imageSize = image.size;
    }
    
    if (skipImageTransform) {
        [image drawInRect:CGRectMake(0.0, 0.0, outputImageSize.width, outputImageSize.height)];
    }
    
    CGSize scales = CGSizeMake(fittedImageSize.width / rect.size.width, fittedImageSize.height / rect.size.height);
    CGSize rotatedContentSize = TGRotatedContentSize(paintingImage.size, rotation);
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformTranslate(transform, outputImageSize.width / 2, outputImageSize.height / 2);
    transform = CGAffineTransformRotate(transform, TGRotationForOrientation(orientation));
    transform = CGAffineTransformTranslate(transform, (rotatedContentSize.width / 2 - CGRectGetMidX(rect)) * scales.width, (rotatedContentSize.height / 2 - CGRectGetMidY(rect)) * scales.height);
    transform = CGAffineTransformRotate(transform, rotation);
    CGContextConcatCTM(context, transform);
    
    if (mirrored)
        CGContextScaleCTM(context, -1.0f, 1.0f);
    
    if (!skipImageTransform) {
        [image drawAtPoint:CGPointMake(-image.size.width / 2, -image.size.height / 2)];
    }
    
    if (paintingImage != nil)
    {
        if (mirrored)
            CGContextScaleCTM(context, -1.0f, 1.0f);
                
        [paintingImage drawInRect:CGRectMake(-imageSize.width / 2, -imageSize.height / 2, imageSize.width, imageSize.height)];
    }
    
    UIImage *croppedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return croppedImage;
}

CGSize TGRotatedContentSize(CGSize contentSize, CGFloat rotation)
{
    CGAffineTransform t = CGAffineTransformMakeTranslation(contentSize.width / 2, contentSize.height / 2);
    t = CGAffineTransformRotate(t, rotation);
    t = CGAffineTransformTranslate(t, -contentSize.width / 2, -contentSize.height / 2);
    
    return CGRectApplyAffineTransform(CGRectMake(0, 0, contentSize.width, contentSize.height), t).size;
}

UIImageOrientation TGNextCCWOrientationForOrientation(UIImageOrientation orientation)
{
    switch (orientation)
    {
        case UIImageOrientationUp:
            return UIImageOrientationLeft;
            
        case UIImageOrientationLeft:
            return UIImageOrientationDown;
            
        case UIImageOrientationDown:
            return UIImageOrientationRight;
            
        case UIImageOrientationRight:
            return UIImageOrientationUp;
            
        default:
            break;
    }
    
    return UIImageOrientationUp;
}


UIImageOrientation TGNextCWOrientationForOrientation(UIImageOrientation orientation)
{
    switch (orientation)
    {
        case UIImageOrientationUp:
        return UIImageOrientationRight;
        
        case UIImageOrientationLeft:
        return UIImageOrientationUp;
        
        case UIImageOrientationDown:
        return UIImageOrientationLeft;
        
        case UIImageOrientationRight:
        return UIImageOrientationDown;
        
        default:
        break;
    }
    
    return UIImageOrientationUp;
}

CGFloat TGRotationForOrientation(UIImageOrientation orientation)
{
    switch (orientation)
    {
        case UIImageOrientationDown:
            return (CGFloat)-M_PI;
            
        case UIImageOrientationLeft:
            return (CGFloat)-M_PI_2;
            
        case UIImageOrientationRight:
            return (CGFloat)M_PI_2;
            
        default:
            break;
    }
    
    return 0.0f;
}

CGFloat TGCounterRotationForOrientation(UIImageOrientation orientation)
{
    switch (orientation)
    {
        case UIImageOrientationDown:
            return (CGFloat)-M_PI;
            
        case UIImageOrientationLeft:
            return (CGFloat)M_PI_2;
            
        case UIImageOrientationRight:
            return (CGFloat)-M_PI_2;
            
        default:
            break;
    }
    
    return 0.0f;
}

CGFloat TGRotationForInterfaceOrientation(UIInterfaceOrientation orientation)
{
    switch (orientation)
    {
        case UIInterfaceOrientationPortraitUpsideDown:
            return (CGFloat)-M_PI;
            
        case UIInterfaceOrientationLandscapeLeft:
            return (CGFloat)-M_PI_2;
            
        case UIInterfaceOrientationLandscapeRight:
            return (CGFloat)M_PI_2;
            
        default:
            break;
    }
    
    return 0.0f;
}

CGAffineTransform TGTransformForVideoOrientation(AVCaptureVideoOrientation orientation, bool mirrored)
{
    CGAffineTransform transform = mirrored ? CGAffineTransformMakeRotation((CGFloat)M_PI) : CGAffineTransformIdentity;
    
    switch (orientation)
    {
        case UIDeviceOrientationLandscapeRight:
        {
            transform = mirrored ? CGAffineTransformIdentity : CGAffineTransformMakeRotation((CGFloat)M_PI);
        }
            break;
            
        case UIDeviceOrientationPortrait:
        {
            transform = CGAffineTransformMakeRotation((CGFloat)M_PI_2);
        }
            break;
            
        case UIDeviceOrientationPortraitUpsideDown:
        {
            transform = CGAffineTransformMakeRotation((CGFloat)M_PI_2 * 3);
        }
            break;
            
        default:
            break;
    }
    
    if (mirrored)
        transform = CGAffineTransformScale(transform, 1, -1);
    
    return transform;
}

bool TGOrientationIsSideward(UIImageOrientation orientation, bool *mirrored)
{
    if (orientation == UIImageOrientationLeft || orientation == UIImageOrientationRight)
    {
        if (mirrored != NULL)
            *mirrored = false;
        
        return true;
    }
    else if (orientation == UIImageOrientationLeftMirrored || orientation == UIImageOrientationRightMirrored)
    {
        if (mirrored != NULL)
            *mirrored = true;
        
        return true;
    }
    
    return false;
}

UIImageOrientation TGMirrorSidewardOrientation(UIImageOrientation orientation)
{
    if (orientation == UIImageOrientationLeft)
        orientation = UIImageOrientationRight;
    else if (orientation == UIImageOrientationRight)
        orientation = UIImageOrientationLeft;
    
    return orientation;
}

UIImageOrientation TGVideoOrientationForAsset(AVAsset *asset, bool *mirrored)
{
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    CGAffineTransform t = videoTrack.preferredTransform;
    
    if (t.a == -1 && t.d == -1) {
        return UIImageOrientationLeft;
    } else if (t.a == 1 && t.d == 1)  {
        return UIImageOrientationRight;
    } else if (t.b == -1 && t.c == 1) {
        return UIImageOrientationDown;
    }  else if (t.a == -1 && t.d == 1) {
        if (mirrored != NULL) {
            *mirrored = true;
        }
        return UIImageOrientationLeft;
    } else if (t.a == 1 && t.d == -1)  {
        if (mirrored != NULL) {
            *mirrored = true;
        }
        return UIImageOrientationRight;
    } else {
        if (t.c == 1) {
            if (mirrored != NULL) {
                *mirrored = true;
            }
        }
        return UIImageOrientationUp;
    }
}

UIImageOrientation TGVideoFinalOrientationForOrientation(UIImageOrientation videoOrientation, UIImageOrientation cropOrientation)
{
    switch (videoOrientation)
    {
        case UIImageOrientationUp:
            return cropOrientation;
            
        case UIImageOrientationDown:
        {
            switch (cropOrientation)
            {
                case UIImageOrientationDown:
                    return UIImageOrientationUp;
                    
                case UIImageOrientationLeft:
                    return UIImageOrientationRight;
                    
                case UIImageOrientationRight:
                    return UIImageOrientationLeft;
                    
                default:
                    return videoOrientation;
            }
        }
            break;
            
        case UIImageOrientationLeft:
        {
            switch (cropOrientation)
            {
                case UIImageOrientationDown:
                    return UIImageOrientationRight;
                    
                case UIImageOrientationLeft:
                    return UIImageOrientationDown;
                    
                case UIImageOrientationRight:
                    return UIImageOrientationUp;
                    
                default:
                    return videoOrientation;
            }
        }
            break;
            
        case UIImageOrientationRight:
        {
            switch (cropOrientation)
            {
                case UIImageOrientationDown:
                    return UIImageOrientationLeft;
                    
                case UIImageOrientationLeft:
                    return UIImageOrientationUp;

                case UIImageOrientationRight:
                    return UIImageOrientationDown;

                default:
                    return videoOrientation;
            }
        }
            break;
            
        default:
            return videoOrientation;
    }
}

CGAffineTransform TGVideoTransformForOrientation(UIImageOrientation orientation, CGSize size, CGRect cropRect, bool mirror)
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    if (mirror)
    {
        if (TGOrientationIsSideward(orientation, NULL))
        {
            cropRect.origin.y *= - 1;
            transform = CGAffineTransformTranslate(transform, 0, size.height);
            transform = CGAffineTransformScale(transform, 1.0f, -1.0f);
        }
        else
        {
            cropRect.origin.x = size.height - cropRect.origin.x;
            transform = CGAffineTransformScale(transform, -1.0f, 1.0f);
        }
    }
    
    switch (orientation)
    {
        case UIImageOrientationUp:
        {
            transform = CGAffineTransformRotate(CGAffineTransformTranslate(transform, size.height - cropRect.origin.x, 0 - cropRect.origin.y), (CGFloat)M_PI_2);
        }
            break;
            
        case UIImageOrientationDown:
        {
            transform = CGAffineTransformRotate(CGAffineTransformTranslate(transform, 0 - cropRect.origin.x, size.width - cropRect.origin.y), (CGFloat)-M_PI_2);
        }
            break;
            
        case UIImageOrientationRight:
        {
            transform = CGAffineTransformRotate(CGAffineTransformTranslate(transform, 0 - cropRect.origin.x, 0 - cropRect.origin.y), 0);
        }
            break;
            
        case UIImageOrientationLeft:
        {
            transform = CGAffineTransformRotate(CGAffineTransformTranslate(transform, size.width - cropRect.origin.x, size.height - cropRect.origin.y), (CGFloat)M_PI);
        }
            break;
            
        default:
            break;
    }
    
    return transform;
}

CGAffineTransform TGVideoCropTransformForOrientation(UIImageOrientation orientation, CGSize size, bool rotateSize)
{
    if (rotateSize && TGOrientationIsSideward(orientation, NULL))
        size = CGSizeMake(size.height, size.width);
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    switch (orientation)
    {
        case UIImageOrientationDown:
        {
            transform = CGAffineTransformRotate(CGAffineTransformMakeTranslation(size.width, size.height), (CGFloat)M_PI);
        }
            break;
            
        case UIImageOrientationRight:
        {
            transform = CGAffineTransformRotate(CGAffineTransformMakeTranslation(size.width, 0), (CGFloat)M_PI_2);
        }
            break;
            
        case UIImageOrientationLeft:
        {
            transform = CGAffineTransformRotate(CGAffineTransformMakeTranslation(0, size.height), (CGFloat)-M_PI_2);
        }
            break;
            
        default:
            break;
    }
    
    return transform;
}

CGAffineTransform TGVideoTransformForCrop(UIImageOrientation orientation, CGSize size, bool mirrored)
{
    if (TGOrientationIsSideward(orientation, NULL))
        size = CGSizeMake(size.height, size.width);
    
    CGAffineTransform transform = CGAffineTransformMakeTranslation(size.width / 2.0f, size.height / 2.0f);
    switch (orientation)
    {
        case UIImageOrientationDown:
        {
            transform = CGAffineTransformRotate(transform, M_PI);
        }
            break;
            
        case UIImageOrientationRight:
        {
            transform = CGAffineTransformRotate(transform, M_PI_2);
        }
            break;
            
        case UIImageOrientationLeft:
        {
            transform = CGAffineTransformRotate(transform, -M_PI_2);
        }
            break;
            
        default:
            break;
    }
    
    if (mirrored)
        transform = CGAffineTransformScale(transform, -1.0f, 1.0f);
    
    if (TGOrientationIsSideward(orientation, NULL))
        size = CGSizeMake(size.height, size.width);
    
    transform = CGAffineTransformTranslate(transform, -size.width / 2.0f, -size.height / 2.0f);

    return transform;
}

CGSize TGTransformDimensionsWithTransform(CGSize dimensions, CGAffineTransform transform)
{
    CGRect rect = CGRectMake(0, 0, dimensions.width, dimensions.height);
    rect = CGRectApplyAffineTransform(rect, transform);
    return rect.size;
}

CGFloat TGRubberBandDistance(CGFloat offset, CGFloat dimension)
{
    const CGFloat constant = 0.55f;
    CGFloat result = (constant * ABS(offset) * dimension) / (dimension + constant * ABS(offset));

    return (offset < 0.0f) ? -result : result;
}

bool _CGPointEqualToPointWithEpsilon(CGPoint point1, CGPoint point2, CGFloat epsilon)
{
    CGFloat absEpsilon = ABS(epsilon);
    bool xOK = ABS(point1.x - point2.x) < absEpsilon;
    bool yOK = ABS(point1.y - point2.y) < absEpsilon;
    
    return xOK && yOK;
}

bool _CGRectEqualToRectWithEpsilon(CGRect rect1, CGRect rect2, CGFloat epsilon)
{
    CGFloat absEpsilon = ABS(epsilon);
    bool xOK = ABS(rect1.origin.x - rect2.origin.x) < absEpsilon;
    bool yOK = ABS(rect1.origin.y - rect2.origin.y) < absEpsilon;
    bool wOK = ABS(rect1.size.width - rect2.size.width) < absEpsilon * 2;
    bool hOK = ABS(rect1.size.height - rect2.size.height) < absEpsilon * 2;
    
    return xOK && yOK && wOK && hOK;
}
