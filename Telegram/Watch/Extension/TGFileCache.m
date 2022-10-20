#import "TGFileCache.h"
#import "TGStringUtils.h"

NSString *const TGFileCacheDomain = @"com.telegram.FileCache";

@interface TGFileCache ()
{
    NSCache *_memoryCache;
    dispatch_queue_t _queue;
    NSURL *_url;
}
@end

@implementation TGFileCache

- (instancetype)init
{
    return [self initWithName:nil useMemoryCache:true];
}

- (instancetype)initWithName:(NSString *)name useMemoryCache:(bool)useMemoryCache
{
    self = [super init];
    if (self != nil)
    {
        if (useMemoryCache)
            _memoryCache = [[NSCache alloc] init];
        _queue = dispatch_queue_create(TGFileCacheDomain.UTF8String, nil);
        _url = [NSURL fileURLWithPath:name relativeToURL:[TGFileCache baseURL]];
        
        dispatch_async(_queue, ^
        {
            if (![[NSFileManager defaultManager] fileExistsAtPath:_url.path])
            {
                NSError *error;
                [[NSFileManager defaultManager] createDirectoryAtURL:_url withIntermediateDirectories:true attributes:nil error:&error];
            }
        });
    }
    return self;
}

- (void)fetchDataForKey:(NSString *)key synchronous:(bool)synchronous unserializeBlock:(id (^)(NSData *))unserializeBlock completion:(void (^)(id))completion
{
    [self fetchDataForKey:key memoryOnly:false synchronous:synchronous unserializeBlock:unserializeBlock completion:completion];
}

- (void)fetchDataForKey:(NSString *)key memoryOnly:(bool)memoryOnly synchronous:(bool)synchronous unserializeBlock:(id (^)(NSData *))unserializeBlock completion:(void (^)(id))completion
{
    if (completion == nil)
        return;
    
    void (^block)(void) = ^
    {
        id cachedObject = [_memoryCache objectForKey:key];
        if (cachedObject != nil)
        {
            completion(cachedObject);
            return;
        }
        
        if (!memoryOnly)
        {
            NSData *data = [[NSData alloc] initWithContentsOfURL:[self urlForKey:key] options:kNilOptions error:nil];
            if (data.length > 0)
            {
                id result = data;
                if (unserializeBlock != nil)
                {
                    result = unserializeBlock(data);
                    [_memoryCache setObject:result forKey:key];
                }
                
                completion(result);
                return;
            }
        }
        
        completion(nil);
    };
    
    if (synchronous)
        dispatch_sync(_queue, block);
    else
        dispatch_async(_queue, block);
}

- (void)cacheData:(NSData *)data key:(NSString *)key synchronous:(bool)synchronous completion:(void (^)(NSURL *))completion
{
    [self cacheData:data key:key synchronous:synchronous serializeBlock:nil completion:completion];
}

- (void)cacheData:(NSObject<NSCoding> *)data key:(NSString *)key synchronous:(bool)synchronous serializeBlock:(NSData *(^)(NSObject<NSCoding> *))serializeBlock completion:(void (^)(NSURL *))completion
{
    void (^block)(void) = ^
    {
        NSURL *url = [self urlForKey:key];
        NSData *serializedData = nil;
        if (serializeBlock != nil)
            serializedData = serializeBlock(data);
        else if ([data isKindOfClass:[NSData class]])
            serializedData = (NSData *)data;
        
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        
        [serializedData writeToURL:url atomically:true];
        if (completion != nil)
            completion(url);
    };
    
    if (synchronous)
        dispatch_sync(_queue, block);
    else
        dispatch_async(_queue, block);
}

- (void)cacheFileAtURL:(NSURL *)url key:(NSString *)key synchronous:(bool)synchronous completion:(void (^)(NSURL *))completion
{
    [self cacheFileAtURL:url key:key synchronous:synchronous unserializeBlock:nil completion:completion];
}

- (void)cacheFileAtURL:(NSURL *)url key:(NSString *)key synchronous:(bool)synchronous unserializeBlock:(id (^)(NSData *))unserializeBlock completion:(void (^)(NSURL *))completion
{
    void (^block)(void) = ^
    {
        NSURL *newUrl = [self urlForKey:key];
        [[NSFileManager defaultManager] copyItemAtURL:url toURL:newUrl error:NULL];
        if (completion != nil)
            completion(newUrl);
        
        if (unserializeBlock != nil && _memoryCache != nil)
        {
            NSData *data = [NSData dataWithContentsOfURL:url];
            id result = unserializeBlock(data);
            [_memoryCache setObject:result forKey:key];
        }
    };
    
    if (synchronous)
        dispatch_sync(_queue, block);
    else
        dispatch_async(_queue, block);
}

- (void)cacheData:(NSData *)data key:(NSString *)key synchronous:(bool)synchronous unserializeBlock:(id (^)(NSData *))unserializeBlock completion:(void (^)(NSURL *))completion
{
    void (^block)(void) = ^
    {
        NSURL *newUrl = [self urlForKey:key];
        [data writeToURL:newUrl atomically:true];
        if (completion != nil)
            completion(newUrl);
        
        if (unserializeBlock != nil && _memoryCache != nil)
        {
            id result = unserializeBlock(data);
            [_memoryCache setObject:result forKey:key];
        }
    };
    
    if (synchronous)
        dispatch_sync(_queue, block);
    else
        dispatch_async(_queue, block);
}

- (void)clearCacheSynchronous:(bool)synchronous
{
    void (^block)(void) = ^
    {
        NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:_url includingPropertiesForKeys:nil options:kNilOptions error:NULL];
        for (NSURL *url in contents)
            [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
    };
    
    if (synchronous)
        dispatch_sync(_queue, block);
    else
        dispatch_async(_queue, block);
}

- (bool)hasDataForKey:(NSString *)key
{
    return [[NSFileManager defaultManager] fileExistsAtPath:[self urlForKey:key].path];
}

- (NSURL *)urlForKey:(NSString *)key
{
    NSString *fileName = [TGStringUtils md5WithString:key];
    if (self.defaultFileExtension != nil)
        fileName = [fileName stringByAppendingPathExtension:self.defaultFileExtension];
    
    return [NSURL fileURLWithPath:[_url.path stringByAppendingPathComponent:fileName]];
}

+ (NSURL *)baseURL
{
    static dispatch_once_t onceToken;
    static NSURL *baseURL;
    dispatch_once(&onceToken, ^
    {
        NSString *cachesPath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, true)[0];
        baseURL = [[NSURL alloc] initFileURLWithPath:[cachesPath stringByAppendingPathComponent:TGFileCacheDomain]];
    });
    return baseURL;
}

@end
