#import <SSignalKit/SSignalKit.h>

typedef enum
{
    TGBridgeSynchronizationStateSynchronized,
    TGBridgeSynchronizationStateWaitingForNetwork,
    TGBridgeSynchronizationStateConnecting,
    TGBridgeSynchronizationStateUpdating
} TGBridgeSynchronizationStateValue;

@interface TGBridgeStateSignal : NSObject

+ (SSignal *)synchronizationState;

@end
