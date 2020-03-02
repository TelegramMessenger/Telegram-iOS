#import "TGCameraCapturedVideo.h"
#import <AVFoundation/AVFoundation.h>
#import <LegacyComponents/TGMediaAssetImageSignals.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>

@interface TGCameraCapturedVideo ()
{
    CGSize _cachedSize;
    NSTimeInterval _cachedDuration;
}
@end

@implementation TGCameraCapturedVideo

- (instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self != nil)
    {
        _avAsset = [[AVURLAsset alloc] initWithURL:url options:nil];
        _cachedSize = CGSizeZero;
        _cachedDuration = 0.0;
    }
    return self;
}

- (void)_cleanUp
{
    [[NSFileManager defaultManager] removeItemAtPath:_avAsset.URL.path error:nil];
}

- (bool)isVideo
{
    return true;
}

- (NSString *)uniqueIdentifier
{
    return _avAsset.URL.absoluteString;
}

- (CGSize)originalSize
{
    if (!CGSizeEqualToSize(_cachedSize, CGSizeZero))
        return _cachedSize;
    
    AVAssetTrack *track = _avAsset.tracks.firstObject;
    _cachedSize = CGRectApplyAffineTransform((CGRect){ CGPointZero, track.naturalSize }, track.preferredTransform).size;
    return _cachedSize;
}

- (NSTimeInterval)videoDuration
{
    return [self originalDuration];
}

- (NSTimeInterval)originalDuration
{
    if (_cachedDuration > DBL_EPSILON)
        return _cachedDuration;
    
    _cachedDuration = CMTimeGetSeconds(_avAsset.duration);
    return _cachedDuration;
}

- (SSignal *)thumbnailImageSignal
{
    CGFloat thumbnailImageSide = TGPhotoEditorScreenImageMaxSize().width;
    CGSize size = TGScaleToSize(self.originalSize, CGSizeMake(thumbnailImageSide, thumbnailImageSide));
    
    return [TGMediaAssetImageSignals videoThumbnailForAVAsset:_avAsset size:size timestamp:kCMTimeZero];
}

- (SSignal *)screenImageSignal:(NSTimeInterval)__unused position
{
    CGFloat imageSide = 1280.0f;
    CGSize size = TGScaleToSize(self.originalSize, CGSizeMake(imageSide, imageSide));
    
    return [TGMediaAssetImageSignals videoThumbnailForAVAsset:_avAsset size:size timestamp:kCMTimeZero];
}

- (SSignal *)originalImageSignal:(NSTimeInterval)position
{
    return [TGMediaAssetImageSignals videoThumbnailForAVAsset:_avAsset size:self.originalSize timestamp:CMTimeMakeWithSeconds(position, NSEC_PER_SEC)];
}

@end
