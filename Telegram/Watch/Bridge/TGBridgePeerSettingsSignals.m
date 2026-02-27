#import "TGBridgePeerSettingsSignals.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGBridgeClient.h"

@implementation TGBridgePeerSettingsSignals

+ (SSignal *)peerSettingsWithPeerId:(int64_t)peerId;
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgePeerSettingsSubscription alloc] initWithPeerId:peerId]];
}

+ (SSignal *)toggleMutedWithPeerId:(int64_t)peerId
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgePeerUpdateNotificationSettingsSubscription alloc] initWithPeerId:peerId]];
}

+ (SSignal *)updateBlockStatusWithPeerId:(int64_t)peerId blocked:(bool)blocked
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgePeerUpdateBlockStatusSubscription alloc] initWithPeerId:peerId blocked:blocked]];
}

@end
