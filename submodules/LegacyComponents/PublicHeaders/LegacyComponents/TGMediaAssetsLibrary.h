#import <SSignalKit/SSignalKit.h>

#import <LegacyComponents/TGMediaAsset.h>
#import <LegacyComponents/TGMediaAssetGroup.h>
#import <LegacyComponents/TGMediaAssetFetchResult.h>

typedef enum
{
    TGMediaLibraryAuthorizationStatusNotDetermined,
    TGMediaLibraryAuthorizationStatusRestricted,
    TGMediaLibraryAuthorizationStatusDenied,
    TGMediaLibraryAuthorizationStatusLimited,
    TGMediaLibraryAuthorizationStatusAuthorized
} TGMediaLibraryAuthorizationStatus;

static TGMediaLibraryAuthorizationStatus TGMediaLibraryCachedAuthorizationStatus = TGMediaLibraryAuthorizationStatusNotDetermined;

@interface TGMediaAssetsLibrary : NSObject
{
    SQueue *_queue;
}

@property (nonatomic, readonly) TGMediaAssetType assetType;

- (instancetype)initForAssetType:(TGMediaAssetType)assetType;
+ (instancetype)libraryForAssetType:(TGMediaAssetType)assetType;

- (SSignal *)assetWithIdentifier:(NSString *)identifier;

- (SSignal *)assetGroups;
- (SSignal *)cameraRollGroup;

- (SSignal *)assetsOfAssetGroup:(TGMediaAssetGroup *)assetGroup reversed:(bool)reversed;

- (SSignal *)libraryChanged;
- (SSignal *)updatedAssetsForAssets:(NSArray *)assets;

- (SSignal *)saveAssetWithImage:(UIImage *)image;
- (SSignal *)saveAssetWithImageData:(NSData *)imageData;
- (SSignal *)saveAssetWithImageAtUrl:(NSURL *)url;
- (SSignal *)saveAssetWithVideoAtUrl:(NSURL *)url;
- (SSignal *)_saveAssetWithUrl:(NSURL *)url isVideo:(bool)isVideo;

+ (instancetype)sharedLibrary;

+ (bool)usesPhotoFramework;

+ (SSignal *)authorizationStatusSignal;
+ (void)requestAuthorizationForAssetType:(TGMediaAssetType)assetType completion:(void (^)(TGMediaLibraryAuthorizationStatus status, TGMediaAssetGroup *cameraRollGroup))completion;
+ (TGMediaLibraryAuthorizationStatus)authorizationStatus;

@end

NSInteger TGMediaAssetGroupComparator(TGMediaAssetGroup *group1, TGMediaAssetGroup *group2, void *context);

extern NSString *const TGMediaAssetsKey;
extern NSString *const TGMediaChangesKey;
