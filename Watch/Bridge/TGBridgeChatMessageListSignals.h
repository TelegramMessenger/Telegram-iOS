#import <SSignalKit/SSignalKit.h>

@interface TGBridgeChatMessageListSignals : NSObject

+ (SSignal *)chatMessageListViewWithPeerId:(int64_t)peerId atMessageId:(int32_t)messageId rangeMessageCount:(NSUInteger)rangeMessageCount;

+ (SSignal *)chatMessageWithPeerId:(int64_t)peerId messageId:(int32_t)messageId;

+ (SSignal *)readChatMessageListWithPeerId:(int64_t)peerId messageId:(int32_t)messageId;

@end
