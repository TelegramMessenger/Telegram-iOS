#import "TGBridgeChatListSignals.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGBridgeClient.h"

@implementation TGBridgeChatListSignals

+ (SSignal *)chatListWithLimit:(NSUInteger)limit;
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeChatListSubscription alloc] initWithLimit:limit]];
}

@end
