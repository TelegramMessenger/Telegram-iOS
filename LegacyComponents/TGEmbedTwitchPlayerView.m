#import "TGEmbedTwitchPlayerView.h"
#import "TGEmbedPlayerState.h"

#import "LegacyComponentsInternal.h"

@interface TGEmbedTwitchPlayerView ()
{
    bool _started;
}
@end

@implementation TGEmbedTwitchPlayerView

- (void)playVideo
{
    if (!_started)
        return;
    
    [self _evaluateJS:@"injectCmd('play')" completion:nil];
    
    TGEmbedPlayerState *newState = [TGEmbedPlayerState stateWithPlaying:true duration:0.0 position:-1.0 downloadProgress:0.0 buffering:false];
    [self updateState:newState];
}

- (void)pauseVideo:(bool)manually
{
    [super pauseVideo:manually];
    [self _evaluateJS:@"injectCmd('play')" completion:nil];
    
    TGEmbedPlayerState *newState = [TGEmbedPlayerState stateWithPlaying:false duration:0.0 position:-1.0 downloadProgress:0.0 buffering:false];
    [self updateState:newState];
}

- (void)_onPageReady
{
    TGDispatchAfter(0.5, dispatch_get_main_queue(), ^
    {
        [super _onPageReady];
    });
    
    TGEmbedPlayerState *newState = [TGEmbedPlayerState stateWithPlaying:false duration:0.0 position:-1.0 downloadProgress:0.0 buffering:false];
    [self updateState:newState];
}

- (TGEmbedPlayerControlsType)_controlsType
{
    return TGEmbedPlayerControlsTypeFull;
}

- (void)_notifyOfCallbackURL:(NSURL *)url
{
    NSString *action = url.host;
    
    NSString *query = url.query;
    NSString *data;
    if (query != nil)
        data = [query componentsSeparatedByString:@"="][1];
    
    if ([action isEqualToString:@"onPlayback"])
    {
        if (!_started)
        {
            _started = true;
            [self _didBeginPlayback];
        }
        
        TGEmbedPlayerState *newState = [TGEmbedPlayerState stateWithPlaying:true duration:0.0 position:-1.0 downloadProgress:0.0 buffering:false];
        [self updateState:newState];
    }
}

- (NSString *)_embedHTML
{
    NSError *error = nil;
    NSString *path = TGComponentsPathForResource(@"TwitchPlayer", @"html");
    
    NSString *embedHTMLTemplate = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error != nil)
    {
        TGLegacyLog(@"[TwitchEmbedPlayer]: Received error rendering template: %@", error);
        return nil;
    }
    
    NSString *embedHTML = [NSString stringWithFormat:embedHTMLTemplate, _webPage.embedUrl];
    return embedHTML;
}

- (void)_setupUserScripts:(WKUserContentController *)contentController
{
    NSError *error = nil;
    NSString *path = TGComponentsPathForResource(@"TwitchPlayerInject", @"js");
    NSString *scriptText = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error != nil)
        TGLegacyLog(@"[TwitchEmbedPlayer]: Received error loading inject script: %@", error);
    
    WKUserScript *script = [[WKUserScript alloc] initWithSource:scriptText injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:false];
    [contentController addUserScript:script];
}

+ (bool)_supportsWebPage:(TGWebPageMediaAttachment *)webPage
{
    NSString *url = webPage.embedUrl;
    return ([url hasPrefix:@"http://player.twitch.tv/"] || [url hasPrefix:@"https://player.twitch.tv/"])
        || ([url hasPrefix:@"http://clips.twitch.tv/"] || [url hasPrefix:@"https://clips.twitch.tv/"]);
}

@end
