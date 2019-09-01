#import <Foundation/Foundation.h>

@interface SThreadPoolTask : NSObject

- (instancetype)initWithBlock:(void (^)(bool (^)()))block;
- (void)execute;
- (void)cancel;

@end
