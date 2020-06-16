#import <Photos/Photos.h>

#import <LegacyComponents/TGMediaAsset.h>

typedef enum
{
    TGMediaAssetGroupSubtypeNone = 0,
    TGMediaAssetGroupSubtypeCameraRoll,
    TGMediaAssetGroupSubtypeMyPhotoStream,
    TGMediaAssetGroupSubtypeFavorites,
    TGMediaAssetGroupSubtypeSelfPortraits,
    TGMediaAssetGroupSubtypePanoramas,
    TGMediaAssetGroupSubtypeVideos,
    TGMediaAssetGroupSubtypeSlomo,
    TGMediaAssetGroupSubtypeTimelapses,
    TGMediaAssetGroupSubtypeBursts,
    TGMediaAssetGroupSubtypeScreenshots,
    TGMediaAssetGroupSubtypeAnimated,
    TGMediaAssetGroupSubtypeRegular,
    TGMediaAssetGroupSubtypeHidden
} TGMediaAssetGroupSubtype;

@interface TGMediaAssetGroup : NSObject

@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSInteger assetCount;
@property (nonatomic, readonly) TGMediaAssetGroupSubtype subtype;
@property (nonatomic, readonly) bool isCameraRoll;
@property (nonatomic, readonly) bool isPhotoStream;
@property (nonatomic, readonly) bool isReversed;

@property (nonatomic, readonly) PHFetchResult *backingFetchResult;
@property (nonatomic, readonly) PHAssetCollection *backingAssetCollection;

- (instancetype)initWithPHFetchResult:(PHFetchResult *)fetchResult;
- (instancetype)initWithPHAssetCollection:(PHAssetCollection *)collection fetchResult:(PHFetchResult *)fetchResult;

- (NSArray *)latestAssets;

+ (bool)_isSmartAlbumCollectionSubtype:(PHAssetCollectionSubtype)subtype requiredForAssetType:(TGMediaAssetType)assetType;

@end
