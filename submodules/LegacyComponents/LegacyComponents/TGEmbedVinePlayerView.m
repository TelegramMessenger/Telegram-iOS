#import "TGEmbedVinePlayerView.h"
#import "TGEmbedPlayerState.h"

#import "LegacyComponentsInternal.h"

#import <AVFoundation/AVFoundation.h>

#import <LegacyComponents/TGModernGalleryVideoView.h>

#import <LegacyComponents/TGTimerTarget.h>

NSString *const TGVinePlayerCallbackOnPlayback = @"onPlayback";

@interface TGEmbedVinePlayerView ()
{
    NSString *_videoId;
    bool _started;
    
    AVPlayer *_player;
    TGModernGalleryVideoView *_videoView;
    UIImageView *_watermarkView;
    
    id _playerStartedObserver;
    id _playerEndedObserver;
}
@end

@implementation TGEmbedVinePlayerView

- (instancetype)initWithWebPageAttachment:(TGWebPageMediaAttachment *)webPage thumbnailSignal:(SSignal *)thumbnailSignal alternateCachePathSignal:(SSignal *)alternateCachePathSignal
{
    self = [super initWithWebPageAttachment:webPage thumbnailSignal:thumbnailSignal alternateCachePathSignal:alternateCachePathSignal];
    if (self != nil)
    {
        _videoId = [TGEmbedVinePlayerView _vineVideoIdFromText:webPage.embedUrl];
        
        self.controlsView.watermarkImage = TGComponentsImageNamed(@"VineWatermark");
        self.controlsView.watermarkPrerenderedOpacity = true;
        self.controlsView.watermarkOffset = CGPointMake(12.0f, 12.0f);
    }
    return self;
}

- (void)_watermarkAction
{
    [super _watermarkAction];
    
    if (self.onWatermarkAction != nil)
        self.onWatermarkAction();
    
    NSString *videoId =  _videoId;
    
    NSURL *appUrl = [[NSURL alloc] initWithString:[[NSString alloc] initWithFormat:@"vine://post/%@", videoId]];
    
    if ([[LegacyComponentsGlobals provider] canOpenURL:appUrl])
    {
        [[LegacyComponentsGlobals provider] openURL:appUrl];
        return;
    }
    
    NSURL *webUrl = [NSURL URLWithString:[NSString stringWithFormat:@"https://vine.co/v/%@", videoId]];
    [[LegacyComponentsGlobals provider] openURL:webUrl];
}

- (void)playVideo
{
    [_player play];
    
    TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:true];
    [self updateState:state];
}

- (void)pauseVideo:(bool)manually
{
    [super pauseVideo:manually];
    [_player pause];
    
    TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:false];
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
    {
        NSArray *components = [query componentsSeparatedByString:@"="];
        if (components.count > 1)
            data = [query substringFromIndex:[components.firstObject length] + 1];
    }
    if ([action isEqual:TGVinePlayerCallbackOnPlayback])
    {
        if (!_started)
        {
            _started = true;
            [self _didBeginPlayback];
        }
    }
    else if ([action isEqualToString:@"onSrc"] && data != nil)
    {
        [self _setupCustomPlayerWithURL:[NSURL URLWithString:data]];
    }
}

- (void)_setupCustomPlayerWithURL:(NSURL *)url
{
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    AVPlayer *player = [AVPlayer playerWithPlayerItem:item];
    _player = player;
    
    UIView *currentView = [self _webView];
    TGModernGalleryVideoView *videoView = [[TGModernGalleryVideoView alloc] initWithFrame:currentView.frame player:player];
    [currentView.superview insertSubview:videoView aboveSubview:currentView];
    
    [self _cleanWebView];
    _videoView = videoView;
    
    __weak TGEmbedVinePlayerView *weakSelf = self;
    _playerStartedObserver = [player addBoundaryTimeObserverForTimes:@[[NSValue valueWithCMTime:CMTimeMake(10, 100)]] queue:NULL usingBlock:^
    {
        __strong TGEmbedVinePlayerView *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            [strongSelf _didBeginPlayback];
            
            TGEmbedPlayerState *state = [TGEmbedPlayerState stateWithPlaying:true];
            [strongSelf updateState:state];
            
            [strongSelf->_player removeTimeObserver:strongSelf->_playerStartedObserver];
            strongSelf->_playerStartedObserver = nil;
            
            if (CMTimeGetSeconds(strongSelf->_player.currentItem.duration) > 0)
                [strongSelf _setupEndedObserver];
        }
    }];
    
    [player play];
}

- (void)_setupEndedObserver
{
     __weak TGEmbedVinePlayerView *weakSelf = self;
    _playerEndedObserver = [_player addBoundaryTimeObserverForTimes:@[[NSValue valueWithCMTime:CMTimeSubtract(_player.currentItem.duration, CMTimeMake(10, 100))]] queue:NULL usingBlock:^
    {
        __strong TGEmbedVinePlayerView *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf->_player seekToTime:CMTimeMake(5, 100)];
    }];
}

- (UIView *)_webView
{
    if (_videoView != nil)
        return _videoView;
    
    return [super _webView];
}

- (NSString *)_embedHTML
{
    NSError *error = nil;
    NSString *path = TGComponentsPathForResource(@"VinePlayer", @"html");
    
    NSString *embedHTMLTemplate = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error != nil)
    {
        TGLegacyLog(@"[VineEmbedPlayer]: Received error rendering template: %@", error);
        return nil;
    }
    
    NSString *embedHTML = [NSString stringWithFormat:embedHTMLTemplate, _videoId];
    return embedHTML;
}

- (NSURL *)_baseURL
{
    return [NSURL URLWithString:@"https://vine.co/"];
}

- (void)_setupUserScripts:(WKUserContentController *)contentController
{
    NSError *error = nil;
    NSString *path = TGComponentsPathForResource(@"VinePlayerInject", @"js");
    NSString *scriptText = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error != nil)
        TGLegacyLog(@"[VineEmbedPlayer]: Received error loading inject script: %@", error);
    
    WKUserScript *script = [[WKUserScript alloc] initWithSource:scriptText injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:false];
    [contentController addUserScript:script];
}

+ (NSString *)_vineVideoIdFromText:(NSString *)text
{
    if ([text hasPrefix:@"http://vine.co/v/"] || [text hasPrefix:@"https://vine.co/v/"])
    {
        NSString *suffix = @"";
        
        NSMutableArray *prefixes = [NSMutableArray arrayWithArray:@
        [
            @"http://vine.co/v/",
            @"https://vine.co/v/"
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
        
        int end = -1;
        
        for (int i = 0; i < (int)suffix.length; i++)
        {
            unichar c = [suffix characterAtIndex:i];
            if (c == '/')
            {
                end = i;
                break;
            }
            
            if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '=' || c == '&' || c == '#'))
                return nil;
        }
        
        if (end != - 1)
            suffix = [suffix substringToIndex:end];
        
        return suffix;
    }
    
    return nil;
}

+ (NSString *)_vineIdFromPermalink:(NSString *)text
{
    static dispatch_once_t onceToken;
    static NSDictionary *map = nil;
    dispatch_once(&onceToken, ^
    {
        map = @
        {
            @"B" : @"0",
            @"u" : @"1",
            @"z" : @"2",
            @"a" : @"3",
            @"W" : @"4",
            @"7" : @"5",
            @"Z" : @"6",
            @"m" : @"7",
            @"K" : @"8",
            @"A" : @"9",
            @"q" : @"a",
            @"U" : @"A",
            @"b" : @"b",
            @"P" : @"B",
            @"h" : @"c",
            @"x" : @"C",
            @"M" : @"d",
            @"Q" : @"D",
            @"2" : @"E",
            @"O" : @"e",
            @"0" : @"F",
            @"e" : @"f",
            @"E" : @"G",
            @"i" : @"g",
            @"5" : @"h",
            @"9" : @"H",
            @"J" : @"i",
            @"V" : @"I",
            @"1" : @"j",
            @"Y" : @"J",
            @"3" : @"K",
            @"n" : @"k",
            @"L" : @"L",
            @"v" : @"l",
            @"l" : @"M",
            @"r" : @"m",
            @"6" : @"n",
            @"g" : @"o",
            @"X" : @"p",
            @"H" : @"q",
            @"w" : @"r",
            @"d" : @"s",
            @"p" : @"t",
            @"D" : @"u",
            @"j" : @"v",
            @"I" : @"w",
            @"T" : @"x",
            @"t" : @"y",
            @"F" : @"z"
        };
    });
    
    NSMutableString *shiftedString = [text mutableCopy];
    for (NSUInteger i = 0; i < shiftedString.length; i++)
    {
        NSString *charStr = [shiftedString substringWithRange:NSMakeRange(i, 1)];
        NSString *mappedStr = map[charStr];
        
        [shiftedString replaceCharactersInRange:NSMakeRange(i, 1) withString:mappedStr];
    }
    
    return [NSString stringWithFormat:@"%lld", [self _convertString:shiftedString fromBase:49]];
}

+ (int64_t)_convertString:(NSString *)string fromBase:(NSInteger)fromBase
{
    NSString *base = @"0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    NSUInteger limit = string.length;
    
    int64_t res = [base rangeOfString:[string substringWithRange:NSMakeRange(0, 1)]].location;
    if (res == NSNotFound)
        return 0;
    
    for (NSUInteger i = 1; i < limit; i++)
    {
        NSInteger a = [base rangeOfString:[string substringWithRange:NSMakeRange(i, 1)]].location;
        if (a == NSNotFound)
            return 0;
        
        res = fromBase * res + a;
    }

    return res;
}

+ (bool)_supportsWebPage:(TGWebPageMediaAttachment *)webPage
{
    NSString *url = webPage.embedUrl;
    return ([url hasPrefix:@"http://vine.co/v/"] || [url hasPrefix:@"https://vine.co/v/"]);
}

@end
