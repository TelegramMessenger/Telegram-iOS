#import <Foundation/Foundation.h>

#import <SSignalKit/SThreadPoolTask.h>
#import <SSignalKit/SThreadPoolQueue.h>

@interface SThreadPool : NSObject

- (instancetype)initWithThreadCount:(NSUInteger)threadCount threadPriority:(double)threadPriority;

- (void)addTask:(SThreadPoolTask *)task;

- (SThreadPoolQueue *)nextQueue;
- (void)_workOnQueue:(SThreadPoolQueue *)queue block:(void (^)())block;

@end
