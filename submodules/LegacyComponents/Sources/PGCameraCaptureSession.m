#import "PGCameraCaptureSession.h"
#import "PGCameraMovieWriter.h"
#import "PGRectangleDetector.h"

#import <LegacyComponents/LegacyComponentsGlobals.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGMediaVideoConverter.h>

#import "LegacyComponentsInternal.h"

#import <Endian.h>

#import <Accelerate/Accelerate.h>

#import <AVFoundation/AVFoundation.h>
#import <SSignalKit/SSignalKit.h>

#import "POPSpringAnimation.h"

const NSInteger PGCameraFrameRate = 30;

@interface PGCameraCaptureSession () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureMetadataOutputObjectsDelegate>
{
    PGCameraMode _currentMode;
    
    PGCameraPosition _preferredCameraPosition;
    
    PGCameraFlashMode _photoFlashMode;
    PGCameraFlashMode _videoFlashMode;
    
    AVCaptureDeviceInput *_videoInput;
    AVCaptureDeviceInput *_audioInput;
        
    AVCaptureDevice *_audioDevice;
    
    dispatch_queue_t _videoQueue;
    dispatch_queue_t _audioQueue;
    dispatch_queue_t _metadataQueue;
    SQueue *_audioSessionQueue;
    
    bool _captureNextFrame;
    bool _capturingForVideoThumbnail;
    
    NSInteger _frameRate;
    
    bool _initialized;
    
    AVCaptureVideoOrientation _captureVideoOrientation;
    bool _captureMirrored;
    
    SMetaDisposable *_currentAudioSession;
    bool _hasAudioSession;
}

@property (nonatomic, copy) void(^capturedFrameCompletion)(UIImage *image);

@end

@implementation PGCameraCaptureSession

- (instancetype)initWithMode:(PGCameraMode)mode position:(PGCameraPosition)position
{
    self = [super init];
    if (self != nil)
    {
        _currentMode = mode;
        _photoFlashMode = PGCameraFlashModeOff;
        _videoFlashMode = PGCameraFlashModeOff;
        
        _videoQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
        _audioQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
        _metadataQueue = dispatch_queue_create(NULL, DISPATCH_QUEUE_SERIAL);
        _audioSessionQueue = [[SQueue alloc] init];
        
        _preferredCameraPosition = position;
        
        _currentAudioSession = [[SMetaDisposable alloc] init];
        
        self.automaticallyConfiguresApplicationAudioSession = false;
        self.usesApplicationAudioSession = true;

    }
    return self;
}

- (void)dealloc
{
    [self endAudioSession];
    [_videoOutput setSampleBufferDelegate:nil queue:NULL];
    [_audioOutput setSampleBufferDelegate:nil queue:NULL];
    [_metadataOutput setMetadataObjectsDelegate:nil queue:NULL];
}

- (void)performInitialConfigurationWithCompletion:(void (^)(void))completion
{
    _initialized = true;
    
    AVCaptureDevice *targetDevice = [PGCameraCaptureSession _deviceWithCameraPosition:_preferredCameraPosition];
    if (targetDevice == nil)
        targetDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    _videoDevice = targetDevice;
        
    NSError *error = nil;
    if (_videoDevice != nil)
    {
        _preferredCameraPosition = [PGCameraCaptureSession _cameraPositionForDevicePosition:_videoDevice.position];
        
        _videoInput = [AVCaptureDeviceInput deviceInputWithDevice:_videoDevice error:&error];
        if (_videoInput != nil && [self canAddInput:_videoInput])
            [self addInput:_videoInput];
        else
            TGLegacyLog(@"ERROR: camera can't add video input");
    }
    else
    {
        _videoInput = nil;
        TGLegacyLog(@"ERROR: camera can't create video device");
    }
    
    if (_currentMode == PGCameraModePhoto || _currentMode == PGCameraModeSquarePhoto)
    {
#if !TARGET_IPHONE_SIMULATOR
        self.sessionPreset = AVCaptureSessionPresetPhoto;
#endif
    }
    else
    {
        [self switchToBestVideoFormatForDevice:_videoDevice];
        [self _addAudioInputRequestAudioSession:true];
        [self setFrameRate:PGCameraFrameRate forDevice:_videoDevice];
    }
    
    AVCaptureStillImageOutput *imageOutput = [[AVCaptureStillImageOutput alloc] init];
    [imageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
    if ([self canAddOutput:imageOutput])
    {
#if !TARGET_IPHONE_SIMULATOR
        [self addOutput:imageOutput];
#endif
        _imageOutput = imageOutput;
    }
    else
    {
        _imageOutput = nil;
        TGLegacyLog(@"ERROR: camera can't add still image output");
    }
    
    [self resetZoom];
    
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    videoOutput.alwaysDiscardsLateVideoFrames = true;
    videoOutput.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) };
    if ([self canAddOutput:videoOutput])
    {
        [videoOutput setSampleBufferDelegate:self queue:_videoQueue];
#if !TARGET_IPHONE_SIMULATOR
        [self addOutput:videoOutput];
#endif
        _videoOutput = videoOutput;
    }
    else
    {
        _videoOutput = nil;
        TGLegacyLog(@"ERROR: camera can't add video output");
    }
    
    AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    if (_videoDevice.position == AVCaptureDevicePositionBack && [self canAddOutput:metadataOutput])
    {
#if !TARGET_IPHONE_SIMULATOR
        [self addOutput:metadataOutput];
#endif
        _metadataOutput = metadataOutput;

        if ([metadataOutput.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeQRCode]) {
            [metadataOutput setMetadataObjectsDelegate:self queue:_metadataQueue];
            metadataOutput.metadataObjectTypes = @[AVMetadataObjectTypeQRCode];
        }
    }
    else
    {
        _metadataOutput = nil;
        TGLegacyLog(@"ERROR: camera can't add metadata output");
    }
    
    self.currentFlashMode = PGCameraFlashModeOff;
    
    [self _enableLowLightBoost];
    [self _enableVideoStabilization];
    
    if (completion != nil)
        completion();
}

- (bool)isResetNeeded
{
    if (self.currentCameraPosition != _preferredCameraPosition)
        return true;
    
    if (self.currentMode == PGCameraModeVideo || self.currentMode == PGCameraModeSquareVideo || self.currentMode == PGCameraModeSquareSwing)
        return true;
    
    if (self.zoomLevel > FLT_EPSILON)
        return true;
    
    return false;
}

- (void)reset
{
    [self beginConfiguration];
    
    [self _removeAudioInputEndAudioSession:true];
    
    if (self.currentCameraPosition != _preferredCameraPosition)
    {
        [self removeInput:_videoInput];

        AVCaptureDevice *targetDevice = [PGCameraCaptureSession _deviceWithCameraPosition:_preferredCameraPosition];
        if (targetDevice == nil)
            targetDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        
        _videoDevice = targetDevice;
        if (_videoDevice != nil)
        {
            _videoInput = [AVCaptureDeviceInput deviceInputWithDevice:_videoDevice error:nil];
            if (_videoInput != nil)
                [self addInput:_videoInput];
        }
    }
    
    [self resetFlashMode];
    
    if (self.currentMode != PGCameraModePhoto)
    {
        if (self.currentMode == PGCameraModeVideo || self.currentMode == PGCameraModeSquareVideo)
            self.sessionPreset = AVCaptureSessionPresetPhoto;
        
        _currentMode = PGCameraModePhoto;
    }
    
    [self commitConfiguration];
    
    [self resetFocusPoint];
    [self resetZoom];
}

- (void)resetFlashMode
{
    _photoFlashMode = PGCameraFlashModeOff;
    _videoFlashMode = PGCameraFlashModeOff;
    self.currentFlashMode = PGCameraFlashModeOff;
}

- (PGCameraMode)currentMode
{
    return _currentMode;
}

- (void)setCurrentMode:(PGCameraMode)mode
{
    _currentMode = mode;
    
    [self beginConfiguration];
    
    [self resetFocusPoint];
    
    switch (mode)
    {
        case PGCameraModePhoto:
        case PGCameraModeSquarePhoto:
        case PGCameraModePhotoScan:
        {
            [self _removeAudioInputEndAudioSession:true];
            self.sessionPreset = AVCaptureSessionPresetPhoto;
            [self setFrameRate:0 forDevice:_videoDevice];
            
            if (mode == PGCameraModePhotoScan) {
                [self setCurrentCameraPosition:PGCameraPositionRear];
            }
        }
            break;
            
        case PGCameraModeVideo:
        case PGCameraModeSquareVideo:
        case PGCameraModeSquareSwing:
        {
            self.sessionPreset = AVCaptureSessionPresetInputPriority;
            [self switchToBestVideoFormatForDevice:_videoDevice];
            [self _addAudioInputRequestAudioSession:true];
            [self setFrameRate:mode == PGCameraFrameRate forDevice:_videoDevice];
        }
            break;
            
        default:
            break;
    }
    
    [self _enableLowLightBoost];
    [self _enableVideoStabilization];
    
    [self resetZoom];
    
    [self commitConfiguration];
    
    if (mode == PGCameraModePhotoScan) {
        if (_rectangleDetector == nil) {
            _rectangleDetector = [[PGRectangleDetector alloc] init];
        }
    } else {
        _rectangleDetector = nil;
    }
}

- (void)switchToBestVideoFormatForDevice:(AVCaptureDevice *)device
{
    [self _reconfigureDevice:device withBlock:^(AVCaptureDevice *device)
    {
        NSArray *availableFormats = device.formats;
        AVCaptureDeviceFormat *preferredFormat = nil;
        NSMutableArray *maybeFormats = nil;
        int32_t maxWidth = 0;
        int32_t maxHeight = 0;
        for (AVCaptureDeviceFormat *format in availableFormats)
        {
            if (![format.mediaType isEqualToString:@"vide"] || [[format valueForKey:@"isPhotoFormat"] boolValue])
                continue;
            
            CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
            if (dimensions.width >= maxWidth && dimensions.width <= 1920 && dimensions.height >= maxHeight && dimensions.height <= 1080)
            {
                if (dimensions.width > maxWidth)
                    maybeFormats = [[NSMutableArray alloc] init];
                FourCharCode mediaSubType = CMFormatDescriptionGetMediaSubType(format.formatDescription);
                if (mediaSubType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
                {
                    maxWidth = dimensions.width;
                    
                    NSArray *rateRanges = format.videoSupportedFrameRateRanges;
                    bool supportedRate = true;
                    for (AVFrameRateRange *range in rateRanges)
                    {
                        if (range.maxFrameRate > 60)
                        {
                            supportedRate = false;
                            break;
                        }
                    }
                    
                    if (supportedRate)
                        [maybeFormats addObject:format];
                }
            }
        }
        
        preferredFormat = maybeFormats.lastObject;
        
        [device setActiveFormat:preferredFormat];
    }];
}

- (void)requestAudioSession
{
    if (_hasAudioSession)
        return;
    
    _hasAudioSession = true;
    [_audioSessionQueue dispatchSync:^
    {
        [_currentAudioSession setDisposable:[[LegacyComponentsGlobals provider] requestAudioSession:TGAudioSessionTypePlayAndRecord interrupted:nil]];
    }];
}

- (void)endAudioSession
{
    _hasAudioSession = false;
    SMetaDisposable *currentAudioSession = _currentAudioSession;
    [_audioSessionQueue dispatch:^
    {
        [currentAudioSession setDisposable:nil];
    }];
}

- (void)_enableLowLightBoost
{
    [self _reconfigureDevice:_videoDevice withBlock:^(AVCaptureDevice *device)
    {
        if (device.isLowLightBoostSupported)
            device.automaticallyEnablesLowLightBoostWhenAvailable = true;
    }];
}

- (void)_enableVideoStabilization
{
    AVCaptureConnection *videoConnection = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
    if (videoConnection.supportsVideoStabilization) {
        videoConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeStandard;
    }
}

- (void)_addAudioInputRequestAudioSession:(bool)requestAudioSession
{
    if (_audioDevice != nil)
        return;
    
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    NSError *error = nil;
    if (audioDevice != nil)
    {
        _audioDevice = audioDevice;
        AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:_audioDevice error:&error];
        if ([self canAddInput:audioInput])
        {
            [self addInput:audioInput];
            _audioInput = audioInput;
        }
    }
    
    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    if ([self canAddOutput:audioOutput])
    {
        [audioOutput setSampleBufferDelegate:self queue:_audioQueue];
        [self addOutput:audioOutput];
        _audioOutput = audioOutput;
    }
    
    if (requestAudioSession)
        [self requestAudioSession];
}

- (void)_removeAudioInputEndAudioSession:(bool)endAudioSession
{
    if (_audioDevice == nil)
        return;
    
    [self removeInput:_audioInput];
    _audioInput = nil;
    
    [_audioOutput setSampleBufferDelegate:nil queue:[SQueue mainQueue]._dispatch_queue];
    [self removeOutput:_audioOutput];
    _audioOutput = nil;
    
    _audioDevice = nil;
    
    if (endAudioSession)
        [self endAudioSession];
}

#pragma mark - Zoom

- (bool)hasUltrawideCamera {
    if (@available(iOS 13.0, *)) {
        if (self.videoDevice.isVirtualDevice && self.videoDevice.constituentDevices.firstObject.deviceType == AVCaptureDeviceTypeBuiltInUltraWideCamera) {
            return true;
        }
    }
    return false;
}

- (bool)hasTelephotoCamera {
    if (@available(iOS 13.0, *)) {
        if (self.videoDevice.isVirtualDevice && self.videoDevice.constituentDevices.lastObject.deviceType == AVCaptureDeviceTypeBuiltInTelephotoCamera) {
            return true;
        }
    }
    return false;
}

- (CGFloat)zoomLevel
{
    if (![self.videoDevice respondsToSelector:@selector(videoZoomFactor)])
        return 1.0f;

    if (@available(iOS 13.0, *)) {
        if (self.videoDevice.isVirtualDevice) {
            CGFloat backingLevel = self.videoDevice.videoZoomFactor;
            CGFloat realLevel = backingLevel;

            NSArray *marks = self.videoDevice.virtualDeviceSwitchOverVideoZoomFactors;
            if (marks.count == 2) {
                CGFloat firstMark = [marks.firstObject floatValue];
                CGFloat secondMark = [marks.lastObject floatValue];

                if (backingLevel < firstMark) {
                    realLevel = 0.5 + 0.5 * (backingLevel - 1.0) / (firstMark - 1.0);
                } else if (backingLevel < secondMark) {
                    realLevel = 1.0 + 1.0 * (backingLevel - firstMark) / (secondMark - firstMark);
                } else {
                    realLevel = 2.0 + 6.0 * (backingLevel - secondMark) / (self.maxZoomLevel - secondMark);
                }
            } else if (marks.count == 1) {
                CGFloat mark = [marks.firstObject floatValue];
                if ([self hasTelephotoCamera]) {
                    if (backingLevel < mark) {
                        realLevel = 1.0 + 1.0 * (backingLevel - 1.0) / (mark - 1.0);
                    } else {
                        realLevel = 2.0 + 6.0 * (backingLevel - mark) / (self.maxZoomLevel - mark);
                    }
                } else if ([self hasUltrawideCamera]) {
                    if (backingLevel < mark) {
                        realLevel = 0.5 + 0.5 * (backingLevel - 1.0) / (mark - 1.0);
                    } else {
                        realLevel = 1.0 + 7.0 * (backingLevel - mark) / (self.maxZoomLevel - mark);
                    }
                }
            }

            return realLevel;
        }
    }
    
    return self.videoDevice.videoZoomFactor;
}

- (CGFloat)minZoomLevel {
    if (self.hasUltrawideCamera) {
        return 0.5;
    }
    return 1.0;
}

- (CGFloat)maxZoomLevel {
    return MIN(16.0f, self.videoDevice.activeFormat.videoMaxZoomFactor);
}

- (void)resetZoom {
    [self setZoomLevel:1.0];
}

- (void)setZoomLevel:(CGFloat)zoomLevel {
    [self setZoomLevel:zoomLevel animated:false];
}

- (void)setZoomLevel:(CGFloat)zoomLevel animated:(bool)animated
{
    if (![self.videoDevice respondsToSelector:@selector(setVideoZoomFactor:)])
        return;
    
    __weak PGCameraCaptureSession *weakSelf = self;
    [self _reconfigureDevice:self.videoDevice withBlock:^(AVCaptureDevice *device)
    {
        __strong PGCameraCaptureSession *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        CGFloat level = zoomLevel;
        CGFloat backingLevel = zoomLevel;
        if (@available(iOS 13.0, *)) {
            if (device.isVirtualDevice) {
                NSArray *marks = device.virtualDeviceSwitchOverVideoZoomFactors;
                if (marks.count == 2) {
                    CGFloat firstMark = [marks.firstObject floatValue];
                    CGFloat secondMark = [marks.lastObject floatValue];
                    if (level < 1.0) {
                        level = MAX(0.5, level);
                        backingLevel = 1.0 + ((level - 0.5) / 0.5) * (firstMark - 1.0);
                    } else if (zoomLevel < 2.0) {
                        backingLevel = firstMark + ((level - 1.0) / 1.0) * (secondMark - firstMark);
                    } else {
                        backingLevel = secondMark + ((level - 2.0) / 6.0) * (self.maxZoomLevel - secondMark);
                    }
                } else if (marks.count == 1) {
                    CGFloat mark = [marks.firstObject floatValue];
                    if ([self hasTelephotoCamera]) {
                        if (zoomLevel < 2.0) {
                            backingLevel = 1.0 + ((level - 1.0) / 1.0) * (mark - 1.0);
                        } else {
                            backingLevel = mark + ((level - 2.0) / 6.0) * (self.maxZoomLevel - mark);
                        }
                    } else if ([self hasUltrawideCamera]) {
                        if (level < 1.0) {
                            level = MAX(0.5, level);
                            backingLevel = 1.0 + ((level - 0.5) / 0.5) * (mark - 1.0);
                        } else {
                            backingLevel = mark + ((level - 1.0) / 7.0) * (self.maxZoomLevel - mark);
                        }
                    }
                }
            }
        }
        CGFloat finalLevel =  MAX(1.0, MIN([strongSelf maxZoomLevel], backingLevel));
        if (animated) {
            bool zoomingIn = finalLevel > self.videoDevice.videoZoomFactor;
            bool needsCrossfade = level >= 1.0;
            POPSpringAnimation *animation = [POPSpringAnimation new];
            animation.property = [POPAnimatableProperty propertyWithName:@"zoom" initializer:^(POPMutableAnimatableProperty *prop)
            {
                prop.readBlock = ^(PGCameraCaptureSession *session, CGFloat values[])
                {
                    if (session != nil) {
                        values[0] = session.videoDevice.videoZoomFactor;
                    }
                };
                
                prop.writeBlock = ^(PGCameraCaptureSession *session, const CGFloat values[])
                {
                    if (session != nil) {
                        if ((zoomingIn && values[0] > finalLevel - 0.015) || (!zoomingIn && values[0] < finalLevel + 0.015)) {
                            if (needsCrossfade && session.crossfadeNeeded != nil)
                                session.crossfadeNeeded();
                        }
                        [session _reconfigureDevice:session->_videoDevice withBlock:^(AVCaptureDevice *device) {
                            device.videoZoomFactor = values[0];
                        }];
                    }
                };
                
                prop.threshold = 0.03f;
            }];
            animation.fromValue = @(self.videoDevice.videoZoomFactor);
            animation.toValue = @(finalLevel);
            animation.springSpeed = 14;
            animation.springBounciness = 1;
            [self pop_addAnimation:animation forKey:@"zoom"];
        } else {
            device.videoZoomFactor = finalLevel;
        }
    }];
}

- (bool)isZoomAvailable
{
    return [PGCameraCaptureSession _isZoomAvailableForDevice:self.videoDevice];
}

+ (bool)_isZoomAvailableForDevice:(AVCaptureDevice *)device
{
    if (![device respondsToSelector:@selector(setVideoZoomFactor:)])
        return false;
    
    if (device.position == AVCaptureDevicePositionFront)
        return false;
    
    return true;
}

#pragma mark - Focus and Exposure

- (void)resetFocusPoint
{
    const CGPoint centerPoint = CGPointMake(0.5f, 0.5f);
    [self setFocusPoint:centerPoint focusMode:AVCaptureFocusModeContinuousAutoFocus exposureMode:AVCaptureExposureModeContinuousAutoExposure monitorSubjectAreaChange:false];
}

- (void)setFocusPoint:(CGPoint)point focusMode:(AVCaptureFocusMode)focusMode exposureMode:(AVCaptureExposureMode)exposureMode monitorSubjectAreaChange:(bool)monitorSubjectAreaChange
{
    [self _reconfigureDevice:self.videoDevice withBlock:^(AVCaptureDevice *device)
    {
        _focusPoint = point;
        
        if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:exposureMode])
        {
            [device setExposurePointOfInterest:point];
            [device setExposureMode:exposureMode];
        }
        if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:focusMode])
        {
            [device setFocusPointOfInterest:point];
            [device setFocusMode:focusMode];
        }

        [device setSubjectAreaChangeMonitoringEnabled:monitorSubjectAreaChange];
        
        if ([device respondsToSelector:@selector(exposureTargetBias)])
        {
            if (fabsf(device.exposureTargetBias) > FLT_EPSILON)
                [device setExposureTargetBias:0.0f completionHandler:nil];
        }
    }];
}

- (void)setExposureTargetBias:(CGFloat)bias
{
    [self _reconfigureDevice:self.videoDevice withBlock:^(AVCaptureDevice *device)
    {
        CGFloat value = 0.0f;
        CGFloat extremum = (bias >= 0) ? device.maxExposureTargetBias : device.minExposureTargetBias;
        value = fabs(bias) * extremum * 0.85f;
        
        [device setExposureTargetBias:(float)value completionHandler:nil];
    }];
}

#pragma mark - Flash

- (PGCameraFlashMode)currentFlashMode
{
    switch (self.currentMode)
    {
        case PGCameraModeVideo:
        case PGCameraModeSquareVideo:
        case PGCameraModeSquareSwing:
            return _videoFlashMode;
            
        default:
            return _photoFlashMode;
    }
}

- (void)setCurrentFlashMode:(PGCameraFlashMode)mode
{
    [self _reconfigureDevice:self.videoDevice withBlock:^(AVCaptureDevice *device)
    {
        switch (self.currentMode)
        {
            case PGCameraModeVideo:
            case PGCameraModeSquareVideo:
            case PGCameraModeSquareSwing:
            {
                AVCaptureTorchMode torchMode = [PGCameraCaptureSession _deviceTorchModeForCameraFlashMode:mode];
                if (device.hasTorch && [device isTorchModeSupported:torchMode])
                {
                    _videoFlashMode = mode;
                    if (mode != PGCameraFlashModeAuto)
                    {
                        device.torchMode = torchMode;
                    }
                    else
                    {
                        device.torchMode = AVCaptureTorchModeOff;
                        
                        AVCaptureFlashMode flashMode = [PGCameraCaptureSession _deviceFlashModeForCameraFlashMode:mode];
                        if (device.hasFlash && [device isFlashModeSupported:flashMode])
                            device.flashMode = flashMode;
                    }
                }
                else if (mode == PGCameraFlashModeAuto && self.alwaysSetFlash)
                {
                    AVCaptureFlashMode flashMode = [PGCameraCaptureSession _deviceFlashModeForCameraFlashMode:mode];
                    if (device.hasFlash && [device isFlashModeSupported:flashMode])
                        device.flashMode = flashMode;
                }
            }
                break;
                
            default:
            {
                AVCaptureFlashMode flashMode = [PGCameraCaptureSession _deviceFlashModeForCameraFlashMode:mode];
                if (device.hasFlash && [device isFlashModeSupported:flashMode])
                {
                    _photoFlashMode = mode;
                    device.flashMode = flashMode;
                }
            }
                break;
        }
    }];
}

+ (AVCaptureFlashMode)_deviceFlashModeForCameraFlashMode:(PGCameraFlashMode)mode
{
    switch (mode)
    {
        case PGCameraFlashModeAuto:
            return AVCaptureFlashModeAuto;
            
        case PGCameraFlashModeOn:
            return AVCaptureFlashModeOn;
            
        default:
            return AVCaptureFlashModeOff;
    }
}

+ (AVCaptureTorchMode)_deviceTorchModeForCameraFlashMode:(PGCameraFlashMode)mode
{
    switch (mode)
    {
        case PGCameraFlashModeAuto:
            return AVCaptureTorchModeAuto;
            
        case PGCameraFlashModeOn:
            return AVCaptureTorchModeOn;
            
        default:
            return AVCaptureTorchModeOff;
    }
}

#pragma mark - Position

- (PGCameraPosition)currentCameraPosition
{
    if (_videoDevice != nil)
        return [PGCameraCaptureSession _cameraPositionForDevicePosition:_videoDevice.position];
    
    return PGCameraPositionUndefined;
}

- (void)setCurrentCameraPosition:(PGCameraPosition)position
{
    AVCaptureDevice *deviceForTargetPosition = [PGCameraCaptureSession _deviceWithCameraPosition:position];
    if ([_videoDevice isEqual:deviceForTargetPosition])
        return;
 
    NSError *error;
    AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:deviceForTargetPosition error:&error];
    
    if (newVideoInput != nil)
    {
        [self resetFocusPoint];
        
        [self beginConfiguration];
        
        [self removeInput:_videoInput];
        if ([self canAddInput:newVideoInput])
        {
            [self addInput:newVideoInput];
            _videoInput = newVideoInput;
        }
        else
        {
            [self addInput:_videoInput];
        }
        
        if (self.currentMode == PGCameraModeVideo) {
            [self switchToBestVideoFormatForDevice:deviceForTargetPosition];
            [self _removeAudioInputEndAudioSession:false];
            [self _addAudioInputRequestAudioSession:false];
        }
        
        [self commitConfiguration];
        
        if (self.currentMode == PGCameraModeVideo || self.currentMode == PGCameraModeSquareVideo || self.currentMode == PGCameraModeSquareSwing)
            [self setFrameRate:PGCameraFrameRate forDevice:deviceForTargetPosition];
        else
            [self setFrameRate:0 forDevice:deviceForTargetPosition];
    }
    
    _videoDevice = deviceForTargetPosition;
    [self resetZoom];
    
    [self setCurrentFlashMode:self.currentFlashMode];
    
    [self _enableLowLightBoost];
    [self _enableVideoStabilization];
}

+ (AVCaptureDevice *)_deviceWithCameraPosition:(PGCameraPosition)position
{
    return [self _deviceWithPosition:[self _devicePositionForCameraPosition:position]];
}

+ (AVCaptureDevice *)_deviceWithPosition:(AVCaptureDevicePosition)position
{
    if (@available(iOS 13.0, *)) {
        if (position != AVCaptureDevicePositionFront) {
            AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInTripleCamera mediaType:AVMediaTypeVideo position:position];
            if (device == nil) {
                device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInDualCamera mediaType:AVMediaTypeVideo position:position];
            }
            if (device == nil) {
                device = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInDualWideCamera mediaType:AVMediaTypeVideo position:position];
            }
            if (device != nil) {
                return device;
            }
        }
    }
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if (device.position == position)
            return device;
    }
    return nil;
}

+ (PGCameraPosition)_cameraPositionForDevicePosition:(AVCaptureDevicePosition)position
{
    switch (position)
    {
        case AVCaptureDevicePositionBack:
            return PGCameraPositionRear;
            
        case AVCaptureDevicePositionFront:
            return PGCameraPositionFront;
            
        default:
            return PGCameraPositionUndefined;
    }
}

+ (AVCaptureDevicePosition)_devicePositionForCameraPosition:(PGCameraPosition)position
{
    switch (position)
    {
        case PGCameraPositionRear:
            return AVCaptureDevicePositionBack;
            
        case PGCameraPositionFront:
            return AVCaptureDevicePositionFront;
            
        default:
            return AVCaptureDevicePositionUnspecified;
    }
}

#pragma mark - Configuration

- (void)_reconfigureDevice:(AVCaptureDevice *)device withBlock:(void (^)(AVCaptureDevice *device))block
{
    if (block == nil)
        return;
    
    NSError *error = nil;
    [device lockForConfiguration:&error];
    block(device);
    [device unlockForConfiguration];
    
    if (error != nil)
        TGLegacyLog(@"ERROR: failed to reconfigure camera: %@", error);
}

- (void)setFrameRate:(NSInteger)frameRate forDevice:(AVCaptureDevice *)videoDevice
{
    _frameRate = frameRate;
    
    if ([videoDevice respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] &&
        [videoDevice respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)])
    {
        if (_frameRate > 0)
        {
            NSInteger maxFrameRate = PGCameraFrameRate;
            if (videoDevice.activeFormat.videoSupportedFrameRateRanges.count > 0)
            {
                AVFrameRateRange *range = self.videoDevice.activeFormat.videoSupportedFrameRateRanges.firstObject;
                if (range.maxFrameRate < maxFrameRate)
                    maxFrameRate = (NSInteger)range.maxFrameRate;
            }
            
            [self _reconfigureDevice:videoDevice withBlock:^(AVCaptureDevice *device)
            {
                [device setActiveVideoMinFrameDuration:CMTimeMake(1, (int32_t)maxFrameRate)];
                [device setActiveVideoMaxFrameDuration:CMTimeMake(1, (int32_t)maxFrameRate)];
            }];
        }
        else
        {
            [self _reconfigureDevice:videoDevice withBlock:^(AVCaptureDevice *device)
            {
                [device setActiveVideoMinFrameDuration:kCMTimeInvalid];
                [device setActiveVideoMaxFrameDuration:kCMTimeInvalid];
            }];
        }
    }
}

- (NSInteger)frameRate
{
    return _frameRate;
}

#pragma mark - 

- (void)startVideoRecordingWithOrientation:(AVCaptureVideoOrientation)orientation mirrored:(bool)mirrored completion:(void (^)(NSURL *outputURL, CGAffineTransform transform, CGSize dimensions, NSTimeInterval duration, bool success))completion
{
    if (_movieWriter.isRecording)
        return;
    
    if (_videoFlashMode == PGCameraFlashModeAuto)
    {
        [self _reconfigureDevice:self.videoDevice withBlock:^(AVCaptureDevice *device)
        {
            AVCaptureTorchMode torchMode = [PGCameraCaptureSession _deviceTorchModeForCameraFlashMode:PGCameraFlashModeAuto];
            if (device.hasTorch && [device isTorchModeSupported:torchMode])
                device.torchMode = torchMode;
        }];
    }
    
    _captureVideoOrientation = orientation;
    _captureMirrored = mirrored;
    
    NSDictionary *videoSettings = [_videoOutput recommendedVideoSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4];
    NSDictionary *audioSettings = [_audioOutput recommendedAudioSettingsForAssetWriterWithOutputFileType:AVFileTypeMPEG4];
    
    if (self.compressVideo)
    {
        videoSettings = [TGMediaVideoConversionPresetSettings videoSettingsForPreset:TGMediaVideoConversionPresetCompressedMedium dimensions:CGSizeMake(848, 480)];
        audioSettings = [TGMediaVideoConversionPresetSettings audioSettingsForPreset:TGMediaVideoConversionPresetCompressedMedium];
    }
    
    _movieWriter = [[PGCameraMovieWriter alloc] initWithVideoTransform:TGTransformForVideoOrientation(orientation, mirrored) videoOutputSettings:videoSettings audioOutputSettings:audioSettings];
    _movieWriter.finishedWithMovieAtURL = completion;
    [_movieWriter startRecording];
}

- (void)stopVideoRecording
{
    if (!_movieWriter.isRecording)
        return;
    
    __weak PGCameraCaptureSession *weakSelf = self;
    [_movieWriter stopRecordingWithCompletion:^
    {
        __strong PGCameraCaptureSession *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_movieWriter = nil;
        
        strongSelf->_videoFlashMode = PGCameraFlashModeOff;
    }];
}

- (void)captureNextFrameCompletion:(void (^)(UIImage * image))completion
{
    dispatch_async(_videoQueue, ^
    {
        _captureNextFrame = true;
        self.capturedFrameCompletion = completion;
    });
}

#define clamp(a) (uint8_t)(a > 255 ? 255 : (a < 0 ? 0 : a))

- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer orientation:(UIImageOrientation)orientation
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);

    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CIImage *coreImage = [CIImage imageWithCVPixelBuffer:imageBuffer];

    CIContext *ciContext = [CIContext contextWithOptions:nil];
    CGImageRef quartzImage = [ciContext createCGImage:coreImage fromRect:CGRectMake(0, 0, width, height)];
    UIImage *image = [[UIImage alloc] initWithCGImage:quartzImage scale:1.0 orientation:orientation];
    CGImageRelease(quartzImage);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    return image;
}

static UIImageOrientation TGSnapshotOrientationForVideoOrientation(bool mirrored)
{
    return mirrored ? UIImageOrientationLeftMirrored : UIImageOrientationRight;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (!self.isRunning)
        return;
    
    if (!CMSampleBufferDataIsReady(sampleBuffer))
    {
        TGLegacyLog(@"WARNING: camera sample buffer data is not ready, skipping");
        return;
    }
    
    if (self.outputSampleBuffer != nil)
    {
        CFRetain(sampleBuffer);
        self.outputSampleBuffer(sampleBuffer, connection);
        CFRelease(sampleBuffer);
    }
    
    if (_movieWriter.isRecording)
        [_movieWriter _processSampleBuffer:sampleBuffer];
    
    if (_rectangleDetector != nil) {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        [_rectangleDetector detectRectangle:imageBuffer];
    }
    
    if (!_captureNextFrame || captureOutput != _videoOutput)
        return;

    _captureNextFrame = false;
    
    if (self.capturedFrameCompletion != nil)
    {
        CFRetain(sampleBuffer);
        void(^capturedFrameCompletion)(UIImage *image) = self.capturedFrameCompletion;
        self.capturedFrameCompletion = nil;
        
        [[SQueue concurrentDefaultQueue] dispatch:^
        {
            TGDispatchOnMainThread(^{
                if (self.requestPreviewIsMirrored != nil) {
                    bool mirrored = self.requestPreviewIsMirrored();
                    UIImageOrientation orientation = TGSnapshotOrientationForVideoOrientation(mirrored);
                    [[SQueue concurrentDefaultQueue] dispatch:^
                    {
                        UIImage *image = [self imageFromSampleBuffer:sampleBuffer orientation:orientation];
                        CFRelease(sampleBuffer);
                        capturedFrameCompletion(image);
                    }];
                }
            });
        }];
    }
}

#pragma mark - Metadata

- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if (!self.isRunning || self.currentMode != PGCameraModePhoto)
        return;
    
    if ([metadataObjects.firstObject isKindOfClass:[AVMetadataMachineReadableCodeObject class]])
    {
        AVMetadataMachineReadableCodeObject *object = (AVMetadataMachineReadableCodeObject *)metadataObjects.firstObject;
        if (object.type == AVMetadataObjectTypeQRCode && object.stringValue.length > 0)
        {
            TGDispatchOnMainThread(^{
                if (self.recognizedQRCode != nil)
                    self.recognizedQRCode(object.stringValue, object);
            });
        }
    }
}

@end
