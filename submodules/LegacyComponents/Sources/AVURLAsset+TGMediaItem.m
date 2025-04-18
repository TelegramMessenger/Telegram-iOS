#import "AVURLAsset+TGMediaItem.h"
#import <LegacyComponents/TGMediaAssetImageSignals.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>

@implementation AVURLAsset (TGMediaItem)

- (bool)isVideo
{
    return true;
}

- (NSString *)uniqueIdentifier
{
    return self.URL.absoluteString;
}

- (CGSize)originalSize
{
    AVAssetTrack *track = [self tracksWithMediaType:AVMediaTypeVideo].firstObject;
    return CGRectApplyAffineTransform((CGRect){ CGPointZero, track.naturalSize }, track.preferredTransform).size;
}

- (SSignal *)thumbnailImageSignal
{
    CGFloat thumbnailImageSide = TGPhotoThumbnailSizeForCurrentScreen().width;
    CGSize size = TGScaleToSize(self.originalSize, CGSizeMake(thumbnailImageSide, thumbnailImageSide));
    
    return [TGMediaAssetImageSignals videoThumbnailForAVAsset:self size:size timestamp:kCMTimeZero];
}

- (SSignal *)screenImageSignal:(NSTimeInterval)__unused position
{
    return nil;
}

- (SSignal *)originalImageSignal:(NSTimeInterval)__unused position
{
    return nil;
}

@end
