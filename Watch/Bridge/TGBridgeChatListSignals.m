#import "TGBridgeChatListSignals.h"
#import "TGBridgeSubscriptions.h"
#import "TGBridgeChat.h"
#import "TGBridgeUser.h"
#import "TGBridgeClient.h"

@implementation TGBridgeChatListSignals

+ (SSignal *)chatListWithLimit:(NSUInteger)limit;
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeChatListSubscription alloc] initWithLimit:limit]];
}

@end
