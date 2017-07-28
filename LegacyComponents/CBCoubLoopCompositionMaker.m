//
// Created by Tikhonenko Pavel on 26/11/2013.
// Copyright (c) 2013 Coub. All rights reserved.
//


#import <CoreMedia/CoreMedia.h>
#import "CBCoubLoopCompositionMaker.h"
#import "CBCoubAsset.h"
#import "CBConstance.h"
#import "AVAsset+CBExtension.h"

#pragma mark -
#pragma mark CBCoubLoopOperation

static AVURLAsset *gDigitalSilenceAsset = nil;

@interface CBCoubLoopOperation : NSOperation

- (id)initWithCoubAsset:(id<CBCoubAsset>)asset loop:(CBCoubLoopCompositionMaker *)loop;

- (void)prepareOperation;
- (void)makeLoop;
- (AVComposition *)makeLoopComposition;

- (BOOL)checkAssetURL:(NSURL *)assetURL;

- (void)completeWithError:(NSError *)error;

@end

@implementation CBCoubLoopOperation
{
@private
	id<CBCoubAsset> _asset;
	CBCoubLoopCompositionMaker *_loop;
	AVAssetExportSession *_exportSession;

	NSURL *_assetURL;
	BOOL _hasExternalAudio;
}

- (id)initWithCoubAsset:(id<CBCoubAsset>)asset loop:(CBCoubLoopCompositionMaker *)loop
{
	self = [super init];
	if(self)
	{
		_asset = asset;
		_loop = loop;
	}
	return self;
}

- (void)main
{
	if([self isCancelled])
		return;

	[self prepareOperation];
}

- (void)prepareOperation
{
	if(![self checkAssetURL:_asset.localVideoFileURL])
		return;

	_assetURL = _asset.localVideoFileURL;
    _hasExternalAudio = _asset.externalAudioURL != nil;
    
	[self makeLoop];
}

- (void)makeLoop
{
	AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:_assetURL options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @YES}];
//	_loop.videoAsset = avAsset;
//	[self completeWithError:nil];
//	return;
	if(_asset.audioType == CBCoubAudioTypeInternal)
	{
		AVComposition *composition = [self makeLoopComposition];
		if(![self isCancelled])
		{
			_loop.videoAsset = composition;
			[self completeWithError:nil];
		}else{

		}
			
	}else{
		_loop.videoAsset = avAsset;
		[self completeWithError:nil];
	}
		
}

- (AVComposition *)makeLoopComposition
{
	AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:_assetURL options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @YES}];
	NSArray *videoTracks = [avAsset tracksWithMediaType:AVMediaTypeVideo];
	if([videoTracks count] == 0)
	{
		
		//TODO: remove cache file and download again

		NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain
										 code:CBCoubLoopErrorNoVideoTracks
									 userInfo:_assetURL ? @{NSURLErrorKey : _assetURL} : nil];
		
		[self completeWithError:error];

		return nil;
	}

	if([self isCancelled])
		return nil;

	AVAssetTrack *originalVideoTrack = videoTracks[0];
	AVAssetTrack *originalAudioTrack = _hasExternalAudio ? nil : avAsset.anyAudioTrack;

	if(originalVideoTrack == nil)
	{
		NSError *error = [NSError errorWithDomain:CBCoubLoopErrorDomain
										 code:CBCoubLoopErrorNoVideoTracks
									 userInfo:nil];
		[self completeWithError:error];
		return nil;
	}

	CMTimeRange videoTrackTimeRange = originalVideoTrack.timeRange;
//	videoTrackTimeRange.start.value = 1;
//	videoTrackTimeRange.duration.value -= 2;

	CMTimeRange audioTrackTimeRange = originalAudioTrack ? originalAudioTrack.timeRange : kCMTimeRangeZero;
//	if(originalAudioTrack)
//	{
//		audioTrackTimeRange.start.value = 1;
//		audioTrackTimeRange.duration.value -= 2;
//	}

	// Calculate the minimum duration of our composition
	CMTime minimumCompositionDuration = CMTimeMake(60*audioTrackTimeRange.start.timescale, audioTrackTimeRange.start.timescale);

	if(!_hasExternalAudio)
	{
		if(originalAudioTrack)
			audioTrackTimeRange = CMTimeRangeGetIntersection(audioTrackTimeRange, videoTrackTimeRange);
	}

	AVAssetTrack *silence = nil;
	CMTimeRange silenceTimeRange = kCMTimeRangeZero;
	//	if(originalAudioTrack && CMTIME_COMPARE_INLINE(audioTrackTimeRange.duration, <, videoTrackTimeRange.duration))
	//	{
	//		if(!gDigitalSilenceAsset)
	//			gDigitalSilenceAsset = [[AVURLAsset alloc] initWithURL:[[NSBundle mainBundle] URLForResource:@"silence2" withExtension:@"caf"] options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @YES}];
	//		silence = gDigitalSilenceAsset.anyAudioTrack;
	//		silenceTimeRange.duration = CMTimeSubtract(videoTrackTimeRange.duration, audioTrackTimeRange.duration);
	//	}

	if([self isCancelled])
		return nil;

	AVMutableComposition *composition = [AVMutableComposition composition];
	AVMutableCompositionTrack *videoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
	AVMutableCompositionTrack *audioTrack = originalAudioTrack ? [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid] : nil;

	CMTime videoTrackDuration = kCMTimeZero;
	NSError *error = nil;
	while(CMTIME_COMPARE_INLINE(videoTrackDuration, <, minimumCompositionDuration))
	{
		if([self isCancelled])
			return nil;

		if(![videoTrack insertTimeRange:videoTrackTimeRange ofTrack:originalVideoTrack atTime:videoTrackDuration error:&error])
		{
//			KAObjectLogError(@"Failed to insert %@ of video track %@ at %@: %@", CBStringFromTimeRange(videoTrackTimeRange), originalVideoTrack, CBStringFromTime(videoTrackDuration), error);
			[self completeWithError:error];
			return nil;
		}
		if(audioTrack)
		{
			if(![audioTrack insertTimeRange:audioTrackTimeRange ofTrack:originalAudioTrack atTime:videoTrackDuration error:&error])
			{

//				KAObjectLogError(@"Failed to insert %@ of audio track %@ at %@: %@", CBStringFromTimeRange(audioTrackTimeRange), originalAudioTrack, CBStringFromTime(videoTrackDuration), error);
				[self completeWithError:error];
				return nil;
			}
		}
		if(silence)
		{
			if(![audioTrack insertTimeRange:silenceTimeRange ofTrack:silence atTime:CMTimeAdd(videoTrackDuration, audioTrackTimeRange.duration) error:&error])
			{
				[self completeWithError:error];
				return nil;
			}
		}
		videoTrackDuration = CMTimeAdd(videoTrackDuration, videoTrackTimeRange.duration);
	}

	videoTrack.preferredTransform = originalVideoTrack.preferredTransform;
	return composition;
}

- (BOOL)checkAssetURL:(NSURL *)assetURL
{
	if (assetURL == nil || ([assetURL isFileURL] && ![[NSFileManager defaultManager] fileExistsAtPath: [assetURL path]]))
	{
		NSLog(@"File doesn't exist: %@", assetURL);
		//TODO: remove cache file and download again

		NSError *error = [NSError errorWithDomain:CBCoubLoopErrorDomain
											 code:CBCoubLoopErrorNoSuchFile
										 userInfo:assetURL ? @{NSURLErrorKey : assetURL} : nil];
		[self completeWithError:error];
		return NO;
	}else{
		return YES;
	}
}

- (void)cancel
{
	[_exportSession cancelExport];
	[super cancel];
}

- (void)completeWithError:(NSError *)error
{
	dispatch_async(dispatch_get_main_queue(), ^
	{
		[_exportSession cancelExport];

		_loop.error = error;
		[_loop notifyObservers];
	});
}
@end

#pragma mark -
#pragma mark CBCoubLoop

static NSOperationQueue *gOperationQueue = nil;

@implementation CBCoubLoopCompositionMaker
{
@private
	CBCoubLoopOperation *_operation;
}

+ (void)initialize
{
	if(!gOperationQueue)
	{
		gOperationQueue = [NSOperationQueue new];
		[gOperationQueue setMaxConcurrentOperationCount:1];
	}
}

- (id)initWithAsset:(id<CBCoubAsset>)asset
{
	self = [super init];

	if(self)
	{
		_asset = asset;
	}

	return self;
}

- (BOOL)hasAudio
{
	return !(_asset.audioType == CBCoubAudioTypeNone);
}

- (void)prepareLoop
{
	if(gOperationQueue.operations.count)
		[gOperationQueue cancelAllOperations];

	if(!_operation)
	{
		self.error = nil;

		CBCoubLoopOperation *operation = [[CBCoubLoopOperation alloc] initWithCoubAsset:_asset loop:self];
		[gOperationQueue addOperation:operation];

		_operation = operation;
		//[_operation start];
	}
}

- (void)cancelPrepareLoop
{
    self.videoAsset = nil;
    
	[_operation cancel];
	_operation = nil;

	self.error = [NSError errorWithDomain:CBCoubLoopErrorDomain
										 code:CBCoubLoopErrorCanceled
									 userInfo:nil];
	[_delegate coubLoop:self didFailToLoadWithError:self.error];

}

- (void)notifyObservers
{
	NSAssert([NSThread isMainThread], @"%s must be called on the main thread", __PRETTY_FUNCTION__);

	if(self.error)
		[_delegate coubLoop:self didFailToLoadWithError:self.error];
	else
	{
		_loopReady = YES;
		[_delegate coubLoopDidFinishPreparing:self];
	}

	_operation = nil;
}

+ (instancetype)coubLoopWithAsset:(id<CBCoubAsset>)asset
{
	CBCoubLoopCompositionMaker *instance = [[CBCoubLoopCompositionMaker alloc] initWithAsset:asset];
	return instance;
}

@end