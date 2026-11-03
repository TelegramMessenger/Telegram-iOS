#import <SSignalKit/SSignalKit.h>

@interface TGBridgeConversationSignals : NSObject

+ (SSignal *)conversationWithPeerId:(int64_t)peerId;

@end
