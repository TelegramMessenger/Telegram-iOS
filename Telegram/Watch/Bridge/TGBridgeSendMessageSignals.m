#import "TGBridgeSendMessageSignals.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGBridgeClient.h"

@implementation TGBridgeSendMessageSignals

+ (SSignal *)sendMessageWithPeerId:(int64_t)peerId text:(NSString *)text replyToMid:(int32_t)replyToMid
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeSendTextMessageSubscription alloc] initWithPeerId:peerId text:text replyToMid:replyToMid]];
}

+ (SSignal *)sendMessageWithPeerId:(int64_t)peerId location:(TGBridgeLocationMediaAttachment *)location replyToMid:(int32_t)replyToMid
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeSendLocationMessageSubscription alloc] initWithPeerId:peerId location:location replyToMid:replyToMid]];
}

+ (SSignal *)sendMessageWithPeerId:(int64_t)peerId sticker:(TGBridgeDocumentMediaAttachment *)sticker replyToMid:(int32_t)replyToMid
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeSendStickerMessageSubscription alloc] initWithPeerId:peerId document:sticker replyToMid:replyToMid]];
}

+ (SSignal *)forwardMessageWithPeerId:(int64_t)peerId mid:(int32_t)mid targetPeerId:(int64_t)targetPeerId
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeSendForwardedMessageSubscription alloc] initWithPeerId:peerId messageId:mid targetPeerId:targetPeerId]];
}

@end
