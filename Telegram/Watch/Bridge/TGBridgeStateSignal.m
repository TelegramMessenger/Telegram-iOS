#import "TGBridgeStateSignal.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGBridgeClient.h"

@implementation TGBridgeStateSignal

+ (SSignal *)synchronizationState
{
    return [[[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeStateSubscription alloc] init]] map:^NSNumber *(id next)
    {
        if ([next isKindOfClass:[NSNumber class]])
            return next;
        
        return @(TGBridgeSynchronizationStateSynchronized);
    }];
}

@end
