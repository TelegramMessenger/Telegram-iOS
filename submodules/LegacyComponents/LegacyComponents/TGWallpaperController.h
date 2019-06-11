#import <LegacyComponents/TGViewController.h>
#import <LegacyComponents/LegacyComponentsContext.h>
#import <LegacyComponents/ASWatcher.h>

@class TGWallpaperInfo;
@class TGWallpaperController;
@class TGPresentation;

@protocol TGWallpaperControllerDelegate <NSObject>

@optional

- (void)wallpaperController:(TGWallpaperController *)wallpaperController didSelectWallpaperWithInfo:(TGWallpaperInfo *)wallpaperInfo;

@end

@interface TGWallpaperController : TGViewController <ASWatcher>

@property (nonatomic, strong) ASHandle *actionHandle;

@property (nonatomic, weak) id<TGWallpaperControllerDelegate> delegate;
@property (nonatomic) bool enableWallpaperAdjustment;
@property (nonatomic, strong) TGPresentation *presentation;

@property (nonatomic, copy) void (^customDismiss)();

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context wallpaperInfo:(TGWallpaperInfo *)wallpaperInfo thumbnailImage:(UIImage *)thumbnailImage;

@end
