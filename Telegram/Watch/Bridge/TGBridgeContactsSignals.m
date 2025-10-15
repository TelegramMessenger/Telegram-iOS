#import "TGBridgeContactsSignals.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGBridgeClient.h"

@implementation TGBridgeContactsSignals

+ (SSignal *)searchContactsWithQuery:(NSString *)query
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeContactsSubscription alloc] initWithQuery:query]];
}

@end
