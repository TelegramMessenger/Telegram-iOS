#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <LegacyComponents/LegacyComponentsAccessChecker.h>
#import <LegacyComponents/LegacyHTTPRequestOperation.h>

@class SSignal;
@class SThreadPool;
@protocol SDisposable;
@class TGLocalization;
@class UIViewController;
@class TGMemoryImageCache;
@class TGImageMediaAttachment;
@class TGNavigationBarPallete;
@class TGMenuSheetPallete;
@class TGMediaAssetsPallete;
@class TGImageBorderPallete;
@class TGCheckButtonPallete;

typedef enum {
    TGAudioSessionTypePlayVoice,
    TGAudioSessionTypePlayMusic,
    TGAudioSessionTypePlayVideo,
    TGAudioSessionTypePlayEmbedVideo,
    TGAudioSessionTypePlayAndRecord,
    TGAudioSessionTypePlayAndRecordHeadphones,
    TGAudioSessionTypeCall
} TGAudioSessionType;

@protocol LegacyComponentsGlobalsProvider <NSObject>

- (void)makeViewDisableInteractiveKeyboardGestureRecognizer:(UIView *)view;

- (TGLocalization *)effectiveLocalization;
- (void)log:(NSString *)string;
- (NSArray<UIWindow *> *)applicationWindows;
- (UIWindow *)applicationStatusBarWindow;
- (UIWindow *)applicationKeyboardWindow;
- (UIApplication *)applicationInstance;

- (UIInterfaceOrientation)applicationStatusBarOrientation;
- (CGRect)statusBarFrame;
- (bool)isStatusBarHidden;
- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation;
- (UIStatusBarStyle)statusBarStyle;
- (void)setStatusBarStyle:(UIStatusBarStyle)statusBarStyle animated:(BOOL)animated;
- (void)forceStatusBarAppearanceUpdate;

- (bool)canOpenURL:(NSURL *)url;
- (void)openURL:(NSURL *)url;
- (void)openURLNative:(NSURL *)url;

- (void)disableUserInteractionFor:(NSTimeInterval)timeInterval;
- (void)setIdleTimerDisabled:(bool)value;

- (void)pauseMusicPlayback;

- (NSString *)dataStoragePath;
- (NSString *)dataCachePath;

- (id<LegacyComponentsAccessChecker>)accessChecker;

- (id<SDisposable>)requestAudioSession:(TGAudioSessionType)type interrupted:(void (^)())interrupted;

- (SThreadPool *)sharedMediaImageProcessingThreadPool;
- (TGMemoryImageCache *)sharedMediaMemoryImageCache;
- (SSignal *)squarePhotoThumbnail:(TGImageMediaAttachment *)imageAttachment ofSize:(CGSize)size threadPool:(SThreadPool *)threadPool memoryCache:(TGMemoryImageCache *)memoryCache pixelProcessingBlock:(void (^)(void *, int, int, int))pixelProcessingBlock downloadLargeImage:(bool)downloadLargeImage placeholder:(SSignal *)placeholder;

- (NSString *)localDocumentDirectoryForLocalDocumentId:(int64_t)localDocumentId version:(int32_t)version;
- (NSString *)localDocumentDirectoryForDocumentId:(int64_t)documentId version:(int32_t)version;

- (void)pausePictureInPicturePlayback;
- (void)resumePictureInPicturePlayback;
- (void)maybeReleaseVolumeOverlay;

- (TGNavigationBarPallete *)navigationBarPallete;
- (TGMenuSheetPallete *)menuSheetPallete;
- (TGMenuSheetPallete *)darkMenuSheetPallete;
- (TGMediaAssetsPallete *)mediaAssetsPallete;
- (TGCheckButtonPallete *)checkButtonPallete;

@optional
- (TGImageBorderPallete *)imageBorderPallete;

@end

@interface LegacyComponentsGlobals : NSObject

+ (void)setProvider:(id<LegacyComponentsGlobalsProvider>)provider;
+ (id<LegacyComponentsGlobalsProvider>)provider;

@end

#ifdef __cplusplus
extern "C" {
#endif
UIImage *TGComponentsImageNamed(NSString *name);
NSString *TGComponentsPathForResource(NSString *name, NSString *type);
#ifdef __cplusplus
}
#endif

