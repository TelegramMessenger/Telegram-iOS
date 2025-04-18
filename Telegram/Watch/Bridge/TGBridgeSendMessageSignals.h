#import <SSignalKit/SSignalKit.h>

#import <WatchCommonWatch/WatchCommonWatch.h>

@interface TGBridgeSendMessageSignals : NSObject

+ (SSignal *)sendMessageWithPeerId:(int64_t)peerId text:(NSString *)text replyToMid:(int32_t)replyToMid;

+ (SSignal *)sendMessageWithPeerId:(int64_t)peerId location:(TGBridgeLocationMediaAttachment *)location replyToMid:(int32_t)replyToMid;

+ (SSignal *)sendMessageWithPeerId:(int64_t)peerId sticker:(TGBridgeDocumentMediaAttachment *)sticker replyToMid:(int32_t)replyToMid;

+ (SSignal *)forwardMessageWithPeerId:(int64_t)peerId mid:(int32_t)mid targetPeerId:(int64_t)targetPeerId;

@end
