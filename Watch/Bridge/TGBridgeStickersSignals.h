#import <SSignalKit/SSignalKit.h>

@interface TGBridgeStickersSignals : NSObject

+ (SSignal *)recentStickersWithLimit:(NSUInteger)limit;
+ (SSignal *)stickerPacks;

+ (NSURL *)stickerPacksURL;

@end
