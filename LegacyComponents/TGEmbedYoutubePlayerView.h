#import "TGEmbedPlayerView.h"

@interface TGEmbedYoutubePlayerView : TGEmbedPlayerView

+ (NSString *)_youtubeVideoIdFromText:(NSString *)text originalUrl:(NSString *)originalUrl startTime:(NSTimeInterval *)startTime;

@end
