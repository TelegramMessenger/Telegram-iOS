#import <Foundation/Foundation.h>

@class MTSignal;
@class MTNetworkUsageCalculationInfo;

typedef enum {
    MTNetworkUsageManagerInterfaceWWAN,
    MTNetworkUsageManagerInterfaceOther
} MTNetworkUsageManagerInterface;

typedef struct {
    NSUInteger incomingBytes;
    NSUInteger outgoingBytes;
} MTNetworkUsageManagerInterfaceStats;

@interface MTNetworkUsageManagerStats : NSObject

@property (nonatomic, readonly) MTNetworkUsageManagerInterfaceStats wwan;
@property (nonatomic, readonly) MTNetworkUsageManagerInterfaceStats other;

@end

@interface MTNetworkUsageManager : NSObject

- (instancetype)initWithInfo:(MTNetworkUsageCalculationInfo *)info;

- (void)addIncomingBytes:(NSUInteger)incomingBytes interface:(MTNetworkUsageManagerInterface)interface;
- (void)addOutgoingBytes:(NSUInteger)outgoingBytes interface:(MTNetworkUsageManagerInterface)interface;

- (void)resetIncomingBytes:(MTNetworkUsageManagerInterface)interface;
- (void)resetOutgoingBytes:(MTNetworkUsageManagerInterface)interface;

- (MTSignal *)currentStats;

@end
