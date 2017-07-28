#import <UIKit/UIKit.h>

#import <LegacyComponents/ActionStage.h>
#import <LegacyComponents/TGCache.h>

#define TG_CACHE_INPLACE false

typedef enum {
    TGRemoteImageContentHintLargeFile = 1,
    TGRemoteImageContentHintSaveToGallery = 2,
    TGRemoteImageContentHintLoadFromDiskSynchronously = 4,
    TGRemoteImageContentHintBlurRemote = 8
} TGRemoteImageContentHints;

@class TGRemoteImageView;

typedef UIImage *(^TGImageProcessor)(UIImage *);
typedef UIImage *(^TGImageUniversalProcessor)(NSString *, UIImage *);

typedef void (^TGImageProgressHandler)(TGRemoteImageView *imageView, float progress);

@interface TGRemoteImageView : UIImageView
<ASWatcher>
@property (nonatomic, strong) ASHandle *actionHandle;
@property (nonatomic, strong) NSString *reuseIdentifier;

@property (nonatomic, strong) TGCache *cache;
@property (nonatomic) bool useCache;
@property (nonatomic) int contentHints;
@property (nonatomic) id userProperties;

@property (nonatomic) bool fadeTransition;
@property (nonatomic) NSTimeInterval fadeTransitionDuration;
@property (nonatomic) bool allowThumbnailCache;

#if TGRemoteImageUseContents
@property (nonatomic, strong) UIImage *image;
#endif
@property (nonatomic, strong) UIView *placeholderOverlay;

@property (nonatomic, strong) NSString *currentUrl;
@property (nonatomic, strong) NSString *currentFilter;

@property (nonatomic, copy) TGImageProgressHandler progressHandler;

@property (nonatomic) int cancelTimeout;

+ (void)throttleDownProcessing;
+ (void)registerImageUniversalProcessor:(TGImageUniversalProcessor)universalProcessor withBaseName:(NSString *)baseName;
+ (void)registerImageProcessor:(TGImageProcessor)imageProcessor withName:(NSString *)name;
+ (TGImageProcessor)imageProcessorForName:(NSString *)name;

+ (void)setSharedCache:(TGCache *)cache;
+ (TGCache *)sharedCache;

- (UIImage *)currentImage;
- (UIImage *)currentPlaceholderImage;

- (void)tryFillCache:(NSMutableDictionary *)dict;

- (void)loadImage:(UIImage *)image;
- (void)loadImage:(NSString *)url filter:(NSString *)filter placeholder:(UIImage *)placeholder;
- (void)loadImage:(NSString *)url filter:(NSString *)filter placeholder:(UIImage *)placeholder forceFade:(bool)forceFade;
- (void)loadPlaceholder:(UIImage *)placeholder;
- (void)cancelLoading;

+ (UIImage *)imageFromCache:(NSString *)url filter:(NSString *)filter cache:(TGCache *)cache;
+ (NSString *)preloadImage:(NSString *)url filter:(NSString *)filter blurIfRemote:(bool)blurIfRemote cache:(TGCache *)cache allowThumbnailCache:(bool)allowThumbnailCache watcher:(id<ASWatcher>)watcher;

- (void)prepareForRecycle;
- (void)prepareForReuse;

@end
