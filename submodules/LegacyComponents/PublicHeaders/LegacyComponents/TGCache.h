#import <UIKit/UIKit.h>

typedef enum {
    TGCacheMemory = 1,
    TGCacheDisk = 2,
    TGCacheBoth = 1 | 2
} TGCacheLocation;

typedef UIImage *(^TGCacheJpegDecodingBlock)(NSData *data);

@interface TGCache : NSObject

@property (nonatomic) int imageMemoryLimit;
@property (nonatomic) int imageMemoryEvictionInterval;

@property (nonatomic) int thumbnailMemoryLimit;
@property (nonatomic) int thumbnailEvictionInterval;
@property (nonatomic) int thumbnailBackgroundBaseline;

@property (nonatomic) int dataMemoryLimit;
@property (nonatomic) int dataMemoryEvictionInterval;

@property (nonatomic) int memoryWarningBaseline;
@property (nonatomic) int backgroundBaseline;

@property (nonatomic) int diskLimit;
@property (nonatomic) int diskEvictionInterval;

@property (nonatomic, strong, readonly) NSString *diskCachePath;

+ (dispatch_queue_t)diskCacheQueue;
+ (NSFileManager *)diskFileManager;

- (id)init;
- (id)initWithCachesPath:(NSString *)cachesPath;

- (void)addTemporaryCachedImagesSource:(NSDictionary *)source autoremove:(bool)autoremove;
- (void)removeTemporaryCachedImageSource:(NSDictionary *)source;

- (void)cacheImage:(UIImage *)image withData:(NSData *)data url:(NSString *)url availability:(int)availability;
- (void)cacheImage:(UIImage *)image withData:(NSData *)data url:(NSString *)url availability:(int)availability completion:(void (^)(void))completion;
- (UIImage *)cachedImage:(NSString *)url availability:(int)availability;
- (void)removeFromMemoryCache:(NSString *)url matchEnd:(bool)matchEnd;
- (NSString *)pathForCachedData:(NSString *)url;

- (void)cacheThumbnail:(UIImage *)image url:(NSString *)url;
- (UIImage *)cachedThumbnail:(NSString *)url;

- (void)diskCacheContains:(NSString *)url1 orUrl:(NSString *)url2 completion:(void (^)(bool containsFirst, bool containsSecond))completion;
- (bool)diskCacheContainsSync:(NSString *)url;
- (void)removeFromDiskCache:(NSString *)url;
- (void)changeCacheItemUrl:(NSString *)oldUrl newUrl:(NSString *)newUrl;
- (void)moveToCache:(NSString *)fileUrl cacheUrl:(NSString *)cacheUrl;
- (void)clearCache:(int)availability;
- (NSArray *)storeMemoryCache;
- (void)restoreMemoryCache:(NSArray *)urlArray;

@end
