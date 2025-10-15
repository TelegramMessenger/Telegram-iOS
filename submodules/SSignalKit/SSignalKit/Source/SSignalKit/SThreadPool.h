#import <Foundation/Foundation.h>

#import <SSignalKit/SThreadPoolTask.h>
#import <SSignalKit/SThreadPoolQueue.h>

@interface SThreadPool : NSObject

- (instancetype _Nonnull)initWithThreadCount:(NSUInteger)threadCount threadPriority:(double)threadPriority;

- (void)addTask:(SThreadPoolTask * _Nonnull)task;

- (SThreadPoolQueue * _Nonnull)nextQueue;
- (void)_workOnQueue:(SThreadPoolQueue * _Nonnull)queue block:(void (^ _Nonnull)())block;

@end
