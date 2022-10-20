#import "PGPhotoEditorPicture.h"

@interface PGPhotoEditorPicture ()
{
    CGSize _imageSize;
    bool _processed;
    
    dispatch_semaphore_t _updateSemaphore;
}
@end

@implementation PGPhotoEditorPicture

- (instancetype)initWithImage:(UIImage *)image
{
    GPUTextureOptions defaultOptions;
    defaultOptions.minFilter = GL_LINEAR;
    defaultOptions.magFilter = GL_LINEAR;
    defaultOptions.wrapS = GL_CLAMP_TO_EDGE;
    defaultOptions.wrapT = GL_CLAMP_TO_EDGE;
    defaultOptions.internalFormat = GL_RGBA;
    defaultOptions.format = GL_BGRA;
    defaultOptions.type = GL_UNSIGNED_BYTE;
    
    return [self initWithImage:image textureOptions:defaultOptions];
}

- (instancetype)initWithImage:(UIImage *)image textureOptions:(GPUTextureOptions)textureOptions
{
    self = [super init];
    if (self != nil)
    {
        _updateSemaphore = dispatch_semaphore_create(0);
        dispatch_semaphore_signal(_updateSemaphore);
        
        [self setupWithCGImage:image.CGImage orientation:image.imageOrientation textureOptions:textureOptions];
    }
    return self;
}

- (void)setupWithCGImage:(CGImageRef)image orientation:(UIImageOrientation)orientation textureOptions:(GPUTextureOptions)textureOptions
{
    bool redrawNeeded = false;
    
    if (orientation != UIImageOrientationUp)
        redrawNeeded = true;
    
    CGSize imageSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
    if (orientation == UIImageOrientationLeft || orientation == UIImageOrientationRight)
        imageSize = CGSizeMake(imageSize.height, imageSize.width);
    
    CGSize fittedImageSize = [GPUImageContext sizeThatFitsWithinATextureForSize:imageSize];
    if (!CGSizeEqualToSize(fittedImageSize, imageSize))
    {
        imageSize = fittedImageSize;
        redrawNeeded = true;
    }
    
    GLubyte *imageData = NULL;
    CFDataRef dataFromImageDataProvider = NULL;
    GLenum format = GL_BGRA;
    
    if (!redrawNeeded)
    {
        if (CGImageGetBytesPerRow(image) != CGImageGetWidth(image) * 4 ||
            CGImageGetBitsPerPixel(image) != 32 ||
            CGImageGetBitsPerComponent(image) != 8)
        {
            redrawNeeded = true;
        }
        else
        {
            CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(image);
            if ((bitmapInfo & kCGBitmapFloatComponents) != 0)
            {
                redrawNeeded = true;
            }
            else
            {
                CGBitmapInfo byteOrderInfo = bitmapInfo & kCGBitmapByteOrderMask;
                if (byteOrderInfo == kCGBitmapByteOrder32Little)
                {
                    /* Little endian, for alpha-first we can use this bitmap directly in GL */
                    CGImageAlphaInfo alphaInfo = bitmapInfo & kCGBitmapAlphaInfoMask;
                    if (alphaInfo != kCGImageAlphaPremultipliedFirst && alphaInfo != kCGImageAlphaFirst &&
                        alphaInfo != kCGImageAlphaNoneSkipFirst)
                    {
                        redrawNeeded = true;
                    }
                }
                else if (byteOrderInfo == kCGBitmapByteOrderDefault || byteOrderInfo == kCGBitmapByteOrder32Big)
                {
                    /* Big endian, for alpha-last we can use this bitmap directly in GL */
                    CGImageAlphaInfo alphaInfo = bitmapInfo & kCGBitmapAlphaInfoMask;
                    if (alphaInfo != kCGImageAlphaPremultipliedLast && alphaInfo != kCGImageAlphaLast &&
                        alphaInfo != kCGImageAlphaNoneSkipLast)
                    {
                        redrawNeeded = true;
                    } else
                    {
                        /* Can access directly using GL_RGBA pixel format */
                        format = GL_RGBA;
                    }
                }
            }
        }
    }
    
    _imageSize = imageSize;
    
    if (redrawNeeded)
    {
        imageData = (GLubyte *) calloc(1, (int)imageSize.width * (int)imageSize.height * 4);
        
        CGColorSpaceRef genericRGBColorspace = CGColorSpaceCreateDeviceRGB();
        
        CGContextRef imageContext = CGBitmapContextCreate(imageData, (size_t)imageSize.width, (size_t)imageSize.height, 8, (size_t)imageSize.width * 4, genericRGBColorspace,  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);

        CGSize imageDrawSize = CGSizeMake(imageSize.width, imageSize.height);
        if (orientation == UIImageOrientationLeft || orientation == UIImageOrientationRight)
            imageDrawSize = CGSizeMake(imageDrawSize.height, imageDrawSize.width);
        
        CGAffineTransform transform = CGAffineTransformIdentity;
        switch (orientation)
        {
            case UIImageOrientationDown:
            case UIImageOrientationDownMirrored:
                transform = CGAffineTransformTranslate(transform, imageSize.width, imageSize.height);
                transform = CGAffineTransformRotate(transform, (CGFloat)M_PI);
                break;
            
            case UIImageOrientationLeft:
            case UIImageOrientationLeftMirrored:
                transform = CGAffineTransformTranslate(transform, imageSize.width, 0);
                transform = CGAffineTransformRotate(transform, (CGFloat)M_PI_2);
                break;

            case UIImageOrientationRight:
            case UIImageOrientationRightMirrored:
                transform = CGAffineTransformTranslate(transform, 0, imageSize.height);
                transform = CGAffineTransformRotate(transform, (CGFloat)-M_PI_2);
                break;

            default:
                break;
        }
        
        switch (orientation)
        {
            case UIImageOrientationUpMirrored:
            case UIImageOrientationDownMirrored:
                transform = CGAffineTransformTranslate(transform, imageSize.width,0);
                transform = CGAffineTransformScale(transform, -1, 1);
                break;
           
            case UIImageOrientationLeftMirrored:
            case UIImageOrientationRightMirrored:
                transform = CGAffineTransformTranslate(transform, imageSize.height, 0);
                transform = CGAffineTransformScale(transform, -1, 1);
                break;

            default:
                break;
        }
        
        CGContextConcatCTM(imageContext, transform);
        CGContextSetInterpolationQuality(imageContext, kCGInterpolationHigh);
        CGContextDrawImage(imageContext, CGRectMake(0.0f, 0.0f, imageDrawSize.width, imageDrawSize.height), image);
        CGContextRelease(imageContext);
        CGColorSpaceRelease(genericRGBColorspace);
    }
    else
    {
        dataFromImageDataProvider = CGDataProviderCopyData(CGImageGetDataProvider(image));
        imageData = (GLubyte *)CFDataGetBytePtr(dataFromImageDataProvider);
    }
    
    runSynchronouslyOnVideoProcessingQueue(^
    {
        [GPUImageContext useImageProcessingContext];
        
        outputFramebuffer = [[GPUImageContext sharedFramebufferCache] fetchFramebufferForSize:imageSize textureOptions:textureOptions onlyTexture:true];
        [outputFramebuffer disableReferenceCounting];
        
        glBindTexture(GL_TEXTURE_2D, [outputFramebuffer texture]);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)imageSize.width, (int)imageSize.height, 0, format, GL_UNSIGNED_BYTE, imageData);
        
        glBindTexture(GL_TEXTURE_2D, 0);
    });
    
    if (redrawNeeded)
        free(imageData);
    else if (dataFromImageDataProvider)
        CFRelease(dataFromImageDataProvider);
}

- (void)dealloc
{
    [outputFramebuffer enableReferenceCounting];
    [outputFramebuffer unlock];
}

- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation
{
    [super addTarget:newTarget atTextureLocation:textureLocation];
    
    if (_processed)
    {
        [newTarget setInputSize:_imageSize atIndex:textureLocation];
        [newTarget newFrameReadyAtTime:kCMTimeIndefinite atIndex:textureLocation];
    }
}

- (void)removeAllTargets
{
    [super removeAllTargets];
    _processed = false;
}

- (bool)processSynchronous:(bool)synchronous completion:(void (^)(void))completion
{
    _processed = true;
    
    if (dispatch_semaphore_wait(_updateSemaphore, DISPATCH_TIME_NOW) != 0)
        return false;
    
    void (^block)(void) = ^
    {
        for (id<GPUImageInput> currentTarget in targets)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            [currentTarget setCurrentlyReceivingMonochromeInput:false];
            [currentTarget setInputSize:_imageSize atIndex:textureIndexOfTarget];
            [currentTarget setInputFramebuffer:outputFramebuffer atIndex:textureIndexOfTarget];
            [currentTarget newFrameReadyAtTime:kCMTimeIndefinite atIndex:textureIndexOfTarget];
        }
        
        dispatch_semaphore_signal(_updateSemaphore);
        
        if (completion != nil)
            completion();
    };
    
    if (synchronous)
        runSynchronouslyOnVideoProcessingQueue(block);
    else
        runAsynchronouslyOnVideoProcessingQueue(block);
    
    return true;
}

@end
