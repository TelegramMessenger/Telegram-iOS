#import "TGEmbedPlayerState.h"

@implementation TGEmbedPlayerState

@synthesize playing = _playing;
@synthesize duration = _duration;
@synthesize position = _position;
@synthesize downloadProgress = _downloadProgress;

+ (instancetype)stateWithPlaying:(bool)playing
{
    TGEmbedPlayerState *state = [[TGEmbedPlayerState alloc] init];
    state->_playing = playing;
    return state;
}

+ (instancetype)stateWithPlaying:(bool)playing duration:(NSTimeInterval)duration position:(NSTimeInterval)position downloadProgress:(CGFloat)downloadProgress
{
    TGEmbedPlayerState *state = [[TGEmbedPlayerState alloc] init];
    state->_playing = playing;
    state->_duration = duration;
    state->_position = position;
    state->_downloadProgress = downloadProgress;
    return state;
}

@end
