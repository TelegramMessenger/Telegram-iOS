#import <Foundation/Foundation.h>

@interface MTPingMessage : NSObject

@property (nonatomic, readonly) int64_t pingId;

- (instancetype)initWithPingId:(int64_t)pingId;

@end
