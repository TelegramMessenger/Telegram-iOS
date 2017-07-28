#import <Foundation/Foundation.h>
#import "TGPIPAblePlayerView.h"

@interface TGEmbedPlayerState : NSObject <TGPIPAblePlayerState>

+ (instancetype)stateWithPlaying:(bool)playing;
+ (instancetype)stateWithPlaying:(bool)playing duration:(NSTimeInterval)duration position:(NSTimeInterval)position downloadProgress:(CGFloat)downloadProgress;

@end
