#import <SSignalKit/SSignalKit.h>

@interface TGBridgePeerSettingsSignals : NSObject

+ (SSignal *)peerSettingsWithPeerId:(int64_t)peerId;

+ (SSignal *)toggleMutedWithPeerId:(int64_t)peerId;
+ (SSignal *)updateBlockStatusWithPeerId:(int64_t)peerId blocked:(bool)blocked;

@end
