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

@protocol MTNetworkUsageManagerProtocol <NSObject>

- (void)addIncomingBytes:(NSUInteger)incomingBytes interface:(MTNetworkUsageManagerInterface)interface;
- (void)addOutgoingBytes:(NSUInteger)outgoingBytes interface:(MTNetworkUsageManagerInterface)interface;

@end

@interface MTNetworkUsageManager : NSObject <MTNetworkUsageManagerProtocol>

- (instancetype)initWithInfo:(MTNetworkUsageCalculationInfo *)info;

- (void)addIncomingBytes:(NSUInteger)incomingBytes interface:(MTNetworkUsageManagerInterface)interface;
- (void)addOutgoingBytes:(NSUInteger)outgoingBytes interface:(MTNetworkUsageManagerInterface)interface;

- (void)resetKeys:(NSArray<NSNumber *> *)keys setKeys:(NSDictionary<NSNumber *, NSNumber *> *)setKeys completion:(void (^)())completion;
- (MTSignal *)currentStatsForKeys:(NSArray<NSNumber *> *)keys;

@end
