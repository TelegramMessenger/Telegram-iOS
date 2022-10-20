#import "TGMediaVideoConverter.h"

#import <CommonCrypto/CommonDigest.h>
#import <sys/stat.h>

#import "GPUImageContext.h"

#import "LegacyComponentsInternal.h"

#import "TGImageUtils.h"
#import "TGPhotoEditorUtils.h"
#import "PGPhotoEditor.h"
#import "TGPaintUtils.h"
#import "TGPhotoPaintEntity.h"

#import "TGVideoEditAdjustments.h"
#import "TGPaintingData.h"
#import "TGPhotoPaintStickersContext.h"

@interface TGMediaVideoConversionPresetSettings ()

+ (bool)keepAudioForPreset:(TGMediaVideoConversionPreset)preset;

+ (NSInteger)_videoBitrateKbpsForPreset:(TGMediaVideoConversionPreset)preset;
+ (NSInteger)_audioBitrateKbpsForPreset:(TGMediaVideoConversionPreset)preset;
+ (NSInteger)_audioChannelsCountForPreset:(TGMediaVideoConversionPreset)preset;

@end


@interface TGMediaSampleBufferProcessor : NSObject
{
    AVAssetReaderOutput *_assetReaderOutput;
    AVAssetWriterInput *_assetWriterInput;
    
    SQueue *_queue;
    bool _finished;
    bool _started;
    
    void (^_completionBlock)(void);
}

@property (nonatomic, readonly) bool succeed;

- (instancetype)initWithAssetReaderOutput:(AVAssetReaderOutput *)assetReaderOutput assetWriterInput:(AVAssetWriterInput *)assetWriterInput;

- (void)startWithTimeRange:(CMTimeRange)timeRange progressBlock:(void (^)(CGFloat progress))progressBlock completionBlock:(void (^)(void))completionBlock;
- (void)cancel;

@end


@interface TGMediaVideoFileWatcher ()
{
    dispatch_source_t _readerSource;
    SQueue *_queue;
}
@end


@interface TGMediaVideoConversionContext : NSObject

@property (nonatomic, readonly) bool cancelled;
@property (nonatomic, readonly) bool finished;

@property (nonatomic, readonly) SQueue *queue;
@property (nonatomic, readonly) SSubscriber *subscriber;

@property (nonatomic, readonly) AVAssetReader *assetReader;
@property (nonatomic, readonly) AVAssetWriter *assetWriter;

@property (nonatomic, readonly) AVAssetImageGenerator *imageGenerator;

@property (nonatomic, readonly) TGMediaSampleBufferProcessor *videoProcessor;
@property (nonatomic, readonly) TGMediaSampleBufferProcessor *audioProcessor;

@property (nonatomic, readonly) id<TGPhotoPaintEntityRenderer> entityRenderer;

@property (nonatomic, readonly) CMTimeRange timeRange;
@property (nonatomic, readonly) CGSize dimensions;
@property (nonatomic, readonly) UIImage *coverImage;

+ (instancetype)contextWithQueue:(SQueue *)queue subscriber:(SSubscriber *)subscriber;

- (instancetype)cancelledContext;
- (instancetype)finishedContext;

- (instancetype)addImageGenerator:(AVAssetImageGenerator *)imageGenerator;
- (instancetype)addCoverImage:(UIImage *)coverImage;
- (instancetype)contextWithAssetReader:(AVAssetReader *)assetReader assetWriter:(AVAssetWriter *)assetWriter videoProcessor:(TGMediaSampleBufferProcessor *)videoProcessor audioProcessor:(TGMediaSampleBufferProcessor *)audioProcessor timeRange:(CMTimeRange)timeRange dimensions:(CGSize)dimensions entityRenderer:(id<TGPhotoPaintEntityRenderer>)entityRenderer;

@end


@interface TGMediaVideoConversionResult ()

+ (instancetype)resultWithFileURL:(NSURL *)fileUrl fileSize:(NSUInteger)fileSize duration:(NSTimeInterval)duration dimensions:(CGSize)dimensions coverImage:(UIImage *)coverImage liveUploadData:(id)livaUploadData;

@end


@implementation TGMediaVideoConverter

+ (SSignal *)convertAVAsset:(AVAsset *)avAsset adjustments:(TGMediaVideoEditAdjustments *)adjustments watcher:(TGMediaVideoFileWatcher *)watcher entityRenderer:(id<TGPhotoPaintEntityRenderer>)entityRenderer
{
    return [self convertAVAsset:avAsset adjustments:adjustments watcher:watcher inhibitAudio:false entityRenderer:entityRenderer];
}

+ (SSignal *)convertAVAsset:(AVAsset *)avAsset adjustments:(TGMediaVideoEditAdjustments *)adjustments watcher:(TGMediaVideoFileWatcher *)watcher inhibitAudio:(bool)inhibitAudio entityRenderer:(id<TGPhotoPaintEntityRenderer>)entityRenderer
{
    if ([avAsset isKindOfClass:[NSURL class]]) {
        avAsset = [[AVURLAsset alloc] initWithURL:(NSURL *)avAsset options:nil];
    }
    SQueue *queue = [[SQueue alloc] init];
    
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        SAtomic *context = [[SAtomic alloc] initWithValue:[TGMediaVideoConversionContext contextWithQueue:queue subscriber:subscriber]];
        NSURL *outputUrl = [self _randomTemporaryURL];
        
        NSArray *requiredKeys = @[ @"tracks", @"duration" ];
        [avAsset loadValuesAsynchronouslyForKeys:requiredKeys completionHandler:^
        {
            [queue dispatch:^
            {
                if (((TGMediaVideoConversionContext *)context.value).cancelled)
                    return;
                
                CGSize dimensions = [avAsset tracksWithMediaType:AVMediaTypeVideo].firstObject.naturalSize;
                TGMediaVideoConversionPreset preset = adjustments.sendAsGif ? TGMediaVideoConversionPresetAnimation : [self presetFromAdjustments:adjustments];
                if (!CGSizeEqualToSize(dimensions, CGSizeZero) && preset != TGMediaVideoConversionPresetAnimation && preset != TGMediaVideoConversionPresetVideoMessage && preset != TGMediaVideoConversionPresetProfile && preset != TGMediaVideoConversionPresetProfileLow && preset != TGMediaVideoConversionPresetProfileHigh && preset != TGMediaVideoConversionPresetProfileVeryHigh && preset != TGMediaVideoConversionPresetPassthrough)
                {
                    TGMediaVideoConversionPreset bestPreset = [self bestAvailablePresetForDimensions:dimensions];
                    if (preset > bestPreset)
                        preset = bestPreset;
                }
                
                NSError *error = nil;
                for (NSString *key in requiredKeys)
                {
                    if ([avAsset statusOfValueForKey:key error:&error] != AVKeyValueStatusLoaded || error != nil)
                    {
                        [subscriber putError:error];
                        return;
                    }
                }
                
                NSString *outputPath = outputUrl.path;
                NSFileManager *fileManager = [NSFileManager defaultManager];
                if ([fileManager fileExistsAtPath:outputPath])
                {
                    [fileManager removeItemAtPath:outputPath error:&error];
                    if (error != nil)
                    {
                        [subscriber putError:error];
                        return;
                    }
                }
                
                if (![self setupAssetReaderWriterForAVAsset:avAsset image:nil duration:0.0 outputURL:outputUrl preset:preset entityRenderer:entityRenderer adjustments:adjustments inhibitAudio:inhibitAudio conversionContext:context error:&error])
                {
                    [subscriber putError:error];
                    return;
                }
                
                TGDispatchAfter(1.0, queue._dispatch_queue, ^
                {
                    if (watcher != nil)
                        [watcher setupWithFileURL:outputUrl];
                });
                
                [self processWithConversionContext:context completionBlock:^
                {
                    TGMediaVideoConversionContext *resultContext = context.value;
                    
                    NSTimeInterval videoStartValue = 0.0;
                    if (adjustments.videoStartValue > 0.0) {
                        videoStartValue = adjustments.videoStartValue - adjustments.trimStartValue;
                    }
                    
                    [resultContext.imageGenerator generateCGImagesAsynchronouslyForTimes:@[ [NSValue valueWithCMTime:CMTimeMakeWithSeconds(videoStartValue, NSEC_PER_SEC)] ] completionHandler:^(__unused CMTime requestedTime, CGImageRef  _Nullable image, __unused CMTime actualTime, AVAssetImageGeneratorResult result, __unused NSError * _Nullable error)
                    {
                        UIImage *coverImage = nil;
                        if (result == AVAssetImageGeneratorSucceeded)
                            coverImage = [UIImage imageWithCGImage:image];
                        
                        __block TGMediaVideoConversionResult *contextResult = nil;
                        [context modify:^id(TGMediaVideoConversionContext *resultContext)
                        {
                            id liveUploadData = nil;
                            if (watcher != nil)
                                liveUploadData = [watcher fileUpdated:true];
                            
                            NSUInteger fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:outputUrl.path error:nil] fileSize];
                            contextResult = [TGMediaVideoConversionResult resultWithFileURL:outputUrl fileSize:fileSize duration:CMTimeGetSeconds(resultContext.timeRange.duration) dimensions:resultContext.dimensions coverImage:coverImage liveUploadData:liveUploadData];
                            return [resultContext finishedContext];
                        }];
                        
                        [subscriber putNext:contextResult];
                        [subscriber putCompletion];
                    }];
                }];
            }];
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [queue dispatch:^
            {
                [context modify:^id(TGMediaVideoConversionContext *currentContext)
                {
                    if (currentContext.finished)
                        return currentContext;
                    
                    [currentContext.videoProcessor cancel];
                    [currentContext.audioProcessor cancel];
                    
                    return [currentContext cancelledContext];
                }];
            }];
        }];
    }];
}

+ (SSignal *)renderUIImage:(UIImage *)image duration:(NSTimeInterval)duration adjustments:(TGMediaVideoEditAdjustments *)adjustments watcher:(TGMediaVideoFileWatcher *)watcher entityRenderer:(id<TGPhotoPaintEntityRenderer>)entityRenderer
{
    SQueue *queue = [[SQueue alloc] init];
       
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
            {
        SAtomic *context = [[SAtomic alloc] initWithValue:[TGMediaVideoConversionContext contextWithQueue:queue subscriber:subscriber]];
        NSURL *outputUrl = [self _randomTemporaryURL];
        
        NSString *path = TGComponentsPathForResource(@"blank", @"mp4");
        AVAsset *avAsset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:path] options:nil];
        
        NSArray *requiredKeys = @[ @"tracks", @"duration", @"playable" ];
        [avAsset loadValuesAsynchronouslyForKeys:requiredKeys completionHandler:^
        {
            [queue dispatch:^
            {
                if (((TGMediaVideoConversionContext *)context.value).cancelled)
                    return;
                
                TGMediaVideoConversionPreset preset = TGMediaVideoConversionPresetAnimation;
                if (adjustments.preset == TGMediaVideoConversionPresetProfile || adjustments.preset != TGMediaVideoConversionPresetProfileLow || adjustments.preset == TGMediaVideoConversionPresetProfileHigh || adjustments.preset == TGMediaVideoConversionPresetProfileVeryHigh) {
                    preset = adjustments.preset;
                }
                
                NSError *error = nil;
                
                NSString *outputPath = outputUrl.path;
                NSFileManager *fileManager = [NSFileManager defaultManager];
                if ([fileManager fileExistsAtPath:outputPath])
                {
                    [fileManager removeItemAtPath:outputPath error:&error];
                    if (error != nil)
                    {
                        [subscriber putError:error];
                        return;
                    }
                }
                
                if (![self setupAssetReaderWriterForAVAsset:avAsset image:image duration:duration outputURL:outputUrl preset:preset entityRenderer:entityRenderer adjustments:adjustments inhibitAudio:true conversionContext:context error:&error])
                {
                    [subscriber putError:error];
                    return;
                }
                
                TGDispatchAfter(1.0, queue._dispatch_queue, ^
                {
                    if (watcher != nil)
                        [watcher setupWithFileURL:outputUrl];
                });
                
                [self processWithConversionContext:context completionBlock:^
                {
                    TGMediaVideoConversionContext *resultContext = context.value;
                    [resultContext.imageGenerator generateCGImagesAsynchronouslyForTimes:@[ [NSValue valueWithCMTime:kCMTimeZero] ] completionHandler:^(__unused CMTime requestedTime, CGImageRef  _Nullable image, __unused CMTime actualTime, AVAssetImageGeneratorResult result, __unused NSError * _Nullable error)
                    {
                        UIImage *coverImage = nil;
                        if (result == AVAssetImageGeneratorSucceeded)
                            coverImage = [UIImage imageWithCGImage:image];
                        
                        __block TGMediaVideoConversionResult *contextResult = nil;
                        [context modify:^id(TGMediaVideoConversionContext *resultContext)
                        {
                            id liveUploadData = nil;
                            if (watcher != nil)
                                liveUploadData = [watcher fileUpdated:true];
                            
                            NSUInteger fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:outputUrl.path error:nil] fileSize];
                            contextResult = [TGMediaVideoConversionResult resultWithFileURL:outputUrl fileSize:fileSize duration:CMTimeGetSeconds(resultContext.timeRange.duration) dimensions:resultContext.dimensions coverImage:coverImage liveUploadData:liveUploadData];
                            return [resultContext finishedContext];
                        }];
                        
                        [subscriber putNext:contextResult];
                        [subscriber putCompletion];
                    }];
                }];
            }];
        }];
                
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [queue dispatch:^
            {
                [context modify:^id(TGMediaVideoConversionContext *currentContext)
                {
                    if (currentContext.finished)
                        return currentContext;
                    
                    [currentContext.videoProcessor cancel];
                    
                    return [currentContext cancelledContext];
                }];
            }];
        }];
    }];
}

+ (CGSize)dimensionsFor:(CGSize)dimensions adjustments:(TGMediaVideoEditAdjustments *)adjustments preset:(TGMediaVideoConversionPreset)preset {
    CGRect transformedRect = CGRectMake(0.0f, 0.0f, dimensions.width, dimensions.height);
    
    bool hasCropping = [adjustments cropAppliedForAvatar:false];
    CGRect cropRect = hasCropping ? CGRectIntegral(adjustments.cropRect) : transformedRect;
    
    CGSize maxDimensions = [TGMediaVideoConversionPresetSettings maximumSizeForPreset:preset];
    CGSize outputDimensions = TGFitSizeF(cropRect.size, maxDimensions);
    outputDimensions = CGSizeMake(ceil(outputDimensions.width), ceil(outputDimensions.height));
    outputDimensions = [self _renderSizeWithCropSize:outputDimensions];
    
    if (TGOrientationIsSideward(adjustments.cropOrientation, NULL))
        outputDimensions = CGSizeMake(outputDimensions.height, outputDimensions.width);
    
    return outputDimensions;
}

+ (AVAssetReaderVideoCompositionOutput *)setupVideoCompositionOutputWithAVAsset:(AVAsset *)avAsset image:(UIImage *)image composition:(AVMutableComposition *)composition videoTrack:(AVAssetTrack *)videoTrack preset:(TGMediaVideoConversionPreset)preset entityRenderer:(id<TGPhotoPaintEntityRenderer>)entityRenderer adjustments:(TGMediaVideoEditAdjustments *)adjustments timeRange:(CMTimeRange)timeRange outputSettings:(NSDictionary **)outputSettings dimensions:(CGSize *)dimensions conversionContext:(SAtomic *)conversionContext
{
    CGSize transformedSize = CGRectApplyAffineTransform((CGRect){CGPointZero, videoTrack.naturalSize}, videoTrack.preferredTransform).size;
    CGRect transformedRect = CGRectMake(0, 0, transformedSize.width, transformedSize.height);
    if (CGSizeEqualToSize(transformedRect.size, CGSizeZero))
        transformedRect = CGRectMake(0, 0, videoTrack.naturalSize.width, videoTrack.naturalSize.height);
    
    bool hasCropping = [adjustments cropAppliedForAvatar:false];
    CGRect cropRect = hasCropping ? CGRectIntegral(adjustments.cropRect) : transformedRect;
    if (cropRect.size.width < FLT_EPSILON || cropRect.size.height < FLT_EPSILON)
        cropRect = transformedRect;
    if (image != nil)
        cropRect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);

    CGSize maxDimensions = [TGMediaVideoConversionPresetSettings maximumSizeForPreset:preset];
    CGSize outputDimensions = TGFitSizeF(cropRect.size, maxDimensions);
    outputDimensions = CGSizeMake(ceil(outputDimensions.width), ceil(outputDimensions.height));
    outputDimensions = [self _renderSizeWithCropSize:outputDimensions rotateSideward:false];
    
    if (TGOrientationIsSideward(adjustments.cropOrientation, NULL))
        outputDimensions = CGSizeMake(outputDimensions.height, outputDimensions.width);
    
    if ((preset == TGMediaVideoConversionPresetProfile || preset == TGMediaVideoConversionPresetProfileLow || preset == TGMediaVideoConversionPresetProfileHigh || preset == TGMediaVideoConversionPresetProfileVeryHigh) && MIN(outputDimensions.width, outputDimensions.height) < 160.0) {
        outputDimensions = CGSizeMake(160.0, 160.0);
    }
        
    AVMutableCompositionTrack *compositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionTrack insertTimeRange:timeRange ofTrack:videoTrack atTime:kCMTimeZero error:NULL];
    
    CMTime frameDuration30FPS = CMTimeMake(1, 30);
    CMTime frameDuration = frameDuration30FPS;
    if (videoTrack.nominalFrameRate > 0)
        frameDuration = CMTimeMake(1, (int32_t)videoTrack.nominalFrameRate);
    else if (CMTimeCompare(videoTrack.minFrameDuration, kCMTimeZero) == 1)
        frameDuration = videoTrack.minFrameDuration;
    
    if (CMTimeCompare(frameDuration, kCMTimeZero) != 1 || !CMTIME_IS_VALID(frameDuration) || image != nil || entityRenderer != nil || adjustments.toolsApplied)
        frameDuration = frameDuration30FPS;
    
    if (CMTimeCompare(frameDuration, frameDuration30FPS)) {
        frameDuration = frameDuration30FPS;
    }
    
    NSInteger fps = (NSInteger)(1.0 / CMTimeGetSeconds(frameDuration));
    
    UIImage *overlayImage = nil;
    if (adjustments.paintingData.imagePath != nil)
        overlayImage = [UIImage imageWithContentsOfFile:adjustments.paintingData.imagePath];
    
    AVMutableVideoComposition *videoComposition;
    if (entityRenderer != nil || adjustments.toolsApplied) {
        PGPhotoEditor *editor = nil;
        CIContext *ciContext = nil;
        if (adjustments.toolsApplied) {
            editor = [[PGPhotoEditor alloc] initWithOriginalSize:adjustments.originalSize adjustments:adjustments forVideo:true enableStickers:true];
            editor.standalone = true;
            ciContext = [CIContext contextWithEAGLContext:[[GPUImageContext sharedImageProcessingContext] context]];
        }
        
        CIImage *backgroundCIImage = nil;
        if (image != nil) {
            backgroundCIImage = [[CIImage alloc] initWithImage:image];
        }
        
        __block CIImage *overlayCIImage = nil;
        videoComposition = [AVMutableVideoComposition videoCompositionWithAsset:avAsset applyingCIFiltersWithHandler:^(AVAsynchronousCIImageFilteringRequest * _Nonnull request) {
            CIImage *resultImage = request.sourceImage;
            
            CGSize size;
            CGPoint finalOffset = CGPointZero;
            if (backgroundCIImage != nil) {
                resultImage = backgroundCIImage;
                size = resultImage.extent.size;
                if ([adjustments cropAppliedForAvatar:false]) {
                    CGRect cropRect = adjustments.cropRect;
                    CGFloat ratio = resultImage.extent.size.width / cropRect.size.width;
                    
                    CGSize extendedSize = CGSizeMake(adjustments.originalSize.width * ratio, adjustments.originalSize.height * ratio);
                    CIImage *image = [[CIImage alloc] initWithColor:[CIColor colorWithRed:0.0f green:0.0f blue:0.0f]];
                    image = [image imageByCroppingToRect:CGRectMake(0.0, 0.0, extendedSize.width, extendedSize.height)];
                    
                    cropRect = CGRectMake(cropRect.origin.x * ratio, (adjustments.originalSize.height - cropRect.size.height - cropRect.origin.y) * ratio, cropRect.size.width * ratio, cropRect.size.height * ratio);
                    
                    resultImage = [resultImage imageByApplyingTransform:CGAffineTransformMakeTranslation(cropRect.origin.x, cropRect.origin.y)];
                    finalOffset = CGPointMake(-cropRect.origin.x, -cropRect.origin.y);
                    
                    image = [resultImage imageByCompositingOverImage:image];
                    resultImage = image;
                    
                    size = resultImage.extent.size;
                }
                
            } else {
                size = resultImage.extent.size;
                if ([adjustments cropAppliedForAvatar:false]) {
                    CGRect cropRect = adjustments.cropRect;
                    cropRect = CGRectMake(cropRect.origin.x, adjustments.originalSize.height - cropRect.size.height - cropRect.origin.y, cropRect.size.width, cropRect.size.height);
                    finalOffset = CGPointMake(-cropRect.origin.x, -cropRect.origin.y);
                }
            }
            
            void (^process)(CIImage *, void(^)(void)) = ^(CIImage *resultImage, void(^unlock)(void)) {
                if (overlayImage != nil && overlayImage.size.width > 0.0) {
                    if (overlayCIImage == nil) {
                        overlayCIImage = [[CIImage alloc] initWithImage:overlayImage];
                        CGFloat scale = size.width / overlayCIImage.extent.size.width;
                        overlayCIImage = [overlayCIImage imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
                    }
                    resultImage = [overlayCIImage imageByCompositingOverImage:resultImage];
                }
                
                if (entityRenderer != nil) {
                    [entityRenderer entitiesForTime:request.compositionTime fps:fps size:size completion:^(NSArray<CIImage *> *images) {
                        CIImage *mergedImage = resultImage;
                        for (CIImage *image in images) {
                            mergedImage = [image imageByCompositingOverImage:mergedImage];
                        }
                        if (!CGPointEqualToPoint(finalOffset, CGPointZero)) {
                            mergedImage = [mergedImage imageByApplyingTransform:CGAffineTransformMakeTranslation(finalOffset.x, finalOffset.y)];
                        }
                        [request finishWithImage:mergedImage context:ciContext];
                        unlock();
                    }];
                } else {
                    if (!CGPointEqualToPoint(finalOffset, CGPointZero)) {
                        resultImage = [resultImage imageByApplyingTransform:CGAffineTransformMakeTranslation(finalOffset.x, finalOffset.y)];
                    }
                    [request finishWithImage:resultImage context:ciContext];
                    unlock();
                }
            };
            
            if (editor != nil && backgroundCIImage == nil) {
                [editor setCIImage:resultImage];
                [editor currentResultCIImage:^(CIImage *image, void(^unlock)(void)) {
                    process(image, unlock);
                }];
            } else {
                process(resultImage, ^{});
            }
        }];
    } else {
        videoComposition = [AVMutableVideoComposition videoComposition];
                
        bool mirrored = false;
        UIImageOrientation videoOrientation = TGVideoOrientationForAsset(avAsset, &mirrored);
        CGAffineTransform transform = TGVideoTransformForOrientation(videoOrientation, videoTrack.naturalSize, cropRect, mirrored);
        CGAffineTransform rotationTransform = TGVideoTransformForCrop(adjustments.cropOrientation, cropRect.size, adjustments.cropMirrored);
        CGAffineTransform finalTransform = CGAffineTransformConcat(transform, rotationTransform);
        
        AVMutableVideoCompositionLayerInstruction *transformer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionTrack];
        [transformer setTransform:finalTransform atTime:kCMTimeZero];
        
        AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, compositionTrack.timeRange.duration);
        instruction.layerInstructions = [NSArray arrayWithObject:transformer];
        videoComposition.instructions = [NSArray arrayWithObject:instruction];
    }
    
    videoComposition.frameDuration = frameDuration;
    
    videoComposition.renderSize = [self _renderSizeWithCropSize:cropRect.size rotateSideward:TGOrientationIsSideward(adjustments.cropOrientation, NULL)];
    if (videoComposition.renderSize.width < FLT_EPSILON || videoComposition.renderSize.height < FLT_EPSILON)
        return nil;

    if (overlayImage != nil && entityRenderer == nil)
    {
        CALayer *parentLayer = [CALayer layer];
        parentLayer.frame = CGRectMake(0, 0, videoComposition.renderSize.width, videoComposition.renderSize.height);

        CALayer *videoLayer = [CALayer layer];
        videoLayer.frame = parentLayer.frame;
        [parentLayer addSublayer:videoLayer];

        CGSize parentSize = parentLayer.bounds.size;
        if (TGOrientationIsSideward(adjustments.cropOrientation, NULL))
            parentSize = CGSizeMake(parentSize.height, parentSize.width);

        CGSize size = CGSizeMake(parentSize.width * transformedSize.width / cropRect.size.width, parentSize.height * transformedSize.height / cropRect.size.height);
        CGPoint origin = CGPointMake(-parentSize.width / cropRect.size.width * cropRect.origin.x,  -parentSize.height / cropRect.size.height * (transformedSize.height - cropRect.size.height - cropRect.origin.y));

        CALayer *rotationLayer = [CALayer layer];
        rotationLayer.frame = CGRectMake(0, 0, parentSize.width, parentSize.height);
        [parentLayer addSublayer:rotationLayer];

        UIImageOrientation orientation = TGMirrorSidewardOrientation(adjustments.cropOrientation);
        CATransform3D layerTransform = CATransform3DMakeTranslation(rotationLayer.frame.size.width / 2.0f, rotationLayer.frame.size.height / 2.0f, 0.0f);
        layerTransform = CATransform3DRotate(layerTransform, TGRotationForOrientation(orientation), 0.0f, 0.0f, 1.0f);
        layerTransform = CATransform3DTranslate(layerTransform, -parentLayer.bounds.size.width / 2.0f, -parentLayer.bounds.size.height / 2.0f, 0.0f);
        rotationLayer.transform = layerTransform;
        rotationLayer.frame = parentLayer.frame;

        CALayer *overlayLayer = [CALayer layer];
        overlayLayer.contents = (id)overlayImage.CGImage;
        overlayLayer.frame = CGRectMake(origin.x, origin.y, size.width, size.height);
        [rotationLayer addSublayer:overlayLayer];

        videoComposition.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
    }
    
    NSDictionary *settings = [TGMediaVideoConversionPresetSettings videoSettingsForPreset:preset dimensions:outputDimensions];
    *outputSettings = settings;
    *dimensions = outputDimensions;

    NSMutableDictionary *videoSettings = [[NSMutableDictionary alloc] init];
    videoSettings[(id)kCVPixelBufferPixelFormatTypeKey] = @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange);
#if TARGET_IPHONE_SIMULATOR
#else
    videoSettings[AVVideoColorPropertiesKey] = settings[AVVideoColorPropertiesKey];
#endif
    
    AVAssetReaderVideoCompositionOutput *output = [[AVAssetReaderVideoCompositionOutput alloc] initWithVideoTracks:[composition tracksWithMediaType:AVMediaTypeVideo] videoSettings:videoSettings];
    output.videoComposition = videoComposition;
    
    AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:composition];
    imageGenerator.appliesPreferredTrackTransform = true;
    imageGenerator.videoComposition = videoComposition;
    imageGenerator.maximumSize = maxDimensions;
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    
    [conversionContext modify:^id(TGMediaVideoConversionContext *context)
    {
        return [context addImageGenerator:imageGenerator];
    }];
    
    return output;
}

+ (bool)setupAssetReaderWriterForAVAsset:(AVAsset *)avAsset image:(UIImage *)image duration:(NSTimeInterval)duration outputURL:(NSURL *)outputURL preset:(TGMediaVideoConversionPreset)preset entityRenderer:(id<TGPhotoPaintEntityRenderer>)entityRenderer adjustments:(TGMediaVideoEditAdjustments *)adjustments inhibitAudio:(bool)inhibitAudio conversionContext:(SAtomic *)outConversionContext error:(NSError **)error
{
    if (image == nil) {
        TGMediaSampleBufferProcessor *videoProcessor = nil;
        TGMediaSampleBufferProcessor *audioProcessor = nil;
        
        AVAssetTrack *audioTrack = [[avAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];
        AVAssetTrack *videoTrack = [[avAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
        if (videoTrack == nil)
            return false;
        
        CGSize dimensions = CGSizeZero;
        CMTimeRange timeRange = videoTrack.timeRange;
        if (adjustments.trimApplied)
        {
            NSTimeInterval duration = CMTimeGetSeconds(videoTrack.timeRange.duration);
            if (adjustments.trimEndValue < duration)
            {
                timeRange = adjustments.trimTimeRange;
            }
            else
            {
                timeRange = CMTimeRangeMake(CMTimeMakeWithSeconds(adjustments.trimStartValue, NSEC_PER_SEC), CMTimeMakeWithSeconds(duration - adjustments.trimStartValue, NSEC_PER_SEC));
            }
        }
        timeRange = CMTimeRangeMake(CMTimeAdd(timeRange.start, CMTimeMake(10, 100)), CMTimeSubtract(timeRange.duration, CMTimeMake(10, 100)));
        
        NSDictionary *outputSettings = nil;
        AVMutableComposition *composition = [AVMutableComposition composition];
        AVAssetReaderVideoCompositionOutput *output = [self setupVideoCompositionOutputWithAVAsset:avAsset image:nil composition:composition videoTrack:videoTrack preset:preset entityRenderer:entityRenderer adjustments:adjustments timeRange:timeRange outputSettings:&outputSettings dimensions:&dimensions conversionContext:outConversionContext];
        if (output == nil)
            return false;
        
        if (preset == TGMediaVideoConversionPresetPassthrough)
            outputSettings = nil;
        
        AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:composition error:error];
        if (assetReader == nil)
            return false;
        
        AVAssetWriter *assetWriter = [[AVAssetWriter alloc] initWithURL:outputURL fileType:AVFileTypeMPEG4 error:error];
        if (assetWriter == nil)
            return false;
        
        [assetReader addOutput:output];
        
        AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSettings];
        [assetWriter addInput:input];
        
        videoProcessor = [[TGMediaSampleBufferProcessor alloc] initWithAssetReaderOutput:output assetWriterInput:input];
        
        if (!inhibitAudio && [TGMediaVideoConversionPresetSettings keepAudioForPreset:preset] && audioTrack != nil)
        {
            AVMutableCompositionTrack *trimAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            [trimAudioTrack insertTimeRange:timeRange ofTrack:audioTrack atTime:kCMTimeZero error:NULL];
            if (trimAudioTrack == nil)
                return false;
            
            AVAssetReaderOutput *output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:trimAudioTrack outputSettings:@{ AVFormatIDKey: @(kAudioFormatLinearPCM) }];
            [assetReader addOutput:output];
            
            AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:[TGMediaVideoConversionPresetSettings audioSettingsForPreset:preset]];
            [assetWriter addInput:input];
            
            audioProcessor = [[TGMediaSampleBufferProcessor alloc] initWithAssetReaderOutput:output assetWriterInput:input];
        }
        
        [outConversionContext modify:^id(TGMediaVideoConversionContext *currentContext)
        {
            return [currentContext contextWithAssetReader:assetReader assetWriter:assetWriter videoProcessor:videoProcessor audioProcessor:audioProcessor timeRange:timeRange dimensions:dimensions entityRenderer:entityRenderer];
        }];
        
        return true;
    } else {
        TGMediaSampleBufferProcessor *videoProcessor = nil;
        
        CGSize dimensions = CGSizeZero;
        NSDictionary *outputSettings = nil;
        CMTimeRange timeRange = CMTimeRangeMake(CMTimeMakeWithSeconds(0.0, NSEC_PER_SEC), CMTimeMakeWithSeconds(duration, NSEC_PER_SEC));
        AVMutableComposition *composition = [AVMutableComposition composition];
        
        AVAssetTrack *videoTrack = [[avAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
        if (videoTrack == nil)
            return false;
       
        AVMutableCompositionTrack *mutableCompositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [mutableCompositionVideoTrack insertTimeRange:timeRange ofTrack:videoTrack atTime:kCMTimeZero error:nil];
        
        AVMutableComposition *mock = [AVMutableComposition composition];
        AVMutableCompositionTrack *mockTrack = [mock addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [mockTrack insertTimeRange:timeRange ofTrack:videoTrack atTime:kCMTimeZero error:nil];
           
        AVAssetReaderVideoCompositionOutput *output = [self setupVideoCompositionOutputWithAVAsset:mock image:image composition:composition videoTrack:videoTrack preset:preset entityRenderer:entityRenderer adjustments:adjustments timeRange:timeRange outputSettings:&outputSettings dimensions:&dimensions conversionContext:outConversionContext];
        if (output == nil)
            return false;
        
        AVAssetReader *assetReader = [[AVAssetReader alloc] initWithAsset:composition error:error];
        if (assetReader == nil)
            return false;
        
        AVAssetWriter *assetWriter = [[AVAssetWriter alloc] initWithURL:outputURL fileType:AVFileTypeMPEG4 error:error];
        if (assetWriter == nil)
            return false;
        
        [assetReader addOutput:output];
        
        AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSettings];
        [assetWriter addInput:input];
        
        videoProcessor = [[TGMediaSampleBufferProcessor alloc] initWithAssetReaderOutput:output assetWriterInput:input];
                
        [outConversionContext modify:^id(TGMediaVideoConversionContext *currentContext)
        {
            return [currentContext contextWithAssetReader:assetReader assetWriter:assetWriter videoProcessor:videoProcessor audioProcessor:nil timeRange:timeRange dimensions:dimensions entityRenderer:entityRenderer];
        }];
        
        return true;
    }
    return false;
}

+ (void)processWithConversionContext:(SAtomic *)context_ completionBlock:(void (^)(void))completionBlock
{
    TGMediaVideoConversionContext *context = [context_ value];
    
    if (![context.assetReader startReading])
    {
        [context.subscriber putError:context.assetReader.error];
        return;
    }
    
    if (![context.assetWriter startWriting])
    {
        [context.subscriber putError:context.assetWriter.error];
        return;
    }
    
    dispatch_group_t dispatchGroup = dispatch_group_create();
    
    [context.assetWriter startSessionAtSourceTime:kCMTimeZero];
    
    if (context.audioProcessor != nil)
    {
        dispatch_group_enter(dispatchGroup);
        [context.audioProcessor startWithTimeRange:context.timeRange progressBlock:nil completionBlock:^
        {
            dispatch_group_leave(dispatchGroup);
        }];
    }
    
    if (context.videoProcessor != nil)
    {
        dispatch_group_enter(dispatchGroup);
        
        SSubscriber *subscriber = context.subscriber;
        [context.videoProcessor startWithTimeRange:context.timeRange progressBlock:^(CGFloat progress)
        {
#if DEBUG
            printf("Video progress: %f\n", progress);
#endif
            [subscriber putNext:@(progress)];
        } completionBlock:^
        {
            dispatch_group_leave(dispatchGroup);
        }];
    }
    
    dispatch_group_notify(dispatchGroup, context.queue._dispatch_queue, ^
    {
        TGMediaVideoConversionContext *context = [context_ value];
        if (context.cancelled)
        {
            [context.assetReader cancelReading];
            [context.assetWriter cancelWriting];
            
            [[NSFileManager defaultManager] removeItemAtURL:context.assetWriter.outputURL error:nil];
        }
        else
        {
            bool audioProcessingFailed = false;
            bool videoProcessingFailed = false;
            
            if (context.audioProcessor != nil)
                audioProcessingFailed = !context.audioProcessor.succeed;
            
            if (context.videoProcessor != nil)
                videoProcessingFailed = !context.videoProcessor.succeed;
            
            if (!audioProcessingFailed && !videoProcessingFailed && context.assetReader.status != AVAssetReaderStatusFailed)
            {
                [context.assetWriter finishWritingWithCompletionHandler:^
                {
                    if (context.assetWriter.status != AVAssetWriterStatusFailed)
                        completionBlock();
                    else
                        [context.subscriber putError:context.assetWriter.error];
                }];
            }
            else
            {
                [context.subscriber putError:context.assetReader.error];
            }
        }
        
    });
}

#pragma mark - Hash

+ (SSignal *)hashForAVAsset:(AVAsset *)avAsset adjustments:(TGMediaVideoEditAdjustments *)adjustments
{
    if ([adjustments trimApplied] || [adjustments cropAppliedForAvatar:false] || adjustments.sendAsGif)
        return [SSignal single:nil];
    
    NSURL *fileUrl = nil;
    NSData *timingData = nil;
    
    if ([avAsset isKindOfClass:[AVURLAsset class]])
    {
        fileUrl = ((AVURLAsset *)avAsset).URL;
    }
    else
    {
        AVComposition *composition = (AVComposition *)avAsset;
        AVCompositionTrack *videoTrack = [composition tracksWithMediaType:AVMediaTypeVideo].firstObject;
        if (videoTrack != nil)
        {
            AVCompositionTrackSegment *firstSegment = videoTrack.segments.firstObject;
            
            NSMutableData *timingData = [[NSMutableData alloc] init];
            for (AVCompositionTrackSegment *segment in videoTrack.segments)
            {
                CMTimeRange targetRange = segment.timeMapping.target;
                CMTimeValue startTime = targetRange.start.value / targetRange.start.timescale;
                CMTimeValue duration = targetRange.duration.value / targetRange.duration.timescale;
                [timingData appendBytes:&startTime length:sizeof(startTime)];
                [timingData appendBytes:&duration length:sizeof(duration)];
            }
            
            fileUrl = firstSegment.sourceURL;
        }
    }
    
    return [SSignal defer:^SSignal *
    {
        if (fileUrl == nil) {
            return [SSignal fail:nil];
        } else {
            NSError *error;
            NSData *fileData = [NSData dataWithContentsOfURL:fileUrl options:NSDataReadingMappedIfSafe error:&error];
            if (error == nil)
                return [SSignal single:[self _hashForVideoWithFileData:fileData timingData:timingData preset:[self presetFromAdjustments:adjustments]]];
            else
                return [SSignal fail:error];
        }
    }];
}

+ (NSString *)_hashForVideoWithFileData:(NSData *)fileData timingData:(NSData *)timingData preset:(TGMediaVideoConversionPreset)preset
{
    const NSUInteger bufSize = 1024;
    NSUInteger numberOfBuffersToRead = MIN(32, floor(fileData.length / bufSize));
    uint8_t buf[bufSize];
    NSUInteger size = fileData.length;
    
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    
    CC_MD5_Update(&md5, &size, sizeof(size));
    const char *SDString = "SD";
    CC_MD5_Update(&md5, SDString, (CC_LONG)strlen(SDString));
    
    if (timingData != nil)
        CC_MD5_Update(&md5, timingData.bytes, (CC_LONG)timingData.length);
    
    NSMutableData *presetData = [[NSMutableData alloc] init];
    NSInteger presetValue = preset;
    [presetData appendBytes:&presetValue length:sizeof(NSInteger)];
    CC_MD5_Update(&md5, presetData.bytes, (CC_LONG)presetData.length);
    
    for (NSUInteger i = 0; (i < size) && (i < bufSize * numberOfBuffersToRead); i += bufSize)
    {
        [fileData getBytes:buf range:NSMakeRange(i, bufSize)];
        CC_MD5_Update(&md5, buf, bufSize);
    }
    
    for (NSUInteger i = size - MIN(size, bufSize * numberOfBuffersToRead); i < size; i += bufSize)
    {
        [fileData getBytes:buf range:NSMakeRange(i, bufSize)];
        CC_MD5_Update(&md5, buf, bufSize);
    }
    
    unsigned char md5Buffer[16];
    CC_MD5_Final(md5Buffer, &md5);
    NSString *hash = [[NSString alloc] initWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5Buffer[0], md5Buffer[1], md5Buffer[2], md5Buffer[3], md5Buffer[4], md5Buffer[5], md5Buffer[6], md5Buffer[7], md5Buffer[8], md5Buffer[9], md5Buffer[10], md5Buffer[11], md5Buffer[12], md5Buffer[13], md5Buffer[14], md5Buffer[15]];
    
    return hash;
}

+ (TGMediaVideoConversionPreset)presetFromAdjustments:(TGMediaVideoEditAdjustments *)adjustments
{
    TGMediaVideoConversionPreset preset = adjustments.preset;
    if (preset == TGMediaVideoConversionPresetCompressedDefault)
    {
        NSNumber *presetValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"TG_preferredVideoPreset_v0"];
        preset = presetValue != nil ? (TGMediaVideoConversionPreset)presetValue.integerValue : TGMediaVideoConversionPresetCompressedMedium;
    }
    return preset;
}

#pragma mark - Miscellaneous

+ (CGSize)_renderSizeWithCropSize:(CGSize)cropSize
{
    return [self _renderSizeWithCropSize:cropSize rotateSideward:false];
}

+ (CGSize)_renderSizeWithCropSize:(CGSize)cropSize rotateSideward:(bool)rotateSideward
{
    const CGFloat blockSize = 16.0f;
    if (rotateSideward)
        cropSize = CGSizeMake(cropSize.height, cropSize.width);
    
    CGFloat renderWidth = CGFloor(cropSize.width / blockSize) * blockSize;
    CGFloat renderHeight = CGFloor(cropSize.height * renderWidth / cropSize.width);
    if (fmod(renderHeight, blockSize) != 0)
        renderHeight = CGFloor(cropSize.height / blockSize) * blockSize;
    return CGSizeMake(renderWidth, renderHeight);
}

+ (NSURL *)_randomTemporaryURL
{
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"%x.mp4", (int)arc4random()]]];
}

+ (NSUInteger)estimatedSizeForPreset:(TGMediaVideoConversionPreset)preset duration:(NSTimeInterval)duration hasAudio:(bool)hasAudio
{
    NSInteger bitrate = [TGMediaVideoConversionPresetSettings _videoBitrateKbpsForPreset:preset];
    if (hasAudio)
        bitrate += [TGMediaVideoConversionPresetSettings _audioBitrateKbpsForPreset:preset] * [TGMediaVideoConversionPresetSettings _audioChannelsCountForPreset:preset];
    
    NSInteger dataRate = bitrate * 1000 / 8;
    return (NSInteger)(dataRate * duration);
}

+ (TGMediaVideoConversionPreset)bestAvailablePresetForDimensions:(CGSize)dimensions
{
    TGMediaVideoConversionPreset preset = TGMediaVideoConversionPresetCompressedVeryHigh;
    CGFloat maxSide = MAX(dimensions.width, dimensions.height);
    for (NSInteger i = TGMediaVideoConversionPresetCompressedVeryHigh; i >= TGMediaVideoConversionPresetCompressedLow; i--)
    {
        CGFloat presetMaxSide = [TGMediaVideoConversionPresetSettings maximumSizeForPreset:(TGMediaVideoConversionPreset)i].width;
        preset = (TGMediaVideoConversionPreset)i;
        if (maxSide >= presetMaxSide)
            break;
    }
    return preset;
}

@end


static CGFloat progressOfSampleBufferInTimeRange(CMSampleBufferRef sampleBuffer, CMTimeRange timeRange)
{
    CMTime progressTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CMTime sampleDuration = CMSampleBufferGetDuration(sampleBuffer);
    if (CMTIME_IS_NUMERIC(sampleDuration))
        progressTime = CMTimeAdd(progressTime, sampleDuration);
    return MAX(0.0f, MIN(1.0f, CMTimeGetSeconds(progressTime) / CMTimeGetSeconds(timeRange.duration)));
}


@implementation TGMediaSampleBufferProcessor

- (instancetype)initWithAssetReaderOutput:(AVAssetReaderOutput *)assetReaderOutput assetWriterInput:(AVAssetWriterInput *)assetWriterInput
{
    self = [super init];
    if (self != nil)
    {
        _assetReaderOutput = assetReaderOutput;
        _assetWriterInput = assetWriterInput;
        
        _queue = [[SQueue alloc] init];
        _finished = false;
        _succeed = false;
        _started = false;
    }
    return self;
}

- (void)startWithTimeRange:(CMTimeRange)timeRange progressBlock:(void (^)(CGFloat progress))progressBlock completionBlock:(void (^)(void))completionBlock
{
    _started = true;
    
    _completionBlock = [completionBlock copy];
    
    [_assetWriterInput requestMediaDataWhenReadyOnQueue:_queue._dispatch_queue usingBlock:^
    {
        if (_finished)
            return;
        
        bool ended = false;
        bool failed = false;
        while ([_assetWriterInput isReadyForMoreMediaData] && !ended && !failed)
        {
            CMSampleBufferRef sampleBuffer = [_assetReaderOutput copyNextSampleBuffer];
            if (sampleBuffer != NULL)
            {
                if (progressBlock != nil)
                    progressBlock(progressOfSampleBufferInTimeRange(sampleBuffer, timeRange));
                
                bool success = false;
                @try {
                    success = [_assetWriterInput appendSampleBuffer:sampleBuffer];
                } @catch (NSException *exception) {
                    if ([exception.name isEqualToString:NSInternalInconsistencyException])
                        success = false;
                } @finally {
                    CFRelease(sampleBuffer);
                }
                
                failed = !success;
            }
            else
            {
                ended = true;
            }
        }
        
        if (ended || failed)
        {
            _succeed = !failed;
            [self _finish];
        }
    }];
}

- (void)cancel
{
    [_queue dispatch:^
    {
        [self _finish];
    } synchronous:true];
}

- (void)_finish
{
    bool didFinish = _finished;
    _finished = true;
    
    if (!didFinish)
    {
        if (_started)
            [_assetWriterInput markAsFinished];
        
        if (_completionBlock != nil)
        {
            void (^completionBlock)(void) = [_completionBlock copy];
            _completionBlock = nil;
            completionBlock();
        }
    }
}

@end


@implementation TGMediaVideoFileWatcher

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _queue = [[SQueue alloc] init];
    }
    return self;
}

- (void)dealloc
{
    dispatch_source_t readerSource = _readerSource;
    
    [_queue dispatch:^
    {
        if (readerSource != nil)
            dispatch_source_cancel(readerSource);
    }];
}

- (void)setupWithFileURL:(NSURL *)fileURL
{
    if (_fileURL != nil)
        return;
    
    _fileURL = fileURL;
    _readerSource = [self _setup];
}

- (dispatch_source_t)_setup
{
    int fd = open([_fileURL.path UTF8String], O_NONBLOCK | O_RDONLY);
    if (fd > 0)
    {
        dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue._dispatch_queue);
        
        int32_t interval = 1;
        dispatch_source_set_timer(source, dispatch_time(DISPATCH_TIME_NOW, interval * NSEC_PER_SEC), interval * NSEC_PER_SEC, (1ull * NSEC_PER_SEC) / 10);
        
        __block NSUInteger lastFileSize = 0;
        __weak TGMediaVideoFileWatcher *weakSelf = self;
        dispatch_source_set_event_handler(source, ^
        {
            __strong TGMediaVideoFileWatcher *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            struct stat st;
            fstat(fd, &st);
            
            if (st.st_size > (long long)(lastFileSize + 32 * 1024))
            {
                lastFileSize = (NSUInteger)st.st_size;
                [strongSelf fileUpdated:false];
            }
        });
        
        dispatch_source_set_cancel_handler(source,^
        {
            close(fd);
        });
        
        dispatch_resume(source);
        
        return source;
    }
    
    return nil;
}

- (id)fileUpdated:(bool)__unused completed
{
    return nil;
}

@end


@implementation TGMediaVideoConversionContext

+ (instancetype)contextWithQueue:(SQueue *)queue subscriber:(SSubscriber *)subscriber
{
    TGMediaVideoConversionContext *context = [[TGMediaVideoConversionContext alloc] init];
    context->_queue = queue;
    context->_subscriber = subscriber;
    return context;
}

- (instancetype)cancelledContext
{
    TGMediaVideoConversionContext *context = [[TGMediaVideoConversionContext alloc] init];
    context->_queue = _queue;
    context->_subscriber = _subscriber;
    context->_cancelled = true;
    context->_assetReader = _assetReader;
    context->_assetWriter = _assetWriter;
    context->_videoProcessor = _videoProcessor;
    context->_audioProcessor = _audioProcessor;
    context->_timeRange = _timeRange;
    context->_dimensions = _dimensions;
    context->_coverImage = _coverImage;
    context->_imageGenerator = _imageGenerator;
    context->_entityRenderer = _entityRenderer;
    return context;
}

- (instancetype)finishedContext
{
    TGMediaVideoConversionContext *context = [[TGMediaVideoConversionContext alloc] init];
    context->_queue = _queue;
    context->_subscriber = _subscriber;
    context->_cancelled = false;
    context->_finished = true;
    context->_assetReader = _assetReader;
    context->_assetWriter = _assetWriter;
    context->_videoProcessor = _videoProcessor;
    context->_audioProcessor = _audioProcessor;
    context->_timeRange = _timeRange;
    context->_dimensions = _dimensions;
    context->_coverImage = _coverImage;
    context->_imageGenerator = _imageGenerator;
    context->_entityRenderer = _entityRenderer;
    return context;
}

- (instancetype)addImageGenerator:(AVAssetImageGenerator *)imageGenerator
{
    TGMediaVideoConversionContext *context = [[TGMediaVideoConversionContext alloc] init];
    context->_queue = _queue;
    context->_subscriber = _subscriber;
    context->_cancelled = _cancelled;
    context->_assetReader = _assetReader;
    context->_assetWriter = _assetWriter;
    context->_videoProcessor = _videoProcessor;
    context->_audioProcessor = _audioProcessor;
    context->_timeRange = _timeRange;
    context->_dimensions = _dimensions;
    context->_coverImage = _coverImage;
    context->_imageGenerator = imageGenerator;
    context->_entityRenderer = _entityRenderer;
    return context;
}

- (instancetype)addCoverImage:(UIImage *)coverImage
{
    TGMediaVideoConversionContext *context = [[TGMediaVideoConversionContext alloc] init];
    context->_queue = _queue;
    context->_subscriber = _subscriber;
    context->_cancelled = _cancelled;
    context->_assetReader = _assetReader;
    context->_assetWriter = _assetWriter;
    context->_videoProcessor = _videoProcessor;
    context->_audioProcessor = _audioProcessor;
    context->_timeRange = _timeRange;
    context->_dimensions = _dimensions;
    context->_coverImage = coverImage;
    context->_imageGenerator = _imageGenerator;
    context->_entityRenderer = _entityRenderer;
    return context;
}

- (instancetype)contextWithAssetReader:(AVAssetReader *)assetReader assetWriter:(AVAssetWriter *)assetWriter videoProcessor:(TGMediaSampleBufferProcessor *)videoProcessor audioProcessor:(TGMediaSampleBufferProcessor *)audioProcessor timeRange:(CMTimeRange)timeRange dimensions:(CGSize)dimensions entityRenderer:(id<TGPhotoPaintEntityRenderer>)entityRenderer
{
    TGMediaVideoConversionContext *context = [[TGMediaVideoConversionContext alloc] init];
    context->_queue = _queue;
    context->_subscriber = _subscriber;
    context->_cancelled = _cancelled;
    context->_assetReader = assetReader;
    context->_assetWriter = assetWriter;
    context->_videoProcessor = videoProcessor;
    context->_audioProcessor = audioProcessor;
    context->_timeRange = timeRange;
    context->_dimensions = dimensions;
    context->_coverImage = _coverImage;
    context->_imageGenerator = _imageGenerator;
    context->_entityRenderer = entityRenderer;
    return context;
}

@end


@implementation TGMediaVideoConversionResult

+ (instancetype)resultWithFileURL:(NSURL *)fileUrl fileSize:(NSUInteger)fileSize duration:(NSTimeInterval)duration dimensions:(CGSize)dimensions coverImage:(UIImage *)coverImage liveUploadData:(id)liveUploadData
{
    TGMediaVideoConversionResult *result = [[TGMediaVideoConversionResult alloc] init];
    result->_fileURL = fileUrl;
    result->_fileSize = fileSize;
    result->_duration = duration;
    result->_dimensions = dimensions;
    result->_coverImage = coverImage;
    result->_liveUploadData = liveUploadData;
    return result;
}

- (NSDictionary *)dictionary
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    dict[@"fileUrl"] = self.fileURL;
    dict[@"dimensions"] = [NSValue valueWithCGSize:self.dimensions];
    dict[@"duration"] = @(self.duration);
    if (self.coverImage != nil)
        dict[@"previewImage"] = self.coverImage;
    if (self.liveUploadData != nil)
        dict[@"liveUploadData"] = self.liveUploadData;
    return dict;
}

@end


@implementation TGMediaVideoConversionPresetSettings

+ (CGSize)maximumSizeForPreset:(TGMediaVideoConversionPreset)preset
{
    switch (preset)
    {
        case TGMediaVideoConversionPresetCompressedVeryLow:
            return (CGSize){ 480.0f, 480.0f };
            
        case TGMediaVideoConversionPresetCompressedLow:
            return (CGSize){ 640.0f, 640.0f };
            
        case TGMediaVideoConversionPresetCompressedMedium:
            return (CGSize){ 848.0f, 848.0f };
            
        case TGMediaVideoConversionPresetCompressedHigh:
            return (CGSize){ 1280.0f, 1280.0f };
            
        case TGMediaVideoConversionPresetCompressedVeryHigh:
            return (CGSize){ 1920.0f, 1920.0f };
            
        case TGMediaVideoConversionPresetVideoMessage:
            return (CGSize){ 384.0f, 384.0f };
        
        case TGMediaVideoConversionPresetProfileLow:
            return (CGSize){ 720.0f, 720.0f };
            
        case TGMediaVideoConversionPresetProfile:
        case TGMediaVideoConversionPresetProfileHigh:
        case TGMediaVideoConversionPresetProfileVeryHigh:
            return (CGSize){ 800.0f, 800.0f };
            
        default:
            return (CGSize){ 848.0f, 848.0f };
    }
}

+ (bool)keepAudioForPreset:(TGMediaVideoConversionPreset)preset
{
    return preset != TGMediaVideoConversionPresetAnimation && preset != TGMediaVideoConversionPresetProfile && preset != TGMediaVideoConversionPresetProfileLow && preset != TGMediaVideoConversionPresetProfileHigh && preset != TGMediaVideoConversionPresetProfileVeryHigh;
}

+ (NSDictionary *)audioSettingsForPreset:(TGMediaVideoConversionPreset)preset
{
    NSInteger bitrate = [self _audioBitrateKbpsForPreset:preset];
    NSInteger channels = [self _audioChannelsCountForPreset:preset];
    
    AudioChannelLayout acl;
    bzero(&acl, sizeof(acl));
    acl.mChannelLayoutTag = channels > 1 ? kAudioChannelLayoutTag_Stereo : kAudioChannelLayoutTag_Mono;
    
    return @
    {
    AVFormatIDKey: @(kAudioFormatMPEG4AAC),
    AVSampleRateKey: @44100.0f,
    AVEncoderBitRateKey: @(bitrate * 1000),
    AVNumberOfChannelsKey: @(channels),
    AVChannelLayoutKey: [NSData dataWithBytes:&acl length:sizeof(acl)]
    };
}

+ (NSDictionary *)videoSettingsForPreset:(TGMediaVideoConversionPreset)preset dimensions:(CGSize)dimensions
{
    NSDictionary *videoCleanApertureSettings = @
    {
    AVVideoCleanApertureWidthKey: @((NSInteger)dimensions.width),
    AVVideoCleanApertureHeightKey: @((NSInteger)dimensions.height),
    AVVideoCleanApertureHorizontalOffsetKey: @10,
    AVVideoCleanApertureVerticalOffsetKey: @10
    };
    
    NSDictionary *videoAspectRatioSettings = @
    {
    AVVideoPixelAspectRatioHorizontalSpacingKey: @3,
    AVVideoPixelAspectRatioVerticalSpacingKey: @3
    };
    
    NSDictionary *codecSettings = @
    {
    AVVideoAverageBitRateKey: @([self _videoBitrateKbpsForPreset:preset] * 1000),
    AVVideoCleanApertureKey: videoCleanApertureSettings,
    AVVideoPixelAspectRatioKey: videoAspectRatioSettings,
    AVVideoExpectedSourceFrameRateKey: @30
    };
    
    NSDictionary *hdVideoProperties = @
    {
    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
    };
    
#if TARGET_IPHONE_SIMULATOR
    return @
    {
    AVVideoCodecKey: AVVideoCodecH264,
    AVVideoCompressionPropertiesKey: codecSettings,
    AVVideoWidthKey: @((NSInteger)dimensions.width),
    AVVideoHeightKey: @((NSInteger)dimensions.height)
    };
#endif
    return @
    {
    AVVideoCodecKey: AVVideoCodecH264,
    AVVideoCompressionPropertiesKey: codecSettings,
    AVVideoWidthKey: @((NSInteger)dimensions.width),
    AVVideoHeightKey: @((NSInteger)dimensions.height),
    AVVideoColorPropertiesKey: hdVideoProperties
    };
}

+ (NSInteger)_videoBitrateKbpsForPreset:(TGMediaVideoConversionPreset)preset
{
    switch (preset)
    {
        case TGMediaVideoConversionPresetCompressedVeryLow:
            return 400;
            
        case TGMediaVideoConversionPresetCompressedLow:
            return 700;
            
        case TGMediaVideoConversionPresetCompressedMedium:
            return 1100;
            
        case TGMediaVideoConversionPresetCompressedHigh:
            return 2500;
            
        case TGMediaVideoConversionPresetCompressedVeryHigh:
            return 4000;
            
        case TGMediaVideoConversionPresetVideoMessage:
            return 1000;
            
        case TGMediaVideoConversionPresetProfile:
            return 1500;
            
        case TGMediaVideoConversionPresetProfileLow:
            return 1100;
            
        case TGMediaVideoConversionPresetProfileHigh:
            return 2000;
            
        case TGMediaVideoConversionPresetProfileVeryHigh:
            return 2400;
            
        default:
            return 900;
    }
}

+ (NSInteger)_audioBitrateKbpsForPreset:(TGMediaVideoConversionPreset)preset
{
    switch (preset)
    {
        case TGMediaVideoConversionPresetCompressedVeryLow:
            return 32;
            
        case TGMediaVideoConversionPresetCompressedLow:
            return 32;
            
        case TGMediaVideoConversionPresetCompressedMedium:
            return 64;
            
        case TGMediaVideoConversionPresetCompressedHigh:
            return 64;
            
        case TGMediaVideoConversionPresetCompressedVeryHigh:
            return 64;
            
        case TGMediaVideoConversionPresetVideoMessage:
            return 64;
            
        case TGMediaVideoConversionPresetAnimation:
        case TGMediaVideoConversionPresetProfile:
        case TGMediaVideoConversionPresetProfileLow:
        case TGMediaVideoConversionPresetProfileHigh:
        case TGMediaVideoConversionPresetProfileVeryHigh:
            return 0;
            
        default:
            return 32;
    }
}

+ (NSInteger)_audioChannelsCountForPreset:(TGMediaVideoConversionPreset)preset
{
    switch (preset)
    {
        case TGMediaVideoConversionPresetCompressedVeryLow:
            return 1;
            
        case TGMediaVideoConversionPresetCompressedLow:
            return 1;
            
        case TGMediaVideoConversionPresetCompressedMedium:
            return 2;
            
        case TGMediaVideoConversionPresetCompressedHigh:
            return 2;
            
        case TGMediaVideoConversionPresetCompressedVeryHigh:
            return 2;
            
        case TGMediaVideoConversionPresetAnimation:
        case TGMediaVideoConversionPresetProfile:
        case TGMediaVideoConversionPresetProfileLow:
        case TGMediaVideoConversionPresetProfileHigh:
        case TGMediaVideoConversionPresetProfileVeryHigh:
            return 0;
            
        default:
            return 1;
    }
}

@end
