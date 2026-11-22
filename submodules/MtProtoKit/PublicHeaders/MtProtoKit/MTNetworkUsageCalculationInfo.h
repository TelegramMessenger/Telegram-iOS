#import <Foundation/Foundation.h>

@class MTQueue;

@interface MTNetworkUsageCalculationInfo : NSObject

@property (nonatomic, strong, readonly) NSString *filePath;
@property (nonatomic, readonly) int32_t incomingWWANKey;
@property (nonatomic, readonly) int32_t outgoingWWANKey;
@property (nonatomic, readonly) int32_t incomingOtherKey;
@property (nonatomic, readonly) int32_t outgoingOtherKey;

- (instancetype)initWithFilePath:(NSString *)filePath incomingWWANKey:(int32_t)incomingWWANKey outgoingWWANKey:(int32_t)outgoingWWANKey incomingOtherKey:(int32_t)incomingOtherKey outgoingOtherKey:(int32_t)outgoingOtherKey;

@end
