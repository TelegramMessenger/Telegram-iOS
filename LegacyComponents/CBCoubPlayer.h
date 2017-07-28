//
//  CBCoubPlayer.h
//  Coub
//
//  Created by Pavel Tikhonenko on 12/08/14.
//  Copyright (c) 2014 Coub. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CBCoubPlayer;
@protocol CBCoubAsset;
@class AVPlayerLayer;

typedef enum
{
	CBCoubPlayerStateReadyToPlay,
	CBCoubPlayerStateRunning = 1,
	CBCoubPlayerStatePlaying = (1 << 1) | CBCoubPlayerStateRunning,
	CBCoubPlayerStatePaused = (1 << 2) | CBCoubPlayerStatePlaying,
	CBCoubPlayerStateInterrupted = (1 << 3) | CBCoubPlayerStatePlaying,
	CBCoubPlayerStateStopped = (1 << 4),
	CBCoubPlayerStatePseudoStopped = (1 << 5) | CBCoubPlayerStateStopped,
	CBCoubPlayerStateError = (1 << 6) | CBCoubPlayerStateStopped,
    CBCoubPlayerStatePrepairing = (1 << 7) | CBCoubPlayerStateRunning,
	CBCoubPlayerStateUnknown = NSNotFound,
}
CBCoubPlayerState;

typedef enum
{
	CBCoubPlayerVideoPlayMethodDefault,
	CBCoubPlayerVideoPlayMethodStream
}
CBCoubPlayerVideoPlayMethod;

#pragma mark -
#pragma mark CBCoubPlayerDelegate

@protocol CBCoubPlayerDelegate <NSObject>
@required
- (void)playerReadyToPlay:(CBCoubPlayer *)player;
- (void)playerDidStartPlaying:(CBCoubPlayer *)player;
- (void)playerDidPause:(CBCoubPlayer *)player withUserAction:(BOOL)isUserAction;
- (void)playerDidResume:(CBCoubPlayer *)player;
- (void)playerDidStop:(CBCoubPlayer *)player;
- (void)playerDidFail:(CBCoubPlayer *)player error:(NSError *)error;
- (void)player:(CBCoubPlayer *)player didReachProgressWhileDownloading:(float)progress;
@end

#pragma mark -
#pragma mark CBCoubPlayer

@interface CBCoubPlayer : NSObject

@property (nonatomic, weak) id<CBCoubPlayerDelegate> delegate;

/// indicate whether player is playing
@property(nonatomic, readonly) BOOL isPlaying;
/// indicate whether player was paused
@property(nonatomic, readonly) BOOL isPaused;
/// indicate whether player was interrupted by system
@property(nonatomic, readonly) BOOL isInterrupted;
/// If Yes then this instance is current/active player
@property(nonatomic, readonly) BOOL isActivePlayer;
/// set/get current player state
@property(nonatomic, assign) CBCoubPlayerState state;

/// set/get whether player playback only video
@property(nonatomic, assign) BOOL withoutAudio; //Default NO

//Temp later move back to private var
@property(nonatomic, strong) id<CBCoubAsset> asset;

@property(nonatomic, assign) CBCoubPlayerVideoPlayMethod videoPlayMethod;



- (instancetype)initWithVideoLayer:(AVPlayerLayer *)layer;

- (void)playAsset:(id<CBCoubAsset>)asset;
- (void)pause;
- (void)resume;
- (void)stop;

// pause video and mute audio
- (void)pseudoStop;

- (BOOL)isVideoLayerPlaying:(AVPlayerLayer *)layer;
- (BOOL)coubPlaying:(id<CBCoubAsset>)coub;
- (BOOL)coubPrepairing:(id<CBCoubAsset>)coub;

+ (instancetype)activePlayer;
+ (instancetype)setActivePlayer:(CBCoubPlayer *)player;

@end
