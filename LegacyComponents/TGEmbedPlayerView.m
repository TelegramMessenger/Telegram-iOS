#import "TGEmbedPlayerView.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGPhotoEditorUtils.h>

#import <LegacyComponents/TGImageView.h>

#import "TGEmbedPlayerState.h"

#import "TGEmbedYoutubePlayerView.h"
#import "TGEmbedVimeoPlayerView.h"
#import "TGEmbedCoubPlayerView.h"
#import "TGEmbedVKPlayerView.h"
#import "TGEmbedVinePlayerView.h"
#import "TGEmbedInstagramPlayerView.h"
#import "TGEmbedSoundCloudPlayerView.h"
#import "TGEmbedTwitchPlayerView.h"
#import "TGEmbedVideoPlayerView.h"

#import <libkern/OSAtomic.h>

@interface TGEmbedPlayerView () <UIWebViewDelegate, WKNavigationDelegate>
{
    CGFloat _embedScale;
    
    TGImageView *_coverView;
    UIView *_dimView;
    UILabel *_errorLabel;
    
    UIWebView *_uiWebView;
    WKWebView *_wkWebView;
    
    UIView *_interactionView;
    
    CGSize _maxPlayerSize;
    
    bool _loading;
    
    dispatch_semaphore_t _sema;
    SQueue *_jsQueue;
    
    SPipe *_statePipe;
    
    bool _pausedManually;
    bool _shouldResumePIPPlayback;
    
    id<SDisposable> _currentAudioSession;
    
    SVariable *_loadProgressValue;
}
@end

@implementation TGEmbedPlayerView

@synthesize requestPictureInPicture = _requestPictureInPicture;
@synthesize disallowPIP = _disallowPIP;
@synthesize initialFrame = _initialFrame;

- (instancetype)initWithWebPageAttachment:(TGWebPageMediaAttachment *)webPage
{
    return [self initWithWebPageAttachment:webPage thumbnailSignal:nil];
}

- (instancetype)initWithWebPageAttachment:(TGWebPageMediaAttachment *)webPage thumbnailSignal:(SSignal *)thumbnailSignal
{
    return [self initWithWebPageAttachment:webPage thumbnailSignal:nil alternateCachePathSignal:nil];
}

- (instancetype)initWithWebPageAttachment:(TGWebPageMediaAttachment *)webPage thumbnailSignal:(SSignal *)thumbnailSignal alternateCachePathSignal:(SSignal *)__unused alternateCachePathSignal
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        self.clipsToBounds = true;
        
        _statePipe = [[SPipe alloc] init];
        _loadProgressValue = [[SVariable alloc] init];
        
        _webPage = webPage;
        _state = [TGEmbedPlayerState stateWithPlaying:false duration:0.0 position:0.0 downloadProgress:0.0f buffering:false];
        
        TGEmbedPlayerControlsType controlsType = [self _controlsType];
        if (controlsType != TGEmbedPlayerControlsTypeNone)
        {
            __weak TGEmbedPlayerView *weakSelf = self;
            _controlsView = [[TGEmbedPlayerControls alloc] initWithFrame:CGRectZero type:controlsType];
            _controlsView.playPressed = ^
            {
                __strong TGEmbedPlayerView *strongSelf = weakSelf;
                if (strongSelf != nil)
                    [strongSelf playVideo];
            };
            _controlsView.pausePressed = ^
            {
                __strong TGEmbedPlayerView *strongSelf = weakSelf;
                if (strongSelf != nil)
                    [strongSelf pauseVideo];
            };
            _controlsView.seekToPosition = ^(CGFloat position)
            {
                __strong TGEmbedPlayerView *strongSelf = weakSelf;
                if (strongSelf != nil)
                    [strongSelf seekToFractPosition:position];
            };
            _controlsView.fullscreenPressed = ^
            {
                __strong TGEmbedPlayerView *strongSelf = weakSelf;
                if (strongSelf != nil)
                    [strongSelf enterFullscreen:0.0];
            };
            _controlsView.pictureInPicturePressed = ^
            {
                __strong TGEmbedPlayerView *strongSelf = weakSelf;
                if (strongSelf != nil)
                    [strongSelf _pictureInPicturePressed];
            };
            _controlsView.watermarkPressed = ^
            {
                __strong TGEmbedPlayerView *strongSelf = weakSelf;
                if (strongSelf != nil && !strongSelf.disableWatermarkAction)
                    [strongSelf _watermarkAction];
            };
            _controlsView.panelVisibilityChange = ^(bool hidden)
            {
                if (hidden)
                    return;
                
                __strong TGEmbedPlayerView *strongSelf = weakSelf;
                if (strongSelf != nil)
                    [strongSelf _onPanelAppearance];
            };
            [_controlsView setPictureInPictureHidden:![self supportsPIP]];
            [self addSubview:_controlsView];
        }
        
        CGSize imageSize = CGSizeZero;
        if (webPage.photo != nil)
            [webPage.photo.imageInfo closestImageUrlWithSize:CGSizeMake(1136, 1136) resultingSize:&imageSize];
        
        CGFloat imageAspect = imageSize.width / imageSize.height;
        CGSize fitSize = CGSizeMake(215.0f, 180.0f);
        if (ABS(imageAspect - 1.0f) < FLT_EPSILON)
            fitSize = CGSizeMake(215.0f, 215.0f);
        
        imageSize = TGScaleToFill(imageSize, fitSize);
        
        _dimWrapperView = [[UIView alloc] init];
        _dimWrapperView.backgroundColor = [UIColor blackColor];
        [self addSubview:_dimWrapperView];
        
        SSignal *coverSignal = thumbnailSignal ?: [[LegacyComponentsGlobals provider] squarePhotoThumbnail:webPage.photo ofSize:imageSize threadPool:[[LegacyComponentsGlobals provider] sharedMediaImageProcessingThreadPool] memoryCache:[[LegacyComponentsGlobals provider] sharedMediaMemoryImageCache] pixelProcessingBlock:nil downloadLargeImage:false placeholder:nil];
        
        _coverView = [[TGImageView alloc] init];
        _coverView.contentMode = UIViewContentModeScaleAspectFill;
        [_coverView setSignal:coverSignal];
        [_dimWrapperView addSubview:_coverView];
        
        _dimView = [[UIView alloc] init];
        _dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _dimView.backgroundColor = UIColorRGBA(0x000000, 0.5f);
        [_dimWrapperView addSubview:_dimView];
        
        _overlayView = [[TGMessageImageViewOverlayView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 44.0f, 44.0f)];
        [_overlayView setRadius:44.0f];
        [_dimWrapperView addSubview:_overlayView];
        
        _errorLabel = [[UILabel alloc] init];
        _errorLabel.backgroundColor = [UIColor clearColor];
        _errorLabel.font = TGSystemFontOfSize(16.0f);
        _errorLabel.hidden = true;
        _errorLabel.text = TGLocalized(@"Web.Error");
        _errorLabel.textColor = [UIColor whiteColor];
        [_errorLabel sizeToFit];
        [_dimWrapperView addSubview:_errorLabel];
        
        if (iosMajorVersion() >= 11)
        {
            _coverView.accessibilityIgnoresInvertColors = true;
            _dimView.accessibilityIgnoresInvertColors = true;
            _overlayView.accessibilityIgnoresInvertColors = true;
            _errorLabel.accessibilityIgnoresInvertColors = true;
        }
        
        _interactionView = [[UIView alloc] initWithFrame:self.bounds];
        _interactionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _interactionView.hidden = true;
        [self addSubview:_interactionView];
        
        _jsQueue = [[SQueue alloc] init];
        _sema = dispatch_semaphore_create(0);
    }
    return self;
}

- (void)dealloc
{
    WKWebView *wkWebView = _wkWebView;
    [_jsQueue dispatchSync:^
    {
        wkWebView.navigationDelegate = nil;
    }];
    
    _uiWebView.delegate = nil;
    
    [_currentAudioSession dispose];
    
    [[LegacyComponentsGlobals provider] resumePictureInPicturePlayback];
    
    TGDispatchAfter(0.1, dispatch_get_main_queue(), ^
    {
        [[LegacyComponentsGlobals provider] maybeReleaseVolumeOverlay];
    });
}

- (void)setDisallowPIP:(bool)disallowPIP
{
    _disallowPIP = disallowPIP;
    [_controlsView setPictureInPictureHidden:disallowPIP];
}

- (void)setDisallowAutoplay:(bool)disallowAutoplay
{
    _disallowAutoplay = disallowAutoplay;
    _dimView.hidden = true;
    
    [_controlsView showLargePlayButton:true];
    [self insertSubview:_dimWrapperView belowSubview:_controlsView];
}

- (void)setDisableControls:(bool)disableControls {
    _disableControls = disableControls;
    if (disableControls) {
        for (UIView *view in [_dimWrapperView.subviews copy]) {
            if (view != _coverView) {
                view.alpha = 0.0f;
                view.hidden = true;
            }
        }
        _controlsView.hidden = true;
        _dimView.hidden = true;
    }
}

- (void)_setupAudioSessionIfNeeded
{
    if (_currentAudioSession != nil)
        return;
    
    _currentAudioSession = [[LegacyComponentsGlobals provider] requestAudioSession:TGAudioSessionTypePlayEmbedVideo interrupted:^{}];
}

- (void)setupWithEmbedSize:(CGSize)embedSize
{
    if (!self.disallowAutoplay || iosMajorVersion() < 8)
        [self _setupAudioSessionIfNeeded];
    
    CGFloat horEdge = [self _compensationEdges];
    CGFloat verEdge =  horEdge * embedSize.width / embedSize.height;
    
    _embedSize = CGSizeMake(embedSize.width + horEdge * 2.0f, embedSize.height + verEdge * 2.0f);
    
    CGSize screenSize = TGScreenSize();
    screenSize = CGSizeMake(screenSize.height, screenSize.width);
    _maxPlayerSize = [self _scaleViewToMaxSize] ? TGScaleToSize(embedSize, screenSize) : _embedSize;
    _embedScale = _embedSize.width / _maxPlayerSize.width;
    
    if (iosMajorVersion() >= 8)
        [self setupWKWebView];
    else
        [self setupUIWebView];
    
    if (!self.disallowAutoplay)
    {
        _overlayView.hidden = false;
        [self setLoadProgress:0.01f duration:0.01];
        [_loadProgressValue set:[SSignal single:@(0.01f)]];
    }
}

- (CGFloat)_compensationEdges
{
    return 0.0f;
}

- (SSignal *)loadProgress {
    return [_loadProgressValue signal];
}

- (void)hideControls
{
    [_controlsView hidePlayButton];
}

- (void)switchToPictureInPicture
{
    [self _pictureInPicturePressed];
}

- (void)_requestSystemPictureInPictureMode
{
    [self _evaluateJS:@"injectCmd('switchToPIP');" completion:^(__unused NSString *result)
    {
    }];
}

- (void)pausePIPPlayback
{
    if (_pausedManually)
        return;
    
    _shouldResumePIPPlayback = true;
    [self pauseVideo:false];
}

- (void)resumePIPPlayback
{
    if (_shouldResumePIPPlayback)
        [self playVideo];
    
    _shouldResumePIPPlayback = false;
}

- (bool)supportsPIP
{
    CGSize screenSize = TGScreenSize();
    return !self.disallowPIP && (int)screenSize.height != 480;
}

- (void)setDimmed:(bool)dimmed animated:(bool)animated
{
    [self setDimmed:dimmed animated:animated shouldDelay:false];
}

- (void)setDimmed:(bool)dimmed animated:(bool)animated shouldDelay:(bool)shouldDelay
{
    bool useFakeProgress = [self _useFakeLoadingProgress];
    if (animated)
    {
        if (dimmed)
        {
            _overlayView.hidden = false;
            if (useFakeProgress) {
                [self setLoadProgress:0.88f duration:3.0];
                [_loadProgressValue set:[SSignal single:@(0.88f)]];
            }
            
            _dimWrapperView.hidden = false;
            _dimWrapperView.alpha = 1.0f;
        }
        else
        {
            [self setLoadProgress:1.0f duration:0.2];
            [_loadProgressValue set:[SSignal single:@(1.0f)]];
            
            NSTimeInterval delay = shouldDelay ? 0.4 : 0.0;
            [UIView animateWithDuration:0.2 delay:delay options:UIViewAnimationOptionAllowAnimatedContent | UIViewAnimationOptionCurveLinear animations:^
            {
                _dimWrapperView.alpha = 0.0f;
            } completion:^(__unused BOOL finished)
            {
                _dimWrapperView.hidden = true;
                _dimWrapperView.alpha = 1.0f;
            }];
        }
    }
    else
    {
        _dimWrapperView.hidden = !dimmed;
        
        _overlayView.hidden = !dimmed;
        if (dimmed && useFakeProgress) {
            [self setLoadProgress:0.88f duration:3.0];
            [_loadProgressValue set:[SSignal single:@(0.88f)]];
        }
        else
            [_overlayView setNone];
    }
}

- (void)setLoadProgress:(CGFloat)value duration:(NSTimeInterval)duration
{
    [_overlayView setProgressAnimated:value duration:duration cancelEnabled:false];
    [_loadProgressValue set:[SSignal single:@(value)]];
}

- (bool)_useFakeLoadingProgress
{
    return true;
}

- (void)setCoverImage:(UIImage *)image
{
    [_coverView setSignal:[SSignal single:image]];
}

#pragma mark - 

- (void)beginLeavingFullscreen
{
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds byRoundingCorners:self.roundCorners cornerRadii:CGSizeMake(14.5f, 14.5f)];
    
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = self.bounds;
    maskLayer.path = maskPath.CGPath;

    self.layer.mask = maskLayer;
}

- (void)finishedLeavingFullscreen
{
    self.layer.mask = nil;
}

- (void)onLockInPlace
{
    [_controlsView setFullscreenButtonHidden:false animated:true];
}

- (void)setInhibitFullscreenButton:(bool)inhibitFullscreenButton
{
    _inhibitFullscreenButton = inhibitFullscreenButton;
    _controlsView.inhibitFullscreenButton = inhibitFullscreenButton;
}

#pragma mark -

- (void)setupWKWebView
{
    WKUserContentController *contentController = [[WKUserContentController alloc] init];
 
    if ([self _applyViewportUserScript])
    {
        NSString *jScript = @"var meta = document.createElement('meta'); meta.setAttribute('name', 'viewport'); meta.setAttribute('content', 'width=device-width'); document.getElementsByTagName('head')[0].appendChild(meta);";
        WKUserScript *viewportScript = [[WKUserScript alloc] initWithSource:jScript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:true];
        [contentController addUserScript:viewportScript];
    }
    
    [self _setupUserScripts:contentController];
    
    WKWebViewConfiguration *conf = [[WKWebViewConfiguration alloc] init];
    conf.allowsInlineMediaPlayback = true;
    conf.userContentController = contentController;
    
    if ([conf respondsToSelector:@selector(setRequiresUserActionForMediaPlayback:)])
        conf.requiresUserActionForMediaPlayback = false;
    else if ([conf respondsToSelector:@selector(setMediaPlaybackRequiresUserAction:)])
        conf.mediaPlaybackRequiresUserAction = false;
    
    if ([conf respondsToSelector:@selector(setAllowsPictureInPictureMediaPlayback:)] && !TGIsPad())
        conf.allowsPictureInPictureMediaPlayback = false;
    
    _wkWebView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:conf];
    _wkWebView.navigationDelegate = self;
    _wkWebView.scrollView.scrollEnabled = false;
    if (iosMajorVersion() >= 11)
        _wkWebView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    
    NSString *embedHTML = [self _embedHTML];
    bool useURL = (embedHTML.length == 0);
    [self commonSetupWithWebView:_wkWebView useURL:useURL completion:^(NSURLRequest *request)
    {
        if (useURL)
            [_wkWebView loadRequest:request];
        else
            [_wkWebView loadHTMLString:embedHTML baseURL:[self _baseURL]];
    }];
}

- (void)webView:(WKWebView *)__unused webView didStartProvisionalNavigation:(WKNavigation *)__unused navigation
{
    if (_loading)
        return;

    _loading = true;
    if (!self.disallowAutoplay)
        [self setDimmed:true animated:false];
    
    if (self.onBeganLoading != nil)
        self.onBeganLoading();
}

- (void)webView:(WKWebView *)__unused webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *url = navigationAction.request.URL;
    if (![url.scheme isEqualToString:@"http"] && ![url.scheme isEqualToString:@"https"] && ![url.absoluteString isEqualToString:@"about:blank"])
    {
        [self _notifyOfCallbackURL:url];
        decisionHandler(WKNavigationActionPolicyCancel);
    }
    else
    {
        if (navigationAction.targetFrame == nil)
        {
            [self _openWebPage:url];
            decisionHandler(WKNavigationActionPolicyCancel);
        }
        else
        {
            decisionHandler(WKNavigationActionPolicyAllow);
        }
    }
}

- (void)webView:(WKWebView *)__unused webView didFinishNavigation:(WKNavigation *)__unused navigation
{
    if (!_loading)
        return;
    
    _loading = false;
    [self _onPageReady];
}

- (void)webView:(WKWebView *)__unused webView didFailNavigation:(WKNavigation *)__unused navigation withError:(NSError *)__unused error
{
    if ([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 204)
        return;
    
    if (!_loading)
        return;

    _loading = false;
    _overlayView.hidden = true;
    [_overlayView setNone];
    _errorLabel.hidden = false;
}

#pragma mark -

- (void)setupUIWebView
{
    _uiWebView = [[UIWebView alloc] initWithFrame:CGRectZero];
    _uiWebView.mediaPlaybackRequiresUserAction = false;
    _uiWebView.delegate = self;
    _uiWebView.scrollView.scrollEnabled = false;
    
    NSString *embedHTML = [self _embedHTML];
    bool useURL = (embedHTML.length == 0);
    [self commonSetupWithWebView:_uiWebView useURL:useURL completion:^(NSURLRequest *request)
    {
        if (useURL)
            [_uiWebView loadRequest:request];
        else
            [_uiWebView loadHTMLString:embedHTML baseURL:[self _baseURL]];
    }];
}

- (BOOL)webView:(UIWebView *)__unused webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)__unused navigationType
{
    NSURL *url = request.URL;
    if (![url.scheme isEqualToString:@"http"] && ![url.scheme isEqualToString:@"https"] && ![url.absoluteString isEqualToString:@"about:blank"])
    {
        [self _notifyOfCallbackURL:url];
        return false;
    }

    return true;
}

- (void)webViewDidStartLoad:(UIWebView *)__unused webView
{
    if (_loading)
        return;

    _loading = true;
    [self setDimmed:true animated:false];
    
    if (self.onBeganLoading != nil)
        self.onBeganLoading();
}

- (void)webViewDidFinishLoad:(UIWebView *)__unused webView
{
    if (!_loading)
        return;
    
    _loading = false;
    [self _onPageReady];
}

- (void)webView:(UIWebView *)__unused webView didFailLoadWithError:(NSError *)__unused error
{
    if (!_loading)
        return;

    _loading = false;
    _overlayView.hidden = true;
    [_overlayView setNone];
    _errorLabel.hidden = false;
}

- (void)commonSetupWithWebView:(UIView *)webView useURL:(bool)useURL completion:(void (^)(NSURLRequest *))completion
{
    CGFloat horEdge = [self _compensationEdges];
    CGFloat verEdge =  horEdge * _embedSize.width / _embedSize.height;
    
    if (iosMajorVersion() >= 11)
        webView.accessibilityIgnoresInvertColors = true;
    
    webView.backgroundColor = [UIColor blackColor];
    webView.frame = CGRectMake(0, 0, _maxPlayerSize.width, _maxPlayerSize.height);
    webView.transform = CGAffineTransformMakeScale(_embedScale, _embedScale);
    webView.center = CGPointMake((_embedSize.width - horEdge * 2.0f) / 2.0f, (_embedSize.height - verEdge * 2.0f) / 2.0f);
    
    if (_controlsView != nil && !_disallowAutoplay)
        [self insertSubview:webView belowSubview:_controlsView];
    else
        [self insertSubview:webView belowSubview:_dimWrapperView];
    
    if (useURL)
    {
        NSURL *url = [self _embedURL];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        NSString *referer = [[NSString alloc] initWithFormat:@"%@://%@", [url scheme], [url host]];
        [request setValue:referer forHTTPHeaderField:@"Referer"];
        
        if (completion != nil)
            completion(request);
    }
    else
    {
        if (completion != nil)
            completion(nil);
    }
}

#pragma mark - 

- (void)_openWebPage:(NSURL *)url
{
    [[LegacyComponentsGlobals provider] openURLNative:url];
}

- (void)playVideo
{
    if (_disallowAutoplay)
        _dimWrapperView.hidden = true;
    
    [self _setupAudioSessionIfNeeded];
}

- (void)pauseVideo
{
    [self pauseVideo:true];
}

- (void)pauseVideo:(bool)manually
{
    _pausedManually = manually;
}

- (void)seekToPosition:(NSTimeInterval)__unused position
{
    
}

- (void)seekToFractPosition:(CGFloat)position
{
    NSTimeInterval timePosition = self.state.duration * position;
    [self seekToPosition:timePosition];
}

- (void)enterFullscreen:(NSTimeInterval)duration
{
    if (self.requestFullscreen != nil)
        self.requestFullscreen(duration);
}

- (void)enterPictureInPicture:(TGEmbedPIPCorner)corner
{
    if (self.requestPictureInPicture != nil)
        self.requestPictureInPicture(corner);
}

- (void)_pictureInPicturePressed
{
    [self enterPictureInPicture:TGEmbedPIPCornerNone];
}

- (SSignal *)stateSignal
{
    return _statePipe.signalProducer();
}

- (void)updateState:(TGEmbedPlayerState *)state
{
    _state = state;
    [_controlsView setState:state];
    
    _statePipe.sink(state);
}

#pragma mark -

- (void)_onPageReady
{
    [self setDimmed:false animated:true];
}

- (void)_didBeginPlayback
{
    [_controlsView notifyOfPlaybackStart];
    
    [[LegacyComponentsGlobals provider] pausePictureInPicturePlayback];
    
    if (self.onBeganPlaying != nil)
        self.onBeganPlaying();
}

- (void)_onPanelAppearance
{
    
}

- (void)_watermarkAction
{
    [self pauseVideo];
}

- (void)_prepareToEnterFullscreen
{
    [_controlsView setWatermarkHidden:true];
    [_controlsView setHidden:true animated:true];
    _interactionView.hidden = false;
}

- (void)_prepareToLeaveFullscreen
{
    [_controlsView setWatermarkHidden:false];
    [_controlsView setHidden:false animated:true];
    _interactionView.hidden = true;
}

#pragma mark -

- (TGEmbedPlayerControlsType)_controlsType
{
    return TGEmbedPlayerControlsTypeNone;
}

- (void)_evaluateJS:(NSString *)jsString completion:(void (^)(NSString *))completion
{
    if (_wkWebView != nil)
    {
        [_jsQueue dispatch:^
        {
            void (^block)(void) = ^
            {
                [_wkWebView evaluateJavaScript:jsString completionHandler:^(id result, __unused NSError *error)
                {
                    dispatch_semaphore_signal(_sema);
                    TGDispatchOnMainThread(^
                    {
                        if (completion != nil)
                            completion(result);
                    });
                 }];
            };
            
            if (iosMajorVersion() >= 11)
                TGDispatchOnMainThread(block);
            else
                block();
            
            dispatch_semaphore_wait(_sema, DISPATCH_TIME_FOREVER);
        }];
    }
    else if (_uiWebView != nil)
    {
        NSString *result = [_uiWebView stringByEvaluatingJavaScriptFromString:jsString];
        if (completion != nil)
            completion(result);
    }
}

- (NSString *)_embedHTML
{
    NSString *path = TGComponentsPathForResource(@"DefaultPlayer", @"html");
    NSError *error = nil;
    NSString *embedHTMLTemplate = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error != nil)
    {
        TGLegacyLog(@"[DefaultEmbedPlayer]: Received error rendering template: %@", error);
        return nil;
    }
    
    NSString *embedHTML = [NSString stringWithFormat:embedHTMLTemplate, [self _embedURL].absoluteString];
    return embedHTML;
}

- (NSURL *)_embedURL
{
    return [NSURL URLWithString:_webPage.embedUrl];
}

- (NSURL *)_baseURL
{
    return [NSURL URLWithString:@"about:blank"];
}

- (void)_setupUserScripts:(WKUserContentController *)__unused contentController
{
    NSError *error = nil;
    NSString *path = TGComponentsPathForResource(@"DefaultPlayerInject", @"js");
    NSString *scriptText = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error != nil)
        TGLegacyLog(@"[DefaultEmbedPlayer]: Received error loading inject script: %@", error);
    
    WKUserScript *script = [[WKUserScript alloc] initWithSource:scriptText injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:false];
    [contentController addUserScript:script];
}

- (bool)_applyViewportUserScript
{
    return true;
}

- (void)_notifyOfCallbackURL:(NSURL *)__unused url
{
    
}

- (UIView *)_webView
{
    if (_wkWebView != nil)
        return _wkWebView;
    else if (_uiWebView != nil)
        return _uiWebView;
    
    return nil;
}

- (bool)_scaleViewToMaxSize
{
    return false;
}

- (void)_cleanWebView
{
    _wkWebView.navigationDelegate = nil;
    [_wkWebView removeFromSuperview];
    _wkWebView = nil;
    
    _uiWebView.delegate = nil;
    [_uiWebView removeFromSuperview];
    _uiWebView = nil;
}

+ (bool)_supportsWebPage:(TGWebPageMediaAttachment *)__unused webPage
{
    return true;
}

+ (Class)playerViewClassForWebPage:(TGWebPageMediaAttachment *)webPage onlySpecial:(bool)onlySpecial
{
    static dispatch_once_t onceToken;
    static NSArray *playerViewClasses;
    dispatch_once(&onceToken, ^
    {
        playerViewClasses = @
        [
            [TGEmbedYoutubePlayerView class],
            [TGEmbedVimeoPlayerView class],
            [TGEmbedCoubPlayerView class],
            [TGEmbedVKPlayerView class],
            [TGEmbedVinePlayerView class],
            [TGEmbedInstagramPlayerView class],
            [TGEmbedSoundCloudPlayerView class],
            [TGEmbedTwitchPlayerView class],
            [TGEmbedVideoPlayerView class]
        ];
    });
    
    if (iosMajorVersion() >= 8)
    {
        for (Class playerViewClass in playerViewClasses)
        {
            if ([playerViewClass _supportsWebPage:webPage])
            {
                if (playerViewClass == [TGEmbedVideoPlayerView class] && onlySpecial)
                    return nil;
                
                return playerViewClass;
            }
        }
    }
    
    if (onlySpecial)
        return nil;
    
    return self;
}

- (void)layoutSubviews
{
    _dimWrapperView.frame = self.bounds;
    _coverView.frame = _dimWrapperView.bounds;
    _overlayView.center = CGPointMake(CGRectGetMidX(_dimWrapperView.bounds), CGRectGetMidY(_dimWrapperView.bounds));
    _errorLabel.center = _overlayView.center;
    _controlsView.frame = self.bounds;
}

+ (TGEmbedPlayerView *)makePlayerViewForWebPage:(TGWebPageMediaAttachment *)webPage thumbnailSignal:(SSignal *)signal {
    Class playerClass = [self playerViewClassForWebPage:webPage onlySpecial:false];
    if (playerClass != nil) {
        return [[playerClass alloc] initWithWebPageAttachment:webPage thumbnailSignal:signal];
    } else {
        return nil;
    }
}

+ (bool)hasNativeSupportForX:(TGWebPageMediaAttachment *)webPage {
    static dispatch_once_t onceToken;
    static NSArray *playerViewClasses;
    dispatch_once(&onceToken, ^
    {
        playerViewClasses = @
        [
         [TGEmbedYoutubePlayerView class],
         /*[TGEmbedVimeoPlayerView class],
         [TGEmbedCoubPlayerView class],
         [TGEmbedVKPlayerView class],
         [TGEmbedVinePlayerView class],
         [TGEmbedInstagramPlayerView class],
         [TGEmbedSoundCloudPlayerView class],
         [TGEmbedTwitchPlayerView class],
         [TGEmbedVideoPlayerView class]*/
         ];
    });
    
    if (iosMajorVersion() >= 8)
    {
        for (Class playerViewClass in playerViewClasses)
        {
            if ([playerViewClass _supportsWebPage:webPage])
            {
                if (playerViewClass == [TGEmbedVideoPlayerView class])
                    return false;
                
                return true;
            }
        }
    }
    
    return false;
}

@end
