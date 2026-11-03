#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SSignalKit/SSignalKit.h>

@class TGEmbedPIPPlaceholderView;
@protocol TGPIPAblePlayerView;

typedef enum
{
    TGEmbedPIPCornerNone,
    TGEmbedPIPCornerTopLeft,
    TGEmbedPIPCornerTopRight,
    TGEmbedPIPCornerBottomRight,
    TGEmbedPIPCornerBottomLeft
} TGEmbedPIPCorner;

@protocol TGPIPAblePlayerState

@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSTimeInterval position;
@property (nonatomic, readonly) CGFloat downloadProgress;
@property (nonatomic, readonly) bool buffering;

@property (nonatomic, readonly, getter=isPlaying) bool playing;

@end

@protocol TGPIPAblePlayerContainerView

- (TGEmbedPIPPlaceholderView *)pipPlaceholderView;
- (void)reattachPlayerView:(UIView<TGPIPAblePlayerView> *)playerView;
- (bool)shouldReattachPlayerBeforeTransition;

@end

@protocol TGPIPAblePlayerView <NSObject>

@property (nonatomic, copy) void (^requestPictureInPicture)(TGEmbedPIPCorner corner);

- (void)playVideo;
- (void)pauseVideo;

- (void)seekToPosition:(NSTimeInterval)position;
- (void)seekToFractPosition:(CGFloat)position;

- (id<TGPIPAblePlayerState>)state;
- (SSignal *)stateSignal;

@property (nonatomic, assign) bool disallowPIP;
- (bool)supportsPIP;
- (void)switchToPictureInPicture;

- (void)_requestSystemPictureInPictureMode;
- (void)_prepareToEnterFullscreen;
- (void)_prepareToLeaveFullscreen;

- (void)resumePIPPlayback;
- (void)pausePIPPlayback;

- (void)beginLeavingFullscreen;
- (void)finishedLeavingFullscreen;

@property (nonatomic, assign) CGRect initialFrame;

@end
