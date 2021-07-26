#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

#import <LegacyComponents/PGCameraShotMetadata.h>

typedef enum {
    PGCameraAuthorizationStatusNotDetermined,
    PGCameraAuthorizationStatusRestricted,
    PGCameraAuthorizationStatusDenied,
    PGCameraAuthorizationStatusAuthorized
} PGCameraAuthorizationStatus;

typedef enum {
    PGMicrophoneAuthorizationStatusNotDetermined,
    PGMicrophoneAuthorizationStatusRestricted,
    PGMicrophoneAuthorizationStatusDenied,
    PGMicrophoneAuthorizationStatusAuthorized
} PGMicrophoneAuthorizationStatus;

typedef enum
{
    PGCameraModeUndefined,
    PGCameraModePhoto,
    PGCameraModeVideo,
    PGCameraModeSquarePhoto,
    PGCameraModeSquareVideo,
    PGCameraModeSquareSwing,
    PGCameraModePhotoScan
} PGCameraMode;

typedef enum
{
    PGCameraFlashModeOff,
    PGCameraFlashModeOn,
    PGCameraFlashModeAuto
} PGCameraFlashMode;

typedef enum
{
    PGCameraPositionUndefined,
    PGCameraPositionRear,
    PGCameraPositionFront
} PGCameraPosition;

@class PGCameraCaptureSession;
@class PGCameraDeviceAngleSampler;
@class TGCameraPreviewView;

@interface PGCamera : NSObject

@property (readonly, nonatomic) PGCameraCaptureSession *captureSession;
@property (readonly, nonatomic) PGCameraDeviceAngleSampler *deviceAngleSampler;

@property (nonatomic, copy) void(^captureStarted)(bool resumed);
@property (nonatomic, copy) void(^captureStopped)(bool paused);

@property (nonatomic, copy) void(^beganModeChange)(PGCameraMode mode, void(^commitBlock)(void));
@property (nonatomic, copy) void(^finishedModeChange)(void);

@property (nonatomic, copy) void(^beganPositionChange)(bool targetPositionHasFlash, bool targetPositionHasZoom, void(^commitBlock)(void));
@property (nonatomic, copy) void(^finishedPositionChange)(bool targetPositionHasZoom);

@property (nonatomic, copy) void(^beganAdjustingFocus)(void);
@property (nonatomic, copy) void(^finishedAdjustingFocus)(void);

@property (nonatomic, copy) void(^flashActivityChanged)(bool flashActive);
@property (nonatomic, copy) void(^flashAvailabilityChanged)(bool flashAvailable);

@property (nonatomic, copy) void(^beganVideoRecording)(bool moment);
@property (nonatomic, copy) void(^finishedVideoRecording)(bool moment);
@property (nonatomic, copy) void(^reallyBeganVideoRecording)(bool moment);

@property (nonatomic, copy) void(^captureInterrupted)(AVCaptureSessionInterruptionReason reason);

@property (nonatomic, copy) void(^onAutoStartVideoRecording)(void);

@property (nonatomic, copy) UIInterfaceOrientation(^requestedCurrentInterfaceOrientation)(bool *mirrored);

@property (nonatomic, assign) PGCameraMode cameraMode;
@property (nonatomic, assign) PGCameraFlashMode flashMode;

@property (nonatomic, readonly) bool isZoomAvailable;
@property (nonatomic, assign) CGFloat zoomLevel;
@property (nonatomic, readonly) CGFloat minZoomLevel;
@property (nonatomic, readonly) CGFloat maxZoomLevel;

- (void)setZoomLevel:(CGFloat)zoomLevel animated:(bool)animated;

@property (nonatomic, readonly) bool hasUltrawideCamera;
@property (nonatomic, readonly) bool hasTelephotoCamera;

@property (nonatomic, assign) bool disableResultMirroring;

@property (nonatomic, assign) bool disabled;
@property (nonatomic, readonly) bool isCapturing;
@property (nonatomic, readonly) NSTimeInterval videoRecordingDuration;

@property (nonatomic, assign) bool autoStartVideoRecording;

- (instancetype)initWithMode:(PGCameraMode)mode position:(PGCameraPosition)position;

- (void)attachPreviewView:(TGCameraPreviewView *)previewView;

- (bool)supportsExposurePOI;
- (bool)supportsFocusPOI;
- (void)setFocusPoint:(CGPoint)focusPoint;

- (bool)supportsExposureTargetBias;
- (void)beginExposureTargetBiasChange;
- (void)setExposureTargetBias:(CGFloat)bias;
- (void)endExposureTargetBiasChange;

- (void)captureNextFrameCompletion:(void (^)(UIImage * image))completion;

- (void)takePhotoWithCompletion:(void (^)(UIImage *result, PGCameraShotMetadata *metadata))completion;

- (void)startVideoRecordingForMoment:(bool)moment completion:(void (^)(NSURL *, CGAffineTransform transform, CGSize dimensions, NSTimeInterval duration, bool success))completion;
- (void)stopVideoRecording;
- (bool)isRecordingVideo;

- (void)startCaptureForResume:(bool)resume completion:(void (^)(void))completion;
- (void)stopCaptureForPause:(bool)pause completion:(void (^)(void))completion;

- (bool)isResetNeeded;
- (void)resetSynchronous:(bool)synchronous completion:(void (^)(void))completion;
- (void)resetTerminal:(bool)terminal synchronous:(bool)synchronous completion:(void (^)(void))completion;

- (bool)hasFlash;
- (bool)flashActive;
- (bool)flashAvailable;

- (PGCameraPosition)togglePosition;

+ (bool)cameraAvailable;
+ (bool)hasFrontCamera;
+ (bool)hasRearCamera;

+ (PGCameraAuthorizationStatus)cameraAuthorizationStatus;
+ (PGMicrophoneAuthorizationStatus)microphoneAuthorizationStatus;

+ (bool)isPhotoCameraMode:(PGCameraMode)mode;
+ (bool)isVideoCameraMode:(PGCameraMode)mode;

@end
