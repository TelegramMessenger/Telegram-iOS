#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SSignalKit/SSignalKit.h>
#import <LegacyComponents/PGCamera.h>

@class SSignal;
@class TGModernButton;
@class TGCameraShutterButton;
@class TGCameraModeControl;
@class TGCameraFlipButton;
@class TGCameraTimeCodeView;
@class TGCameraZoomView;
@class TGCameraZoomModeView;
@class TGCameraZoomWheelView;
@class TGCameraToastView;
@class TGMediaPickerPhotoCounterButton;
@class TGMediaPickerPhotoStripView;
@class TGMediaPickerGallerySelectedItemsModel;
@class TGMediaEditingContext;

@interface TGCameraCornersView : UIImageView

@end

@interface TGCameraMainView : UIView
{
    UIInterfaceOrientation _interfaceOrientation;
    
    TGCameraShutterButton *_shutterButton;
    TGCameraModeControl *_modeControl;
    
    TGCameraFlipButton *_flipButton;
    TGCameraTimeCodeView *_timecodeView;
    
    TGCameraToastView *_toastView;
    
    TGMediaPickerPhotoCounterButton *_photoCounterButton;
    TGMediaPickerPhotoStripView *_selectedPhotosView;
    
    TGCameraZoomView *_zoomView;
    TGCameraZoomModeView *_zoomModeView;
    TGCameraZoomWheelView *_zoomWheelView;
    
@public
    TGModernButton *_cancelButton;
    TGModernButton *_doneButton;
}

@property (nonatomic, copy) void(^cameraFlipped)(void);
@property (nonatomic, copy) bool(^cameraShouldLeaveMode)(PGCameraMode mode);
@property (nonatomic, copy) void(^cameraModeChanged)(PGCameraMode mode);
@property (nonatomic, copy) void(^flashModeChanged)(PGCameraFlashMode mode);

@property (nonatomic, copy) void(^focusPointChanged)(CGPoint point);
@property (nonatomic, copy) void(^expositionChanged)(CGFloat value);
@property (nonatomic, copy) void(^zoomChanged)(CGFloat level, bool animated);

@property (nonatomic, copy) void(^shutterPressed)(bool fromHardwareButton);
@property (nonatomic, copy) void(^shutterReleased)(bool fromHardwareButton);
@property (nonatomic, copy) void(^shutterPanGesture)(UIPanGestureRecognizer *gesture);
@property (nonatomic, copy) void(^cancelPressed)(void);
@property (nonatomic, copy) void(^donePressed)(void);
@property (nonatomic, copy) void(^resultPressed)(NSInteger index);
@property (nonatomic, copy) void(^itemRemoved)(NSInteger index);

@property (nonatomic, copy) NSTimeInterval(^requestedVideoRecordingDuration)(void);

@property (nonatomic, assign) CGRect previewViewFrame;

- (instancetype)initWithFrame:(CGRect)frame avatar:(bool)avatar hasUltrawideCamera:(bool)hasUltrawideCamera hasTelephotoCamera:(bool)hasTelephotoCamera;

- (void)setDocumentFrameHidden:(bool)hidden;
- (void)setCameraMode:(PGCameraMode)mode;
- (void)updateForCameraModeChangeWithPreviousMode:(PGCameraMode)previousMode;
- (void)updateForCameraModeChangeAfterResize;

- (void)setToastMessage:(NSString *)message animated:(bool)animated;

- (void)setFlashMode:(PGCameraFlashMode)mode;
- (void)setFlashActive:(bool)active;
- (void)setFlashUnavailable:(bool)unavailable;
- (void)setHasFlash:(bool)hasFlash;

- (void)setHasZoom:(bool)hasZoom;
- (void)setZoomLevel:(CGFloat)zoomLevel displayNeeded:(bool)displayNeeded;
- (void)zoomChangingEnded;

- (void)setHasModeControl:(bool)hasModeControl;

- (void)setShutterButtonHighlighted:(bool)highlighted;
- (void)setShutterButtonEnabled:(bool)enabled;

- (void)setDoneButtonHidden:(bool)hidden animated:(bool)animated;

- (void)shutterButtonPressed;
- (void)shutterButtonReleased;
- (void)shutterButtonPanGesture:(UIPanGestureRecognizer *)gestureRecognizer;
- (void)flipButtonPressed;
- (void)cancelButtonPressed;
- (void)doneButtonPressed;

- (void)setRecordingVideo:(bool)recordingVideo animated:(bool)animated;
- (void)setInterfaceHiddenForVideoRecording:(bool)hidden animated:(bool)animated;

@property (nonatomic, weak) TGMediaEditingContext *editingContext;

@property (nonatomic, copy) SSignal *(^thumbnailSignalForItem)(id item);
- (void)setResults:(NSArray *)results;
- (void)setSelectedItemsModel:(TGMediaPickerGallerySelectedItemsModel *)selectedItemsModel;
- (void)updateSelectionInterface:(NSUInteger)selectedCount counterVisible:(bool)counterVisible animated:(bool)animated;
- (void)updateSelectedPhotosView:(bool)reload incremental:(bool)incremental add:(bool)add index:(NSInteger)index;

- (UIInterfaceOrientation)interfaceOrientation;
- (void)setInterfaceOrientation:(UIInterfaceOrientation)orientation animated:(bool)animated;

- (void)photoCounterButtonPressed;

@end
