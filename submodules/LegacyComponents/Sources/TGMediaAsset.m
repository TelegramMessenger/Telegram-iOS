#import "TGMediaAsset.h"
#import "TGMediaAssetImageSignals.h"

#import "LegacyComponentsInternal.h"

#import <MobileCoreServices/MobileCoreServices.h>

@interface TGMediaAsset ()
{
    NSNumber *_cachedType;
    
    NSString *_cachedUniqueId;
    NSURL *_cachedLegacyAssetUrl;
    NSNumber *_cachedLegacyVideoRotated;
    
    NSNumber *_cachedDuration;
}
@end

@implementation TGMediaAsset

- (instancetype)initWithPHAsset:(PHAsset *)asset
{
    self = [super init];
    if (self != nil)
    {
        _backingAsset = asset;
    }
    return self;
}

- (NSString *)identifier
{
    if (_cachedUniqueId == nil)
    {
        if (self.backingAsset != nil)
            _cachedUniqueId = self.backingAsset.localIdentifier;
    }
    
    return _cachedUniqueId;
}

- (CGSize)dimensions
{
    if (self.backingAsset != nil)
        return CGSizeMake(self.backingAsset.pixelWidth, self.backingAsset.pixelHeight);
    return CGSizeZero;
}

- (NSDate *)date
{
    if (self.backingAsset != nil)
        return self.backingAsset.creationDate;
    return nil;
}

- (bool)isVideo
{
    return self.type == TGMediaAssetVideoType;
}

- (bool)representsBurst
{
    return self.backingAsset.representsBurst;
}

- (NSInteger)fileSize {
    if (self.backingAsset != nil) {
        PHAssetResource *resource = [PHAssetResource assetResourcesForAsset:self.backingAsset].firstObject;
        if (resource != nil) {
            return [[resource valueForKey:@"fileSize"] integerValue];
        }
    }
    return 0;
}

- (NSString *)uniformTypeIdentifier
{
    if (self.backingAsset != nil)
        return [self.backingAsset valueForKey:@"uniformTypeIdentifier"];
    return nil;
}

- (NSString *)fileName
{
    if (self.backingAsset != nil) {
        NSString *fileName = [self.backingAsset valueForKey:@"filename"];
        if (fileName == nil) {
            NSArray *resources = [PHAssetResource assetResourcesForAsset:self.backingAsset];
            PHAssetResource *resource = resources.firstObject;
            if (resource != nil) {
                fileName = resource.originalFilename;
            }
        }
        return fileName;
    }
    return nil;
}

- (bool)_isGif
{
    return [self.uniformTypeIdentifier isEqualToString:(NSString *)kUTTypeGIF];
}

- (bool)isFavorite
{
    return _backingAsset.isFavorite;
}

- (TGMediaAssetType)type
{
    if (_cachedType == nil)
    {
        if (self.backingAsset != nil)
        {
            if ([self _isGif])
                _cachedType = @(TGMediaAssetGifType);
            else
                _cachedType = @([TGMediaAsset assetTypeForPHAssetMediaType:self.backingAsset.mediaType]);
        }
    }
    
    return _cachedType.intValue;
}

- (TGMediaAssetSubtype)subtypes
{
    TGMediaAssetSubtype subtypes = TGMediaAssetSubtypeNone;
    
    if (self.backingAsset != nil)
        subtypes = [TGMediaAsset assetSubtypesForPHAssetMediaSubtypes:self.backingAsset.mediaSubtypes];
    
    return subtypes;
}

- (NSTimeInterval)videoDuration
{
    if (self.backingAsset != nil)
        return self.backingAsset.duration;
    return 0;
}

- (SSignal *)actualVideoDuration
{
    if (!self.isVideo)
        return [SSignal fail:nil];
    
    if (_cachedDuration == nil)
    {
        NSTimeInterval assetDuration = self.videoDuration;
        return [[[TGMediaAssetImageSignals avAssetForVideoAsset:self] map:^id(AVAsset *asset)
        {
            NSTimeInterval duration = CMTimeGetSeconds(asset.duration);
            _cachedDuration = @(duration);
            return _cachedDuration;
        }] catch:^SSignal * _Nonnull(id  _Nullable error) {
            return [SSignal single:@(assetDuration)];
        }];
    }
    
    return [SSignal single:_cachedDuration];
}

+ (PHAssetMediaType)assetMediaTypeForAssetType:(TGMediaAssetType)assetType
{
    switch (assetType)
    {
        case TGMediaAssetPhotoType:
            return PHAssetMediaTypeImage;
            
        case TGMediaAssetVideoType:
            return PHAssetMediaTypeVideo;
            
        default:
            return PHAssetMediaTypeUnknown;
    }
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    
    return [self.identifier isEqual:((TGMediaAsset *)object).identifier];
}

+ (TGMediaAssetType)assetTypeForPHAssetMediaType:(PHAssetMediaType)type
{
    switch (type)
    {
        case PHAssetMediaTypeImage:
            return TGMediaAssetPhotoType;
            
        case PHAssetMediaTypeVideo:
            return TGMediaAssetVideoType;
            
        default:
            return TGMediaAssetAnyType;
    }
}

+ (TGMediaAssetSubtype)assetSubtypesForPHAssetMediaSubtypes:(PHAssetMediaSubtype) subtypes
{
    TGMediaAssetSubtype result = TGMediaAssetSubtypeNone;
    
    if (subtypes & PHAssetMediaSubtypePhotoPanorama)
        result |= TGMediaAssetSubtypePhotoPanorama;
    
    if (subtypes & PHAssetMediaSubtypePhotoHDR)
        result |= TGMediaAssetSubtypePhotoHDR;
    
    if (iosMajorVersion() >= 9 && subtypes & PHAssetMediaSubtypePhotoScreenshot)
        result |= TGMediaAssetSubtypePhotoScreenshot;
    
    if (subtypes & PHAssetMediaSubtypeVideoStreamed)
        result |= TGMediaAssetSubtypeVideoStreamed;
    
    if (subtypes & PHAssetMediaSubtypeVideoHighFrameRate)
        result |= TGMediaAssetSubtypeVideoHighFrameRate;
    
    if (subtypes & PHAssetMediaSubtypeVideoTimelapse)
        result |= TGMediaAssetSubtypeVideoTimelapse;
    
    if (subtypes & PHAssetMediaSubtypePhotoLive)
        result |= TGMediaAssetSubtypePhotoLive;
    
    if (subtypes & PHAssetMediaSubtypePhotoDepthEffect)
        result |= TGMediaAssetSubtypePhotoDepthEffect;
    
    return result;
}

- (NSString *)uniqueIdentifier
{
    return self.identifier;
}

@end
