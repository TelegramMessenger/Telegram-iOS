#import "TGMediaAssetImageSignals.h"

#import <Photos/Photos.h>

#import "TGMediaAssetModernImageSignals.h"

#import "TGPhotoEditorUtils.h"

#import "TGMediaAssetsLibrary.h"

const CGSize TGMediaAssetImageLegacySizeLimit = { 2048, 2048 };

@implementation TGMediaAssetImageData

@end

@implementation TGMediaAssetImageFileAttributes

@end


@implementation TGMediaAssetImageSignals

static Class TGMediaAssetImageSignalsClass = nil;

+ (void)load
{
    TGMediaAssetImageSignalsClass = [TGMediaAssetModernImageSignals class];
}

+ (SSignal *)imageForAsset:(TGMediaAsset *)asset imageType:(TGMediaAssetImageType)imageType size:(CGSize)size
{
    return [self imageForAsset:asset imageType:imageType size:size allowNetworkAccess:true];
}

+ (SSignal *)imageForAsset:(TGMediaAsset *)asset imageType:(TGMediaAssetImageType)imageType size:(CGSize)size allowNetworkAccess:(bool)allowNetworkAccess
{
    return [TGMediaAssetImageSignalsClass imageForAsset:asset imageType:imageType size:size allowNetworkAccess:allowNetworkAccess];
}

+ (SSignal *)livePhotoForAsset:(TGMediaAsset *)asset
{
    return [self livePhotoForAsset:asset allowNetworkAccess:true];
}

+ (SSignal *)livePhotoForAsset:(TGMediaAsset *)asset allowNetworkAccess:(bool)allowNetworkAccess
{
    return [TGMediaAssetImageSignalsClass livePhotoForAsset:asset allowNetworkAccess:allowNetworkAccess];
}

+ (SSignal *)imageDataForAsset:(TGMediaAsset *)asset
{
    return [self imageDataForAsset:asset allowNetworkAccess:true];
}

+ (SSignal *)imageDataForAsset:(TGMediaAsset *)asset allowNetworkAccess:(bool)allowNetworkAccess
{
    return [TGMediaAssetImageSignalsClass imageDataForAsset:asset allowNetworkAccess:allowNetworkAccess];
}

+ (SSignal *)imageDataForAsset:(TGMediaAsset *)asset allowNetworkAccess:(bool)allowNetworkAccess convertToJpeg:(bool)convertToJpeg
{
    return [TGMediaAssetImageSignalsClass imageDataForAsset:asset allowNetworkAccess:allowNetworkAccess convertToJpeg:convertToJpeg];
}

+ (SSignal *)imageMetadataForAsset:(TGMediaAsset *)asset
{
    return [TGMediaAssetImageSignalsClass imageMetadataForAsset:asset];
}

+ (SSignal *)fileAttributesForAsset:(TGMediaAsset *)asset
{
    return [TGMediaAssetImageSignalsClass fileAttributesForAsset:asset];
}

+ (void)startCachingImagesForAssets:(NSArray *)assets imageType:(TGMediaAssetImageType)imageType size:(CGSize)size
{
    return [TGMediaAssetImageSignalsClass startCachingImagesForAssets:assets imageType:imageType size:size];
}

+ (void)stopCachingImagesForAssets:(NSArray *)assets imageType:(TGMediaAssetImageType)imageType size:(CGSize)size
{
    return [TGMediaAssetImageSignalsClass stopCachingImagesForAssets:assets imageType:imageType size:size];
}

+ (void)stopCachingImagesForAllAssets
{
    [TGMediaAssetImageSignalsClass stopCachingImagesForAllAssets];
}

+ (SQueue *)_thumbnailQueue
{
    static dispatch_once_t onceToken;
    static SQueue *queue;
    dispatch_once(&onceToken, ^
    {
        queue = [[SQueue alloc] init];
    });
    return queue;
}

+ (SSignal *)videoThumbnailsForAsset:(TGMediaAsset *)asset size:(CGSize)size timestamps:(NSArray *)timestamps
{
    return [[self avAssetForVideoAsset:asset] mapToSignal:^SSignal *(AVAsset *avAsset)
    {
        return [self videoThumbnailsForAVAsset:avAsset size:size timestamps:timestamps];
    }];
}

+ (SSignal *)videoThumbnailsForAVAsset:(AVAsset *)avAsset size:(CGSize)size timestamps:(NSArray *)timestamps
{
    SSignal *signal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        NSMutableArray *images = [[NSMutableArray alloc] init];
        
        AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:avAsset];
        generator.appliesPreferredTrackTransform = true;
        generator.maximumSize = size;
        generator.requestedTimeToleranceBefore = kCMTimeZero;
        generator.requestedTimeToleranceAfter = kCMTimeZero;
        
        [generator generateCGImagesAsynchronouslyForTimes:timestamps completionHandler:^(__unused CMTime requestedTime, CGImageRef imageRef, __unused CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error)
        {
           if (error != nil)
           {
               [subscriber putError:error];
               return;
           }
            
            UIImage *image = [UIImage imageWithCGImage:imageRef];
            if (result == AVAssetImageGeneratorSucceeded && image != nil)
                [images addObject:image];
            
            if (images.count == timestamps.count)
            {
                [subscriber putNext:images];
                [subscriber putCompletion];
            }
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [generator cancelAllCGImageGeneration];
        }];
    }];
    
    return [signal startOn:[self _thumbnailQueue]];
}

+ (SSignal *)videoThumbnailForAsset:(TGMediaAsset *)asset size:(CGSize)size timestamp:(CMTime)timestamp
{
    return [[self avAssetForVideoAsset:asset] mapToSignal:^SSignal *(AVAsset *avAsset)
    {
        return [self videoThumbnailForAVAsset:avAsset size:size timestamp:timestamp];
    }];
}

+ (SSignal *)videoThumbnailForAVAsset:(AVAsset *)avAsset size:(CGSize)size timestamp:(CMTime)timestamp
{
    SSignal *signal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:avAsset];
        generator.appliesPreferredTrackTransform = true;
        generator.maximumSize = size;
        generator.requestedTimeToleranceBefore = kCMTimeZero;
        generator.requestedTimeToleranceAfter = kCMTimeZero;
        
        [generator generateCGImagesAsynchronouslyForTimes:@[ [NSValue valueWithCMTime:timestamp] ] completionHandler:^(__unused CMTime requestedTime, CGImageRef imageRef, __unused CMTime actualTime, AVAssetImageGeneratorResult result, __unused NSError *error)
        {
            UIImage *image = [UIImage imageWithCGImage:imageRef];
            if (result == AVAssetImageGeneratorSucceeded && image != nil)
            {
                [subscriber putNext:image];
                [subscriber putCompletion];
            }
        }];
    
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [generator cancelAllCGImageGeneration];
        }];
    }];
    
    return [signal startOn:[self _thumbnailQueue]];
}

+ (SSignal *)saveUncompressedVideoForAsset:(TGMediaAsset *)asset toPath:(NSString *)path
{
    return [self saveUncompressedVideoForAsset:asset toPath:path allowNetworkAccess:false];
}

+ (SSignal *)saveUncompressedVideoForAsset:(TGMediaAsset *)asset toPath:(NSString *)path allowNetworkAccess:(bool)allowNetworkAccess
{
    if (!asset.isVideo)
        return [SSignal fail:nil];
    
    return [TGMediaAssetImageSignalsClass saveUncompressedVideoForAsset:asset toPath:path allowNetworkAccess:allowNetworkAccess];
}

+ (SSignal *)playerItemForVideoAsset:(TGMediaAsset *)asset
{
    if (asset == nil)
        return [SSignal fail:nil];
    
    return [TGMediaAssetImageSignalsClass playerItemForVideoAsset:asset];
}

+ (SSignal *)avAssetForVideoAsset:(TGMediaAsset *)asset
{
    return [self avAssetForVideoAsset:asset allowNetworkAccess:false];
}

+ (SSignal *)avAssetForVideoAsset:(TGMediaAsset *)asset allowNetworkAccess:(bool)allowNetworkAccess
{
    if (asset == nil)
        return [SSignal fail:nil];
    
    return [TGMediaAssetImageSignalsClass avAssetForVideoAsset:asset allowNetworkAccess:allowNetworkAccess];
}

+ (UIImageOrientation)videoOrientationOfAVAsset:(AVAsset *)avAsset
{
    NSArray *videoTracks = [avAsset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *videoTrack = videoTracks.firstObject;
    if (videoTrack == nil)
        return UIImageOrientationUp;
    
    CGAffineTransform transform = videoTrack.preferredTransform;
    CGFloat angle = TGRadiansToDegrees((CGFloat)atan2(transform.b, transform.a));
    
    UIImageOrientation orientation = 0;
    switch ((NSInteger)angle)
    {
        case 0:
            orientation = UIImageOrientationUp;
            break;
        case 90:
            orientation = UIImageOrientationRight;
            break;
        case 180:
            orientation = UIImageOrientationDown;
            break;
        case -90:
            orientation	= UIImageOrientationLeft;
            break;
        default:
            orientation = UIImageOrientationUp;
            break;
    }
    
    return orientation;
}

+ (bool)usesPhotoFramework
{
    return [TGMediaAssetImageSignalsClass usesPhotoFramework];
}

@end
