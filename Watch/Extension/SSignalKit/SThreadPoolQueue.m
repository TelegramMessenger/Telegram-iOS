#import "SThreadPoolQueue.h"

#import "SThreadPool.h"

@interface SThreadPoolQueue ()
{
    __weak SThreadPool *_threadPool;
    NSMutableArray *_tasks;
}

@end

@implementation SThreadPoolQueue

- (instancetype)initWithThreadPool:(SThreadPool *)threadPool
{
    self = [super init];
    if (self != nil)
    {
        _threadPool = threadPool;
        _tasks = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)addTask:(SThreadPoolTask *)task
{
    SThreadPool *threadPool = _threadPool;
    [threadPool _workOnQueue:self block:^
    {
        [_tasks addObject:task];
    }];
}

- (SThreadPoolTask *)_popFirstTask
{
    if (_tasks.count != 0)
    {
        SThreadPoolTask *task = _tasks[0];
        [_tasks removeObjectAtIndex:0];
        return task;
    }
    return nil;
}

- (bool)_hasTasks
{
    return _tasks.count != 0;
}

@end
