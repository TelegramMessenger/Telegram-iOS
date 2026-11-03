#import <SSignalKit/SSignalKit.h>

@interface TGBridgeRemoteSignals : NSObject

+ (SSignal *)openRemoteMessageWithPeerId:(int64_t)peerId messageId:(int32_t)messageId type:(int32_t)type autoPlay:(bool)autoPlay;

@end
