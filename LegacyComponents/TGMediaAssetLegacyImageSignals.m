#import "TGMediaAssetLegacyImageSignals.h"

#import "LegacyComponentsInternal.h"

#import <AssetsLibrary/AssetsLibrary.h>

#import "TGMediaAsset.h"

@implementation TGMediaAssetLegacyImageSignals

+ (SSignal *)imageForAsset:(TGMediaAsset *)asset imageType:(TGMediaAssetImageType)imageType size:(CGSize)size allowNetworkAccess:(bool)__unused allowNetworkAccess
{
    if (imageType == TGMediaAssetImageTypeFastScreen)
    {
        return [[self imageForAsset:asset imageType:TGMediaAssetImageTypeAspectRatioThumbnail size:CGSizeZero] then:[self imageForAsset:asset imageType:TGMediaAssetImageTypeScreen size:size]];
    }
    
    switch (imageType)
    {
        case TGMediaAssetImageTypeThumbnail:
        {
            return [SSignal single:[UIImage imageWithCGImage:asset.backingLegacyAsset.thumbnail]];
        }
            break;
            
        case TGMediaAssetImageTypeAspectRatioThumbnail:
        {
            return [SSignal single:[UIImage imageWithCGImage:asset.backingLegacyAsset.aspectRatioThumbnail]];
        }
            break;
            
        case TGMediaAssetImageTypeScreen:
        case TGMediaAssetImageTypeFullSize:
        {
            if (imageType == TGMediaAssetImageTypeScreen && asset.isVideo)
                return [SSignal single:[UIImage imageWithCGImage:asset.backingLegacyAsset.defaultRepresentation.fullScreenImage]];
            
            if (imageType == TGMediaAssetImageTypeFullSize)
                size = TGMediaAssetImageLegacySizeLimit;
            
            return [[[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
            {
                ALAssetRepresentation *representation = asset.backingLegacyAsset.defaultRepresentation;
                CGDataProviderDirectCallbacks callbacks =
                {
                    .version = 0,
                    .getBytePointer = NULL,
                    .releaseBytePointer = NULL,
                    .getBytesAtPosition = TGGetAssetBytesCallback,
                    .releaseInfo = TGReleaseAssetCallback,
                };
                
                CGDataProviderRef provider = CGDataProviderCreateDirect((void *)CFBridgingRetain(representation), representation.size, &callbacks);
                CGImageSourceRef source = CGImageSourceCreateWithDataProvider(provider, NULL);
                
                CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)@
                {
                    (NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @(YES),
                    (NSString *)kCGImageSourceThumbnailMaxPixelSize : @((NSInteger)MAX(size.width, size.height)),
                    (NSString *)kCGImageSourceCreateThumbnailWithTransform : @(YES)
                });
                
                if (source != NULL)
                    CFRelease(source);
                
                if (provider != NULL)
                    CFRelease(provider);
                
                NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
                if (imageRef != nil && representation != nil)
                {
                    result[@"imageRef"] = (__bridge id)(imageRef);
                    result[@"representation"] = representation;
                    
                    [subscriber putNext:result];
                    [subscriber putCompletion];
                }
                else
                {
                    [subscriber putError:nil];
                }
                
                return [[SBlockDisposable alloc] initWithBlock:^
                {
                    if (imageRef != NULL)
                        CFRelease(imageRef);
                }];
            }] mapToSignal:^SSignal *(NSDictionary *result)
            {
                return [self _editedImageWithCGImage:(__bridge CGImageRef)(result[@"imageRef"]) representation:result[@"representation"]];
            }] startOn:[self _processingQueue]];
        }
            break;
            
        default:
            break;
    }
    
    return [SSignal fail:nil];
}

+ (SSignal *)livePhotoForAsset:(TGMediaAsset *)asset
{
    return [SSignal fail:nil];
}

+ (SSignal *)imageDataForAsset:(TGMediaAsset *)asset allowNetworkAccess:(bool)__unused allowNetworkAccess
{
    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        ALAssetRepresentation *representation = asset.backingLegacyAsset.defaultRepresentation;
        NSUInteger size = (NSUInteger)representation.size;
        void *bytes = malloc(size);
        for (NSUInteger offset = 0; offset < size; )
        {
            NSError *error = nil;
            offset += [representation getBytes:bytes + offset fromOffset:(long long)offset length:256 * 1024 error:&error];
            if (error != nil)
            {
                [subscriber putError:nil];
                return nil;
            }
        }
        
        NSData *imageData = [[NSData alloc] initWithBytesNoCopy:bytes length:size freeWhenDone:true];
        NSArray *fileNameComponents = [representation.url.absoluteString.lastPathComponent componentsSeparatedByString:@"?"];
        NSString *fileName = fileNameComponents.firstObject;
        
        TGMediaAssetImageData *data = [[TGMediaAssetImageData alloc] init];
        data.fileName = fileName;
        data.fileUTI = representation.UTI;
        data.imageData = imageData;
        
        [subscriber putNext:data];
        [subscriber putCompletion];
        
        return nil;
    }] startOn:[self _processingQueue]];
}

+ (SSignal *)imageMetadataWithAsset:(TGMediaAsset *)asset
{
    return [SSignal single:asset.backingLegacyAsset.defaultRepresentation.metadata];
}

+ (SSignal *)fileAttributesForAsset:(TGMediaAsset *)asset
{
    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        ALAssetRepresentation *representation = asset.backingLegacyAsset.defaultRepresentation;
        NSArray *fileNameComponents = [representation.url.absoluteString.lastPathComponent componentsSeparatedByString:@"?"];
        NSString *fileName = fileNameComponents.firstObject;
        NSString *fileUTI = representation.UTI;
        
        TGMediaAssetImageFileAttributes *attributes = [[TGMediaAssetImageFileAttributes alloc] init];
        attributes.fileName = fileName;
        attributes.fileUTI = fileUTI;
        attributes.dimensions = representation.dimensions;
        attributes.fileSize = (NSUInteger)representation.size;
        
        [subscriber putNext:attributes];
        [subscriber putCompletion];
        
        return nil;
    }] startOn:[self _processingQueue]];
}

+ (void)startCachingImagesForAssets:(NSArray *)__unused assets imageType:(TGMediaAssetImageType)__unused imageType size:(CGSize)__unused size
{

}

+ (void)stopCachingImagesForAssets:(NSArray *)__unused assets imageType:(TGMediaAssetImageType)__unused imageType size:(CGSize)__unused size
{

}

+ (void)stopCachingImagesForAllAssets
{

}

+ (SSignal *)saveUncompressedVideoForAsset:(TGMediaAsset *)asset toPath:(NSString *)path allowNetworkAccess:(bool)__unused allowNetworkAccess
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        NSOutputStream *os = [[NSOutputStream alloc] initToFileAtPath:path append:false];
        [os open];
        
        ALAssetRepresentation *representation = asset.backingLegacyAsset.defaultRepresentation;
        long long size = representation.size;
        
        uint8_t buf[128 * 1024];
        for (long long offset = 0; offset < size; offset += 128 * 1024)
        {
            long long batchSize = MIN(128 * 1024, size - offset);
            NSUInteger readBytes = [representation getBytes:buf fromOffset:offset length:(NSUInteger)batchSize error:nil];
            [os write:buf maxLength:readBytes];
        }
        
        [os close];
        
        NSArray *fileNameComponents = [representation.url.absoluteString.lastPathComponent componentsSeparatedByString:@"?"];
        NSString *fileName = fileNameComponents.firstObject;
        
        [subscriber putNext:fileName];
        [subscriber putCompletion];
        
        return nil;
    }];
}

+ (SSignal *)playerItemForVideoAsset:(TGMediaAsset *)asset
{
    return [SSignal single:[AVPlayerItem playerItemWithURL:asset.url]];
}

+ (SSignal *)avAssetForVideoAsset:(TGMediaAsset *)asset allowNetworkAccess:(bool)__unused allowNetworkAccess
{
    return [SSignal single:[[AVURLAsset alloc] initWithURL:asset.url options:nil]];
}

+ (bool)usesPhotoFramework
{
    return false;
}

+ (SSignal *)_editedImageWithCGImage:(CGImageRef)cgImage representation:(ALAssetRepresentation *)representation
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        NSError *error = nil;
        CGSize originalImageSize = CGSizeMake([representation.metadata[@"PixelWidth"] floatValue], [representation.metadata[@"PixelHeight"] floatValue]);
        
        NSData *xmpData = [representation.metadata[@"AdjustmentXMP"] dataUsingEncoding:NSUTF8StringEncoding];
        
        CIContext *context = [CIContext contextWithOptions:nil];
        
        CIImage *ciImage = [CIImage imageWithCGImage:cgImage];
        NSArray *filterArray = [CIFilter filterArrayFromSerializedXMP:xmpData inputImageExtent:ciImage.extent error:&error];
        if ((originalImageSize.width != CGImageGetWidth(cgImage)) || (originalImageSize.height != CGImageGetHeight(cgImage)))
        {
            CGFloat zoom = MIN(originalImageSize.width / CGImageGetWidth(cgImage), originalImageSize.height / CGImageGetHeight(cgImage));
            
            bool hasTranslation = false;
            bool hasCrop = false;
            
            for (CIFilter *filter in filterArray)
            {
                if ([filter.name isEqualToString:@"CIAffineTransform"] && !hasTranslation)
                {
                    hasTranslation = true;
                    CGAffineTransform t = [[filter valueForKey:@"inputTransform"] CGAffineTransformValue];
                    t.tx /= zoom;
                    t.ty /= zoom;
                    [filter setValue:[NSValue valueWithCGAffineTransform:t] forKey:@"inputTransform"];
                }
                
                if ([filter.name isEqualToString:@"CICrop"] && !hasCrop)
                {
                    hasCrop = true;
                    CGRect r = [[filter valueForKey:@"inputRectangle"] CGRectValue];
                    r.origin.x /= zoom;
                    r.origin.y /= zoom;
                    r.size.width /= zoom;
                    r.size.height /= zoom;
                    [filter setValue:[NSValue valueWithCGRect:r] forKey:@"inputRectangle"];
                }
            }
        }
        
        for (CIFilter *filter in filterArray)
        {
            [filter setValue:ciImage forKey:kCIInputImageKey];
            ciImage = [filter outputImage];
        }
        
        CGImageRef editedImage = [context createCGImage:ciImage fromRect:ciImage.extent];
        UIImage *resultImage = [UIImage imageWithCGImage:editedImage];
        CGImageRelease(editedImage);
        
        if (error == nil)
        {
            [subscriber putNext:resultImage];
            [subscriber putCompletion];
        }
        else
        {
            [subscriber putError:error];
        }
        
        return nil;
    }];
}

+ (SQueue *)_processingQueue
{
    static dispatch_once_t onceToken;
    static SQueue *queue;
    dispatch_once(&onceToken, ^
    {
        queue = [[SQueue alloc] init];
    });
    return queue;
}

static size_t TGGetAssetBytesCallback(void *info, void *buffer, off_t position, size_t count)
{
    ALAssetRepresentation *rep = (__bridge id)info;
    
    NSError *error = nil;
    size_t countRead = [rep getBytes:(uint8_t *)buffer fromOffset:position length:count error:&error];
    
    if (countRead == 0 && error)
        TGLegacyLog(@"error occured while reading an asset: %@", error);
    
    return countRead;
}

static void TGReleaseAssetCallback(void *info)
{
    CFRelease(info);
}

@end
