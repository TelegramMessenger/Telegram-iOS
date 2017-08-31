#import "TGVideoCameraMovieRecorder.h"
#import <AVFoundation/AVFoundation.h>

typedef enum {
	TGMovieRecorderStatusIdle = 0,
	TGMovieRecorderStatusPreparingToRecord,
	TGMovieRecorderStatusRecording,
	TGMovieRecorderStatusFinishingWaiting,
	TGMovieRecorderStatusFinishingCommiting,
	TGMovieRecorderStatusFinished,
	TGMovieRecorderStatusFailed
} TGMovieRecorderStatus;


@interface TGVideoCameraMovieRecorder ()
{
	TGMovieRecorderStatus _status;
	
	dispatch_queue_t _writingQueue;
	
	NSURL *_url;
	
	AVAssetWriter *_assetWriter;
	bool _haveStartedSession;
	
	CMFormatDescriptionRef _audioTrackSourceFormatDescription;
	NSDictionary *_audioTrackSettings;
	AVAssetWriterInput *_audioInput;
	
	CMFormatDescriptionRef _videoTrackSourceFormatDescription;
	CGAffineTransform _videoTrackTransform;
	NSDictionary *_videoTrackSettings;
	AVAssetWriterInput *_videoInput;

	__weak id<TGVideoCameraMovieRecorderDelegate> _delegate;
	dispatch_queue_t _delegateCallbackQueue;
    
    CMTime _startTimeStamp;
    CMTime _lastAudioTimeStamp;
    
    CMTime _timeOffset;
    
    bool _wasPaused;
}
@end


@implementation TGVideoCameraMovieRecorder

- (instancetype)initWithURL:(NSURL *)URL delegate:(id<TGVideoCameraMovieRecorderDelegate>)delegate callbackQueue:(dispatch_queue_t)queue
{
	self = [super init];
	if (self != nil)
	{
		_writingQueue = dispatch_queue_create("org.telegram.movierecorder.writing", DISPATCH_QUEUE_SERIAL);
		_videoTrackTransform = CGAffineTransformIdentity;
		_url = URL;
		_delegate = delegate;
		_delegateCallbackQueue = queue;
	}
	return self;
}

- (void)addVideoTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription transform:(CGAffineTransform)transform settings:(NSDictionary *)videoSettings
{
	if (formatDescription == NULL)
		return;
	
	@synchronized (self)
	{
		if (_status != TGMovieRecorderStatusIdle)
			return;
		
		if (_videoTrackSourceFormatDescription)
			return;
		
		_videoTrackSourceFormatDescription = (CMFormatDescriptionRef)CFRetain(formatDescription);
		_videoTrackTransform = transform;
		_videoTrackSettings = [videoSettings copy];
	}
}

- (void)addAudioTrackWithSourceFormatDescription:(CMFormatDescriptionRef)formatDescription settings:(NSDictionary *)audioSettings
{
	if (formatDescription == NULL)
		return;

	@synchronized (self)
	{
		if (_status != TGMovieRecorderStatusIdle)
			return;
		
		if (_audioTrackSourceFormatDescription)
			return;
		
		_audioTrackSourceFormatDescription = (CMFormatDescriptionRef)CFRetain(formatDescription);
		_audioTrackSettings = [audioSettings copy];
	}
}

- (void)prepareToRecord
{
	@synchronized( self )
	{
		if (_status != TGMovieRecorderStatusIdle)
			return;
		
		[self transitionToStatus:TGMovieRecorderStatusPreparingToRecord error:nil];
	}
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^
    {
		@autoreleasepool
		{
			NSError *error = nil;
    
			[[NSFileManager defaultManager] removeItemAtURL:_url error:NULL];
			
			_assetWriter = [[AVAssetWriter alloc] initWithURL:_url fileType:AVFileTypeMPEG4 error:&error];
			
            bool succeed = false;
			if (error == nil && _videoTrackSourceFormatDescription)
            {
				succeed = [self setupAssetWriterVideoInputWithSourceFormatDescription:_videoTrackSourceFormatDescription transform:_videoTrackTransform settings:_videoTrackSettings];
			}
			
			if (error == nil && succeed && _audioTrackSourceFormatDescription)
            {
				succeed = [self setupAssetWriterAudioInputWithSourceFormatDescription:_audioTrackSourceFormatDescription settings:_audioTrackSettings];
			}
			
			if (error == nil && succeed)
            {
				if (![_assetWriter startWriting])
					error = _assetWriter.error;
			}
			
			@synchronized (self)
			{
				if (error || !succeed)
					[self transitionToStatus:TGMovieRecorderStatusFailed error:error];
				else
					[self transitionToStatus:TGMovieRecorderStatusRecording error:nil];
			}
		}
	} );
}

- (void)appendVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer withPresentationTime:(CMTime)presentationTime
{
	CMSampleBufferRef sampleBuffer = NULL;
	
    CMSampleTimingInfo timingInfo;
	timingInfo.duration = kCMTimeInvalid;
	timingInfo.decodeTimeStamp = kCMTimeInvalid;
	timingInfo.presentationTimeStamp = presentationTime;
	
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, _videoTrackSourceFormatDescription, &timingInfo, &sampleBuffer);
        
	if (sampleBuffer)
    {
		[self appendSampleBuffer:sampleBuffer ofMediaType:AVMediaTypeVideo];
        CFRelease(sampleBuffer);
    }
}

- (void)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
	[self appendSampleBuffer:sampleBuffer ofMediaType:AVMediaTypeAudio];
}

- (void)finishRecording
{
	@synchronized (self)
	{
		bool shouldFinishRecording = false;
		switch (_status)
		{
			case TGMovieRecorderStatusIdle:
			case TGMovieRecorderStatusPreparingToRecord:
			case TGMovieRecorderStatusFinishingWaiting:
			case TGMovieRecorderStatusFinishingCommiting:
			case TGMovieRecorderStatusFinished:
			case TGMovieRecorderStatusFailed:
				break;
                
			case TGMovieRecorderStatusRecording:
				shouldFinishRecording = true;
				break;
		}
		
		if (shouldFinishRecording)
			[self transitionToStatus:TGMovieRecorderStatusFinishingWaiting error:nil];
		else
			return;
	}
	
	dispatch_async(_writingQueue, ^
    {
		@autoreleasepool
		{
			@synchronized (self)
			{
				if (_status != TGMovieRecorderStatusFinishingWaiting)
					return;
				
				[self transitionToStatus:TGMovieRecorderStatusFinishingCommiting error:nil];
			}

			[_assetWriter finishWritingWithCompletionHandler:^
            {
				@synchronized (self)
				{
					NSError *error = _assetWriter.error;
					if (error)
						[self transitionToStatus:TGMovieRecorderStatusFailed error:error];
					else
						[self transitionToStatus:TGMovieRecorderStatusFinished error:nil];
				}
			}];
		}
	} );
}

- (void)dealloc
{    
	if (_audioTrackSourceFormatDescription)
		CFRelease(_audioTrackSourceFormatDescription);
	
	if (_videoTrackSourceFormatDescription)
		CFRelease(_videoTrackSourceFormatDescription);
}

- (void)setPaused:(bool)paused
{
    @synchronized (self)
    {
        _paused = paused;
        if (_paused)
            _wasPaused = true;
    }
}

- (CMSampleBufferRef)adjustTimeOfSample:(CMSampleBufferRef)sample byOffset:(CMTime)offset
{
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
    CMSampleTimingInfo *pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
    for (CMItemCount i = 0; i < count; i++)
    {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
    }
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, pInfo, &sout);
    free(pInfo);
    return sout;
}

- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer ofMediaType:(NSString *)mediaType
{
	if (sampleBuffer == NULL)
		return;
	
	@synchronized (self)
    {
		if (_status < TGMovieRecorderStatusRecording || (mediaType == AVMediaTypeAudio && !_haveStartedSession))
			return;
	}
    
    CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
	
	CFRetain(sampleBuffer);
	dispatch_async(_writingQueue, ^
    {
        CMSampleBufferRef buffer = sampleBuffer;
        
		@autoreleasepool
		{
			@synchronized (self)
			{
				if (_status > TGMovieRecorderStatusFinishingWaiting)
                {
					CFRelease(sampleBuffer);
					return;
				}
			}
			
			if (!_haveStartedSession)
            {
				[_assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
				_haveStartedSession = true;
                
                _startTimeStamp = timestamp;
			}
            
			AVAssetWriterInput *input = (mediaType == AVMediaTypeVideo) ? _videoInput : _audioInput;
            @synchronized (self)
            {
                if (_wasPaused)
                {
                    if (input == _videoInput)
                        return;
                    
                    _wasPaused = false;
                    
                    CMTime pts = CMSampleBufferGetPresentationTimeStamp(buffer);
                    CMTime last = _lastAudioTimeStamp;
                    if (last.flags & kCMTimeFlags_Valid)
                    {
                        CMTime offset = CMTimeSubtract(pts, last);
                        if (_timeOffset.value == 0)
                            _timeOffset = offset;
                        else
                            _timeOffset = CMTimeAdd(_timeOffset, offset);
                    }
                    _lastAudioTimeStamp.flags = 0;
                }
            }
            
            if (_timeOffset.value > 0 && input == _videoInput)
            {
                buffer = [self adjustTimeOfSample:buffer byOffset:_timeOffset];
                CFRelease(sampleBuffer);
            }
            
            CMTime pts = CMSampleBufferGetPresentationTimeStamp(buffer);
            CMTime duration = CMSampleBufferGetDuration(buffer);
            if (duration.value > 0)
                pts = CMTimeAdd(pts, duration);
            
            if (input == _audioInput)
                _lastAudioTimeStamp = pts;
            
			if (input.readyForMoreMediaData)
			{
				if (![input appendSampleBuffer:buffer])
                {
					NSError *error = _assetWriter.error;
					@synchronized (self)
                    {
						[self transitionToStatus:TGMovieRecorderStatusFailed error:error];
					}
				}
			}
			CFRelease(buffer);
        }
	});
}

- (void)transitionToStatus:(TGMovieRecorderStatus)newStatus error:(NSError *)error
{
	bool shouldNotifyDelegate = false;
	
	if (newStatus != _status)
	{
		if ((newStatus == TGMovieRecorderStatusFinished) || (newStatus == TGMovieRecorderStatusFailed))
		{
			shouldNotifyDelegate = true;
			
			dispatch_async(_writingQueue, ^
            {
				[self teardownAssetWriterAndInputs];
				if (newStatus == TGMovieRecorderStatusFailed)
                {
					[[NSFileManager defaultManager] removeItemAtURL:_url error:NULL];
				}
			});
		}
		else if (newStatus == TGMovieRecorderStatusRecording)
		{
			shouldNotifyDelegate = true;
		}
		
		_status = newStatus;
	}

	if (shouldNotifyDelegate)
	{
		dispatch_async(_delegateCallbackQueue, ^
        {
			@autoreleasepool
			{
				switch ( newStatus )
				{
					case TGMovieRecorderStatusRecording:
						[_delegate movieRecorderDidFinishPreparing:self];
						break;
                        
					case TGMovieRecorderStatusFinished:
						[_delegate movieRecorderDidFinishRecording:self];
						break;
                        
					case TGMovieRecorderStatusFailed:
						[_delegate movieRecorder:self didFailWithError:error];
						break;
                        
					default:
						break;
				}
			}
		});
	}
}

- (bool)setupAssetWriterAudioInputWithSourceFormatDescription:(CMFormatDescriptionRef)audioFormatDescription settings:(NSDictionary *)audioSettings
{
	if ([_assetWriter canApplyOutputSettings:audioSettings forMediaType:AVMediaTypeAudio])
	{
		_audioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioSettings sourceFormatHint:audioFormatDescription];
		_audioInput.expectsMediaDataInRealTime = true;
		
		if ([_assetWriter canAddInput:_audioInput])
		{
			[_assetWriter addInput:_audioInput];
		}
		else
		{
			return false;
		}
	}
	else
	{
		return false;
	}
	
	return true;
}

- (bool)setupAssetWriterVideoInputWithSourceFormatDescription:(CMFormatDescriptionRef)videoFormatDescription transform:(CGAffineTransform)transform settings:(NSDictionary *)videoSettings
{
	if ([_assetWriter canApplyOutputSettings:videoSettings forMediaType:AVMediaTypeVideo])
	{
		_videoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoSettings sourceFormatHint:videoFormatDescription];
		_videoInput.expectsMediaDataInRealTime = true;
		_videoInput.transform = transform;
		
		if ([_assetWriter canAddInput:_videoInput])
		{
			[_assetWriter addInput:_videoInput];
		}
		else
		{
			return false;
		}
	}
	else
	{
		return false;
	}
	
	return true;
}

- (void)teardownAssetWriterAndInputs
{
	_videoInput = nil;
	_audioInput = nil;
	_assetWriter = nil;
}

- (NSTimeInterval)videoDuration
{
    return CMTimeGetSeconds(CMTimeSubtract(_lastAudioTimeStamp, _startTimeStamp));
}

@end
