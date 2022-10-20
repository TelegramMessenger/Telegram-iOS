#import <SSignalKit/SSignalKit.h>

#import <LegacyComponents/TGVideoEditAdjustments.h>

@interface TGMediaVideoFileWatcher : NSObject
{
    NSURL *_fileURL;
}

- (void)setupWithFileURL:(NSURL *)fileURL;
- (id)fileUpdated:(bool)completed;

@end

@protocol TGPhotoPaintEntityRenderer;

@interface TGMediaVideoConverter : NSObject

+ (SSignal *)convertAVAsset:(AVAsset *)avAsset adjustments:(TGMediaVideoEditAdjustments *)adjustments watcher:(TGMediaVideoFileWatcher *)watcher entityRenderer:(id<TGPhotoPaintEntityRenderer>)entityRenderer;
+ (SSignal *)convertAVAsset:(AVAsset *)avAsset adjustments:(TGMediaVideoEditAdjustments *)adjustments watcher:(TGMediaVideoFileWatcher *)watcher inhibitAudio:(bool)inhibitAudio entityRenderer:(id<TGPhotoPaintEntityRenderer>)entityRenderer;
+ (SSignal *)hashForAVAsset:(AVAsset *)avAsset adjustments:(TGMediaVideoEditAdjustments *)adjustments;

+ (SSignal *)renderUIImage:(UIImage *)image duration:(NSTimeInterval)duration adjustments:(TGMediaVideoEditAdjustments *)adjustments watcher:(TGMediaVideoFileWatcher *)watcher entityRenderer:(id<TGPhotoPaintEntityRenderer>)entityRenderer;

+ (NSUInteger)estimatedSizeForPreset:(TGMediaVideoConversionPreset)preset duration:(NSTimeInterval)duration hasAudio:(bool)hasAudio;
+ (TGMediaVideoConversionPreset)bestAvailablePresetForDimensions:(CGSize)dimensions;
+ (CGSize)_renderSizeWithCropSize:(CGSize)cropSize;

+ (TGMediaVideoConversionPreset)presetFromAdjustments:(TGMediaVideoEditAdjustments *)adjustments;
+ (CGSize)dimensionsFor:(CGSize)dimensions adjustments:(TGMediaVideoEditAdjustments *)adjustments preset:(TGMediaVideoConversionPreset)preset;

@end


@interface TGMediaVideoConversionResult : NSObject

@property (nonatomic, readonly) NSURL *fileURL;
@property (nonatomic, readonly) NSUInteger fileSize;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) CGSize dimensions;
@property (nonatomic, readonly) UIImage *coverImage;
@property (nonatomic, readonly) id liveUploadData;

- (NSDictionary *)dictionary;

@end


@interface TGMediaVideoConversionPresetSettings : NSObject

+ (CGSize)maximumSizeForPreset:(TGMediaVideoConversionPreset)preset;
+ (NSDictionary *)videoSettingsForPreset:(TGMediaVideoConversionPreset)preset dimensions:(CGSize)dimensions;
+ (NSDictionary *)audioSettingsForPreset:(TGMediaVideoConversionPreset)preset;

@end
