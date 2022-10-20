#import "TGBridgeStickersSignals.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGBridgeStickerPack.h"
#import "TGBridgeClient.h"

@implementation TGBridgeStickersSignals

static NSArray *cachedStickers = nil;

+ (SSignal *)cachedRecentStickers
{
    return [SSignal single:cachedStickers];
}

+ (SSignal *)recentStickersWithLimit:(NSUInteger)limit
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeRecentStickersSubscription alloc] initWithLimit:limit]];
//    return [[self cachedRecentStickers] mapToSignal:^SSignal *(NSArray *stickers) {
//        SSignal *remote = [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeRecentStickersSubscription alloc] initWithLimit:limit]];
//        remote = [remote onNext:^(NSArray *stickers) {
//            cachedStickers = stickers;
//        }];
//        if (stickers != nil) {
//            return [[SSignal single:stickers] then:remote];
//        } else {
//            return remote;
//        }
//    }];
}

+ (SSignal *)stickerPacks
{
    return [[SSignal single:[[TGBridgeClient instance] stickerPacks]] then:[[TGBridgeClient instance] fileSignalForKey:@"stickers"]];
}

+ (NSURL *)stickerPacksURL
{
    static dispatch_once_t onceToken;
    static NSURL *stickerPacksURL;
    dispatch_once(&onceToken, ^
    {
        NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true)[0];
        stickerPacksURL = [[NSURL alloc] initFileURLWithPath:[documentsPath stringByAppendingPathComponent:@"stickers.data"]];
    });
    return stickerPacksURL;
}

@end
