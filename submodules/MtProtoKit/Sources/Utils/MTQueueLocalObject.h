#import <Foundation/Foundation.h>

@class MTQueue;

NS_ASSUME_NONNULL_BEGIN

@interface MTQueueLocalObject<__covariant T> : NSObject

- (instancetype)initWithQueue:(MTQueue *)queue generator:(T(^)())generator;
- (void)with:(void (^)(T))f;

@end

NS_ASSUME_NONNULL_END
