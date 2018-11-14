#import "TGBridgeConversationSignals.h"
#import "TGBridgeSubscriptions.h"
#import "TGBridgeChat.h"
#import "TGBridgeUser.h"
#import "TGBridgeClient.h"

@implementation TGBridgeConversationSignals

+ (SSignal *)conversationWithPeerId:(int64_t)peerId
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeConversationSubscription alloc] initWithPeerId:peerId]];
}

@end
