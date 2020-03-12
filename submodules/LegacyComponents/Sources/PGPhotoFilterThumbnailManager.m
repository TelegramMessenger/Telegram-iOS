#import "PGPhotoFilterThumbnailManager.h"

#import <LegacyComponents/TGMemoryImageCache.h>
#import <pthread.h>

#import <SSignalKit/SSignalKit.h>

#import "PGPhotoEditor.h"
#import "PGPhotoFilter.h"
#import "PGPhotoFilterDefinition.h"
#import "PGPhotoProcessPass.h"
#import "PGPhotoEditorPicture.h"

const NSUInteger TGFilterThumbnailCacheSoftMemoryLimit = 2 * 1024 * 1024;
const NSUInteger TGFilterThumbnailCacheHardMemoryLimit = 2 * 1024 * 1024;

@interface PGPhotoFilterThumbnailManager ()
{
    TGMemoryImageCache *_filterThumbnailCache;
    SQueue *_cachingQueue;
    
    UIImage *_thumbnailImage;
    PGPhotoEditorPicture *_thumbnailPicture;
    
    SQueue *_filteringQueue;
    dispatch_queue_t _prepQueue;
    
    pthread_rwlock_t _callbackLock;
    NSMutableDictionary *_callbacksForId;
    
    NSInteger _version;
}

@end

@implementation PGPhotoFilterThumbnailManager

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        [self invalidateThumbnailImages];

        _prepQueue = dispatch_queue_create("ph.pictogra.Pictograph.FilterThumbnailQueue", DISPATCH_QUEUE_CONCURRENT);
        
        _cachingQueue = [[SQueue alloc] init];
        _callbacksForId = [[NSMutableDictionary alloc] init];
        
        _filteringQueue = [[SQueue alloc] init];
        pthread_rwlock_init(&_callbackLock, NULL);
    }
    return self;
}

- (void)setThumbnailImage:(UIImage *)image
{
    [self invalidateThumbnailImages];
    _thumbnailImage = image;

    //_thumbnailPicture = [[PGPhotoEditorPicture alloc] initWithImage:_thumbnailImage];
}

- (void)requestThumbnailImageForFilter:(PGPhotoFilter *)filter completion:(void (^)(UIImage *image, bool cached, bool finished))completion
{
    if (filter.definition.type == PGPhotoFilterTypePassThrough)
    {
        if (completion != nil)
        {
            if (_thumbnailImage != nil)
                completion(_thumbnailImage, true, true);
            else
                completion(nil, true, false);
        }
        
        return;
    }
    
    UIImage *cachedImage = [_filterThumbnailCache imageForKey:filter.identifier attributes:nil];
    if (cachedImage != nil)
    {
        if (completion != nil)
            completion(cachedImage, true, true);
        return;
    }
    
    if (_thumbnailImage == nil)
    {
        completion(nil, true, true);
        return;
    }
    
    if (completion != nil)
        completion(_thumbnailImage, true, false);
    
    NSInteger version = _version;
    
    __weak PGPhotoFilterThumbnailManager *weakSelf = self;
    [self _addCallback:completion forId:filter.identifier createCallback:^
    {
        __strong PGPhotoFilterThumbnailManager *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
         
        if (version != strongSelf->_version)
            return;
         
        [strongSelf renderFilterThumbnailWithPicture:strongSelf->_thumbnailPicture filter:filter completion:^(UIImage *result)
        {
            [strongSelf _processCompletionForId:filter.identifier withResult:result];
        }];
    }];
}

- (void)startCachingThumbnailImagesForFilters:(NSArray *)filters
{
    if (_thumbnailImage == nil)
        return;
    
    NSMutableArray *filtersToStartCaching = [[NSMutableArray alloc] init];
    
    for (PGPhotoFilter *filter in filters)
    {
        if (filter.definition.type != PGPhotoFilterTypePassThrough && [_filterThumbnailCache imageForKey:filter.identifier attributes:nil] == nil)
            [filtersToStartCaching addObject:filter];
    }
    
    NSInteger version = _version;
    
    [_cachingQueue dispatch:^
    {
        if (version != _version)
            return;
        
        for (PGPhotoFilter *filter in filtersToStartCaching)
        {
            __weak PGPhotoFilterThumbnailManager *weakSelf = self;
            [self _addCallback:nil forId:filter.identifier createCallback:^
            {
                __strong PGPhotoFilterThumbnailManager *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                if (version != strongSelf->_version)
                    return;
               
                [strongSelf renderFilterThumbnailWithPicture:strongSelf->_thumbnailPicture filter:filter completion:^(UIImage *result)
                {
                    [strongSelf _processCompletionForId:filter.identifier withResult:result];
                }];
            }];
        }
    }];
}

- (void)stopCachingThumbnailImagesForFilters:(NSArray *)__unused filters
{
    
}

- (void)stopCachingThumbnailImagesForAllFilters
{
    
}

- (void)_processCompletionForId:(NSString *)filterId withResult:(UIImage *)result
{
    [_filterThumbnailCache setImage:result forKey:filterId attributes:nil];
    
    NSArray *callbacks = [self _callbacksForId:filterId];
    [self _removeCallbacksForId:filterId];
    
    for (id callback in callbacks)
    {
        void(^callbackBlock)(UIImage *image, bool cached, bool finished) = callback;
        if (callbackBlock != nil)
            callbackBlock(result, false, true);
    }
}

- (void)renderFilterThumbnailWithPicture:(PGPhotoEditorPicture *)picture filter:(PGPhotoFilter *)filter completion:(void (^)(UIImage *result))completion
{
    PGPhotoEditor *photoEditor = self.photoEditor;
    if (photoEditor == nil)
        return;
    
    NSInteger version = _version;
    dispatch_async(_prepQueue, ^
    {
        GPUImageOutput<GPUImageInput> *gpuFilter = filter.optimizedPass.filter;
        [_filteringQueue dispatch:^
        {
            if (version != _version)
                return;
            
            [picture addTarget:gpuFilter];
            [gpuFilter useNextFrameForImageCapture];
            [picture processSynchronous:true completion:^
            {
                UIImage *image = [gpuFilter imageFromCurrentFramebufferWithOrientation:UIImageOrientationUp];
                [picture removeAllTargets];
                
                if (completion != nil)
                    completion(image);
            }];
        }];
    });
}

- (void)invalidateThumbnailImages
{
    _version = lrand48();

    _filterThumbnailCache = [[TGMemoryImageCache alloc] initWithSoftMemoryLimit:TGFilterThumbnailCacheSoftMemoryLimit
                                                                hardMemoryLimit:TGFilterThumbnailCacheHardMemoryLimit];
}

- (void)haltCaching
{
    _version = lrand48();
}

- (void)_addCallback:(void (^)(UIImage *, bool, bool))callback forId:(NSString *)filterId createCallback:(void (^)(void))createCallback
{
    if (filterId == nil)
    {
        callback(nil, true, false);
        return;
    }
    
    pthread_rwlock_rdlock(&_callbackLock);
    
    bool isInitial = false;
    if (_callbacksForId[filterId] == nil)
    {
        isInitial = true;
        _callbacksForId[filterId] = [[NSMutableArray alloc] init];
    }
    
    if (callback != nil)
    {
        NSMutableArray *callbacksForId = _callbacksForId[filterId];
        [callbacksForId addObject:callback];
        _callbacksForId[filterId] = callbacksForId;
    }
    
    if (isInitial && createCallback != nil)
        createCallback();
    
    pthread_rwlock_unlock(&_callbackLock);
}

- (NSArray *)_callbacksForId:(NSString *)filterId
{
    if (filterId == nil)
        return nil;
    
    __block NSArray *callbacksForId;
    
    pthread_rwlock_rdlock(&_callbackLock);
    callbacksForId = _callbacksForId[filterId];
    pthread_rwlock_unlock(&_callbackLock);
    
    return [callbacksForId copy];
}

- (void)_removeCallbacksForId:(NSString *)filterId
{
    if (filterId == nil)
        return;
    
    pthread_rwlock_rdlock(&_callbackLock);
    [_callbacksForId removeObjectForKey:filterId];
    pthread_rwlock_unlock(&_callbackLock);
}

@end
