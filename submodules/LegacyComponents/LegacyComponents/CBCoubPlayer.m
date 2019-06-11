//
//  CBCoubPlayer.m
//  Coub
//
//  Created by Pavel Tikhonenko on 12/08/14.
//  Copyright (c) 2014 Coub. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "CBCoubPlayer.h"
#import "CBCoubAsset.h"
#import "CBVideoPlayer.h"
#import "CBCoubLoopCompositionMaker.h"
#import "CBAssetDownloadManager.h"
#import "STKAudioPlayer.h"
#import "CBLibrary.h"
#import "CBConstance.h"
#import "CBDownloadOperationDelegate.h"

static CBCoubPlayer *gActivePlayer = nil;
static NSLock *gLock = nil;
static BOOL gPlaybackIsInterrupted = NO;

@interface CBCoubPlayer ()<CBDownloadOperationDelegate, STKAudioPlayerDelegate, CBCoubLoopDelegate>
{
	BOOL _shouldPlayWhenReady;
	BOOL _shouldResumeWhenAppIsActive;
	BOOL _shouldResumeWhenInterruptionEnds;
    BOOL _shouldPlayAfterStop;
	NSInteger _currentPlayingChunk;
	double _startTime;
}


@property(nonatomic, strong) CBVideoPlayer *videoPlayer;
@property(nonatomic, strong) STKAudioPlayer *audioPlayer;
@property(nonatomic, strong) CBCoubLoopCompositionMaker *loopMaker;


@end

@implementation CBCoubPlayer

+ (void)initialize
{
	if(!gLock)
	{
		NSError *categoryError = NULL;
		NSError *activeError = NULL;

        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&categoryError];
        [[AVAudioSession sharedInstance] setActive:YES error:&activeError];

        Float32 bufferLength = 0.1;
        AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration, sizeof(bufferLength), &bufferLength);
    
		gLock = [[NSLock alloc] init];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pauseActivePlayer:) name:UIApplicationWillResignActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resumeActivePlayer:) name:UIApplicationDidBecomeActiveNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pauseActivePlayer:) name:CBPlayerInterruptionDidBeginNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resumeActivePlayer:) name:CBPlayerInterruptionDidEndNotification object:nil];
	}
}

- (instancetype)initWithVideoLayer:(AVPlayerLayer *)layer
{
	return [self initWithVideoLayer:layer videoPlayMethod:CBCoubPlayerVideoPlayMethodDefault];
}

- (instancetype)initWithVideoLayer:(AVPlayerLayer *)layer videoPlayMethod:(CBCoubPlayerVideoPlayMethod)videoPlayMethod
{
	self = [super init];

	if(self)
	{
		_currentPlayingChunk = -1;
		_videoPlayMethod = videoPlayMethod;
		_state = CBCoubPlayerStateUnknown;

		[self createVideoPlayerWithLayer:layer];

	}

	return self;
}

#pragma mark -
#pragma mark Getter/Setter

- (BOOL)isPlaying
{
	return _state == CBCoubPlayerStatePlaying;
}

- (BOOL)isPaused
{
	return _state == CBCoubPlayerStatePaused;
}

- (BOOL)isActivePlayer
{
	return (gActivePlayer == self);
}

#pragma mark -
#pragma mark Public methods

- (void)playAsset:(id<CBCoubAsset>)asset
{
    NSLog(@"playAsset");
    
	if(_state == CBCoubPlayerStateRunning && self.asset == asset)
		return;

	if(gActivePlayer == self && self.asset == asset && gActivePlayer.state == CBCoubPlayerStatePlaying)
		return;

	[[NSNotificationCenter defaultCenter] postNotificationName:@"interruptDownloading" object:nil];

	//_startTime = [CBUtils timestamp];

	if(gActivePlayer == self)
	{
		[_videoPlayer stop];
		[_audioPlayer dispose];
	}else{
		[self stopActivePlayer];
		[self becomeActivePlayer];
	}

	gPlaybackIsInterrupted = NO; //NOTE: note note note
	_shouldPlayWhenReady = YES;
	self.state = CBCoubPlayerStateRunning;

	self.asset = asset;

	[self downloadMediaAssetsWithCompletion:^(__unused id result) {
		[self prepareLoopCompostion];
	}failure:^(NSError *error) {
		[self failPlaybackWithError:error];
	}];
}

- (void)pause
{
	_shouldPlayWhenReady = NO;

	if(!self.isPlaying)
		return;

	self.state = CBCoubPlayerStatePaused;

	[_videoPlayer pause];

	if(_asset.audioType == CBCoubAudioTypeExternal)
		[_audioPlayer pause];

	if([_delegate respondsToSelector:@selector(playerDidPause:withUserAction:)])
		[_delegate playerDidPause:self withUserAction:YES];
}

- (void)resume
{
	_shouldPlayWhenReady = YES;

//	if(_state == CBCoubPlayerStateReadyToPlay)
//	{
//		[self startPlayingIfPossible];
//	}
    if(self.state == CBCoubPlayerStatePaused){
		self.state = STKAudioPlayerStatePlaying;

		[_videoPlayer play];

		if(_asset.audioType == CBCoubAudioTypeExternal)
			[_audioPlayer resume];
	}

	if([_delegate respondsToSelector:@selector(playerDidResume:)])
		[_delegate playerDidResume:self];
}

- (void)stop
{
	_shouldPlayWhenReady = NO;

	if(self.state == CBCoubPlayerStateStopped || self.state == NSNotFound)
		return;

	//KAObjectLog(@"stop player");

	//[[CBAssetDownloadManager sharedManager] cancelDownloadingForCoub:_asset];

	if([_delegate respondsToSelector:@selector(playerDidStop:)])
		[_delegate playerDidStop:self];

//	[_audioPlayer pause];
	if(_asset.audioType == CBCoubAudioTypeExternal)
	{
		_audioPlayer.delegate = nil;
		[_audioPlayer dispose];
		_audioPlayer = nil;
	}

	[_videoPlayer stop];

//	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//
//    });

	self.state = CBCoubPlayerStateStopped;

	[self resignActivePlayer];
}

- (void)pseudoStop
{
	_shouldPlayWhenReady = NO;

	if(self.isPlaying)
	{
		if(_asset.audioType == CBCoubAudioTypeExternal)
			[_audioPlayer pause];
		else
			[_videoPlayer pause];
	}

	self.state = CBCoubPlayerStatePseudoStopped;
}

- (void)stopActivePlayer
{
	[gActivePlayer stop];
}

- (void)resetCurrentPlayer
{
	self.state = NSNotFound;
	_shouldPlayWhenReady = YES;
	_currentPlayingChunk = -1;
	[self.loopMaker cancelPrepareLoop];
}

#pragma mark -
#pragma mark Private methods

- (void)createVideoPlayerWithLayer:(AVPlayerLayer *)layer
{
	self.videoPlayer = [[CBVideoPlayer alloc] initWithVideoLayer:layer];
}

- (void)prepareVideoPlayer
{
	[_videoPlayer prepareWithAVAsset:self.loopMaker.videoAsset completion:^(NSError *error) {
		if(error)
			[self failPlaybackWithError:error];
		else{
			if([_delegate respondsToSelector:@selector(playerReadyToPlay:)])
				[_delegate playerReadyToPlay:self];

			[self startPlayingIfPossible];
		}
	}];
    
    [self.loopMaker cancelPrepareLoop];
}

- (void)playVideoPlayer
{
	[_videoPlayer play];

	if(_shouldPlayWhenReady == NO)
		[self pause];
}

- (void)createAudioPlayer
{
	self.audioPlayer = [[STKAudioPlayer alloc] init];
	_audioPlayer.delegate = self;
}

- (void)prepareAudioPlayer
{
	_currentPlayingChunk = -1;

//	STKAudioPlayerState state = _audioPlayer.state;

	[self startPlayingFirstAudioChunk];
}

- (void)startPlayingFirstAudioChunk
{
//	NSFileManager *fileManager = [NSFileManager defaultManager];
//	NSDictionary *attributes = [fileManager attributesOfItemAtPath:[_asset localAudioChunkWithIdx:0].path error:nil];

	_shouldPlayAfterStop = NO;

	NSURL * url = [_asset localAudioChunkWithIdx:0];

	if (url) {
		[_audioPlayer playURL:url];
	}
}

- (void)startPlayingIfPossible
{
	if(self.state == CBCoubPlayerStatePlaying)
		return;

	self.state = CBCoubPlayerStateReadyToPlay;

	if(gPlaybackIsInterrupted && _shouldPlayWhenReady)
		[self pauseWhileInterrupted];

	if(!_shouldPlayWhenReady)
		return;

	if(!_withoutAudio && _asset.audioType == CBCoubAudioTypeExternal && _audioPlayer.state != STKAudioPlayerStatePlaying)
	{
        [self createAudioPlayer];
		[self prepareAudioPlayer];
		return;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:@"resumeDownloading" object:nil];

	self.state = CBCoubPlayerStatePlaying;

	if([_delegate respondsToSelector:@selector(playerDidStartPlaying:)])
		[_delegate playerDidStartPlaying:self];


	[self playVideoPlayer];

//    NSNumber *number = [NSNumber numberWithDouble:[CBUtils timestamp] - _startTime];
//    NSString *curPlace = [CBAnalyticManager sharedManager].currentPlayerPlace;
//    NSString *assetId = _asset.assetId;
//    
//    NSDictionary *dict = @{@"loading_time":number,
//                           @"coubId":assetId,
//                           @"place": curPlace};
//    
//	[[CBAnalyticManager sharedManager] track:@"player_started"
//								  properties:dict
//									  method:CBAnalyticManagerMethodCES];
}

- (void)downloadMediaAssetsWithCompletion:(CBSuccessBlock)success failure:(CBFailureBlock)failure
{
    [[CBAssetDownloadManager sharedManager] downloadCoub:_asset tag:-1
                                            withDelegate:self
                                              withChunks:!_withoutAudio
                                          downloadSucces:^(__unused id<CBCoubAsset> coub, __unused NSInteger tag) {
		success(nil);
	}downloadFailure:^(__unused id<CBCoubAsset> coub, __unused NSInteger tag, NSError *error) {
		failure(error);
	}];
}

- (void)downloadChunk:(NSInteger)idx
{
	if(_asset.audioType != CBCoubAudioTypeExternal)
		return;

	[[CBAssetDownloadManager sharedManager] downloadChunkWithCoub:_asset tag:NSNotFound chunkIdx:idx downloadSucces:^(id<CBCoubAsset> __unused coub, NSInteger __unused tag) {
		[_audioPlayer queueURL:[_asset localAudioChunkWithIdx:idx]];
	} downloadFailure:^(__unused id<CBCoubAsset> coub, __unused NSInteger tag, __unused NSError *error) {
        
	}];

//	[[CBAssetDownloadManager sharedManager] downloadNextChunkWithCoub:_asset downloadSucces:^(id<CBDownloadAsset> coub, NSInteger tag) {
//		[_audioPlayer queueURL:[_asset localAudioChunkWithIdx:tag]];
//	} downloadFailure:^(id<CBDownloadAsset> coub, NSInteger tag, NSError *error) {
//
//	}];
}

- (void)prepareLoopCompostion
{
	if(self.state == CBCoubPlayerStateStopped)
		return;

	self.loopMaker = [CBCoubLoopCompositionMaker coubLoopWithAsset:_asset];
	_loopMaker.delegate = self;
	[_loopMaker prepareLoop];
}

- (void)failPlaybackWithError:(NSError *)error
{
	if(self.state == CBCoubPlayerStateStopped)
		return;

	self.state = CBCoubPlayerStateError;

	if([_delegate respondsToSelector:@selector(playerDidFail:error:)])
		[_delegate playerDidFail:self error:error];
}

#pragma mark -

- (void)becomeActivePlayer
{
	[gLock lock];
	if(gActivePlayer != self)
	{
		//[gActivePlayer pause];
		gActivePlayer = self;
	}
	[gLock unlock];
}


- (void)resignActivePlayer
{
	[gLock lock];
	if(gActivePlayer == self && self.isPlaying == NO)
		gActivePlayer = nil;
	[gLock unlock];
}

#pragma mark -
#pragma mark Audio Player Delegate methods

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer stateChanged:(STKAudioPlayerState)state previousState:(STKAudioPlayerState)previousState
{
    if(state == STKAudioPlayerStateStopped && _shouldPlayAfterStop)
    {
        [self startPlayingFirstAudioChunk];
        return;
    }
    
	if(state == STKAudioPlayerStatePlaying && self.state != CBCoubPlayerStatePlaying)
	{
		//KAObjectLog(@"STKAudioPlayerStatePlaying");

		[self startPlayingIfPossible];
	}
}

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer unexpectedError:(STKAudioPlayerErrorCode)errorCode
{
	[self failPlaybackWithError:nil];
}

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didStartPlayingQueueItemId:(NSObject *)queueItemId
{
	if(_currentPlayingChunk == 3)
		_currentPlayingChunk = -1;

	_currentPlayingChunk++;

	NSInteger nextItem = _currentPlayingChunk+1;
	nextItem = nextItem > 3 ? 0 : nextItem;

	if([[CBLibrary sharedLibrary] isCoubChunkDownloadedByPermalink:_asset.assetId idx:nextItem])
		[_audioPlayer queueURL:[_asset localAudioChunkWithIdx:nextItem]];
	else
		[self downloadChunk:nextItem];
}

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didFinishBufferingSourceWithQueueItemId:(NSObject *)queueItemId
{

}

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didFinishPlayingQueueItemId:(NSObject *)queueItemId withReason:(STKAudioPlayerStopReason)stopReason andProgress:(double)progress andDuration:(double)duration
{

}

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer logInfo:(NSString *)line
{
	//KAObjectLog(@"%@", line);
}

#pragma mark -
#pragma mark Download Manager Delegate methods

- (void)downloadDidReachProgress:(float)progress
{
	if([_delegate respondsToSelector:@selector(player:didReachProgressWhileDownloading:)])
		[_delegate player:self didReachProgressWhileDownloading:progress];
}

- (void)downloadHasBeenCancelledWithError:(NSError *)error
{
	if(error == nil)
		return;

	[self failPlaybackWithError:error];
}

#pragma mark -
#pragma mark Loop Composition Maker Delegate methods

- (void)coubLoopDidFinishPreparing:(CBCoubLoopCompositionMaker *)loop
{
	[self prepareVideoPlayer];
}

- (void)coubLoop:(CBCoubLoopCompositionMaker *)loop didFailToLoadWithError:(NSError *)error
{
	if(error.code == CBCoubLoopErrorCanceled)
		return;

	[self failPlaybackWithError:error];
}

#pragma mark -

+ (void)pauseActivePlayer:(NSNotification *)notification
{
	//KAObjectLog(@"pauseActivePlayer %p", gActivePlayer);

	if([[notification name] isEqualToString:UIApplicationWillResignActiveNotification])
	{
		[gActivePlayer pauseWhileInBackground];
	}else
	{
		gPlaybackIsInterrupted = YES;
		[gActivePlayer pauseWhileInterrupted];
	}
}


+ (void)resumeActivePlayer:(NSNotification *)notification
{
	//KAObjectLog(@"resumeActivePlayer %p", gActivePlayer);

    NSLog(@"resumeActivePlayer");
    
	if([[notification name] isEqualToString:UIApplicationDidBecomeActiveNotification])
	{
		[gActivePlayer resumeIfPausedWhileInBackground];
	}else
	{
		gPlaybackIsInterrupted = NO;
		[gActivePlayer resumeIfPausedWhileInterrupted];
	}
}

- (void)pauseWhileInBackground
{
	_shouldResumeWhenAppIsActive = self.isPlaying || _shouldPlayWhenReady;
	[self pause];
}


- (void)resumeIfPausedWhileInBackground
{
    NSLog(@"resumeIfPausedWhileInBackground");
    
	if(_shouldResumeWhenAppIsActive)
		[self resume];
}


- (void)pauseWhileInterrupted
{
	_shouldResumeWhenInterruptionEnds = self.isPlaying || _shouldPlayWhenReady;
	[self pause];
}


- (void)resumeIfPausedWhileInterrupted
{
	if(_shouldResumeWhenInterruptionEnds)
		[self resume];
}

#pragma mark -

+ (instancetype)activePlayer
{
	return gActivePlayer;
}

- (void)dealloc
{
	_audioPlayer.delegate = nil;
	[_audioPlayer dispose];
}

@end
