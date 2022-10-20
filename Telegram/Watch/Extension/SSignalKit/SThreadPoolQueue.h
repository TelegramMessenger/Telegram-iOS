#import <Foundation/Foundation.h>

@class SThreadPool;
@class SThreadPoolTask;

@interface SThreadPoolQueue : NSObject

- (instancetype)initWithThreadPool:(SThreadPool *)threadPool;
- (void)addTask:(SThreadPoolTask *)task;
- (SThreadPoolTask *)_popFirstTask;
- (bool)_hasTasks;

@end
