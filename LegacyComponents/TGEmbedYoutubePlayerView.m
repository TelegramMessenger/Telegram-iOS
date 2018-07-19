#import "TGEmbedYoutubePlayerView.h"
#import "TGEmbedPlayerState.h"

#import "LegacyComponentsInternal.h"

NSString *const TGYTPlayerCallbackOnReady = @"onReady";
NSString *const TGYTPlayerCallbackOnState = @"onState";
NSString *const TGYTPlayerCallbackOnPlaybackQualityChange = @"onPlaybackQualityChange";
NSString *const TGYTPlayerCallbackOnError = @"onError";

const NSInteger TGYTPlayerStateUnstartedCode = -1;
const NSInteger TGYTPlayerStateEndedCode = 0;
const NSInteger TGYTPlayerStatePlayingCode = 1;
const NSInteger TGYTPlayerStatePausedCode = 2;
const NSInteger TGYTPlayerStateBufferingCode = 3;

@interface TGEmbedYoutubePlayerView ()
{
    NSDictionary *_playerParams;
    bool _started;
    bool _failed;
    
    bool _ready;
    bool _playOnReady;
    NSInteger _playAfterTicks;
    
    NSInteger _ignorePositionUpdates;
}
@end

@implementation TGEmbedYoutubePlayerView

- (instancetype)initWithWebPageAttachment:(TGWebPageMediaAttachment *)webPage thumbnailSignal:(SSignal *)thumbnailSignal alternateCachePathSignal:(SSignal *)alternateCachePathSignal
{
    self = [super initWithWebPageAttachment:webPage thumbnailSignal:thumbnailSignal alternateCachePathSignal:alternateCachePathSignal];
    if (self != nil)
    {
        NSTimeInterval start = 0.0;
        NSString *videoId = [TGEmbedYoutubePlayerView _youtubeVideoIdFromText:webPage.embedUrl originalUrl:webPage.url startTime:&start];
        _playerParams = @
        {
            @"videoId": videoId,
            @"playerVars": @
            {
                @"cc_load_policy" : @1,
                @"iv_load_policy" : @3,
                @"controls" : @0,
                @"playsinline" : @1,
                @"autohide" : @1,
                @"showinfo" : @0,
                @"rel" : @0,
                @"modestbranding" : @1,
                @"start" : @((NSInteger)start)
            }
        };
        
        self.controlsView.watermarkImage = TGComponentsImageNamed(@"YoutubeWatermark");
        self.controlsView.watermarkPosition = TGEmbedPlayerWatermarkPositionBottomRight;
        self.controlsView.watermarkOffset = CGPointMake(-12.0f, -12.0f);
    }
    return self;
}

- (void)_watermarkAction
{
    [super _watermarkAction];
    
    if (self.onWatermarkAction != nil)
        self.onWatermarkAction();
    
    NSString *videoId =  _playerParams[@"videoId"];
    
    NSURL *appUrl = [[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"youtube://watch?v=%@", videoId]];
    if ([[LegacyComponentsGlobals provider] canOpenURL:appUrl])
    {
        [[LegacyComponentsGlobals provider] openURL:appUrl];
        return;
    }
    
    NSURL *webUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://youtube.com/watch?v=%@", videoId]];
    [[LegacyComponentsGlobals provider] openURL:webUrl];
}

- (void)playVideo
{
    if (!_ready && self.disallowAutoplay)
    {
        _playOnReady = true;
        _playAfterTicks = 2;
        return;
    }
    
    [super playVideo];
    [self _evaluateJS:@"player.playVideo();" completion:nil];
    
    _ignorePositionUpdates = 2;
}

- (void)pauseVideo:(bool)manually
{
    [super pauseVideo:manually];
    [self _evaluateJS:@"player.pauseVideo();" completion:nil];
}

- (void)seekToPosition:(NSTimeInterval)position
{
    NSString *command = [NSString stringWithFormat:@"player.seekTo(%@, true);", @(position)];
    [self _evaluateJS:command completion:nil];
    
    TGEmbedPlayerState *newState = [TGEmbedPlayerState stateWithPlaying:self.state.isPlaying duration:self.state.duration position:position downloadProgress:self.state.downloadProgress buffering:self.state.buffering];
    [self updateState:newState];
    
    _ignorePositionUpdates = 2;
}

- (TGEmbedPlayerControlsType)_controlsType
{
    return TGEmbedPlayerControlsTypeFull;
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
    
    if ([action isEqualToString:TGYTPlayerCallbackOnState])
    {
        if (_failed)
            return;
        
        NSURLComponents *urlComponents = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:false];
        NSArray *queryItems = urlComponents.queryItems;
        
        bool failed = _failed;
        bool playing = self.state.playing;
        bool finished = false;
        NSTimeInterval position = self.state.position;
        NSTimeInterval duration = self.state.duration;
        CGFloat downloadProgress = self.state.downloadProgress;
        bool buffering = self.state.buffering;
        
        for (NSURLQueryItem *queryItem in queryItems)
        {
            if ([queryItem.name isEqualToString:@"playback"])
            {
                playing = ([queryItem.value integerValue] == TGYTPlayerStatePlayingCode);
                finished = ([queryItem.value integerValue] == TGYTPlayerStateEndedCode);
                buffering = ([queryItem.value integerValue] == TGYTPlayerStateBufferingCode);
            }
            else if ([queryItem.name isEqualToString:@"position"])
            {
                if (_ignorePositionUpdates > 0)
                    _ignorePositionUpdates--;
                else
                    position = [queryItem.value doubleValue];
            }
            else if ([queryItem.name isEqualToString:@"duration"])
            {
                duration = [queryItem.value doubleValue];
            }
            else if ([queryItem.name isEqualToString:@"download"])
            {
                downloadProgress = MAX(0.0f, MIN(1.0, [queryItem.value floatValue]));
            }
            else if ([queryItem.name isEqualToString:@"failed"])
            {
                failed = [queryItem.value boolValue];
            }
        }
        
        if (failed && !_failed)
        {
            _failed = true;
            [self setDimmed:false animated:true shouldDelay:false];
            [self.controlsView setDisabled];
        }
        
        if (playing && !_started)
        {
            _started = true;
            [self _didBeginPlayback];
        }
        
        if (finished)
            position = 0.0;
        
        TGEmbedPlayerState *newState = [TGEmbedPlayerState stateWithPlaying:playing duration:duration position:position downloadProgress:downloadProgress buffering:buffering];
        [self updateState:newState];
        
        if (_playAfterTicks > 0)
        {
            _playAfterTicks--;
            if (_playAfterTicks == 0)
            {
                _ready = true;
                [self playVideo];
            }
        }
    }
    else if ([action isEqualToString:TGYTPlayerCallbackOnReady])
    {
        _ready = true;
        if (_playOnReady)
        {
            _playAfterTicks = 0;
            _playOnReady = false;
            [self playVideo];
        }
        
        if (!self.disallowAutoplay)
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self playVideo];
                
                TGDispatchAfter(2.0, dispatch_get_main_queue(), ^{
                    if (!_started)
                        [self playVideo];
                });
            });
        }
    }
}

- (NSString *)_embedHTML
{
    NSDictionary *playerCallbacks = @
    {
        @"onReady" : @"onReady",
        @"onStateChange" : @"onStateChange",
        @"onPlaybackQualityChange" : @"onPlaybackQualityChange",
        @"onError" : @"onPlayerError"
    };
    
    NSMutableDictionary *playerParams = [[NSMutableDictionary alloc] init];
    [playerParams addEntriesFromDictionary:_playerParams];
    
    if (![playerParams objectForKey:@"height"])
        [playerParams setValue:@"100%" forKey:@"height"];
    if (![playerParams objectForKey:@"width"])
        [playerParams setValue:@"100%" forKey:@"width"];
    
    [playerParams setValue:playerCallbacks forKey:@"events"];
    
    if ([playerParams objectForKey:@"playerVars"])
    {
        NSMutableDictionary *playerVars = [[NSMutableDictionary alloc] init];
        [playerVars addEntriesFromDictionary:[playerParams objectForKey:@"playerVars"]];
    }
    else
    {
        [playerParams setValue:[[NSDictionary alloc] init] forKey:@"playerVars"];
    }
    
    NSError *error = nil;
    NSString *path = TGComponentsPathForResource(@"YoutubePlayer", @"html");
    
    NSString *embedHTMLTemplate = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error != nil)
    {
        TGLegacyLog(@"[YTEmbedPlayer]: Received error rendering template: %@", error);
        return nil;
    }
    
    NSError *jsonRenderingError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:playerParams options:NSJSONWritingPrettyPrinted error:&jsonRenderingError];
    if (jsonRenderingError != nil)
    {
        NSLog(@"[YTEmbedPlayer]: Attempted configuration of player with invalid playerVars: %@ \tError: %@", playerParams, jsonRenderingError);
        return nil;
    }
    
    NSString *playerVarsJsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    NSString *autoplay = self.disallowAutoplay ? @"false" : @"true";
    NSString *embedHTML = [NSString stringWithFormat:embedHTMLTemplate, playerVarsJsonString, autoplay];
    return embedHTML;
}

- (NSURL *)_baseURL
{
    return [NSURL URLWithString:@"https://youtube.com/"];
}

- (void)_setupUserScripts:(WKUserContentController *)contentController
{
    NSError *error = nil;
    NSString *path = TGComponentsPathForResource(@"YoutubePlayerInject", @"js");
    NSString *scriptText = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error != nil)
        TGLegacyLog(@"[YTEmbedPlayer]: Received error loading inject script: %@", error);
    
    WKUserScript *script = [[WKUserScript alloc] initWithSource:scriptText injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:false];
    [contentController addUserScript:script];
}

- (bool)_scaleViewToMaxSize
{
    return true;
}

- (CGFloat)_compensationEdges
{
    return 3.0f;
}

+ (NSString *)_youtubeVideoIdFromText:(NSString *)text originalUrl:(NSString *)originalUrl startTime:(NSTimeInterval *)startTime
{
    if ([text hasPrefix:@"http://www.youtube.com/watch?v="] || [text hasPrefix:@"https://www.youtube.com/watch?v="] || [text hasPrefix:@"http://m.youtube.com/watch?v="] || [text hasPrefix:@"https://m.youtube.com/watch?v="])
    {
        NSRange range1 = [text rangeOfString:@"?v="];
        bool match = true;
        for (NSInteger i = range1.location + range1.length; i < (NSInteger)text.length; i++)
        {
            unichar c = [text characterAtIndex:i];
            if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '=' || c == '&' || c == '#'))
            {
                match = false;
                break;
            }
        }
        
        if (match)
        {
            NSString *videoId = nil;
            NSRange ampRange = [text rangeOfString:@"&"];
            NSRange hashRange = [text rangeOfString:@"#"];
            if (ampRange.location != NSNotFound || hashRange.location != NSNotFound)
            {
                NSInteger location = MIN(ampRange.location, hashRange.location);
                videoId = [text substringWithRange:NSMakeRange(range1.location + range1.length, location - range1.location - range1.length)];
            }
            else
                videoId = [text substringFromIndex:range1.location + range1.length];
            
            if (videoId.length != 0)
                return videoId;
        }
    }
    else if ([text hasPrefix:@"http://youtu.be/"] || [text hasPrefix:@"https://youtu.be/"] || [text hasPrefix:@"http://www.youtube.com/embed/"] || [text hasPrefix:@"https://www.youtube.com/embed/"])
    {
        NSString *suffix = @"";

        NSMutableArray *prefixes = [NSMutableArray arrayWithArray:@
        [
            @"http://youtu.be/",
            @"https://youtu.be/",
            @"http://www.youtube.com/embed/",
            @"https://www.youtube.com/embed/"
        ]];
        
        while (suffix.length == 0 && prefixes.count > 0)
        {
            NSString *prefix = prefixes.firstObject;
            if ([text hasPrefix:prefix])
            {
                suffix = [text substringFromIndex:prefix.length];
                break;
            }
            else
            {
                [prefixes removeObjectAtIndex:0];
            }
        }
        
        NSString *queryString = nil;
        for (int i = 0; i < (int)suffix.length; i++)
        {
            unichar c = [suffix characterAtIndex:i];
            if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '=' || c == '&' || c == '#'))
            {
                if (c == '?')
                {
                    queryString = [suffix substringFromIndex:i + 1];
                    suffix = [suffix substringToIndex:i];
                    break;
                }
                else
                {
                    return nil;
                }
            }
        }
        
        if (startTime != NULL)
        {
            NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
            NSString *queryString = [NSURL URLWithString:originalUrl].query;
            for (NSString *param in [queryString componentsSeparatedByString:@"&"])
            {
                NSArray *components = [param componentsSeparatedByString:@"="];
                if (components.count < 2)
                    continue;
                [params setObject:components.lastObject forKey:components.firstObject];
            }
            
            NSString *timeParam = params[@"t"];
            if (timeParam == nil)
                timeParam = params[@"time_continue"];
            if (timeParam != nil)
            {
                NSTimeInterval position = 0.0;
                if ([timeParam rangeOfString:@"s"].location != NSNotFound)
                {
                    NSString *value;
                    NSUInteger location = 0;
                    for (NSUInteger i = 0; i < timeParam.length; i++)
                    {
                        unichar c = [timeParam characterAtIndex:i];
                        if ((c < '0' || c > '9'))
                        {
                            value = [timeParam substringWithRange:NSMakeRange(location, i - location)];
                            location = i + 1;
                            switch (c)
                            {
                                case 's':
                                    position += value.doubleValue;
                                    break;
                                    
                                case 'm':
                                    position += value.doubleValue * 60.0;
                                    break;
                                    
                                case 'h':
                                    position += value.doubleValue * 3600.0;
                                    break;
                                    
                                default:
                                    break;
                            }
                        }
                    }
                }
                else
                {
                    position = timeParam.doubleValue;
                }
                
                *startTime = position;
            }
        }
                
        return suffix;
    }
    
    return nil;
}

+ (bool)_supportsWebPage:(TGWebPageMediaAttachment *)webPage
{
    NSString *url = webPage.embedUrl;
    if ([url rangeOfString:@"list"].location != NSNotFound)
        return false;
    
    return ([url hasPrefix:@"http://www.youtube.com/watch?v="] || [url hasPrefix:@"https://www.youtube.com/watch?v="] || [url hasPrefix:@"http://m.youtube.com/watch?v="] || [url hasPrefix:@"https://m.youtube.com/watch?v="] || [url hasPrefix:@"http://youtu.be/"] || [url hasPrefix:@"https://youtu.be/"] || [url hasPrefix:@"https://www.youtube.com/embed/"]);
}

@end
