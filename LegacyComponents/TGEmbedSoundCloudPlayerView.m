#import "TGEmbedSoundCloudPlayerView.h"

@implementation TGEmbedSoundCloudPlayerView

- (instancetype)initWithWebPageAttachment:(TGWebPageMediaAttachment *)webPage thumbnailSignal:(SSignal *)thumbnailSignal
{
    self = [super initWithWebPageAttachment:webPage thumbnailSignal:thumbnailSignal];
    if (self != nil)
    {
        
    }
    return self;
}

- (NSURL *)_embedURL
{
    NSString *trackId = [TGEmbedSoundCloudPlayerView _soundCloudIdFromText:_webPage.embedUrl];
    
    NSString *url = [NSString stringWithFormat:@"https://w.soundcloud.com/player/?url=https%%3A%%2F%%2Fapi.soundcloud.com%%2Ftracks%%2F%@&auto_play=true&show_artwork=true&visual=true&liking=false&download=false&sharing=false&buying=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false", trackId];
    return [NSURL URLWithString:url];
}

+ (NSString *)_soundCloudIdFromText:(NSString *)text
{
    NSMutableArray *prefixes = [NSMutableArray arrayWithArray:@
    [
        @"http://w.soundcloud.com/player/?url=",
        @"https://w.soundcloud.com/player/?url="
    ]];
    
    NSString *prefix = nil;
    for (NSString *p in prefixes)
    {
        if ([text hasPrefix:p])
        {
            prefix = p;
            break;
        }
    }
    
    if (prefix == nil)
        return nil;
    
    NSString *suffix = [[text substringFromIndex:prefix.length] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSArray *components = [suffix componentsSeparatedByString:@"&"];
    if (components.count < 2)
        return nil;
    
    
    NSString *url = components.firstObject;
    components = [url componentsSeparatedByString:@"/"];
    
    if (components.count < 1)
        return nil;
    
    NSString *identifier = components.lastObject;
    
    for (int i = 0; i < (int)identifier.length; i++)
    {
        unichar c = [identifier characterAtIndex:i];
        if (!(c >= '0' && c <= '9'))
            return nil;
    }
    
    return identifier;
}

+ (bool)_supportsWebPage:(TGWebPageMediaAttachment *)webPage
{
    NSString *url = webPage.embedUrl;
    return ([url hasPrefix:@"http://w.soundcloud.com/player/"] || [url hasPrefix:@"https://w.soundcloud.com/player/"]);
}

@end
