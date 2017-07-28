//
//  CBVideoPlayer.m
//  Coub
//
//  Created by Pavel Tikhonenko on 12/08/14.
//  Copyright (c) 2014 Coub. All rights reserved.
//

#import "CBVideoPlayer.h"

static void *kPlayerItemContext = (void *) 1;
static void *kPlayerStatusContext = (void *) 2;

static void *kPlayerLayerReadyToDisplayContext = (void *) 4;

@interface CBVideoPlayer ()

@property (nonatomic, strong) AVPlayerLayer *layer;
@property (nonatomic, strong) AVPlayer *videoPlayer;
@property (nonatomic, strong) AVPlayerItem *nextItem;
@property (nonatomic, assign) BOOL hasBeenReseted;

@property (nonatomic, copy) void (^prepairingCompletion)(NSError *error);

@end

@implementation CBVideoPlayer

- (id)initWithVideoLayer:(AVPlayerLayer *)layer
{
    self = [super init];
    
    if(self)
    {
		self.status = CBVideoPlayerStatusUnknown;
		self.hasBeenReseted = YES;

		self.layer = layer;

        [self createVideoPlayer];


		self.status = CBVideoPlayerStatusInited;
    }
    
    return self;
}

#pragma mark -
#pragma mark Public methods

- (void)prepareWithAVAsset:(AVAsset *)asset completion:(void (^)(NSError *error))completion
{
	self.prepairingCompletion = completion;

	self.status = CBVideoPlayerStatusPrepairing;

	if(!_hasBeenReseted)
		[self resetPlayer];

	_hasBeenReseted = NO;

	[self prepareVideoPlayer];
	[self prepareVideoLayer];

	AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
	[self.videoPlayer replaceCurrentItemWithPlayerItem:item];

}

- (void)play
{
	[_videoPlayer play];
}

- (void)pause
{
	_videoPlayer.rate = 0;
}

- (void)stop
{
	_videoPlayer.rate = 0;

	[self resetPlayer];
    [self.videoPlayer replaceCurrentItemWithPlayerItem:nil];
}

- (void)stopPrepairing
{

}

#pragma mark -
#pragma mark Private methods

- (void)createVideoPlayer
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(restartAVPlayer:)
												 name:AVPlayerItemDidPlayToEndTimeNotification object:nil];

    self.videoPlayer = [AVPlayer new];
    _videoPlayer.actionAtItemEnd = AVPlayerActionAtItemEndNone;

}

- (void)prepareVideoPlayer
{
	[_videoPlayer addObserver:self forKeyPath:@"currentItem" options:NSKeyValueObservingOptionNew context:kPlayerItemContext];
	[_videoPlayer addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:kPlayerStatusContext];
}

- (void)prepareVideoLayer
{
	[_layer addObserver:self forKeyPath:@"readyForDisplay" options:NSKeyValueObservingOptionNew context:kPlayerLayerReadyToDisplayContext];
}

- (void)resetPlayer
{
	@try{
		[_videoPlayer removeObserver:self forKeyPath:@"currentItem" context:kPlayerItemContext];
	}@catch(id anException){}

	@try{
		[_videoPlayer removeObserver:self forKeyPath:@"status" context:kPlayerStatusContext];
	}@catch(id anException){}

	@try{
		[_layer removeObserver:self forKeyPath:@"readyForDisplay" context:kPlayerLayerReadyToDisplayContext];
	}@catch(id anException){}
}

- (void)prerollPlayer
{
	[_videoPlayer prerollAtRate:1 completionHandler:^(BOOL finished) {
		[_layer setPlayer:self.videoPlayer];
	}];
}
- (void)completeVideoPrepairing
{
	[self resetPlayer];
	self.prepairingCompletion(nil);
}

- (void)restartAVPlayer:(NSNotification *)notification
{
	AVPlayerItem *playerItem = [notification object];
	if(playerItem == _videoPlayer.currentItem)
	{
		[_videoPlayer seekToTime:kCMTimeZero];
	}
}

#pragma mark -
#pragma mark Observe value

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	AVPlayer *player = (AVPlayer *) object;

	if(context == kPlayerLayerReadyToDisplayContext)
	{
		[self completeVideoPrepairing];
	}

	if(context == kPlayerStatusContext || context == kPlayerItemContext)
	{
		//KAObjectLog(@"%@ status: %i", player == self.videoPlayer ? @"videoPlayer" : @"audioPlayer", player.status);

		NSLog(@"status: %i", player.status);
		if(context == kPlayerItemContext && player.currentItem == nil && _nextItem)
			return;

		if(context == kPlayerItemContext && player.currentItem == nil)
			return;

		if(player.status == AVPlayerStatusReadyToPlay)
		{
			[self prerollPlayer];
		}else if(player.status == AVPlayerStatusFailed)
		{
			//[self.delegate playerInitialzeProccess:self completeWithError:[NSError errorWithDomain:@"com.coub.player" code:99 userInfo:nil]];

		}//else if(player.status == AVPlayerStatusUnknown)
		//KAObjectLog(@"%@ AVPlayerStatusUnknown: %@", player == self.videoPlayer ? @"videoPlayer" : @"audioPlayer", player.error);
	}
}

- (void)dealloc
{
	@try{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
	}@catch(id anException){}

	[self resetPlayer];
}
@end
