#import <AVFoundation/AVFoundation.h>
#import <LegacyComponents/TGMediaEditingContext.h>

typedef enum
{
    TGMediaVideoConversionPresetCompressedDefault,
    TGMediaVideoConversionPresetCompressedVeryLow,
    TGMediaVideoConversionPresetCompressedLow,
    TGMediaVideoConversionPresetCompressedMedium,
    TGMediaVideoConversionPresetCompressedHigh,
    TGMediaVideoConversionPresetCompressedVeryHigh,
    TGMediaVideoConversionPresetAnimation,
    TGMediaVideoConversionPresetVideoMessage
} TGMediaVideoConversionPreset;

@interface TGVideoEditAdjustments : NSObject <TGMediaEditAdjustments>

@property (nonatomic, readonly) NSTimeInterval trimStartValue;
@property (nonatomic, readonly) NSTimeInterval trimEndValue;
@property (nonatomic, readonly) TGMediaVideoConversionPreset preset;

- (CMTimeRange)trimTimeRange;

- (bool)trimApplied;

- (bool)isCropAndRotationEqualWith:(id<TGMediaEditAdjustments>)adjustments;

- (NSDictionary *)dictionary;

- (instancetype)editAdjustmentsWithPreset:(TGMediaVideoConversionPreset)preset maxDuration:(NSTimeInterval)maxDuration;
+ (instancetype)editAdjustmentsWithOriginalSize:(CGSize)originalSize preset:(TGMediaVideoConversionPreset)preset;

+ (instancetype)editAdjustmentsWithDictionary:(NSDictionary *)dictionary;

+ (instancetype)editAdjustmentsWithOriginalSize:(CGSize)originalSize
                                       cropRect:(CGRect)cropRect
                                cropOrientation:(UIImageOrientation)cropOrientation
                          cropLockedAspectRatio:(CGFloat)cropLockedAspectRatio
                                   cropMirrored:(bool)cropMirrored
                                 trimStartValue:(NSTimeInterval)trimStartValue
                                   trimEndValue:(NSTimeInterval)trimEndValue
                                   paintingData:(TGPaintingData *)paintingData
                                      sendAsGif:(bool)sendAsGif
                                         preset:(TGMediaVideoConversionPreset)preset;

@end

typedef TGVideoEditAdjustments TGMediaVideoEditAdjustments;

extern const NSTimeInterval TGVideoEditMinimumTrimmableDuration;
extern const NSTimeInterval TGVideoEditMaximumGifDuration;
