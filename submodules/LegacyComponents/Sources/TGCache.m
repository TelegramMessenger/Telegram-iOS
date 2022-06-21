#import "TGCache.h"

#import "LegacyComponentsInternal.h"

#import "TGImageUtils.h"

#import <objc/runtime.h>
#import <CommonCrypto/CommonDigest.h>
#import <ImageIO/ImageIO.h>

#import <pthread.h>

#undef TG_SYNCHRONIZED_DEFINE
#undef TG_SYNCHRONIZED_INIT
#undef TG_SYNCHRONIZED_BEGIN
#undef TG_SYNCHRONIZED_END

#define TG_SYNCHRONIZED_DEFINE(lock) pthread_mutex_t TG_SYNCHRONIZED_##lock
#define TG_SYNCHRONIZED_INIT(lock) pthread_mutex_init(&TG_SYNCHRONIZED_##lock, NULL)
#define TG_SYNCHRONIZED_BEGIN(lock) pthread_mutex_lock(&TG_SYNCHRONIZED_##lock);
#define TG_SYNCHRONIZED_END(lock) pthread_mutex_unlock(&TG_SYNCHRONIZED_##lock);

static NSString *md5String(NSString *string)
{
    /*static const char *md5PropertyKey = "MD5Key";
    NSString *result = objc_getAssociatedObject(string, md5PropertyKey);
    if (result != nil)
        return result;*/
    
    const char *ptr = [string UTF8String];
    unsigned char md5Buffer[16];
    CC_MD5(ptr, (CC_LONG)[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], md5Buffer);
    NSString *output = [[NSString alloc] initWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5Buffer[0], md5Buffer[1], md5Buffer[2], md5Buffer[3], md5Buffer[4], md5Buffer[5], md5Buffer[6], md5Buffer[7], md5Buffer[8], md5Buffer[9], md5Buffer[10], md5Buffer[11], md5Buffer[12], md5Buffer[13], md5Buffer[14], md5Buffer[15]];
    //objc_setAssociatedObject(string, md5PropertyKey, output, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return output;
}

@interface TGCacheRecord : NSObject

@property (nonatomic) NSTimeInterval date;
@property (nonatomic, strong) id object;
@property (nonatomic) NSUInteger size;

- (id)initWithObject:(id)object size:(NSUInteger)size;

@end

@implementation TGCacheRecord

@synthesize date = _date;
@synthesize object = _object;
@synthesize size = _size;

- (id)initWithObject:(id)object size:(NSUInteger)size
{
    self = [super init];
    if (self != nil)
    {
        _object = object;
        _date = CFAbsoluteTimeGetCurrent();
        _size = size;
    }
    return self;
}

@end

static NSFileManager *cacheFileManager = nil;

@interface TGCache ()
{
    TG_SYNCHRONIZED_DEFINE(_dataMemoryCache);
}

@property (nonatomic, strong) NSMutableArray *temporaryCachedImagesSources;

@property (nonatomic, strong) NSMutableDictionary *memoryCache;
@property (nonatomic) int memoryCacheSize1;

@property (nonatomic, strong) NSMutableDictionary *thumbnailCache;
@property (nonatomic) int thumbnailCacheSize;

@property (nonatomic, strong) NSMutableDictionary *dataMemoryCache;
@property (nonatomic) int dataMemoryCacheSize;

@end

@implementation TGCache

+ (dispatch_queue_t)diskCacheQueue
{
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("com.telegraph.diskcache", 0);
        //dispatch_set_target_queue(queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
        
        if (cacheFileManager == nil)
            cacheFileManager = [[NSFileManager alloc] init];
    });
    return queue;
}

+ (NSFileManager *)diskFileManager
{
    if (cacheFileManager == nil)
        cacheFileManager = [[NSFileManager alloc] init];
    
    return cacheFileManager;
}

- (id)init {
    return [self initWithCachesPath:[[LegacyComponentsGlobals provider] dataCachePath]];
}

- (id)initWithCachesPath:(NSString *)cachesPath
{
    self = [super init];
    if (self != nil)
    {
        TG_SYNCHRONIZED_INIT(_dataMemoryCache);
        
        _imageMemoryLimit = deviceMemorySize() > 300 ? (int)(15 * 1024 * 1024) : (int)(11 * 1024 * 1024);
        _imageMemoryEvictionInterval = deviceMemorySize() > 300 ? 1024 * 1024 : 812 * 1024;
        
        //_imageMemoryLimit = 10;
        //_imageMemoryEvictionInterval = 10;
        
        _thumbnailMemoryLimit = deviceMemorySize() > 300 ? (int)(1.6 * 1024 * 1024) : (int)(1.1 * 1024 * 1024);
        _thumbnailEvictionInterval = cpuCoreCount() > 1 ? (int)(0.4 * 1024 * 1024) : (int)(0.25 * 1024 * 1024);
        
        _dataMemoryLimit = deviceMemorySize() > 300 ? (int)(1 * 1024 * 1024) : (int)(0.6 * 1024 * 1024);
        _dataMemoryEvictionInterval = cpuCoreCount() > 1 ? (int)(0.4 * 1024 * 1024) : (int)(0.25 * 1024 * 1024);
        
        _diskLimit = 32 * 1024 * 1024;
        _diskEvictionInterval = 6 * 1024 * 1024;
        
        _memoryWarningBaseline = deviceMemorySize() > 300 ? (int)(1.5 * 1024 * 1024) : (int)(1.1 * 1024 * 1024);
        
        _backgroundBaseline = deviceMemorySize() > 300 ? (int)(5.8 * 1024 * 1024) : (int)(2.8 * 1024 * 1024);
        
        _temporaryCachedImagesSources = [[NSMutableArray alloc] init];
        
        _memoryCache = [[NSMutableDictionary alloc] init];
        self.memoryCacheSize = 0;
        
        _thumbnailCache = [[NSMutableDictionary alloc] init];
        _thumbnailCacheSize = 0;
        
        _dataMemoryCache = [[NSMutableDictionary alloc] init];
        _dataMemoryCacheSize = 0;
        
        _diskCachePath = cachesPath;
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        if (![fileManager fileExistsAtPath:_diskCachePath])
            [fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

- (int)memoryCacheSize
{
    return _memoryCacheSize1;
}

- (void)setMemoryCacheSize:(int)memoryCacheSize
{
    _memoryCacheSize1 = memoryCacheSize;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning:(NSNotification *)__unused notification
{
    [self freeMemoryCache:_memoryWarningBaseline];
}

- (void)didEnterBackground:(NSNotification *)__unused notification
{
    [self freeMemoryCache:_backgroundBaseline];
}

- (void)addTemporaryCachedImagesSource:(NSDictionary *)source autoremove:(bool)autoremove
{
    dispatch_block_t block = ^
    {
        [_temporaryCachedImagesSources addObject:source];
        if (autoremove)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self removeTemporaryCachedImageSource:source];
            });
        }
    };
    
    if ([NSThread isMainThread])
        block();
    else
        dispatch_async(dispatch_get_main_queue(), block);
}

- (void)removeTemporaryCachedImageSource:(NSDictionary *)source
{
    dispatch_block_t block = ^
    {
        [_temporaryCachedImagesSources removeObject:source];
    };
    
    if ([NSThread isMainThread])
        block();
    else
        dispatch_async(dispatch_get_main_queue(), block);
}

- (void)freeMemoryCache:(NSUInteger)targetSize
{
    dispatch_block_t block = ^
    {
        if (self.memoryCacheSize > (int)targetSize)
        {
            __unused int sizeBefore = self.memoryCacheSize;
            NSArray *sortedKeys = [_memoryCache keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2)
            {
                return (((TGCacheRecord *)obj1).date < ((TGCacheRecord *)obj2).date) ? NSOrderedAscending : NSOrderedDescending;
            }];
            for (int i = 0; i < (int)sortedKeys.count && self.memoryCacheSize > (int)targetSize; i++)
            {
                NSString *key = [sortedKeys objectAtIndex:i];
                TGCacheRecord *record = [_memoryCache objectForKey:key];
                self.memoryCacheSize -= (int)record.size;
                if (self.memoryCacheSize < 0)
                    self.memoryCacheSize = 0;
                [_memoryCache removeObjectForKey:key];
                //TGLegacyLog(@"evict %@", key);
            }
            
            __block int currentCacheSize = 0;
            [_memoryCache enumerateKeysAndObjectsUsingBlock:^(__unused NSString *key, TGCacheRecord *record, __unused BOOL *stop)
            {
                currentCacheSize += record.size;
            }];
            
            self.memoryCacheSize = currentCacheSize;
            
            //TGLegacyLog(@"TGCache: freed %d kbytes (cache size: %d kbytes)", (int)((sizeBefore - self.memoryCacheSize) / 1024), (int)(self.memoryCacheSize / 1024));
        }
    };
    if ([NSThread isMainThread])
        block();
    else
        dispatch_async(dispatch_get_main_queue(), block);
}

- (void)freeThumbnailCache:(NSUInteger)targetSize
{
    dispatch_block_t block = ^
    {
        if (_thumbnailCacheSize > (int)targetSize)
        {
            //int sizeBefore = _thumbnailCacheSize;
            NSArray *sortedKeys = [_thumbnailCache keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2)
            {
                return (((TGCacheRecord *)obj1).date < ((TGCacheRecord *)obj2).date) ? NSOrderedAscending : NSOrderedDescending;
            }];
            for (int i = 0; i < (int)sortedKeys.count && _thumbnailCacheSize > (int)targetSize; i++)
            {
                NSString *key = [sortedKeys objectAtIndex:i];
                TGCacheRecord *record = [_thumbnailCache objectForKey:key];
                _thumbnailCacheSize -= record.size;
                if (_thumbnailCacheSize < 0)
                    _thumbnailCacheSize = 0;
                [_thumbnailCache removeObjectForKey:key];
            }
        }
    };
    if ([NSThread isMainThread])
        block();
    else
        dispatch_async(dispatch_get_main_queue(), block);
}

- (void)freeCompressedMemoryCache:(NSUInteger)targetSize reentrant:(bool)reentrant
{
    if (!reentrant)
        TG_SYNCHRONIZED_BEGIN(_dataMemoryCache);
    {
        if (_dataMemoryCacheSize > (int)targetSize)
        {
            __unused int sizeBefore = _dataMemoryCacheSize;
            NSArray *sortedKeys = [_dataMemoryCache keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2)
            {
                return (((TGCacheRecord *)obj1).date < ((TGCacheRecord *)obj2).date) ? NSOrderedAscending : NSOrderedDescending;
            }];
            for (int i = 0; i < (int)sortedKeys.count && _dataMemoryCacheSize > (int)targetSize; i++)
            {
                NSString *key = [sortedKeys objectAtIndex:i];
                TGCacheRecord *record = [_dataMemoryCache objectForKey:key];
                _dataMemoryCacheSize -= record.size;
                if (_dataMemoryCacheSize < 0)
                    _dataMemoryCacheSize = 0;
                [_dataMemoryCache removeObjectForKey:key];
            }
            //TGLegacyLog(@"TGCache (compressed): freed %d kbytes (cache size: %d kbytes)", (int)((sizeBefore - _dataMemoryCacheSize) / 1024), (int)(_dataMemoryCacheSize / 1024));
        }
    }
    if (!reentrant)
        TG_SYNCHRONIZED_END(_dataMemoryCache);
}

- (void)cacheCompressedObject:(NSData *)data url:(NSString *)url reentrant:(bool)reentrant
{
    if (!reentrant)
        TG_SYNCHRONIZED_BEGIN(_dataMemoryCache);
    
    TGCacheRecord *cacheRecord = [_dataMemoryCache objectForKey:url];
    if (cacheRecord != nil)
    {
        _dataMemoryCacheSize -= cacheRecord.size;
        cacheRecord.date = CFAbsoluteTimeGetCurrent();
        cacheRecord.object = data;
        cacheRecord.size = data.length;
        _dataMemoryCacheSize += cacheRecord.size;
    }
    else
    {
        [_dataMemoryCache setObject:[[TGCacheRecord alloc] initWithObject:data size:data.length] forKey:url];
        _dataMemoryCacheSize += data.length;
    }
    
    if (_dataMemoryCacheSize >= _dataMemoryLimit + _dataMemoryEvictionInterval)
        [self freeCompressedMemoryCache:_dataMemoryLimit reentrant:true];
    
    if (!reentrant)
        TG_SYNCHRONIZED_END(_dataMemoryCache);
}

- (void)cacheImage:(UIImage *)image withData:(NSData *)data url:(NSString *)url availability:(int)availability
{
    [self cacheImage:image withData:data url:url availability:availability completion:nil];
}

- (void)cacheImage:(UIImage *)image withData:(NSData *)data url:(NSString *)url availability:(int)availability completion:(void (^)(void))completion
{
#ifdef DEBUG
    if (data != nil)
        TGLegacyLog(@"cache image %d bytes with url %@", (int)data.length, url);
#endif
    
    if (image != nil && (availability & TGCacheMemory))
    {
        int size = (int)(image.size.width * image.size.height * 4 * image.scale);
        dispatch_block_t block = ^
        {
            TGCacheRecord *cacheRecord = [_memoryCache objectForKey:url];
            if (cacheRecord != nil)
            {
                self.memoryCacheSize -= (int)cacheRecord.size;
                cacheRecord.date = CFAbsoluteTimeGetCurrent();
                cacheRecord.object = image;
                cacheRecord.size = size;
                self.memoryCacheSize += size;
            }
            else
            {
                [_memoryCache setObject:[[TGCacheRecord alloc] initWithObject:image size:size] forKey:url];
                self.memoryCacheSize += size;
            }
            
            if (self.memoryCacheSize >= _imageMemoryLimit + _imageMemoryEvictionInterval)
                [self freeMemoryCache:_imageMemoryLimit];
        };
        if ([NSThread isMainThread])
            block();
        else
            dispatch_async(dispatch_get_main_queue(), block);
    }
    
    if ((data != nil || image != nil) && (availability & TGCacheDisk) && url != nil)
    {
        dispatch_async([TGCache diskCacheQueue], ^
        {   
            if (data != nil)
            {
                [self cacheCompressedObject:data url:url reentrant:false];

                [data writeToFile:[_diskCachePath stringByAppendingPathComponent:md5String(url)] atomically:true];
                
                if (completion != nil)
                    completion();
            }
        });
    }
}

- (UIImage *)cachedImage:(NSString *)url availability:(int)availability
{
    UIImage *image = nil;
    
    if (availability & TGCacheMemory)
    {
        __block UIImage *blockImage = nil;
        dispatch_block_t block = ^
        {
            TGCacheRecord *cacheRecord = [_memoryCache objectForKey:url];
            if (cacheRecord != nil)
            {
                cacheRecord.date = CFAbsoluteTimeGetCurrent();
                blockImage = cacheRecord.object;
            }
            else if (_temporaryCachedImagesSources.count != 0)
            {
                for (NSDictionary *dict in _temporaryCachedImagesSources)
                {
                    UIImage *image = [dict objectForKey:url];
                    //TGLegacyLog(@"From temp cache %@", url);
                    if (image != nil)
                    {
                        blockImage = image;
                        break;
                    }
                }
            }
        };
        if ([NSThread isMainThread])
            block();
        else
            dispatch_sync(dispatch_get_main_queue(), block);
        image = blockImage;
    }
    
    if (image != nil)
        return image;
    
    if (availability & TGCacheDisk)
    {
        UIImage *dataImage = nil;
        
        TG_SYNCHRONIZED_BEGIN(_dataMemoryCache);
        {
            TGCacheRecord *cacheRecord = [_dataMemoryCache objectForKey:url];
            if (cacheRecord != nil)
            {
                cacheRecord.date = CFAbsoluteTimeGetCurrent();
                
                {
                    NSDictionary *dict = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:true] forKey:(id)kCGImageSourceShouldCache];
                    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)cacheRecord.object, nil);
                    if (source != nil)
                    {
                        CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, 0, (__bridge CFDictionaryRef)dict);
                        
                        dataImage = [[UIImage alloc] initWithCGImage:cgImage];
                        
                        CGImageRelease(cgImage);
                        CFRelease(source);
                    }
                }
                
                if (dataImage != nil && (availability & TGCacheMemory))
                    [self cacheImage:dataImage withData:nil url:url availability:TGCacheMemory];
            }
        }
        TG_SYNCHRONIZED_END(_dataMemoryCache);
        
        if (dataImage != nil)
            return dataImage;
        
        __block UIImage *diskImageResult = nil;
        dispatch_sync([TGCache diskCacheQueue], ^
        {
            NSDictionary *dict = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:true] forKey:(id)kCGImageSourceShouldCache];
            
            NSURL *realUrl = [[NSURL alloc] initFileURLWithPath:[_diskCachePath stringByAppendingPathComponent:md5String(url)]];
            CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)realUrl, NULL);
            if (source != nil)
            {
                CGImageRef cgImage = CGImageSourceCreateImageAtIndex(source, 0, (__bridge CFDictionaryRef)dict);
                
                UIImage *diskImage = [UIImage imageWithCGImage:cgImage];
                
                if (diskImage != nil && (availability & TGCacheMemory))
                {
                    [self cacheImage:diskImage withData:nil url:url availability:TGCacheMemory];
                }
             
                if (diskImage != nil)
                {
                    diskImageResult = diskImage;
                    
                    if (diskImage != nil)
                    {
                        dispatch_async([TGCache diskCacheQueue], ^
                        {
                            NSData *data = [[NSData alloc] initWithContentsOfURL:realUrl];
                            if (data != nil)
                            {
                                [self cacheCompressedObject:data url:url reentrant:false];
                            }
                        });
                    }
                }
                
                CGImageRelease(cgImage);
                CFRelease(source);
            }
        });
        image = diskImageResult;
        return image;
    }
    
    return nil;
}

- (void)removeFromMemoryCache:(NSString *)url matchEnd:(bool)matchEnd
{
    if (url == nil)
        return;
    
    dispatch_block_t block = ^
    {
        TGCacheRecord *cacheRecord = [_memoryCache objectForKey:url];
        if (cacheRecord != nil)
        {
            self.memoryCacheSize -= (int)cacheRecord.size;
            if (self.memoryCacheSize < 0)
                self.memoryCacheSize = 0;
            [_memoryCache removeObjectForKey:url];
        }
        
        if (matchEnd)
        {
            NSMutableArray *removeKeys = [[NSMutableArray alloc] init];
            
            [_memoryCache enumerateKeysAndObjectsUsingBlock:^(NSString *key, __unused id obj, __unused BOOL *stop)
            {
                if ([key hasSuffix:url])
                    [removeKeys addObject:key];
            }];
            
            [_memoryCache removeObjectsForKeys:removeKeys];
        }
        
        TGCacheRecord *dataCacheRecord = [_dataMemoryCache objectForKey:url];
        if (dataCacheRecord != nil)
        {
            _dataMemoryCacheSize -= dataCacheRecord.size;
            if (_dataMemoryCacheSize < 0)
                _dataMemoryCacheSize = 0;
            [_dataMemoryCache removeObjectForKey:url];
        }
    };
    if ([NSThread isMainThread])
        block();
    else
        dispatch_sync(dispatch_get_main_queue(), block);
}

- (void)cacheThumbnail:(UIImage *)image url:(NSString *)url
{
    if ([self cachedThumbnail:url] != nil)
        return;
    
    if (image != nil)
    {
        int side = 32;
        if (!TGIsRetina())
            side *= 2;
        int size = (int)(side * side * 4);
        if (image.size.width > side || image.size.height > side)
        {
            image = TGScaleImage(image, CGSizeMake(side, side));
        }
        else
            return;
        
        dispatch_block_t block = ^
        {
            TGCacheRecord *cacheRecord = [_thumbnailCache objectForKey:url];
            if (cacheRecord != nil)
            {
                _thumbnailCacheSize -= cacheRecord.size;
                cacheRecord.date = CFAbsoluteTimeGetCurrent();
                cacheRecord.object = image;
                cacheRecord.size = size;
                _thumbnailCacheSize += size;
            }
            else
            {
                [_thumbnailCache setObject:[[TGCacheRecord alloc] initWithObject:image size:size] forKey:url];
                _thumbnailCacheSize += size;
            }
            
            //TGLegacyLog(@"Cache thumbnail: %@", url);
            
            //TGLegacyLog(@"_thumbnailCacheSize = %d", _thumbnailCacheSize);
            
            if (_thumbnailCacheSize >= _thumbnailMemoryLimit + _thumbnailEvictionInterval)
                [self freeThumbnailCache:_thumbnailMemoryLimit];
        };
        if ([NSThread isMainThread])
            block();
        else
            dispatch_async(dispatch_get_main_queue(), block);
    }
}

- (UIImage *)cachedThumbnail:(NSString *)url
{
    UIImage *image = nil;
    __block UIImage *blockImage = nil;
    dispatch_block_t block = ^
    {
        TGCacheRecord *cacheRecord = [_thumbnailCache objectForKey:url];
        if (cacheRecord != nil)
        {
            cacheRecord.date = CFAbsoluteTimeGetCurrent();
            blockImage = cacheRecord.object;
        }
        else
        {
            //TGLegacyLog(@"Thumbnail not found: %@", url);
        }
    };
    if ([NSThread isMainThread])
        block();
    else
        dispatch_async(dispatch_get_main_queue(), block);
    image = blockImage;
    if (image != nil)
        return image;
    
    return nil;
}

- (void)diskCacheContains:(NSString *)url1 orUrl:(NSString *)url2 completion:(void (^)(bool containsFirst, bool containsSecond))completion
{   
    dispatch_async([TGCache diskCacheQueue], ^
    {
        bool cached = [cacheFileManager fileExistsAtPath:[_diskCachePath stringByAppendingPathComponent:md5String(url1)]];
        if (cached)
        {
            if (completion)
                completion(true, false);
        }
        else if (url2 != nil)
        {
            cached = [cacheFileManager fileExistsAtPath:[_diskCachePath stringByAppendingPathComponent:md5String(url2)]];
            if (completion)
                completion(false, cached);
        }
        else
        {
            if (completion)
                completion(false, false);
        }
    });
}

- (bool)diskCacheContainsSync:(NSString *)url
{
    __block bool result = false;
    
    dispatch_sync([TGCache diskCacheQueue], ^
    {
        result = [cacheFileManager fileExistsAtPath:[_diskCachePath stringByAppendingPathComponent:md5String(url)]];
    });
    
    return result;
}

- (void)removeFromDiskCache:(NSString *)url
{
    dispatch_async([TGCache diskCacheQueue], ^
    {
        [cacheFileManager removeItemAtPath:[_diskCachePath stringByAppendingPathComponent:md5String(url)] error:nil];
    });
}

- (NSString *)pathForCachedData:(NSString *)url
{
    return [_diskCachePath stringByAppendingPathComponent:md5String(url)];
}

- (void)changeCacheItemUrl:(NSString *)oldUrl newUrl:(NSString *)newUrl
{
    //TGLegacyLog(@"TGCache: rename \"%@\" -> \"%@\"", oldUrl, newUrl);
    dispatch_block_t block = ^
    {
        TGCacheRecord *record = [_memoryCache objectForKey:oldUrl];
        if (record != nil)
        {
            [_memoryCache setObject:record forKey:newUrl];
            [_memoryCache removeObjectForKey:oldUrl];
        }
    };
    if ([NSThread isMainThread])
        block();
    else
        dispatch_async(dispatch_get_main_queue(), block);
    
    dispatch_async([TGCache diskCacheQueue], ^
    {
        NSError *error = nil;
        [cacheFileManager moveItemAtPath:[_diskCachePath stringByAppendingPathComponent:md5String(oldUrl)] toPath:[_diskCachePath stringByAppendingPathComponent:md5String(newUrl)] error:&error];
        if (error != nil)
            TGLegacyLog(@"Failed to move: %@", error);
    });
}

- (void)moveToCache:(NSString *)fileUrl cacheUrl:(NSString *)cacheUrl
{
    TGLegacyLog(@"TGCache: move \"%@\" -> \"%@\"", fileUrl, cacheUrl);
    dispatch_block_t block = ^
    {
        TGCacheRecord *record = [_memoryCache objectForKey:fileUrl];
        if (record != nil)
        {
            [_memoryCache setObject:record forKey:cacheUrl];
            [_memoryCache removeObjectForKey:fileUrl];
        }
    };
    if ([NSThread isMainThread])
        block();
    else
        dispatch_async(dispatch_get_main_queue(), block);
    
    dispatch_async([TGCache diskCacheQueue], ^
    {
        NSError *error = nil;

        NSString *targetPath = [_diskCachePath stringByAppendingPathComponent:md5String(cacheUrl)];
        if ([[NSFileManager defaultManager] fileExistsAtPath:targetPath])
            [[NSFileManager defaultManager] removeItemAtPath:targetPath error:NULL];
        
        [cacheFileManager moveItemAtPath:fileUrl toPath:targetPath error:&error];
        if (error != nil)
            TGLegacyLog(@"Failed to move: %@", error);
    });
}

- (void)clearCache:(int)availability
{
    if (availability & TGCacheMemory)
    {
        dispatch_block_t block = ^
        {
            [_memoryCache removeAllObjects];
            self.memoryCacheSize = 0;
        };
        if ([NSThread isMainThread])
            block();
        else
            dispatch_async(dispatch_get_main_queue(), block);
        
        TG_SYNCHRONIZED_BEGIN(_dataMemoryCache);
        [_dataMemoryCache removeAllObjects];
        _dataMemoryCacheSize = 0;
        TG_SYNCHRONIZED_END(_dataMemoryCache);
    }
    if (availability & TGCacheDisk)
    {
        dispatch_async([TGCache diskCacheQueue], ^
        {
            NSDirectoryEnumerator* en = [cacheFileManager enumeratorAtPath:_diskCachePath];
            NSError* error = nil;
            
            int removedCount = 0;
            int failedCount = 0;
            
            NSString* file;
            while (file = [en nextObject])
            {
                if ([cacheFileManager removeItemAtPath:[_diskCachePath stringByAppendingPathComponent:file] error:&error])
                    removedCount++;
                else
                    failedCount++;
            }
            
            TGLegacyLog(@"TGCache: removed %d files (%d failed)", removedCount, failedCount);
        });
    }
}

- (NSArray *)storeMemoryCache
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    
    dispatch_block_t block = ^
    {
        [_memoryCache enumerateKeysAndObjectsUsingBlock:^(NSString *key, __unused id obj, __unused BOOL *stop)
        {
            [array addObject:key];
        }];
    };
    if ([NSThread isMainThread])
        block();
    else
        dispatch_sync(dispatch_get_main_queue(), block);
    
    return array;
}

- (void)restoreMemoryCache:(NSArray *)array
{
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    for (NSString *url in array)
    {
        [self cachedImage:url availability:TGCacheDisk];
    }
    TGLegacyLog(@"Cache restored in %f ms", (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0);
}

@end
