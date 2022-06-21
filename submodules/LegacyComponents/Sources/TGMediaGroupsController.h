#import <LegacyComponents/TGViewController.h>

#import <LegacyComponents/TGMediaAssetsController.h>

@interface TGMediaGroupsController : TGViewController

@property (nonatomic, assign) bool localMediaCacheEnabled;
@property (nonatomic, assign) bool liveVideoUploadEnabled;
@property (nonatomic, assign) bool captionsEnabled;
@property (nonatomic, assign) CGFloat topInset;

@property (nonatomic, strong) TGMediaAssetsPallete *pallete;

@property (nonatomic, copy) void (^openAssetGroup)(TGMediaAssetGroup *);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context assetsLibrary:(TGMediaAssetsLibrary *)assetsLibrary intent:(TGMediaAssetsControllerIntent)intent;

@end
