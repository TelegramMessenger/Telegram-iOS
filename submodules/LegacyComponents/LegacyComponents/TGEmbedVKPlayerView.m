#import "TGEmbedVKPlayerView.h"

#import <SSignalKit/SSignalKit.h>

#import "TGEmbedYoutubePlayerView.h"
#import "TGEmbedVimeoPlayerView.h"
#import "TGEmbedCoubPlayerView.h"
#import "TGEmbedVideoPlayerView.h"

@interface TGEmbedVKPlayerView ()
{
    NSString *_url;
    
    TGEmbedPlayerView *_subPlayerView;
    SMetaDisposable *_disposable;
}
@end

@implementation TGEmbedVKPlayerView

- (instancetype)initWithWebPageAttachment:(TGWebPageMediaAttachment *)webPage thumbnailSignal:(SSignal *)thumbnailSignal alternateCachePathSignal:(SSignal *)alternateCachePathSignal
{
    self = [super initWithWebPageAttachment:webPage thumbnailSignal:thumbnailSignal alternateCachePathSignal:alternateCachePathSignal];
    if (self != nil)
    {
        _url = webPage.embedUrl;
    }
    return self;
}

- (void)dealloc
{
    [_disposable dispose];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    
    if (_subPlayerView != nil)
        _subPlayerView.frame = self.bounds;
}

- (void)setRequestFullscreen:(void (^)(NSTimeInterval))requestFullscreen
{
    [super setRequestFullscreen:requestFullscreen];
    
    if (_subPlayerView != nil)
        [_subPlayerView setRequestFullscreen:requestFullscreen];
}

- (void)setRequestPictureInPicture:(void (^)(TGEmbedPIPCorner))requestPictureInPicture
{
    [super setRequestPictureInPicture:requestPictureInPicture];
    
    if (_subPlayerView != nil)
        [_subPlayerView setRequestPictureInPicture:requestPictureInPicture];
}

- (void)_prepareToEnterFullscreen
{
    [super _prepareToEnterFullscreen];
    
    if (_subPlayerView != nil)
        [_subPlayerView _prepareToEnterFullscreen];
}

- (void)_prepareToLeaveFullscreen
{
    [super _prepareToLeaveFullscreen];
    
    if (_subPlayerView != nil)
        [_subPlayerView _prepareToLeaveFullscreen];
}

- (void)playVideo
{
    [super playVideo];
    
    if (_subPlayerView != nil)
    {
        [_subPlayerView playVideo];
        return;
    }
}

- (void)pauseVideo:(bool)manually
{
    [super pauseVideo:manually];

    if (_subPlayerView != nil)
    {
        [_subPlayerView pauseVideo:manually];
        return;
    }
}

- (void)seekToPosition:(NSTimeInterval)position
{
    if (_subPlayerView != nil)
    {
        [_subPlayerView seekToPosition:position];
        return;
    }
}

- (void)onLockInPlace
{
    [super onLockInPlace];
    
    if (_subPlayerView != nil)
    {
        [_subPlayerView onLockInPlace];
        return;
    }
}

- (void)setupWithEmbedSize:(CGSize)embedSize
{
    [super setupWithEmbedSize:embedSize];
    
    [self initializePlayer];
    
    [self setLoadProgress:0.01f duration:0.01];
}

- (void)_requestSystemPictureInPictureMode
{
    if (_subPlayerView != nil)
        [_subPlayerView _requestSystemPictureInPictureMode];
    else
        [super _requestSystemPictureInPictureMode];
}

- (TGEmbedPlayerState *)state
{
    if (_subPlayerView != nil)
        return [_subPlayerView state];
    else
        return [super state];
}

- (SSignal *)stateSignal
{
    if (_subPlayerView != nil)
        return [_subPlayerView stateSignal];
    else
        return [super stateSignal];
}

- (void)initializePlayer
{
    __weak TGEmbedVKPlayerView *weakSelf = self;
    SSignal *signal = [[[LegacyComponentsGlobals provider] dataForHttpLocation:_url] map:^NSString *(NSData *data)
    {
        return [[NSString alloc] initWithData:data encoding:NSWindowsCP1251StringEncoding];
    }];
    
    _disposable = [[SMetaDisposable alloc] init];
    [_disposable setDisposable:[[signal deliverOn:[SQueue mainQueue]] startWithNext:^(NSString *next)
    {
        __strong TGEmbedVKPlayerView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;

        NSRange ytRange = [next rangeOfString:@"youtube.com/embed/"];
        if (ytRange.location != NSNotFound)
        {
            NSString *videoId = [self _getVideoId:next location:ytRange.location + @"youtube.com/embed/".length stopChar:'?'];
            if (videoId.length > 0)
            {
                TGWebPageMediaAttachment *webPage = [[TGWebPageMediaAttachment alloc] init];
                webPage.embedUrl = [NSString stringWithFormat:@"https://www.youtube.com/embed/%@", videoId];
                
                [self _setupWithSubPlayerView:[[TGEmbedYoutubePlayerView alloc] initWithWebPageAttachment:webPage]];
            }
        }
        
        NSRange vimeoRange = [next rangeOfString:@"vimeo.com/video/"];
        if (vimeoRange.location != NSNotFound)
        {
            NSString *videoId = [self _getVideoId:next location:vimeoRange.location + @"vimeo.com/video/".length stopChar:'?'];
            if (videoId.length > 0)
            {
                TGWebPageMediaAttachment *webPage = [[TGWebPageMediaAttachment alloc] init];
                webPage.embedUrl = [NSString stringWithFormat:@"https://player.vimeo.com/video/%@", videoId];
                
                [self _setupWithSubPlayerView:[[TGEmbedVimeoPlayerView alloc] initWithWebPageAttachment:webPage]];
            }
        }
        
        NSRange coubRange = [next rangeOfString:@"coub.com/embed/"];
        if (coubRange.location != NSNotFound)
        {
            NSString *videoId = [self _getVideoId:next location:coubRange.location + @"coub.com/embed/".length stopChar:'"'];
            if (videoId.length > 0)
            {
                TGWebPageMediaAttachment *webPage = [[TGWebPageMediaAttachment alloc] init];
                webPage.embedUrl = [NSString stringWithFormat:@"https://coub.com/embed/%@", videoId];
                
                [self _setupWithSubPlayerView:[[TGEmbedCoubPlayerView alloc] initWithWebPageAttachment:webPage]];
            }
        }
        
        NSRange vkRange = [next rangeOfString:@"<video id="];
        NSRange urlRange = [next rangeOfString:@"<source src=\""];
        if (vkRange.location != NSNotFound && urlRange.location != NSNotFound)
        {
            NSString *videoUrl = [self _getVideoId:next location:urlRange.location + @"<source src=\"".length stopChar:'"'];
            if (videoUrl.length > 0)
            {
                TGWebPageMediaAttachment *webPage = [[TGWebPageMediaAttachment alloc] init];
                webPage.embedUrl = videoUrl;

                [self _setupWithSubPlayerView:[[TGEmbedVideoPlayerView alloc] initWithWebPageAttachment:webPage]];
            }
        }
    }]];
}

- (NSString *)_getVideoId:(NSString *)string location:(NSUInteger)location stopChar:(char)stopChar
{
    for (NSUInteger i = location; i < string.length - location; i++)
    {
        unichar c = [string characterAtIndex:i];
        if (c == stopChar)
        {
            return [string substringWithRange:NSMakeRange(location, i - location)];
        }
    }
    
    return nil;
}

- (void)_setupWithSubPlayerView:(TGEmbedPlayerView *)playerView
{
    self.backgroundColor = [UIColor blackColor];
    
    _subPlayerView = playerView;
    _subPlayerView.frame = self.bounds;
    
    [[self _webView].superview insertSubview:playerView aboveSubview:[self _webView]];
    [self _cleanWebView];
    
    [self.controlsView removeFromSuperview];
    [playerView.dimWrapperView removeFromSuperview];
    
    [playerView setupWithEmbedSize:_embedSize];
    
    playerView.requestFullscreen = [self.requestFullscreen copy];
    playerView.requestPictureInPicture = [self.requestPictureInPicture copy];
    
    __weak TGEmbedVKPlayerView *weakSelf = self;
    playerView.onBeganLoading = ^
    {
        __strong TGEmbedVKPlayerView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf setDimmed:true animated:false shouldDelay:false];
    };
    
    playerView.onBeganPlaying = ^
    {
        __strong TGEmbedVKPlayerView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf setDimmed:false animated:true shouldDelay:false];
    };
    
    playerView.onRealLoadProgress = ^(CGFloat progress, NSTimeInterval duration)
    {
        __strong TGEmbedVKPlayerView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf setLoadProgress:progress duration:duration];
    };
}

+ (bool)_supportsWebPage:(TGWebPageMediaAttachment *)webPage
{
    NSString *url = webPage.embedUrl;
    return ([url hasPrefix:@"http://vk.com/video_ext.php"] || [url hasPrefix:@"https://vk.com/video_ext.php"]);
}

@end
