#import "TGBridgeAudioSignals.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGBridgeClient.h"
#import "TGFileCache.h"

#import "TGExtensionDelegate.h"
#import <libkern/OSAtomic.h>

@interface TGBridgeAudioManager : NSObject
{
    NSMutableArray *_pendingUrls;
    OSSpinLock _pendingUrlsLock;
}
@end

@implementation TGBridgeAudioManager

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
    OSSpinLockLock(&_pendingUrlsLock);
    [_pendingUrls addObject:url];
    OSSpinLockUnlock(&_pendingUrlsLock);
}

- (void)removeUrl:(NSString *)url
{
    OSSpinLockLock(&_pendingUrlsLock);
    [_pendingUrls removeObject:url];
    OSSpinLockUnlock(&_pendingUrlsLock);
}

- (bool)hasUrl:(NSString *)url
{
    OSSpinLockLock(&_pendingUrlsLock);
    bool contains = [_pendingUrls containsObject:url];
    OSSpinLockUnlock(&_pendingUrlsLock);
    
    return contains;
}

@end


@implementation TGBridgeAudioSignals

+ (SSignal *)audioForAttachment:(TGBridgeMediaAttachment *)attachment conversationId:(int64_t)conversationId messageId:(int32_t)messageId
{
    NSString *url = [NSString stringWithFormat:@"audio_%lld_%d", conversationId, messageId];    
    SSignal *remoteSignal = [[[[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeAudioSubscription alloc] initWithAttachment:attachment peerId:conversationId messageId:messageId]] onDispose:^
    {
        // cancel download
    }] mapToSignal:^SSignal *(__unused id next)
    {
        return [self _downloadedFileWithUrl:url];
    }];
    
    return [[self _cachedOrPendingWithUrl:url] catch:^SSignal *(id error)
    {
        return remoteSignal;
    }];
}

+ (SSignal *)_loadCachedWithUrl:(NSString *)url
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        TGFileCache *audioCache = [TGExtensionDelegate instance].audioCache;
        if ([audioCache hasDataForKey:url])
        {
            [subscriber putNext:[audioCache urlForKey:url]];
            [subscriber putCompletion];
        }
        else
        {
            [subscriber putError:nil];
        }
        
        return nil;
    }];
}

+ (SSignal *)_downloadedFileWithUrl:(NSString *)url
{
    return [[self _loadCachedWithUrl:url] catch:^SSignal *(id error)
    {
        return [[[TGBridgeClient instance] fileSignalForKey:url] take:1];
    }];
}

+ (SSignal *)_cachedOrPendingWithUrl:(NSString *)url
{
    return [[self _loadCachedWithUrl:url] catch:^SSignal *(id error)
    {
        if ([[self audioManager] hasUrl:url])
            return [self _downloadedFileWithUrl:url];
        
        return [SSignal fail:nil];
    }];
}

+ (SSignal *)sentAudioForConversationId:(int64_t)conversationId
{
    return [[[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeAudioSentSubscription alloc] initWithConversationId:conversationId]] onNext:^(TGBridgeMessage *next)
    {
        int64_t identifier = 0;
        int64_t localIdentifier = 0;
        for (TGBridgeMediaAttachment *attachment in next.media)
        {
            if ([attachment isKindOfClass:[TGBridgeAudioMediaAttachment class]])
            {
                identifier = ((TGBridgeAudioMediaAttachment *)attachment).audioId;
                localIdentifier = ((TGBridgeAudioMediaAttachment *)attachment).localAudioId;
            }
            else if ([attachment isKindOfClass:[TGBridgeDocumentMediaAttachment class]])
            {
                identifier = ((TGBridgeDocumentMediaAttachment *)attachment).documentId;
                localIdentifier = ((TGBridgeDocumentMediaAttachment *)attachment).localDocumentId;
            }
        }
        
        if (identifier != 0 && localIdentifier != 0)
        {
            TGFileCache *audioCache = [[TGExtensionDelegate instance] audioCache];
            
            NSString *localId = [NSString stringWithFormat:@"%lld", localIdentifier];
            NSString *audioId = [NSString stringWithFormat:@"%lld", identifier];
            
            if ([audioCache hasDataForKey:localId] && ![audioCache hasDataForKey:audioId])
            {
                NSURL *localUrl = [audioCache urlForKey:localId];
                NSURL *remoteUrl = [audioCache urlForKey:audioId];
                
                [[NSFileManager defaultManager] moveItemAtURL:localUrl toURL:remoteUrl error:nil];
            }
        }
    }];
}

+ (TGBridgeAudioManager *)audioManager
{
    static dispatch_once_t onceToken;
    static TGBridgeAudioManager *manager;
    dispatch_once(&onceToken, ^
    {
        manager = [[TGBridgeAudioManager alloc] init];
    });
    return manager;
}

@end
