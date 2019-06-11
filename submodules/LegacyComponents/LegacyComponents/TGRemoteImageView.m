#import "TGRemoteImageView.h"

#import <QuartzCore/QuartzCore.h>

#import "TGCache.h"

#import <LegacyComponents/SGraphObjectNode.h>

#import <LegacyComponents/TGImageManager.h>

static TGCache *sharedCache = nil;

@interface TGRemoteImageView ()

@property (atomic, strong) NSString *path;
@property (atomic, strong) NSString *currentCacheUrl;

@property (nonatomic, strong) UIImageView *placeholderView;

@end

@implementation TGRemoteImageView

+ (NSMutableDictionary *)imageProcessors
{
    static NSMutableDictionary *dictionary = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        dictionary = [[NSMutableDictionary alloc] init];
    });
    return dictionary;
}

+ (NSMutableDictionary *)universalImageProcessors
{
    static NSMutableDictionary *dictionary = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        dictionary = [[NSMutableDictionary alloc] init];
    });
    return dictionary;
}

+ (void)throttleDownProcessing
{
    
}

+ (void)registerImageUniversalProcessor:(TGImageUniversalProcessor)universalProcessor withBaseName:(NSString *)baseName
{
    [[TGRemoteImageView universalImageProcessors] setObject:[universalProcessor copy] forKey:baseName];
}

+ (void)registerImageProcessor:(TGImageProcessor)imageProcessor withName:(NSString *)name
{
    [[TGRemoteImageView imageProcessors] setObject:[imageProcessor copy] forKey:name];
}

+ (TGImageProcessor)imageProcessorForName:(NSString *)name
{
    TGImageProcessor processor = [[TGRemoteImageView imageProcessors] objectForKey:name];
    if (processor != nil)
        return processor;
    
    NSRange range = [name rangeOfString:@":"];
    if (range.location != NSNotFound)
    {
        NSString *baseName = [name substringToIndex:range.location];
        TGImageUniversalProcessor universalProcessor = [[TGRemoteImageView universalImageProcessors] objectForKey:baseName];
        if (universalProcessor != nil)
        {
            return ^UIImage *(UIImage *source)
            {
                return universalProcessor(name, source);
            };
        }
    }
    
    return nil;
}

+ (void)setSharedCache:(TGCache *)cache
{
    sharedCache = cache;
}

+ (TGCache *)sharedCache
{
    return sharedCache;
}

#pragma mark - Implementation

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        _fadeTransitionDuration = 0.14;
        _useCache = true;
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [self cancelLoading];
}

- (void)addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    self.userInteractionEnabled = true;
    
    [super addGestureRecognizer:gestureRecognizer];
}

- (void)setFadeTransition:(bool)fadeTransition
{
    if (fadeTransition != _fadeTransition)
    {
        if (fadeTransition && _placeholderView == nil)
        {
            _placeholderView = [[UIImageView alloc] init];
            _placeholderView.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
            _placeholderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [_placeholderView setContentMode:self.contentMode];
            [self addSubview:_placeholderView];
        }
        else if (!fadeTransition && _placeholderView != nil)
        {
            [_placeholderView removeFromSuperview];
            _placeholderView = nil;
        }
        
        _fadeTransition = fadeTransition;
    }
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
    if (_placeholderView != nil)
        [_placeholderView setContentMode:contentMode];
    
    [super setContentMode:contentMode];
}

- (void)setPlaceholderOverlay:(UIView *)placeholderOverlay
{
    if (_placeholderOverlay != nil)
    {
        [_placeholderOverlay removeFromSuperview];
        _placeholderOverlay = nil;
    }
    
    _placeholderOverlay = placeholderOverlay;
    [_placeholderView addSubview:placeholderOverlay];
}

- (void)prepareForRecycle
{
    [self cancelLoading];
    self.image = nil;
    
    if (_placeholderOverlay != nil)
    {
        [_placeholderOverlay removeFromSuperview];
        _placeholderOverlay = nil;
    }
}

- (void)prepareForReuse
{
    [self cancelLoading];
    self.image = nil;
}

- (UIImage *)currentImage
{
    return self.image;
}

- (UIImage *)currentPlaceholderImage
{
    return _placeholderView.image;
}

- (void)tryFillCache:(NSMutableDictionary *)dict
{
    if (_currentUrl == nil)
        return;
    
    UIImage *currentImage = [self currentImage];
    if (currentImage != nil)
    {
        NSString *key = _currentFilter == nil ? _currentUrl : [[NSString alloc] initWithFormat:@"{filter:%@}%@", _currentFilter, _currentUrl];
        
        if (key != nil)
            [dict setObject:currentImage forKey:key];
    }
}

- (void)loadImage:(UIImage *)image
{
    [self cancelLoading];
    
    self.image = image;
    
    if (_placeholderView != nil)
    {
        [_placeholderView.layer removeAllAnimations];
        _placeholderView.image = nil;
        _placeholderView.hidden = true;
        _placeholderView.alpha = 0.0f;
    }
}

- (void)loadImage:(NSString *)url filter:(NSString *)filter placeholder:(UIImage *)placeholder
{
    [self loadImage:url filter:filter placeholder:placeholder forceFade:false];
}

- (void)loadImage:(NSString *)url filter:(NSString *)filter placeholder:(UIImage *)placeholder forceFade:(bool)forceFade
{
    [self cancelLoading];
    
    self.currentUrl = url;
    self.currentFilter = filter;
    
    TGCache *cache = _cache != nil ? _cache : [TGRemoteImageView sharedCache];
    
    NSString *trimmedUrl = url;
    NSArray *components = [trimmedUrl componentsSeparatedByString:@"_"];
    if (components.count >= 5)
        trimmedUrl = [NSString stringWithFormat:@"%@_%@_%@_%@", components[0], components[1], components[2], components[3]];
    
    NSString *cacheUrl = filter == nil ? trimmedUrl : [[NSString alloc] initWithFormat:@"{filter:%@}%@", filter, trimmedUrl];
    self.currentCacheUrl = cacheUrl;
    UIImage *image = [cache cachedImage:cacheUrl availability:TGCacheMemory];
    
    if (image == nil)
        image = [[TGImageManager instance] loadImageSyncWithUri:url canWait:false decode:true acceptPartialData:false asyncTaskId:NULL progress:nil partialCompletion:nil completion:nil];
    
    if (image == nil && (_contentHints & TGRemoteImageContentHintLoadFromDiskSynchronously))
    {
        UIImage *managerImage = [[TGImageManager instance] loadImageSyncWithUri:url canWait:true decode:filter == nil acceptPartialData:false asyncTaskId:NULL progress:nil partialCompletion:nil completion:nil];
        if (managerImage == nil)
            managerImage = [cache cachedImage:url availability:TGCacheDisk];
        
        if (managerImage != nil)
        {
            if (filter != nil)
            {
                TGImageProcessor procesor = [TGRemoteImageView imageProcessorForName:filter];
                if (procesor != nil)
                    image = procesor(managerImage);
            }
            else
                image = managerImage;
        }
    }
    
    if (image != nil)
    {
        if (_contentHints & TGRemoteImageContentHintSaveToGallery)
        {
            [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/checkImageStored/(%lu)", (unsigned long)[url hash]] options:[[NSDictionary alloc] initWithObjectsAndKeys:url, @"url", nil] watcher:self];
        }
        
        if (forceFade)
        {
            self.image = image;
            
            if (_placeholderView != nil)
            {   
                [_placeholderView.layer removeAllAnimations];
                UIView *placeholderView = _placeholderView;
                _placeholderView.alpha = 1.0f;
                _placeholderView.hidden = false;
                if (placeholder != nil)
                    _placeholderView.image = placeholder;
                [UIView animateWithDuration:_fadeTransitionDuration animations:^{
                    placeholderView.alpha = 0.0f;
                } completion:^(BOOL finished)
                {
                    if (finished)
                        placeholderView.hidden = true;
                }];
            }
        }
        else
        {
            self.image = image;
            
            if (_placeholderView != nil)
            {
                [_placeholderView.layer removeAllAnimations];
                _placeholderView.image = nil;
                _placeholderView.hidden = true;
                _placeholderView.alpha = 0.0f;
            }
        }
        
        if (_progressHandler)
            _progressHandler(self, 1.0f);
    }
    else
    {
        if (_allowThumbnailCache)
        {
            UIImage *thumbnail = [cache cachedThumbnail:cacheUrl];
            if (thumbnail != nil)
                placeholder = thumbnail;
        }
        
        if (_placeholderView != nil)
        {
            self.image = nil;
            [_placeholderView.layer removeAllAnimations];
            _placeholderView.image = placeholder;
            _placeholderView.hidden = false;
            _placeholderView.alpha = 1.0f;
        }
        else
        {
            self.image = placeholder;
        }
        
        if (filter != nil)
            self.path = [NSString stringWithFormat:@"/img/({filter:%@}%@)", filter, url];
        else
            self.path = [NSString stringWithFormat:@"/img/(%@)", url];
        
        NSMutableDictionary *options = [[NSMutableDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithInt:_cancelTimeout], @"cancelTimeout", cache, @"cache", [NSNumber numberWithBool:_useCache], @"useCache", [NSNumber numberWithBool:_allowThumbnailCache], @"allowThumbnailCache", [[NSNumber alloc] initWithInt:_contentHints], @"contentHints", nil];
        if (_userProperties != nil)
            [options setObject:_userProperties forKey:@"userProperties"];
        if (_contentHints & TGRemoteImageContentHintBlurRemote)
            options[@"blurIfRemote"] = @(true);
        [ActionStageInstance() requestActor:self.path options:options watcher:self];
    }
}

- (void)loadPlaceholder:(UIImage *)placeholder
{
    if (!_placeholderView.hidden)
        _placeholderView.image = placeholder;
}

- (void)cancelLoading
{
    if (self.path != nil)
    {
        ASHandle *actionHandle = _actionHandle;
        NSString *path = self.path;
        [ActionStageInstance() dispatchOnStageQueue:^
        {
            [ActionStageInstance() removeWatcherByHandle:actionHandle fromPath:path];
        }];
        
        self.image = nil;

        if (_placeholderView != nil)
        {
            [_placeholderView.layer removeAllAnimations];
        }
        
        self.path = nil;
    }
    
    self.currentUrl = nil;
    self.currentFilter = nil;
}

+ (UIImage *)imageFromCache:(NSString *)url filter:(NSString *)filter cache:(TGCache *)cache
{
    TGCache *usingCache = cache != nil ? cache : [TGRemoteImageView sharedCache];
    
    UIImage *image = nil;
    if (filter == nil)
        image = [usingCache cachedImage:url availability:TGCacheMemory];
    else
        image = [usingCache cachedImage:[[NSString alloc] initWithFormat:@"{filter:%@}%@", filter, url] availability:TGCacheMemory];
    
    return image;
}

+ (NSString *)preloadImage:(NSString *)url filter:(NSString *)filter blurIfRemote:(bool)blurIfRemote cache:(TGCache *)cache allowThumbnailCache:(bool)allowThumbnailCache watcher:(id<ASWatcher>)watcher
{
    TGCache *usingCache = cache != nil ? cache : [TGRemoteImageView sharedCache];
    
    UIImage *image = nil;
    if (filter == nil)
        image = [usingCache cachedImage:url availability:TGCacheMemory];
    else
        image = [usingCache cachedImage:[[NSString alloc] initWithFormat:@"{filter:%@}%@", filter, url] availability:TGCacheMemory];
    
    if (image == nil)
    {
        NSString *path = nil;
        if (filter != nil)
            path = [NSString stringWithFormat:@"/img/({filter:%@}%@)", filter, url];
        else
            path = [NSString stringWithFormat:@"/img/(%@)", url];
        
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:0], @"cancelTimeout", usingCache, @"cache", [NSNumber numberWithBool:allowThumbnailCache], @"forceMemoryCache", @(TG_CACHE_INPLACE), @"allowThumbnailCache", @(blurIfRemote), @"blurIfRemote", nil];
        [ActionStageInstance() requestActor:path options:options watcher:watcher];
        
        return path;
    }
    
    return nil;
}

- (void)actorMessageReceived:(NSString *)path messageType:(NSString *)messageType message:(id)message
{
    if ([messageType isEqualToString:@"progress"])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            if (_progressHandler == nil)
                return;
            
            if (self.path != nil && [path isEqualToString:self.path])
            {
                if (_progressHandler)
                    _progressHandler(self, [message floatValue]);
            }
        });
    }
}

- (void)actorReportedProgress:(NSString *)path progress:(float)progress
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (_progressHandler == nil)
            return;
        
        if (self.path != nil && [path isEqualToString:self.path])
        {
            if (_progressHandler)
                _progressHandler(self, progress);
        }
    });
}

- (void)actorCompleted:(int)resultCode path:(NSString *)path result:(id)result
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (self.path != nil && [path isEqualToString:self.path])
        {
            if (resultCode == ASStatusSuccess && result != nil)
            {
                if (_contentHints & TGRemoteImageContentHintSaveToGallery)
                {
                    [ActionStageInstance() requestActor:[[NSString alloc] initWithFormat:@"/tg/checkImageStored/(%lu)", (unsigned long)[self.currentUrl hash]] options:[[NSDictionary alloc] initWithObjectsAndKeys:self.currentUrl, @"url", nil] watcher:self];
                }
                
                UIImage *image = ((SGraphObjectNode *)result).object;
                if (image != nil)
                {
#if TG_CACHE_INPLACE
                    if (_useCache)
                    {
                        TGCache *cache = _cache != nil ? _cache : [TGRemoteImageView sharedCache];
                        [cache cacheImage:image withData:nil url:self.currentCacheUrl availability:TGCacheMemory];
                    }
#endif
                    
                    self.image = image;
                    
                    if (_placeholderView != nil)
                    {
                        //[_placeholderView.layer removeAllAnimations];
                        if (_fadeTransitionDuration < FLT_EPSILON)
                        {
                            _placeholderView.alpha = 0.0f;
                            _placeholderView.hidden = true;
                        }
                        else
                        {
                            UIView *placeholderView = _placeholderView;
                            [UIView animateWithDuration:_fadeTransitionDuration animations:^
                            {
                                placeholderView.alpha = 0.0f;
                            } completion:^(BOOL finished)
                            {
                                if (finished)
                                    placeholderView.hidden = true;
                            }];
                        }
                    }
                }
            }
            else
            {
                self.currentUrl = nil;
                self.currentFilter = nil;
            }
            
            if (_progressHandler)
                _progressHandler(self, 1.0f);
            
            self.path = nil;
        }
        /*else if (self.path != nil && ![path isEqualToString:self.path])
        {
            TGLegacyLog(@"Received wrong path: <<<%@>>> vs <<<%@>>>", self.path, path);
        }*/
    });
}

@end
