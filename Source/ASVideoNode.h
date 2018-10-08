//
//  ASVideoNode.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#ifndef MINIMAL_ASDK
#import <AsyncDisplayKit/ASNetworkImageNode.h>

@class AVAsset, AVPlayer, AVPlayerLayer, AVPlayerItem, AVVideoComposition, AVAudioMix;
@protocol ASVideoNodeDelegate;

typedef NS_ENUM(NSInteger, ASVideoNodePlayerState) {
  ASVideoNodePlayerStateUnknown,
  ASVideoNodePlayerStateInitialLoading,
  ASVideoNodePlayerStateReadyToPlay,
  ASVideoNodePlayerStatePlaybackLikelyToKeepUpButNotPlaying,
  ASVideoNodePlayerStatePlaying,
  ASVideoNodePlayerStateLoading,
  ASVideoNodePlayerStatePaused,
  ASVideoNodePlayerStateFinished
};

NS_ASSUME_NONNULL_BEGIN

// IMPORTANT NOTES:
// 1. Applications using ASVideoNode must link AVFoundation! (this provides the AV* classes below)
// 2. This is a relatively new component of AsyncDisplayKit.  It has many useful features, but
//    there is room for further expansion and optimization.  Please report any issues or requests
//    in an issue on GitHub: https://github.com/facebook/AsyncDisplayKit/issues

@interface ASVideoNode : ASNetworkImageNode

- (void)play;
- (void)pause;
- (BOOL)isPlaying;
- (void)resetToPlaceholder;

// TODO: copy
@property (nullable) AVAsset *asset;

/**
 ** @abstract The URL with which the asset was initialized.
 ** @discussion Setting the URL will override the current asset with a newly created AVURLAsset created from the given URL, and AVAsset *asset will point to that newly created AVURLAsset.  Please don't set both assetURL and asset.
 ** @return Current URL the asset was initialized or nil if no URL was given.
 **/
@property (nullable, copy) NSURL *assetURL;

// TODO: copy both of these.
@property (nullable) AVVideoComposition *videoComposition;
@property (nullable) AVAudioMix *audioMix;

@property (nullable, readonly) AVPlayer *player;

// TODO: copy
@property (nullable, readonly) AVPlayerItem *currentItem;

@property (nullable, nonatomic, readonly) AVPlayerLayer *playerLayer;


/**
 * When shouldAutoplay is set to true, a video node will play when it has both loaded and entered the "visible" interfaceState.
 * If it leaves the visible interfaceState it will pause but will resume once it has returned.
 */
@property BOOL shouldAutoplay;
@property BOOL shouldAutorepeat;

@property BOOL muted;
@property BOOL shouldAggressivelyRecoverFromStall;

@property (readonly) ASVideoNodePlayerState playerState;
//! Defaults to 1000
@property int32_t periodicTimeObserverTimescale;

//! Defaults to AVLayerVideoGravityResizeAspect
@property (null_resettable, copy) NSString *gravity;

@property (nullable, weak) id<ASVideoNodeDelegate, ASNetworkImageNodeDelegate> delegate;

@end

@protocol ASVideoNodeDelegate <ASNetworkImageNodeDelegate>
@optional
/**
 * @abstract Delegate method invoked when the node's video has played to its end time.
 * @param videoNode The video node has played to its end time.
 */
- (void)videoDidPlayToEnd:(ASVideoNode *)videoNode;
/**
 * @abstract Delegate method invoked the node is tapped.
 * @param videoNode The video node that was tapped.
 * @discussion The video's play state is toggled if this method is not implemented.
 */
- (void)didTapVideoNode:(ASVideoNode *)videoNode;
/**
 * @abstract Delegate method invoked when player changes state.
 * @param videoNode The video node.
 * @param state player state before this change.
 * @param toState player new state.
 * @discussion This method is called after each state change
 */
- (void)videoNode:(ASVideoNode *)videoNode willChangePlayerState:(ASVideoNodePlayerState)state toState:(ASVideoNodePlayerState)toState;
/**
 * @abstract Ssks delegate if state change is allowed
 * ASVideoNodePlayerStatePlaying or ASVideoNodePlayerStatePaused.
 * asks delegate if state change is allowed.
 * @param videoNode The video node.
 * @param state player state that is going to be set.
 * @discussion Delegate method invoked when player changes it's state to
 * ASVideoNodePlayerStatePlaying or ASVideoNodePlayerStatePaused
 * and asks delegate if state change is valid
 */
- (BOOL)videoNode:(ASVideoNode*)videoNode shouldChangePlayerStateTo:(ASVideoNodePlayerState)state;
/**
 * @abstract Delegate method invoked when player playback time is updated.
 * @param videoNode The video node.
 * @param timeInterval current playback time in seconds.
 */
- (void)videoNode:(ASVideoNode *)videoNode didPlayToTimeInterval:(NSTimeInterval)timeInterval;
/**
 * @abstract Delegate method invoked when the video player stalls.
 * @param videoNode The video node that has experienced the stall
 * @param timeInterval Current playback time when the stall happens
 */
- (void)videoNode:(ASVideoNode *)videoNode didStallAtTimeInterval:(NSTimeInterval)timeInterval;
/**
 * @abstract Delegate method invoked when the video player starts the inital asset loading
 * @param videoNode The videoNode
 */
- (void)videoNodeDidStartInitialLoading:(ASVideoNode *)videoNode;
/**
 * @abstract Delegate method invoked when the video is done loading the asset and can start the playback
 * @param videoNode The videoNode
 */
- (void)videoNodeDidFinishInitialLoading:(ASVideoNode *)videoNode;
/**
 * @abstract Delegate method invoked when the AVPlayerItem for the asset has been set up and can be accessed throught currentItem.
 * @param videoNode The videoNode.
 * @param currentItem The AVPlayerItem that was constructed from the asset.
 */
- (void)videoNode:(ASVideoNode *)videoNode didSetCurrentItem:(AVPlayerItem *)currentItem;
/**
 * @abstract Delegate method invoked when the video node has recovered from the stall
 * @param videoNode The videoNode
 */
- (void)videoNodeDidRecoverFromStall:(ASVideoNode *)videoNode;
/**
 * @abstract Delegate method invoked when an error occurs while trying trying to load an asset
 * @param videoNode The videoNode.
 * @param key The key of value that failed to load.
 * @param asset The asset.
 * @param error The error that occurs.
 */
- (void)videoNode:(ASVideoNode *)videoNode didFailToLoadValueForKey:(NSString *)key asset:(AVAsset *)asset error:(NSError *)error;

@end

@interface ASVideoNode (Unavailable)

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(nullable ASDisplayNodeDidLoadBlock)didLoadBlock NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
#endif
