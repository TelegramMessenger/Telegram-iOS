#import "TGBridgeChatMessageListSignals.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGBridgeClient.h"

@implementation TGBridgeChatMessageListSignals

+ (SSignal *)chatMessageListViewWithPeerId:(int64_t)peerId atMessageId:(int32_t)messageId rangeMessageCount:(NSUInteger)rangeMessageCount
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeChatMessageListSubscription alloc] initWithPeerId:peerId atMessageId:messageId rangeMessageCount:rangeMessageCount]];
}

+ (SSignal *)chatMessageWithPeerId:(int64_t)peerId messageId:(int32_t)messageId
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeChatMessageSubscription alloc] initWithPeerId:peerId messageId:messageId]];
}

+ (SSignal *)readChatMessageListWithPeerId:(int64_t)peerId messageId:(int32_t)messageId
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeReadChatMessageListSubscription alloc] initWithPeerId:peerId messageId:messageId]];
}

@end
