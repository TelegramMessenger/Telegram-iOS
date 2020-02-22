#import "TGEmbedInstagramPlayerView.h"
#import "TGEmbedPlayerState.h"

#import "LegacyComponentsInternal.h"

NSString *const TGInstagramPlayerCallbackOnPlayback = @"onPlayback";

@interface TGEmbedInstagramPlayerView ()
{
    NSString *_url;
    bool _playing;
    bool _started;
}
@end

@implementation TGEmbedInstagramPlayerView

- (instancetype)initWithWebPageAttachment:(TGWebPageMediaAttachment *)webPage thumbnailSignal:(SSignal *)thumbnailSignal alternateCachePathSignal:(SSignal *)alternateCachePathSignal
{
    self = [super initWithWebPageAttachment:webPage thumbnailSignal:thumbnailSignal alternateCachePathSignal:alternateCachePathSignal];
    if (self != nil)
    {
        _url = webPage.embedUrl;
    }
    return self;
}

- (void)playVideo
{
    _playing = true;
    [self _evaluateJS:@"play()" completion:nil];
    
    TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:_playing];
    [self updateState:state];
}

- (void)pauseVideo:(bool)manually
{
    [super pauseVideo:manually];
    
    _playing = false;
    [self _evaluateJS:@"pause();" completion:nil];
    
    TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:_playing];
    [self updateState:state];
}

- (TGEmbedPlayerControlsType)_controlsType
{
    return TGEmbedPlayerControlsTypeSimple;
}

- (void)_onPageReady
{
    
}

- (void)_didBeginPlayback
{
    [super _didBeginPlayback];
    [self setDimmed:false animated:true shouldDelay:false];
}

- (void)_notifyOfCallbackURL:(NSURL *)url
{
    NSString *action = url.host;
    
    NSString *query = url.query;
    NSString *data;
    if (query != nil)
        data = [query componentsSeparatedByString:@"="][1];
    
    if ([action isEqual:TGInstagramPlayerCallbackOnPlayback])
    {
        if (!_started)
        {
            _started = true;
            [self _didBeginPlayback];
        }
        _playing = true;
        TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:true];
        [self updateState:state];
    }
}

- (NSString *)_embedHTML
{
    NSError *error = nil;
    NSString *path = TGComponentsPathForResource(@"InstagramPlayer", @"html");
    
    NSString *embedHTMLTemplate = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error != nil)
    {
        TGLegacyLog(@"[InstagramEmbedPlayer]: Received error rendering template: %@", error);
        return nil;
    }
    
    NSString *embedHTML = [NSString stringWithFormat:embedHTMLTemplate, _url];
    return embedHTML;
}

- (NSURL *)_baseURL
{
    return [NSURL URLWithString:@"https://instagram.com/"];
}

+ (bool)_supportsWebPage:(TGWebPageMediaAttachment *)webPage
{
    NSURL *url = [NSURL URLWithString:webPage.embedUrl];
    return ([url.host containsString:@"cdninstagram"] && [url.pathExtension isEqualToString:@"mp4"]);
}

@end
