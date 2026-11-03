#import <SSignalKit/SSignalKit.h>

@interface TGBridgeBotSignals : NSObject

+ (SSignal *)botInfoForUserId:(int32_t)userId;
+ (SSignal *)botReplyMarkupForPeerId:(int64_t)peerId;

@end
