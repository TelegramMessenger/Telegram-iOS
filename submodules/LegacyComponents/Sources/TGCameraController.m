#import "TGCameraController.h"

#import "LegacyComponentsInternal.h"

#import <objc/runtime.h>

#import <LegacyComponents/TGPaintUtils.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGPhotoEditorAnimation.h>

#import <LegacyComponents/PGCamera.h>
#import <LegacyComponents/PGCameraCaptureSession.h>
#import <LegacyComponents/PGCameraDeviceAngleSampler.h>
#import <LegacyComponents/PGCameraVolumeButtonHandler.h>

#import <LegacyComponents/TGCameraPreviewView.h>
#import <LegacyComponents/TGCameraMainPhoneView.h>
#import <LegacyComponents/TGCameraMainTabletView.h>
#import "TGCameraFocusCrosshairsControl.h"
#import "TGCameraRectangleView.h"

#import <LegacyComponents/TGFullscreenContainerView.h>
#import <LegacyComponents/TGPhotoEditorController.h>

#import <LegacyComponents/TGModernGalleryController.h>
#import <LegacyComponents/TGMediaPickerGalleryModel.h>
#import <LegacyComponents/TGMediaPickerGalleryPhotoItem.h>
#import <LegacyComponents/TGMediaPickerGalleryVideoItem.h>
#import <LegacyComponents/TGMediaPickerGalleryVideoItemView.h>
#import <LegacyComponents/TGModernGalleryVideoView.h>

#import "TGMediaVideoConverter.h"
#import <LegacyComponents/TGMediaAssetImageSignals.h>
#import <LegacyComponents/PGPhotoEditorValues.h>
#import <LegacyComponents/TGVideoEditAdjustments.h>
#import <LegacyComponents/TGPaintingData.h>
#import <LegacyComponents/UIImage+TGMediaEditableItem.h>
#import <LegacyComponents/AVURLAsset+TGMediaItem.h>

#import <LegacyComponents/TGModernGalleryZoomableScrollViewSwipeGestureRecognizer.h>

#import <LegacyComponents/TGMediaAssetsLibrary.h>

#import <LegacyComponents/TGTimerTarget.h>

#import <LegacyComponents/TGMenuSheetController.h>
#import <LegacyComponents/TGMediaPickerSendActionSheetController.h>

#import "TGMediaPickerGallerySelectedItemsModel.h"
#import "TGCameraCapturedPhoto.h"
#import "TGCameraCapturedVideo.h"

#import "PGPhotoEditor.h"
#import "PGRectangleDetector.h"
#import "TGWarpedView.h"

#import "TGAnimationUtils.h"

const CGFloat TGCameraSwipeMinimumVelocity = 600.0f;
const CGFloat TGCameraSwipeVelocityThreshold = 700.0f;
const CGFloat TGCameraSwipeDistanceThreshold = 128.0f;
const NSTimeInterval TGCameraMinimumClipDuration = 4.0f;

@implementation TGCameraControllerWindow

static CGPoint TGCameraControllerClampPointToScreenSize(__unused id self, __unused SEL _cmd, CGPoint point)
{
    CGSize screenSize = TGScreenSize();
    return CGPointMake(MAX(0, MIN(point.x, screenSize.width)), MAX(0, MIN(point.y, screenSize.height)));
}

+ (void)initialize
{
    static bool initialized = false;
    if (!initialized)
    {
        initialized = true;
        
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone && (iosMajorVersion() > 8 || (iosMajorVersion() == 8 && iosMinorVersion() >= 3)))
        {
            FreedomDecoration instanceDecorations[] =
            {
                { .name = 0x4ea0b831U,
                    .imp = (IMP)&TGCameraControllerClampPointToScreenSize,
                    .newIdentifier = FreedomIdentifierEmpty,
                    .newEncoding = FreedomIdentifierEmpty
                }
            };
            
            freedomClassAutoDecorate(0x913b3af6, NULL, 0, instanceDecorations, sizeof(instanceDecorations) / sizeof(instanceDecorations[0]));
        }
    }
}

@end

@interface TGCameraController () <UIGestureRecognizerDelegate>
{
    bool _standalone;
    
    TGCameraControllerIntent _intent;
    PGCamera *_camera;
    PGCameraVolumeButtonHandler *_buttonHandler;
    
    UIView *_autorotationCorrectionView;
    
    UIView *_backgroundView;
    TGCameraPreviewView *_previewView;
    TGCameraMainView *_interfaceView;
    TGCameraCornersView *_cornersView;
    UIView *_overlayView;
    TGCameraFocusCrosshairsControl *_focusControl;
    TGCameraRectangleView *_rectangleView;
    
    UISwipeGestureRecognizer *_photoSwipeGestureRecognizer;
    UISwipeGestureRecognizer *_videoSwipeGestureRecognizer;
    TGModernGalleryZoomableScrollViewSwipeGestureRecognizer *_panGestureRecognizer;
    UIPinchGestureRecognizer *_pinchGestureRecognizer;
    
    CGFloat _dismissProgress;
    bool _dismissing;
    bool _finishedWithResult;
    
    TGMediaPickerGallerySelectedItemsModel *_selectedItemsModel;
    NSMutableArray<id<TGMediaEditableItem, TGMediaSelectableItem>> *_items;
    TGMediaEditingContext *_editingContext;
    TGMediaSelectionContext *_selectionContext;
    
    NSTimer *_switchToVideoTimer;
    NSTimer *_startRecordingTimer;
    bool _stopRecordingOnRelease;
    bool _shownMicrophoneAlert;
    
    id<LegacyComponentsContext> _context;
    bool _saveEditedPhotos;
    bool _saveCapturedMedia;
    
    bool _shutterIsBusy;
    bool _crossfadingForZoom;
    
    UIImpactFeedbackGenerator *_feedbackGenerator;
    
    NSMutableSet *_previousQRCodes;
}
@end

@implementation TGCameraController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia
{
    return [self initWithContext:context saveEditedPhotos:saveEditedPhotos saveCapturedMedia:saveCapturedMedia intent:TGCameraControllerGenericIntent];
}

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia intent:(TGCameraControllerIntent)intent
{
    return [self initWithContext:context saveEditedPhotos:saveEditedPhotos saveCapturedMedia:saveCapturedMedia camera:[[PGCamera alloc] init] previewView:nil intent:intent];
}

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context saveEditedPhotos:(bool)saveEditedPhotos saveCapturedMedia:(bool)saveCapturedMedia camera:(PGCamera *)camera previewView:(TGCameraPreviewView *)previewView intent:(TGCameraControllerIntent)intent
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        _context = context;
        if (previewView == nil)
            _standalone = true;
        _intent = intent;
        _camera = camera;
        _previewView = previewView;
        
        _items = [[NSMutableArray alloc] init];
        
        if (_intent != TGCameraControllerGenericIntent)
            _allowCaptions = false;
        _saveEditedPhotos = saveEditedPhotos;
        _saveCapturedMedia = saveCapturedMedia;
        
        _previousQRCodes = [[NSMutableSet alloc] init];
        
        if (iosMajorVersion() >= 10) {
            _feedbackGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        }
    }
    return self;
}

- (void)dealloc
{
    _camera.beganModeChange = nil;
    _camera.finishedModeChange = nil;
    _camera.beganPositionChange = nil;
    _camera.finishedPositionChange = nil;
    _camera.beganAdjustingFocus = nil;
    _camera.finishedAdjustingFocus = nil;
    _camera.flashActivityChanged = nil;
    _camera.flashAvailabilityChanged = nil;
    _camera.beganVideoRecording = nil;
    _camera.finishedVideoRecording = nil;
    _camera.captureInterrupted = nil;
    _camera.requestedCurrentInterfaceOrientation = nil;
    _camera.deviceAngleSampler.deviceOrientationChanged = nil;

    PGCamera *camera = _camera;
    if (_finishedWithResult || _standalone)
        [camera stopCaptureForPause:false completion:nil];
    
    [[[LegacyComponentsGlobals provider] applicationInstance] setIdleTimerDisabled:false];
}

- (void)loadView
{
    [super loadView];
    object_setClass(self.view, [TGFullscreenContainerView class]);
    
    CGSize screenSize = TGScreenSize();
    CGRect screenBounds = CGRectMake(0, 0, screenSize.width, screenSize.height);
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
        self.view.frame = screenBounds;
    
    _autorotationCorrectionView = [[UIView alloc] initWithFrame:screenBounds];
    _autorotationCorrectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_autorotationCorrectionView];
        
    _backgroundView = [[UIView alloc] initWithFrame:screenBounds];
    _backgroundView.backgroundColor = [UIColor blackColor];
    [_autorotationCorrectionView addSubview:_backgroundView];
    
    if (_previewView == nil)
    {
        _previewView = [[TGCameraPreviewView alloc] initWithFrame:[TGCameraController _cameraPreviewFrameForScreenSize:screenSize mode:PGCameraModePhoto]];
        [_camera attachPreviewView:_previewView];
        [_autorotationCorrectionView addSubview:_previewView];
    }
    
    _overlayView = [[UIView alloc] initWithFrame:screenBounds];
    _overlayView.clipsToBounds = true;
    _overlayView.frame = [TGCameraController _cameraPreviewFrameForScreenSize:screenSize mode:_camera.cameraMode];
    [_autorotationCorrectionView addSubview:_overlayView];
    
    UIInterfaceOrientation interfaceOrientation = [[LegacyComponentsGlobals provider] applicationStatusBarOrientation];
    
    if (interfaceOrientation == UIInterfaceOrientationPortrait)
        interfaceOrientation = [TGCameraController _interfaceOrientationForDeviceOrientation:_camera.deviceAngleSampler.deviceOrientation];
    
    __weak TGCameraController *weakSelf = self;
    _focusControl = [[TGCameraFocusCrosshairsControl alloc] initWithFrame:_overlayView.bounds];
    _focusControl.enabled = (_camera.supportsFocusPOI || _camera.supportsExposurePOI);
    _focusControl.stopAutomatically = (_focusControl.enabled && !_camera.supportsFocusPOI);
    _focusControl.previewView = _previewView;
    _focusControl.focusPOIChanged = ^(CGPoint point)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_camera setFocusPoint:point];
    };
    _focusControl.beganExposureChange = ^
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_camera beginExposureTargetBiasChange];
    };
    _focusControl.exposureChanged = ^(CGFloat value)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_camera setExposureTargetBias:value];
    };
    _focusControl.endedExposureChange = ^
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_camera endExposureTargetBiasChange];
    };
    [_focusControl setInterfaceOrientation:interfaceOrientation animated:false];
    [_overlayView addSubview:_focusControl];
    
    _rectangleView = [[TGCameraRectangleView alloc] initWithFrame:_overlayView.bounds];
    _rectangleView.previewView = _previewView;
    _rectangleView.hidden = true;
    [_overlayView addSubview:_rectangleView];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        _panGestureRecognizer = [[TGModernGalleryZoomableScrollViewSwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _panGestureRecognizer.delegate = self;
        _panGestureRecognizer.delaysTouchesBegan = true;
        _panGestureRecognizer.cancelsTouchesInView = false;
        [_overlayView addGestureRecognizer:_panGestureRecognizer];
    }
    
    _pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    _pinchGestureRecognizer.delegate = self;
    [_overlayView addGestureRecognizer:_pinchGestureRecognizer];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        _interfaceView = [[TGCameraMainPhoneView alloc] initWithFrame:screenBounds avatar:_intent == TGCameraControllerAvatarIntent hasUltrawideCamera:_camera.hasUltrawideCamera hasTelephotoCamera:_camera.hasTelephotoCamera];
        [_interfaceView setInterfaceOrientation:interfaceOrientation animated:false];
    }
    else
    {
        _interfaceView = [[TGCameraMainTabletView alloc] initWithFrame:screenBounds avatar:_intent == TGCameraControllerAvatarIntent hasUltrawideCamera:_camera.hasUltrawideCamera hasTelephotoCamera:_camera.hasTelephotoCamera];
        [_interfaceView setInterfaceOrientation:interfaceOrientation animated:false];
        
        CGSize referenceSize = [self referenceViewSizeForOrientation:interfaceOrientation];
        if (referenceSize.width > referenceSize.height)
            referenceSize = CGSizeMake(referenceSize.height, referenceSize.width);
        
        _interfaceView.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(interfaceOrientation));
        _interfaceView.frame = CGRectMake(0, 0, referenceSize.width, referenceSize.height);
    }
    
    _cornersView = [[TGCameraCornersView alloc] init];
    
    if (_intent == TGCameraControllerPassportIdIntent)
        [_interfaceView setDocumentFrameHidden:false];
    _selectedItemsModel = [[TGMediaPickerGallerySelectedItemsModel alloc] initWithSelectionContext:nil items:[_items copy]];
    [_interfaceView setSelectedItemsModel:_selectedItemsModel];
    _selectedItemsModel.selectionUpdated = ^(bool reload, bool incremental, bool add, NSInteger index)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_interfaceView updateSelectedPhotosView:reload incremental:incremental add:add index:index];
        NSInteger count = strongSelf->_items.count;
        [strongSelf->_interfaceView updateSelectionInterface:count counterVisible:count > 0 animated:true];
    };
    _interfaceView.thumbnailSignalForItem = ^SSignal *(id item)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf != nil)
            return [strongSelf _signalForItem:item];
        return nil;
    };
    _interfaceView.requestedVideoRecordingDuration = ^NSTimeInterval
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return 0.0;
        
        return strongSelf->_camera.videoRecordingDuration;
    };
    
    _interfaceView.cameraFlipped = ^
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_camera togglePosition];
    };
    
    _interfaceView.cameraShouldLeaveMode = ^bool(__unused PGCameraMode mode)
    {
        return true;
    };
    _interfaceView.cameraModeChanged = ^(PGCameraMode mode)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf _updateCameraMode:mode updateInterface:false];
    };
    
    _interfaceView.flashModeChanged = ^(PGCameraFlashMode mode)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_camera setFlashMode:mode];
    };
    
    _interfaceView.zoomChanged = ^(CGFloat level, bool animated)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_camera setZoomLevel:level animated:animated];
    };
    
    _interfaceView.shutterPressed = ^(bool fromHardwareButton)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (fromHardwareButton)
            [strongSelf->_interfaceView setShutterButtonHighlighted:true];
        
        [strongSelf shutterPressed];
    };
        
    _interfaceView.shutterReleased = ^(bool fromHardwareButton)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (fromHardwareButton)
            [strongSelf->_interfaceView setShutterButtonHighlighted:false];
        
        if (strongSelf->_previewView.hidden)
            return;
        
        [strongSelf shutterReleased];
    };
    
    _interfaceView.shutterPanGesture = ^(UIPanGestureRecognizer *gesture) {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf handleRamp:gesture];
    };
    
    _interfaceView.cancelPressed = ^
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf cancelPressed];
    };
    _interfaceView.resultPressed = ^(NSInteger index)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf presentResultControllerForItem:index == -1 ? nil : strongSelf->_items[index] completion:nil];
    };
    _interfaceView.itemRemoved = ^(NSInteger index)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            id item = [strongSelf->_items objectAtIndex:index];
            [strongSelf->_selectionContext setItem:item selected:false];
            [strongSelf->_items removeObjectAtIndex:index];
            [strongSelf->_selectedItemsModel removeSelectedItem:item];
            [strongSelf->_interfaceView setResults:[strongSelf->_items copy]];
        }
    };
    
    if (_intent != TGCameraControllerGenericIntent && _intent != TGCameraControllerAvatarIntent)
        [_interfaceView setHasModeControl:false];

    if (@available(iOS 11.0, *)) {
        _backgroundView.accessibilityIgnoresInvertColors = true;
        _interfaceView.accessibilityIgnoresInvertColors = true;
        _focusControl.accessibilityIgnoresInvertColors = true;
    }
    
    [_autorotationCorrectionView addSubview:_interfaceView];
    if ((int)self.view.frame.size.width > 320 || [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        [_autorotationCorrectionView addSubview:_cornersView];
    }
     
    _photoSwipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    _photoSwipeGestureRecognizer.delegate = self;
    [_autorotationCorrectionView addGestureRecognizer:_photoSwipeGestureRecognizer];
    
    _videoSwipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    _videoSwipeGestureRecognizer.delegate = self;
    [_autorotationCorrectionView addGestureRecognizer:_videoSwipeGestureRecognizer];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
    {
        _photoSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
        _videoSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    }
    else
    {
        _photoSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionUp;
        _videoSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionDown;
    }
    
    void (^buttonPressed)(void) = ^
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_interfaceView.shutterPressed(true);
    };

    void (^buttonReleased)(void) = ^
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_interfaceView.shutterReleased(true);
    };
    
    _buttonHandler = [[PGCameraVolumeButtonHandler alloc] initWithUpButtonPressedBlock:buttonPressed upButtonReleasedBlock:buttonReleased downButtonPressedBlock:buttonPressed downButtonReleasedBlock:buttonReleased];
    
    [self _configureCamera];
}

- (void)_updateCameraMode:(PGCameraMode)mode updateInterface:(bool)updateInterface {
    [_camera setCameraMode:mode];
    if (updateInterface)
        [_interfaceView setCameraMode:mode];
    
    _focusControl.hidden = mode == PGCameraModePhotoScan;
    _rectangleView.hidden = mode != PGCameraModePhotoScan;
    
    if (mode == PGCameraModePhotoScan) {
        [self _createContextsIfNeeded];
        
        if (_items.count == 0) {
            [_interfaceView setToastMessage:@"Position the document in view" animated:true];
        } else {
            
        }
    }
}

- (void)_configureCamera
{
    __weak TGCameraController *weakSelf = self;
    _camera.requestedCurrentInterfaceOrientation = ^UIInterfaceOrientation(bool *mirrored)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return UIInterfaceOrientationUnknown;
        
        if (strongSelf->_intent == TGCameraControllerPassportIdIntent)
            return UIInterfaceOrientationPortrait;
        
        if (mirrored != NULL)
        {
            TGCameraPreviewView *previewView = strongSelf->_previewView;
            if (previewView != nil)
                *mirrored = previewView.captureConnection.videoMirrored;
        }
        
        return [strongSelf->_interfaceView interfaceOrientation];
    };
    
    _camera.beganModeChange = ^(PGCameraMode mode, void(^commitBlock)(void))
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_buttonHandler.ignoring = true;
        
        [strongSelf->_focusControl reset];
        strongSelf->_focusControl.active = false;
        
        strongSelf.view.userInteractionEnabled = false;
        
        PGCameraMode currentMode = strongSelf->_camera.cameraMode;
        bool generalModeNotChanged = [PGCamera isPhotoCameraMode:mode] == [PGCamera isPhotoCameraMode:currentMode];
        if (strongSelf->_camera.captureSession.currentCameraPosition == PGCameraPositionFront && mode == PGCameraModePhotoScan) {
            generalModeNotChanged = false;
        }
        if ([PGCamera isVideoCameraMode:mode] && !generalModeNotChanged)
        {
            [[LegacyComponentsGlobals provider] pauseMusicPlayback];
        }
        
        if (generalModeNotChanged)
        {
            if (commitBlock != nil)
                commitBlock();
        }
        else
        {
            [strongSelf->_camera captureNextFrameCompletion:^(UIImage *image)
            {
                if (commitBlock != nil)
                    commitBlock();
                 
                image = TGCameraModeSwitchImage(image, CGSizeMake(image.size.width, image.size.height));
                 
                TGDispatchOnMainThread(^
                {
                    [strongSelf->_previewView beginTransitionWithSnapshotImage:image animated:true];
                });
            }];
        }
    };
    
    _camera.finishedModeChange = ^
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        TGDispatchOnMainThread(^
        {
            [strongSelf->_interfaceView setZoomLevel:1.0f displayNeeded:false];
            
            if (!strongSelf->_dismissing)
            {
                strongSelf.view.userInteractionEnabled = true;
                [strongSelf resizePreviewViewForCameraMode:strongSelf->_camera.cameraMode];
                
                strongSelf->_focusControl.active = true;
                [strongSelf->_interfaceView setFlashMode:strongSelf->_camera.flashMode];

                [strongSelf->_buttonHandler enableIn:1.5f];
                
                if (strongSelf->_camera.cameraMode == PGCameraModeVideo && ([PGCamera microphoneAuthorizationStatus] == PGMicrophoneAuthorizationStatusRestricted || [PGCamera microphoneAuthorizationStatus] == PGMicrophoneAuthorizationStatusDenied) && !strongSelf->_shownMicrophoneAlert)
                {
                    [[[LegacyComponentsGlobals provider] accessChecker] checkMicrophoneAuthorizationStatusForIntent:TGMicrophoneAccessIntentVideo alertDismissCompletion:nil];
                    strongSelf->_shownMicrophoneAlert = true;
                }
                
                if (strongSelf->_camera.cameraMode == PGCameraModePhotoScan) {
                    strongSelf->_camera.captureSession.rectangleDetector.update = ^(bool capture, PGRectangle *rectangle) {
                        __strong TGCameraController *strongSelf = weakSelf;
                        if (strongSelf == nil)
                            return;
                        
                        TGDispatchOnMainThread(^{
                            [strongSelf->_rectangleView drawRectangle:rectangle];
                            if (capture) {
                                [strongSelf _makeScan:rectangle];
                            }
                        });
                    };
                }
            }
            
            [strongSelf->_previewView endTransitionAnimated:true];
        });
    };
    
    _camera.beganPositionChange = ^(bool targetPositionHasFlash, bool targetPositionHasZoom, void(^commitBlock)(void))
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_focusControl reset];
        
        [strongSelf->_interfaceView setHasFlash:targetPositionHasFlash];
        if (!targetPositionHasZoom) {
            [strongSelf->_interfaceView setHasZoom:targetPositionHasZoom];
        }
        strongSelf->_camera.zoomLevel = 0.0f;
        
        strongSelf.view.userInteractionEnabled = false;
        
        [strongSelf->_camera captureNextFrameCompletion:^(UIImage *image)
        {
            if (commitBlock != nil)
                commitBlock();
             
            image = TGCameraPositionSwitchImage(image, CGSizeMake(image.size.width, image.size.height));
             
            TGDispatchOnMainThread(^
            {
                [UIView transitionWithView:strongSelf->_previewView duration:0.4f options:UIViewAnimationOptionTransitionFlipFromLeft | UIViewAnimationOptionCurveEaseOut animations:^
                {
                    [strongSelf->_previewView beginTransitionWithSnapshotImage:image animated:false];
                } completion:^(__unused BOOL finished)
                {
                    strongSelf.view.userInteractionEnabled = true;
                }];
            });
        }];
        
        if (@available(iOS 13.0, *)) {
            [strongSelf->_feedbackGenerator impactOccurredWithIntensity:0.5];
        } else {
            [strongSelf->_feedbackGenerator impactOccurred];
        }
    };
    
    _camera.finishedPositionChange = ^(bool targetPositionHasZoom)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        TGDispatchOnMainThread(^
        {
            [strongSelf->_previewView endTransitionAnimated:true];
            [strongSelf->_interfaceView setZoomLevel:1.0f displayNeeded:false];

            if (targetPositionHasZoom) {
                [strongSelf->_interfaceView setHasZoom:targetPositionHasZoom];
            }
            
            if (strongSelf->_camera.hasFlash && strongSelf->_camera.flashActive)
                [strongSelf->_interfaceView setFlashActive:true];
                                   
            strongSelf->_focusControl.enabled = (strongSelf->_camera.supportsFocusPOI || strongSelf->_camera.supportsExposurePOI);
            strongSelf->_focusControl.stopAutomatically = (strongSelf->_focusControl.enabled && !strongSelf->_camera.supportsFocusPOI);
        });
    };
    
    _camera.beganAdjustingFocus = ^
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_focusControl playAutoFocusAnimation];
    };
    
    _camera.finishedAdjustingFocus = ^
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_focusControl stopAutoFocusAnimation];
    };
    
    _camera.flashActivityChanged = ^(bool active)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf->_camera.flashMode != PGCameraFlashModeAuto)
            active = false;
        
        TGDispatchOnMainThread(^
        {
            [strongSelf->_interfaceView setFlashActive:active];
        });
    };
    
    _camera.flashAvailabilityChanged = ^(bool available)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_interfaceView setFlashUnavailable:!available];
    };
    
    _camera.beganVideoRecording = ^(__unused bool moment)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_focusControl.ignoreAutofocusing = true;
        [strongSelf->_interfaceView setRecordingVideo:true animated:true];
    };
    
    _camera.captureInterrupted = ^(AVCaptureSessionInterruptionReason reason)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (reason == AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps)
            [strongSelf beginTransitionOutWithVelocity:0.0f];
    };
    
    _camera.finishedVideoRecording = ^(__unused bool moment)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_focusControl.ignoreAutofocusing = false;
        [strongSelf->_interfaceView setFlashMode:PGCameraFlashModeOff];
    };
    
    _camera.deviceAngleSampler.deviceOrientationChanged = ^(UIDeviceOrientation orientation)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf handleDeviceOrientationChangedTo:orientation];
    };
    
    _camera.captureSession.recognizedQRCode = ^(NSString *value, AVMetadataMachineReadableCodeObject *object)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf.recognizedQRCode != nil)
        {
            if (![strongSelf->_previousQRCodes containsObject:value])
            {
                strongSelf.recognizedQRCode(value);
                [strongSelf->_previousQRCodes addObject:value];
            }
        }
    };
    
    _camera.captureSession.crossfadeNeeded = ^{
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            if (strongSelf->_crossfadingForZoom) {
                return;
            }
            strongSelf->_crossfadingForZoom = true;
            
            [strongSelf->_camera captureNextFrameCompletion:^(UIImage *image)
            {
                TGDispatchOnMainThread(^
                {
                    [strongSelf->_previewView beginTransitionWithSnapshotImage:image animated:false];
                    
                    TGDispatchAfter(0.15, dispatch_get_main_queue(), ^{
                        [strongSelf->_previewView endTransitionAnimated:true];
                        strongSelf->_crossfadingForZoom = false;
                    });
                });
            }];
        };
    };
}

#pragma mark - View Life Cycle

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [UIView animateWithDuration:0.3f animations:^
    {
        [_context setApplicationStatusBarAlpha:0.0f];
    }];
    
    [[[LegacyComponentsGlobals provider] applicationInstance] setIdleTimerDisabled:true];
    
    if (!_camera.isCapturing)
        [_camera startCaptureForResume:false completion:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [UIView animateWithDuration:0.3f animations:^
    {
        //[_context setApplicationStatusBarAlpha:1.0f];
    }];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    if ([self shouldCorrectAutorotation])
        [self applyAutorotationCorrectingTransformForOrientation:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation]];
}

- (bool)shouldCorrectAutorotation
{
    return [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

- (void)applyAutorotationCorrectingTransformForOrientation:(UIInterfaceOrientation)orientation
{
    CGSize screenSize = TGScreenSize();
    CGRect screenBounds = CGRectMake(0, 0, screenSize.width, screenSize.height);
    
    _autorotationCorrectionView.transform = CGAffineTransformIdentity;
    _autorotationCorrectionView.frame = screenBounds;
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    switch (orientation)
    {
        case UIInterfaceOrientationPortraitUpsideDown:
            transform = CGAffineTransformMakeRotation(M_PI);
            break;
            
        case UIInterfaceOrientationLandscapeLeft:
            transform = CGAffineTransformMakeRotation(M_PI_2);
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            transform = CGAffineTransformMakeRotation(-M_PI_2);
            break;
            
        default:
            break;
    }
    
    _autorotationCorrectionView.transform = transform;
    CGSize bounds = [_context fullscreenBounds].size;
    _autorotationCorrectionView.center = CGPointMake(bounds.width / 2, bounds.height / 2);
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        return UIInterfaceOrientationMaskAll;
    
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        return true;
    
    return false;
}

- (void)setInterfaceHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        if (hidden && _interfaceView.alpha < FLT_EPSILON)
            return;

        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        animation.fromValue = @(_interfaceView.alpha);
        animation.toValue = @(hidden ? 0.0f : 1.0f);
        animation.duration = 0.2f;
        [_interfaceView.layer addAnimation:animation forKey:@"opacity"];
        
        CABasicAnimation *cornersAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        cornersAnimation.fromValue = @(_cornersView.alpha);
        cornersAnimation.toValue = @(hidden ? 0.0f : 1.0f);
        cornersAnimation.duration = 0.2f;
        [_cornersView.layer addAnimation:cornersAnimation forKey:@"opacity"];
        
        _interfaceView.alpha = hidden ? 0.0f : 1.0f;
        _cornersView.alpha = hidden ? 0.0 : 1.0;
    }
    else
    {
        [_interfaceView.layer removeAllAnimations];
        _interfaceView.alpha = hidden ? 0.0 : 1.0;
        
        [_cornersView.layer removeAllAnimations];
        _cornersView.alpha = hidden ? 0.0 : 1.0;
    }
}

#pragma mark - 

- (void)startVideoRecording
{
    __weak TGCameraController *weakSelf = self;
    if (_camera.cameraMode == PGCameraModePhoto)
    {
        _switchToVideoTimer = nil;
        
        _camera.onAutoStartVideoRecording = ^
        {
            __strong TGCameraController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf->_stopRecordingOnRelease = true;
            
            [strongSelf->_camera startVideoRecordingForMoment:false completion:^(NSURL *outputURL, __unused CGAffineTransform transform, CGSize dimensions, NSTimeInterval duration, bool success)
            {
                __strong TGCameraController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (success)
                {
                    TGCameraCapturedVideo *capturedVideo = [[TGCameraCapturedVideo alloc] initWithURL:outputURL];
                    [strongSelf addResultItem:capturedVideo];
                    
                    if (![strongSelf maybePresentResultControllerForItem:capturedVideo completion:nil])
                    {
                        strongSelf->_camera.disabled = false;
                        [strongSelf->_interfaceView setRecordingVideo:false animated:true];
                    }
                }
                else
                {
                    [strongSelf->_interfaceView setRecordingVideo:false animated:false];
                }
            }];
        };
        _camera.autoStartVideoRecording = true;
        [self _updateCameraMode:PGCameraModeVideo updateInterface:true];
    }
    else if (_camera.cameraMode == PGCameraModeVideo)
    {
        _startRecordingTimer = nil;
        
        [_camera startVideoRecordingForMoment:false completion:^(NSURL *outputURL, __unused CGAffineTransform transform, CGSize dimensions, NSTimeInterval duration, bool success)
        {
            __strong TGCameraController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (success)
            {
                TGCameraCapturedVideo *capturedVideo = [[TGCameraCapturedVideo alloc] initWithURL:outputURL];
                [strongSelf addResultItem:capturedVideo];
                
                if (![strongSelf maybePresentResultControllerForItem:capturedVideo completion:nil])
                {
                    strongSelf->_camera.disabled = false;
                    [strongSelf->_interfaceView setRecordingVideo:false animated:true];
                }
            }
            else
            {
                [strongSelf->_interfaceView setRecordingVideo:false animated:false];
            }
        }];

        _stopRecordingOnRelease = true;
    }
}

- (void)shutterPressed
{
    if (@available(iOS 13.0, *)) {
        [_feedbackGenerator impactOccurredWithIntensity:0.5];
    } else {
        [_feedbackGenerator impactOccurred];
    }
    
    PGCameraMode cameraMode = _camera.cameraMode;
    switch (cameraMode)
    {
        case PGCameraModePhoto:
        {
            if (_intent == TGCameraControllerGenericIntent || _intent == TGCameraControllerAvatarIntent)
            {
                _switchToVideoTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(startVideoRecording) interval:0.25 repeat:false];
            }
        }
            break;
    
        case PGCameraModeVideo:
        case PGCameraModeSquareVideo:
        case PGCameraModeSquareSwing:
        {
            if (!_camera.isRecordingVideo)
            {
                _startRecordingTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(startVideoRecording) interval:0.25 repeat:false];
            }
            else
            {
                _stopRecordingOnRelease = true;
            }
        }
            break;
            
        default:
            break;
    }
}

- (void)shutterReleased
{
    if (@available(iOS 13.0, *)) {
        [_feedbackGenerator impactOccurredWithIntensity:0.6];
    } else {
        [_feedbackGenerator impactOccurred];
    }
    
    [_switchToVideoTimer invalidate];
    _switchToVideoTimer = nil;
    
    [_startRecordingTimer invalidate];
    _startRecordingTimer = nil;
 
    if (_shutterIsBusy)
        return;
    
    __weak TGCameraController *weakSelf = self;
    PGCameraMode cameraMode = _camera.cameraMode;
    if (cameraMode == PGCameraModePhoto || cameraMode == PGCameraModeSquarePhoto || cameraMode == PGCameraModePhotoScan)
    {
        _camera.disabled = true;

        _shutterIsBusy = true;
        
        TGDispatchAfter(0.05, dispatch_get_main_queue(), ^
        {
            [_previewView blink];
        });
        
        if (![self willPresentResultController])
        {
        }
        else
        {
            _buttonHandler.enabled = false;
            [_buttonHandler ignoreEventsFor:1.5f andDisable:true];
        }
                
        [_camera takePhotoWithCompletion:^(UIImage *result, PGCameraShotMetadata *metadata)
        {
            __strong TGCameraController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
        
            TGDispatchOnMainThread(^
            {
                strongSelf->_shutterIsBusy = false;
                
                if (strongSelf->_intent == TGCameraControllerAvatarIntent || strongSelf->_intent == TGCameraControllerSignupAvatarIntent)
                {
                    [strongSelf presentPhotoResultControllerWithImage:result metadata:metadata completion:^{}];
                }
                else
                {
                    TGCameraCapturedPhoto *capturedPhoto = [[TGCameraCapturedPhoto alloc] initWithImage:result metadata:metadata];
                    [strongSelf addResultItem:capturedPhoto];
                    
                    if (![strongSelf maybePresentResultControllerForItem:capturedPhoto completion:nil])
                        strongSelf->_camera.disabled = false;
                }
            });
            
            [[SQueue concurrentDefaultQueue] dispatch:^{
                [TGCameraController generateStartImageWithImage:result];
            }];
        }];
    }
    else if (cameraMode == PGCameraModeVideo || cameraMode == PGCameraModeSquareVideo || cameraMode == PGCameraModeSquareSwing)
    {
        if (!_camera.isRecordingVideo)
        {
            [_buttonHandler ignoreEventsFor:1.0f andDisable:false];
            
            [_camera startVideoRecordingForMoment:false completion:^(NSURL *outputURL, __unused CGAffineTransform transform, CGSize dimensions, NSTimeInterval duration, bool success)
            {
                __strong TGCameraController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (success)
                {
                    TGCameraCapturedVideo *capturedVideo = [[TGCameraCapturedVideo alloc] initWithURL:outputURL];
                    if (strongSelf->_intent == TGCameraControllerAvatarIntent || strongSelf->_intent == TGCameraControllerSignupAvatarIntent)
                    {
                        [strongSelf presentPhotoResultControllerWithImage:capturedVideo metadata:nil completion:^{
                             [strongSelf->_interfaceView setRecordingVideo:false animated:true];
                        }];
                    } else {
                        [strongSelf addResultItem:capturedVideo];
                        if (![strongSelf maybePresentResultControllerForItem:capturedVideo completion:nil])
                        {
                            strongSelf->_camera.disabled = false;
                            [strongSelf->_interfaceView setRecordingVideo:false animated:true];
                        }
                    }
                }
                else
                {
                    [strongSelf->_interfaceView setRecordingVideo:false animated:false];
                }
            }];
        }
        else if (_stopRecordingOnRelease)
        {
            _stopRecordingOnRelease = false;
            
            [_camera stopVideoRecording];
            TGDispatchAfter(0.3, dispatch_get_main_queue(), ^{
                [_camera setZoomLevel:1.0];
                [_interfaceView setZoomLevel:1.0 displayNeeded:false];
                _camera.disabled = true;
            });
            
            [_buttonHandler ignoreEventsFor:1.0f andDisable:[self willPresentResultController]];
        }
    }
}

- (void)_makeScan:(PGRectangle *)rectangle
{
    if (_shutterIsBusy)
        return;
    
    _camera.disabled = true;
    _shutterIsBusy = true;
    
    __weak TGCameraController *weakSelf = self;
    [_camera takePhotoWithCompletion:^(UIImage *result, PGCameraShotMetadata *metadata)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        TGDispatchOnMainThread(^
        {
            [strongSelf->_interfaceView setToastMessage:nil animated:true];
            
            strongSelf->_shutterIsBusy = false;
            
            [strongSelf->_rectangleView drawRectangle:nil];
            strongSelf->_rectangleView.enabled = false;
            
            TGDispatchAfter(2.0, dispatch_get_main_queue(), ^{
                strongSelf->_rectangleView.enabled = true;
            });
            
            TGCameraCapturedPhoto *capturedPhoto = [[TGCameraCapturedPhoto alloc] initWithImage:result rectangle:rectangle];
            [strongSelf addResultItem:capturedPhoto];
            
            PGRectangle *cropRectangle = [[rectangle rotate90] transform:CGAffineTransformMakeScale(result.size.width, result.size.height)];
            PGRectangle *convertedRectangle = [cropRectangle sort];
            convertedRectangle = [convertedRectangle cartesian:result.size.height];
            
            CIImage *ciImage = [[CIImage alloc] initWithImage:result];
            CIImage *croppedImage = [ciImage imageByApplyingFilter:@"CIPerspectiveCorrection" withInputParameters:@{
                @"inputTopLeft": [CIVector vectorWithCGPoint:convertedRectangle.topLeft],
                @"inputTopRight": [CIVector vectorWithCGPoint:convertedRectangle.topRight],
                @"inputBottomLeft": [CIVector vectorWithCGPoint:convertedRectangle.bottomLeft],
                @"inputBottomRight": [CIVector vectorWithCGPoint:convertedRectangle.bottomRight]
            }];
            CIImage *enhancedImage = [croppedImage imageByApplyingFilter:@"CIDocumentEnhancer" withInputParameters:@{}];
            
            CIContext *context = [CIContext contextWithOptions:nil];
            UIImage *editedImage = [UIImage imageWithCGImage:[context createCGImage:enhancedImage fromRect:enhancedImage.extent]];
            UIImage *thumbnailImage = TGScaleImage(editedImage, TGScaleToFillSize(editedImage.size, TGPhotoThumbnailSizeForCurrentScreen()));
            [strongSelf->_editingContext setImage:editedImage thumbnailImage:thumbnailImage forItem:capturedPhoto synchronous:true];
            [strongSelf->_editingContext setAdjustments:[PGPhotoEditorValues editorValuesWithOriginalSize:result.size cropRectangle:cropRectangle cropOrientation:UIImageOrientationUp cropSize:editedImage.size enhanceDocument:true paintingData:nil] forItem:capturedPhoto];
            
            [strongSelf _playScanAnimation:editedImage rectangle:rectangle completion:^{
                [strongSelf->_selectedItemsModel addSelectedItem:capturedPhoto];
                [strongSelf->_selectionContext setItem:capturedPhoto selected:true];
                [strongSelf->_interfaceView setResults:[strongSelf->_items copy]];
                
                TGDispatchAfter(0.5, dispatch_get_main_queue(), ^{
                    [strongSelf->_interfaceView setToastMessage:@"Ready for next scan" animated:true];
                });
            }];
            
            strongSelf->_camera.disabled = false;
        });
    }];
}

- (void)_playScanAnimation:(UIImage *)image rectangle:(PGRectangle *)rectangle completion:(void(^)(void))completion
{
    TGWarpedView *warpedView = [[TGWarpedView alloc] initWithImage:image];
    warpedView.layer.anchorPoint = CGPointMake(0, 0);
    warpedView.frame = _rectangleView.frame;
    [_rectangleView.superview addSubview:warpedView];
    
    CGAffineTransform transform = CGAffineTransformMakeScale(_previewView.frame.size.width, _previewView.frame.size.height);
    PGRectangle *displayRectangle = [[[rectangle rotate90] transform:transform] sort];
    [warpedView transformToFitQuadTopLeft:displayRectangle.topLeft topRight:displayRectangle.topRight bottomLeft:displayRectangle.bottomLeft bottomRight:displayRectangle.bottomRight];
    
    CGFloat inset = 16.0f;
    CGSize targetSize = TGScaleToFit(image.size, CGSizeMake(_previewView.frame.size.width - inset * 2.0, _previewView.frame.size.height - inset * 2.0));
    CGRect targetRect = CGRectMake(floor((_previewView.frame.size.width - targetSize.width) / 2.0), floor((_previewView.frame.size.height - targetSize.height) / 2.0), targetSize.width, targetSize.height);
    
    [UIView animateWithDuration:0.3 delay:0.0 options:(7 << 16) animations:^{
        [warpedView transformToFitQuadTopLeft:CGPointMake(targetRect.origin.x, targetRect.origin.y) topRight:CGPointMake(targetRect.origin.x + targetRect.size.width, targetRect.origin.y) bottomLeft:CGPointMake(targetRect.origin.x, targetRect.origin.y + targetRect.size.height) bottomRight:CGPointMake(targetRect.origin.x + targetRect.size.width, targetRect.origin.y + targetRect.size.height)];
    } completion:^(BOOL finished) {
        UIImageView *outView = [[UIImageView alloc] initWithImage:image];
        outView.frame = targetRect;
        [warpedView.superview addSubview:outView];
        [warpedView removeFromSuperview];
        
        TGDispatchAfter(0.2, dispatch_get_main_queue(), ^{
            CGPoint sourcePoint = outView.center;
            CGPoint targetPoint = CGPointMake(_previewView.frame.size.width - 44.0, _previewView.frame.size.height - 44.0);
            CGPoint midPoint = CGPointMake((sourcePoint.x + targetPoint.x) / 2.0, sourcePoint.y - 30.0);
            
            CGFloat x1 = sourcePoint.x;
            CGFloat y1 = sourcePoint.y;
            CGFloat x2 = midPoint.x;
            CGFloat y2 = midPoint.y;
            CGFloat x3 = targetPoint.x;
            CGFloat y3 = targetPoint.y;

            CGFloat a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / ((x1 - x2) * (x1 - x3) * (x2 - x3));
            CGFloat b = (x1 * x1 * (y2 - y3) + x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1)) / ((x1 - x2) * (x1 - x3) * (x2 - x3));
            CGFloat c = (x2 * x2 * (x3 * y1 - x1 * y3) + x2 * (x1 * x1 * y3 - x3 * x3 * y1) + x1 * x3 * (x3 - x1) * y2) / ((x1 - x2) * (x1 - x3) * (x2 - x3));
            
            [UIView animateWithDuration:0.3 animations:^{
                outView.transform = CGAffineTransformMakeScale(0.1, 0.1);
            } completion:^(BOOL finished) {
                [outView removeFromSuperview];
            }];
            
            TGDispatchAfter(0.28, dispatch_get_main_queue(), ^{
                completion();
            });
            
            CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
            NSMutableArray *values = [[NSMutableArray alloc] init];
            NSMutableArray *keyTimes = [[NSMutableArray alloc] init];
            for (NSInteger i = 0; i < 10; i++) {
                CGFloat k = (CGFloat)i / (CGFloat)(10 - 1);
                CGFloat x = sourcePoint.x * (1.0 - k) + targetPoint.x * k;
                CGFloat y = a * x * x + b * x + c;
                
                [values addObject:[NSValue valueWithCGPoint:CGPointMake(x, y)]];
                [keyTimes addObject:@(k)];
            }
            animation.values = values;
            animation.keyTimes = keyTimes;
            animation.duration = 0.35;
            animation.removedOnCompletion = false;
            [outView.layer addAnimation:animation forKey:@"position"];
        });
    }];
}

- (void)cancelPressed
{
    if (_items.count > 0)
    {
        __weak TGCameraController *weakSelf = self;
        
        TGMenuSheetController *controller = [[TGMenuSheetController alloc] initWithContext:_context dark:false];
        controller.dismissesByOutsideTap = true;
        controller.narrowInLandscape = true;
        __weak TGMenuSheetController *weakController = controller;
        
        NSArray *items = @
        [
         [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Camera.Discard") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
          {
              __strong TGMenuSheetController *strongController = weakController;
              if (strongController == nil)
                  return;
              
              __strong TGCameraController *strongSelf = weakSelf;
              if (strongSelf == nil)
                  return;
              
              [strongController dismissAnimated:true manual:false completion:nil];
              [strongSelf beginTransitionOutWithVelocity:0.0f];
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
            __strong TGCameraController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return CGRectZero;
            
            UIButton *cancelButton = strongSelf->_interfaceView->_cancelButton;
            return [cancelButton convertRect:cancelButton.bounds toView:strongSelf.view];
        };
        controller.permittedArrowDirections = UIPopoverArrowDirectionAny;
        [controller presentInViewController:self sourceView:self.view animated:true];
    }
    else
    {
        [self beginTransitionOutWithVelocity:0.0f];
    }
}

#pragma mark - Result

- (void)addResultItem:(id<TGMediaEditableItem, TGMediaSelectableItem>)item
{
    [_items addObject:item];
}

- (bool)willPresentResultController
{
    return _items.count == 0 || (_items.count > 0 && (_items.count + 1) % 10 == 0);
}

- (bool)shouldPresentResultController
{
    return _items.count == 1 || (_items.count > 0 && _items.count % 10 == 0);
}

- (bool)maybePresentResultControllerForItem:(id<TGMediaEditableItem, TGMediaSelectableItem>)editableItem completion:(void (^)(void))completion
{
    if ([self shouldPresentResultController])
    {
        [self presentResultControllerForItem:editableItem completion:^
        {
            [_selectedItemsModel addSelectedItem:editableItem];
            [_selectionContext setItem:editableItem selected:true];
            [_interfaceView setResults:[_items copy]];
            if (completion != nil)
                completion();
        }];
        return true;
    }
    else
    {
        [_selectedItemsModel addSelectedItem:editableItem];
        [_selectionContext setItem:editableItem selected:true];
        [_interfaceView setResults:[_items copy]];
        return false;
    }
}

- (NSArray *)prepareGalleryItemsForResults:(void (^)(TGMediaPickerGalleryItem *))enumerationBlock
{
    NSMutableArray *galleryItems = [[NSMutableArray alloc] init];
    for (id<TGMediaEditableItem, TGMediaSelectableItem> item in _items)
    {
        TGMediaPickerGalleryItem<TGModernGallerySelectableItem, TGModernGalleryEditableItem> *galleryItem = nil;
        if ([item isKindOfClass:[TGCameraCapturedPhoto class]])
        {
            galleryItem = [[TGMediaPickerGalleryPhotoItem alloc] initWithAsset:item];
        }
        else if ([item isKindOfClass:[TGCameraCapturedVideo class]])
        {
            galleryItem = [[TGMediaPickerGalleryVideoItem alloc] initWithAsset:item];
        }

        galleryItem.selectionContext = _selectionContext;
        galleryItem.editingContext = _editingContext;
        galleryItem.stickersContext = _stickersContext;
        
        if (enumerationBlock != nil)
            enumerationBlock(galleryItem);
        
        if (galleryItem != nil)
            [galleryItems addObject:galleryItem];
    }
    
    return galleryItems;
}

- (void)_createContextsIfNeeded
{
    TGMediaEditingContext *editingContext = _editingContext;
    if (editingContext == nil)
    {
        editingContext = [[TGMediaEditingContext alloc] init];
        if (self.forcedCaption != nil)
            [editingContext setForcedCaption:self.forcedCaption];
        _editingContext = editingContext;
        _interfaceView.editingContext = editingContext;
    }
    TGMediaSelectionContext *selectionContext = _selectionContext;
    if (selectionContext == nil)
    {
        selectionContext = [[TGMediaSelectionContext alloc] initWithGroupingAllowed:self.allowGrouping selectionLimit:100];
        if (self.allowGrouping)
            selectionContext.grouping = true;
        _selectionContext = selectionContext;
    }
}

- (void)presentResultControllerForItem:(id<TGMediaEditableItem, TGMediaSelectableItem>)editableItemValue completion:(void (^)(void))completion
{
    __block id<TGMediaEditableItem, TGMediaSelectableItem> editableItem = editableItemValue;
    UIViewController *(^begin)(id<LegacyComponentsContext>) = ^(id<LegacyComponentsContext> windowContext) {
        [self _createContextsIfNeeded];
        TGMediaEditingContext *editingContext = _editingContext;
        TGMediaSelectionContext *selectionContext = _selectionContext;
        
        if (editableItem == nil)
            editableItem = _items.lastObject;
        
        [[[LegacyComponentsGlobals provider] applicationInstance] setIdleTimerDisabled:false];
        
        if (_intent == TGCameraControllerPassportIdIntent)
        {
            TGCameraCapturedPhoto *photo = (TGCameraCapturedPhoto *)editableItem;
            CGSize size = photo.originalSize;
            CGFloat height = size.width * 0.704f;
            PGPhotoEditorValues *values = [PGPhotoEditorValues editorValuesWithOriginalSize:size cropRect:CGRectMake(0, floor((size.height - height) / 2.0f), size.width, height) cropRotation:0.0f cropOrientation:UIImageOrientationUp cropLockedAspectRatio:0.0f cropMirrored:false toolValues:nil paintingData:nil sendAsGif:false];
            
            SSignal *cropSignal = [[photo originalImageSignal:0.0] map:^UIImage *(UIImage *image)
            {
                UIImage *croppedImage = TGPhotoEditorCrop(image, nil, UIImageOrientationUp, 0.0f, values.cropRect, false, TGPhotoEditorResultImageMaxSize, size, true);
                return croppedImage;
            }];
            
            [cropSignal startWithNext:^(UIImage *image)
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
                
                [editingContext setAdjustments:values forItem:photo];
                [editingContext setImage:image thumbnailImage:thumbnailImage forItem:photo synchronous:true];
            }];
        }

        __weak TGCameraController *weakSelf = self;
        TGModernGalleryController *galleryController = [[TGModernGalleryController alloc] initWithContext:windowContext];
        galleryController.adjustsStatusBarVisibility = false;
        galleryController.hasFadeOutTransition = true;
        
        __block id<TGModernGalleryItem> focusItem = nil;
        NSArray *galleryItems = [self prepareGalleryItemsForResults:^(TGMediaPickerGalleryItem *item)
        {
            if (focusItem == nil && [item.asset isEqual:editableItem])
            {
                focusItem = item;
                
                if ([item.asset isKindOfClass:[TGCameraCapturedVideo class]])
                {
                    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:((TGCameraCapturedVideo *)item.asset).immediateAVAsset];
                    generator.appliesPreferredTrackTransform = true;
                    generator.maximumSize = CGSizeMake(640.0f, 640.0f);
                    CGImageRef imageRef = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:NULL];
                    UIImage *thumbnailImage = [[UIImage alloc] initWithCGImage:imageRef];
                    CGImageRelease(imageRef);
                    
                    item.immediateThumbnailImage = thumbnailImage;
                }
            }
        }];
        
        bool hasCamera = !self.inhibitMultipleCapture && (((_intent == TGCameraControllerGenericIntent || _intent == TGCameraControllerGenericPhotoOnlyIntent) && !_shortcut) || (_intent == TGCameraControllerPassportMultipleIntent));
        TGMediaPickerGalleryModel *model = [[TGMediaPickerGalleryModel alloc] initWithContext:windowContext items:galleryItems focusItem:focusItem selectionContext:_items.count > 1 ? selectionContext : nil editingContext:editingContext hasCaptions:self.allowCaptions allowCaptionEntities:self.allowCaptionEntities hasTimer:self.hasTimer onlyCrop:_intent == TGCameraControllerPassportIntent || _intent == TGCameraControllerPassportIdIntent || _intent == TGCameraControllerPassportMultipleIntent inhibitDocumentCaptions:self.inhibitDocumentCaptions hasSelectionPanel:true hasCamera:hasCamera recipientName:self.recipientName];
        model.inhibitMute = self.inhibitMute;
        model.controller = galleryController;
        model.stickersContext = self.stickersContext;
        
        __weak TGModernGalleryController *weakGalleryController = galleryController;
        __weak TGMediaPickerGalleryModel *weakModel = model;
        
        model.interfaceView.doneLongPressed = ^(TGMediaPickerGalleryItem *item) {
            __strong TGCameraController *strongSelf = weakSelf;
            __strong TGMediaPickerGalleryModel *strongModel = weakModel;
            if (strongSelf == nil || !(strongSelf.hasSilentPosting || strongSelf.hasSchedule) || strongSelf->_shortcut)
                return;
            
            if (iosMajorVersion() >= 10) {
                UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
                [generator impactOccurred];
            }
            
            bool effectiveHasSchedule = strongSelf.hasSchedule;
            for (id item in strongModel.selectionContext.selectedItems)
            {
                if ([item isKindOfClass:[TGMediaAsset class]])
                {
                    if ([[strongSelf->_editingContext timerForItem:item] integerValue] > 0)
                    {
                        effectiveHasSchedule = false;
                        break;
                    }
                }
            }
            
            TGMediaPickerSendActionSheetController *controller = [[TGMediaPickerSendActionSheetController alloc] initWithContext:strongSelf->_context isDark:true sendButtonFrame:strongModel.interfaceView.doneButtonFrame canSendSilently:strongSelf->_hasSilentPosting canSchedule:effectiveHasSchedule reminder:strongSelf->_reminder hasTimer:strongSelf->_hasTimer];
            controller.send = ^{
                __strong TGCameraController *strongSelf = weakSelf;
                __strong TGMediaPickerGalleryModel *strongModel = weakModel;
    
                if (strongSelf == nil || strongModel == nil)
                    return;
                
                __strong TGModernGalleryController *strongController = weakGalleryController;
                if (strongController == nil)
                    return;
                
                if ([item isKindOfClass:[TGMediaPickerGalleryVideoItem class]])
                {
                    TGMediaPickerGalleryVideoItemView *itemView = (TGMediaPickerGalleryVideoItemView *)[strongController itemViewForItem:item];
                    [itemView stop];
                    [itemView setPlayButtonHidden:true animated:true];
                }
                
                if (strongSelf->_selectionContext.allowGrouping)
                    [[NSUserDefaults standardUserDefaults] setObject:@(!strongSelf->_selectionContext.grouping) forKey:@"TG_mediaGroupingDisabled_v0"];
                
                if (strongSelf.finishedWithResults != nil)
                    strongSelf.finishedWithResults(strongController, strongSelf->_selectionContext, strongSelf->_editingContext, item.asset, false, 0);
                
                [strongSelf _dismissTransitionForResultController:strongController];
            };
            controller.sendSilently = ^{
                __strong TGCameraController *strongSelf = weakSelf;
                __strong TGMediaPickerGalleryModel *strongModel = weakModel;
                
                if (strongSelf == nil || strongModel == nil)
                    return;
                
                __strong TGModernGalleryController *strongController = weakGalleryController;
                if (strongController == nil)
                    return;
                
                if ([item isKindOfClass:[TGMediaPickerGalleryVideoItem class]])
                {
                    TGMediaPickerGalleryVideoItemView *itemView = (TGMediaPickerGalleryVideoItemView *)[strongController itemViewForItem:item];
                    [itemView stop];
                    [itemView setPlayButtonHidden:true animated:true];
                }
                
                if (strongSelf->_selectionContext.allowGrouping)
                    [[NSUserDefaults standardUserDefaults] setObject:@(!strongSelf->_selectionContext.grouping) forKey:@"TG_mediaGroupingDisabled_v0"];
                
                if (strongSelf.finishedWithResults != nil)
                    strongSelf.finishedWithResults(strongController, strongSelf->_selectionContext, strongSelf->_editingContext, item.asset, true, 0);
                
                [strongSelf _dismissTransitionForResultController:strongController];
            };
            controller.schedule = ^{
                __strong TGCameraController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                strongSelf.presentScheduleController(true, ^(int32_t time) {
                    __strong TGCameraController *strongSelf = weakSelf;
                    __strong TGMediaPickerGalleryModel *strongModel = weakModel;
                    
                    if (strongSelf == nil || strongModel == nil)
                        return;
                    
                    __strong TGModernGalleryController *strongController = weakGalleryController;
                    if (strongController == nil)
                        return;
                    
                    if ([item isKindOfClass:[TGMediaPickerGalleryVideoItem class]])
                    {
                        TGMediaPickerGalleryVideoItemView *itemView = (TGMediaPickerGalleryVideoItemView *)[strongController itemViewForItem:item];
                        [itemView stop];
                        [itemView setPlayButtonHidden:true animated:true];
                    }
                    
                    if (strongSelf->_selectionContext.allowGrouping)
                        [[NSUserDefaults standardUserDefaults] setObject:@(!strongSelf->_selectionContext.grouping) forKey:@"TG_mediaGroupingDisabled_v0"];
                    
                    if (strongSelf.finishedWithResults != nil)
                        strongSelf.finishedWithResults(strongController, strongSelf->_selectionContext, strongSelf->_editingContext, item.asset, false, time);
                    
                    [strongSelf _dismissTransitionForResultController:strongController];
                });
            };
            controller.sendWithTimer = ^{
                __strong TGCameraController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                strongSelf.presentTimerController(^(int32_t time) {
                    __strong TGCameraController *strongSelf = weakSelf;
                    __strong TGMediaPickerGalleryModel *strongModel = weakModel;
                    
                    if (strongSelf == nil || strongModel == nil)
                        return;
                    
                    __strong TGModernGalleryController *strongController = weakGalleryController;
                    if (strongController == nil)
                        return;
                    
                    if ([item isKindOfClass:[TGMediaPickerGalleryVideoItem class]])
                    {
                        TGMediaPickerGalleryVideoItemView *itemView = (TGMediaPickerGalleryVideoItemView *)[strongController itemViewForItem:item];
                        [itemView stop];
                        [itemView setPlayButtonHidden:true animated:true];
                    }
                    
                    TGMediaEditingContext *editingContext = strongSelf->_editingContext;
                    NSMutableArray *items = [strongSelf->_selectionContext.selectedItems mutableCopy];
                    [items addObject:item.asset];
                    
                    for (id<TGMediaEditableItem> editableItem in items) {
                        [editingContext setTimer:@(time) forItem:editableItem];
                    }
                    
                    if (strongSelf.finishedWithResults != nil)
                        strongSelf.finishedWithResults(strongController, strongSelf->_selectionContext, strongSelf->_editingContext, item.asset, false, 0);
                    
                    [strongSelf _dismissTransitionForResultController:strongController];
                });
            };
            
            id<LegacyComponentsOverlayWindowManager> windowManager = nil;
            id<LegacyComponentsContext> windowContext = nil;
            windowManager = [strongSelf->_context makeOverlayWindowManager];
            windowContext = [windowManager context];
            
            TGOverlayControllerWindow *controllerWindow = [[TGOverlayControllerWindow alloc] initWithManager:windowManager parentController:strongSelf contentController:(TGOverlayController *)controller];
            controllerWindow.hidden = false;
        };
        
        model.willFinishEditingItem = ^(id<TGMediaEditableItem> editableItem, id<TGMediaEditAdjustments> adjustments, id representation, bool hasChanges)
        {
            __strong TGCameraController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;

            if (hasChanges)
            {
                [editingContext setAdjustments:adjustments forItem:editableItem];
                [editingContext setTemporaryRep:representation forItem:editableItem];
            }
        };

        model.didFinishEditingItem = ^(id<TGMediaEditableItem> editableItem, __unused id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, UIImage *thumbnailImage)
        {
            [editingContext setImage:resultImage thumbnailImage:thumbnailImage forItem:editableItem synchronous:false];
        };

        model.saveItemCaption = ^(id<TGMediaEditableItem> editableItem, NSAttributedString *caption)
        {
            __strong TGCameraController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf->_editingContext setCaption:caption forItem:editableItem];
        };

        model.interfaceView.hasSwipeGesture = false;
        galleryController.model = model;

        if (_items.count > 1)
            [model.interfaceView updateSelectionInterface:selectionContext.count counterVisible:(selectionContext.count > 0) animated:false];
        else
            [model.interfaceView updateSelectionInterface:1 counterVisible:false animated:false];
        model.interfaceView.thumbnailSignalForItem = ^SSignal *(id item)
        {
            __strong TGCameraController *strongSelf = weakSelf;
            if (strongSelf != nil)
                return [strongSelf _signalForItem:item];
            return nil;
        };
        model.interfaceView.donePressed = ^(TGMediaPickerGalleryItem *item)
        {
            __strong TGCameraController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;

            TGMediaPickerGalleryModel *strongModel = weakModel;
            if (strongModel == nil)
                return;

            __strong TGModernGalleryController *strongController = weakGalleryController;
            if (strongController == nil)
                return;

            if ([item isKindOfClass:[TGMediaPickerGalleryVideoItem class]])
            {
                TGMediaPickerGalleryVideoItemView *itemView = (TGMediaPickerGalleryVideoItemView *)[strongController itemViewForItem:item];
                [itemView stop];
                [itemView setPlayButtonHidden:true animated:true];
            }
            
            if (strongSelf->_selectionContext.allowGrouping)
                [[NSUserDefaults standardUserDefaults] setObject:@(!strongSelf->_selectionContext.grouping) forKey:@"TG_mediaGroupingDisabled_v0"];

            if (strongSelf.finishedWithResults != nil)
                strongSelf.finishedWithResults(strongController, strongSelf->_selectionContext, strongSelf->_editingContext, item.asset, false, 0);
            
            if (strongSelf->_shortcut)
                return;

            [strongSelf _dismissTransitionForResultController:strongController];
        };

        CGSize snapshotSize = TGScaleToFill(CGSizeMake(480, 640), CGSizeMake(self.view.frame.size.width, self.view.frame.size.width));
        UIView *snapshotView = [_previewView snapshotViewAfterScreenUpdates:false];
        snapshotView.contentMode = UIViewContentModeScaleAspectFill;
        snapshotView.frame = CGRectMake(_previewView.center.x - snapshotSize.width / 2, _previewView.center.y - snapshotSize.height / 2, snapshotSize.width, snapshotSize.height);
        snapshotView.hidden = true;
        [_previewView.superview insertSubview:snapshotView aboveSubview:_previewView];

        galleryController.beginTransitionIn = ^UIView *(__unused TGMediaPickerGalleryItem *item, __unused TGModernGalleryItemView *itemView)
        {
            __strong TGCameraController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                TGModernGalleryController *strongGalleryController = weakGalleryController;
                strongGalleryController.view.alpha = 0.0f;
                [UIView animateWithDuration:0.3f animations:^
                 {
                     strongGalleryController.view.alpha = 1.0f;
                     strongSelf->_interfaceView.alpha = 0.0f;
                 }];
                return snapshotView;
            }
            return nil;
        };

        galleryController.finishedTransitionIn = ^(__unused TGMediaPickerGalleryItem *item, __unused TGModernGalleryItemView *itemView)
        {
            __strong TGCameraController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            TGMediaPickerGalleryModel *strongModel = weakModel;
            if (strongModel == nil)
                return;

            [strongModel.interfaceView setSelectedItemsModel:strongModel.selectedItemsModel];
            
            [strongSelf->_camera stopCaptureForPause:true completion:nil];

            snapshotView.hidden = true;

            if (completion != nil)
                completion();
        };

        galleryController.beginTransitionOut = ^UIView *(__unused TGMediaPickerGalleryItem *item, __unused TGModernGalleryItemView *itemView)
        {
            __strong TGCameraController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                TGMediaPickerGalleryModel *strongModel = weakModel;
                if (strongModel == nil)
                    return nil;
                
                [[[LegacyComponentsGlobals provider] applicationInstance] setIdleTimerDisabled:true];

                if (strongSelf->_camera.cameraMode == PGCameraModeVideo)
                    [strongSelf->_interfaceView setRecordingVideo:false animated:false];
            
                strongSelf->_buttonHandler.enabled = true;
                [strongSelf->_buttonHandler ignoreEventsFor:2.0f andDisable:false];

                strongSelf->_camera.disabled = false;
                [strongSelf->_camera startCaptureForResume:true completion:nil];

                [UIView animateWithDuration:0.3f delay:0.1f options:UIViewAnimationOptionCurveLinear animations:^
                {
                    strongSelf->_interfaceView.alpha = 1.0f;
                } completion:nil];
                
                if (!strongModel.interfaceView.capturing)
                {
                    [strongSelf->_items removeAllObjects];
                    [strongSelf->_interfaceView setResults:nil];
                    [strongSelf->_selectionContext clear];
                    [strongSelf->_selectedItemsModel clear];
                    
                    [strongSelf->_interfaceView updateSelectionInterface:0 counterVisible:false animated:false];
                }

                return snapshotView;
            }
            return nil;
        };
        
        void (^dismissGalleryImpl)() = nil;

        galleryController.completedTransitionOut = ^
        {
            [snapshotView removeFromSuperview];
            
            TGModernGalleryController *strongGalleryController = weakGalleryController;
            if (strongGalleryController == nil) {
                return;
            }
            if (strongGalleryController.customDismissSelf) {
                strongGalleryController.customDismissSelf();
            }
        };

        TGOverlayController *contentController = galleryController;
        if (_shortcut)
        {
            contentController = [[TGOverlayController alloc] initWithContext:_context];

            TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[galleryController]];
            galleryController.navigationBarShouldBeHidden = true;

            [contentController addChildViewController:navigationController];
            [contentController.view addSubview:navigationController.view];
        }
        
        if (_customPresentOverlayController) {
            dismissGalleryImpl = ^{
                TGModernGalleryController *strongGalleryController = weakGalleryController;
                if (strongGalleryController == nil) {
                    return;
                }
                if (strongGalleryController.customDismissSelf) {
                    strongGalleryController.customDismissSelf();
                }
            };
        } else {
            dismissGalleryImpl = ^{
                TGModernGalleryController *strongGalleryController = weakGalleryController;
                if (strongGalleryController != nil && strongGalleryController.overlayWindow == nil)
                {
                    TGNavigationController *navigationController = (TGNavigationController *)strongGalleryController.navigationController;
                    TGOverlayControllerWindow *window = (TGOverlayControllerWindow *)navigationController.view.window;
                    if ([window isKindOfClass:[TGOverlayControllerWindow class]])
                        [window dismiss];
                }
            };
        }
        galleryController.view.clipsToBounds = true;
        return contentController;
    };
    
    if (_customPresentOverlayController) {
        _customPresentOverlayController(^TGOverlayController * (id<LegacyComponentsContext> context) {
            return (TGOverlayController *)begin(context);
        });
    } else {
        id<LegacyComponentsOverlayWindowManager> windowManager = nil;
        id<LegacyComponentsContext> windowContext = nil;
        windowManager = [_context makeOverlayWindowManager];
        windowContext = [windowManager context];
        
        UIViewController *controller = begin(windowContext);
        
        TGOverlayControllerWindow *controllerWindow = [[TGOverlayControllerWindow alloc] initWithManager:windowManager parentController:self contentController:(TGOverlayController *)controller];
        controllerWindow.hidden = false;
        controllerWindow.windowLevel = self.view.window.windowLevel + 0.0001f;
    }
}

- (SSignal *)_signalForItem:(id<TGMediaEditableItem>)item
{
    SSignal *assetSignal = [item thumbnailImageSignal];
    if (_editingContext == nil)
        return assetSignal;
    
    return [[_editingContext thumbnailImageSignalForItem:item] mapToSignal:^SSignal *(id result)
    {
        if (result != nil)
            return [SSignal single:result];
        else
            return assetSignal;
    }];
}

#pragma mark - Legacy Photo Result

- (void)presentPhotoResultControllerWithImage:(id<TGMediaEditableItem>)input metadata:(PGCameraShotMetadata *)metadata completion:(void (^)(void))completion
{
    [[[LegacyComponentsGlobals provider] applicationInstance] setIdleTimerDisabled:false];
 
    if (input == nil || ([input isKindOfClass:[UIImage class]] && ((UIImage *)input).size.width < FLT_EPSILON))
    {
        [self beginTransitionOutWithVelocity:0.0f];
        return;
    }
 
    UIImage *image = nil;
    if ([input isKindOfClass:[UIImage class]]) {
        image = (UIImage *)input;
    } else if ([input isKindOfClass:[TGCameraCapturedVideo class]]) {
        AVAsset *asset = ((TGCameraCapturedVideo *)input).immediateAVAsset;
        
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = true;
        generator.maximumSize = CGSizeMake(640.0f, 640.0f);
        CGImageRef imageRef = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:NULL];
        image = [[UIImage alloc] initWithCGImage:imageRef];
        CGImageRelease(imageRef);
    }
    
    id<LegacyComponentsOverlayWindowManager> windowManager = nil;
    id<LegacyComponentsContext> windowContext = nil;
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        windowManager = [_context makeOverlayWindowManager];
        windowContext = [windowManager context];
    } else {
        windowContext = _context;
    }
    
    __weak TGCameraController *weakSelf = self;
    TGOverlayController *overlayController = nil;
    
    _focusControl.ignoreAutofocusing = true;
    
    TGPhotoEditorControllerIntent intent = TGPhotoEditorControllerAvatarIntent;
    if (_intent == TGCameraControllerSignupAvatarIntent) {
        intent = TGPhotoEditorControllerSignupAvatarIntent;
    }
    TGPhotoEditorController *controller = [[TGPhotoEditorController alloc] initWithContext:windowContext item:input intent:(TGPhotoEditorControllerFromCameraIntent | intent) adjustments:nil caption:nil screenImage:image availableTabs:[TGPhotoEditorController defaultTabsForAvatarIntent] selectedTab:TGPhotoEditorCropTab];
    controller.stickersContext = _stickersContext;
    __weak TGPhotoEditorController *weakController = controller;
    controller.beginTransitionIn = ^UIView *(CGRect *referenceFrame, __unused UIView **parentView)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return nil;
        
        strongSelf->_previewView.hidden = true;
        *referenceFrame = strongSelf->_previewView.frame;
        
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:strongSelf->_previewView.frame];
        imageView.image = image;
        
        return imageView;
    };
    
    controller.beginTransitionOut = ^UIView *(CGRect *referenceFrame, __unused UIView **parentView)
    {
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return nil;
        
        CGRect startFrame = CGRectZero;
        if (referenceFrame != NULL)
        {
            startFrame = *referenceFrame;
            *referenceFrame = strongSelf->_previewView.frame;
        }
        
        [strongSelf transitionBackFromResultControllerWithReferenceFrame:startFrame];
        
        return strongSelf->_previewView;
    };
    
    controller.didFinishEditing = ^(PGPhotoEditorValues *editorValues, UIImage *resultImage, __unused UIImage *thumbnailImage, bool hasChanges)
    {
        if (!hasChanges)
            return;
        
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        TGDispatchOnMainThread(^
        {
            if (editorValues.paintingData.hasAnimation) {
                TGVideoEditAdjustments *adjustments = [TGVideoEditAdjustments editAdjustmentsWithPhotoEditorValues:(PGPhotoEditorValues *)editorValues preset:TGMediaVideoConversionPresetProfileVeryHigh];

                NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"gifvideo_%x.jpg", (int)arc4random()]];
                NSData *data = UIImageJPEGRepresentation(resultImage, 0.8);
                [data writeToFile:filePath atomically:true];
                
                UIImage *previewImage = resultImage;
                if ([adjustments cropAppliedForAvatar:false] || adjustments.hasPainting || adjustments.toolsApplied)
                {
                    UIImage *paintingImage = adjustments.paintingData.stillImage;
                    if (paintingImage == nil) {
                        paintingImage = adjustments.paintingData.image;
                    }
                    UIImage *croppedPaintingImage = TGPhotoEditorPaintingCrop(paintingImage, adjustments.cropOrientation, adjustments.cropRotation, adjustments.cropRect, adjustments.cropMirrored, resultImage.size, adjustments.originalSize, true, true, false);
                    UIImage *thumbnailImage = TGPhotoEditorVideoExtCrop(resultImage, croppedPaintingImage, adjustments.cropOrientation, adjustments.cropRotation, adjustments.cropRect, adjustments.cropMirrored, TGScaleToFill(resultImage.size, CGSizeMake(800, 800)), adjustments.originalSize, true, true, true, true);
                    if (thumbnailImage != nil) {
                        previewImage = thumbnailImage;
                    }
                }
                
                if (strongSelf.finishedWithVideo != nil)
                    strongSelf.finishedWithVideo(nil, [NSURL fileURLWithPath:filePath], previewImage, 0, CGSizeZero, adjustments, nil, nil, nil);
            } else {
                if (strongSelf.finishedWithPhoto != nil)
                    strongSelf.finishedWithPhoto(nil, resultImage, nil, nil, nil);
            }
                        
            if (strongSelf.shouldStoreCapturedAssets && [input isKindOfClass:[UIImage class]])
            {
                [strongSelf _savePhotoToCameraRollWithOriginalImage:image editedImage:[editorValues toolsApplied] ? resultImage : nil];
            }
            
            __strong TGPhotoEditorController *strongController = weakController;
            if (strongController != nil)
            {
                [strongController updateStatusBarAppearanceForDismiss];
                [strongSelf _dismissTransitionForResultController:(TGOverlayController *)strongController];
            }
        });
    };
    
    controller.didFinishEditingVideo = ^(AVAsset *asset, id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, UIImage *thumbnailImage, bool hasChanges) {
        if (!hasChanges)
            return;
        
        __strong TGCameraController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        TGDispatchOnMainThread(^
        {
            if (strongSelf.finishedWithVideo != nil)
                strongSelf.finishedWithVideo(nil, [(AVURLAsset *)asset URL], resultImage, 0, CGSizeZero, adjustments, nil, nil, nil);
        
            __strong TGPhotoEditorController *strongController = weakController;
            if (strongController != nil)
            {
                [strongController updateStatusBarAppearanceForDismiss];
                [strongSelf _dismissTransitionForResultController:(TGOverlayController *)strongController];
            }
        });
    };
    
    controller.requestThumbnailImage = ^(id<TGMediaEditableItem> editableItem)
    {
        return [editableItem thumbnailImageSignal];
    };
    
    controller.requestOriginalScreenSizeImage = ^(id<TGMediaEditableItem> editableItem, NSTimeInterval position)
    {
        return [editableItem screenImageSignal:position];
    };
    
    controller.requestOriginalFullSizeImage = ^(id<TGMediaEditableItem> editableItem, NSTimeInterval position)
    {
        if (editableItem.isVideo) {
            if ([editableItem isKindOfClass:[TGMediaAsset class]]) {
                return [TGMediaAssetImageSignals avAssetForVideoAsset:(TGMediaAsset *)editableItem allowNetworkAccess:true];
            } else if ([editableItem isKindOfClass:[TGCameraCapturedVideo class]]) {
                return ((TGCameraCapturedVideo *)editableItem).avAsset;
            } else {
                return [editableItem originalImageSignal:position];
            }
        } else {
            return [editableItem originalImageSignal:position];
        }
    };
    
    overlayController = (TGOverlayController *)controller;
            
    if (windowManager != nil)
    {
        TGOverlayController *contentController = overlayController;
        if (_shortcut)
        {
            contentController = [[TGOverlayController alloc] init];
            
            TGNavigationController *navigationController = [TGNavigationController navigationControllerWithControllers:@[overlayController]];
            overlayController.navigationBarShouldBeHidden = true;
            [contentController addChildViewController:navigationController];
            [contentController.view addSubview:navigationController.view];
        }
        
        TGOverlayControllerWindow *controllerWindow = [[TGOverlayControllerWindow alloc] initWithManager:windowManager parentController:self contentController:contentController];
        controllerWindow.windowLevel = self.view.window.windowLevel + 0.0001f;
        controllerWindow.hidden = false;
    }
    else
    {
        [self addChildViewController:overlayController];
        [self.view addSubview:overlayController.view];
    }
    
    if (completion != nil)
        completion();
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _interfaceView.alpha = 0.0f;
    }];
}

- (void)_savePhotoToCameraRollWithOriginalImage:(UIImage *)originalImage editedImage:(UIImage *)editedImage
{
    if (!_saveEditedPhotos || originalImage == nil)
        return;
    
    SSignal *savePhotoSignal = _saveCapturedMedia ? [[TGMediaAssetsLibrary sharedLibrary] saveAssetWithImage:originalImage] : [SSignal complete];
    if (_saveEditedPhotos && editedImage != nil)
        savePhotoSignal = [savePhotoSignal then:[[TGMediaAssetsLibrary sharedLibrary] saveAssetWithImage:editedImage]];
    
    [savePhotoSignal startWithNext:nil];
}

- (void)_saveVideoToCameraRollWithURL:(NSURL *)url completion:(void (^)(void))completion
{
    if (!_saveCapturedMedia)
        return;
    
    [[[TGMediaAssetsLibrary sharedLibrary] saveAssetWithVideoAtUrl:url] startWithNext:nil error:^(__unused NSError *error)
    {
        if (completion != nil)
            completion();
    } completed:completion];
}

- (CGRect)transitionBackFromResultControllerWithReferenceFrame:(CGRect)referenceFrame
{
    _camera.disabled = false;
    
    _buttonHandler.enabled = true;
    [_buttonHandler ignoreEventsFor:2.0f andDisable:false];
    _previewView.hidden = false;
    
    _focusControl.ignoreAutofocusing = false;
    
    CGRect targetFrame = _previewView.frame;

    _previewView.frame = referenceFrame;
    POPSpringAnimation *animation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
    animation.fromValue = [NSValue valueWithCGRect:referenceFrame];
    animation.toValue = [NSValue valueWithCGRect:targetFrame];
    [_previewView pop_addAnimation:animation forKey:@"frame"];
    
    [UIView animateWithDuration:0.3f delay:0.1f options:UIViewAnimationOptionCurveLinear animations:^
    {
        _interfaceView.alpha = 1.0f;
        _cornersView.alpha = 1.0;
    } completion:nil];
    
    _interfaceView.previewViewFrame = _previewView.frame;
    
    return targetFrame;
}

#pragma mark - Transition

- (void)beginTransitionInFromRect:(CGRect)rect
{
    [_autorotationCorrectionView insertSubview:_previewView aboveSubview:_backgroundView];
    
    _previewView.frame = rect;
    
    _backgroundView.alpha = 0.0f;
    _interfaceView.alpha = 0.0f;
    _cornersView.alpha = 0.0;
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _backgroundView.alpha = 1.0f;
        _interfaceView.alpha = 1.0f;
        _cornersView.alpha = 1.0;
    }];
    
    CGRect fromFrame = rect;
    CGRect toFrame = [TGCameraController _cameraPreviewFrameForScreenSize:TGScreenSize() mode:_camera.cameraMode];

    if (!CGRectEqualToRect(fromFrame, CGRectZero))
    {
        __weak TGCameraController *weakSelf = self;
        POPSpringAnimation *frameAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
        frameAnimation.fromValue = [NSValue valueWithCGRect:fromFrame];
        frameAnimation.toValue = [NSValue valueWithCGRect:toFrame];
        frameAnimation.springSpeed = 20;
        frameAnimation.springBounciness = 1;
        frameAnimation.completionBlock = ^(POPAnimation *anim, BOOL finished) {
            __strong TGCameraController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf.finishedTransitionIn != NULL) {
                ;strongSelf.finishedTransitionIn();
            }
        };
        [_previewView pop_addAnimation:frameAnimation forKey:@"frame"];
        
        POPSpringAnimation *cornersFrameAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
        cornersFrameAnimation.fromValue = [NSValue valueWithCGRect:fromFrame];
        cornersFrameAnimation.toValue = [NSValue valueWithCGRect:toFrame];
        cornersFrameAnimation.springSpeed = 20;
        cornersFrameAnimation.springBounciness = 1;
        [_cornersView pop_addAnimation:cornersFrameAnimation forKey:@"frame"];
    }
    else
    {
        _previewView.frame = toFrame;
        _cornersView.frame = toFrame;
    }
    
    _interfaceView.previewViewFrame = toFrame;
}

+ (void)generateStartImageWithImage:(UIImage *)frameImage {
    CGFloat minSize = MIN(frameImage.size.width, frameImage.size.height);
    UIImage *image = TGPhotoEditorCrop(frameImage, nil, UIImageOrientationUp, 0.0f, CGRectMake((frameImage.size.width - minSize) / 2.0f, (frameImage.size.height - minSize) / 2.0f, minSize, minSize), false, CGSizeMake(240.0f, 240.0f), frameImage.size, true);
    UIImage *startImage = TGSecretBlurredAttachmentImage(image, image.size, NULL, false, 0);
    TGDispatchOnMainThread(^{
        [TGCameraController saveStartImage:startImage];
    });
}

- (void)beginTransitionOutWithVelocity:(CGFloat)velocity
{
    _dismissing = true;
    self.view.userInteractionEnabled = false;
    
    
    _focusControl.active = false;
    _rectangleView.hidden = true;
    
    [self setInterfaceHidden:true animated:true];
    
    [UIView animateWithDuration:0.25f animations:^
    {
        _backgroundView.alpha = 0.0f;
        _cornersView.alpha = 0.0;
    }];
    
    CGRect referenceFrame = CGRectZero;
    if (self.beginTransitionOut != nil)
        referenceFrame = self.beginTransitionOut();
    
    __weak TGCameraController *weakSelf = self;
    [_camera captureNextFrameCompletion:^(UIImage *frameImage) {
        [[SQueue concurrentDefaultQueue] dispatch:^{
            [TGCameraController generateStartImageWithImage:frameImage];
        }];
    }];
    if (_standalone)
    {
        [self simpleTransitionOutWithVelocity:velocity completion:^
        {
            __strong TGCameraController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf.finishedTransitionOut != nil)
                strongSelf.finishedTransitionOut();
            
            [strongSelf dismiss];
        }];
        return;
    }

    bool resetNeeded = _camera.isResetNeeded;
    if (resetNeeded)
        [_previewView beginResetTransitionAnimated:true];

    [_camera resetSynchronous:false completion:^
    {
        TGDispatchOnMainThread(^
        {
            if (resetNeeded)
                [_previewView endResetTransitionAnimated:true];
        });
    }];
    
    [_previewView.layer removeAllAnimations];
    
    if (!CGRectIsEmpty(referenceFrame))
    {
        POPSpringAnimation *frameAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
        frameAnimation.fromValue = [NSValue valueWithCGRect:_previewView.frame];
        frameAnimation.toValue = [NSValue valueWithCGRect:referenceFrame];
        frameAnimation.springSpeed = 20;
        frameAnimation.springBounciness = 1;
        frameAnimation.completionBlock = ^(__unused POPAnimation *animation, __unused BOOL finished)
        {
            __strong TGCameraController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;

            if (strongSelf.finishedTransitionOut != nil)
                strongSelf.finishedTransitionOut();

            [strongSelf dismiss];
        };
        [_previewView pop_addAnimation:frameAnimation forKey:@"frame"];
        
        POPSpringAnimation *cornersAnimation = [POPSpringAnimation animationWithPropertyNamed:kPOPViewFrame];
        cornersAnimation.fromValue = [NSValue valueWithCGRect:_cornersView.frame];
        cornersAnimation.toValue = [NSValue valueWithCGRect:referenceFrame];
        cornersAnimation.springSpeed = 20;
        cornersAnimation.springBounciness = 1;
        [_cornersView pop_addAnimation:cornersAnimation forKey:@"frame"];
    }
    else
    {
        if (self.finishedTransitionOut != nil)
            self.finishedTransitionOut();
        
        [self dismiss];
    }
}

- (void)_dismissTransitionForResultController:(TGOverlayController *)resultController
{
    _finishedWithResult = true;
    
    //[_context setApplicationStatusBarAlpha:1.0f];
    
    self.view.hidden = true;
    
    [resultController.view.layer animatePositionFrom:resultController.view.layer.position to:CGPointMake(resultController.view.layer.position.x, resultController.view.layer.position.y + resultController.view.bounds.size.height) duration:0.3 timingFunction:kCAMediaTimingFunctionSpring removeOnCompletion:false completion:^(__unused bool finished) {
        if (resultController.customDismissSelf) {
            resultController.customDismissSelf();
        } else {
            [resultController dismiss];
        }
        [self dismiss];
    }];
}

- (void)simpleTransitionOutWithVelocity:(CGFloat)velocity completion:(void (^)())completion
{
    self.view.userInteractionEnabled = false;
    
    const CGFloat minVelocity = 4000.0f;
    if (ABS(velocity) < minVelocity)
        velocity = (velocity < 0.0f ? -1.0f : 1.0f) * minVelocity;
    CGFloat distance = (velocity < FLT_EPSILON ? -1.0f : 1.0f) * self.view.frame.size.height;
    CGRect targetFrame = (CGRect){{_previewView.frame.origin.x, distance}, _previewView.frame.size};
    
    [UIView animateWithDuration:ABS(distance / velocity) delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^
    {
        _previewView.frame = targetFrame;
        _cornersView.frame = targetFrame;
    } completion:^(__unused BOOL finished)
    {
        if (completion)
            completion();
    }];
}

- (void)_updateDismissTransitionMovementWithDistance:(CGFloat)distance animated:(bool)animated
{
    CGRect originalFrame = [TGCameraController _cameraPreviewFrameForScreenSize:TGScreenSize() mode:_camera.cameraMode];
    CGRect frame = (CGRect){ { originalFrame.origin.x, originalFrame.origin.y + distance }, originalFrame.size };
    if (animated)
    {
        [UIView animateWithDuration:0.3 animations:^
        {
            _previewView.frame = frame;
            _cornersView.frame = frame;
        }];
    }
    else
    {
        _previewView.frame = frame;
        _cornersView.frame = frame;
    }
}

- (void)_updateDismissTransitionWithProgress:(CGFloat)progress animated:(bool)animated
{
    CGFloat alpha = 1.0f - MAX(0.0f, MIN(1.0f, progress * 4.0f));
    CGFloat transitionProgress = MAX(0.0f, MIN(1.0f, progress * 2.0f));
    
    if (transitionProgress > FLT_EPSILON)
    {
        [self setInterfaceHidden:true animated:true];
        _focusControl.active = false;
    }
    else if (animated)
    {
        [self setInterfaceHidden:false animated:true];
        _focusControl.active = true;
    }
    
    if (animated)
    {
        [UIView animateWithDuration:0.3 animations:^
        {
            _backgroundView.alpha = alpha;
        }];
    }
    else
    {
        _backgroundView.alpha = alpha;
    }
}

- (void)resizePreviewViewForCameraMode:(PGCameraMode)mode
{
    CGRect frame = [TGCameraController _cameraPreviewFrameForScreenSize:TGScreenSize() mode:mode];
    _interfaceView.previewViewFrame = frame;
    [_interfaceView updateForCameraModeChangeAfterResize];
    
    [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionLayoutSubviews animations:^
    {
        _previewView.frame = frame;
        _cornersView.frame = frame;
        _overlayView.frame = frame;
    } completion:nil];
}

- (void)handleDeviceOrientationChangedTo:(UIDeviceOrientation)deviceOrientation
{
    if (_camera.isRecordingVideo || _intent == TGCameraControllerPassportIdIntent)
        return;
    
    UIInterfaceOrientation orientation = [TGCameraController _interfaceOrientationForDeviceOrientation:deviceOrientation];
    if ([_interfaceView isKindOfClass:[TGCameraMainPhoneView class]])
    {
        [_interfaceView setInterfaceOrientation:orientation animated:true];
    }
    else
    {
        if (orientation == UIInterfaceOrientationUnknown)
            return;
        
        switch (deviceOrientation)
        {
            case UIDeviceOrientationPortrait:
            {
                _photoSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionUp;
                _videoSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionDown;
            }
                break;
            case UIDeviceOrientationPortraitUpsideDown:
            {
                _photoSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionDown;
                _videoSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionUp;
            }
                break;
            case UIDeviceOrientationLandscapeLeft:
            {
                _photoSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
                _videoSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
            }
                break;
            case UIDeviceOrientationLandscapeRight:
            {
                _photoSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
                _videoSwipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
            }
                break;
                
            default:
                break;
        }
        
        [_interfaceView setInterfaceOrientation:orientation animated:false];
        CGSize referenceSize = [self referenceViewSizeForOrientation:orientation];
        if (referenceSize.width > referenceSize.height)
            referenceSize = CGSizeMake(referenceSize.height, referenceSize.width);
        
        self.view.userInteractionEnabled = false;
        [UIView animateWithDuration:0.5f delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionLayoutSubviews animations:^
        {
            _interfaceView.transform = CGAffineTransformMakeRotation(TGRotationForInterfaceOrientation(orientation));
            _interfaceView.frame = CGRectMake(0, 0, referenceSize.width, referenceSize.height);
            [_interfaceView setNeedsLayout];
        } completion:^(BOOL finished)
        {
            if (finished)
                self.view.userInteractionEnabled = true;
        }];
    }
    
    [_focusControl setInterfaceOrientation:orientation animated:true];
}

#pragma mark - Gesture Recognizers

- (CGFloat)dismissProgressForSwipeDistance:(CGFloat)distance
{
    return MAX(0.0f, MIN(1.0f, ABS(distance / 150.0f)));
}

- (void)handleSwipe:(UISwipeGestureRecognizer *)gestureRecognizer
{
    PGCameraMode newMode = PGCameraModeUndefined;
    if (gestureRecognizer == _photoSwipeGestureRecognizer)
    {
        newMode = PGCameraModePhoto;
    }
    else if (gestureRecognizer == _videoSwipeGestureRecognizer)
    {
        if (_intent == TGCameraControllerAvatarIntent) {
            newMode = PGCameraModeSquareVideo;
        } else {
            newMode = PGCameraModeVideo;
        }
    }
    
    if (newMode != PGCameraModeUndefined && _camera.cameraMode != newMode)
    {
        [_camera setCameraMode:newMode];
        [_interfaceView setCameraMode:newMode];
    }
}

- (void)handlePan:(TGModernGalleryZoomableScrollViewSwipeGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateChanged:
        {
            _dismissProgress = [self dismissProgressForSwipeDistance:[gestureRecognizer swipeDistance]];
            [self _updateDismissTransitionWithProgress:_dismissProgress animated:false];
            [self _updateDismissTransitionMovementWithDistance:[gestureRecognizer swipeDistance] animated:false];
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        {
            CGFloat swipeVelocity = [gestureRecognizer swipeVelocity];
            if (ABS(swipeVelocity) < TGCameraSwipeMinimumVelocity)
                swipeVelocity = (swipeVelocity < 0.0f ? -1.0f : 1.0f) * TGCameraSwipeMinimumVelocity;
            
            __weak TGCameraController *weakSelf = self;
            bool(^transitionOut)(CGFloat) = ^bool(CGFloat swipeVelocity)
            {
                __strong TGCameraController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return false;
                
                [strongSelf beginTransitionOutWithVelocity:swipeVelocity];
                
                return true;
            };
            
            if ((ABS(swipeVelocity) < TGCameraSwipeVelocityThreshold && ABS([gestureRecognizer swipeDistance]) < TGCameraSwipeDistanceThreshold) || !transitionOut(swipeVelocity))
            {
                _dismissProgress = 0.0f;
                [self _updateDismissTransitionWithProgress:0.0f animated:true];
                [self _updateDismissTransitionMovementWithDistance:0.0f animated:true];
            }
        }
            break;
            
        case UIGestureRecognizerStateCancelled:
        {
            _dismissProgress = 0.0f;
            [self _updateDismissTransitionWithProgress:0.0f animated:true];
            [self _updateDismissTransitionMovementWithDistance:0.0f animated:true];
        }
            break;
            
        default:
            break;
    }
}

- (void)handlePinch:(UIPinchGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateChanged:
        {
            CGFloat delta = (gestureRecognizer.scale - 1.0f) * 1.25;
            if (_camera.zoomLevel > 2.0) {
                delta *= 2.0;
            }
            CGFloat value = MAX(_camera.minZoomLevel, MIN(_camera.maxZoomLevel, _camera.zoomLevel + delta));
            
            [_camera setZoomLevel:value];
            [_interfaceView setZoomLevel:value displayNeeded:true];
            
            gestureRecognizer.scale = 1.0f;
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            [_interfaceView zoomChangingEnded];
        }
            break;
            
        default:
            break;
    }
}

- (void)handleRamp:(UIPanGestureRecognizer *)gestureRecognizer
{
    if (!_stopRecordingOnRelease) {
        [gestureRecognizer setTranslation:CGPointZero inView:self.view];
        return;
    }
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateChanged:
        {
            CGPoint translation = [gestureRecognizer translationInView:self.view];
          
            CGFloat value = 1.0;
            if (translation.y < 0.0) {
                value = MIN(8.0, value + ABS(translation.y) / 60.0);
            }
            
            [_camera setZoomLevel:value];
            [_interfaceView setZoomLevel:value displayNeeded:true];
        }
            break;
        case UIGestureRecognizerStateEnded:
        {
            [self shutterReleased];
        }
            break;
        default:
            break;
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == _panGestureRecognizer)
        return !_camera.isRecordingVideo && _items.count == 0;
    else if (gestureRecognizer == _photoSwipeGestureRecognizer || gestureRecognizer == _videoSwipeGestureRecognizer)
        return (_intent == TGCameraControllerGenericIntent || _intent == TGCameraControllerAvatarIntent) && !_camera.isRecordingVideo;
    else if (gestureRecognizer == _pinchGestureRecognizer)
        return _camera.isZoomAvailable;
    
    return true;
}

+ (CGRect)_cameraPreviewFrameForScreenSize:(CGSize)screenSize mode:(PGCameraMode)mode
{
    CGFloat widescreenWidth = MAX(screenSize.width, screenSize.height);

    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone)
    {
        switch (mode)
        {
            case PGCameraModeVideo:
            {
                if (widescreenWidth == 926.0f)
                    return CGRectMake(0, 82, screenSize.width, screenSize.height - 82 - 83);
                else if (widescreenWidth == 896.0f)
                    return CGRectMake(0, 77, screenSize.width, screenSize.height - 77 - 83);
                else if (widescreenWidth == 812.0f)
                    return CGRectMake(0, 77, screenSize.width, screenSize.height - 77 - 68);
                else
                    return CGRectMake(0, 0, screenSize.width, screenSize.height);
            }
                break;
            
            case PGCameraModeSquarePhoto:
            case PGCameraModeSquareVideo:
            case PGCameraModeSquareSwing:
            {
                CGRect rect = [self _cameraPreviewFrameForScreenSize:screenSize mode:PGCameraModePhoto];
                CGFloat topOffset = CGRectGetMidY(rect) - rect.size.width / 2;
                
                if (widescreenWidth - 480.0f < FLT_EPSILON)
                    topOffset = 40.0f;
                
                return CGRectMake(0, floor(topOffset), rect.size.width, rect.size.width);
            }
                break;
            
            default:
            {
                if (widescreenWidth == 932.0f)
                    return CGRectMake(0, 136, screenSize.width, screenSize.height - 136 - 223);
                else if (widescreenWidth == 926.0f)
                    return CGRectMake(0, 121, screenSize.width, screenSize.height - 121 - 234);
                else if (widescreenWidth == 896.0f)
                    return CGRectMake(0, 121, screenSize.width, screenSize.height - 121 - 223);
                if (widescreenWidth == 852.0f)
                    return CGRectMake(0, 136, screenSize.width, screenSize.height - 136 - 192);
                else if (widescreenWidth == 844.0f)
                    return CGRectMake(0, 77, screenSize.width, screenSize.height - 77 - 191);
                else if (widescreenWidth == 812.0f)
                    return CGRectMake(0, 121, screenSize.width, screenSize.height - 121 - 191);
                else if (widescreenWidth >= 736.0f - FLT_EPSILON)
                    return CGRectMake(0, 44, screenSize.width, screenSize.height - 50 - 136);
                else if (widescreenWidth >= 667.0f - FLT_EPSILON)
                    return CGRectMake(0, 44, screenSize.width, screenSize.height - 44 - 123);
                else if (widescreenWidth >= 568.0f - FLT_EPSILON)
                    return CGRectMake(0, 40, screenSize.width, screenSize.height - 40 - 101);
                else
                    return CGRectMake(0, 0, screenSize.width, screenSize.height);
            }
                break;
        }
    }
    else
    {
        if (mode == PGCameraModeSquarePhoto || mode == PGCameraModeSquareVideo || mode == PGCameraModeSquareSwing)
            return CGRectMake(0, (screenSize.height - screenSize.width) / 2, screenSize.width, screenSize.width);
        
        return CGRectMake(0, 0, screenSize.width, screenSize.height);
    }
}

+ (UIInterfaceOrientation)_interfaceOrientationForDeviceOrientation:(UIDeviceOrientation)orientation
{
    switch (orientation)
    {
        case UIDeviceOrientationPortrait:
            return UIInterfaceOrientationPortrait;
            
        case UIDeviceOrientationPortraitUpsideDown:
            return UIInterfaceOrientationPortraitUpsideDown;
            
        case UIDeviceOrientationLandscapeLeft:
            return UIInterfaceOrientationLandscapeRight;
            
        case UIDeviceOrientationLandscapeRight:
            return UIInterfaceOrientationLandscapeLeft;
            
        default:
            return UIInterfaceOrientationUnknown;
    }
}

+ (NSArray *)resultSignalsForSelectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext currentItem:(id<TGMediaSelectableItem>)currentItem storeAssets:(bool)storeAssets saveEditedPhotos:(bool)saveEditedPhotos descriptionGenerator:(id (^)(id, NSAttributedString *, NSString *))descriptionGenerator
{
    NSMutableArray *signals = [[NSMutableArray alloc] init];
    NSMutableArray *selectedItems = selectionContext.selectedItems != nil ? [selectionContext.selectedItems mutableCopy] : [[NSMutableArray alloc] init];
    if (selectedItems.count == 0 && currentItem != nil)
        [selectedItems addObject:currentItem];
    
    bool isScan = false;
    for (id<TGMediaEditableItem> item in selectedItems) {
        if ([item isKindOfClass:[TGCameraCapturedPhoto class]] && ((TGCameraCapturedPhoto *)item).rectangle != nil) {
            isScan = true;
            break;
        }
    }
    
    if (storeAssets && !isScan) {
        NSMutableArray *fullSizeSignals = [[NSMutableArray alloc] init];
        for (id<TGMediaEditableItem> item in selectedItems)
        {
            if ([item isKindOfClass:[TGCameraCapturedPhoto class]] && ((TGCameraCapturedPhoto *)item).rectangle != nil) {
                isScan = true;
            }
            
            if ([editingContext timerForItem:item] == nil)
            {
                SSignal *saveMedia = [SSignal defer:^SSignal *
                {
                    if ([item isKindOfClass:[TGCameraCapturedPhoto class]])
                    {
                        TGCameraCapturedPhoto *photo = (TGCameraCapturedPhoto *)item;
                        return [SSignal single:@{@"type": @"photo", @"url": photo.url}];
                    }
                    else if ([item isKindOfClass:[TGCameraCapturedVideo class]])
                    {
                        TGCameraCapturedVideo *video = (TGCameraCapturedVideo *)item;
                        return [[video avAsset] mapToSignal:^SSignal *(AVURLAsset *avAsset) {
                            return [SSignal single:@{@"type": @"video", @"url": avAsset.URL}];
                        }];
                    }
                    
                    return [SSignal complete];
                }];
                
                [fullSizeSignals addObject:saveMedia];
                
                if (saveEditedPhotos)
                {
                    [fullSizeSignals addObject:[[[editingContext fullSizeImageUrlForItem:item] filter:^bool(id result)
                    {
                        return [result isKindOfClass:[NSURL class]];
                    }] mapToSignal:^SSignal *(NSURL *url)
                    {
                        return [SSignal single:@{@"type": @"photo", @"url": url}];
                    }]];
                }
            }
        }
        
        SSignal *combinedSignal = nil;
        SQueue *queue = [SQueue concurrentDefaultQueue];
        
        for (SSignal *signal in fullSizeSignals)
        {
            if (combinedSignal == nil)
                combinedSignal = [signal startOn:queue];
            else
                combinedSignal = [[combinedSignal then:signal] startOn:queue];
        }
        
        [[[combinedSignal deliverOn:[SQueue mainQueue]] mapToSignal:^SSignal *(NSDictionary *desc)
        {
            if ([desc[@"type"] isEqualToString:@"photo"])
            {
                return [[TGMediaAssetsLibrary sharedLibrary] saveAssetWithImageAtUrl:desc[@"url"]];
            }
            else if ([desc[@"type"] isEqualToString:@"video"])
            {
                return [[TGMediaAssetsLibrary sharedLibrary] saveAssetWithVideoAtUrl:desc[@"url"]];
            }
            else
            {
                return [SSignal complete];
            }
        }] startWithNext:nil];
    }
    
    static dispatch_once_t onceToken;
    static UIImage *blankImage;
    dispatch_once(&onceToken, ^
    {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), true, 0.0f);
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, 1, 1));
        
        blankImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    
    SSignal *(^inlineThumbnailSignal)(id<TGMediaEditableItem>) = ^SSignal *(id<TGMediaEditableItem> item)
    {
        return [item thumbnailImageSignal];
    };
    
    NSNumber *groupedId;
    NSInteger i = 0;
    if (selectionContext.grouping && selectedItems.count > 1)
        groupedId = @([TGCameraController generateGroupedId]);
    
    bool hasAnyTimers = false;
    if (editingContext != nil)
    {
        for (id<TGMediaEditableItem> item in selectedItems)
        {
            if ([editingContext timerForItem:item] != nil)
            {
                hasAnyTimers = true;
                break;
            }
        }
    }
    
    for (id<TGMediaEditableItem> asset in selectedItems)
    {
        if ([asset isKindOfClass:[TGCameraCapturedPhoto class]])
        {
            NSAttributedString *caption = [editingContext captionForItem:asset];
            id<TGMediaEditAdjustments> adjustments = [editingContext adjustmentsForItem:asset];
            NSNumber *timer = [editingContext timerForItem:asset];

            SSignal *inlineSignal = [[asset screenImageSignal:0.0] map:^id(UIImage *originalImage)
            {
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                dict[@"type"] = @"editedPhoto";
                dict[@"image"] = originalImage;
                                         
                if (timer != nil)
                    dict[@"timer"] = timer;
                else if (groupedId != nil && !hasAnyTimers)
                    dict[@"groupedId"] = groupedId;
                
                if (isScan) {
                    if (caption != nil)
                        dict[@"caption"] = caption;
                    return dict;
                } else {
                    id generatedItem = descriptionGenerator(dict, caption, nil);
                    return generatedItem;
                }
            }];
            
            SSignal *assetSignal = inlineSignal;
            SSignal *imageSignal = assetSignal;
            if (editingContext != nil)
            {
                imageSignal = [[[[[editingContext imageSignalForItem:asset withUpdates:true] filter:^bool(id result)
                {
                    return result == nil || ([result isKindOfClass:[UIImage class]] && !((UIImage *)result).degraded);
                }] take:1] mapToSignal:^SSignal *(id result)
                {
                    if (result == nil)
                    {
                        return [SSignal fail:nil];
                    }
                    else if ([result isKindOfClass:[UIImage class]])
                    {
                        UIImage *image = (UIImage *)result;
                        image.edited = true;
                        return [SSignal single:image];
                    }
                    
                    return [SSignal complete];
                }] onCompletion:^
                {
                    
                }];
            } else {
                NSLog(@"Editing context is nil");
            }
            
            [signals addObject:[[[imageSignal map:^NSDictionary *(UIImage *image)
            {
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                dict[@"type"] = @"editedPhoto";
                dict[@"image"] = image;
                if (adjustments.paintingData.stickers.count > 0)
                    dict[@"stickers"] = adjustments.paintingData.stickers;
                
                bool animated = false;
                for (TGPhotoPaintEntity *entity in adjustments.paintingData.entities) {
                    if (entity.animated) {
                        animated = true;
                        break;
                    }
                }
                
                if (animated) {
                    dict[@"isAnimation"] = @true;
                    if ([adjustments isKindOfClass:[PGPhotoEditorValues class]]) {
                        dict[@"adjustments"] = [TGVideoEditAdjustments editAdjustmentsWithPhotoEditorValues:(PGPhotoEditorValues *)adjustments preset:TGMediaVideoConversionPresetAnimation];
                    } else {
                        dict[@"adjustments"] = adjustments;
                    }
                    
                    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"gifvideo_%x.jpg", (int)arc4random()]];
                    NSData *data = UIImageJPEGRepresentation(image, 0.8);
                    [data writeToFile:filePath atomically:true];
                    dict[@"url"] = [NSURL fileURLWithPath:filePath];
                    
                    if ([adjustments cropAppliedForAvatar:false] || adjustments.hasPainting || adjustments.toolsApplied)
                    {
                        UIImage *paintingImage = adjustments.paintingData.stillImage;
                        if (paintingImage == nil) {
                            paintingImage = adjustments.paintingData.image;
                        }
                        UIImage *thumbnailImage = TGPhotoEditorVideoExtCrop(image, paintingImage, adjustments.cropOrientation, adjustments.cropRotation, adjustments.cropRect, adjustments.cropMirrored, TGScaleToFill(image.size, CGSizeMake(512, 512)), adjustments.originalSize, true, true, true, false);
                        if (thumbnailImage != nil) {
                            dict[@"previewImage"] = thumbnailImage;
                        }
                    }
                }
                
                if (timer != nil)
                    dict[@"timer"] = timer;
                else if (groupedId != nil && !hasAnyTimers)
                    dict[@"groupedId"] = groupedId;
                
                if (isScan) {
                    if (caption != nil)
                        dict[@"caption"] = caption;
                    return dict;
                } else {
                    id generatedItem = descriptionGenerator(dict, caption, nil);
                    return generatedItem;
                }
            }] catch:^SSignal *(__unused id error)
            {
                return inlineSignal;
            }] onCompletion:^{
                [editingContext description];
            }]];
            
            i++;
        }
        else if ([asset isKindOfClass:[TGCameraCapturedVideo class]])
        {
            TGCameraCapturedVideo *video = (TGCameraCapturedVideo *)asset;
            
            TGVideoEditAdjustments *adjustments = (TGVideoEditAdjustments *)[editingContext adjustmentsForItem:asset];
            NSAttributedString *caption = [editingContext captionForItem:asset];
            NSNumber *timer = [editingContext timerForItem:asset];
            
            UIImage *(^cropVideoThumbnail)(UIImage *, CGSize, CGSize, bool) = ^UIImage *(UIImage *image, CGSize targetSize, CGSize sourceSize, bool resize)
            {
                if ([adjustments cropAppliedForAvatar:false] || adjustments.hasPainting || adjustments.toolsApplied)
                {
                    CGRect scaledCropRect = CGRectMake(adjustments.cropRect.origin.x * image.size.width / adjustments.originalSize.width, adjustments.cropRect.origin.y * image.size.height / adjustments.originalSize.height, adjustments.cropRect.size.width * image.size.width / adjustments.originalSize.width, adjustments.cropRect.size.height * image.size.height / adjustments.originalSize.height);
                    UIImage *paintingImage = adjustments.paintingData.stillImage;
                    if (paintingImage == nil) {
                        paintingImage = adjustments.paintingData.image;
                    }
                    if (adjustments.toolsApplied) {
                        image = [PGPhotoEditor resultImageForImage:image adjustments:adjustments];
                    }
                    return TGPhotoEditorCrop(image, paintingImage, adjustments.cropOrientation, 0, scaledCropRect, adjustments.cropMirrored, targetSize, sourceSize, resize);
                }
                
                return image;
            };
            
            CGSize imageSize = TGFillSize(asset.originalSize, CGSizeMake(512, 512));
            SSignal *trimmedVideoThumbnailSignal = [[video avAsset] mapToSignal:^SSignal *(AVURLAsset *avAsset) {
                return [[TGMediaAssetImageSignals videoThumbnailForAVAsset:avAsset size:imageSize timestamp:CMTimeMakeWithSeconds(adjustments.trimStartValue, NSEC_PER_SEC)] map:^UIImage *(UIImage *image)
                {
                    return cropVideoThumbnail(image, TGScaleToFill(asset.originalSize, CGSizeMake(512, 512)), asset.originalSize, true);
                }];
            }];
            
            SSignal *videoThumbnailSignal = [inlineThumbnailSignal(asset) map:^UIImage *(UIImage *image)
            {
                return cropVideoThumbnail(image, image.size, image.size, false);
            }];
            
            SSignal *thumbnailSignal = adjustments.trimStartValue > FLT_EPSILON ? trimmedVideoThumbnailSignal : videoThumbnailSignal;
            
            TGMediaVideoConversionPreset preset = [TGMediaVideoConverter presetFromAdjustments:adjustments];
            CGSize dimensions = [TGMediaVideoConverter dimensionsFor:asset.originalSize adjustments:adjustments preset:preset];
            NSTimeInterval duration = adjustments.trimApplied ? (adjustments.trimEndValue - adjustments.trimStartValue) : video.videoDuration;
            
            [signals addObject:[thumbnailSignal mapToSignal:^id(UIImage *image)
            {
                return [video.avAsset map:^id(AVURLAsset *avAsset) {
                    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                    dict[@"type"] = @"cameraVideo";
                    dict[@"url"] = avAsset.URL;
                    dict[@"previewImage"] = image;
                    dict[@"adjustments"] = adjustments;
                    dict[@"dimensions"] = [NSValue valueWithCGSize:dimensions];
                    dict[@"duration"] = @(duration);
                    
                    if (adjustments.paintingData.stickers.count > 0)
                        dict[@"stickers"] = adjustments.paintingData.stickers;
                    if (timer != nil)
                        dict[@"timer"] = timer;
                    else if (groupedId != nil && !hasAnyTimers)
                        dict[@"groupedId"] = groupedId;
                    
                    id generatedItem = descriptionGenerator(dict, caption, nil);
                    return generatedItem;
                }];
            }]];
            
            i++;
        }
     
        if (groupedId != nil && i == 10)
        {
            i = 0;
            groupedId = @([TGCameraController generateGroupedId]);
        }
    }
    
    if (isScan) {
        SSignal *scanSignal = [[SSignal combineSignals:signals] map:^NSDictionary *(NSArray *results) {
            NSMutableData *data = [[NSMutableData alloc] init];
            UIImage *previewImage = nil;
            UIGraphicsBeginPDFContextToData(data, CGRectZero, nil);
            for (NSDictionary *dict in results) {
                if ([dict[@"type"] isEqual:@"editedPhoto"]) {
                    UIImage *image = dict[@"image"];
                    if (previewImage == nil) {
                        previewImage = image;
                    }
                    if (image != nil) {
                        CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
                        UIGraphicsBeginPDFPageWithInfo(rect, nil);
                        CGContextRef pdfContext = UIGraphicsGetCurrentContext();
                        
                        CGContextTranslateCTM(pdfContext, 0, image.size.height);
                        CGContextScaleCTM(pdfContext, 1.0, -1.0);
                        
                        NSData *jpegData = UIImageJPEGRepresentation(image, 0.65);
                        CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef)jpegData);
                        CGImageRef cgImage = CGImageCreateWithJPEGDataProvider(dataProvider, NULL, true, kCGRenderingIntentDefault);
                        CGContextDrawImage(pdfContext, rect, cgImage);
                        
                        CGDataProviderRelease(dataProvider);
                        CGImageRelease(cgImage);
                    }
                }
            }
            UIGraphicsEndPDFContext();
            
            NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"scan_%x.pdf", (int)arc4random()]];
            [data writeToFile:filePath atomically:true];
            
            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
            dict[@"type"] = @"file";
            dict[@"previewImage"] = previewImage;
            dict[@"tempFileUrl"] = [NSURL fileURLWithPath:filePath];
            dict[@"fileName"] = @"Document Scan.pdf";
            dict[@"mimeType"] = @"application/pdf";
            
            id generatedItem = descriptionGenerator(dict, dict[@"caption"], nil);
            return generatedItem;
        }];
        signals = [NSMutableArray arrayWithObject:scanSignal];
    }
    
    return signals;
}

+ (int64_t)generateGroupedId
{
    int64_t value;
    arc4random_buf(&value, sizeof(int64_t));
    return value;
}

#pragma mark - Start Image

static UIImage *startImage = nil;

+ (UIImage *)startImage
{
    if (startImage == nil)
        startImage = TGComponentsImageNamed (@"CameraPlaceholder.jpg");
    
    return startImage;
}

+ (void)saveStartImage:(UIImage *)image
{
    if (image == nil)
        return;
    
    startImage = image;
}

@end
