#include "VideoCameraCapturer.h"

#import <AVFoundation/AVFoundation.h>

#import "base/RTCLogging.h"
#import "base/RTCVideoFrameBuffer.h"
#import "components/video_frame_buffer/RTCCVPixelBuffer.h"
#import "sdk/objc/native/src/objc_video_track_source.h"
#import "api/video_track_source_proxy.h"

#import "helpers/UIDevice+RTCDevice.h"

#import "helpers/AVCaptureSession+DevicePosition.h"
#import "helpers/RTCDispatcher+Private.h"
#import "base/RTCVideoFrame.h"

static const int64_t kNanosecondsPerSecond = 1000000000;

static webrtc::ObjCVideoTrackSource *getObjCVideoSource(const rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> nativeSource) {
    webrtc::VideoTrackSourceProxy *proxy_source =
    static_cast<webrtc::VideoTrackSourceProxy *>(nativeSource.get());
    return static_cast<webrtc::ObjCVideoTrackSource *>(proxy_source->internal());
}

@interface VideoCameraCapturer () <AVCaptureVideoDataOutputSampleBufferDelegate> {
    rtc::scoped_refptr<webrtc::VideoTrackSourceInterface> _source;
    
    dispatch_queue_t _frameQueue;
    AVCaptureDevice *_currentDevice;
    BOOL _hasRetriedOnFatalError;
    BOOL _isRunning;
    BOOL _willBeRunning;
    
    AVCaptureVideoDataOutput *_videoDataOutput;
    AVCaptureSession *_captureSession;
    FourCharCode _preferredOutputPixelFormat;
    FourCharCode _outputPixelFormat;
    RTCVideoRotation _rotation;
    UIDeviceOrientation _orientation;
}

@end

@implementation VideoCameraCapturer

- (instancetype)initWithSource:(rtc::scoped_refptr<webrtc::VideoTrackSourceInterface>)source {
    self = [super init];
    if (self != nil) {
        _source = source;
        if (![self setupCaptureSession:[[AVCaptureSession alloc] init]]) {
            return nil;
        }
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        _orientation = UIDeviceOrientationPortrait;
        _rotation = RTCVideoRotation_90;
        [center addObserver:self
                   selector:@selector(deviceOrientationDidChange:)
                       name:UIDeviceOrientationDidChangeNotification
                     object:nil];
        [center addObserver:self
                   selector:@selector(handleCaptureSessionInterruption:)
                       name:AVCaptureSessionWasInterruptedNotification
                     object:_captureSession];
        [center addObserver:self
                   selector:@selector(handleCaptureSessionInterruptionEnded:)
                       name:AVCaptureSessionInterruptionEndedNotification
                     object:_captureSession];
        [center addObserver:self
                   selector:@selector(handleApplicationDidBecomeActive:)
                       name:UIApplicationDidBecomeActiveNotification
                     object:[UIApplication sharedApplication]];
        [center addObserver:self
                   selector:@selector(handleCaptureSessionRuntimeError:)
                       name:AVCaptureSessionRuntimeErrorNotification
                     object:_captureSession];
        [center addObserver:self
                   selector:@selector(handleCaptureSessionDidStartRunning:)
                       name:AVCaptureSessionDidStartRunningNotification
                     object:_captureSession];
        [center addObserver:self
                   selector:@selector(handleCaptureSessionDidStopRunning:)
                       name:AVCaptureSessionDidStopRunningNotification
                     object:_captureSession];
    }
    return self;
}

- (void)dealloc {
    NSAssert(!_willBeRunning, @"Session was still running in RTCCameraVideoCapturer dealloc. Forgot to call stopCapture?");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (NSArray<AVCaptureDevice *> *)captureDevices {
    AVCaptureDeviceDiscoverySession *session = [AVCaptureDeviceDiscoverySession
                                                discoverySessionWithDeviceTypes:@[ AVCaptureDeviceTypeBuiltInWideAngleCamera ]
                                                mediaType:AVMediaTypeVideo
                                                position:AVCaptureDevicePositionUnspecified];
    return session.devices;
}

+ (NSArray<AVCaptureDeviceFormat *> *)supportedFormatsForDevice:(AVCaptureDevice *)device {
  // Support opening the device in any format. We make sure it's converted to a format we
  // can handle, if needed, in the method `-setupVideoDataOutput`.
  return device.formats;
}

- (FourCharCode)preferredOutputPixelFormat {
  return _preferredOutputPixelFormat;
}

- (void)startCaptureWithDevice:(AVCaptureDevice *)device
                        format:(AVCaptureDeviceFormat *)format
                           fps:(NSInteger)fps {
  [self startCaptureWithDevice:device format:format fps:fps completionHandler:nil];
}

- (void)stopCapture {
  [self stopCaptureWithCompletionHandler:nil];
}

- (void)startCaptureWithDevice:(AVCaptureDevice *)device
                        format:(AVCaptureDeviceFormat *)format
                           fps:(NSInteger)fps
             completionHandler:(nullable void (^)(NSError *))completionHandler {
  _willBeRunning = YES;
  [RTCDispatcher
      dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
   block:^{
      RTCLogInfo("startCaptureWithDevice %@ @ %ld fps", format, (long)fps);
      
      dispatch_async(dispatch_get_main_queue(), ^{
          [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
      });
      
      _currentDevice = device;
      
      NSError *error = nil;
      if (![_currentDevice lockForConfiguration:&error]) {
          RTCLogError(@"Failed to lock device %@. Error: %@",
                      _currentDevice,
                      error.userInfo);
          if (completionHandler) {
              completionHandler(error);
          }
          _willBeRunning = NO;
          return;
      }
      [self reconfigureCaptureSessionInput];
      [self updateOrientation];
      [self updateDeviceCaptureFormat:format fps:fps];
      [self updateVideoDataOutputPixelFormat:format];
      [_captureSession startRunning];
      [_currentDevice unlockForConfiguration];
      _isRunning = YES;
      if (completionHandler) {
          completionHandler(nil);
      }
  }];
}

- (void)stopCaptureWithCompletionHandler:(nullable void (^)(void))completionHandler {
  _willBeRunning = NO;
  [RTCDispatcher
   dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
   block:^{
      RTCLogInfo("Stop");
      _currentDevice = nil;
      for (AVCaptureDeviceInput *oldInput in [_captureSession.inputs copy]) {
          [_captureSession removeInput:oldInput];
      }
      [_captureSession stopRunning];
      
      dispatch_async(dispatch_get_main_queue(), ^{
          [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
      });
      _isRunning = NO;
      if (completionHandler) {
          completionHandler();
      }
  }];
}

#pragma mark iOS notifications

#if TARGET_OS_IPHONE
- (void)deviceOrientationDidChange:(NSNotification *)notification {
  [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
                               block:^{
                                 [self updateOrientation];
                               }];
}
#endif

#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
           fromConnection:(AVCaptureConnection *)connection {
    NSParameterAssert(captureOutput == _videoDataOutput);
    
    if (CMSampleBufferGetNumSamples(sampleBuffer) != 1 || !CMSampleBufferIsValid(sampleBuffer) ||
        !CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (pixelBuffer == nil) {
        return;
    }
    
    // Default to portrait orientation on iPhone.
    BOOL usingFrontCamera = NO;
    // Check the image's EXIF for the camera the image came from as the image could have been
    // delayed as we set alwaysDiscardsLateVideoFrames to NO.
    AVCaptureDevicePosition cameraPosition =
    [AVCaptureSession devicePositionForSampleBuffer:sampleBuffer];
    if (cameraPosition != AVCaptureDevicePositionUnspecified) {
        usingFrontCamera = AVCaptureDevicePositionFront == cameraPosition;
    } else {
        AVCaptureDeviceInput *deviceInput =
        (AVCaptureDeviceInput *)((AVCaptureInputPort *)connection.inputPorts.firstObject).input;
        usingFrontCamera = AVCaptureDevicePositionFront == deviceInput.device.position;
    }
    switch (_orientation) {
        case UIDeviceOrientationPortrait:
            _rotation = RTCVideoRotation_90;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            _rotation = RTCVideoRotation_270;
            break;
        case UIDeviceOrientationLandscapeLeft:
            _rotation = usingFrontCamera ? RTCVideoRotation_180 : RTCVideoRotation_0;
            break;
        case UIDeviceOrientationLandscapeRight:
            _rotation = usingFrontCamera ? RTCVideoRotation_0 : RTCVideoRotation_180;
            break;
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationUnknown:
            // Ignore.
            break;
    }
    
    RTCCVPixelBuffer *rtcPixelBuffer = [[RTCCVPixelBuffer alloc] initWithPixelBuffer:pixelBuffer];
    int64_t timeStampNs = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) *
    kNanosecondsPerSecond;
    RTCVideoFrame *videoFrame = [[RTCVideoFrame alloc] initWithBuffer:rtcPixelBuffer
                                                             rotation:_rotation
                                                          timeStampNs:timeStampNs];
    getObjCVideoSource(_source)->OnCapturedFrame(videoFrame);
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
    didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
         fromConnection:(AVCaptureConnection *)connection {
  NSString *droppedReason =
      (__bridge NSString *)CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_DroppedFrameReason, nil);
  RTCLogError(@"Dropped sample buffer. Reason: %@", droppedReason);
}

#pragma mark - AVCaptureSession notifications

- (void)handleCaptureSessionInterruption:(NSNotification *)notification {
    NSString *reasonString = nil;
    NSNumber *reason = notification.userInfo[AVCaptureSessionInterruptionReasonKey];
    if (reason) {
        switch (reason.intValue) {
            case AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableInBackground:
                reasonString = @"VideoDeviceNotAvailableInBackground";
                break;
            case AVCaptureSessionInterruptionReasonAudioDeviceInUseByAnotherClient:
                reasonString = @"AudioDeviceInUseByAnotherClient";
                break;
            case AVCaptureSessionInterruptionReasonVideoDeviceInUseByAnotherClient:
                reasonString = @"VideoDeviceInUseByAnotherClient";
                break;
            case AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps:
                reasonString = @"VideoDeviceNotAvailableWithMultipleForegroundApps";
                break;
        }
    }
    RTCLog(@"Capture session interrupted: %@", reasonString);
}

- (void)handleCaptureSessionInterruptionEnded:(NSNotification *)notification {
    RTCLog(@"Capture session interruption ended.");
}

- (void)handleCaptureSessionRuntimeError:(NSNotification *)notification {
    NSError *error = [notification.userInfo objectForKey:AVCaptureSessionErrorKey];
    RTCLogError(@"Capture session runtime error: %@", error);

    [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
                                 block:^{
        if (error.code == AVErrorMediaServicesWereReset) {
            [self handleNonFatalError];
        } else {
            [self handleFatalError];
        }
    }];
}

- (void)handleCaptureSessionDidStartRunning:(NSNotification *)notification {
    RTCLog(@"Capture session started.");
    
    [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
                                 block:^{
        // If we successfully restarted after an unknown error,
        // allow future retries on fatal errors.
        _hasRetriedOnFatalError = NO;
    }];
}

- (void)handleCaptureSessionDidStopRunning:(NSNotification *)notification {
  RTCLog(@"Capture session stopped.");
}

- (void)handleFatalError {
    [RTCDispatcher
     dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
     block:^{
        if (!_hasRetriedOnFatalError) {
            RTCLogWarning(@"Attempting to recover from fatal capture error.");
            [self handleNonFatalError];
            _hasRetriedOnFatalError = YES;
        } else {
            RTCLogError(@"Previous fatal error recovery failed.");
        }
    }];
}

- (void)handleNonFatalError {
    [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
                                 block:^{
        RTCLog(@"Restarting capture session after error.");
        if (_isRunning) {
            [_captureSession startRunning];
        }
    }];
}

#pragma mark - UIApplication notifications

- (void)handleApplicationDidBecomeActive:(NSNotification *)notification {
    [RTCDispatcher dispatchAsyncOnType:RTCDispatcherTypeCaptureSession
                                 block:^{
        if (_isRunning && !_captureSession.isRunning) {
            RTCLog(@"Restarting capture session on active.");
            [_captureSession startRunning];
        }
    }];
}

#pragma mark - Private

- (dispatch_queue_t)frameQueue {
    if (!_frameQueue) {
        _frameQueue =
        dispatch_queue_create("org.webrtc.cameravideocapturer.video", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_frameQueue,
                                  dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    }
    return _frameQueue;
}

- (BOOL)setupCaptureSession:(AVCaptureSession *)captureSession {
    NSAssert(_captureSession == nil, @"Setup capture session called twice.");
    _captureSession = captureSession;
    _captureSession.sessionPreset = AVCaptureSessionPresetInputPriority;
    _captureSession.usesApplicationAudioSession = NO;
    [self setupVideoDataOutput];
    // Add the output.
    if (![_captureSession canAddOutput:_videoDataOutput]) {
        RTCLogError(@"Video data output unsupported.");
        return NO;
    }
    [_captureSession addOutput:_videoDataOutput];
    
    return YES;
}

- (void)setupVideoDataOutput {
    NSAssert(_videoDataOutput == nil, @"Setup video data output called twice.");
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    // `videoDataOutput.availableVideoCVPixelFormatTypes` returns the pixel formats supported by the
    // device with the most efficient output format first. Find the first format that we support.
    NSSet<NSNumber *> *supportedPixelFormats = [RTCCVPixelBuffer supportedPixelFormats];
    NSMutableOrderedSet *availablePixelFormats =
    [NSMutableOrderedSet orderedSetWithArray:videoDataOutput.availableVideoCVPixelFormatTypes];
    [availablePixelFormats intersectSet:supportedPixelFormats];
    NSNumber *pixelFormat = availablePixelFormats.firstObject;
    NSAssert(pixelFormat, @"Output device has no supported formats.");
    
    _preferredOutputPixelFormat = [pixelFormat unsignedIntValue];
    _outputPixelFormat = _preferredOutputPixelFormat;
    videoDataOutput.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey : pixelFormat};
    videoDataOutput.alwaysDiscardsLateVideoFrames = NO;
    [videoDataOutput setSampleBufferDelegate:self queue:self.frameQueue];
    _videoDataOutput = videoDataOutput;
}

- (void)updateVideoDataOutputPixelFormat:(AVCaptureDeviceFormat *)format {
    FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(format.formatDescription);
    if (![[RTCCVPixelBuffer supportedPixelFormats] containsObject:@(mediaSubType)]) {
        mediaSubType = _preferredOutputPixelFormat;
    }
    
    if (mediaSubType != _outputPixelFormat) {
        _outputPixelFormat = mediaSubType;
        _videoDataOutput.videoSettings =
        @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : @(mediaSubType) };
    }
}

#pragma mark - Private, called inside capture queue

- (void)updateDeviceCaptureFormat:(AVCaptureDeviceFormat *)format fps:(NSInteger)fps {
    NSAssert([RTCDispatcher isOnQueueForType:RTCDispatcherTypeCaptureSession],
             @"updateDeviceCaptureFormat must be called on the capture queue.");
    @try {
        _currentDevice.activeFormat = format;
        _currentDevice.activeVideoMinFrameDuration = CMTimeMake(1, (int32_t)fps);
    } @catch (NSException *exception) {
        RTCLogError(@"Failed to set active format!\n User info:%@", exception.userInfo);
        return;
    }
}

- (void)reconfigureCaptureSessionInput {
    NSAssert([RTCDispatcher isOnQueueForType:RTCDispatcherTypeCaptureSession],
             @"reconfigureCaptureSessionInput must be called on the capture queue.");
    NSError *error = nil;
    AVCaptureDeviceInput *input =
    [AVCaptureDeviceInput deviceInputWithDevice:_currentDevice error:&error];
    if (!input) {
        RTCLogError(@"Failed to create front camera input: %@", error.localizedDescription);
        return;
    }
    [_captureSession beginConfiguration];
    for (AVCaptureDeviceInput *oldInput in [_captureSession.inputs copy]) {
        [_captureSession removeInput:oldInput];
    }
    if ([_captureSession canAddInput:input]) {
        [_captureSession addInput:input];
    } else {
        RTCLogError(@"Cannot add camera as an input to the session.");
    }
    [_captureSession commitConfiguration];
}

- (void)updateOrientation {
    NSAssert([RTCDispatcher isOnQueueForType:RTCDispatcherTypeCaptureSession],
             @"updateOrientation must be called on the capture queue.");
    _orientation = [UIDevice currentDevice].orientation;
}

@end
