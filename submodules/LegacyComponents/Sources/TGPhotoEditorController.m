#import "TGPhotoEditorController.h"

#import "LegacyComponentsInternal.h"

#import <objc/runtime.h>

#import <LegacyComponents/ASWatcher.h>

#import <Photos/Photos.h>

#import <LegacyComponents/TGPhotoEditorAnimation.h>
#import "TGPhotoEditorInterfaceAssets.h"
#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGPaintUtils.h>

#import <LegacyComponents/UIImage+TG.h>

#import "TGProgressWindow.h"

#import "PGPhotoEditor.h"
#import "PGPhotoEditorView.h"

#import "TGPaintFaceDetector.h"

#import <LegacyComponents/PGPhotoEditorValues.h>
#import <LegacyComponents/TGVideoEditAdjustments.h>
#import <LegacyComponents/TGPaintingData.h>
#import <LegacyComponents/TGMediaVideoConverter.h>

#import "TGPhotoToolbarView.h"
#import "TGPhotoEditorPreviewView.h"
#import "TGPhotoEntitiesContainerView.h"

#import <LegacyComponents/TGMenuView.h>

#import <LegacyComponents/TGMediaAssetsLibrary.h>
#import <LegacyComponents/TGMediaAssetImageSignals.h>

#import "TGPhotoCropController.h"
#import "TGPhotoToolsController.h"
#import "TGPhotoPaintController.h"
#import "TGPhotoQualityController.h"
#import "TGPhotoAvatarPreviewController.h"

#import "TGPhotoAvatarCropView.h"

#import "TGMessageImageViewOverlayView.h"
#import "TGMediaPickerGalleryVideoScrubber.h"
#import "TGMediaPickerGalleryVideoScrubberThumbnailView.h"

#import "TGMenuSheetController.h"

#import <LegacyComponents/AVURLAsset+TGMediaItem.h>
#import "TGCameraCapturedVideo.h"

@interface TGPhotoEditorController () <ASWatcher, TGViewControllerNavigationBarAppearance, TGMediaPickerGalleryVideoScrubberDataSource, TGMediaPickerGalleryVideoScrubberDelegate, UIDocumentInteractionControllerDelegate>
{
    bool _switchingTab;
    TGPhotoEditorTab _availableTabs;
    TGPhotoEditorTab _currentTab;
    TGPhotoEditorTabController *_currentTabController;
    
    TGMediaEditingContext *_standaloneEditingContext;
    
    UIView *_backgroundView;
    UIView *_containerView;
    UIView *_wrapperView;
    UIView *_transitionWrapperView;
    TGPhotoToolbarView *_portraitToolbarView;
    TGPhotoToolbarView *_landscapeToolbarView;
    TGPhotoEditorPreviewView *_previewView;
    PGPhotoEditorView *_fullPreviewView;
    TGPhotoEntitiesContainerView *_fullEntitiesView;
    UIImageView *_fullPaintingView;
    
    PGPhotoEditor *_photoEditor;
    
    SQueue *_queue;
    TGPhotoEditorControllerIntent _intent;
    id<TGMediaEditableItem> _item;
    UIImage *_screenImage;
    UIImage *_thumbnailImage;
    
    CMTime _chaseTime;
    bool _chaseStart;
    bool _chasingTime;
    bool _isPlaying;
    AVPlayerItem *_playerItem;
    SMetaDisposable *_playerItemDisposable;
    id _playerStartedObserver;
    id _playerReachedEndObserver;
    bool _registeredKeypathObserver;
    NSTimer *_positionTimer;
    bool _scheduledVideoPlayback;
    
    id<TGMediaEditAdjustments> _initialAdjustments;
    NSAttributedString *_caption;
    
    bool _viewFillingWholeScreen;
    bool _forceStatusBarVisible;
    
    bool _ignoreDefaultPreviewViewTransitionIn;
    bool _hasOpenedPhotoTools;
    bool _hiddenToolbarView;
    
    TGMenuContainerView *_menuContainerView;
    UIDocumentInteractionController *_documentController;
    
    bool _dismissed;
    
    bool _hadProgress;
    bool _progressVisible;
    TGMessageImageViewOverlayView *_progressView;
    
    SMetaDisposable *_faceDetectorDisposable;
    
    bool _wasPlaying;
    bool _initializedScrubber;
    NSArray *_cachedThumbnails;
    TGMediaPickerGalleryVideoScrubber *_scrubberView;
    
    bool _resetDotPosition;
    NSTimeInterval _dotPosition;
    UIImageView *_dotMarkerView;
    TGMediaPickerGalleryVideoScrubberThumbnailView *_dotImageView;
    UIView *_dotImageSnapshotView;
    
    bool _requestingThumbnails;
    SMetaDisposable *_thumbnailsDisposable;
    
    id<LegacyComponentsContext> _context;
}

@property (nonatomic, weak) UIImage *fullSizeImage;

@end

@implementation TGPhotoEditorController

@synthesize actionHandle = _actionHandle;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context item:(id<TGMediaEditableItem>)item intent:(TGPhotoEditorControllerIntent)intent adjustments:(id<TGMediaEditAdjustments>)adjustments caption:(NSAttributedString *)caption screenImage:(UIImage *)screenImage availableTabs:(TGPhotoEditorTab)availableTabs selectedTab:(TGPhotoEditorTab)selectedTab
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        _context = context;
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        self.automaticallyManageScrollViewInsets = false;
        self.autoManageStatusBarBackground = false;
        self.isImportant = true;
        
        _availableTabs = availableTabs;

        _item = item;
        _currentTab = selectedTab;
        _intent = intent;
        
        _caption = caption;
        _initialAdjustments = adjustments;
        _screenImage = screenImage;
        
        CGSize originalSize = _item.originalSize;
        if ([self presentedForAvatarCreation]) {
            CGFloat maxSide = [GPUImageContext maximumTextureSizeForThisDevice];
            if (MAX(_item.originalSize.width, _item.originalSize.height) > maxSide) {
                originalSize = TGScaleToFit(_item.originalSize, CGSizeMake(maxSide, maxSide));
            }
        }
        
        _queue = [[SQueue alloc] init];
        _photoEditor = [[PGPhotoEditor alloc] initWithOriginalSize:originalSize adjustments:adjustments forVideo:item.isVideo enableStickers:(intent & TGPhotoEditorControllerSignupAvatarIntent) == 0];
        if ([self presentedForAvatarCreation])
        {
            _photoEditor.cropOnLast = true;
            CGFloat shortSide = MIN(originalSize.width, originalSize.height);
            _photoEditor.cropRect = CGRectMake((originalSize.width - shortSide) / 2, (originalSize.height - shortSide) / 2, shortSide, shortSide);
        }
                
        if ([adjustments isKindOfClass:[TGVideoEditAdjustments class]])
        {
            TGVideoEditAdjustments *videoAdjustments = (TGVideoEditAdjustments *)adjustments;
            _photoEditor.trimStartValue = videoAdjustments.trimStartValue;
            _photoEditor.trimEndValue = videoAdjustments.trimEndValue;
        }
        
        _thumbnailsDisposable = [[SMetaDisposable alloc] init];
        
        _chaseTime = kCMTimeInvalid;
        
        self.customAppearanceMethodsForwarding = true;
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [_faceDetectorDisposable dispose];
    [_thumbnailsDisposable dispose];
}

- (void)loadView
{
    [super loadView];
    
    self.view.frame = (CGRect){ CGPointZero, [self referenceViewSize]};
    self.view.clipsToBounds = true;
    
    if (@available(iOS 11.0, *)) {
        self.view.accessibilityIgnoresInvertColors = true;
    }
    
    if ([self presentedForAvatarCreation] && ![self presentedFromCamera])
        self.view.backgroundColor = [UIColor blackColor];
    
    _wrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_wrapperView];
    
    _backgroundView = [[UIView alloc] initWithFrame:_wrapperView.bounds];
    _backgroundView.alpha = 0.0f;
    _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _backgroundView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarBackgroundColor];
    [_wrapperView addSubview:_backgroundView];
    
    _transitionWrapperView = [[UIView alloc] initWithFrame:_wrapperView.bounds];
    [_wrapperView addSubview:_transitionWrapperView];
    
    _containerView = [[UIView alloc] initWithFrame:CGRectZero];
    [_wrapperView addSubview:_containerView];
    
    _progressView = [[TGMessageImageViewOverlayView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 60.0f, 60.0f)];
    [_progressView setRadius:60.0];
    _progressView.userInteractionEnabled = false;
    
    __weak TGPhotoEditorController *weakSelf = self;
    
    void(^toolbarCancelPressed)(void) = ^
    {
        __strong TGPhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf cancelButtonPressed];
    };
    
    void(^toolbarDonePressed)(void) = ^
    {
        __strong TGPhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf doneButtonPressed];
    };
    
    void(^toolbarDoneLongPressed)(id) = ^(id sender)
    {
        __strong TGPhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf doneButtonLongPressed:sender];
    };
    
    void(^toolbarTabPressed)(TGPhotoEditorTab) = ^(TGPhotoEditorTab tab)
    {
        __strong TGPhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        switch (tab)
        {
            default:
                [strongSelf presentTab:tab];
                break;
                
            case TGPhotoEditorToolsTab:
            case TGPhotoEditorBlurTab:
            case TGPhotoEditorCurvesTab:
            case TGPhotoEditorTintTab:
                if ([strongSelf->_currentTabController isKindOfClass:[TGPhotoToolsController class]])
                    [strongSelf->_currentTabController handleTabAction:tab];
                else
                    [strongSelf presentTab:TGPhotoEditorToolsTab];
                break;
                
            case TGPhotoEditorPaintTab:
            case TGPhotoEditorEraserTab:
                if ([strongSelf->_currentTabController isKindOfClass:[TGPhotoPaintController class]])
                    [strongSelf->_currentTabController handleTabAction:tab];
                else
                    [strongSelf presentTab:TGPhotoEditorPaintTab];
                break;
                
            case TGPhotoEditorStickerTab:
            case TGPhotoEditorTextTab:
                [strongSelf->_currentTabController handleTabAction:tab];
                break;
                
            case TGPhotoEditorRotateTab:
            case TGPhotoEditorMirrorTab:
            case TGPhotoEditorAspectRatioTab:
                if ([strongSelf->_currentTabController isKindOfClass:[TGPhotoCropController class]] || [strongSelf->_currentTabController isKindOfClass:[TGPhotoAvatarPreviewController class]])
                    [strongSelf->_currentTabController handleTabAction:tab];
                break;
        }
    };
     
    TGPhotoEditorBackButton backButton = TGPhotoEditorBackButtonCancel;
    TGPhotoEditorDoneButton doneButton = TGPhotoEditorDoneButtonCheck;
    _portraitToolbarView = [[TGPhotoToolbarView alloc] initWithContext:_context backButton:backButton doneButton:doneButton solidBackground:true];
    [_portraitToolbarView setToolbarTabs:_availableTabs animated:false];
    [_portraitToolbarView setActiveTab:_currentTab];
    _portraitToolbarView.cancelPressed = toolbarCancelPressed;
    _portraitToolbarView.donePressed = toolbarDonePressed;
    _portraitToolbarView.doneLongPressed = toolbarDoneLongPressed;
    _portraitToolbarView.tabPressed = toolbarTabPressed;
    [_wrapperView addSubview:_portraitToolbarView];
    
    _landscapeToolbarView = [[TGPhotoToolbarView alloc] initWithContext:_context backButton:backButton doneButton:doneButton solidBackground:true];
    [_landscapeToolbarView setToolbarTabs:_availableTabs animated:false];
    [_landscapeToolbarView setActiveTab:_currentTab];
    _landscapeToolbarView.cancelPressed = toolbarCancelPressed;
    _landscapeToolbarView.donePressed = toolbarDonePressed;
    _landscapeToolbarView.doneLongPressed = toolbarDoneLongPressed;
    _landscapeToolbarView.tabPressed = toolbarTabPressed;
    
    if ([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad)
        [_wrapperView addSubview:_landscapeToolbarView];
    
    if ((_intent & TGPhotoEditorControllerWebIntent) || (_intent & TGPhotoEditorControllerAvatarIntent && _item.isVideo))
        [self updateDoneButtonEnabled:false animated:false];
    
    CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:self.view.frame toolbarLandscapeSize:TGPhotoEditorToolbarSize orientation:self.effectiveOrientation panelSize:TGPhotoEditorPanelSize hasOnScreenNavigation:self.hasOnScreenNavigation];
    CGSize fittedSize = TGScaleToSize(_photoEditor.rotatedCropSize, containerFrame.size);
    
    _previewView = [[TGPhotoEditorPreviewView alloc] initWithFrame:CGRectMake(0, 0, fittedSize.width, fittedSize.height)];
    _previewView.clipsToBounds = true;
    [_previewView setSnapshotImage:_screenImage];
    [_photoEditor setPreviewOutput:_previewView];
    [self updatePreviewView:true];
    
    if ([self presentedForAvatarCreation]) {
        _previewView.applyMirror = true;
        
        CGSize fittedSize  = TGScaleToSize(_photoEditor.originalSize, CGSizeMake(1024, 1024));
        _fullPreviewView = [[PGPhotoEditorView alloc] initWithFrame:CGRectMake(0, 0, fittedSize.width, fittedSize.height)];
        _photoEditor.additionalOutputs = @[_fullPreviewView];
        [self.view addSubview:_fullPreviewView];
        
        _fullPaintingView = [[UIImageView alloc] init];
        _fullPaintingView.frame = _fullPreviewView.frame;
        
        _fullEntitiesView = [[TGPhotoEntitiesContainerView alloc] init];
        _fullEntitiesView.userInteractionEnabled = false;
        CGRect rect = [TGPhotoPaintController fittedCropRect:_photoEditor.cropRect originalSize:_photoEditor.originalSize keepOriginalSize:true];
        _fullEntitiesView.frame = CGRectMake(0, 0, rect.size.width, rect.size.height);
    }
        
    _dotMarkerView = [[UIImageView alloc] initWithImage:TGCircleImage(7.0, [TGPhotoEditorInterfaceAssets accentColor])];
    [_scrubberView addSubview:_dotMarkerView];
    _dotMarkerView.center = CGPointMake(30.0, -20.0);
    
    _dotImageView = [[TGMediaPickerGalleryVideoScrubberThumbnailView alloc] initWithImage:nil originalSize:_photoEditor.originalSize cropRect:CGRectZero cropOrientation:UIImageOrientationUp cropMirrored:false];
    _dotImageView.frame = CGRectMake(0.0, 0.0, 160.0, 160.0);
    _dotImageView.userInteractionEnabled = true;
    
    CAShapeLayer* maskLayer = [CAShapeLayer new];
    maskLayer.frame = _dotImageView.bounds;
    maskLayer.path = [UIBezierPath bezierPathWithOvalInRect:_dotImageView.bounds].CGPath;
    _dotImageView.layer.mask = maskLayer;
    
    UITapGestureRecognizer *dotTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDotTap)];
    [_dotImageView addGestureRecognizer:dotTapRecognizer];
    
    if ([self presentedForAvatarCreation] && _item.isVideo) {
        _scrubberView = [[TGMediaPickerGalleryVideoScrubber alloc] initWithFrame:CGRectMake(0.0f, 0.0, _portraitToolbarView.frame.size.width, 68.0f)];
        _scrubberView.minimumLength = 3.0;
        _scrubberView.layer.allowsGroupOpacity = true;
        _scrubberView.hasDotPicker = true;
        _scrubberView.dataSource = self;
        _scrubberView.delegate = self;
        _scrubberView.clipsToBounds = false;
    }
    
    [self detectFaces];
    
    [self presentTab:_currentTab];
}

- (void)handleDotTap {
    TGPhotoAvatarPreviewController *previewController = (TGPhotoAvatarPreviewController *)_currentTabController;
    if (![previewController isKindOfClass:[TGPhotoAvatarPreviewController class]])
        return;
    
    [self stopVideoPlayback:false];
    [self seekVideo:_dotPosition];
        
    [previewController beginScrubbing:false];
    
    [_scrubberView setValue:_dotPosition resetPosition:true];
    
    __weak TGPhotoEditorController *weakSelf = self;
    [previewController endScrubbing:false completion:^bool{
        __strong TGPhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        return !strongSelf->_scrubberView.isScrubbing;
    }];
}

- (void)setToolbarHidden:(bool)hidden animated:(bool)animated
{
    if (self.requestToolbarsHidden == nil)
        return;
    
    if (_hiddenToolbarView == hidden)
        return;
    
    if (hidden)
    {
        [_portraitToolbarView transitionOutAnimated:animated transparent:true hideOnCompletion:false];
        [_landscapeToolbarView transitionOutAnimated:animated transparent:true hideOnCompletion:false];
    }
    else
    {
        [_portraitToolbarView transitionInAnimated:animated transparent:true];
        [_landscapeToolbarView transitionInAnimated:animated transparent:true];
    }
    
    self.requestToolbarsHidden(hidden, animated);
    _hiddenToolbarView = hidden;
}

- (BOOL)prefersStatusBarHidden
{
    if (_forceStatusBarVisible)
        return false;
    
    if ([self inFormSheet])
        return false;
    
    if (self.navigationController != nil)
        return _viewFillingWholeScreen;
    
    if (self.dontHideStatusBar)
        return false;
    
    return true;
}

- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures
{
    return [_currentTabController preferredScreenEdgesDeferringSystemGestures];
}

- (UIBarStyle)requiredNavigationBarStyle
{
    return UIBarStyleDefault;
}

- (bool)navigationBarShouldBeHidden
{
    return true;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([_currentTabController isKindOfClass:[TGPhotoCropController class]])
        return;
    
    if (self.item.isVideo) {
        _scrubberView.allowsTrimming = self.item.originalDuration >= TGVideoEditMinimumTrimmableDuration;
        _scrubberView.disableZoom = true;
        _scrubberView.disableTimeDisplay = true;
        _scrubberView.trimStartValue = 0.0;
        _scrubberView.trimEndValue = MIN(9.9, self.item.originalDuration);
        [_scrubberView setTrimApplied:self.item.originalDuration > 9.9];
        _scrubberView.maximumLength = 9.9;
        
        [self setVideoEndTime:_scrubberView.trimEndValue];
    }
    
    NSTimeInterval position = 0;
    TGMediaVideoEditAdjustments *adjustments = [_photoEditor exportAdjustments];
    if ([adjustments isKindOfClass:[TGMediaVideoEditAdjustments class]])
        position = adjustments.trimStartValue;
    
    PGPhotoEditor *photoEditor = _photoEditor;
    
    CGSize screenSize = TGNativeScreenSize();
    SSignal *signal = nil;
    if ([_photoEditor hasDefaultCropping] && (NSInteger)screenSize.width == 320)
    {
        signal = [self.requestOriginalScreenSizeImage(_item, position) filter:^bool(id image)
        {
            return [image isKindOfClass:[UIImage class]];
        }];
    }
    else
    {
        if (_item.isVideo) {
            signal = [self.requestOriginalFullSizeImage(_item, position) deliverOn:_queue];
        } else {
            bool avatar = [self presentedForAvatarCreation];
            signal = [[[[self.requestOriginalFullSizeImage(_item, position) takeLast] deliverOn:_queue] filter:^bool(id image)
            {
                return [image isKindOfClass:[UIImage class]];
            }] map:^UIImage *(UIImage *image)
            {
                if (avatar) {
                    CGFloat maxSide = [GPUImageContext maximumTextureSizeForThisDevice];
                    if (MAX(image.size.width, image.size.height) > maxSide) {
                        CGSize fittedSize = TGScaleToFit(image.size, CGSizeMake(maxSide, maxSide));
                        return TGScaleImageToPixelSize(image, fittedSize);
                    } else {
                        return image;
                    }
                } else {
                    return TGPhotoEditorCrop(image, nil, photoEditor.cropOrientation, photoEditor.cropRotation, photoEditor.cropRect, photoEditor.cropMirrored, TGPhotoEditorScreenImageMaxSize(), photoEditor.originalSize, true);
                }
            }];
        }
    }
    
    __weak TGPhotoEditorController *weakSelf = self;
    [signal startWithNext:^(id next)
    {
        __strong TGPhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf->_dismissed)
            return;
        
        CGFloat progress = 0.0;
        bool progressVisible = false;
        bool doneEnabled = true;
        if ([next isKindOfClass:[UIImage class]]) {
            [photoEditor setImage:(UIImage *)next forCropRect:photoEditor.cropRect cropRotation:photoEditor.cropRotation cropOrientation:photoEditor.cropOrientation cropMirrored:photoEditor.cropMirrored fullSize:false];
            if (!((UIImage *)next).degraded) {
                progress = 1.0f;
            }
        } else if ([next isKindOfClass:[AVAsset class]]) {
            strongSelf->_playerItem = [AVPlayerItem playerItemWithAsset:(AVAsset *)next];
            strongSelf->_player = [AVPlayer playerWithPlayerItem:strongSelf->_playerItem];
            strongSelf->_player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
            strongSelf->_player.muted = true;
            
            [photoEditor setPlayerItem:strongSelf->_playerItem forCropRect:photoEditor.cropRect cropRotation:0.0 cropOrientation:photoEditor.cropOrientation cropMirrored:photoEditor.cropMirrored];
                                    
            TGDispatchOnMainThread(^
            {
                [strongSelf->_previewView performTransitionInWithCompletion:^{}];
                
                if (strongSelf->_scheduledVideoPlayback) {
                    strongSelf->_scheduledVideoPlayback = false;
                    [strongSelf startVideoPlayback:true];
                }
            });
            progress = 1.0f;
            doneEnabled = true;
        } else if ([next isKindOfClass:[NSNumber class]]) {
            progress = [next floatValue];
            progressVisible = true;
            doneEnabled = false;
        }
        
        TGDispatchOnMainThread(^{
            if (strongSelf->_dismissed)
                return;
            
            [strongSelf setProgressVisible:progressVisible value:progress animated:progressVisible];
            [strongSelf updateDoneButtonEnabled:doneEnabled animated:true];
            if (progressVisible)
                strongSelf->_hadProgress = true;
            
            if (strongSelf->_hadProgress && !progressVisible) {
                [strongSelf->_progressView setPlay];
                [strongSelf->_scrubberView reloadThumbnails];
            }
        });
        
        if ([next isKindOfClass:[NSNumber class]]) {
            return;
        }
        
        if (strongSelf->_ignoreDefaultPreviewViewTransitionIn)
        {
            __strong TGPhotoEditorController *strongSelf = weakSelf;
             if (strongSelf == nil)
                 return;
            TGDispatchOnMainThread(^
            {
                if (strongSelf->_dismissed)
                    return;
                if ([strongSelf->_currentTabController isKindOfClass:[TGPhotoQualityController class]])
                    [strongSelf->_previewView setSnapshotImageOnTransition:next];
                else
                    [strongSelf->_previewView setSnapshotImage:next];
            });
        }
        else
        {
            [photoEditor processAnimated:false completion:^
            {
                __strong TGPhotoEditorController *strongSelf = weakSelf;
                if (strongSelf == nil)
                     return;
                TGDispatchOnMainThread(^
                {
                    if (strongSelf->_dismissed)
                        return;
                    [strongSelf->_previewView performTransitionInWithCompletion:^
                    {
                        if (!strongSelf.skipInitialTransition)
                            [strongSelf->_previewView setSnapshotImage:next];
                    }];
                });
            }];
        }
    }];
}

- (NSTimeInterval)trimStartValue {
    if (_scrubberView != nil) {
        return _scrubberView.trimStartValue;
    } else {
        return _photoEditor.trimStartValue;
    }
}

- (NSTimeInterval)trimEndValue {
    if (_scrubberView != nil) {
        if (_scrubberView.trimEndValue > 0.0)
            return _scrubberView.trimEndValue;
        else
            return MIN(9.9, _scrubberView.duration);
    } else {
        return _photoEditor.trimEndValue;
    }
}

- (void)_setupPlaybackStartedObserver
{
    CMTime startTime = CMTimeMake(10, 100);
    if (self.trimStartValue > DBL_EPSILON)
        startTime = CMTimeMakeWithSeconds(self.trimStartValue + 0.1, NSEC_PER_SEC);
    
    __weak TGPhotoEditorController *weakSelf = self;
    _playerStartedObserver = [_player addBoundaryTimeObserverForTimes:@[[NSValue valueWithCMTime:startTime]] queue:NULL usingBlock:^
    {
        __strong TGPhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
    
        [strongSelf->_player removeTimeObserver:strongSelf->_playerStartedObserver];
        strongSelf->_playerStartedObserver = nil;
        
        if (CMTimeGetSeconds(strongSelf->_player.currentItem.duration) > 0)
            [strongSelf _setupPlaybackReachedEndObserver];
    }];
}

- (void)_setupPlaybackReachedEndObserver
{
    if (_playerReachedEndObserver != nil)
        [_player removeTimeObserver:_playerReachedEndObserver];
    
    CMTime endTime = CMTimeSubtract(_player.currentItem.duration, CMTimeMake(10, 100));
    if (self.trimEndValue > DBL_EPSILON && self.trimEndValue < CMTimeGetSeconds(_player.currentItem.duration))
        endTime = CMTimeMakeWithSeconds(self.trimEndValue - 0.1, NSEC_PER_SEC);
    
    CMTime startTime = CMTimeMake(5, 100);
    if (self.trimStartValue > DBL_EPSILON)
        startTime = CMTimeMakeWithSeconds(self.trimStartValue + 0.05, NSEC_PER_SEC);
    
    __weak TGPhotoEditorController *weakSelf = self;
    _playerReachedEndObserver = [_player addBoundaryTimeObserverForTimes:@[[NSValue valueWithCMTime:endTime]] queue:NULL usingBlock:^
    {
        __strong TGPhotoEditorController *strongSelf = weakSelf;
        if (strongSelf != nil && !strongSelf->_dismissed) {
            [strongSelf->_player seekToTime:startTime];
            [strongSelf->_scrubberView setValue:strongSelf.trimStartValue resetPosition:true];
            
            [strongSelf->_fullEntitiesView seekTo:0.0];
            [strongSelf->_fullEntitiesView play];
        }
    }];
}

- (void)returnFullPreviewView {
    _fullPreviewView.frame = CGRectMake(-10000, 0, _fullPreviewView.frame.size.width, _fullPreviewView.frame.size.height);
    [self.view addSubview:_fullPreviewView];
}

- (void)startVideoPlayback:(bool)reset {
    if (reset && _player == nil) {
        _scheduledVideoPlayback = true;
        return;
    }
    
    if (reset) {
        NSTimeInterval startPosition = 0.0f;
        if (self.trimStartValue > DBL_EPSILON)
            startPosition = self.trimStartValue;
        
        CMTime targetTime = CMTimeMakeWithSeconds(startPosition, NSEC_PER_SEC);
        [_player.currentItem seekToTime:targetTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        
        [self _setupPlaybackStartedObserver];
        
        if (!_registeredKeypathObserver) {
            [_player addObserver:self forKeyPath:@"rate" options:NSKeyValueObservingOptionNew context:nil];
            _registeredKeypathObserver = true;
        }
        
        [_fullEntitiesView seekTo:0.0];
        [_fullEntitiesView play];
    } else {
        [_fullEntitiesView play];
    }
    
    _isPlaying = true;
    [_player play];
    
    [_positionTimer invalidate];
    _positionTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(positionTimerEvent) interval:0.25 repeat:true];
    [self positionTimerEvent];
}

- (void)stopVideoPlayback:(bool)reset {
    if (reset) {
        if (_playerStartedObserver != nil)
            [_player removeTimeObserver:_playerStartedObserver];
        if (_playerReachedEndObserver != nil)
            [_player removeTimeObserver:_playerReachedEndObserver];
        
        if (_registeredKeypathObserver) {
            [_player removeObserver:self forKeyPath:@"rate" context:nil];
            _registeredKeypathObserver = false;
        }
        
        [_scrubberView setIsPlaying:false];
    } else {
        [_fullEntitiesView pause];
    }
    
    _isPlaying = false;
    [_player pause];
    
    [_positionTimer invalidate];
    _positionTimer = nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)__unused change context:(void *)__unused context
{
    if (object == _player && [keyPath isEqualToString:@"rate"])
    {
        if ([_currentTabController isKindOfClass:[TGPhotoAvatarPreviewController class]]) {
            [_scrubberView setIsPlaying:_player.rate > FLT_EPSILON];
        }
    }
}

- (void)positionTimerEvent
{
    if ([_currentTabController isKindOfClass:[TGPhotoAvatarPreviewController class]]) {
        [_scrubberView setValue:CMTimeGetSeconds(_player.currentItem.currentTime) resetPosition:false];
    }
}

- (NSTimeInterval)currentTime {
    return CMTimeGetSeconds(_player.currentItem.currentTime) - [self trimStartValue];
}

- (void)setMinimalVideoDuration:(NSTimeInterval)duration {
    _scrubberView.minimumLength = duration;
}

- (void)seekVideo:(NSTimeInterval)position {
    CMTime targetTime = CMTimeMakeWithSeconds(position, NSEC_PER_SEC);
    
    if (CMTIME_COMPARE_INLINE(targetTime, !=, _chaseTime))
    {
        _chaseTime = targetTime;
        
        if (!_chasingTime) {
            [self chaseTime];
        }
    }
}

- (void)chaseTime {
    _chasingTime = true;
    CMTime currentChasingTime = _chaseTime;
    
    [_player.currentItem seekToTime:currentChasingTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
        if (!_chaseStart) {
            TGDispatchOnMainThread(^{
               [_fullEntitiesView seekTo:CMTimeGetSeconds(currentChasingTime) - _scrubberView.trimStartValue];
            });
        }
        if (CMTIME_COMPARE_INLINE(currentChasingTime, ==, _chaseTime)) {
            _chasingTime = false;
            _chaseTime = kCMTimeInvalid;
        } else {
            [self chaseTime];
        }
    }];
}

- (void)setVideoEndTime:(NSTimeInterval)endTime {
    _player.currentItem.forwardPlaybackEndTime = CMTimeMakeWithSeconds(endTime, NSEC_PER_SEC);
    [self _setupPlaybackReachedEndObserver];
}

- (void)viewWillAppear:(BOOL)animated
{
    if (![self inFormSheet] && (self.navigationController != nil || self.dontHideStatusBar))
    {
        if (animated)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                [_context setApplicationStatusBarAlpha:0.0f];
            }];
        }
        else
        {
            [_context setApplicationStatusBarAlpha:0.0f];
        }
    }
    else if (!self.dontHideStatusBar)
    {
        if (iosMajorVersion() < 7) {
            [_context forceSetStatusBarHidden:true withAnimation:UIStatusBarAnimationNone];
        }
    }
    
    [super viewWillAppear:animated];

    [self transitionIn];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (self.navigationController != nil)
    {
        _viewFillingWholeScreen = true;

        if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)])
            [self setNeedsStatusBarAppearanceUpdate];
        else
            [_context forceSetStatusBarHidden:[self prefersStatusBarHidden] withAnimation:UIStatusBarAnimationNone];
        
        self.navigationController.interactivePopGestureRecognizer.enabled = false;
    }
    
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (self.navigationController != nil || self.dontHideStatusBar)
    {
        _viewFillingWholeScreen = false;
        
        if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)])
            [self setNeedsStatusBarAppearanceUpdate];
        else
            [_context forceSetStatusBarHidden:[self prefersStatusBarHidden] withAnimation:UIStatusBarAnimationNone];
        
        if (animated)
        {
            [UIView animateWithDuration:0.3 animations:^
            {
                [_context setApplicationStatusBarAlpha:1.0f];
            }];
        }
        else
        {
            [_context setApplicationStatusBarAlpha:1.0f];
        }
        
        self.navigationController.interactivePopGestureRecognizer.enabled = true;
    }

    if (@available(iOS 11.0, *)) {
        if ([self respondsToSelector:@selector(setNeedsUpdateOfScreenEdgesDeferringSystemGestures)])
            [self setNeedsUpdateOfScreenEdgesDeferringSystemGestures];
    }
    
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    //strange ios6 crashfix
    if (iosMajorVersion() < 7 && !self.dontHideStatusBar)
    {
        TGDispatchAfter(0.5f, dispatch_get_main_queue(), ^
        {
            [_context forceSetStatusBarHidden:false withAnimation:UIStatusBarAnimationNone];
        });
    }
}

- (void)updateDoneButtonEnabled:(bool)enabled animated:(bool)animated
{
    [_portraitToolbarView setEditButtonsEnabled:enabled animated:animated];
    [_landscapeToolbarView setEditButtonsEnabled:enabled animated:animated];
    
    [_portraitToolbarView setDoneButtonEnabled:enabled animated:animated];
    [_landscapeToolbarView setDoneButtonEnabled:enabled animated:animated];
    
    if (animated) {
        [UIView animateWithDuration:0.2 animations:^{
            _scrubberView.alpha = enabled ? 1.0 : 0.2;
        }];
    } else {
        _scrubberView.alpha = enabled ? 1.0 : 0.2;
    }
    
    _scrubberView.userInteractionEnabled = enabled;
}

- (void)updateStatusBarAppearanceForDismiss
{
    _forceStatusBarVisible = true;
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)])
        [self setNeedsStatusBarAppearanceUpdate];
    else
        [_context forceSetStatusBarHidden:[self prefersStatusBarHidden] withAnimation:UIStatusBarAnimationNone];
}

- (BOOL)shouldAutorotate
{
    return (!(_currentTabController != nil && ![_currentTabController shouldAutorotate]) && [super shouldAutorotate]);
}

#pragma mark - 

- (void)createEditedImageWithEditorValues:(id<TGMediaEditAdjustments>)editorValues createThumbnail:(bool)createThumbnail saveOnly:(bool)saveOnly completion:(void (^)(UIImage *))completion
{
    bool avatar = [self presentedForAvatarCreation];
    
    if (!saveOnly)
    {
        if (!avatar && [editorValues isDefaultValuesForAvatar:false])
        {
            if (self.willFinishEditing != nil)
                self.willFinishEditing(nil, [_currentTabController currentResultRepresentation], true);
            
            if (self.didFinishEditing != nil)
                self.didFinishEditing(nil, nil, nil, true);

            if (completion != nil)
                completion(nil);
            
            return;
        }
    }
    
    if (!saveOnly && self.willFinishEditing != nil)
        self.willFinishEditing(editorValues, [_currentTabController currentResultRepresentation], true);
    
    if (!saveOnly && !avatar && completion != nil)
        completion(nil);
    
    UIImage *fullSizeImage = self.fullSizeImage;
    PGPhotoEditor *photoEditor = _photoEditor;
    
    SSignal *imageSignal = nil;
    if (fullSizeImage == nil)
    {
        imageSignal = [[[self.requestOriginalFullSizeImage(_item, 0) filter:^bool(id result)
        {
            return [result isKindOfClass:[UIImage class]];
        }] takeLast] map:^UIImage *(UIImage *image) {
            if (avatar) {
                CGFloat maxSide = [GPUImageContext maximumTextureSizeForThisDevice];
                if (MAX(image.size.width, image.size.height) > maxSide) {
                    CGSize fittedSize = TGScaleToFit(image.size, CGSizeMake(maxSide, maxSide));
                    return TGScaleImageToPixelSize(image, fittedSize);
                } else {
                    return image;
                }
            } else {
                return image;
            }
        }];
    }
    else
    {
        imageSignal = [SSignal single:fullSizeImage];
    }
    
    bool hasImageAdjustments = editorValues.toolsApplied || saveOnly;
    bool hasPainting = editorValues.hasPainting;
    bool hasAnimation = editorValues.paintingData.hasAnimation;
    
    SSignal *(^imageCropSignal)(UIImage *, bool) = ^(UIImage *image, bool resize)
    {
        return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            UIImage *paintingImage = !hasImageAdjustments ? editorValues.paintingData.image : nil;
            UIImage *croppedImage = TGPhotoEditorCrop(image, paintingImage, photoEditor.cropOrientation, photoEditor.cropRotation, photoEditor.cropRect, photoEditor.cropMirrored, TGPhotoEditorResultImageMaxSize, photoEditor.originalSize, resize);
            [subscriber putNext:croppedImage];
            [subscriber putCompletion];
            
            return nil;
        }];
    };
    
    SQueue *queue = _queue;
    SSignal *(^imageRenderSignal)(UIImage *) = ^(UIImage *image)
    {
        return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            [photoEditor setImage:image forCropRect:photoEditor.cropRect cropRotation:photoEditor.cropRotation cropOrientation:photoEditor.cropOrientation cropMirrored:photoEditor.cropMirrored fullSize:true];
            [photoEditor createResultImageWithCompletion:^(UIImage *result)
            {
                [queue dispatch:^{
                    UIImage *final = result;
                    if (hasPainting)
                    {
                        final = TGPaintCombineCroppedImages(final, editorValues.paintingData.image, true, photoEditor.originalSize, photoEditor.cropRect, photoEditor.cropOrientation, photoEditor.cropRotation, photoEditor.cropMirrored);
                        [TGPaintingData facilitatePaintingData:editorValues.paintingData];
                    }
                    
                    [subscriber putNext:final];
                    [subscriber putCompletion];
                }];
            }];
            
            return nil;
        }];
    };

    SSignal *renderedImageSignal = [[imageSignal mapToSignal:^SSignal *(UIImage *image)
    {
        return [imageCropSignal(image, !hasImageAdjustments || hasPainting || MAX(image.size.width, image.size.height) > 4096) startOn:_queue];
    }] mapToSignal:^SSignal *(UIImage *image)
    {
        if (hasImageAdjustments)
            return [[[SSignal complete] delay:0.3 onQueue:queue] then:imageRenderSignal(image)];
        else
            return [SSignal single:image];
    }];
    
    if (saveOnly)
    {
        [[renderedImageSignal deliverOn:[SQueue mainQueue]] startWithNext:^(UIImage *image)
        {
            if (completion != nil)
                completion(image);
        }];
    }
    else
    {
        void (^didFinishRenderingFullSizeImage)(UIImage *) = self.didFinishRenderingFullSizeImage;
        void (^didFinishEditing)(id<TGMediaEditAdjustments>, UIImage *, UIImage *, bool ) = self.didFinishEditing;
        
        [[[[renderedImageSignal map:^id(UIImage *image)
        {
            if (!hasImageAdjustments)
            {
                if (hasPainting && !hasAnimation && didFinishRenderingFullSizeImage != nil)
                    didFinishRenderingFullSizeImage(image);

                return image;
            }
            else
            {
                if (!saveOnly && !hasAnimation && didFinishRenderingFullSizeImage != nil)
                    didFinishRenderingFullSizeImage(image);
                
                return TGPhotoEditorFitImage(image, TGPhotoEditorResultImageMaxSize);
            }
        }] map:^NSDictionary *(UIImage *image)
        {
            NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
            if (image != nil)
                result[@"image"] = image;
            
            if (createThumbnail)
            {
                CGSize fillSize = TGPhotoThumbnailSizeForCurrentScreen();
                fillSize.width = CGCeil(fillSize.width);
                fillSize.height = CGCeil(fillSize.height);
                
                CGSize size = TGScaleToFillSize(image.size, fillSize);
                
                UIGraphicsBeginImageContextWithOptions(size, true, 0.0f);
                CGContextRef context = UIGraphicsGetCurrentContext();
                CGContextSetInterpolationQuality(context, kCGInterpolationMedium);
                
                [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
                
                UIImage *thumbnailImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                
                if (thumbnailImage != nil)
                    result[@"thumbnail"] = thumbnailImage;
            }
            
            return result;
        }] deliverOn:[SQueue mainQueue]] startWithNext:^(NSDictionary *result)
        {
            UIImage *image = result[@"image"];
            UIImage *thumbnailImage = result[@"thumbnail"];
            
            if (avatar && image.size.width < 150.0) {
                image = TGScaleImageToPixelSize(image, CGSizeMake(150.0, 150.0));
            }
            
            if (avatar && completion != nil) {
                completion(image);
            }
            
            if (!saveOnly && didFinishEditing != nil)
                didFinishEditing(editorValues, image, thumbnailImage, true);
        } error:^(__unused id error)
        {
            TGLegacyLog(@"renderedImageSignal error");
        } completed:nil];
    }
}

#pragma mark - Intent

- (bool)presentedFromCamera
{
    return _intent & TGPhotoEditorControllerFromCameraIntent;
}

- (bool)presentedForAvatarCreation
{
    return _intent & (TGPhotoEditorControllerAvatarIntent | TGPhotoEditorControllerSignupAvatarIntent);
}

#pragma mark - Transition

- (void)transitionIn
{
    if (self.navigationController != nil)
        return;
    
    CGFloat delay = [self presentedFromCamera] ? 0.1f: 0.0f;
    
    _portraitToolbarView.alpha = 0.0f;
    _landscapeToolbarView.alpha = 0.0f;
    [UIView animateWithDuration:0.3f delay:delay options:UIViewAnimationOptionCurveLinear animations:^
    {
        _portraitToolbarView.alpha = 1.0f;
        _landscapeToolbarView.alpha = 1.0f;
    } completion:nil];
}

- (void)transitionOutSaving:(bool)saving completion:(void (^)(void))completion
{
    _dismissed = true;
    if (!saving) {
        [self stopVideoPlayback:true];
    }
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _portraitToolbarView.alpha = 0.0f;
        _landscapeToolbarView.alpha = 0.0f;
    }];
    
    _currentTabController.beginTransitionOut = self.beginTransitionOut;
    [self setToolbarHidden:false animated:true];
    
    if (self.beginCustomTransitionOut != nil && !saving)
    {
        id rep = [_currentTabController currentResultRepresentation];
        if ([rep isKindOfClass:[UIImage class]])
        {
            UIImageView *imageView = [[UIImageView alloc] initWithImage:(UIImage *)rep];
            rep = imageView;
        }
        [_currentTabController prepareForCustomTransitionOut];
        
        TGPhotoEditorTabController *tabController = _currentTabController;
        self.beginCustomTransitionOut([_currentTabController transitionOutReferenceFrame], rep, ^{
            [tabController finishCustomTransitionOut];
            if (completion)
                completion();
        });
    }
    else
    {
        [_currentTabController transitionOutSaving:saving completion:^
        {
            if (completion != nil)
                completion();
            
            if (self.finishedTransitionOut != nil)
                self.finishedTransitionOut(saving);
        }];
    }
}

- (void)presentTab:(TGPhotoEditorTab)tab
{    
    if (_switchingTab || (tab == _currentTab && _currentTabController != nil))
        return;
    
    bool isInitialAppearance = true;

    CGRect transitionReferenceFrame = CGRectZero;
    UIView *transitionReferenceView = nil;
    UIView *transitionParentView = nil;
    bool transitionNoTransitionView = false;
    
    UIImage *snapshotImage = nil;
    UIView *snapshotView = nil;
    
    TGPhotoEditorTabController *currentController = _currentTabController;
    TGPhotoEditorTab switchingFromTab = TGPhotoEditorNoneTab;
    if (currentController != nil)
    {
        if (![currentController isDismissAllowed])
            return;
        
        [self savePaintingData];
                
        bool resetTransform = false;
        if ([self presentedForAvatarCreation] && tab == TGPhotoEditorCropTab && [currentController isKindOfClass:[TGPhotoPaintController class]]) {
            resetTransform = true;
        }
        
        currentController.switchingToTab = tab;
        [currentController transitionOutSwitching:true completion:^
        {
            [currentController removeFromParentViewController];
            [currentController.view removeFromSuperview];
            
            if (resetTransform) {
                _previewView.transform = CGAffineTransformIdentity;
            }
        }];
        
        transitionReferenceFrame = [currentController transitionOutReferenceFrame];
        transitionReferenceView = [currentController transitionOutReferenceView];
        transitionNoTransitionView = false;
        
        if ([currentController isKindOfClass:[TGPhotoCropController class]])
        {
            _backgroundView.alpha = 1.0f;
            [UIView animateWithDuration:0.3f animations:^
            {
                _backgroundView.alpha = 0.0f;
            } completion:nil];
            switchingFromTab = TGPhotoEditorCropTab;
        } else if ([currentController isKindOfClass:[TGPhotoToolsController class]]) {
            switchingFromTab = TGPhotoEditorToolsTab;
        }
        
        isInitialAppearance = false;
        
        snapshotView = [currentController snapshotView];
    }
    else
    {
        if (self.beginTransitionIn != nil)
            transitionReferenceView = self.beginTransitionIn(&transitionReferenceFrame, &transitionParentView);
        
        if ([self presentedFromCamera] && [self presentedForAvatarCreation])
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
            {
                transitionReferenceFrame = CGRectMake(self.view.frame.size.width - transitionReferenceFrame.size.height - transitionReferenceFrame.origin.y,
                                                      transitionReferenceFrame.origin.x,
                                                      transitionReferenceFrame.size.height, transitionReferenceFrame.size.width);
            }
            else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
            {
                transitionReferenceFrame = CGRectMake(transitionReferenceFrame.origin.y,
                                                      self.view.frame.size.height - transitionReferenceFrame.size.width - transitionReferenceFrame.origin.x,
                                                      transitionReferenceFrame.size.height, transitionReferenceFrame.size.width);
            }
#pragma clang diagnostic pop
        }
        
        if ([self presentedForAvatarCreation] && ![self presentedFromCamera])
            transitionNoTransitionView = true;
        
        snapshotImage = _screenImage;
    }
    
    if (_currentTabController == nil && self.skipInitialTransition) {
        [self presentAnimated:true];
    }
    
    _switchingTab = true;
    
    if ([_currentTabController isKindOfClass:[TGPhotoAvatarPreviewController class]]) {
        if (_item.isVideo && !_isPlaying) {
            [self setPlayButtonHidden:true animated:false];
            [self startVideoPlayback:false];
        } else if (!_item.isVideo) {
            [_photoEditor processAnimated:false completion:nil];
        }
    }
    
    TGPhotoEditorBackButton backButtonType = TGPhotoEditorBackButtonCancel;
    TGPhotoEditorDoneButton doneButtonType = TGPhotoEditorDoneButtonCheck;
    
    __weak TGPhotoEditorController *weakSelf = self;
    TGPhotoEditorTabController *controller = nil;
    switch (tab)
    {
        case TGPhotoEditorCropTab:
        {
            _fullPaintingView.hidden = false;
            
            [self updatePreviewView:true];
            __block UIView *initialBackgroundView = nil;
            
            if ([self presentedForAvatarCreation])
            {
                bool skipInitialTransition = (![self presentedFromCamera] && self.navigationController != nil) || self.skipInitialTransition;
                
                TGPhotoAvatarPreviewController *cropController = [[TGPhotoAvatarPreviewController alloc] initWithContext:_context photoEditor:_photoEditor previewView:_previewView];
                cropController.scrubberView = _scrubberView;
                cropController.dotImageView = _dotImageView;
                cropController.dotMarkerView = _dotMarkerView;
                cropController.fullPreviewView = _fullPreviewView;
                cropController.fullPaintingView = _fullPaintingView;
                cropController.fullEntitiesView = _fullEntitiesView;
                cropController.fullEntitiesView.userInteractionEnabled = false;
                cropController.fromCamera = [self presentedFromCamera];
                cropController.skipTransitionIn = skipInitialTransition;
                if (snapshotImage != nil)
                    [cropController setSnapshotImage:snapshotImage];
                cropController.toolbarLandscapeSize = TGPhotoEditorToolbarSize;
                cropController.controlVideoPlayback = ^(bool play) {
                    __strong TGPhotoEditorController *strongSelf = weakSelf;
                    if (strongSelf == nil || strongSelf->_progressVisible)
                        return;
                    if (play) {
                        [strongSelf startVideoPlayback:false];
                    } else {
                        [strongSelf stopVideoPlayback:false];
                    }
                };
                cropController.isVideoPlaying = ^bool{
                    __strong TGPhotoEditorController *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return false;
                    return strongSelf->_isPlaying;
                };
                cropController.togglePlayback = ^{
                    __strong TGPhotoEditorController *strongSelf = weakSelf;
                    if (strongSelf == nil || !strongSelf->_item.isVideo || strongSelf->_progressVisible)
                        return;
                    
                    if (strongSelf->_isPlaying) {
                        [strongSelf stopVideoPlayback:false];
                        [strongSelf setPlayButtonHidden:false animated:true];
                    } else {
                        [strongSelf startVideoPlayback:false];
                        [strongSelf setPlayButtonHidden:true animated:true];
                    }
                };
                cropController.croppingChanged = ^{
                    __strong TGPhotoEditorController *strongSelf = weakSelf;
                    if (strongSelf != nil) {
                        [strongSelf->_scrubberView updateThumbnails];
                        
                        strongSelf->_dotImageView.cropRect = strongSelf->_photoEditor.cropRect;
                        strongSelf->_dotImageView.cropOrientation = strongSelf->_photoEditor.cropOrientation;
                        strongSelf->_dotImageView.cropMirrored = strongSelf->_photoEditor.cropMirrored;
                        [strongSelf->_dotImageView updateCropping:true];
                        
                        [strongSelf updatePreviewView:false];
                    }
                };
                cropController.beginTransitionIn = ^UIView *(CGRect *referenceFrame, UIView **parentView, bool *noTransitionView)
                {
                    __strong TGPhotoEditorController *strongSelf = weakSelf;
                    *referenceFrame = transitionReferenceFrame;
                    *noTransitionView = transitionNoTransitionView;
                    *parentView = transitionParentView;
                    
                    if (strongSelf != nil)
                    {
                        UIView *backgroundView = nil;
                        if (!skipInitialTransition)
                        {
                            UIView *backgroundSuperview = transitionParentView;
                            if (backgroundSuperview == nil)
                                backgroundSuperview = transitionReferenceView.superview.superview;
                            
                            initialBackgroundView = [[UIView alloc] initWithFrame:backgroundSuperview.bounds];
                            initialBackgroundView.alpha = 0.0f;
                            initialBackgroundView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarBackgroundColor];
                            [backgroundSuperview addSubview:initialBackgroundView];
                            backgroundView = initialBackgroundView;
                        }
                        else
                        {
                            backgroundView = strongSelf->_backgroundView;
                        }
                        
                        [UIView animateWithDuration:0.3f animations:^
                         {
                            backgroundView.alpha = 1.0f;
                        }];
                    }
                    
                    return transitionReferenceView;
                };
                cropController.finishedTransitionIn = ^
                {
                    __strong TGPhotoEditorController *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    if (!skipInitialTransition)
                    {
                        [initialBackgroundView removeFromSuperview];
                        if (strongSelf.finishedTransitionIn != nil)
                            strongSelf.finishedTransitionIn();
                    }
                    else
                    {
                        strongSelf->_backgroundView.alpha = 0.0f;
                    }
                    
                    strongSelf->_switchingTab = false;
                    
                    if (isInitialAppearance)
                        [strongSelf startVideoPlayback:true];
                };
                cropController.finishedTransitionOut = ^
                {
                    __strong TGPhotoEditorController *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    strongSelf->_fullPaintingView.hidden = true;
                    if (strongSelf->_currentTabController.finishedTransitionIn != nil) {
                        strongSelf->_currentTabController.finishedTransitionIn();
                        strongSelf->_currentTabController.finishedTransitionIn = nil;
                    }
                    
                    [strongSelf->_currentTabController _finishedTransitionInWithView:nil];
                    
                    [strongSelf returnFullPreviewView];
                };
                controller = cropController;
                
                doneButtonType = TGPhotoEditorDoneButtonDone;
            }
            else
            {
                TGPhotoCropController *cropController = [[TGPhotoCropController alloc] initWithContext:_context photoEditor:_photoEditor previewView:_previewView metadata:self.metadata forVideo:(_intent == TGPhotoEditorControllerVideoIntent)];
                if (snapshotView != nil)
                    [cropController setSnapshotView:snapshotView];
                else if (snapshotImage != nil)
                    [cropController setSnapshotImage:snapshotImage];
                cropController.toolbarLandscapeSize = TGPhotoEditorToolbarSize;
                cropController.beginTransitionIn = ^UIView *(CGRect *referenceFrame, UIView **parentView, bool *noTransitionView)
                {
                    *referenceFrame = transitionReferenceFrame;
                    *noTransitionView = transitionNoTransitionView;
                    *parentView = transitionParentView;
                    
                    __strong TGPhotoEditorController *strongSelf = weakSelf;
                    if (strongSelf != nil)
                    {
                        UIView *backgroundView = nil;
                        if (isInitialAppearance)
                        {
                            UIView *backgroundSuperview = transitionParentView;
                            if (backgroundSuperview == nil)
                                backgroundSuperview = transitionReferenceView.superview.superview;
                            
                            initialBackgroundView = [[UIView alloc] initWithFrame:backgroundSuperview.bounds];
                            initialBackgroundView.alpha = 0.0f;
                            initialBackgroundView.backgroundColor = [TGPhotoEditorInterfaceAssets toolbarBackgroundColor];
                            [backgroundSuperview addSubview:initialBackgroundView];
                            backgroundView = initialBackgroundView;
                        }
                        else
                        {
                            backgroundView = strongSelf->_backgroundView;
                        }
                        
                        [UIView animateWithDuration:0.3f animations:^
                        {
                            backgroundView.alpha = 1.0f;
                        }];
                    }
                    
                    return transitionReferenceView;
                };
                cropController.finishedTransitionIn = ^
                {
                    __strong TGPhotoEditorController *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    if (isInitialAppearance)
                    {
                        [initialBackgroundView removeFromSuperview];
                        if (strongSelf.finishedTransitionIn != nil)
                            strongSelf.finishedTransitionIn();
                    }
                    else
                    {
                        strongSelf->_backgroundView.alpha = 0.0f;
                    }
                    
                    strongSelf->_switchingTab = false;
                };
                cropController.cropReset = ^
                {
                    __strong TGPhotoEditorController *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    [strongSelf reset];
                };
                
                if (_intent != TGPhotoEditorControllerVideoIntent)
                {
                    [[self.requestOriginalFullSizeImage(_item, 0) deliverOn:[SQueue mainQueue]] startWithNext:^(UIImage *image)
                    {
                        if (cropController.dismissing && !cropController.switching)
                            return;
                        
                        if (![image isKindOfClass:[UIImage class]] || image.degraded)
                            return;
                        
                        self.fullSizeImage = image;
                        [cropController setImage:image];
                    }];
                }
                else if (self.requestImage != nil)
                {
                    UIImage *image = self.requestImage();
                    [cropController setImage:image];
                }
                
                controller = cropController;
            }
        }
            break;
            
        case TGPhotoEditorPaintTab:
        {
            TGPhotoPaintController *paintController = [[TGPhotoPaintController alloc] initWithContext:_context photoEditor:_photoEditor previewView:_previewView entitiesView:_fullEntitiesView];
            paintController.stickersContext = _stickersContext;
            paintController.toolbarLandscapeSize = TGPhotoEditorToolbarSize;
            paintController.controlVideoPlayback = ^(bool play) {
                __strong TGPhotoEditorController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                if (play) {
                    [strongSelf startVideoPlayback:false];
                } else {
                    [strongSelf stopVideoPlayback:false];
                }
            };
            paintController.beginTransitionIn = ^UIView *(CGRect *referenceFrame, UIView **parentView, bool *noTransitionView)
            {
                __strong TGPhotoEditorController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return nil;
                
                *referenceFrame = transitionReferenceFrame;
                *parentView = transitionParentView;
                *noTransitionView = transitionNoTransitionView;
                
                return transitionReferenceView;
            };
            paintController.finishedTransitionIn = ^
            {
                __strong TGPhotoEditorController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (isInitialAppearance && strongSelf.finishedTransitionIn != nil)
                    strongSelf.finishedTransitionIn();
                
                strongSelf->_switchingTab = false;
                
                if (isInitialAppearance)
                    [strongSelf startVideoPlayback:true];
            };
            
            controller = paintController;
        }
            break;
            
        case TGPhotoEditorToolsTab:
        {
            TGPhotoToolsController *toolsController = [[TGPhotoToolsController alloc] initWithContext:_context photoEditor:_photoEditor previewView:_previewView entitiesView:_fullEntitiesView];
            toolsController.toolbarLandscapeSize = TGPhotoEditorToolbarSize;
            toolsController.beginTransitionIn = ^UIView *(CGRect *referenceFrame, UIView **parentView, bool *noTransitionView)
            {
                *referenceFrame = transitionReferenceFrame;
                *parentView = transitionParentView;
                *noTransitionView = transitionNoTransitionView;
                
                return transitionReferenceView;
            };
            toolsController.finishedTransitionIn = ^
            {
                __strong TGPhotoEditorController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
            
                if (isInitialAppearance && strongSelf.finishedTransitionIn != nil)
                    strongSelf.finishedTransitionIn();
                
                strongSelf->_switchingTab = false;
                
                if (isInitialAppearance)
                    [strongSelf startVideoPlayback:true];
            };
            controller = toolsController;
        }
            break;
            
        case TGPhotoEditorQualityTab:
        {
            _ignoreDefaultPreviewViewTransitionIn = true;
            
            TGPhotoQualityController *qualityController = [[TGPhotoQualityController alloc] initWithContext:_context photoEditor:_photoEditor previewView:_previewView];
            qualityController.item = _item;
            qualityController.toolbarLandscapeSize = TGPhotoEditorToolbarSize;
            qualityController.beginTransitionIn = ^UIView *(CGRect *referenceFrame, UIView **parentView, bool *noTransitionView)
            {
                *referenceFrame = transitionReferenceFrame;
                *parentView = transitionParentView;
                *noTransitionView = transitionNoTransitionView;
                
                return transitionReferenceView;
            };
            qualityController.finishedTransitionIn = ^
            {
                __strong TGPhotoEditorController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (isInitialAppearance && strongSelf.finishedTransitionIn != nil)
                    strongSelf.finishedTransitionIn();
                
                strongSelf->_switchingTab = false;
                strongSelf->_ignoreDefaultPreviewViewTransitionIn = false;
            };

            controller = qualityController;
        }
            break;
            
        default:
            break;
    }
    
    if ([self presentedForAvatarCreation] && !isInitialAppearance && tab != TGPhotoEditorCropTab) {
        backButtonType = TGPhotoEditorBackButtonBack;
    }
    
    _currentTabController = controller;
    _currentTabController.item = _item;
    _currentTabController.intent = _intent;
    _currentTabController.switchingFromTab = switchingFromTab;
    _currentTabController.initialAppearance = isInitialAppearance;
    
    if (![_currentTabController isKindOfClass:[TGPhotoPaintController class]])
        _currentTabController.availableTabs = _availableTabs;
    
    if ([self presentedForAvatarCreation] && self.navigationController == nil)
        _currentTabController.transitionSpeed = 20.0f;
    
    [self addChildViewController:_currentTabController];
    [_containerView addSubview:_currentTabController.view];
    
    if (currentController != nil)
        [_currentTabController viewWillAppear:true];
        
    _currentTabController.view.frame = _containerView.bounds;
    
    if (currentController != nil)
        [_currentTabController viewDidAppear:true];
    
    _currentTabController.valuesChanged = ^
    {
        __strong TGPhotoEditorController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf updatePreviewView:true];
    };
    _currentTabController.tabsChanged = ^
    {
        __strong TGPhotoEditorController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf updateEditorButtons];
    };
    
    _currentTab = tab;
    
    [_portraitToolbarView setToolbarTabs:[_currentTabController availableTabs] animated:true];
    [_landscapeToolbarView setToolbarTabs:[_currentTabController availableTabs] animated:true];
    
    [_portraitToolbarView setBackButtonType:backButtonType];
    [_landscapeToolbarView setBackButtonType:backButtonType];
    
    [_portraitToolbarView setDoneButtonType:doneButtonType];
    [_landscapeToolbarView setDoneButtonType:doneButtonType];
    
    [self updateEditorButtons];

    if (@available(iOS 11.0, *)) {
        if ([self respondsToSelector:@selector(setNeedsUpdateOfScreenEdgesDeferringSystemGestures)])
            [self setNeedsUpdateOfScreenEdgesDeferringSystemGestures];
    }
}

- (void)updatePreviewView:(bool)full
{
    if (full) {
        [_previewView setPaintingImageWithData:_photoEditor.paintingData];
        _fullPaintingView.image = _photoEditor.paintingData.image;
    }
    UIImageOrientation cropOrientation = _photoEditor.cropOrientation;
    if ([self presentedForAvatarCreation]) {
        cropOrientation = UIImageOrientationUp;
    }
    [_previewView setCropRect:_photoEditor.cropRect cropOrientation:cropOrientation cropRotation:_photoEditor.cropRotation cropMirrored:_photoEditor.cropMirrored originalSize:_photoEditor.originalSize];
}

- (void)updateEditorButtons
{
    TGPhotoEditorTab activeTab = TGPhotoEditorNoneTab;
    activeTab = [_currentTabController activeTab];
    [_portraitToolbarView setActiveTab:activeTab];
    [_landscapeToolbarView setActiveTab:activeTab];
    
    TGPhotoEditorTab highlightedTabs = TGPhotoEditorNoneTab;
    highlightedTabs = [_currentTabController highlightedTabs];
    [_portraitToolbarView setEditButtonsHighlighted:highlightedTabs];
    [_landscapeToolbarView setEditButtonsHighlighted:highlightedTabs];
}

#pragma mark - Crop

- (void)reset
{
    if (_intent != TGPhotoEditorControllerVideoIntent)
        return;
    
    TGPhotoCropController *cropController = (TGPhotoCropController *)_currentTabController;
    if (![cropController isKindOfClass:[TGPhotoCropController class]])
        return;
}
#pragma mark -

- (void)presentAnimated:(bool)animated
{
    if (animated)
    {
        const CGFloat velocity = 2000.0f;
        CGFloat duration = self.view.frame.size.height / velocity;
        CGRect targetFrame =  self.view.frame;
        self.view.frame = CGRectOffset(self.view.frame, 0, self.view.frame.size.height);
        
        [UIView animateWithDuration:duration animations:^
        {
            self.view.frame = targetFrame;
        } completion:^(__unused BOOL finished)
        {
            TGDispatchAfter(1.0, dispatch_get_main_queue(), ^{
                [_photoEditor updateProcessChain:true];
            });
        }];
    }
}

- (void)dismissAnimated:(bool)animated
{
    _dismissed = true;
    
    self.view.userInteractionEnabled = false;
    
    if (self.navigationController != nil)
        animated = false;
    
    if (animated)
    {
        const CGFloat velocity = 2000.0f;
        CGFloat duration = self.view.frame.size.height / velocity;
        CGRect targetFrame = CGRectOffset(self.view.frame, 0, self.view.frame.size.height);
        
        [UIView animateWithDuration:duration delay:0.4 options:kNilOptions animations:^
        {
            self.view.frame = targetFrame;
        } completion:^(__unused BOOL finished)
        {
            [_currentTabController finishCustomTransitionOut];
            if (self.navigationController != nil) {
                [self.navigationController popViewControllerAnimated:false];
            } else {
                [self dismiss];
                if (self.onDismiss)
                    self.onDismiss();
            }
        }];
    }
    else
    {
        if (self.navigationController != nil) {
            [_currentTabController finishCustomTransitionOut];
            [self.navigationController popViewControllerAnimated:false];
        } else {
            [self dismiss];
        }
    }
}

- (void)cancelButtonPressed
{
    [self dismissEditor];
}

- (void)dismissEditor
{
    if (![_currentTabController isKindOfClass:[TGPhotoAvatarPreviewController class]] && [self presentedForAvatarCreation]) {
        [self presentTab:TGPhotoEditorCropTab];
        return;
    }
    
    if (![_currentTabController isDismissAllowed])
        return;
 
    __weak TGPhotoEditorController *weakSelf = self;
    void(^dismiss)(void) = ^
    {
        __strong TGPhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf.view.userInteractionEnabled = false;
        [strongSelf->_currentTabController prepareTransitionOutSaving:false];
        
        if (self.skipInitialTransition) {
            [strongSelf dismissAnimated:true];
        } else if (strongSelf.navigationController != nil && [strongSelf.navigationController.viewControllers containsObject:strongSelf])
        {
            [strongSelf.navigationController popViewControllerAnimated:true];
        }
        else
        {
            [strongSelf transitionOutSaving:false completion:^
            {
                [strongSelf dismiss];
            }];
        }
        
        if (strongSelf.willFinishEditing != nil)
            strongSelf.willFinishEditing(nil, nil, false);
        
        if (strongSelf.didFinishEditing != nil)
            strongSelf.didFinishEditing(nil, nil, nil, false);
    };
    
    TGPaintingData *paintingData = nil;
    if ([_currentTabController isKindOfClass:[TGPhotoPaintController class]])
        paintingData = [(TGPhotoPaintController *)_currentTabController paintingData];
    
    PGPhotoEditorValues *editorValues = paintingData == nil ? [_photoEditor exportAdjustments] : [_photoEditor exportAdjustmentsWithPaintingData:paintingData];
    
    if ((_initialAdjustments == nil && (![editorValues isDefaultValuesForAvatar:[self presentedForAvatarCreation]] || editorValues.cropOrientation != UIImageOrientationUp)) || (_initialAdjustments != nil && ![editorValues isEqual:_initialAdjustments]))
    {
        TGMenuSheetController *controller = [[TGMenuSheetController alloc] initWithContext:_context dark:false];
        controller.dismissesByOutsideTap = true;
        controller.narrowInLandscape = true;
        __weak TGMenuSheetController *weakController = controller;
        
        NSArray *items = @
        [
         [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"PhotoEditor.DiscardChanges") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
            {
                __strong TGMenuSheetController *strongController = weakController;
                if (strongController == nil)
                    return;
                
                [strongController dismissAnimated:true manual:false completion:^
                {
                    dismiss();
                }];
            }],
            [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.Cancel") type:TGMenuSheetButtonTypeCancel fontSize:20.0 action:^
            {
                __strong TGMenuSheetController *strongController = weakController;
                if (strongController != nil)
                    [strongController dismissAnimated:true];
            }]
        ];
        
        [controller setItemViews:items];
        controller.sourceRect = ^
        {
            __strong TGPhotoEditorController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return CGRectZero;
            
            if (UIInterfaceOrientationIsPortrait(strongSelf.effectiveOrientation))
                return [strongSelf.view convertRect:strongSelf->_portraitToolbarView.cancelButtonFrame fromView:strongSelf->_portraitToolbarView];
            else
                return [strongSelf.view convertRect:strongSelf->_landscapeToolbarView.cancelButtonFrame fromView:strongSelf->_landscapeToolbarView];
        };
        [controller presentInViewController:self sourceView:self.view animated:true];
    }
    else
    {
        dismiss();
    }
}

- (void)doneButtonPressed
{
    if ([self presentedForAvatarCreation] && ![_currentTabController isKindOfClass:[TGPhotoAvatarPreviewController class]]) {
        [self presentTab:TGPhotoEditorCropTab];
    } else {
        [self applyEditor];
    }
}

- (void)savePaintingData {
    if (![_currentTabController isKindOfClass:[TGPhotoPaintController class]])
        return;
    
    TGPhotoPaintController *paintController = (TGPhotoPaintController *)_currentTabController;
    TGPaintingData *paintingData = [paintController paintingData];
    _photoEditor.paintingData = paintingData;
    
    if (paintingData != nil)
        [TGPaintingData storePaintingData:paintingData inContext:self.editingContext forItem:_item forVideo:(_intent == TGPhotoEditorControllerVideoIntent)];
    
    [_previewView setPaintingImageWithData:_photoEditor.paintingData];
    [_previewView setPaintingHidden:false];
}

- (void)applyEditor
{
    if (![_currentTabController isDismissAllowed])
        return;
    
    self.view.userInteractionEnabled = false;
    [_currentTabController prepareTransitionOutSaving:true];
    
    bool saving = true;
    NSTimeInterval videoStartValue = 0.0;
    NSTimeInterval trimStartValue = 0.0;
    NSTimeInterval trimEndValue = 0.0;
    
    if ([_currentTabController isKindOfClass:[TGPhotoPaintController class]])
    {
        [self savePaintingData];
    }
    else if ([_currentTabController isKindOfClass:[TGPhotoQualityController class]])
    {
        TGPhotoQualityController *qualityController = (TGPhotoQualityController *)_currentTabController;
        _photoEditor.preset = qualityController.preset;
        saving = false;
        
        [[NSUserDefaults standardUserDefaults] setObject:@(qualityController.preset) forKey:@"TG_preferredVideoPreset_v0"];
    } else if ([_currentTabController isKindOfClass:[TGPhotoAvatarPreviewController class]])
    {
        videoStartValue = _dotPosition;
        trimStartValue = self.trimStartValue;
        trimEndValue = MIN(self.trimStartValue + 9.9, self.trimEndValue);
    }
    
    [self stopVideoPlayback:true];
    
    TGPaintingData *paintingData = _photoEditor.paintingData;
    TGVideoEditAdjustments *adjustments = [_photoEditor exportAdjustmentsWithPaintingData:paintingData];
    if ([self presentedForAvatarCreation] && _item.isVideo) {
        [[SQueue concurrentDefaultQueue] dispatch:^
         {
            id<TGMediaEditableItem> item = _item;
            SSignal *assetSignal = [SSignal complete];
            if ([item isKindOfClass:[TGMediaAsset class]])
                assetSignal = [TGMediaAssetImageSignals avAssetForVideoAsset:(TGMediaAsset *)item];
            else if ([item isKindOfClass:[TGCameraCapturedVideo class]])
                assetSignal = ((TGCameraCapturedVideo *)item).avAsset;
            
            [assetSignal startWithNext:^(AVURLAsset *asset)
            {
                CGSize videoDimensions = CGSizeZero;
                if ([item isKindOfClass:[TGMediaAsset class]])
                    videoDimensions = ((TGMediaAsset *)item).dimensions;
                else if ([asset isKindOfClass:[AVURLAsset class]])
                    videoDimensions = ((AVURLAsset *)asset).originalSize;
                
                AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
                generator.appliesPreferredTrackTransform = true;
                generator.requestedTimeToleranceAfter = kCMTimeZero;
                generator.requestedTimeToleranceBefore = kCMTimeZero;
                
                CGImageRef imageRef = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(MIN(videoStartValue, CMTimeGetSeconds(asset.duration) - 0.05), NSEC_PER_SEC) actualTime:nil error:NULL];
                UIImage *image = [UIImage imageWithCGImage:imageRef];
                CGImageRelease(imageRef);
                
                UIImage *paintingImage = adjustments.paintingData.stillImage;
                if (paintingImage == nil) {
                    paintingImage = adjustments.paintingData.image;
                }
                
                UIImage *fullImage = nil;
                if (adjustments.toolsApplied) {
                    image = [PGPhotoEditor resultImageForImage:image adjustments:adjustments];
                    
                    if ([self presentedForAvatarCreation]) {
                         fullImage = TGPhotoEditorVideoCrop(image, paintingImage, adjustments.cropOrientation, adjustments.cropRotation, adjustments.cropRect, adjustments.cropMirrored, CGSizeMake(640, 640), item.originalSize, true, false);
                    } else {
                        CGSize fillSize = TGScaleToFillSize(videoDimensions, image.size);
                        
                        UIGraphicsBeginImageContextWithOptions(fillSize, true, 0.0f);
                        CGContextRef context = UIGraphicsGetCurrentContext();
                        CGContextSetInterpolationQuality(context, kCGInterpolationMedium);
                        
                        [image drawInRect:CGRectMake(0, 0, fillSize.width, fillSize.height)];
                        [paintingImage drawInRect:CGRectMake(0, 0, fillSize.width, fillSize.height)];
                        
                        fullImage = UIGraphicsGetImageFromCurrentImageContext();
                        UIGraphicsEndImageContext();
                    }
                } else {
                    fullImage = TGPhotoEditorVideoCrop(image, paintingImage, adjustments.cropOrientation, adjustments.cropRotation, adjustments.cropRect, adjustments.cropMirrored, CGSizeMake(640, 640), item.originalSize, true, false);
                }
                
                NSTimeInterval duration = trimEndValue - trimStartValue;
                TGMediaVideoConversionPreset preset;
                if (duration > 0.0) {
                    if (duration <= 2.0) {
                        preset = TGMediaVideoConversionPresetProfileVeryHigh;
                    } else if (duration <= 5.0) {
                        preset = TGMediaVideoConversionPresetProfileHigh;
                    } else if (duration <= 8.0) {
                        preset = TGMediaVideoConversionPresetProfile;
                    } else {
                        preset = TGMediaVideoConversionPresetProfileLow;
                    }
                } else {
                    preset = TGMediaVideoConversionPresetProfile;
                }
                
                TGDispatchOnMainThread(^{
                    if (self.didFinishEditingVideo != nil)
                        self.didFinishEditingVideo(asset, [adjustments editAdjustmentsWithPreset:preset videoStartValue:videoStartValue trimStartValue:trimStartValue trimEndValue:trimEndValue], fullImage, nil, true);
                    
                    [self dismissAnimated:true];
                });
            }];
        }];
        return;
    }
    else if (_intent != TGPhotoEditorControllerVideoIntent)
    {
        TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
        progressWindow.windowLevel = self.view.window.windowLevel + 0.001f;
        [progressWindow performSelector:@selector(showAnimated) withObject:nil afterDelay:0.5];
        
        bool forAvatar = [self presentedForAvatarCreation];
        [self createEditedImageWithEditorValues:adjustments createThumbnail:!forAvatar saveOnly:false completion:^(__unused UIImage *image)
        {
            [NSObject cancelPreviousPerformRequestsWithTarget:progressWindow selector:@selector(showAnimated) object:nil];
            [progressWindow dismiss:true];
            
            if (forAvatar) {
                [self dismissAnimated:true];
                return;
            }
            [self transitionOutSaving:true completion:^
            {
                [self dismiss];
            }];
        }];
    }
    else
    {
        bool hasChanges = !(_initialAdjustments == nil && [adjustments isDefaultValuesForAvatar:false] && adjustments.cropOrientation == UIImageOrientationUp);
        
        if (adjustments.paintingData != nil || adjustments.hasPainting != _initialAdjustments.hasPainting || adjustments.toolsApplied)
        {
            [[SQueue concurrentDefaultQueue] dispatch:^
            {
                id<TGMediaEditableItem> item = _item;
                SSignal *assetSignal = [SSignal complete];
                if ([item isKindOfClass:[TGMediaAsset class]])
                    assetSignal = [TGMediaAssetImageSignals avAssetForVideoAsset:(TGMediaAsset *)item];
                else if ([item isKindOfClass:[TGCameraCapturedVideo class]])
                    assetSignal = ((TGCameraCapturedVideo *)item).avAsset;
                
                [assetSignal startWithNext:^(AVAsset *asset)
                {
                    CGSize videoDimensions = CGSizeZero;
                    if ([item isKindOfClass:[TGMediaAsset class]])
                        videoDimensions = ((TGMediaAsset *)item).dimensions;
                    else if ([asset isKindOfClass:[AVURLAsset class]])
                        videoDimensions = ((AVURLAsset *)asset).originalSize;
                    
                    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
                    generator.appliesPreferredTrackTransform = true;
                    generator.maximumSize = TGFitSize(videoDimensions, CGSizeMake(1280.0f, 1280.0f));
                    generator.requestedTimeToleranceAfter = kCMTimeZero;
                    generator.requestedTimeToleranceBefore = kCMTimeZero;
                    
                    CGImageRef imageRef = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(adjustments.trimStartValue, NSEC_PER_SEC) actualTime:nil error:NULL];
                    UIImage *image = [UIImage imageWithCGImage:imageRef];
                    CGImageRelease(imageRef);
                    
                    if (adjustments.toolsApplied) {
                        image = [PGPhotoEditor resultImageForImage:image adjustments:adjustments];
                    }
                    
                    UIImage *paintingImage = adjustments.paintingData.stillImage;
                    if (paintingImage == nil) {
                        paintingImage = adjustments.paintingData.image;
                    }
                    
                    CGSize fillSize = TGScaleToFillSize(videoDimensions, image.size);
                    UIImage *fullImage = nil;
                    UIGraphicsBeginImageContextWithOptions(fillSize, true, 0.0f);
                    CGContextRef context = UIGraphicsGetCurrentContext();
                    CGContextSetInterpolationQuality(context, kCGInterpolationMedium);
                    
                    [image drawInRect:CGRectMake(0, 0, fillSize.width, fillSize.height)];
                    [paintingImage drawInRect:CGRectMake(0, 0, fillSize.width, fillSize.height)];
                    
                    fullImage = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                    
                    CGSize thumbnailSize = TGPhotoThumbnailSizeForCurrentScreen();
                    thumbnailSize.width = CGCeil(thumbnailSize.width);
                    thumbnailSize.height = CGCeil(thumbnailSize.height);
                    
                    fillSize = TGScaleToFillSize(videoDimensions, thumbnailSize);
                    UIImage *thumbnailImage = nil;
                    UIGraphicsBeginImageContextWithOptions(fillSize, true, 0.0f);
                    context = UIGraphicsGetCurrentContext();
                    CGContextSetInterpolationQuality(context, kCGInterpolationMedium);
                    
                    [image drawInRect:CGRectMake(0, 0, fillSize.width, fillSize.height)];
                    [paintingImage drawInRect:CGRectMake(0, 0, fillSize.width, fillSize.height)];
                    
                    thumbnailImage = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                    
                    [self.editingContext setImage:fullImage thumbnailImage:thumbnailImage forItem:_item synchronous:true];
                }];
            }];
        }
        
        if (self.willFinishEditing != nil)
            self.willFinishEditing(hasChanges ? adjustments : nil, nil, hasChanges);
        
        if (self.didFinishEditing != nil)
            self.didFinishEditing(hasChanges ? adjustments : nil, nil, nil, hasChanges);
        
        if ([self presentedForAvatarCreation]) {
            [self dismissAnimated:true];
        } else {
            [self transitionOutSaving:saving completion:^
            {
                [self dismiss];
            }];
        }
    }
}

- (TGMediaEditingContext *)editingContext
{
    if (_editingContext) {
        return _editingContext;
    } else {
        if (_standaloneEditingContext == nil) {
            _standaloneEditingContext = [[TGMediaEditingContext alloc] init];
        }
        return _standaloneEditingContext;
    }
}

- (void)doneButtonLongPressed:(UIButton *)sender
{
    if (_intent == TGPhotoEditorControllerVideoIntent)
        return;
    
    if (_menuContainerView != nil)
    {
        [_menuContainerView removeFromSuperview];
        _menuContainerView = nil;
    }

    _menuContainerView = [[TGMenuContainerView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height)];
    [self.view addSubview:_menuContainerView];
    
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    [actions addObject:@{ @"title": @"Save to Camera Roll", @"action": @"save" }];    
    if ([_context canOpenURL:[NSURL URLWithString:@"instagram://"]])
        [actions addObject:@{ @"title": @"Share on Instagram", @"action": @"instagram" }];
    
    [_menuContainerView.menuView setButtonsAndActions:actions watcherHandle:_actionHandle];
    [_menuContainerView.menuView sizeToFit];
    
    CGRect titleLockIconViewFrame = [sender.superview convertRect:sender.frame toView:_menuContainerView];
    titleLockIconViewFrame.origin.y += 16.0f;
    [_menuContainerView showMenuFromRect:titleLockIconViewFrame animated:false];
}

- (void)actionStageActionRequested:(NSString *)action options:(id)options
{
    if ([action isEqualToString:@"menuAction"])
    {
        NSString *menuAction = options[@"action"];
        if ([menuAction isEqualToString:@"save"])
            [self _saveToCameraRoll];
        else if ([menuAction isEqualToString:@"instagram"])
            [self _openInInstagram];
    }
}

#pragma mark - External Export

- (void)_saveToCameraRoll
{
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    progressWindow.windowLevel = self.view.window.windowLevel + 0.001f;
    [progressWindow performSelector:@selector(showAnimated) withObject:nil afterDelay:0.5];
    
    TGPaintingData *paintingData = nil;
    if ([_currentTabController isKindOfClass:[TGPhotoPaintController class]])
        paintingData = [(TGPhotoPaintController *)_currentTabController paintingData];
    
    PGPhotoEditorValues *editorValues = paintingData == nil ? [_photoEditor exportAdjustments] : [_photoEditor exportAdjustmentsWithPaintingData:paintingData];
    
    [self createEditedImageWithEditorValues:editorValues createThumbnail:false saveOnly:true completion:^(UIImage *resultImage)
    {
        [[[[TGMediaAssetsLibrary sharedLibrary] saveAssetWithImage:resultImage] deliverOn:[SQueue mainQueue]] startWithNext:nil completed:^
        {
            [NSObject cancelPreviousPerformRequestsWithTarget:progressWindow selector:@selector(showAnimated) object:nil];
            [progressWindow dismissWithSuccess];
        }];
    }];
}

- (void)_openInInstagram
{
    TGProgressWindow *progressWindow = [[TGProgressWindow alloc] init];
    progressWindow.windowLevel = self.view.window.windowLevel + 0.001f;
    [progressWindow performSelector:@selector(showAnimated) withObject:nil afterDelay:0.5];
    
    TGPaintingData *paintingData = nil;
    if ([_currentTabController isKindOfClass:[TGPhotoPaintController class]])
        paintingData = [(TGPhotoPaintController *)_currentTabController paintingData];
    
    PGPhotoEditorValues *editorValues = paintingData == nil ? [_photoEditor exportAdjustments] : [_photoEditor exportAdjustmentsWithPaintingData:paintingData];
    
    [self createEditedImageWithEditorValues:editorValues createThumbnail:false saveOnly:true completion:^(UIImage *resultImage)
    {
        [NSObject cancelPreviousPerformRequestsWithTarget:progressWindow selector:@selector(showAnimated) object:nil];
        [progressWindow dismiss:true];
        
        NSData *imageData = UIImageJPEGRepresentation(resultImage, 0.9);
        NSString *writePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"instagram.igo"];
        if (![imageData writeToFile:writePath atomically:true])
        {
            return;
        }
        
        NSURL *fileURL = [NSURL fileURLWithPath:writePath];
        
        _documentController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
        _documentController.delegate = self;
        [_documentController setUTI:@"com.instagram.exclusivegram"];
        if (_caption.length > 0)
            [_documentController setAnnotation:@{@"InstagramCaption" : _caption.string}];
        [_documentController presentOpenInMenuFromRect:self.view.frame inView:self.view animated:true];
    }];
}

- (void)documentInteractionControllerDidDismissOpenInMenu:(UIDocumentInteractionController *)__unused controller
{
    _documentController = nil;
}

#pragma mark -

- (void)dismiss
{
    if (self.overlayWindow != nil || self.customDismissBlock != nil)
    {
        [super dismiss];
    }
    else
    {
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
    }
}

#pragma mark - Layout

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self.view setNeedsLayout];
    
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateLayout:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation]];
}

- (bool)inFormSheet
{
    if (iosMajorVersion() < 9)
        return [super inFormSheet];
    
    UIUserInterfaceSizeClass sizeClass = [_context currentHorizontalSizeClass];
    if (sizeClass == UIUserInterfaceSizeClassCompact)
        return false;
    
    return [super inFormSheet];
}

- (CGSize)referenceViewSize
{
    if ([self inFormSheet])
        return CGSizeMake(540.0f, 620.0f);
    
    if (self.parentViewController != nil)
        return self.parentViewController.view.frame.size;
    else if (self.navigationController != nil)
        return self.navigationController.view.frame.size;
    
    return [_context fullscreenBounds].size;
}

- (bool)hasOnScreenNavigation {
    bool hasOnScreenNavigation = false;
    if (@available(iOS 11.0, *)) {
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || _context.safeAreaInset.bottom > FLT_EPSILON;
    }
    return hasOnScreenNavigation;
}

- (UIInterfaceOrientation)effectiveOrientation {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self effectiveOrientation:self.interfaceOrientation];
#pragma clang diagnostic pop
}

- (UIInterfaceOrientation)effectiveOrientation:(UIInterfaceOrientation)orientation {
    bool isPad = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad;
    if ([self inFormSheet] || isPad)
        orientation = UIInterfaceOrientationPortrait;
    return orientation;
}

- (UIEdgeInsets)screenEdges {
    CGSize referenceSize = [self referenceViewSize];
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height);
    return UIEdgeInsetsMake((screenSide - referenceSize.height) / 2, (screenSide - referenceSize.width) / 2, (screenSide + referenceSize.height) / 2, (screenSide + referenceSize.width) / 2);
}

- (void)updateLayout:(UIInterfaceOrientation)orientation
{
    orientation = [self effectiveOrientation:orientation];
    
    CGSize referenceSize = [self referenceViewSize];
    
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height);
    _wrapperView.frame = CGRectMake((referenceSize.width - screenSide) / 2, (referenceSize.height - screenSide) / 2, screenSide, screenSide);
    
    _containerView.frame = CGRectMake((screenSide - referenceSize.width) / 2, (screenSide - referenceSize.height) / 2, referenceSize.width, referenceSize.height);
    _transitionWrapperView.frame = _containerView.frame;
    
    UIEdgeInsets screenEdges = UIEdgeInsetsMake((screenSide - referenceSize.height) / 2, (screenSide - referenceSize.width) / 2, (screenSide + referenceSize.height) / 2, (screenSide + referenceSize.width) / 2);
    
    _landscapeToolbarView.interfaceOrientation = orientation;
    
    UIEdgeInsets safeAreaInset = [self calculatedSafeAreaInset];
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            [UIView performWithoutAnimation:^
            {
                _landscapeToolbarView.frame = CGRectMake(screenEdges.left, screenEdges.top, TGPhotoEditorToolbarSize + safeAreaInset.left, referenceSize.height);
            }];
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            [UIView performWithoutAnimation:^
            {
                _landscapeToolbarView.frame = CGRectMake(screenEdges.right - TGPhotoEditorToolbarSize - safeAreaInset.right, screenEdges.top, TGPhotoEditorToolbarSize + safeAreaInset.right, referenceSize.height);
            }];
        }
            break;
            
        default:
        {
            _landscapeToolbarView.frame = CGRectMake(_landscapeToolbarView.frame.origin.x, screenEdges.top, TGPhotoEditorToolbarSize, referenceSize.height);
        }
            break;
    }
    
    CGFloat portraitToolbarViewBottomEdge = screenSide;
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        portraitToolbarViewBottomEdge = screenEdges.bottom;
    
    CGFloat previousWidth = _portraitToolbarView.frame.size.width;
    _portraitToolbarView.frame = CGRectMake(screenEdges.left, portraitToolbarViewBottomEdge - TGPhotoEditorToolbarSize - safeAreaInset.bottom, referenceSize.width, TGPhotoEditorToolbarSize + safeAreaInset.bottom);
    
    _scrubberView.frame = CGRectMake(0.0, 0.0, _portraitToolbarView.frame.size.width, _scrubberView.frame.size.height);
        
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!_initializedScrubber) {
            [_scrubberView layoutSubviews];
            _initializedScrubber = true;
            [_scrubberView reloadData];
            [_scrubberView resetToStart];
            if (_isPlaying)
                [_scrubberView _updateScrubberAnimationsAndResetCurrentPosition:true];
        } else {
            if (previousWidth != _portraitToolbarView.frame.size.width)
                [_scrubberView reloadThumbnails];
        }
    });
}

- (void)_setScreenImage:(UIImage *)screenImage
{
    _screenImage = screenImage;
    if ([_currentTabController isKindOfClass:[TGPhotoAvatarPreviewController class]])
        [(TGPhotoAvatarPreviewController *)_currentTabController setSnapshotImage:screenImage];
}

- (void)_finishedTransitionIn
{
    _switchingTab = false;
    if ([_currentTabController isKindOfClass:[TGPhotoAvatarPreviewController class]])
        [(TGPhotoAvatarPreviewController *)_currentTabController _finishedTransitionIn];
}

- (CGFloat)toolbarLandscapeSize
{
    return TGPhotoEditorToolbarSize;
}

- (UIView *)transitionWrapperView
{
    return _transitionWrapperView;
}

- (void)layoutProgressView {
    if (_progressView.superview == nil)
        [_containerView addSubview:_progressView];
    
    CGSize referenceSize = [self referenceViewSize];
    CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:self.effectiveOrientation panelSize:0.0 hasOnScreenNavigation:self.hasOnScreenNavigation];
    
    _progressView.frame = (CGRect){{CGFloor(CGRectGetMidX(containerFrame) - _progressView.frame.size.width / 2.0f), CGFloor(CGRectGetMidY(containerFrame) - _progressView.frame.size.height / 2.0f)}, _progressView.frame.size};
}

- (void)setProgressVisible:(bool)progressVisible value:(CGFloat)value animated:(bool)animated
{
    _progressVisible = progressVisible;
    
    if (progressVisible)
    {
        [self layoutProgressView];
        
        _progressView.alpha = 1.0f;
    }
    else if (_progressView.superview != nil)
    {
        if (animated)
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _progressView.alpha = 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                    [_progressView removeFromSuperview];
            }];
        }
        else {
            [_progressView removeFromSuperview];
        }
    }
    
    [_progressView setProgress:value cancelEnabled:false animated:animated];
}

- (void)setInfoString:(NSString *)string
{
    [_portraitToolbarView setInfoString:string];
    [_landscapeToolbarView setInfoString:string];
}

- (void)detectFaces
{
    if (_faceDetectorDisposable == nil)
        _faceDetectorDisposable = [[SMetaDisposable alloc] init];
    
    id<TGMediaEditableItem> item = _item;
    CGSize originalSize = _photoEditor.originalSize;
    
    if (self.requestOriginalScreenSizeImage == nil)
        return;
    
    SSignal *cachedFaces = self.editingContext != nil ? [self.editingContext facesForItem:item] : [SSignal single:nil];
    
    SSignal *cachedSignal = [cachedFaces mapToSignal:^SSignal *(id result)
    {
        if (result == nil)
            return [SSignal fail:nil];
        return [SSignal single:result];
    }];
    SSignal *imageSignal = self.requestOriginalScreenSizeImage(item, 0);
    SSignal *detectSignal = [[[imageSignal filter:^bool(UIImage *image)
    {
        if (![image isKindOfClass:[UIImage class]])
            return false;
        
        if (image.degraded)
            return false;
        
        return true;
    }] take:1] mapToSignal:^SSignal *(UIImage *image) {
        return [[TGPaintFaceDetector detectFacesInImage:image originalSize:originalSize] startOn:[SQueue concurrentDefaultQueue]];
    }];
    
    __weak TGPhotoEditorController *weakSelf = self;
    [_faceDetectorDisposable setDisposable:[[[cachedSignal catch:^SSignal *(__unused id error)
    {
        return detectSignal;
    }] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *next)
    {
        __strong TGPhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf.editingContext setFaces:next forItem:item];
     
        if (next.count == 0)
            return;
        
        strongSelf->_faces = next;
    }]];
}

+ (TGPhotoEditorTab)defaultTabsForAvatarIntent
{
    static dispatch_once_t onceToken;
    static TGPhotoEditorTab avatarTabs = TGPhotoEditorNoneTab;
    dispatch_once(&onceToken, ^
    {
        if (iosMajorVersion() >= 7)
            avatarTabs = TGPhotoEditorCropTab | TGPhotoEditorPaintTab | TGPhotoEditorToolsTab;
    });
    return avatarTabs;
}

- (void)setPlayButtonHidden:(bool)hidden animated:(bool)animated
{
    if (!hidden) {
        [_progressView setPlay];
        [self layoutProgressView];
    }
    
    if (animated)
    {
        _progressView.hidden = false;
        _progressView.alpha = 0.0f;
        [UIView animateWithDuration:0.15f animations:^
        {
            _progressView.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            if (finished)
                _progressView.hidden = hidden;
        }];
    }
    else
    {
        _progressView.alpha = hidden ? 0.0f : 1.0f;
        _progressView.hidden = hidden;
    }
}

#pragma mark - Video Scrubber Data Source & Delegate

#pragma mark Scrubbing

- (id<TGMediaEditableItem>)item {
    return _item;
}

- (NSTimeInterval)videoScrubberDuration:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber
{
    return self.item.originalDuration;
}

- (CGFloat)videoScrubberThumbnailAspectRatio:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber
{
    return 1.0f;
}

- (void)videoScrubberDidBeginScrubbing:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber
{
    [self stopVideoPlayback:false];
 
    [self setPlayButtonHidden:true animated:false];
    
    TGPhotoAvatarPreviewController *previewController = (TGPhotoAvatarPreviewController *)_currentTabController;
    if (![previewController isKindOfClass:[TGPhotoAvatarPreviewController class]])
        return;
    
    [previewController beginScrubbing:true];
}

- (void)resetDotImage {
    UIView *snapshotView = nil;
    UIView *dotSnapshotView = nil;
    if (_dotImageView.image != nil) {
        dotSnapshotView = [_dotMarkerView snapshotViewAfterScreenUpdates:false];
        dotSnapshotView.frame = _dotMarkerView.frame;
        [_dotMarkerView.superview addSubview:dotSnapshotView];
        
        snapshotView = [_dotImageView snapshotViewAfterScreenUpdates:false];
        snapshotView.frame = [_dotImageView.superview convertRect:_dotImageView.frame toView:_dotMarkerView.superview];
        [_dotMarkerView.superview addSubview:snapshotView];
    }
    
    if (snapshotView != nil) {
        [UIView animateWithDuration:0.15 animations:^{
            snapshotView.center = _dotMarkerView.center;
            snapshotView.transform = CGAffineTransformMakeScale(0.05, 0.05);
            snapshotView.alpha = 0.0f;
            dotSnapshotView.transform = CGAffineTransformMakeScale(0.3, 0.3);
            dotSnapshotView.alpha = 0.0f;
        } completion:^(BOOL finished) {
            [snapshotView removeFromSuperview];
            [dotSnapshotView removeFromSuperview];
        }];
    }
    
    _dotImageView.image = nil;
    _dotMarkerView.hidden = true;
}

- (void)updateDotImage:(bool)animated {
    AVPlayer *player = _player;
    if (player == nil) {
        return;
    }
    id<TGMediaEditAdjustments> adjustments = [_photoEditor exportAdjustments];
    [[SQueue concurrentDefaultQueue] dispatch:^{
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:player.currentItem.asset];
        generator.appliesPreferredTrackTransform = true;
        generator.maximumSize = CGSizeMake(160.0f, 160.0f);
        generator.requestedTimeToleranceAfter = kCMTimeZero;
        generator.requestedTimeToleranceBefore = kCMTimeZero;
                
        CGImageRef imageRef = [generator copyCGImageAtTime:player.currentItem.currentTime actualTime:NULL error:NULL];
        UIImage *image = [[UIImage alloc] initWithCGImage:imageRef];
        CGImageRelease(imageRef);
        
        if (adjustments.toolsApplied) {
            PGPhotoEditor *editor = [[PGPhotoEditor alloc] initWithOriginalSize:adjustments.originalSize adjustments:adjustments forVideo:false enableStickers:true];
            editor.standalone = true;
            [editor setImage:image forCropRect:adjustments.cropRect cropRotation:0.0 cropOrientation:adjustments.cropOrientation cropMirrored:adjustments.cropMirrored fullSize:false];
            image = editor.currentResultImage;
        }
                
        TGDispatchOnMainThread(^{
            if (animated) {
                UIView *snapshotView = nil;
                UIView *dotSnapshotView = nil;
                if (_dotImageView.image != nil) {
                    dotSnapshotView = [_dotMarkerView snapshotViewAfterScreenUpdates:false];
                    dotSnapshotView.frame = _dotMarkerView.frame;
                    [_dotMarkerView.superview addSubview:dotSnapshotView];
                    
                    snapshotView = [_dotImageView snapshotViewAfterScreenUpdates:false];
                    snapshotView.frame = [_dotImageView.superview convertRect:_dotImageView.frame toView:_dotMarkerView.superview];
                    [_dotMarkerView.superview addSubview:snapshotView];
                }
                
                if (snapshotView != nil) {
                    [UIView animateWithDuration:0.15 animations:^{
                        snapshotView.center = _dotMarkerView.center;
                        snapshotView.transform = CGAffineTransformMakeScale(0.05, 0.05);
                        snapshotView.alpha = 0.0f;
                        dotSnapshotView.transform = CGAffineTransformMakeScale(0.3, 0.3);
                        dotSnapshotView.alpha = 0.0f;
                    } completion:^(BOOL finished) {
                        [snapshotView removeFromSuperview];
                        [dotSnapshotView removeFromSuperview];
                    }];
                }
                
                _dotMarkerView.hidden = false;
                _dotImageView.image = image;
                _dotImageView.cropRect = _photoEditor.cropRect;
                _dotImageView.cropOrientation = _photoEditor.cropOrientation;
                _dotImageView.cropMirrored = _photoEditor.cropMirrored;
                [_dotImageView updateCropping];
                
                [_scrubberView addSubview:_dotMarkerView];
                
                _dotMarkerView.center = CGPointMake([_scrubberView scrubberPositionForPosition:_dotPosition].x + 7.0, 9.5);
                _dotMarkerView.transform = CGAffineTransformMakeScale(0.3, 0.3);
                _dotMarkerView.alpha = 0.0;
                [UIView animateWithDuration:0.3 animations:^{
                    _dotMarkerView.transform = CGAffineTransformIdentity;
                    _dotMarkerView.alpha = 1.0;
                }];
                
                UIEdgeInsets screenEdges = [self screenEdges];
                CGSize referenceSize = [self referenceViewSize];
                CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:self.effectiveOrientation panelSize:0.0 hasOnScreenNavigation:self.hasOnScreenNavigation];
                containerFrame.origin.x += screenEdges.left;
                containerFrame.origin.y += screenEdges.top;
                
                CGFloat scale = (containerFrame.size.width - [TGPhotoAvatarCropView areaInsetSize].width * 2.0) / 160.0;
                _dotImageView.center = CGPointMake(CGRectGetMidX(containerFrame), CGRectGetMidY(containerFrame));
                _dotImageView.transform = CGAffineTransformMakeScale(scale, scale);
                
                CGPoint targetCenter = [_dotMarkerView.superview convertPoint:_dotMarkerView.center toView:_wrapperView];
                targetCenter.y -= 27.0;
                [UIView animateWithDuration:0.4 delay:0.0 usingSpringWithDamping:1.1 initialSpringVelocity:0.1 options:kNilOptions animations:^{
                    _dotImageView.center = targetCenter;
                    _dotImageView.transform = CGAffineTransformMakeScale(0.225, 0.225);
                } completion:^(BOOL finished) {
                    
                }];
            } else {
                if (_dotImageView.image != nil) {
                    [_scrubberView addSubview:_dotMarkerView];
                    
                    UIView *snapshotView;
                    if (_dotImageView.image != nil) {
                        _dotImageSnapshotView = [_dotImageView snapshotViewAfterScreenUpdates:false];
                        snapshotView.frame = _dotImageView.bounds;
                        [_dotImageView addSubview:snapshotView];
                    }
                    
                    _dotMarkerView.hidden = false;
                    _dotImageView.image = image;
                    _dotImageView.cropRect = _photoEditor.cropRect;
                    _dotImageView.cropOrientation = _photoEditor.cropOrientation;
                    _dotImageView.cropMirrored = _photoEditor.cropMirrored;
                    [_dotImageView updateCropping];
                }
            }
        });
    }];
}

- (void)videoScrubberDidEndScrubbing:(TGMediaPickerGalleryVideoScrubber *)videoScrubber
{
    __weak TGPhotoEditorController *weakSelf = self;
    TGPhotoAvatarPreviewController *previewController = (TGPhotoAvatarPreviewController *)_currentTabController;
    if (![previewController isKindOfClass:[TGPhotoAvatarPreviewController class]])
        return;
    
    _dotPosition = videoScrubber.value;
    
    [previewController endScrubbing:true completion:^bool{
        __strong TGPhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        return !strongSelf->_scrubberView.isScrubbing;
    }];
    
    TGDispatchAfter(0.16, dispatch_get_main_queue(), ^{
        [self updateDotImage:true];
    });
}

- (void)videoScrubber:(TGMediaPickerGalleryVideoScrubber *)videoScrubber valueDidChange:(NSTimeInterval)position
{
    [self seekVideo:position];
}

#pragma mark Trimming

- (bool)hasTrimming
{
    return _scrubberView.hasTrimming;
}

- (CMTimeRange)trimRange
{
    return CMTimeRangeMake(CMTimeMakeWithSeconds(self.trimStartValue , NSEC_PER_SEC), CMTimeMakeWithSeconds((self.trimEndValue - self.trimStartValue), NSEC_PER_SEC));
}

- (void)videoScrubberDidBeginEditing:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber
{
    [self stopVideoPlayback:false];
    
    [self setPlayButtonHidden:true animated:false];
}

- (void)videoScrubberDidEndEditing:(TGMediaPickerGalleryVideoScrubber *)videoScrubber
{
    if (_resetDotPosition) {
        _dotPosition = videoScrubber.trimStartValue;
        _resetDotPosition = false;
    }
    
    [self setVideoEndTime:videoScrubber.trimEndValue];
    
    [videoScrubber resetToStart];
    [self startVideoPlayback:true];
    
    [self setPlayButtonHidden:true animated:false];
    
    _chaseStart = false;
}

- (void)videoScrubber:(TGMediaPickerGalleryVideoScrubber *)videoScrubber editingStartValueDidChange:(NSTimeInterval)startValue
{
    if (startValue > _dotPosition || videoScrubber.trimEndValue < _dotPosition) {
        _resetDotPosition = true;
        [self resetDotImage];
    }
    
    if (!_chaseStart) {
        _chaseStart = true;
        [_fullEntitiesView resetToStart];
    }
    
    [self seekVideo:startValue];
}

- (void)videoScrubber:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber editingEndValueDidChange:(NSTimeInterval)endValue
{
    if (endValue < _dotPosition || videoScrubber.trimStartValue > _dotPosition) {
        _resetDotPosition = true;
        [self resetDotImage];
    }
    [self seekVideo:endValue];
}

#pragma mark Thumbnails

- (NSArray *)videoScrubber:(TGMediaPickerGalleryVideoScrubber *)videoScrubber evenlySpacedTimestamps:(NSInteger)count startingAt:(NSTimeInterval)startTimestamp endingAt:(NSTimeInterval)endTimestamp
{
    if (endTimestamp < startTimestamp)
        return nil;
    
    if (count == 0)
        return nil;

    NSTimeInterval duration = [self videoScrubberDuration:videoScrubber];
    if (endTimestamp > duration)
        endTimestamp = duration;
    
    NSTimeInterval interval = (endTimestamp - startTimestamp) / count;
    
    NSMutableArray *timestamps = [[NSMutableArray alloc] init];
    for (NSInteger i = 0; i < count; i++)
        [timestamps addObject:@(startTimestamp + i * interval)];
    
    return timestamps;
}

- (NSArray *)_placeholderThumbnails:(NSArray *)timestamps {
    NSMutableArray *thumbnails = [[NSMutableArray alloc] init];
    UIImage *blurredImage = TGBlurredRectangularImage(_screenImage, true, _screenImage.size, _screenImage.size, NULL, nil);
    for (__unused NSNumber *value in timestamps) {
        if (thumbnails.count == 0)
            [thumbnails addObject:_screenImage];
        else
            [thumbnails addObject:blurredImage];
    }
    return thumbnails;
}

- (void)videoScrubber:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber requestThumbnailImagesForTimestamps:(NSArray *)timestamps size:(CGSize)size isSummaryThumbnails:(bool)isSummaryThumbnails
{
    if (timestamps.count == 0)
        return;
    
    id<TGMediaEditAdjustments> adjustments = [_photoEditor exportAdjustments];
            
    __weak TGPhotoEditorController *weakSelf = self;
    SSignal *thumbnailsSignal = nil;
    if (_cachedThumbnails != nil) {
        thumbnailsSignal = [SSignal single:_cachedThumbnails];
    } else if ([self.item isKindOfClass:[TGMediaAsset class]]) {
        thumbnailsSignal = [[SSignal single:[self _placeholderThumbnails:timestamps]] then:[[TGMediaAssetImageSignals videoThumbnailsForAsset:(TGMediaAsset *)self.item size:size timestamps:timestamps] onNext:^(NSArray *images) {
               __strong TGPhotoEditorController *strongSelf = weakSelf;
               if (strongSelf == nil)
                   return;
               
               if (strongSelf->_cachedThumbnails == nil)
                   strongSelf->_cachedThumbnails = images;
           }]];
    } else if ([self.item isKindOfClass:[TGCameraCapturedVideo class]]) {
        thumbnailsSignal = [[((TGCameraCapturedVideo *)self.item).avAsset takeLast] mapToSignal:^SSignal *(AVAsset *avAsset) {
            return [[SSignal single:[self _placeholderThumbnails:timestamps]] then:[[TGMediaAssetImageSignals videoThumbnailsForAVAsset:avAsset size:size timestamps:timestamps]  onNext:^(NSArray *images) {
                   __strong TGPhotoEditorController *strongSelf = weakSelf;
                   if (strongSelf == nil)
                       return;
                   
                   if (strongSelf->_cachedThumbnails == nil)
                       strongSelf->_cachedThumbnails = images;
               }]];
        }];
    }
        
    _requestingThumbnails = true;
    
    [_thumbnailsDisposable setDisposable:[[[thumbnailsSignal map:^NSArray *(NSArray *images) {
        if (adjustments.toolsApplied) {
            NSMutableArray *editedImages = [[NSMutableArray alloc] init];
            PGPhotoEditor *editor = [[PGPhotoEditor alloc] initWithOriginalSize:adjustments.originalSize adjustments:adjustments forVideo:false enableStickers:true];
            editor.standalone = true;
            for (UIImage *image in images) {
                [editor setImage:image forCropRect:adjustments.cropRect cropRotation:0.0 cropOrientation:adjustments.cropOrientation cropMirrored:adjustments.cropMirrored fullSize:false];
                UIImage *resultImage = editor.currentResultImage;
                if (resultImage != nil) {
                    [editedImages addObject:resultImage];
                } else {
                    [editedImages addObject:image];
                }
            }
            return editedImages;
        } else {
            return images;
        }
    }] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *images)
    {
        __strong TGPhotoEditorController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [images enumerateObjectsUsingBlock:^(UIImage *image, NSUInteger index, __unused BOOL *stop)
        {
            if (index < timestamps.count)
                [strongSelf->_scrubberView setThumbnailImage:image forTimestamp:[timestamps[index] doubleValue] index:index isSummaryThubmnail:isSummaryThumbnails last:index == (images.count - 1)];
        }];
        
        if (strongSelf->_dotImageSnapshotView != nil) {
            [UIView animateWithDuration:0.2 animations:^{
                strongSelf->_dotImageSnapshotView.alpha = 0.0f;
            } completion:^(BOOL finished) {
                [strongSelf->_dotImageSnapshotView removeFromSuperview];
                strongSelf->_dotImageSnapshotView = nil;
            }];
        }
    } completed:^
    {
        __strong TGPhotoEditorController *strongSelf = weakSelf;
        if (strongSelf != nil)
            strongSelf->_requestingThumbnails = false;
    }]];
}

- (void)videoScrubberDidFinishRequestingThumbnails:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber
{
    _requestingThumbnails = false;
}

- (void)videoScrubberDidCancelRequestingThumbnails:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber
{
    _requestingThumbnails = false;
}

- (CGSize)videoScrubberOriginalSize:(TGMediaPickerGalleryVideoScrubber *)__unused videoScrubber cropRect:(CGRect *)cropRect cropOrientation:(UIImageOrientation *)cropOrientation cropMirrored:(bool *)cropMirrored
{
    id<TGMediaEditAdjustments> adjustments = [_photoEditor exportAdjustments];
    if (cropRect != NULL)
        *cropRect = (adjustments != nil) ? adjustments.cropRect : CGRectMake(0, 0, self.item.originalSize.width, self.item.originalSize.height);
    
    if (cropOrientation != NULL)
        *cropOrientation = (adjustments != nil) ? adjustments.cropOrientation : UIImageOrientationUp;
    
    if (cropMirrored != NULL)
        *cropMirrored = adjustments.cropMirrored;
    
    return self.item.originalSize;
}

@end
