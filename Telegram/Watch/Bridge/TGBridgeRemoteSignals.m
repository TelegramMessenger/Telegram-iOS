#import "TGBridgeRemoteSignals.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGBridgeClient.h"

@implementation TGBridgeRemoteSignals

+ (SSignal *)openRemoteMessageWithPeerId:(int64_t)peerId messageId:(int32_t)messageId type:(int32_t)type autoPlay:(bool)autoPlay
{
    autoPlay = false;
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeRemoteSubscription alloc] initWithPeerId:peerId messageId:messageId type:type autoPlay:autoPlay]];
}

@end
