#import <MtProtoKit/MTSignal.h>

#import <pthread/pthread.h>
#import <MtProtoKit/MTTimer.h>
#import <MtProtoKit/MTQueue.h>
#import <MtProtoKit/MTAtomic.h>
#import <MtProtoKit/MTBag.h>

#import <os/lock.h>

@interface MTSubscriberDisposable : NSObject <MTDisposable>
{
    __weak MTSubscriber *_subscriber;
    id<MTDisposable> _disposable;
    pthread_mutex_t _lock;
}

@end

@implementation MTSubscriberDisposable

- (instancetype)initWithSubscriber:(MTSubscriber *)subscriber disposable:(id<MTDisposable>)disposable {
    self = [super init];
    if (self != nil) {
        _subscriber = subscriber;
        _disposable = disposable;
        pthread_mutex_init(&_lock, nil);
    }
    return self;
}

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
}

- (void)dispose {
    MTSubscriber *subscriber = nil;
    id<MTDisposable> disposeItem = nil;
    pthread_mutex_lock(&_lock);
    disposeItem = _disposable;
    _disposable = nil;
    subscriber = _subscriber;
    _subscriber = nil;
    pthread_mutex_unlock(&_lock);
    
    [disposeItem dispose];
    [subscriber _markTerminatedWithoutDisposal];
}

@end

@interface MTStrictDisposable : NSObject<MTDisposable> {
    id<MTDisposable> _disposable;
    const char *_file;
    int _line;
    
#if DEBUG
    pthread_mutex_t _lock;
    bool _isDisposed;
#endif
}

- (instancetype)initWithDisposable:(id<MTDisposable>)disposable file:(const char *)file line:(int)line;
- (void)dispose;

@end

@implementation MTStrictDisposable

- (instancetype)initWithDisposable:(id<MTDisposable>)disposable file:(const char *)file line:(int)line {
    self = [super init];
    if (self != nil) {
        _disposable = disposable;
        _file = file;
        _line = line;
        
#if DEBUG
        pthread_mutex_init(&_lock, nil);
#endif
    }
    return self;
}

- (void)dealloc {
#if DEBUG
    pthread_mutex_lock(&_lock);
    if (!_isDisposed) {
        NSLog(@"Leaked disposable from %s:%d", _file, _line);
        assert(false);
    }
    pthread_mutex_unlock(&_lock);
    
    pthread_mutex_destroy(&_lock);
#endif
}

- (void)dispose {
#if DEBUG
    pthread_mutex_lock(&_lock);
    _isDisposed = true;
    pthread_mutex_unlock(&_lock);
#endif
    
    [_disposable dispose];
}

@end

@interface MTSignal_ValueContainer : NSObject

@property (nonatomic, strong, readonly) id value;

@end

@implementation MTSignal_ValueContainer

- (instancetype)initWithValue:(id)value {
    self = [super init];
    if (self != nil) {
        _value = value;
    }
    return self;
}

@end

@interface MTSignalQueueState : NSObject <MTDisposable>
{
    os_unfair_lock _lock;
    bool _executingSignal;
    bool _terminated;
    
    id<MTDisposable> _disposable;
    MTMetaDisposable *_currentDisposable;
    MTSubscriber *_subscriber;
    
    NSMutableArray *_queuedSignals;
    bool _queueMode;
}

@end

@implementation MTSignalQueueState

- (instancetype)initWithSubscriber:(MTSubscriber *)subscriber queueMode:(bool)queueMode
{
    self = [super init];
    if (self != nil)
    {
        _subscriber = subscriber;
        _currentDisposable = [[MTMetaDisposable alloc] init];
        _queuedSignals = queueMode ? [[NSMutableArray alloc] init] : nil;
        _queueMode = queueMode;
    }
    return self;
}

- (void)beginWithDisposable:(id<MTDisposable>)disposable
{
    _disposable = disposable;
}

- (void)enqueueSignal:(MTSignal *)signal
{
    bool startSignal = false;
    os_unfair_lock_lock(&_lock);
    if (_queueMode && _executingSignal) {
        [_queuedSignals addObject:signal];
    }
    else
    {
        _executingSignal = true;
        startSignal = true;
    }
    os_unfair_lock_unlock(&_lock);
    
    if (startSignal)
    {
        __weak MTSignalQueueState *weakSelf = self;
        id<MTDisposable> disposable = [signal startWithNext:^(id next)
        {
            __strong MTSignalQueueState *strongSelf = weakSelf;
            if (strongSelf) {
                #if DEBUG
                assert(strongSelf->_subscriber != nil);
                #endif
                [strongSelf->_subscriber putNext:next];
            }
        } error:^(id error)
        {
            __strong MTSignalQueueState *strongSelf = weakSelf;
            if (strongSelf) {
                #if DEBUG
                assert(strongSelf->_subscriber != nil);
                #endif
                [strongSelf->_subscriber putError:error];
            }
        } completed:^
        {
            __strong MTSignalQueueState *strongSelf = weakSelf;
            if (strongSelf != nil) {
                [strongSelf headCompleted];
            }
        }];
        
        [_currentDisposable setDisposable:disposable];
    }
}

- (void)headCompleted
{
    MTSignal *nextSignal = nil;
    
    bool terminated = false;
    os_unfair_lock_lock(&_lock);
    _executingSignal = false;
    
    if (_queueMode)
    {
        if (_queuedSignals.count != 0)
        {
            nextSignal = _queuedSignals[0];
            [_queuedSignals removeObjectAtIndex:0];
            _executingSignal = true;
        }
        else
            terminated = _terminated;
    }
    else
        terminated = _terminated;
    os_unfair_lock_unlock(&_lock);
    
    if (terminated)
        [_subscriber putCompletion];
    else if (nextSignal != nil)
    {
        __weak MTSignalQueueState *weakSelf = self;
        id<MTDisposable> disposable = [nextSignal startWithNext:^(id next)
        {
            __strong MTSignalQueueState *strongSelf = weakSelf;
            if (strongSelf) {
                #if DEBUG
                assert(strongSelf->_subscriber != nil);
                #endif
                [strongSelf->_subscriber putNext:next];
            }
        } error:^(id error)
        {
            __strong MTSignalQueueState *strongSelf = weakSelf;
            if (strongSelf) {
                #if DEBUG
                assert(strongSelf->_subscriber != nil);
                #endif
                [strongSelf->_subscriber putError:error];
            }
        } completed:^
        {
            __strong MTSignalQueueState *strongSelf = weakSelf;
            if (strongSelf != nil) {
                [strongSelf headCompleted];
            }
        }];
        
        [_currentDisposable setDisposable:disposable];
    }
}

- (void)beginCompletion
{
    bool executingSignal = false;
    os_unfair_lock_lock(&_lock);
    executingSignal = _executingSignal;
    _terminated = true;
    os_unfair_lock_unlock(&_lock);
    
    if (!executingSignal) {
        [_subscriber putCompletion];
    }
}

- (void)dispose
{
    [_currentDisposable dispose];
    [_disposable dispose];
}

@end

@interface MTSignalCombineState : NSObject

@property (nonatomic, strong, readonly) NSDictionary *latestValues;
@property (nonatomic, strong, readonly) NSArray *completedStatuses;
@property (nonatomic) bool error;

@end

@implementation MTSignalCombineState

- (instancetype)initWithLatestValues:(NSDictionary *)latestValues completedStatuses:(NSArray *)completedStatuses error:(bool)error
{
    self = [super init];
    if (self != nil)
    {
        _latestValues = latestValues;
        _completedStatuses = completedStatuses;
        _error = error;
    }
    return self;
}

@end

@implementation MTSignal

- (instancetype)initWithGenerator:(id<MTDisposable> (^)(MTSubscriber *))generator
{
    self = [super init];
    if (self != nil)
    {
        _generator = [generator copy];
    }
    return self;
}

- (id<MTDisposable>)startWithNext:(void (^)(id next))next error:(void (^)(id error))error completed:(void (^)())completed
{
    MTSubscriber *subscriber = [[MTSubscriber alloc] initWithNext:next error:error completed:completed];
    id<MTDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[MTSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable];
}

- (id<MTDisposable>)startWithNextStrict:(void (^)(id next))next error:(void (^)(id error))error completed:(void (^)())completed file:(const char *)file line:(int)line
{
    MTSubscriber *subscriber = [[MTSubscriber alloc] initWithNext:next error:error completed:completed];
    id<MTDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[MTStrictDisposable alloc] initWithDisposable:[[MTSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable] file:file line:line];
}

- (id<MTDisposable>)startWithNext:(void (^)(id next))next
{
    MTSubscriber *subscriber = [[MTSubscriber alloc] initWithNext:next error:nil completed:nil];
    id<MTDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[MTSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable];
}

- (id<MTDisposable>)startWithNextStrict:(void (^)(id next))next file:(const char *)file line:(int)line
{
    MTSubscriber *subscriber = [[MTSubscriber alloc] initWithNext:next error:nil completed:nil];
    id<MTDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[MTStrictDisposable alloc] initWithDisposable:[[MTSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable] file:file line:line];
}

- (id<MTDisposable>)startWithNext:(void (^)(id next))next completed:(void (^)())completed
{
    MTSubscriber *subscriber = [[MTSubscriber alloc] initWithNext:next error:nil completed:completed];
    id<MTDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[MTSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable];
}

- (id<MTDisposable>)startWithNextStrict:(void (^)(id next))next completed:(void (^)())completed file:(const char *)file line:(int)line
{
    MTSubscriber *subscriber = [[MTSubscriber alloc] initWithNext:next error:nil completed:completed];
    id<MTDisposable> disposable = _generator(subscriber);
    [subscriber _assignDisposable:disposable];
    return [[MTStrictDisposable alloc] initWithDisposable:[[MTSubscriberDisposable alloc] initWithSubscriber:subscriber disposable:disposable] file:file line:line];
}

+ (MTSignal *)single:(id)next
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        [subscriber putNext:next];
        [subscriber putCompletion];
        return nil;
    }];
}

+ (MTSignal *)fail:(id)error
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        [subscriber putError:error];
        return nil;
    }];
}

+ (MTSignal *)never
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (__unused MTSubscriber *subscriber)
    {
        return nil;
    }];
}

+ (MTSignal *)complete
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        [subscriber putCompletion];
        return nil;
    }];
}

- (MTSignal *)then:(MTSignal *)signal
{
    return [[MTSignal alloc] initWithGenerator:^(MTSubscriber *subscriber)
    {
        MTDisposableSet *compositeDisposable = [[MTDisposableSet alloc] init];
        
        MTMetaDisposable *currentDisposable = [[MTMetaDisposable alloc] init];
        [compositeDisposable add:currentDisposable];
        
        [currentDisposable setDisposable:[self startWithNext:^(id next)
        {
            [subscriber putNext:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [compositeDisposable add:[signal startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                [subscriber putCompletion];
            }]];
        }]];
        
        return compositeDisposable;
    }];
}

- (MTSignal *)delay:(NSTimeInterval)seconds onQueue:(MTQueue *)queue
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        MTMetaDisposable *startDisposable = [[MTMetaDisposable alloc] init];
        MTMetaDisposable *timerDisposable = [[MTMetaDisposable alloc] init];
        
        MTTimer *timer = [[MTTimer alloc] initWithTimeout:seconds repeat:false completion:^() {
            [startDisposable setDisposable:[self startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                [subscriber putCompletion];
            }]];
        } queue:queue.nativeQueue];
        
        [timer start];
        
        [timerDisposable setDisposable:[[MTBlockDisposable alloc] initWithBlock:^
        {
            [timer invalidate];
        }]];
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
            [startDisposable dispose];
            [timerDisposable dispose];
        }];
    }];
}

- (MTSignal *)timeout:(NSTimeInterval)seconds onQueue:(MTQueue *)queue orSignal:(MTSignal *)signal
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        MTMetaDisposable *startDisposable = [[MTMetaDisposable alloc] init];
        MTMetaDisposable *timerDisposable = [[MTMetaDisposable alloc] init];

        MTTimer *timer = [[MTTimer alloc] initWithTimeout:seconds repeat:false completion:^{
            [startDisposable setDisposable:[signal startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                [subscriber putCompletion];
            }]];
        } queue:queue.nativeQueue];
        [timer start];
        
        [timerDisposable setDisposable:[self startWithNext:^(id next)
        {
            [timer invalidate];
            [subscriber putNext:next];
        } error:^(id error)
        {
            [timer invalidate];
            [subscriber putError:error];
        } completed:^
        {
            [timer invalidate];
            [subscriber putCompletion];
        }]];
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
            [startDisposable dispose];
            [timerDisposable dispose];
        }];
    }];
}

- (MTSignal *)catch:(MTSignal *(^)(id error))f
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        MTMetaDisposable *mainDisposable = [[MTMetaDisposable alloc] init];
        MTMetaDisposable *alternativeDisposable = [[MTMetaDisposable alloc] init];
        
        [mainDisposable setDisposable:[self startWithNext:^(id next)
        {
            [subscriber putNext:next];
        } error:^(id error)
        {
            MTSignal *signal = f(error);
            [alternativeDisposable setDisposable:[signal startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                [subscriber putCompletion];
            }]];
        } completed:^
        {
            [subscriber putCompletion];
        }]];
        
        return [[MTBlockDisposable alloc] initWithBlock:^{
            [mainDisposable dispose];
            [alternativeDisposable dispose];
        }];
    }];
}

+ (MTSignal *)combineSignals:(NSArray *)signals
{
    if (signals.count == 0)
        return [MTSignal single:@[]];
    else
        return [self combineSignals:signals withInitialStates:nil];
}

+ (MTSignal *)combineSignals:(NSArray *)signals withInitialStates:(NSArray *)initialStates
{
    return [[MTSignal alloc] initWithGenerator:^(MTSubscriber *subscriber)
    {
        NSMutableArray *completedStatuses = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < signals.count; i++) {
            [completedStatuses addObject:@false];
        }
        NSMutableDictionary *initialLatestValues = [[NSMutableDictionary alloc] init];
        for (NSUInteger i = 0; i < initialStates.count; i++) {
            initialLatestValues[@(i)] = initialStates[i];
        }
        MTAtomic *combineState = [[MTAtomic alloc] initWithValue:[[MTSignalCombineState alloc] initWithLatestValues:initialLatestValues completedStatuses:completedStatuses error:false]];
        
        MTDisposableSet *compositeDisposable = [[MTDisposableSet alloc] init];
        
        NSUInteger index = 0;
        NSUInteger count = signals.count;
        for (MTSignal *signal in signals) {
            id<MTDisposable> disposable = [signal startWithNext:^(id next)
            {
                MTSignalCombineState *currentState = [combineState modify:^id(MTSignalCombineState *state)
                {
                    NSMutableDictionary *latestValues = [[NSMutableDictionary alloc] initWithDictionary:state.latestValues];
                    latestValues[@(index)] = next;
                    return [[MTSignalCombineState alloc] initWithLatestValues:latestValues completedStatuses:state.completedStatuses error:state.error];
                }];
                NSMutableArray *latestValues = [[NSMutableArray alloc] init];
                for (NSUInteger i = 0; i < count; i++)
                {
                    id value = currentState.latestValues[@(i)];
                    if (value == nil)
                    {
                        latestValues = nil;
                        break;
                    }
                    latestValues[i] = value;
                }
                if (latestValues != nil)
                    [subscriber putNext:latestValues];
            }
                                                         error:^(id error)
            {
                __block bool hadError = false;
                [combineState modify:^id(MTSignalCombineState *state)
                {
                    hadError = state.error;
                    return [[MTSignalCombineState alloc] initWithLatestValues:state.latestValues completedStatuses:state.completedStatuses error:true];
                }];
                if (!hadError)
                    [subscriber putError:error];
            } completed:^
            {
                __block bool wasCompleted = false;
                __block bool isCompleted = false;
                [combineState modify:^id(MTSignalCombineState *state)
                {
                    NSMutableArray *completedStatuses = [[NSMutableArray alloc] initWithArray:state.completedStatuses];
                    bool everyStatusWasCompleted = true;
                    for (NSNumber *nStatus in completedStatuses)
                    {
                        if (![nStatus boolValue])
                        {
                            everyStatusWasCompleted = false;
                            break;
                        }
                    }
                    completedStatuses[index] = @true;
                    bool everyStatusIsCompleted = true;
                    for (NSNumber *nStatus in completedStatuses)
                    {
                        if (![nStatus boolValue])
                        {
                            everyStatusIsCompleted = false;
                            break;
                        }
                    }
                    
                    wasCompleted = everyStatusWasCompleted;
                    isCompleted = everyStatusIsCompleted;
                    
                    return [[MTSignalCombineState alloc] initWithLatestValues:state.latestValues completedStatuses:completedStatuses error:state.error];
                }];
                if (!wasCompleted && isCompleted)
                    [subscriber putCompletion];
            }];
            [compositeDisposable add:disposable];
            index++;
        }
        
        return compositeDisposable;
    }];
}

+ (MTSignal *)mergeSignals:(NSArray *)signals
{
    if (signals.count == 0)
        return [MTSignal complete];
    
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        MTDisposableSet *disposables = [[MTDisposableSet alloc] init];
        MTAtomic *completedStates = [[MTAtomic alloc] initWithValue:[[NSSet alloc] init]];
        
        NSInteger index = -1;
        NSUInteger count = signals.count;
        for (MTSignal *signal in signals)
        {
            index++;
            
            id<MTDisposable> disposable = [signal startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                NSSet *set = [completedStates modify:^id(NSSet *set)
                {
                    return [set setByAddingObject:@(index)];
                }];
                if (set.count == count)
                    [subscriber putCompletion];
            }];
            
            [disposables add:disposable];
        }
        
        return disposables;
    }];
};

static dispatch_block_t recursiveBlock(void (^block)(dispatch_block_t recurse))
{
    return ^
    {
        block(recursiveBlock(block));
    };
}

- (MTSignal *)restart
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        MTAtomic *shouldRestart = [[MTAtomic alloc] initWithValue:@true];
        
        MTMetaDisposable *currentDisposable = [[MTMetaDisposable alloc] init];
        
        void (^start)() = recursiveBlock(^(dispatch_block_t recurse)
        {
            NSNumber *currentShouldRestart = [shouldRestart with:^id(NSNumber *current)
            {
                return current;
            }];
            
            if ([currentShouldRestart boolValue])
            {
                id<MTDisposable> disposable = [self startWithNext:^(id next)
                {
                    [subscriber putNext:next];
                } error:^(id error)
                {
                    [subscriber putError:error];
                } completed:^
                {
                    recurse();
                }];
                [currentDisposable setDisposable:disposable];
            }
        });
        
        start();
        
        return [[MTBlockDisposable alloc] initWithBlock:^
        {
            [currentDisposable dispose];
            
            [shouldRestart modify:^id(__unused id current)
            {
                return @false;
            }];
        }];
    }];
}

- (MTSignal *)take:(NSUInteger)count
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        MTAtomic *counter = [[MTAtomic alloc] initWithValue:@(0)];
        return [self startWithNext:^(id next)
        {
            __block bool passthrough = false;
            __block bool complete = false;
            [counter modify:^id(NSNumber *currentCount)
            {
                NSUInteger updatedCount = [currentCount unsignedIntegerValue] + 1;
                if (updatedCount <= count)
                    passthrough = true;
                if (updatedCount == count)
                    complete = true;
                return @(updatedCount);
            }];
            
            if (passthrough)
                [subscriber putNext:next];
            if (complete)
                [subscriber putCompletion];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [subscriber putCompletion];
        }];
    }];
}

- (MTSignal *)switchToLatest
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        MTSignalQueueState *state = [[MTSignalQueueState alloc] initWithSubscriber:subscriber queueMode:false];
        
        [state beginWithDisposable:[self startWithNext:^(id next)
        {
            [state enqueueSignal:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [state beginCompletion];
        }]];
        
        return state;
    }];
}

- (MTSignal *)map:(id (^)(id))f {
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        return [self startWithNext:^(id next)
        {
            [subscriber putNext:f(next)];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [subscriber putCompletion];
        }];
    }];
}

- (MTSignal *)filter:(bool (^)(id))f
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        return [self startWithNext:^(id next)
        {
            if (f(next))
                [subscriber putNext:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [subscriber putCompletion];
        }];
    }];
}

- (MTSignal *)mapToSignal:(MTSignal *(^)(id))f
{
    return [[self map:f] switchToLatest];
}

- (MTSignal *)onDispose:(void (^)())f
{
    return [[MTSignal alloc] initWithGenerator:^(MTSubscriber *subscriber)
    {
        MTDisposableSet *compositeDisposable = [[MTDisposableSet alloc] init];
        
        [compositeDisposable add:[self startWithNext:^(id next)
        {
            [subscriber putNext:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [subscriber putCompletion];
        }]];
        
        [compositeDisposable add:[[MTBlockDisposable alloc] initWithBlock:^
        {
            f();
        }]];
        
        return compositeDisposable;
    }];
}

- (MTSignal *)deliverOn:(MTQueue *)queue
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        return [self startWithNext:^(id next)
        {
            [queue dispatchOnQueue:^
            {
                [subscriber putNext:next];
            }];
        } error:^(id error)
        {
            [queue dispatchOnQueue:^
            {
                [subscriber putError:error];
            }];
        } completed:^
        {
            [queue dispatchOnQueue:^
            {
                [subscriber putCompletion];
            }];
        }];
    }];
}

- (MTSignal *)startOn:(MTQueue *)queue
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable> (MTSubscriber *subscriber)
    {
        __block bool isCancelled = false;
        MTMetaDisposable *disposable = [[MTMetaDisposable alloc] init];
        [disposable setDisposable:[[MTBlockDisposable alloc] initWithBlock:^
        {
            isCancelled = true;
        }]];
        
        [queue dispatchOnQueue:^
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

- (MTSignal *)takeLast
{
    return [[MTSignal alloc] initWithGenerator:^id<MTDisposable>(MTSubscriber *subscriber)
    {
        MTAtomic *last = [[MTAtomic alloc] initWithValue:nil];
        return [self startWithNext:^(id next)
        {
            [last swap:[[MTSignal_ValueContainer alloc] initWithValue:next]];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            MTSignal_ValueContainer *value = [last with:^id(id value) {
                return value;
            }];
            if (value != nil)
            {
                [subscriber putNext:value.value];
            }
            [subscriber putCompletion];
        }];
    }];
}

- (MTSignal *)reduceLeft:(id)value with:(id (^)(id, id))f
{
    return [[MTSignal alloc] initWithGenerator:^(MTSubscriber *subscriber)
    {
        __block id intermediateResult = value;
        
        return [self startWithNext:^(id next)
        {
            intermediateResult = f(intermediateResult, next);
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            if (intermediateResult != nil)
                [subscriber putNext:intermediateResult];
            [subscriber putCompletion];
        }];
    }];
}

@end
