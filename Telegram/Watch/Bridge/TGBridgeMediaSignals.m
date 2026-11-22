#import "TGBridgeMediaSignals.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGBridgeClient.h"
#import "TGFileCache.h"

#import "TGGeometry.h"
#import "TGWatchCommon.h"

#import "TGExtensionDelegate.h"
#import <libkern/OSAtomic.h>

@interface TGBridgeMediaManager : NSObject
{
    NSMutableArray *_pendingUrls;
    OSSpinLock _pendingUrlsLock;
}
@end

@implementation TGBridgeMediaManager

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _pendingUrls = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)addUrl:(NSString *)url
{
    if (url == nil)
        return;
    
    OSSpinLockLock(&_pendingUrlsLock);
    [_pendingUrls addObject:url];
    OSSpinLockUnlock(&_pendingUrlsLock);
}

- (void)removeUrl:(NSString *)url
{
    if (url == nil)
        return;
    
    OSSpinLockLock(&_pendingUrlsLock);
    [_pendingUrls removeObject:url];
    OSSpinLockUnlock(&_pendingUrlsLock);
}

- (bool)hasUrl:(NSString *)url
{
    if (url == nil)
        return false;
    
    OSSpinLockLock(&_pendingUrlsLock);
    bool contains = [_pendingUrls containsObject:url];
    OSSpinLockUnlock(&_pendingUrlsLock);
    
    return contains;
}

@end


@implementation TGBridgeMediaSignals

+ (SSignal *)thumbnailWithPeerId:(int64_t)peerId messageId:(int32_t)messageId size:(CGSize)size notification:(bool)notification
{
    TGBridgeSubscription *subscription = [[TGBridgeMediaThumbnailSubscription alloc] initWithPeerId:peerId messageId:messageId size:size notification:notification];
    NSString *imageUrl = [NSString stringWithFormat:@"%lld_%d", peerId, messageId];
    return [self _requestImageWithUrl:imageUrl subscription:subscription];
}

+ (SSignal *)avatarWithPeerId:(int64_t)peerId url:(NSString *)url type:(TGBridgeMediaAvatarType)type
{
    NSString *imageUrl = [NSString stringWithFormat:@"%@_%lu", url, (unsigned long)type];
    TGBridgeSubscription *subscription = [[TGBridgeMediaAvatarSubscription alloc] initWithPeerId:peerId url:url type:type];
    return [self _requestImageWithUrl:imageUrl subscription:subscription];
}

+ (CGSize)_imageSizeForStickerType:(TGMediaStickerImageType)avatarType
{
    switch (avatarType)
    {
        case TGMediaStickerImageTypeList:
            return CGSizeMake(19, 19);
            
        case TGMediaStickerImageTypeNormal:
        case TGMediaStickerImageTypeInput:
        {
            return TGWatchStickerSizeForScreen(TGWatchScreenType());
        }
            
        default:
            break;
    }
    
    return CGSizeMake(72, 72);
}

+ (SSignal *)stickerWithDocumentId:(int64_t)documentId packId:(int64_t)packId accessHash:(int64_t)accessHash type:(TGMediaStickerImageType)type
{
    CGSize imageSize = [self _imageSizeForStickerType:type];
    NSString *imageUrl = [NSString stringWithFormat:@"sticker_%lld_%dx%d_0", documentId, (int)imageSize.width, (int)imageSize.height];
    
    TGBridgeSubscription *subscription = [[TGBridgeMediaStickerSubscription alloc] initWithDocumentId:documentId stickerPackId:packId stickerPackAccessHash:accessHash stickerPeerId:0 stickerMessageId:0 notification:false size:imageSize];
    
    return [self _requestImageWithUrl:imageUrl subscription:subscription];
}

+ (SSignal *)stickerWithDocumentId:(int64_t)documentId peerId:(int64_t)peerId messageId:(int32_t)messageId type:(TGMediaStickerImageType)type notification:(bool)notification
{
    CGSize imageSize = [self _imageSizeForStickerType:type];
    NSString *imageUrl = [NSString stringWithFormat:@"sticker_%lld_%dx%d_%d", documentId, (int)imageSize.width, (int)imageSize.height, notification];
    
    TGBridgeSubscription *subscription = [[TGBridgeMediaStickerSubscription alloc] initWithDocumentId:documentId stickerPackId:0 stickerPackAccessHash:0 stickerPeerId:peerId stickerMessageId:messageId notification:notification size:imageSize];
    
    return [self _requestImageWithUrl:imageUrl subscription:subscription];
}

+ (id(^)(NSData *))_imageUnserializeBlock
{
    return ^id(NSData *data)
    {
        return data;
    };
}

+ (SSignal *)_requestImageWithUrl:(NSString *)url subscription:(TGBridgeSubscription *)subscription
{
    SSignal *remoteSignal = [[[[TGBridgeClient instance] requestSignalWithSubscription:subscription] onStart:^
                              {
        if (![[self mediaManager] hasUrl:url])
            [[self mediaManager] addUrl:url];
    }] then:[[self _downloadedFileWithUrl:url] onNext:^(id next)
    {
        [[self mediaManager] removeUrl:url];
    }]];
    return [[self _cachedOrPendingWithUrl:url] catch:^SSignal *(id error)
    {
        return remoteSignal;
    }];
}

+ (SSignal *)_loadCachedWithUrl:(NSString *)url memoryOnly:(bool)memoryOnly unserializeBlock:(UIImage *(^)(NSData *))unserializeBlock
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        [[TGExtensionDelegate instance].imageCache fetchDataForKey:url memoryOnly:memoryOnly synchronous:false unserializeBlock:unserializeBlock completion:^(id image)
        {
            if (image != nil)
            {
                [subscriber putNext:image];
                [subscriber putCompletion];
            }
            else
            {
                [subscriber putError:nil];
            }
        }];
        
        return nil;
    }];
}

+ (SSignal *)_downloadedFileWithUrl:(NSString *)url
{
    return [[self _loadCachedWithUrl:url memoryOnly:true unserializeBlock:nil] catch:^SSignal *(id error)
    {
        return [[[[TGBridgeClient instance] fileSignalForKey:url] take:1] map:^NSData *(NSURL *url)
        {
            return [NSData dataWithContentsOfURL:url];
        }];
    }];
}

+ (SSignal *)_cachedOrPendingWithUrl:(NSString *)url
{
    return [[self _loadCachedWithUrl:url memoryOnly:false unserializeBlock:[self _imageUnserializeBlock]] catch:^SSignal *(id error)
    {
        if ([[self mediaManager] hasUrl:url])
            return [self _downloadedFileWithUrl:url];
        
        return [SSignal fail:nil];
    }];
}

+ (TGBridgeMediaManager *)mediaManager
{
    static dispatch_once_t onceToken;
    static TGBridgeMediaManager *manager;
    dispatch_once(&onceToken, ^
    {
        manager = [[TGBridgeMediaManager alloc] init];
    });
    return manager;
}

@end
