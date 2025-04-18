#import "TGImageUtils.h"

#import "LegacyComponentsInternal.h"

#import <Accelerate/Accelerate.h>
#import <CommonCrypto/CommonCrypto.h>

#import <os/lock.h>
#import <map>

#import <objc/runtime.h>

static bool retinaInitialized = false;
static bool isRetina()
{
    static bool retina = false;
    if (!retinaInitialized)
    {
        retina = [[UIScreen mainScreen] scale] > 1.9f;
        retinaInitialized = true;
    }
    return retina;
}

static void addRoundedRectToPath(CGContextRef context, CGRect rect, float ovalWidth, float ovalHeight)
{
    CGFloat fw, fh;
    if (ovalWidth == 0 || ovalHeight == 0)
    {
        CGContextAddRect(context, rect);
        return;
    }
    CGContextSaveGState(context);
    CGContextTranslateCTM (context, CGRectGetMinX(rect), CGRectGetMinY(rect));
    CGContextScaleCTM (context, ovalWidth, ovalHeight);
    fw = CGRectGetWidth (rect) / ovalWidth;
    fh = CGRectGetHeight (rect) / ovalHeight;
    CGContextMoveToPoint(context, fw, fh/2);
    CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);
    CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1);
    CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1);
    CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1);
    CGContextClosePath(context);
    CGContextRestoreGState(context);
}

UIImage *TGScaleImage(UIImage *image, CGSize size)
{
    return TGScaleAndRoundCornersWithOffset(image, size, CGPointZero, size, 0, nil, true, nil);
}

UIImage *TGScaleAndRoundCorners(UIImage *image, CGSize size, CGSize imageSize, int radius, UIImage *overlay, bool opaque, UIColor *backgroundColor)
{
    return TGScaleAndRoundCornersWithOffset(image, size, CGPointZero, imageSize, radius, overlay, opaque, backgroundColor);
}

UIImage *TGScaleAndRoundCornersWithOffset(UIImage *image, CGSize size, CGPoint offset, CGSize imageSize, int radius, UIImage *overlay, bool opaque, UIColor *backgroundColor)
{
    return TGScaleAndRoundCornersWithOffsetAndFlags(image, size, offset, imageSize, radius, overlay, opaque, backgroundColor, 0);
}

UIImage *TGScaleAndRoundCornersWithOffsetAndFlags(UIImage *image, CGSize size, CGPoint offset, CGSize imageSize, int radius, UIImage *overlay, bool opaque, UIColor *backgroundColor, int flags)
{
    if (CGSizeEqualToSize(imageSize, CGSizeZero))
        imageSize = size;
    
    CGFloat scale = 1.0f;
    if (isRetina())
    {
        scale = TGScreenScaling(); //2.0f;
        size.width *= scale;
        size.height *= scale;
        imageSize.width *= scale;
        imageSize.height *= scale;
        radius *= scale;
    }
    
    UIGraphicsBeginImageContextWithOptions(imageSize, opaque, 1.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //if (flags & TGScaleImageScaleSharper)
    //    CGContextSetInterpolationQuality(context, kCGInterpolationLow);
    
    if (overlay != nil)
        CGContextSaveGState(context);
    
    if (backgroundColor != nil)
    {
        CGContextSetFillColorWithColor(context, backgroundColor.CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, imageSize.width, imageSize.height));
    }
    else if (opaque)
    {
        static UIColor *whiteColor = nil;
        if (whiteColor == nil)
            whiteColor = [UIColor whiteColor];
        CGContextSetFillColorWithColor(context, whiteColor.CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, imageSize.width, imageSize.height));
    }
    
    if (radius > 0)
    {
        CGContextBeginPath(context);
        CGRect rect = (flags & TGScaleImageRoundCornersByOuterBounds) ? CGRectMake(offset.x * scale, offset.y * scale, imageSize.width, imageSize.height) : CGRectMake(offset.x * scale, offset.y * scale, size.width, size.height);
        addRoundedRectToPath(context, rect, radius, radius);
        CGContextClosePath(context);
        CGContextClip(context);
    }
    
    CGPoint actualOffset = CGPointEqualToPoint(offset, CGPointZero) ? CGPointMake((int)((imageSize.width - size.width) / 2), (int)((imageSize.height - size.height) / 2)) : CGPointMake(offset.x * scale, offset.y * scale);
    if (flags & TGScaleImageFlipVerical)
    {
        CGContextTranslateCTM(context, actualOffset.x + size.width / 2, actualOffset.y + size.height / 2);
        CGContextScaleCTM(context, 1.0f, -1.0f);
        CGContextTranslateCTM(context, -actualOffset.x - size.width / 2, -actualOffset.y - size.height / 2);
    }
    [image drawInRect:CGRectMake(actualOffset.x, actualOffset.y, size.width, size.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    
    if (overlay != nil)
    {
        CGContextRestoreGState(context);
        
        if (flags & TGScaleImageScaleOverlay)
        {
            CGContextScaleCTM(context, scale, scale);
            [overlay drawInRect:CGRectMake(0, 0, imageSize.width / scale, imageSize.height / scale)];
        }
        else
        {
            [overlay drawInRect:CGRectMake(0, 0, overlay.size.width * scale, overlay.size.height * scale)];
        }
    }
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

UIImage *TGScaleAndBlurImage(NSData *data, __unused CGSize size, __autoreleasing NSData **blurredData)
{
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    UIImage *image = [[UIImage alloc] initWithData:data];
    //image = TGScaleImageToPixelSize(image, CGSizeMake(128, 128));
    
    float blur = 0.05f;
    int boxSize = (int)(blur * 100);
    boxSize = boxSize - (boxSize % 2) + 1;
    
    CGImageRef img = image.CGImage;
    
    vImage_Buffer inBuffer, outBuffer;
    vImage_Error error;
    
    void *pixelBuffer = NULL;
    
    CGDataProviderRef inProvider = CGImageGetDataProvider(img);
    CFDataRef inBitmapData = CGDataProviderCopyData(inProvider);
    
    inBuffer.width = CGImageGetWidth(img);
    inBuffer.height = CGImageGetHeight(img);
    inBuffer.rowBytes = CGImageGetBytesPerRow(img);
    
    inBuffer.data = (void*)CFDataGetBytePtr(inBitmapData);
    
    pixelBuffer = malloc(CGImageGetBytesPerRow(img) *
                         CGImageGetHeight(img));
    
    if(pixelBuffer == NULL)
        NSLog(@"No pixelbuffer");
    
    outBuffer.data = pixelBuffer;
    outBuffer.width = CGImageGetWidth(img);
    outBuffer.height = CGImageGetHeight(img);
    outBuffer.rowBytes = CGImageGetBytesPerRow(img);
    
    error = vImageBoxConvolve_ARGB8888(&inBuffer,
                                       &outBuffer,
                                       NULL,
                                       0,
                                       0,
                                       boxSize,
                                       boxSize,
                                       NULL,
                                       kvImageEdgeExtend);
    
    error = vImageBoxConvolve_ARGB8888(&outBuffer,
                                       &inBuffer,
                                       NULL,
                                       0,
                                       0,
                                       boxSize,
                                       boxSize,
                                       NULL,
                                       kvImageEdgeExtend);
    
    
    if (error) {
        NSLog(@"error from convolution %ld", error);
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(
                                             inBuffer.data,
                                             inBuffer.width,
                                             inBuffer.height,
                                             8,
                                             inBuffer.rowBytes,
                                             colorSpace,
                                             kCGImageAlphaNoneSkipLast);
    CGImageRef imageRef = CGBitmapContextCreateImage (ctx);
    UIImage *returnImage = [UIImage imageWithCGImage:imageRef];
    
    //clean up
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    
    free(pixelBuffer);
    CFRelease(inBitmapData);
    
    CGImageRelease(imageRef);
    
    if (blurredData != NULL)
        *blurredData = UIImageJPEGRepresentation(returnImage, 0.6f);
    
    TGLegacyLog(@"Blur time: %f ms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0);
    
    return returnImage;
}

UIImage *TGScaleImageToPixelSize(UIImage *image, CGSize size)
{
    UIGraphicsBeginImageContextWithOptions(size, true, 1.0f);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

UIImage *TGRotateAndScaleImageToPixelSize(UIImage *image, CGSize size)
{
    UIGraphicsBeginImageContextWithOptions(size, true, 1.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextTranslateCTM(context, size.height / 2, size.width / 2);
    CGContextRotateCTM(context, -(float)M_PI_2);
    CGContextTranslateCTM(context, -size.height / 2 + (size.width - size.height) / 2, -size.width / 2 + (size.width - size.height) / 2);
    
    CGContextScaleCTM (context, size.width / image.size.height, size.height / image.size.width);
    
    [image drawAtPoint:CGPointMake(0, 0) blendMode:kCGBlendModeCopy alpha:1.0f];
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

UIImage *TGFixOrientationAndCrop(UIImage *source, CGRect cropFrame, CGSize imageSize)
{
    /*float scale = 1.0f;
    if (isRetina())
    {
        scale = 2.0f;
        imageSize.width *= 2;
        imageSize.height *= 2;
    }*/
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(imageSize.width, imageSize.height), true, 1.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGSize sourceSize = source.size;
    CGFloat sourceScale = source.scale;
    sourceSize.width *= sourceScale;
    sourceSize.height *= sourceScale;
    
    CGContextScaleCTM (context, imageSize.width / cropFrame.size.width, imageSize.height / cropFrame.size.height);
    [source drawAtPoint:CGPointMake(-cropFrame.origin.x, -cropFrame.origin.y) blendMode:kCGBlendModeCopy alpha:1.0f];
    //[source drawInRect:CGRectMake(-cropFrame.origin.x, -cropFrame.origin.y, sourceSize.width, sourceSize.height) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIImage *croppedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return croppedImage;
}

UIImage *TGRotateAndCrop(UIImage *source, CGRect cropFrame, CGSize imageSize)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(imageSize.width, imageSize.height), true, 1.0f);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextTranslateCTM(context, imageSize.width / 2, imageSize.height / 2);
    CGContextRotateCTM(context, (float)M_PI_2);
    CGContextTranslateCTM(context, -imageSize.width / 2, -imageSize.height / 2);
    
    CGContextScaleCTM (context, imageSize.width / cropFrame.size.width, imageSize.height / cropFrame.size.height);
    
    [source drawAtPoint:CGPointMake(-cropFrame.origin.x, -cropFrame.origin.y) blendMode:kCGBlendModeCopy alpha:1.0f];
    UIImage *croppedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return croppedImage;
}

static int32_t get_bits(uint8_t const *bytes, unsigned int bitOffset, unsigned int numBits)
{
    uint8_t const *data = bytes;
    numBits = (unsigned int)pow(2, numBits) - 1; //this will only work up to 32 bits, of course
    data += bitOffset / 8;
    bitOffset %= 8;
    return (*((int*)data) >> bitOffset) & numBits;
}

UIImage *TGIdenticonImage(NSData *data, NSData *additionalData, CGSize size)
{
    uint8_t bits[128];
    memset(bits, 0, 128);
    
    uint8_t additionalBits[256 * 8];
    memset(additionalBits, 0, 256 * 8);
    
    [data getBytes:bits length:MIN((NSUInteger)128, data.length)];
    [additionalData getBytes:additionalBits length:MIN((NSUInteger)256, additionalData.length)];
    
    static CGColorRef colors[6];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        static const int textColors[] =
        {
            0xffffff,
            0xd5e6f3,
            0x2d5775,
            0x2f99c9
        };
        
        for (int i = 0; i < 4; i++)
        {
            colors[i] = CGColorRetain(UIColorRGB(textColors[i]).CGColor);
        }
    });
    
    UIGraphicsBeginImageContextWithOptions(size, true, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, colors[0]);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    
    if (additionalData == nil) {
        int bitPointer = 0;
        
        CGFloat rectSize = size.width / 8.0f;
        
        for (int iy = 0; iy < 8; iy++)
        {
            for (int ix = 0; ix < 8; ix++)
            {
                int32_t byteValue = get_bits(bits, bitPointer, 2);
                bitPointer += 2;
                int colorIndex = ABS(byteValue) % 4;
                
                CGContextSetFillColorWithColor(context, colors[colorIndex]);
                
                CGRect rect = CGRectMake(ix * rectSize, iy * rectSize, rectSize, rectSize);
                if (size.width > 200) {
                    rect.origin.x = CGCeil(rect.origin.x);
                    rect.origin.y = CGCeil(rect.origin.y);
                    rect.size.width = CGCeil(rect.size.width);
                    rect.size.height = CGCeil(rect.size.height);
                }
                CGContextFillRect(context, rect);
            }
        }
    } else {
        int bitPointer = 0;
        
        CGFloat rectSize = size.width / 12.0f;
        
        for (int iy = 0; iy < 12; iy++)
        {
            for (int ix = 0; ix < 12; ix++)
            {
                int32_t byteValue = 0;
                if (bitPointer < 128) {
                    byteValue = get_bits(bits, bitPointer, 2);
                } else {
                    byteValue = get_bits(additionalBits, bitPointer - 128, 2);
                }
                bitPointer += 2;
                int colorIndex = ABS(byteValue) % 4;
                
                CGContextSetFillColorWithColor(context, colors[colorIndex]);
                
                CGRect rect = CGRectMake(ix * rectSize, iy * rectSize, rectSize, rectSize);
                if (size.width > 200) {
                    rect.origin.x = CGCeil(rect.origin.x);
                    rect.origin.y = CGCeil(rect.origin.y);
                    rect.size.width = CGCeil(rect.size.width);
                    rect.size.height = CGCeil(rect.size.height);
                }
                CGContextFillRect(context, rect);
            }
        }
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

UIImage *TGCircleImage(CGFloat radius, UIColor *color)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(radius, radius), false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, radius, radius));
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

UIImage *TGImageNamed(NSString *name)
{
    if (iosMajorVersion() >= 8)
        return [UIImage imageNamed:name inBundle:nil compatibleWithTraitCollection:nil];
    else
        return [UIImage imageNamed:name];
}

UIImage *TGTintedImage(UIImage *image, UIColor *color)
{
    if (image == nil)
        return nil;
    
    UIGraphicsBeginImageContextWithOptions(image.size, false, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    CGContextSetBlendMode (context, kCGBlendModeSourceAtop);
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, CGRectMake(0, 0, image.size.width, image.size.height));
    
    UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return tintedImage;
}

UIImage *TGTintedWithAlphaImage(UIImage *image, UIColor *color)
{
    CGFloat alpha = 1.0f;
    if (![color getRed:nil green:nil blue:nil alpha:&alpha])
        [color getWhite:nil alpha:&alpha];
    
    UIImage *tintedImage = TGTintedImage(image, [color colorWithAlphaComponent:1.0f]);
    if (alpha > 1.0f - FLT_EPSILON)
    {
        return tintedImage;
    }
    else
    {
        UIGraphicsBeginImageContextWithOptions(tintedImage.size, false, 0.0f);
        [tintedImage drawAtPoint:CGPointZero blendMode:kCGBlendModeNormal alpha:alpha];
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return image;
    }
}

NSString *TGImageHash(NSData *data)
{    
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    CC_MD5_Update(&md5, [data bytes], (CC_LONG)data.length);
    
    unsigned char md5Buffer[16];
    CC_MD5_Final(md5Buffer, &md5);
    NSString *hash = [[NSString alloc] initWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5Buffer[0], md5Buffer[1], md5Buffer[2], md5Buffer[3], md5Buffer[4], md5Buffer[5], md5Buffer[6], md5Buffer[7], md5Buffer[8], md5Buffer[9], md5Buffer[10], md5Buffer[11], md5Buffer[12], md5Buffer[13], md5Buffer[14], md5Buffer[15]];
    
    return hash;
}

@implementation UIImage (Preloading)

- (UIImage *)preloadedImage
{
    UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale);
    [self drawInRect:CGRectMake(0, 0, self.size.width, self.size.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (UIImage *)preloadedImageWithAlpha {
    UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale);
    [self drawInRect:CGRectMake(0, 0, self.size.width, self.size.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (void)tgPreload
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), true, 0);
    [self drawAtPoint:CGPointZero];
    UIGraphicsEndImageContext();
}

static const char *mediumImageKey = "mediumImage";

- (void)setMediumImage:(UIImage *)image
{
    objc_setAssociatedObject(self, mediumImageKey, image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIImage *)mediumImage
{
    return (UIImage *)objc_getAssociatedObject(self, mediumImageKey);
}

- (CGSize)screenSize
{
    float scale = TGIsRetina() ? 2.0f : 1.0f;
    if (ABS(self.scale - 1.0) < FLT_EPSILON)
        return CGSizeMake(self.size.width / scale, self.size.height / scale);
    return self.size;
}

- (CGSize)pixelSize
{
    return CGSizeMake(self.size.width * self.scale, self.size.height * self.scale);
}

@end

CGSize TGFitSize(CGSize size, CGSize maxSize)
{
    if (size.width < 1)
        size.width = 1;
    if (size.height < 1)
        size.height = 1;
        
    if (size.width > maxSize.width)
    {
        size.height = CGFloor((size.height * maxSize.width / size.width));
        size.width = maxSize.width;
    }
    if (size.height > maxSize.height)
    {
        size.width = CGFloor((size.width * maxSize.height / size.height));
        size.height = maxSize.height;
    }
    return size;
}

CGSize TGFitSizeF(CGSize size, CGSize maxSize)
{
    if (size.width < 1)
        size.width = 1;
    if (size.height < 1)
        size.height = 1;
    
    if (size.width > maxSize.width)
    {
        size.height = (size.height * maxSize.width / size.width);
        size.width = maxSize.width;
    }
    if (size.height > maxSize.height)
    {
        size.width = (size.width * maxSize.height / size.height);
        size.height = maxSize.height;
    }
    return size;
}

CGSize TGFillSize(CGSize size, CGSize maxSize)
{
    if (size.width < 1)
        size.width = 1;
    if (size.height < 1)
        size.height = 1;
    
    if (/*size.width >= size.height && */size.width < maxSize.width)
    {
        size.height = CGFloor(maxSize.width * size.height / MAX(1.0f, size.width));
        size.width = maxSize.width;
    }
    
    if (/*size.width <= size.height &&*/ size.height < maxSize.height)
    {
        size.width = CGFloor(maxSize.height * size.width / MAX(1.0f, size.height));
        size.height = maxSize.height;
    }
    
    return size;
}

CGSize TGFillSizeF(CGSize size, CGSize maxSize)
{
    if (size.width < 1)
        size.width = 1;
    if (size.height < 1)
        size.height = 1;
    
    if (/*size.width >= size.height && */size.width < maxSize.width)
    {
        size.height = maxSize.width * size.height / MAX(1.0f, size.width);
        size.width = maxSize.width;
    }
    
    if (/*size.width <= size.height &&*/ size.height < maxSize.height)
    {
        size.width = maxSize.height * size.width / MAX(1.0f, size.height);
        size.height = maxSize.height;
    }
    
    return size;
}

CGSize TGCropSize(CGSize size, CGSize maxSize)
{
    if (size.width < 1)
        size.width = 1;
    if (size.height < 1)
        size.height = 1;
    
    return CGSizeMake(MIN(size.width, maxSize.width), MIN(size.height, maxSize.height));
}

CGSize TGScaleToFill(CGSize size, CGSize boundsSize)
{
    if (size.width < 1.0f || size.height < 1.0f)
        return CGSizeMake(1.0f, 1.0f);
    
    CGFloat scale = MAX(boundsSize.width / size.width, boundsSize.height / size.height);
    return CGSizeMake(CGRound(size.width * scale), CGRound(size.height * scale));
}

CGSize TGScaleToFit(CGSize size, CGSize boundsSize)
{
    if (size.width < 1.0f || size.height < 1.0f)
        return CGSizeMake(1.0f, 1.0f);
    
    CGFloat scale = MIN(boundsSize.width / size.width, boundsSize.height / size.height);
    return CGSizeMake(CGFloor(size.width * scale), CGFloor(size.height * scale));
}

CGFloat TGRetinaPixel = 0.5f;
CGFloat TGScreenPixel = 0.5f;

CGFloat TGRetinaFloor(CGFloat value)
{
    return TGIsRetina() ? (CGFloor(value * 2.0f)) / 2.0f : CGFloor(value);
}

CGFloat TGRetinaCeil(CGFloat value)
{
    return TGIsRetina() ? (CGCeil(value * 2.0f)) / 2.0f : CGCeil(value);
}

CGFloat TGScreenPixelFloor(CGFloat value)
{
    static CGFloat scale = 2.0f;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        scale = [UIScreen mainScreen].scale;
    });
    return CGFloor(value * scale) / scale;
}

bool TGIsRetina()
{
    static bool value = true;
    static bool initialized = false;
    if (!initialized)
    {
        value = [[UIScreen mainScreen] scale] > 1.5f;
        initialized = true;
        
        TGRetinaPixel = value ? 0.5f : 0.0f;
        TGScreenPixel = 1.0f / [[UIScreen mainScreen] scale];
    }
    return value;
}

CGFloat TGScreenScaling()
{
    static CGFloat value = 2.0f;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        value = [UIScreen mainScreen].scale;
    });
    
    return value;
}

CGFloat TGSeparatorHeight()
{
    static CGFloat value = 1.0f;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGFloat scale = TGScreenScaling();
        if (fabs(scale - 2.0f) < FLT_EPSILON)
            value = 0.5f;
        else if (fabs(scale - 3.0f) < FLT_EPSILON)
            value = 0.33f;
    });
    
    return value;
}


bool TGIsPad()
{
    static bool value = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        value = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
    });
    
    return value;
}

CGSize TGScreenSize()
{
    static CGSize size;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIScreen *screen = [UIScreen mainScreen];
        
        if ([screen respondsToSelector:@selector(fixedCoordinateSpace)])
            size = [screen.coordinateSpace convertRect:screen.bounds toCoordinateSpace:screen.fixedCoordinateSpace].size;
        else
            size = screen.bounds.size;
    });
    
    return size;
}

CGSize TGNativeScreenSize()
{
    static CGSize size;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIScreen *screen = [UIScreen mainScreen];
        
        if ([screen respondsToSelector:@selector(nativeBounds)])
            size = [screen.coordinateSpace convertRect:screen.nativeBounds toCoordinateSpace:screen.fixedCoordinateSpace].size;
        else
            size = TGScreenSize();
    });
    
    return size;
}

uint32_t TGColorHexCode(UIColor *color)
{
    CGFloat red, green, blue, alpha;
    if (![color getRed:&red green:&green blue:&blue alpha:&alpha]) {
        if (![color getWhite:&red alpha:&alpha]) {
            return 0;
        }
        green = red;
        blue = red;
    }
    
    uint32_t redInt = (uint32_t)(red * 255 + 0.5);
    uint32_t greenInt = (uint32_t)(green * 255 + 0.5);
    uint32_t blueInt = (uint32_t)(blue * 255 + 0.5);
    
    return (redInt << 16) | (greenInt << 8) | blueInt;
}

uint32_t TGColorHexCodeWithAlpha(UIColor *color)
{
    CGFloat red, green, blue, alpha;
    if ([color getRed:&red green:&green blue:&blue alpha:&alpha])
    {
        uint32_t redInt = (uint32_t)(red * 255 + 0.5);
        uint32_t greenInt = (uint32_t)(green * 255 + 0.5);
        uint32_t blueInt = (uint32_t)(blue * 255 + 0.5);
        uint32_t alphaInt = (uint32_t)(alpha * 255 + 0.5);
        
        return (alphaInt << 24) | (redInt << 16) | (greenInt << 8) | blueInt;
    }
    
    return 0;
}

NSData *TGJPEGRepresentation(UIImage *image, CGFloat compressionRate)
{
    if (image.CGImage == nil)
        return nil;
    
    NSMutableData *data = [[NSMutableData alloc] init];
    
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, (__bridge CFStringRef)@"public.jpeg", 1, NULL);
    if (destination == NULL)
        return nil;
    
    NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
    [properties setObject:@(compressionRate) forKey:(__bridge NSString *)kCGImageDestinationLossyCompressionQuality];
    
    CGImageDestinationAddImage(destination, image.CGImage, (__bridge CFDictionaryRef)properties);
    CGImageDestinationFinalize(destination);
    
    CFRelease(destination);
    
    if (data.length == 0)
        return nil;
    
    return data;
}

bool TGWriteJPEGRepresentationToFile(UIImage *image, CGFloat compressionRate, NSString *filePath)
{
    if (image.CGImage == nil)
        return false;
    
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:filePath], (__bridge CFStringRef)@"public.jpeg", 1, NULL);
    if (destination == NULL)
        return false;
    
    NSMutableDictionary *properties = [[NSMutableDictionary alloc] init];
    [properties setObject:@(compressionRate) forKey:(__bridge NSString *)kCGImageDestinationLossyCompressionQuality];
    
    CGImageDestinationAddImage(destination, image.CGImage, (__bridge CFDictionaryRef)properties);
    bool succeed = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    
    return succeed;
}


static bool readCGFloat(NSString *string, int &position, CGFloat &result) {
    int start = position;
    bool seenDot = false;
    int length = (int)string.length;
    while (position < length) {
        unichar c = [string characterAtIndex:position];
        position++;
        
        if (c == '.') {
            if (seenDot) {
                return false;
            } else {
                seenDot = true;
            }
        } else if ((c < '0' || c > '9') && c != '-') {
            if (position == start) {
                result = 0.0f;
                return true;
            } else {
                result = [[string substringWithRange:NSMakeRange(start, position - start)] floatValue];
                return true;
            }
        }
    }
    if (position == start) {
        result = 0.0f;
        return true;
    } else {
        result = [[string substringWithRange:NSMakeRange(start, position - start)] floatValue];
        return true;
    }
    return true;
}

void TGDrawSvgPath(CGContextRef context, NSString *path) {
    int position = 0;
    int length = (int)path.length;
    
    while (position < length) {
        unichar c = [path characterAtIndex:position];
        position++;
        
        if (c == ' ') {
            continue;
        }
        
        if (c == 'M') { // M
            CGFloat x = 0.0f;
            CGFloat y = 0.0f;
            readCGFloat(path, position, x);
            readCGFloat(path, position, y);
            CGContextMoveToPoint(context, x, y);
        } else if (c == 'L') { // L
            CGFloat x = 0.0f;
            CGFloat y = 0.0f;
            readCGFloat(path, position, x);
            readCGFloat(path, position, y);
            CGContextAddLineToPoint(context, x, y);
        } else if (c == 'C') { // C
            CGFloat x1 = 0.0f;
            CGFloat y1 = 0.0f;
            CGFloat x2 = 0.0f;
            CGFloat y2 = 0.0f;
            CGFloat x = 0.0f;
            CGFloat y = 0.0f;
            readCGFloat(path, position, x1);
            readCGFloat(path, position, y1);
            readCGFloat(path, position, x2);
            readCGFloat(path, position, y2);
            readCGFloat(path, position, x);
            readCGFloat(path, position, y);
            
            CGContextAddCurveToPoint(context, x1, y1, x2, y2, x, y);
        } else if (c == 'Z') { // Z
            CGContextClosePath(context);
            CGContextFillPath(context);
            CGContextBeginPath(context);
        } else if (c == 'S') { // Z
            CGContextClosePath(context);
            CGContextStrokePath(context);
            CGContextBeginPath(context);
        } else if (c == 'U') { // Z
            CGContextStrokePath(context);
            CGContextBeginPath(context);
        }
    }
}

@implementation TGImageBorderPallete

+ (instancetype)palleteWithBorderColor:(UIColor *)borderColor shadowColor:(UIColor *)shadowColor
{
    TGImageBorderPallete *pallete = [[TGImageBorderPallete alloc] init];
    pallete->_borderColor = borderColor;
    pallete->_shadowColor = shadowColor;
    return pallete;
}

@end
