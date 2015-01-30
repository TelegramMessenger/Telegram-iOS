#import "SThreadPool.h"

#import <libkern/OSAtomic.h>
#import <pthread.h>
#import "SQueue.h"

@class SThreadPoolOperation;

@interface SThreadPoolTask ()

@property (nonatomic, strong, readonly) SThreadPoolOperation *operation;

- (instancetype)initWithOperation:(SThreadPoolOperation *)operation;

@end

@interface SThreadPoolOperationCanelledHolder : NSObject
{
    @public
    volatile bool _cancelled;
}

@property (nonatomic, weak) SThreadPoolOperation *operation;

@end

@implementation SThreadPoolOperationCanelledHolder

@end

@interface SThreadPoolOperation : NSOperation
{
    void (^_block)(bool (^)());
}

@property (nonatomic, strong, readonly) SThreadPoolOperationCanelledHolder *cancelledHolder;

@end

@implementation SThreadPoolOperation

- (instancetype)initWithBlock:(void (^)(bool (^)()))block
{
    self = [super init];
    if (self != nil)
    {
        _block = [block copy];
        _cancelledHolder = [[SThreadPoolOperationCanelledHolder alloc] init];
        _cancelledHolder.operation = self;
    }
    return self;
}

- (void)main
{
    if (!_cancelledHolder->_cancelled)
    {
        SThreadPoolOperationCanelledHolder *cancelledHolder = _cancelledHolder;
        _block(^bool
        {
            return cancelledHolder->_cancelled;
        });
    }
}

- (void)cancel
{
    _cancelledHolder->_cancelled = true;
}

- (BOOL)isCancelled
{
    return _cancelledHolder->_cancelled;
}

@end

@interface SThreadPool ()
{
    SQueue *_managementQueue;
    NSMutableArray *_threads;
    NSMutableArray *_operations;
    
    pthread_mutex_t _mutex;
    pthread_cond_t _cond;
}

@end

@implementation SThreadPool

+ (void)threadEntryPoint:(SThreadPool *)threadPool
{
    while (true)
    {
        SThreadPoolOperation *operation = nil;
        
        pthread_mutex_lock(&threadPool->_mutex);
        while (true)
        {
            while (threadPool->_operations.count == 0)
                pthread_cond_wait(&threadPool->_cond, &threadPool->_mutex);
            for (NSUInteger index = 0; index < threadPool->_operations.count; index++)
            {
                SThreadPoolOperation *maybeOperation = threadPool->_operations[index];
                if ([maybeOperation isCancelled])
                {
                    [threadPool->_operations removeObjectAtIndex:index];
                    index--;
                }
                else if ([maybeOperation isReady])
                {
                    operation = maybeOperation;
                    [threadPool->_operations removeObjectAtIndex:index];
                    break;
                }
            }
            
            if (operation != nil)
                break;
        }
        pthread_mutex_unlock(&threadPool->_mutex);
        
        @autoreleasepool
        {
            [operation main];
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
            _operations = [[NSMutableArray alloc] init];
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

- (void)_addOperation:(SThreadPoolOperation *)operation
{
    pthread_mutex_lock(&_mutex);
    [_operations addObject:operation];
    pthread_cond_signal(&_cond);
    pthread_mutex_unlock(&_mutex);
}

- (id)addTask:(void (^)(bool (^)()))task
{
    SThreadPoolOperation *operation = [[SThreadPoolOperation alloc] initWithBlock:task];
    [_managementQueue dispatch:^
    {
        [self _addOperation:operation];
    }];
    return operation.cancelledHolder;
}

- (SThreadPoolTask *)prepareTask:(void (^)(bool (^)()))task
{
    SThreadPoolOperation *operation = [[SThreadPoolOperation alloc] initWithBlock:task];
    return [[SThreadPoolTask alloc] initWithOperation:operation];
}

- (id)startTask:(SThreadPoolTask *)task
{
    [_managementQueue dispatch:^
    {
        [self _addOperation:task.operation];
    }];
    return task.operation.cancelledHolder;
}

- (void)cancelTask:(id)taskId
{
    if (taskId != nil)
        ((SThreadPoolOperationCanelledHolder *)taskId)->_cancelled = true;
}

@end

@implementation SThreadPoolTask

- (instancetype)initWithOperation:(SThreadPoolOperation *)operation
{
    self = [super init];
    if (self != nil)
    {
        _operation = operation;
    }
    return self;
}

- (void)addDependency:(SThreadPoolTask *)task
{
    [_operation addDependency:task->_operation];
}

@end
