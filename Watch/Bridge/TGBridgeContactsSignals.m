#import "TGBridgeContactsSignals.h"
#import "TGBridgeSubscriptions.h"
#import "TGBridgeUser.h"
#import "TGBridgeClient.h"

@implementation TGBridgeContactsSignals

+ (SSignal *)searchContactsWithQuery:(NSString *)query
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeContactsSubscription alloc] initWithQuery:query]];
}

@end
