#import <SSignalKit/SSignalKit.h>
#import <CoreMedia/CoreMedia.h>
#import <UIKit/UIKit.h>

@class TGMediaAsset;
@class AVPlayerItem;
@class AVAsset;

typedef enum
{
    TGMediaAssetImageTypeUndefined = 0,
    TGMediaAssetImageTypeThumbnail,
    TGMediaAssetImageTypeAspectRatioThumbnail,
    TGMediaAssetImageTypeScreen,
    TGMediaAssetImageTypeFastScreen,
    TGMediaAssetImageTypeLargeThumbnail,    
    TGMediaAssetImageTypeFastLargeThumbnail,
    TGMediaAssetImageTypeFullSize
} TGMediaAssetImageType;

@interface TGMediaAssetImageData : NSObject

@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *fileUTI;
@property (nonatomic, strong) NSData *imageData;

@end


@interface TGMediaAssetImageFileAttributes : NSObject

@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *fileUTI;
@property (nonatomic, assign) CGSize dimensions;
@property (nonatomic, assign) NSUInteger fileSize;

@end


@interface TGMediaAssetImageSignals : NSObject

+ (SSignal *)imageForAsset:(TGMediaAsset *)asset imageType:(TGMediaAssetImageType)imageType size:(CGSize)size;
+ (SSignal *)imageForAsset:(TGMediaAsset *)asset imageType:(TGMediaAssetImageType)imageType size:(CGSize)size allowNetworkAccess:(bool)allowNetworkAccess;

+ (SSignal *)livePhotoForAsset:(TGMediaAsset *)asset;
+ (SSignal *)livePhotoForAsset:(TGMediaAsset *)asset allowNetworkAccess:(bool)allowNetworkAccess;

+ (SSignal *)imageDataForAsset:(TGMediaAsset *)asset;
+ (SSignal *)imageDataForAsset:(TGMediaAsset *)asset allowNetworkAccess:(bool)allowNetworkAccess;
+ (SSignal *)imageDataForAsset:(TGMediaAsset *)asset allowNetworkAccess:(bool)allowNetworkAccess convertToJpeg:(bool)convertToJpeg;

+ (SSignal *)imageMetadataForAsset:(TGMediaAsset *)asset;
+ (SSignal *)fileAttributesForAsset:(TGMediaAsset *)asset;

+ (void)startCachingImagesForAssets:(NSArray *)assets imageType:(TGMediaAssetImageType)imageType size:(CGSize)size;
+ (void)stopCachingImagesForAssets:(NSArray *)assets imageType:(TGMediaAssetImageType)imageType size:(CGSize)size;
+ (void)stopCachingImagesForAllAssets;

+ (SSignal *)videoThumbnailsForAsset:(TGMediaAsset *)asset size:(CGSize)size timestamps:(NSArray *)timestamps;
+ (SSignal *)videoThumbnailsForAVAsset:(AVAsset *)avAsset size:(CGSize)size timestamps:(NSArray *)timestamps;
+ (SSignal *)videoThumbnailForAsset:(TGMediaAsset *)asset size:(CGSize)size timestamp:(CMTime)timestamp;
+ (SSignal *)videoThumbnailForAVAsset:(AVAsset *)avAsset size:(CGSize)size timestamp:(CMTime)timestamp;

+ (SSignal *)saveUncompressedVideoForAsset:(TGMediaAsset *)asset toPath:(NSString *)path;
+ (SSignal *)saveUncompressedVideoForAsset:(TGMediaAsset *)asset toPath:(NSString *)path allowNetworkAccess:(bool)allowNetworkAccess;

+ (SSignal *)playerItemForVideoAsset:(TGMediaAsset *)asset;
+ (SSignal *)avAssetForVideoAsset:(TGMediaAsset *)asset;
+ (SSignal *)avAssetForVideoAsset:(TGMediaAsset *)asset allowNetworkAccess:(bool)allowNetworkAccess;
+ (UIImageOrientation)videoOrientationOfAVAsset:(AVAsset *)avAsset;

+ (bool)usesPhotoFramework;

@end

extern const CGSize TGMediaAssetImageLegacySizeLimit;
