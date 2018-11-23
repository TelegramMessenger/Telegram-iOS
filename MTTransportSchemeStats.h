#import <Foundation/Foundation.h>

@interface MTTransportSchemeStats : NSObject<NSCoding>

@property (nonatomic, readonly) int32_t lastFailureTimestamp;
@property (nonatomic, readonly) int32_t lastResponseTimestamp;

- (instancetype)initWithLastFailureTimestamp:(int32_t)lastFailureTimestamp lastResponseTimestamp:(int32_t)lastResponseTimestamp;

- (instancetype)withUpdatedLastFailureTimestamp:(int32_t)lastFailureTimestamp;
- (instancetype)withUpdatedLastResponseTimestamp:(int32_t)lastResponseTimestamp;

@end
