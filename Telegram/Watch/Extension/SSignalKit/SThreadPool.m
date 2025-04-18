#import "SThreadPool.h"

#import <libkern/OSAtomic.h>
#import <pthread.h>
#import "SQueue.h"

@interface SThreadPool ()
{
    SQueue *_managementQueue;
    NSMutableArray *_threads;
    
    NSMutableArray *_queues;
    NSMutableArray *_takenQueues;
    
    pthread_mutex_t _mutex;
    pthread_cond_t _cond;
}

@end

@implementation SThreadPool

+ (void)threadEntryPoint:(SThreadPool *)threadPool
{
    SThreadPoolQueue *queue = nil;
    
    while (true)
    {
        SThreadPoolTask *task = nil;
        
        pthread_mutex_lock(&threadPool->_mutex);
        
        if (queue != nil)
        {
            [threadPool->_takenQueues removeObject:queue];
            if ([queue _hasTasks])
                [threadPool->_queues addObject:queue];
        }
        
        while (true)
        {
            while (threadPool->_queues.count == 0)
                pthread_cond_wait(&threadPool->_cond, &threadPool->_mutex);

            queue = threadPool->_queues.firstObject;
            task = [queue _popFirstTask];
            
            if (queue != nil)
            {
                [threadPool->_takenQueues addObject:queue];
                [threadPool->_queues removeObjectAtIndex:0];
            
                break;
            }
        }
        pthread_mutex_unlock(&threadPool->_mutex);
        
        @autoreleasepool
        {
            [task execute];
        }
    }
}

- (instancetype)init
{
    return [self initWithThreadCount:2 threadPriority:0.5];
}

- (instancetype)initWithThreadCount:(NSUInteger)threadCount threadPriority:(double)threadPriority
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_mutex, 0);
        pthread_cond_init(&_cond, 0);
        
        _managementQueue = [[SQueue alloc] init];
        
        [_managementQueue dispatch:^
        {
            _threads = [[NSMutableArray alloc] init];
            _queues = [[NSMutableArray alloc] init];
            _takenQueues = [[NSMutableArray alloc] init];
            for (NSUInteger i = 0; i < threadCount; i++)
            {
                NSThread *thread = [[NSThread alloc] initWithTarget:[SThreadPool class] selector:@selector(threadEntryPoint:) object:self];
                thread.name = [[NSString alloc] initWithFormat:@"SThreadPool-%p-%d", self, (int)i];
                [thread setThreadPriority:threadPriority];
                [_threads addObject:thread];
                [thread start];
            }
        }];
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_mutex);
    pthread_cond_destroy(&_cond);
}

- (void)addTask:(SThreadPoolTask *)task
{
    SThreadPoolQueue *tempQueue = [self nextQueue];
    [tempQueue addTask:task];
}

- (SThreadPoolQueue *)nextQueue
{
    return [[SThreadPoolQueue alloc] initWithThreadPool:self];
}

- (void)_workOnQueue:(SThreadPoolQueue *)queue block:(void (^)())block
{
    [_managementQueue dispatch:^
    {
        pthread_mutex_lock(&_mutex);
        block();
        if (![_queues containsObject:queue] && ![_takenQueues containsObject:queue])
            [_queues addObject:queue];
        pthread_cond_broadcast(&_cond);
        pthread_mutex_unlock(&_mutex);
    }];
}

@end
