#import <Foundation/Foundation.h>

@interface SThreadPoolTask : NSObject

- (void)addDependency:(SThreadPoolTask *)task;

@end

@interface SThreadPool : NSObject

- (instancetype)initWithThreadCount:(NSUInteger)threadCount threadPriority:(double)threadPriority;

- (id)addTask:(void (^)(bool (^)()))task;
- (SThreadPoolTask *)prepareTask:(void (^)(bool (^)()))task;
- (id)startTask:(SThreadPoolTask *)task;
- (void)cancelTask:(id)taskId;

@end
