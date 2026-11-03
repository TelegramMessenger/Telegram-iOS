#import "SSignal+Dispatch.h"
#import "SAtomic.h"
#import "STimer.h"
#import "SBlockDisposable.h"
#import "SMetaDisposable.h"

@interface SSignal_ThrottleContainer : NSObject

@property (nonatomic, strong, readonly) id value;
@property (nonatomic, readonly) bool committed;
@property (nonatomic, readonly) bool last;

@end

@implementation SSignal_ThrottleContainer

- (instancetype)initWithValue:(id)value committed:(bool)committed last:(bool)last {
    self = [super init];
    if (self != nil) {
        _value = value;
        _committed = committed;
        _last = last;
    }
    return self;
}

@end

@implementation SSignal (Dispatch)

- (SSignal *)deliverOn:(SQueue *)queue
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        return [self startWithNext:^(id next)
        {
            [queue dispatch:^
            {
                [subscriber putNext:next];
            }];
        } error:^(id error)
        {
            [queue dispatch:^
            {
                [subscriber putError:error];
            }];
        } completed:^
        {
            [queue dispatch:^
            {
                [subscriber putCompletion];
            }];
        }];
    }];
}

- (SSignal *)deliverOnThreadPool:(SThreadPool *)threadPool
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SThreadPoolQueue *queue = [threadPool nextQueue];
        return [self startWithNext:^(id next)
        {
            SThreadPoolTask *task = [[SThreadPoolTask alloc] initWithBlock:^(bool (^cancelled)())
            {
                if (!cancelled())
                    [subscriber putNext:next];
            }];
            [queue addTask:task];
        } error:^(id error)
        {
            SThreadPoolTask *task = [[SThreadPoolTask alloc] initWithBlock:^(bool (^cancelled)())
            {
                if (!cancelled())
                    [subscriber putError:error];
            }];
            [queue addTask:task];
        } completed:^
        {
            SThreadPoolTask *task = [[SThreadPoolTask alloc] initWithBlock:^(bool (^cancelled)())
            {
                if (!cancelled())
                    [subscriber putCompletion];
            }];
            [queue addTask:task];
        }];
    }];
}

- (SSignal *)startOn:(SQueue *)queue
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        __block bool isCancelled = false;
        SMetaDisposable *disposable = [[SMetaDisposable alloc] init];
        [disposable setDisposable:[[SBlockDisposable alloc] initWithBlock:^
        {
            isCancelled = true;
        }]];
        
        [queue dispatch:^
        {
            if (!isCancelled)
            {
                [disposable setDisposable:[self startWithNext:^(id next)
                {
                    [subscriber putNext:next];
                } error:^(id error)
                {
                    [subscriber putError:error];
                } completed:^
                {
                    [subscriber putCompletion];
                }]];
            }
        }];
        
        return disposable;
    }];
}

- (SSignal *)startOnThreadPool:(SThreadPool *)threadPool
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SMetaDisposable *disposable = [[SMetaDisposable alloc] init];
        
        SThreadPoolTask *task = [[SThreadPoolTask alloc] initWithBlock:^(bool (^cancelled)())
        {
            if (cancelled && cancelled())
                return;
            
            [disposable setDisposable:[self startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                [subscriber putCompletion];
            }]];
        }];
        
        [disposable setDisposable:[[SBlockDisposable alloc] initWithBlock:^
        {
            [task cancel];
        }]];
        
        [threadPool addTask:task];
        
        return disposable;
    }];
}

- (SSignal *)throttleOn:(SQueue *)queue delay:(NSTimeInterval)delay
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        SAtomic *value = [[SAtomic alloc] initWithValue:nil];
        STimer *timer = [[STimer alloc] initWithTimeout:delay repeat:false completion:^{
            [value modify:^id(SSignal_ThrottleContainer *container) {
                if (container != nil) {
                    if (!container.committed) {
                        [subscriber putNext:container.value];
                        container = [[SSignal_ThrottleContainer alloc] initWithValue:container.value committed:true last:container.last];
                    }
                    
                    if (container.last) {
                        [subscriber putCompletion];
                    }
                }
                return container;
            }];
        } queue:queue];
        
        return [[self deliverOn:queue] startWithNext:^(id next) {
            [value modify:^id(SSignal_ThrottleContainer *container) {
                if (container == nil) {
                    container = [[SSignal_ThrottleContainer alloc] initWithValue:next committed:false last:false];
                }
                return container;
            }];
            [timer invalidate];
            [timer start];
        } error:^(id error) {
            [timer invalidate];
            [subscriber putError:error];
        } completed:^{
            [timer invalidate];
            __block bool start = false;
            [value modify:^id(SSignal_ThrottleContainer *container) {
                bool wasCommitted = false;
                if (container == nil) {
                    wasCommitted = true;
                    container = [[SSignal_ThrottleContainer alloc] initWithValue:nil committed:true last:true];
                } else {
                    wasCommitted = container.committed;
                    container = [[SSignal_ThrottleContainer alloc] initWithValue:container.value committed:container.committed last:true];
                }
                start = wasCommitted;
                return container;
            }];
            if (start) {
                [timer start];
            } else {
                [timer fireAndInvalidate];
            }
        }];
    }];
}

@end
