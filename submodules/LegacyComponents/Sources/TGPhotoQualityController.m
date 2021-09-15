#import "TGPhotoQualityController.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGPhotoEditorUtils.h>

#import "TGPhotoEditorInterfaceAssets.h"
#import <LegacyComponents/TGPhotoEditorAnimation.h>

#import <LegacyComponents/TGModernGalleryVideoView.h>
#import "TGPhotoEditorPreviewView.h"
#import "TGPhotoEditorGenericToolView.h"

#import <LegacyComponents/TGMediaAsset.h>
#import <LegacyComponents/TGMediaAssetImageSignals.h>
#import <LegacyComponents/TGMediaVideoConverter.h>
#import "TGCameraCapturedVideo.h"

#import "TGPaintingWrapperView.h"
#import "TGMessageImageViewOverlayView.h"

#import "PGPhotoEditor.h"

const CGFloat TGPhotoEditorQualityPanelSize = 75.0f;
const NSTimeInterval TGPhotoQualityPreviewDuration = 15.0f;

@interface TGPhotoQuality : NSObject <PGPhotoEditorItem>

@property (nonatomic, assign) bool hasAudio;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, readonly) NSInteger finalValue;
@property (nonatomic, assign) CGFloat maximumValue;

@end

@interface TGPhotoQualityController ()
{
    TGPhotoQuality *_quality;
    
    UIView *_wrapperView;
    UIView *_portraitToolsWrapperView;
    UIView *_landscapeToolsWrapperView;
    
    UIView <TGPhotoEditorToolView> *_portraitToolControlView;
    UIView <TGPhotoEditorToolView> *_landscapeToolControlView;
    
    bool _appeared;
    bool _dismissing;
    bool _animating;
    
    TGMessageImageViewOverlayView *_overlayView;
    TGModernGalleryVideoView *_videoView;
    AVPlayer *_player;
    SMetaDisposable *_disposable;
    id _playerStartedObserver;
    id _playerReachedEndObserver;
    
    NSInteger _previewId;
    NSTimeInterval _fileDuration;
    bool _hasAudio;
    
    TGMediaVideoConversionPreset _currentPreset;
}

@property (nonatomic, weak) PGPhotoEditor *photoEditor;
@property (nonatomic, weak) TGPhotoEditorPreviewView *previewView;

@end

@implementation TGPhotoQualityController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        self.photoEditor = photoEditor;
        self.previewView = previewView;
        
        _previewId = (int)arc4random();
        _currentPreset = TGMediaVideoConversionPresetCompressedDefault;
        
        _quality = [[TGPhotoQuality alloc] init];
        
        NSInteger value = 0;
        if (photoEditor.preset != TGMediaVideoConversionPresetCompressedDefault)
        {
            value = photoEditor.preset;
        }
        else
        {
            NSNumber *presetValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"TG_preferredVideoPreset_v0"];
            if (presetValue != nil)
                value = [presetValue integerValue];
            else
                value = TGMediaVideoConversionPresetCompressedMedium;
        }
        
        _disposable = [[SMetaDisposable alloc] init];
        
        _quality.value = @(value - 1);
    }
    return self;
}

- (void)dealloc
{
    [self cleanupVideoPreviews];
}

- (void)loadView
{
    [super loadView];
    
    __weak TGPhotoQualityController *weakSelf = self;
    void(^interactionEnded)(void) = ^
    {
        __strong TGPhotoQualityController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if ([strongSelf shouldAutorotate])
            [TGViewController attemptAutorotation];
        
        [strongSelf generateVideoPreview];
    };
    
    CGSize dimensions = CGSizeZero;
    if ([self.item isKindOfClass:[TGMediaAsset class]])
        dimensions = ((TGMediaAsset *)self.item).dimensions;
    else if ([self.item isKindOfClass:[TGCameraCapturedVideo class]])
        dimensions = ((TGCameraCapturedVideo *)self.item).dimensions;
    
    if (!CGSizeEqualToSize(dimensions, CGSizeZero))
        _quality.maximumValue = [TGMediaVideoConverter bestAvailablePresetForDimensions:dimensions] - 1;
    else
        _quality.maximumValue = TGMediaVideoConversionPresetCompressedMedium - 1;
    
    TGPhotoEditorPreviewView *previewView = _previewView;
    previewView.hidden = true;
    previewView.interactionEnded = nil;
    [self.view addSubview:_previewView];
    
    _wrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_wrapperView];
    
    _portraitToolsWrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    _portraitToolsWrapperView.alpha = 0.0f;
    [_wrapperView addSubview:_portraitToolsWrapperView];
    
    _landscapeToolsWrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    _landscapeToolsWrapperView.alpha = 0.0f;
    [_wrapperView addSubview:_landscapeToolsWrapperView];
    
    _overlayView = [[TGMessageImageViewOverlayView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 44.0f, 44.0f)];
    _overlayView.alpha = 0.0f;
    [_overlayView setRadius:44.0f];
    [self.view addSubview:_overlayView];
        
    _portraitToolControlView = [_quality itemControlViewWithChangeBlock:^(id newValue, __unused bool animated)
    {
        __strong TGPhotoQualityController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_landscapeToolControlView setValue:newValue];
    }];
    _portraitToolControlView.backgroundColor = [TGPhotoEditorInterfaceAssets panelBackgroundColor];
    _portraitToolControlView.clipsToBounds = true;
    _portraitToolControlView.interactionEnded = interactionEnded;
    _portraitToolControlView.layer.rasterizationScale = TGScreenScaling();
    _portraitToolControlView.isLandscape = false;
    [_portraitToolsWrapperView addSubview:_portraitToolControlView];
    
    _landscapeToolControlView = [_quality itemControlViewWithChangeBlock:^(id newValue, __unused bool animated)
    {
        __strong TGPhotoQualityController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_portraitToolControlView setValue:newValue];
    }];
    _landscapeToolControlView.backgroundColor = [TGPhotoEditorInterfaceAssets panelBackgroundColor];
    _landscapeToolControlView.clipsToBounds = true;
    _landscapeToolControlView.interactionEnded = interactionEnded;
    _landscapeToolControlView.layer.rasterizationScale = TGScreenScaling();
    _landscapeToolControlView.isLandscape = true;
    _landscapeToolControlView.toolbarLandscapeSize = self.toolbarLandscapeSize;
    [_landscapeToolsWrapperView addSubview:_landscapeToolControlView];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self transitionIn];
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _overlayView.alpha = 1.0f;
    }];
    [self generateVideoPreview];
}

- (BOOL)shouldAutorotate
{
    TGPhotoEditorPreviewView *previewView = self.previewView;
    return (!previewView.isTracking && !_portraitToolControlView.isTracking && !_landscapeToolControlView.isTracking && [super shouldAutorotate]);
}

- (bool)isDismissAllowed
{
    return _appeared && !(_portraitToolControlView.isTracking && !_landscapeToolControlView.isTracking && !_animating);
}

#pragma mark - Transition

- (void)transitionIn
{
    [UIView animateWithDuration:0.3f animations:^
    {
        _portraitToolsWrapperView.alpha = 1.0f;
        _landscapeToolsWrapperView.alpha = 1.0f;
    }];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
        _portraitToolControlView.layer.shouldRasterize = true;
    else
        _landscapeToolControlView.layer.shouldRasterize = true;
    
    CGRect toolTargetFrame;
    switch (self.interfaceOrientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            toolTargetFrame = _landscapeToolsWrapperView.frame;
            _landscapeToolsWrapperView.frame = CGRectOffset(_landscapeToolsWrapperView.frame, -_landscapeToolsWrapperView.frame.size.width / 2 - 20, 0);
        }
            break;
        case UIInterfaceOrientationLandscapeRight:
        {
            toolTargetFrame = _landscapeToolsWrapperView.frame;
            _landscapeToolsWrapperView.frame = CGRectOffset(_landscapeToolsWrapperView.frame, _landscapeToolsWrapperView.frame.size.width / 2 + 20, 0);
        }
            break;
            
        default:
        {
            toolTargetFrame = _portraitToolsWrapperView.frame;
            _portraitToolsWrapperView.frame = CGRectOffset(_portraitToolsWrapperView.frame, 0, _portraitToolsWrapperView.frame.size.height / 2 + 20);
        }
            break;
    }
    
    void (^animationBlock)(void) = ^
    {
        if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
            _portraitToolsWrapperView.frame = toolTargetFrame;
        else
            _landscapeToolsWrapperView.frame = toolTargetFrame;
    };
#pragma clang diagnostic pop
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _wrapperView.alpha = 1.0f;
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            _portraitToolControlView.layer.shouldRasterize = false;
            _landscapeToolControlView.layer.shouldRasterize = false;
        }
    }];

    if (iosMajorVersion() >= 7)
        [UIView animateWithDuration:0.4f delay:0.0f usingSpringWithDamping:1.0f initialSpringVelocity:0.0f options:UIViewAnimationOptionCurveLinear animations:animationBlock completion:nil];
    else
        [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionAllowUserInteraction animations:animationBlock completion:nil];
}

- (void)transitionOutSwitching:(bool)__unused switching completion:(void (^)(void))completion
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    _wrapperView.backgroundColor = [UIColor clearColor];
    
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
        _portraitToolControlView.layer.shouldRasterize = true;
    else
        _landscapeToolControlView.layer.shouldRasterize = true;
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _wrapperView.alpha = 0.0f;
    }];
    
    UIInterfaceOrientation orientation = self.interfaceOrientation;
    if ([self inFormSheet] || [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        orientation = UIInterfaceOrientationPortrait;
    }
    else if ([self.presentingViewController isKindOfClass:[TGNavigationController class]] &&
             [(TGNavigationController *)self.presentingViewController presentationStyle] == TGNavigationControllerPresentationStyleInFormSheet)
    {
        orientation = UIInterfaceOrientationPortrait;
    }

    if (UIInterfaceOrientationIsPortrait(orientation))
        _landscapeToolsWrapperView.hidden = true;
    else
        _portraitToolsWrapperView.hidden = true;
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _landscapeToolsWrapperView.transform = CGAffineTransformMakeTranslation(-_landscapeToolsWrapperView.frame.size.width / 3.0f * 2.0f, 0.0f);
            } completion:nil];
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _landscapeToolsWrapperView.transform = CGAffineTransformMakeTranslation(_landscapeToolsWrapperView.frame.size.width / 3.0f * 2.0f, 0.0f);
            } completion:nil];
        }
            break;
            
        default:
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
            {
                _portraitToolsWrapperView.transform = CGAffineTransformMakeTranslation(0.0f, _portraitToolsWrapperView.frame.size.height / 3.0f * 2.0f);
            } completion:nil];
        }
            break;
    }
    
    [UIView animateWithDuration:0.2f animations:^
    {
        _portraitToolsWrapperView.alpha = 0.0f;
        _landscapeToolsWrapperView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        if (completion != nil)
            completion();
    }];
#pragma clang diagnostic pop
}

- (void)_animatePreviewViewTransitionOutToFrame:(CGRect)targetFrame saving:(bool)saving parentView:(UIView *)__unused parentView completion:(void (^)(void))completion
{
    [_disposable dispose];
    
    _dismissing = true;
    
    _overlayView.hidden = true;
    if (_player != nil)
        [_player pause];
    
    UIView *previewView = _videoView ?: self.previewView;
    UIView *snapshotView = nil;
    POPSpringAnimation *snapshotAnimation = nil;
    POPSpringAnimation *snapshotAlphaAnimation = nil;

    if (saving && CGRectIsNull(targetFrame) && parentView != nil)
    {
        snapshotView = [previewView snapshotViewAfterScreenUpdates:false];
        snapshotView.frame = previewView.frame;
        
        CGSize fittedSize = TGScaleToSize(previewView.frame.size, self.view.frame.size);
        targetFrame = CGRectMake((self.view.frame.size.width - fittedSize.width) / 2,
                                 (self.view.frame.size.height - fittedSize.height) / 2,
                                 fittedSize.width,
                                 fittedSize.height);
        
        [parentView addSubview:snapshotView];
        
        snapshotAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
        snapshotAnimation.fromValue = [NSValue valueWithCGRect:snapshotView.frame];
        snapshotAnimation.toValue = [NSValue valueWithCGRect:targetFrame];
        
        snapshotAlphaAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewAlpha];
        snapshotAlphaAnimation.fromValue = @(snapshotView.alpha);
        snapshotAlphaAnimation.toValue = @(0.0f);
    }
    
    if (previewView != self.previewView)
        self.previewView.hidden = true;

    POPSpringAnimation *previewAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
    previewAnimation.fromValue = [NSValue valueWithCGRect:previewView.frame];
    previewAnimation.toValue = [NSValue valueWithCGRect:targetFrame];
    
    POPSpringAnimation *previewAlphaAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewAlpha];
    previewAlphaAnimation.fromValue = @(previewView.alpha);
    previewAlphaAnimation.toValue = @(0.0f);
    
    NSMutableArray *animations = [NSMutableArray arrayWithArray:@[ previewAnimation, previewAlphaAnimation ]];
    if (snapshotAnimation != nil)
        [animations addObject:snapshotAnimation];
    
    [TGPhotoEditorAnimation performBlock:^(__unused bool allFinished)
    {
        [snapshotView removeFromSuperview];
         
        if (completion != nil)
            completion();
    } whenCompletedAllAnimations:animations];
    
    if (snapshotAnimation != nil)
    {
        [snapshotView pop_addAnimation:snapshotAnimation forKey:@"frame"];
    }
    [previewView pop_addAnimation:previewAnimation forKey:@"frame"];
    [previewView pop_addAnimation:previewAlphaAnimation forKey:@"alpha"];
}

- (void)_finishedTransitionInWithView:(UIView *)transitionView
{
    _appeared = true;
    
    if ([transitionView isKindOfClass:[TGPhotoEditorPreviewView class]]) {
        [self.view insertSubview:transitionView atIndex:0];
    } else {
        [transitionView removeFromSuperview];
    }
    
    TGPhotoEditorPreviewView *previewView = _previewView;
    previewView.hidden = false;
    [previewView performTransitionInIfNeeded];
}

- (CGRect)transitionOutReferenceFrame
{
    TGPhotoEditorPreviewView *previewView = _previewView;
    return previewView.frame;
}

- (UIView *)transitionOutReferenceView
{
    return _previewView;
}

- (CGRect)transitionOutSourceFrameForReferenceFrame:(CGRect)referenceFrame orientation:(UIInterfaceOrientation)orientation
{
    bool hasOnScreenNavigation = false;
    if (@available(iOS 11.0, *)) {
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || self.context.safeAreaInset.bottom > FLT_EPSILON;
    }
    
    CGRect containerFrame = [TGPhotoQualityController photoContainerFrameForParentViewFrame:self.view.frame toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoEditorQualityPanelSize hasOnScreenNavigation:hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(referenceFrame.size, containerFrame.size);
    CGRect sourceFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    return sourceFrame;
}

- (CGRect)_targetFrameForTransitionInFromFrame:(CGRect)fromFrame
{
    CGSize referenceSize = [self referenceViewSize];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIInterfaceOrientation orientation = self.interfaceOrientation;
#pragma clang diagnostic pop
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        orientation = UIInterfaceOrientationPortrait;
    
    bool hasOnScreenNavigation = false;
    if (@available(iOS 11.0, *)) {
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || self.context.safeAreaInset.bottom > FLT_EPSILON;
    }
    
    CGRect containerFrame = [TGPhotoQualityController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoEditorQualityPanelSize hasOnScreenNavigation:hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(fromFrame.size, containerFrame.size);
    CGRect toFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    return toFrame;
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateLayout:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation]];
}

- (CGSize)referenceViewSize
{
    if (self.parentViewController != nil)
    {
        TGPhotoEditorController *controller = (TGPhotoEditorController *)self.parentViewController;
        return [controller referenceViewSize];
    }
    
    return CGSizeZero;
}

- (TGMediaVideoConversionPreset)preset
{
    return (TGMediaVideoConversionPreset)_quality.finalValue;
}

- (void)updateLayout:(UIInterfaceOrientation)orientation
{
    CGSize referenceSize = [self referenceViewSize];
    
    if ([self inFormSheet] || [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        orientation = UIInterfaceOrientationPortrait;
    }
    else if ([self.presentingViewController isKindOfClass:[TGNavigationController class]] && [(TGNavigationController *)self.presentingViewController presentationStyle] == TGNavigationControllerPresentationStyleInFormSheet)
    {
        orientation = UIInterfaceOrientationPortrait;
    }
    
    CGFloat panelSize = TGPhotoEditorQualityPanelSize;
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height) + 2 * panelSize;
    _wrapperView.frame = CGRectMake((referenceSize.width - screenSide) / 2, (referenceSize.height - screenSide) / 2, screenSide, screenSide);
    
    CGFloat panelToolbarPortraitSize = panelSize + TGPhotoEditorToolbarSize;
    CGFloat panelToolbarLandscapeSize = panelToolbarPortraitSize;
    
    bool hasOnScreenNavigation = false;
    if (@available(iOS 11.0, *)) {
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || self.context.safeAreaInset.bottom > FLT_EPSILON;
    }
    
    UIEdgeInsets safeAreaInset = [TGViewController safeAreaInsetForOrientation:orientation hasOnScreenNavigation:hasOnScreenNavigation];
    UIEdgeInsets screenEdges = UIEdgeInsetsMake((screenSide - referenceSize.height) / 2 , (screenSide - referenceSize.width) / 2, (screenSide + referenceSize.height) / 2, (screenSide + referenceSize.width) / 2);
    screenEdges.top += safeAreaInset.top;
    screenEdges.left += safeAreaInset.left;
    screenEdges.bottom -= safeAreaInset.bottom;
    screenEdges.right -= safeAreaInset.right;
    
    if (_dismissing)
        return;
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            [UIView performWithoutAnimation:^
            {
                _landscapeToolsWrapperView.frame = CGRectMake(0, screenEdges.top, panelToolbarLandscapeSize, _landscapeToolsWrapperView.frame.size.height);
                _landscapeToolControlView.frame = CGRectMake(panelToolbarLandscapeSize - panelSize, 0, panelSize, _landscapeToolsWrapperView.frame.size.height);
            }];
            
            _landscapeToolsWrapperView.frame = CGRectMake(screenEdges.left, screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);
            
            _landscapeToolControlView.frame = CGRectMake(panelToolbarLandscapeSize - panelSize - 7.0f, 0, panelSize - 7.0f, _landscapeToolsWrapperView.frame.size.height);
            
            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.left, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            [UIView performWithoutAnimation:^
            {
                _landscapeToolsWrapperView.frame = CGRectMake(screenSide - panelToolbarLandscapeSize, screenEdges.top, panelToolbarLandscapeSize, _landscapeToolsWrapperView.frame.size.height);
                _landscapeToolControlView.frame = CGRectMake(0, 0, panelSize, _landscapeToolsWrapperView.frame.size.height);
            }];
            
            _landscapeToolsWrapperView.frame = CGRectMake(screenEdges.right - panelToolbarLandscapeSize, screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);
            
            _landscapeToolControlView.frame = CGRectMake(7.0f, 0, panelSize - 7.0f, _landscapeToolsWrapperView.frame.size.height);
            
            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.left, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
        }
            break;
            
        default:
        {
            CGFloat x = _landscapeToolsWrapperView.frame.origin.x;
            if (x < screenSide / 2)
                x = 0;
            else
                x = screenSide - panelSize;
            _landscapeToolsWrapperView.frame = CGRectMake(x, screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);
            
            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.left, screenEdges.bottom - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
            
            _portraitToolControlView.frame = CGRectMake(0, 7.0f, _portraitToolsWrapperView.frame.size.width, _portraitToolsWrapperView.frame.size.height - TGPhotoEditorToolbarSize - 7.0f);
        }
            break;
    }
    
    PGPhotoEditor *photoEditor = self.photoEditor;
    TGPhotoEditorPreviewView *previewView = self.previewView;
    
    if (previewView.superview != self.view)
        return;
    
    CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:panelSize hasOnScreenNavigation:hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(photoEditor.rotatedCropSize, containerFrame.size);
    previewView.frame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    _videoView.frame = previewView.frame;
    
    _overlayView.frame = CGRectMake(floor(previewView.frame.origin.x + (previewView.frame.size.width - _overlayView.frame.size.width) / 2.0f), floor(previewView.frame.origin.y + (previewView.frame.size.height - _overlayView.frame.size.height) / 2.0f), _overlayView.frame.size.width, _overlayView.frame.size.height);
}

- (void)_updateVideoDuration:(NSTimeInterval)duration hasAudio:(bool)hasAudio
{
    _fileDuration = duration;
    _hasAudio = hasAudio;
    
    TGVideoEditAdjustments *adjustments = [self.photoEditor exportAdjustments];
    if ([adjustments trimApplied])
        _quality.duration = adjustments.trimEndValue - adjustments.trimStartValue;
    else
        _quality.duration = _fileDuration;
    
    [self updateInfo];
}

- (NSURL *)_previewDirectoryURL
{
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"videopreview_%d", (int)_previewId]]];
}

- (void)cleanupVideoPreviews
{
    [[NSFileManager defaultManager] removeItemAtURL:[self _previewDirectoryURL] error:NULL];
}

- (void)updateInfo
{
    NSUInteger estimatedSize = [TGMediaVideoConverter estimatedSizeForPreset:self.preset duration:_fileDuration hasAudio:_hasAudio];
    
    CGRect cropRect = _photoEditor.cropRect;
    CGSize maxDimensions = [TGMediaVideoConversionPresetSettings maximumSizeForPreset:self.preset];
    CGSize outputDimensions = TGFitSizeF(cropRect.size, maxDimensions);
    outputDimensions = CGSizeMake(ceil(outputDimensions.width), ceil(outputDimensions.height));
    outputDimensions = [TGMediaVideoConverter _renderSizeWithCropSize:outputDimensions];

    NSString *fileSize = [NSString stringWithFormat:@"MP4 • ~%@ • %dx%d", [TGStringUtils stringForFileSize:estimatedSize precision:1], (int)outputDimensions.width, (int)outputDimensions.height];
    
    [(TGPhotoEditorController *)self.parentViewController setInfoString:fileSize];
}

- (void)generateVideoPreview
{
    if (self.preset == _currentPreset)
        return;
    
    _currentPreset = self.preset;
    
    [self updateInfo];
    
    SSignal *assetSignal = [self.item isKindOfClass:[TGMediaAsset class]] ? [TGMediaAssetImageSignals avAssetForVideoAsset:(TGMediaAsset *)self.item] : ((TGCameraCapturedVideo *)self.item).avAsset;

    if ([self.item isKindOfClass:[TGMediaAsset class]])
        [self _updateVideoDuration:((TGMediaAsset *)self.item).videoDuration hasAudio:true];
    
    TGVideoEditAdjustments *adjustments = [self.photoEditor exportAdjustments];
    adjustments = [adjustments editAdjustmentsWithPreset:self.preset maxDuration:TGPhotoQualityPreviewDuration];
    
    __block NSTimeInterval delay = 0.0;
    __weak TGPhotoQualityController *weakSelf = self;
    SSignal *convertSignal = [[assetSignal onNext:^(AVAsset *next) {
        __strong TGPhotoQualityController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            TGDispatchOnMainThread(^{
                bool hasAudio = [next tracksWithMediaType:AVMediaTypeAudio].count > 0;
                [strongSelf _updateVideoDuration:CMTimeGetSeconds(next.duration) hasAudio:hasAudio];
            });
        }
    }] mapToSignal:^SSignal *(AVAsset *avAsset)
    {
        return [[[[[SSignal single:avAsset] delay:delay onQueue:[SQueue concurrentDefaultQueue]] mapToSignal:^SSignal *(AVAsset *avAsset)
        {
            return [TGMediaVideoConverter convertAVAsset:avAsset adjustments:adjustments watcher:nil inhibitAudio:true entityRenderer:nil];
        }] onError:^(__unused id error) {
            delay = 1.0;
        }] retryIf:^bool(__unused id error)
        {
            return true;
        }];
    }];
    
    SSignal *urlSignal = nil;
    
    NSURL *fileUrl = [NSURL fileURLWithPath:[[self _previewDirectoryURL].path stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"%d.mov", self.preset]]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileUrl.path])
    {
        urlSignal = [SSignal single:fileUrl];
    }
    else
    {
        if (_player != nil)
            [_player pause];
        
        _overlayView.hidden = false;
        [_overlayView setProgress:0.03f cancelEnabled:false animated:true];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:[self _previewDirectoryURL].path])
            [[NSFileManager defaultManager] createDirectoryAtPath:[self _previewDirectoryURL].path withIntermediateDirectories:true attributes:nil error:NULL];
        
        urlSignal = [convertSignal map:^id(id value)
        {
            if ([value isKindOfClass:[TGMediaVideoConversionResult class]])
            {
                TGMediaVideoConversionResult *result = (TGMediaVideoConversionResult *)value;
                [[NSFileManager defaultManager] moveItemAtURL:result.fileURL toURL:fileUrl error:NULL];
                return fileUrl;
            }
            return value;
        }];
    }
    
    [_disposable setDisposable:[[urlSignal deliverOn:[SQueue mainQueue]] startWithNext:^(id next)
    {
        __strong TGPhotoQualityController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf->_dismissing)
            return;
        
        if ([next isKindOfClass:[NSURL class]])
        {
            __block AVPlayer *previousPlayer;
            __block id previousPlayerReachedEndObserver;
            if (strongSelf->_player != nil)
            {
                previousPlayer = strongSelf->_player;
                previousPlayerReachedEndObserver = strongSelf->_playerReachedEndObserver;
                strongSelf->_playerReachedEndObserver = nil;
            }
            
            strongSelf->_player = [AVPlayer playerWithURL:next];
            strongSelf->_player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
            
            UIView *previousVideoView = strongSelf->_videoView;
            strongSelf->_videoView = [[TGModernGalleryVideoView alloc] initWithFrame:strongSelf->_previewView.frame player:strongSelf->_player];
            strongSelf->_videoView.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
            strongSelf->_videoView.playerLayer.opaque = false;
            strongSelf->_videoView.playerLayer.backgroundColor = nil;
            UIView *belowView = strongSelf->_overlayView;
            if (previousVideoView != nil)
                belowView = previousVideoView;
            [strongSelf.view insertSubview:strongSelf->_videoView belowSubview:belowView];
            
            [strongSelf->_player play];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [strongSelf updateLayout:strongSelf.interfaceOrientation];
#pragma clang diagnostic pop
            
            strongSelf->_overlayView.hidden = true;
            [strongSelf->_overlayView setProgress:0.03f cancelEnabled:false animated:true];
            
            TGDispatchAfter(0.2, dispatch_get_main_queue(), ^
            {
                TGDispatchAfter(0.1, dispatch_get_main_queue(), ^
                {
                    if (previousVideoView != nil)
                        [previousVideoView removeFromSuperview];
                });
                
                if (previousPlayer != nil)
                {
                    [strongSelf->_player seekToTime:previousPlayer.currentItem.currentTime];
                    if (previousPlayerReachedEndObserver != nil)
                        [previousPlayer removeTimeObserver:previousPlayerReachedEndObserver];
                        
                    previousPlayerReachedEndObserver = nil;
                    [previousPlayer pause];
                    previousPlayer = nil;
                }
                
                [strongSelf _setupPlaybackReachedEndObserver];
            });
        }
        else if ([next isKindOfClass:[NSNumber class]])
        {
            strongSelf->_overlayView.hidden = false;
            CGFloat progress = MAX(0.03, [next doubleValue]);
            [strongSelf->_overlayView setProgress:progress cancelEnabled:false animated:true];
        }
    } error:^(id error) {
        TGLegacyLog(@"Video Quality Preview Error: %@", error);
    } completed:nil]];
}

- (void)_setupPlaybackReachedEndObserver
{
    CMTime endTime = CMTimeSubtract(_player.currentItem.duration, CMTimeMake(10, 100));
    CMTime startTime = CMTimeMake(5, 100);
    
    __weak TGPhotoQualityController *weakSelf = self;
    _playerReachedEndObserver = [_player addBoundaryTimeObserverForTimes:@[[NSValue valueWithCMTime:endTime]] queue:NULL usingBlock:^
    {
        __strong TGPhotoQualityController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf->_player seekToTime:startTime];
    }];
}

- (TGPhotoEditorTab)availableTabs
{
    return TGPhotoEditorNoneTab;
}

@end


@implementation TGPhotoQuality

@synthesize value = _value;
@synthesize tempValue = _tempValue;
@synthesize maximumValue = _maximumValue;
@synthesize parameters = _parameters;
@synthesize beingEdited = _beingEdited;
@synthesize shouldBeSkipped = _shouldBeSkipped;
@synthesize parametersChanged = _parametersChanged;
@synthesize disabled = _disabled;

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _maximumValue = 4.0f;
    }
    return self;
}

- (bool)segmented
{
    return true;
}

- (NSString *)identifier
{
    return @"quality";
}

- (NSString *)title
{
    return TGLocalized(@"PhotoEditor.QualityTool");
}

- (CGFloat)defaultValue
{
    return 0.0f;
}

- (CGFloat)minimumValue
{
    return 0.0f;
}

- (CGFloat)maximumValue
{
    return _maximumValue;
}

- (void)setMaximumValue:(CGFloat)maximumValue
{
    _maximumValue = maximumValue;
    
    if ([self.value doubleValue] > maximumValue)
        self.value = @(maximumValue);
}

- (id)displayValue
{
    return self.value;
}

- (void)setValue:(id)value
{
    _value = value;
}

- (Class)valueClass
{
    return [NSNumber class];
}

- (NSInteger)finalValue
{
    return [self.value integerValue] + 1;
}

- (NSString *)stringValue
{
    NSInteger value = self.finalValue;
    NSString *title = nil;
    switch (value)
    {
        case TGMediaVideoConversionPresetCompressedVeryLow:
            title = @"240p"; //TGLocalized(@"PhotoEditor.QualityVeryLow");
            break;
            
        case TGMediaVideoConversionPresetCompressedLow:
            title = @"360p"; //TGLocalized(@"PhotoEditor.QualityLow");
            break;
            
        case TGMediaVideoConversionPresetCompressedMedium:
            title = @"480p"; //TGLocalized(@"PhotoEditor.QualityMedium");
            break;
            
        case TGMediaVideoConversionPresetCompressedHigh:
            title = @"720p"; //TGLocalized(@"PhotoEditor.QualityHigh");
            break;
            
        case TGMediaVideoConversionPresetCompressedVeryHigh:
            title = @"1080p"; //TGLocalized(@"PhotoEditor.QualityVeryHigh");
            break;
            
        default:
            break;
    }
    
    return title;
}

- (void)updateParameters
{
    
}

- (UIView <TGPhotoEditorToolView> *)itemControlViewWithChangeBlock:(void (^)(id newValue, bool animated))changeBlock
{
    __weak TGPhotoQuality *weakSelf = self;
    
    UIView <TGPhotoEditorToolView> *view = [[TGPhotoEditorGenericToolView alloc] initWithEditorItem:self];
    view.valueChanged = ^(id newValue, bool animated)
    {
        __strong TGPhotoQuality *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if ([strongSelf.value isEqual:newValue])
            return;
        
        strongSelf.value = newValue;
        
        if (changeBlock != nil)
            changeBlock(newValue, animated);
    };
    return view;
}

- (UIView<TGPhotoEditorToolView> *)itemAreaViewWithChangeBlock:(void (^)(id))__unused changeBlock
{
    return nil;
}

@end
