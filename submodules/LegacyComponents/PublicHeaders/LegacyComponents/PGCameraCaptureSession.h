#import <AVFoundation/AVFoundation.h>

#import <LegacyComponents/PGCamera.h>

@class PGCameraMovieWriter;
@class PGRectangleDetector;

@interface PGCameraCaptureSession : AVCaptureSession

@property (nonatomic, readonly) AVCaptureDevice *videoDevice;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
@property (nonatomic, readonly) AVCaptureStillImageOutput *imageOutput;
#pragma clang diagnostic pop
@property (nonatomic, readonly) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, readonly) AVCaptureAudioDataOutput *audioOutput;
@property (nonatomic, readonly) AVCaptureMetadataOutput *metadataOutput;
@property (nonatomic, readonly) PGCameraMovieWriter *movieWriter;
@property (nonatomic, readonly) PGRectangleDetector *rectangleDetector;

@property (nonatomic, assign) bool alwaysSetFlash;
@property (nonatomic, assign) PGCameraMode currentMode;
@property (nonatomic, assign) PGCameraFlashMode currentFlashMode;

@property (nonatomic, assign) PGCameraPosition currentCameraPosition;
@property (nonatomic, readonly) PGCameraPosition preferredCameraPosition;

@property (nonatomic, readonly) bool isZoomAvailable;
@property (nonatomic, assign) CGFloat zoomLevel;
@property (nonatomic, readonly) CGFloat minZoomLevel;
@property (nonatomic, readonly) CGFloat maxZoomLevel;

- (void)setZoomLevel:(CGFloat)zoomLevel animated:(bool)animated;

@property (nonatomic, readonly) bool hasUltrawideCamera;
@property (nonatomic, readonly) bool hasTelephotoCamera;

@property (nonatomic, readonly) CGPoint focusPoint;

@property (nonatomic, copy) void(^outputSampleBuffer)(CMSampleBufferRef sampleBuffer, AVCaptureConnection *connection);

@property (nonatomic, copy) bool(^requestPreviewIsMirrored)(void);

@property (nonatomic, copy) void(^crossfadeNeeded)(void);

@property (nonatomic, copy) void(^recognizedQRCode)(NSString *value, AVMetadataMachineReadableCodeObject *object);

@property (nonatomic, assign) bool compressVideo;

- (instancetype)initWithMode:(PGCameraMode)mode position:(PGCameraPosition)position;

- (void)performInitialConfigurationWithCompletion:(void (^)(void))completion;

- (void)setFocusPoint:(CGPoint)point focusMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode monitorSubjectAreaChange:(bool)monitorSubjectAreaChange;
- (void)setExposureTargetBias:(CGFloat)bias;

- (bool)isResetNeeded;
- (void)reset;
- (void)resetFlashMode;

- (void)startVideoRecordingWithOrientation:(AVCaptureVideoOrientation)orientation mirrored:(bool)mirrored completion:(void (^)(NSURL *outputURL, CGAffineTransform transform, CGSize dimensions, NSTimeInterval duration, bool success))completion;
- (void)stopVideoRecording;

- (void)captureNextFrameCompletion:(void (^)(UIImage * image))completion;

+ (AVCaptureDevice *)_deviceWithCameraPosition:(PGCameraPosition)position;

+ (bool)_isZoomAvailableForDevice:(AVCaptureDevice *)device;

@end
