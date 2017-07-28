#import "TGEmbedPlayerView.h"

@interface TGEmbedCoubPlayerView : TGEmbedPlayerView

+ (NSString *)_coubVideoIdFromText:(NSString *)text;

+ (NSDictionary *)coubJSONByPermalink:(NSString *)permalink;
+ (void)setCoubJSON:(NSDictionary *)json forPermalink:(NSString *)permalink;

@end
