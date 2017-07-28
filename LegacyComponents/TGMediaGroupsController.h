#import <LegacyComponents/LegacyComponents.h>

#import <LegacyComponents/TGMediaAssetsController.h>

@interface TGMediaGroupsController : TGViewController

@property (nonatomic, strong) TGSuggestionContext *suggestionContext;
@property (nonatomic, assign) bool localMediaCacheEnabled;
@property (nonatomic, assign) bool liveVideoUploadEnabled;
@property (nonatomic, assign) bool captionsEnabled;

@property (nonatomic, copy) void (^openAssetGroup)(TGMediaAssetGroup *);

- (instancetype)initWithAssetsLibrary:(TGMediaAssetsLibrary *)assetsLibrary intent:(TGMediaAssetsControllerIntent)intent;

@end
