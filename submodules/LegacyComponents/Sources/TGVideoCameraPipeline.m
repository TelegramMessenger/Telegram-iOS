#import "TGVideoCameraPipeline.h"

#import "LegacyComponentsInternal.h"

#import <libkern/OSAtomic.h>
#import <CoreMedia/CoreMedia.h>
#import <ImageIO/ImageIO.h>
#import <Accelerate/Accelerate.h>

#import <LegacyComponents/TGVideoCameraGLRenderer.h>

#import <LegacyComponents/TGVideoCameraMovieRecorder.h>
#import <LegacyComponents/TGMediaVideoConverter.h>

typedef enum {
	TGVideoCameraRecordingStatusIdle = 0,
	TGVideoCameraRecordingStatusStartingRecording,
	TGVideoCameraRecordingStatusRecording,
	TGVideoCameraRecordingStatusStoppingRecording,
} TGVideoCameraRecordingStatus;

const NSInteger TGVideoCameraRetainedBufferCount = 16;

@interface TGVideoCameraPipeline () <AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, TGVideoCameraMovieRecorderDelegate>
{
	AVCaptureSession *_captureSession;
    
	AVCaptureDevice *_videoDevice;
    AVCaptureConnection *_videoConnection;
    AVCaptureDeviceInput *_videoInput;
    AVCaptureVideoDataOutput *_videoOutput;
    
    AVCaptureDevice *_audioDevice;
	AVCaptureConnection *_audioConnection;
    AVCaptureDeviceInput *_audioInput;
    AVCaptureAudioDataOutput *_audioOutput;
    
	AVCaptureVideoOrientation _videoBufferOrientation;
    AVCaptureDevicePosition _preferredPosition;
	bool _running;
	bool _startCaptureSessionOnEnteringForeground;
	id _applicationWillEnterForegroundObserver;
	
    dispatch_queue_t _audioDataOutputQueue;
	dispatch_queue_t _videoDataOutputQueue;
	
	TGVideoCameraGLRenderer *_renderer;
	bool _renderingEnabled;
	
	TGVideoCameraMovieRecorder *_recorder;
	NSURL *_recordingURL;
	TGVideoCameraRecordingStatus _recordingStatus;
    UIImage *_recordingThumbnail;
		
	__weak id<TGVideoCameraPipelineDelegate> _delegate;
	dispatch_queue_t _delegateCallbackQueue;
    
    NSTimeInterval _resultDuration;
    
    CVPixelBufferRef _previousPixelBuffer;
    int32_t _repeatingCount;
    
    int16_t _micLevelPeak;
    int _micLevelPeakCount;
    
    TGMediaVideoConversionPreset _preset;
    
    bool _liveUpload;
    id<TGLiveUploadInterface> _watcher;
    id _liveUploadData;
    
    OSSpinLock _recordLock;
    bool _startRecordAfterAudioBuffer;
    
    CVPixelBufferRef _currentPreviewPixelBuffer;
    NSMutableDictionary *_thumbnails;
    
    NSTimeInterval _firstThumbnailTime;
    NSTimeInterval _previousThumbnailTime;
    
    id<TGLiveUploadInterface> _liveUploadInterface;
}

@property (nonatomic, strong) __attribute__((NSObject)) CMFormatDescriptionRef outputVideoFormatDescription;
@property (nonatomic, strong) __attribute__((NSObject)) CMFormatDescriptionRef outputAudioFormatDescription;

@end

@implementation TGVideoCameraPipeline

- (instancetype)initWithDelegate:(id<TGVideoCameraPipelineDelegate>)delegate position:(AVCaptureDevicePosition)position callbackQueue:(dispatch_queue_t)queue liveUploadInterface:(id<TGLiveUploadInterface>)liveUploadInterface
{
	self = [super init];
	if (self != nil)
	{
        _liveUploadInterface = liveUploadInterface;
        _preferredPosition = position;
		
		_videoDataOutputQueue = dispatch_queue_create("org.telegram.VideoCameraPipeline.video", DISPATCH_QUEUE_SERIAL);
		dispatch_set_target_queue(_videoDataOutputQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
		
		_renderer = [[TGVideoCameraGLRenderer alloc] init];
				
		_delegate = delegate;
		_delegateCallbackQueue = queue;
        
        _thumbnails = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
    printf("Camera pipeline dealloc\n");
	[self destroyCaptureSession];
}

- (void)startRunning
{
    [[TGVideoCameraPipeline cameraQueue] dispatch:^
    {
		[self setupCaptureSession];
		
		if (_captureSession != nil)
        {
			[_captureSession startRunning];
			_running = true;
		}
	}];
}

- (void)stopRunning
{
    [[TGVideoCameraPipeline cameraQueue] dispatch:^
    {
		_running = false;
		
		[self stopRecording:^(__unused bool success) {}];
		
		[_captureSession stopRunning];
		[self captureSessionDidStopRunning];
		[self destroyCaptureSession];
	}];
}

- (void)setupCaptureSession
{
	if (_captureSession != nil)
		return;
	
	_captureSession = [[AVCaptureSession alloc] init];
    _captureSession.automaticallyConfiguresApplicationAudioSession = false;
    _captureSession.usesApplicationAudioSession = true;

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(captureSessionNotification:) name:nil object:_captureSession];
	_applicationWillEnterForegroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:[[LegacyComponentsGlobals provider] applicationInstance] queue:nil usingBlock:^(__unused NSNotification *note)
    {
		[self applicationWillEnterForeground];
	}];

	_audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
	_audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:_audioDevice error:nil];
	if ([_captureSession canAddInput:_audioInput])
		[_captureSession addInput:_audioInput];
	
	_audioOutput = [[AVCaptureAudioDataOutput alloc] init];
	_audioDataOutputQueue = dispatch_queue_create("org.telegram.VideoCameraPipeline.audio", DISPATCH_QUEUE_SERIAL);
	[_audioOutput setSampleBufferDelegate:self queue:_audioDataOutputQueue];
	
	if ([_captureSession canAddOutput:_audioOutput])
		[_captureSession addOutput:_audioOutput];

	_audioConnection = [_audioOutput connectionWithMediaType:AVMediaTypeAudio];

    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if (device.position == _preferredPosition)
        {
            videoDevice = device;
            break;
        }
    }
    
    _renderer.mirror = (videoDevice.position == AVCaptureDevicePositionFront);
    _renderer.orientation = _orientation;
    
	NSError *videoDeviceError = nil;
	_videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:videoDevice error:&videoDeviceError];
	if ([_captureSession canAddInput:_videoInput])
    {
		[_captureSession addInput:_videoInput];
        _videoDevice = videoDevice;
	}
	else
    {
		[self handleNonRecoverableCaptureSessionRuntimeError:videoDeviceError];
		return;
	}
	
	_videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    _videoOutput.alwaysDiscardsLateVideoFrames = false;
	_videoOutput.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
	[_videoOutput setSampleBufferDelegate:self queue:_videoDataOutputQueue];
	
	if ([_captureSession canAddOutput:_videoOutput])
		[_captureSession addOutput:_videoOutput];
	
	_videoConnection = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
    
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480])
        _captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    else
        _captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    
    [self _configureFPS];
	
    [self _enableLowLightBoost];
    [self _enableVideoStabilization];
    
	_videoBufferOrientation = _videoConnection.videoOrientation;
}

- (void)destroyCaptureSession
{
	if (_captureSession)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:_captureSession];
		
		[[NSNotificationCenter defaultCenter] removeObserver:_applicationWillEnterForegroundObserver];
		_applicationWillEnterForegroundObserver = nil;
        
        [_captureSession beginConfiguration];
        [_captureSession removeOutput:_videoOutput];
        [_captureSession removeInput:_videoInput];
        [_captureSession removeOutput:_audioOutput];
        [_captureSession removeInput:_audioInput];
		[_captureSession commitConfiguration];
        
        _audioInput = nil;
        _audioDevice = nil;
        _audioOutput = nil;
        _audioConnection = nil;
        
        _videoInput = nil;
        _videoDevice = nil;
        _videoOutput = nil;
        _videoConnection = nil;
		_captureSession = nil;
	}
}

- (void)captureSessionNotification:(NSNotification *)notification
{
    [[TGVideoCameraPipeline cameraQueue] dispatch:^
    {
		if ([notification.name isEqualToString:AVCaptureSessionWasInterruptedNotification])
		{
            NSInteger reason = [notification.userInfo[AVCaptureSessionInterruptionReasonKey] integerValue];
            if (reason == AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableInBackground) {
                if (_running)
                    _startCaptureSessionOnEnteringForeground = true;
            } else {
                [self captureSessionDidStopRunning];
            }
		}
		else if ([notification.name isEqualToString:AVCaptureSessionRuntimeErrorNotification])
		{
			[self captureSessionDidStopRunning];
			
			NSError *error = notification.userInfo[AVCaptureSessionErrorKey];
			if (error.code == AVErrorMediaServicesWereReset)
            {
				[self handleRecoverableCaptureSessionRuntimeError:error];
			}
			else
			{
				[self handleNonRecoverableCaptureSessionRuntimeError:error];
			}
		}
	}];
}

- (void)handleRecoverableCaptureSessionRuntimeError:(NSError *)__unused error
{
	if (_running)
		[_captureSession startRunning];
}

- (void)handleNonRecoverableCaptureSessionRuntimeError:(NSError *)error
{
	_running = false;
	[self destroyCaptureSession];
	
	[self invokeDelegateCallbackAsync:^
    {
		[_delegate capturePipeline:self didStopRunningWithError:error];
	}];
}

- (void)captureSessionDidStopRunning
{
	[self stopRecording:^(__unused bool success) {}];
	[self destroyVideoPipeline];
}

- (void)applicationWillEnterForeground
{
    [[TGVideoCameraPipeline cameraQueue] dispatch:^
    {
		if (_startCaptureSessionOnEnteringForeground)
		{
			_startCaptureSessionOnEnteringForeground = false;
			if (_running)
				[_captureSession startRunning];
		}
    }];
}

- (void)setupVideoPipelineWithInputFormatDescription:(CMFormatDescriptionRef)inputFormatDescription
{
	[_renderer prepareForInputWithFormatDescription:inputFormatDescription outputRetainedBufferCountHint:TGVideoCameraRetainedBufferCount];
    self.outputVideoFormatDescription = _renderer.outputFormatDescription;
}

- (void)destroyVideoPipeline
{
	dispatch_sync(_videoDataOutputQueue, ^
    {
		if (self.outputVideoFormatDescription == NULL)
			return;
		
		self.outputVideoFormatDescription = NULL;
		[_renderer reset];
        
        if (_currentPreviewPixelBuffer != NULL)
        {
            CFRelease(_currentPreviewPixelBuffer);
            _currentPreviewPixelBuffer = NULL;
        }
	});
}

- (void)videoPipelineDidRunOutOfBuffers
{
	[self invokeDelegateCallbackAsync:^
    {
		[_delegate capturePipelineDidRunOutOfPreviewBuffers:self];
	}];
}

- (void)setRenderingEnabled:(bool)renderingEnabled
{
	@synchronized (_renderer)
    {
		_renderingEnabled = renderingEnabled;
	}
}

- (bool)renderingEnabled
{
	@synchronized (_renderer)
    {
		return _renderingEnabled;
	}
}

- (void)captureOutput:(AVCaptureOutput *)__unused captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
	CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
	
	if (connection == _videoConnection)
	{
		if (self.outputVideoFormatDescription == NULL)
			[self setupVideoPipelineWithInputFormatDescription:formatDescription];
        else {
//            [_recorder appendVideoSampleBuffer:sampleBuffer];
			[self renderVideoSampleBuffer:sampleBuffer];
        }
	}
	else if (connection == _audioConnection)
	{
		self.outputAudioFormatDescription = formatDescription;
		
		@synchronized (self)
        {
			if (_recordingStatus == TGVideoCameraRecordingStatusRecording)
				[_recorder appendAudioSampleBuffer:sampleBuffer];
		}

        CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
        uint32_t numSamplesInBuffer = (uint32_t)CMSampleBufferGetNumSamples(sampleBuffer);
        
        AudioBufferList audioBufferList;
        
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, NULL, &audioBufferList, sizeof(audioBufferList), NULL, NULL, kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, &blockBuffer );
        
        for (uint32_t bufferCount = 0; bufferCount < audioBufferList.mNumberBuffers; bufferCount++)
        {
            int16_t *samples = (int16_t *)audioBufferList.mBuffers[bufferCount].mData;
            [self processWaveformPreview:samples count:numSamplesInBuffer];
        }
        
        CFRelease(blockBuffer);
        
        OSSpinLockLock(&_recordLock);
        if (_startRecordAfterAudioBuffer)
        {
            _startRecordAfterAudioBuffer = false;
            TGDispatchOnMainThread(^
            {
                [self startRecording:_recordingURL preset:_preset liveUpload:_liveUpload];
            });
        }
        OSSpinLockUnlock(&_recordLock);
    }
}

- (void)processWaveformPreview:(int16_t const *)samples count:(int)count {
    for (int i = 0; i < count; i++) {
        int16_t sample = samples[i];
        if (sample < 0) {
            sample = -sample;
        }
    
        if (_micLevelPeak < sample) {
            _micLevelPeak = sample;
        }
        _micLevelPeakCount++;
        
        if (_micLevelPeakCount >= 1200) {
            if (_micLevel) {
                CGFloat level = (CGFloat)_micLevelPeak / 4000.0;
                _micLevel(level);
            }
            _micLevelPeak = 0;
            _micLevelPeakCount = 0;
        }
    }
}

- (UIImage *)imageFromImageBuffer:(CVPixelBufferRef)imageBuffer
{
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    return image;
}


- (void)renderVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
	CVPixelBufferRef renderedPixelBuffer = NULL;
	CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
	@synchronized (_renderer)
	{
		if (_renderingEnabled)
        {
            bool repeatingFrames = false;
            @synchronized (self)
            {
                if (_recorder.paused && _previousPixelBuffer != NULL)
                {
                    _recorder.paused = false;
                    _repeatingCount = 11;
                    
                    [_renderer setPreviousPixelBuffer:_previousPixelBuffer];
                    CFRelease(_previousPixelBuffer);
                    _previousPixelBuffer = NULL;
                }
                
                if (_repeatingCount > 0)
                {
                    repeatingFrames = true;
                    _repeatingCount--;
                }
                
                CGFloat opacity = 1.0f;
                if (_repeatingCount < 10)
                    opacity = _repeatingCount / 9.0f;

                [_renderer setOpacity:opacity];
                
                if (_repeatingCount == 0)
                    [_renderer setPreviousPixelBuffer:NULL];
            }
            
			CVPixelBufferRef sourcePixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
			renderedPixelBuffer = [_renderer copyRenderedPixelBuffer:sourcePixelBuffer];
            
            @synchronized (self)
            {
                if (_recordingStatus == TGVideoCameraRecordingStatusRecording && _recordingThumbnail == nil)
                {
                    UIImage *image = [self imageFromImageBuffer:sourcePixelBuffer];
                    _recordingThumbnail = image;
                }
                
                if (_recordingStatus == TGVideoCameraRecordingStatusRecording && !repeatingFrames)
                {
                    NSTimeInterval currentTime = CMTimeGetSeconds(timestamp);
                    if (_previousThumbnailTime < DBL_EPSILON)
                    {
                        _firstThumbnailTime = currentTime;
                        _previousThumbnailTime = currentTime;
                        
                        [self storeThumbnailWithSampleBuffer:sampleBuffer time:0.0 mirror:_renderer.mirror];
                    }
                    else
                    {
                        NSTimeInterval relativeThumbnailTime = _previousThumbnailTime - _firstThumbnailTime;
                        NSTimeInterval interval = MAX(0.1, relativeThumbnailTime / 10.0);
                        
                        if (currentTime - _previousThumbnailTime >= interval)
                        {
                            [self storeThumbnailWithSampleBuffer:sampleBuffer time:relativeThumbnailTime mirror:_renderer.mirror];
                            _previousThumbnailTime = currentTime;
                        }
                    }
                }
                
                if (!repeatingFrames)
                {
                    if (_previousPixelBuffer != NULL)
                    {
                        CFRelease(_previousPixelBuffer);
                        _previousPixelBuffer = NULL;
                    }
                    
                    _previousPixelBuffer = sourcePixelBuffer;
                    CFRetain(sourcePixelBuffer);
                }
            }
		}
		else
        {
			return;
		}
	}
	
	if (renderedPixelBuffer)
	{
		@synchronized (self)
		{
			[self outputPreviewPixelBuffer:renderedPixelBuffer];
            
			if (_recordingStatus == TGVideoCameraRecordingStatusRecording)
				[_recorder appendVideoPixelBuffer:renderedPixelBuffer withPresentationTime:timestamp];
		}
		
		CFRelease(renderedPixelBuffer);
	}
	else
	{
		[self videoPipelineDidRunOutOfBuffers];
	}
}

- (void)outputPreviewPixelBuffer:(CVPixelBufferRef)previewPixelBuffer
{
    if (_currentPreviewPixelBuffer != NULL)
    {
        CFRelease(_currentPreviewPixelBuffer);
        _currentPreviewPixelBuffer = NULL;
    }
    
    if (_previousPixelBuffer != NULL)
    {
        _currentPreviewPixelBuffer = previewPixelBuffer;
        CFRetain(_currentPreviewPixelBuffer);
    }
    
    [self invokeDelegateCallbackAsync:^
    {
		CVPixelBufferRef currentPreviewPixelBuffer = NULL;
		@synchronized (self)
		{
			currentPreviewPixelBuffer = _currentPreviewPixelBuffer;
			if (currentPreviewPixelBuffer != NULL)
            {
				CFRetain(currentPreviewPixelBuffer);
                if (_currentPreviewPixelBuffer != NULL)
                {
                    CFRelease(_currentPreviewPixelBuffer);
                    _currentPreviewPixelBuffer = NULL;
                }
			}
		}
		
		if (currentPreviewPixelBuffer != NULL)
        {
			[_delegate capturePipeline:self previewPixelBufferReadyForDisplay:currentPreviewPixelBuffer];
			CFRelease(currentPreviewPixelBuffer);
		}
	}];
}

- (void)storeThumbnailWithSampleBuffer:(CMSampleBufferRef)sampleBuffer time:(NSTimeInterval)time mirror:(bool)mirror
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    size_t cropX = (size_t)((width - height) / 2.0);
    size_t cropY = 0;
    size_t cropWidth = height;
    size_t cropHeight = height;
    size_t outWidth = 66;
    size_t outHeight = 66;

    CVPixelBufferLockBaseAddress(imageBuffer,0);
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    
    vImage_Buffer inBuff;
    inBuff.height = cropHeight;
    inBuff.width = cropWidth;
    inBuff.rowBytes = bytesPerRow;
    
    unsigned long startpos = cropY * bytesPerRow + 4 * cropX;
    inBuff.data = baseAddress + startpos;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreateWithData(NULL, outWidth, outHeight, 8, outWidth * 4, colorSpace, kCGImageByteOrder32Little | kCGImageAlphaPremultipliedFirst, NULL, nil);
    
    unsigned char *outImg = CGBitmapContextGetData(context);
    vImage_Buffer outBuff = {outImg, outHeight, outWidth, 4 * outWidth};
    
    vImage_Error err = vImageScale_ARGB8888(&inBuff, &outBuff, NULL, 0);
    if (err != kvImageNoError)
        TGLegacyLog(@"Video Message thumbnail generation error %ld", err);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image = [UIImage imageWithCGImage:cgImage scale:1.0f orientation:mirror ? UIImageOrientationLeftMirrored : UIImageOrientationRight];
    CGImageRelease(cgImage);
    
    _thumbnails[@(time)] = image;
}

- (void)startRecording:(NSURL *)url preset:(TGMediaVideoConversionPreset)preset liveUpload:(bool)liveUpload
{
    _recordingURL = url;
    _preset = preset;
    _liveUpload = liveUpload;
    
    OSSpinLockLock(&_recordLock);
    if (self.outputAudioFormatDescription == NULL)
    {
        _startRecordAfterAudioBuffer = true;
        OSSpinLockUnlock(&_recordLock);
        return;
    }
    OSSpinLockUnlock(&_recordLock);
    
	@synchronized (self)
	{
		if (_recordingStatus != TGVideoCameraRecordingStatusIdle)
			return;
		
		[self transitionToRecordingStatus:TGVideoCameraRecordingStatusStartingRecording error:nil];
	}
	
	dispatch_queue_t callbackQueue = dispatch_queue_create("org.telegram.VideoCameraPipeline.recorder", DISPATCH_QUEUE_SERIAL);
	TGVideoCameraMovieRecorder *recorder = [[TGVideoCameraMovieRecorder alloc] initWithURL:_recordingURL delegate:self callbackQueue:callbackQueue];
	
    NSDictionary *audioSettings = [TGMediaVideoConversionPresetSettings audioSettingsForPreset:preset];
	[recorder addAudioTrackWithSourceFormatDescription:self.outputAudioFormatDescription settings:audioSettings];

    _videoTransform = [self transformForOrientation:self.orientation];

    CGSize size = [TGMediaVideoConversionPresetSettings maximumSizeForPreset:preset];
    NSDictionary *videoSettings = [TGMediaVideoConversionPresetSettings videoSettingsForPreset:preset dimensions:size];
	[recorder addVideoTrackWithSourceFormatDescription:self.outputVideoFormatDescription transform:CGAffineTransformIdentity settings:videoSettings];
	_recorder = recorder;
	
	[recorder prepareToRecord];
}

- (void)stopRecording:(void (^)(bool))completed
{
    [[TGVideoCameraPipeline cameraQueue] dispatch:^
    {
        @synchronized (self)
        {
            if (_recordingStatus != TGVideoCameraRecordingStatusRecording) {
                if (completed) {
                    completed(false);
                }
                return;
            }
            
            [self transitionToRecordingStatus:TGVideoCameraRecordingStatusStoppingRecording error:nil];
        }
        
        _resultDuration = _recorder.videoDuration;
        [_recorder finishRecording:^{
            __unused __auto_type description = [self description];
            if (completed) {
                completed(true);
            }
        }];
    }];
}

- (bool)isRecording
{
    return _recorder != nil && !_recorder.paused;
}

- (void)movieRecorderDidFinishPreparing:(TGVideoCameraMovieRecorder *)__unused recorder
{
	@synchronized (self)
	{
		if (_recordingStatus != TGVideoCameraRecordingStatusStartingRecording)
			return;
		
		[self transitionToRecordingStatus:TGVideoCameraRecordingStatusRecording error:nil];
        
        if (_liveUpload)
        {
            _watcher = _liveUploadInterface;
            [_watcher setupWithFileURL:_recordingURL];
        }
	}
}

- (void)movieRecorder:(TGVideoCameraMovieRecorder *)__unused recorder didFailWithError:(NSError *)error
{
	@synchronized (self)
	{
		_recorder = nil;
		[self transitionToRecordingStatus:TGVideoCameraRecordingStatusIdle error:error];
	}
}

- (void)movieRecorderDidFinishRecording:(TGVideoCameraMovieRecorder *)__unused recorder
{
    printf("movieRecorderDidFinishRecording\n");
    
	@synchronized (self)
	{
		if (_recordingStatus != TGVideoCameraRecordingStatusStoppingRecording)
            return;
	}
	
	_recorder = nil;
    
    if (_watcher != nil)
        _liveUploadData = [_watcher fileUpdated:true];
    
    [self transitionToRecordingStatus:TGVideoCameraRecordingStatusIdle error:nil];
}

- (void)transitionToRecordingStatus:(TGVideoCameraRecordingStatus)newStatus error:(NSError *)error
{
    printf("transitionToRecordingStatus %d\n", newStatus);
    
	TGVideoCameraRecordingStatus oldStatus = _recordingStatus;
	_recordingStatus = newStatus;
    
	if (newStatus != oldStatus)
	{
		dispatch_block_t delegateCallbackBlock = nil;
		
		if (error && newStatus == TGVideoCameraRecordingStatusIdle)
		{
			delegateCallbackBlock = ^{ [_delegate capturePipeline:self recordingDidFailWithError:error]; };
		}
		else
		{
            __strong id<TGVideoCameraPipelineDelegate> delegate = _delegate;
			if ((oldStatus == TGVideoCameraRecordingStatusStartingRecording) && (newStatus == TGVideoCameraRecordingStatusRecording))
				delegateCallbackBlock = ^{ [delegate capturePipelineRecordingDidStart:self]; };
			else if ((oldStatus == TGVideoCameraRecordingStatusRecording) && (newStatus == TGVideoCameraRecordingStatusStoppingRecording))
				delegateCallbackBlock = ^{ [delegate capturePipelineRecordingWillStop:self]; };
			else if ((oldStatus == TGVideoCameraRecordingStatusStoppingRecording) && (newStatus == TGVideoCameraRecordingStatusIdle))
				delegateCallbackBlock = ^{
                    printf("transitionToRecordingStatus delegateCallbackBlock _delegate == nil = %d\n", (int)(delegate == nil));
                    [delegate capturePipelineRecordingDidStop:self duration:_resultDuration liveUploadData:_liveUploadData thumbnailImage:_recordingThumbnail thumbnails:_thumbnails];
                };
		}
		
		if (delegateCallbackBlock != nil)
			[self invokeDelegateCallbackAsync:delegateCallbackBlock];
	}
}

- (void)invokeDelegateCallbackAsync:(dispatch_block_t)callbackBlock
{
	dispatch_async(_delegateCallbackQueue, ^
    {
		@autoreleasepool
        {
			callbackBlock();
		}
	});
}

- (CGAffineTransform)transformForOrientation:(AVCaptureVideoOrientation)orientation
{
	CGAffineTransform transform = CGAffineTransformIdentity;
		
	CGFloat orientationAngleOffset = angleOffsetFromPortraitOrientationToOrientation(orientation);
	CGFloat videoOrientationAngleOffset = angleOffsetFromPortraitOrientationToOrientation(_videoBufferOrientation);
	
	CGFloat angleOffset = orientationAngleOffset - videoOrientationAngleOffset;
	transform = CGAffineTransformMakeRotation(angleOffset);
    
	return transform;
}

static CGFloat angleOffsetFromPortraitOrientationToOrientation(AVCaptureVideoOrientation orientation)
{
	CGFloat angle = 0.0;
	
	switch (orientation)
	{
        case AVCaptureVideoOrientationPortrait:
            angle = 0.0;
            break;
        case AVCaptureVideoOrientationPortraitUpsideDown:
            angle = M_PI;
            break;
        case AVCaptureVideoOrientationLandscapeRight:
            angle = -M_PI_2;
            break;
        case AVCaptureVideoOrientationLandscapeLeft:
            angle = M_PI_2;
            break;
        default:
            break;
	}
	
	return angle;
}

- (NSTimeInterval)videoDuration
{
    return _recorder.videoDuration;
}

- (CGFloat)zoomLevel
{
    if (![_videoDevice respondsToSelector:@selector(videoZoomFactor)])
        return 1.0f;
    
    return (_videoDevice.videoZoomFactor - 1.0f) / ([self _maximumZoomFactor] - 1.0f);
}

- (CGFloat)_maximumZoomFactor
{
    return MIN(5.0f, _videoDevice.activeFormat.videoMaxZoomFactor);
}

- (void)setZoomLevel:(CGFloat)zoomLevel
{
    zoomLevel = MAX(0.0f, MIN(1.0f, zoomLevel));
    
    __weak TGVideoCameraPipeline *weakSelf = self;
    [[TGVideoCameraPipeline cameraQueue] dispatch:^
    {
        __strong TGVideoCameraPipeline *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [self _reconfigureDevice:_videoDevice withBlock:^(AVCaptureDevice *device) {
            device.videoZoomFactor = MAX(1.0f, MIN([strongSelf _maximumZoomFactor], 1.0f + ([strongSelf _maximumZoomFactor] - 1.0f) * zoomLevel));
        }];
    }];
}

- (void)cancelZoom {
    __weak TGVideoCameraPipeline *weakSelf = self;
    [[TGVideoCameraPipeline cameraQueue] dispatch:^
    {
        __strong TGVideoCameraPipeline *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [self _reconfigureDevice:_videoDevice withBlock:^(AVCaptureDevice *device) {
            [device rampToVideoZoomFactor:1.0 withRate:8.0];
        }];
    }];
}

- (bool)isZoomAvailable
{
    return [TGVideoCameraPipeline _isZoomAvailableForDevice:_videoDevice];
}

+ (bool)_isZoomAvailableForDevice:(AVCaptureDevice *)device
{
    if (![device respondsToSelector:@selector(setVideoZoomFactor:)])
        return false;
    
    if (device.position == AVCaptureDevicePositionFront)
        return false;
    
    return true;
}

- (void)setCameraPosition:(AVCaptureDevicePosition)position
{
    @synchronized (self)
    {
        _recorder.paused = true;
    }
    
    [[TGVideoCameraPipeline cameraQueue] dispatch:^
    {
        NSError *error;
        
        NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        AVCaptureDevice *deviceForTargetPosition = nil;
        for (AVCaptureDevice *device in devices)
        {
            if (device.position == position)
            {
                deviceForTargetPosition = device;
                break;
            }
        }
        
        _renderer.mirror = deviceForTargetPosition.position == AVCaptureDevicePositionFront;
        _renderer.orientation = _orientation;
        
        AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:deviceForTargetPosition error:&error];
        if (newVideoInput != nil)
        {
            [_captureSession beginConfiguration];
            
            [_captureSession removeInput:_videoInput];
            if ([_captureSession canAddInput:newVideoInput])
            {
                [_captureSession addInput:newVideoInput];
                _videoInput = newVideoInput;
            }
            else
            {
                [_captureSession addInput:_videoInput];
            }
            
            [_captureSession commitConfiguration];
        }
        
        _videoDevice = deviceForTargetPosition;
        
        _videoConnection = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];

        [self _configureFPS];
        
        [self _enableLowLightBoost];
        [self _enableVideoStabilization];
        
        _videoBufferOrientation = _videoConnection.videoOrientation;
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
        if (iosMajorVersion() >= 13) {
            videoConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeCinematicExtended;
        } else {
            videoConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeCinematic;
        }
    }
}

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

- (void)_addAudioInput
{
    if (_audioDevice != nil || _audioDataOutputQueue == NULL)
        return;
    
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    NSError *error = nil;
    if (audioDevice != nil)
    {
        _audioDevice = audioDevice;
        AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:_audioDevice error:&error];
        if ([_captureSession canAddInput:audioInput])
        {
            [_captureSession addInput:audioInput];
            _audioInput = audioInput;
        }
    }
    
    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    if ([_captureSession canAddOutput:audioOutput])
    {
        [audioOutput setSampleBufferDelegate:self queue:_audioDataOutputQueue];
        [_captureSession addOutput:audioOutput];
        _audioOutput = audioOutput;
    }
}

- (void)_removeAudioInput
{
    if (_audioDevice == nil)
        return;
    
    [_captureSession removeInput:_audioInput];
    _audioInput = nil;
    
    [_audioOutput setSampleBufferDelegate:nil queue:NULL];
    [_captureSession removeOutput:_audioOutput];
    _audioOutput = nil;
    
    _audioDevice = nil;
}

- (void)_configureFPS
{
    CMTime frameDuration = CMTimeMake(1, 30);
    [self _reconfigureDevice:_videoDevice withBlock:^(AVCaptureDevice *device)
    {
        device.activeVideoMaxFrameDuration = frameDuration;
        device.activeVideoMinFrameDuration = frameDuration;
    }];
}

+ (bool)cameraPositionChangeAvailable
{
    return [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count > 1;
}

+ (SQueue *)cameraQueue
{
    static dispatch_once_t onceToken;
    static SQueue *queue = nil;
    dispatch_once(&onceToken, ^
    {
        queue = [[SQueue alloc] init];
    });
    
    return queue;
}

@end
