#import <UIKit/UIKit.h>

#import <LegacyComponents/LegacyComponents.h>

#import <WebKit/WebKit.h>
#import <SSignalKit/SSignalKit.h>
#import <LegacyComponents/TGEmbedPlayerControls.h>
#import <LegacyComponents/TGMessageImageViewOverlayView.h>
#import <LegacyComponents/TGPIPAblePlayerView.h>

@class TGEmbedPlayerView;

@protocol TGEmbedPlayerWrapperView <NSObject>

- (void)reattachPlayerView;
- (void)reattachPlayerView:(TGEmbedPlayerView *)playerView;

@end

@interface TGEmbedPlayerView : UIView <TGPIPAblePlayerView>
{
    TGWebPageMediaAttachment *_webPage;
        
    TGMessageImageViewOverlayView *_overlayView;
    CGSize _embedSize;
}

@property (nonatomic, readonly) TGEmbedPlayerState *state;
@property (nonatomic, readonly) TGEmbedPlayerControls *controlsView;
@property (nonatomic, readonly) UIView *dimWrapperView;

@property (nonatomic, assign) bool disableWatermarkAction;
@property (nonatomic, assign) bool inhibitFullscreenButton;

@property (nonatomic, assign) UIRectCorner roundCorners;

@property (nonatomic, assign) bool disallowAutoplay;
@property (nonatomic, assign) bool disallowPIP;
@property (nonatomic, assign) bool disableControls;

@property (nonatomic, assign) CGRect initialFrame;

@property (nonatomic, copy) void (^onWatermarkAction)(void);

@property (nonatomic, copy) void (^requestFullscreen)(NSTimeInterval duration);
@property (nonatomic, copy) void (^onMetadataLoaded)(NSString *title, NSString *subtitle);

@property (nonatomic, copy) void (^onBeganLoading)(void);
@property (nonatomic, copy) void (^onBeganPlaying)(void);
@property (nonatomic, copy) void (^onRealLoadProgress)(CGFloat progress, NSTimeInterval duration);

- (instancetype)initWithWebPageAttachment:(TGWebPageMediaAttachment *)webPage;
- (instancetype)initWithWebPageAttachment:(TGWebPageMediaAttachment *)webPage thumbnailSignal:(SSignal *)thumbnailSignal;
- (instancetype)initWithWebPageAttachment:(TGWebPageMediaAttachment *)webPage thumbnailSignal:(SSignal *)thumbnailSignal alternateCachePathSignal:(SSignal *)alternateCachePathSignal;
- (void)setupWithEmbedSize:(CGSize)embedSize;

- (void)setDimmed:(bool)dimmed animated:(bool)animated shouldDelay:(bool)shouldDelay;
- (void)setCoverImage:(UIImage *)image;

- (void)pauseVideo:(bool)manually;

- (void)updateState:(TGEmbedPlayerState *)state;

- (void)hideControls;

- (void)enterFullscreen:(NSTimeInterval)duration;
- (void)enterPictureInPicture:(TGEmbedPIPCorner)corner;

- (void)_onPageReady;
- (void)_didBeginPlayback;
- (void)_onPanelAppearance;
- (void)_watermarkAction;

- (void)_openWebPage:(NSURL *)url;

- (bool)_scaleViewToMaxSize;

- (void)onLockInPlace;

- (bool)_useFakeLoadingProgress;
- (void)setLoadProgress:(CGFloat)value duration:(NSTimeInterval)duration;
- (void)setDimmed:(bool)dimmed animated:(bool)animated;

- (TGEmbedPlayerControlsType)_controlsType;
- (void)_evaluateJS:(NSString *)jsString completion:(void (^)(NSString *))completion;
- (NSURL *)_embedURL;
- (NSString *)_embedHTML;
- (NSURL *)_baseURL;
- (void)_notifyOfCallbackURL:(NSURL *)url;
- (void)_setupUserScripts:(WKUserContentController *)contentController;
- (bool)_applyViewportUserScript;
- (UIView *)_webView;
- (CGFloat)_compensationEdges;

- (void)_cleanWebView;

- (SSignal *)loadProgress;

+ (bool)_supportsWebPage:(TGWebPageMediaAttachment *)webPage;
+ (bool)hasNativeSupportForX:(TGWebPageMediaAttachment *)webPage;

+ (Class)playerViewClassForWebPage:(TGWebPageMediaAttachment *)webPage onlySpecial:(bool)onlySpecial;
+ (TGEmbedPlayerView *)makePlayerViewForWebPage:(TGWebPageMediaAttachment *)webPage thumbnailSignal:(SSignal *)signal;

@end
