#import "TGMediaAsset+TGMediaEditableItem.h"
#import <LegacyComponents/TGMediaAssetImageSignals.h>

#import <LegacyComponents/LegacyComponents.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>

@implementation TGMediaAsset (TGMediaEditableItem)

- (NSString *)uniqueIdentifier
{
    return self.identifier;
}

- (CGSize)originalSize
{
    if (![TGMediaAssetImageSignals usesPhotoFramework])
        return TGFitSize(self.dimensions, TGMediaAssetImageLegacySizeLimit);
    
    return self.dimensions;
}

- (NSTimeInterval)originalDuration
{
    return self.videoDuration;
}

- (SSignal *)thumbnailImageSignal
{
    CGFloat scale = MIN(2.0f, TGScreenScaling());
    CGFloat thumbnailImageSide = TGPhotoThumbnailSizeForCurrentScreen().width * scale;
    
    return [TGMediaAssetImageSignals imageForAsset:self imageType:TGMediaAssetImageTypeAspectRatioThumbnail size:CGSizeMake(thumbnailImageSide, thumbnailImageSide)];
}

- (SSignal *)screenImageSignal:(NSTimeInterval)__unused position
{
    return [TGMediaAssetImageSignals imageForAsset:self imageType:TGMediaAssetImageTypeScreen size:TGPhotoEditorScreenImageMaxSize()];
}

- (SSignal *)originalImageSignal:(NSTimeInterval)position
{
    if (self.isVideo)
        return [TGMediaAssetImageSignals videoThumbnailForAsset:self size:self.dimensions timestamp:CMTimeMakeWithSeconds(position, NSEC_PER_SEC)];
    
    return [[TGMediaAssetImageSignals imageForAsset:self imageType:TGMediaAssetImageTypeFullSize size:CGSizeZero] takeLast];
}

@end
