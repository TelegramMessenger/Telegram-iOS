#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>
#else
#import <Foundation/Foundation.h>
#endif
#import <XCTest/XCTest.h>

@import SSignalKit;

#import "DeallocatingObject.h"

@interface DisposableHolder : NSObject {
}

@property (nonatomic, strong) id<SDisposable> disposable;

@end

@implementation DisposableHolder

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _disposable = [[[SSignal single:nil] delay:1.0 onQueue:[SQueue concurrentDefaultQueue]] startWithNext:^(__unused id next){
            [self description];
        }];
    }
    return self;
}

- (void)dealloc {
    [_disposable dispose];
}

@end

@interface SSignalBasicTests : XCTestCase

@end

@implementation SSignalBasicTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testSignalGenerated
{
    __block bool deallocated = false;
    __block bool disposed = false;
    __block bool generated = false;
    
    {
        DeallocatingObject *object = [[DeallocatingObject alloc] initWithDeallocated:&deallocated];
        SSignal *signal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            [subscriber putNext:@1];
            [object description];
            
            return [[SBlockDisposable alloc] initWithBlock:^
            {
                [object description];
                disposed = true;
            }];
        }];
        id<SDisposable> disposable = [signal startWithNext:^(__unused id next)
        {
            generated = true;
            [object description];
        } error:nil completed:nil];
        [disposable dispose];
    }
    
    XCTAssertTrue(deallocated);
    XCTAssertTrue(disposed);
    XCTAssertTrue(generated);
}

- (void)testSignalGeneratedCompleted
{
    __block bool deallocated = false;
    __block bool disposed = false;
    __block bool generated = false;
    __block bool completed = false;
    
    {
        DeallocatingObject *object = [[DeallocatingObject alloc] initWithDeallocated:&deallocated];
        SSignal *signal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            [subscriber putNext:@1];
            [subscriber putCompletion];
            [object description];
            
            return [[SBlockDisposable alloc] initWithBlock:^
            {
                [object description];
                disposed = true;
            }];
        }];
        id<SDisposable> disposable = [signal startWithNext:^(__unused id next)
        {
            [object description];
            generated = true;
        } error:nil completed:^
        {
            [object description];
            completed = true;
        }];
        [disposable dispose];
    }
    
    XCTAssertTrue(deallocated);
    XCTAssertTrue(disposed);
    XCTAssertTrue(generated);
    XCTAssertTrue(completed);
}

- (void)testSignalGeneratedError
{
    __block bool deallocated = false;
    __block bool disposed = false;
    __block bool generated = false;
    __block bool error = false;
    
    {
        DeallocatingObject *object = [[DeallocatingObject alloc] initWithDeallocated:&deallocated];
        SSignal *signal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            [subscriber putNext:@1];
            [subscriber putError:@1];
            [object description];
            
            return [[SBlockDisposable alloc] initWithBlock:^
            {
                [object description];
                disposed = true;
            }];
        }];
        id<SDisposable> disposable = [signal startWithNext:^(__unused id next)
        {
            generated = true;
        } error:^(__unused id value)
        {
            error = true;
        } completed:nil];
        [disposable dispose];
    }
    
    XCTAssertTrue(deallocated);
    XCTAssertTrue(disposed);
    XCTAssertTrue(generated);
    XCTAssertTrue(error);
}

- (void)testMap
{
    bool deallocated = false;
    __block bool disposed = false;
    __block bool generated = false;
    
    {
        @autoreleasepool
        {
            DeallocatingObject *object = [[DeallocatingObject alloc] initWithDeallocated:&deallocated];
            SSignal *signal = [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
            {
                [subscriber putNext:@1];
                [object description];
                return [[SBlockDisposable alloc] initWithBlock:^
                {
                    [object description];
                    disposed = true;
                }];
            }] map:^id(id value)
            {
                [object description];
                return @([value intValue] * 2);
            }];
            
            id<SDisposable> disposable = [signal startWithNext:^(id value)
            {
                generated = [value isEqual:@2];
            } error:nil completed:nil];
            [disposable dispose];
        }
    }
    
    XCTAssertTrue(deallocated);
    XCTAssertTrue(disposed);
    XCTAssertTrue(generated);
}

- (void)testSubscriberDisposal
{
    __block bool disposed = false;
    __block bool generated = false;
    
    dispatch_queue_t queue = dispatch_queue_create(NULL, 0);
    
    @autoreleasepool
    {
        SSignal *signal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            dispatch_async(queue, ^
            {
                usleep(200);
                [subscriber putNext:@1];
            });
            
            return [[SBlockDisposable alloc] initWithBlock:^
            {
                disposed = true;
            }];
        }];
        
        id<SDisposable> disposable = [signal startWithNext:^(id value)
        {
            generated = true;
        } error:nil completed:nil];
        NSLog(@"dispose");
        [disposable dispose];
    }
    
    dispatch_barrier_sync(queue, ^
    {
    });
    
    XCTAssertTrue(disposed);
    XCTAssertFalse(generated);
}

- (void)testThen
{
    __block bool generatedFirst = false;
    __block bool disposedFirst = false;
    __block bool generatedSecond = false;
    __block bool disposedSecond = false;
    __block int result = 0;
    
    SSignal *signal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        generatedFirst = true;
        [subscriber putNext:@(1)];
        [subscriber putCompletion];
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            disposedFirst = true;
        }];
    }];
    
    signal = [signal then:[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        generatedSecond = true;
        [subscriber putNext:@(2)];
        [subscriber putCompletion];
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            disposedSecond = true;
        }];
    }]];
    
    [signal startWithNext:^(id next)
    {
        result += [next intValue];
    }];
    
    XCTAssertTrue(generatedFirst);
    XCTAssertTrue(disposedFirst);
    XCTAssertTrue(generatedSecond);
    XCTAssertTrue(disposedSecond);
    XCTAssert(result == 3);
}

- (void)testSwitchToLatest
{
    __block int result = 0;
    __block bool disposedOne = false;
    __block bool disposedTwo = false;
    __block bool disposedThree = false;
    __block bool completedAll = false;
    
    bool deallocatedOne = false;
    bool deallocatedTwo = false;
    bool deallocatedThree = false;
    
    @autoreleasepool
    {
        DeallocatingObject *objectOne = [[DeallocatingObject alloc] initWithDeallocated:&deallocatedOne];
        DeallocatingObject *objectTwo = [[DeallocatingObject alloc] initWithDeallocated:&deallocatedTwo];
        DeallocatingObject *objectThree = [[DeallocatingObject alloc] initWithDeallocated:&deallocatedThree];

        SSignal *one = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            [subscriber putNext:@(1)];
            [subscriber putCompletion];
            __unused id a0 = [objectOne description];
            return [[SBlockDisposable alloc] initWithBlock:^
            {
                __unused id a0 = [objectOne description];
                disposedOne = true;
            }];
        }];
        SSignal *two = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            [subscriber putNext:@(2)];
            [subscriber putCompletion];
            __unused id a1 = [objectTwo description];
            return [[SBlockDisposable alloc] initWithBlock:^
            {
                __unused id a1 = [objectOne description];
                disposedTwo = true;
            }];
        }];
        SSignal *three = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            [subscriber putNext:@(3)];
            [subscriber putCompletion];
            __unused id a0 = [objectThree description];
            return [[SBlockDisposable alloc] initWithBlock:^
            {
                __unused id a1 = [objectOne description];
                disposedThree = true;
            }];
        }];
        
        SSignal *signal = [[[[SSignal single:one] then:[SSignal single:two]] then:[SSignal single:three]] switchToLatest];
        [signal startWithNext:^(id next)
        {
            result += [next intValue];
        } error:nil completed:^
        {
            completedAll = true;
        }];
    }
    
    XCTAssert(result == 6);
    XCTAssertTrue(disposedOne);
    XCTAssertTrue(disposedTwo);
    XCTAssertTrue(disposedThree);
    XCTAssertTrue(deallocatedOne);
    XCTAssertTrue(deallocatedTwo);
    XCTAssertTrue(deallocatedThree);
    XCTAssertTrue(completedAll);
}

- (void)testSwitchToLatestError
{
    __block bool errorGenerated = false;
    
    SSignal *one = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        [subscriber putError:nil];
        return nil;
    }];
    
    [one startWithNext:^(__unused id next)
    {
        
    } error:^(__unused id error)
    {
        errorGenerated = true;
    } completed:^
    {
        
    }];
    
    XCTAssertTrue(errorGenerated);
}

- (void)testSwitchToLatestCompleted
{
    __block bool completedAll = false;
    
    SSignal *one = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        [subscriber putCompletion];
        return nil;
    }];
    
    [one startWithNext:^(__unused id next)
    {
        
    } error:^(__unused id error)
    {
    } completed:^
    {
        completedAll = true;
    }];
    
    XCTAssertTrue(completedAll);
}

- (void)testQueue
{
    dispatch_queue_t queue = dispatch_queue_create(NULL, 0);
    
    __block bool disposedFirst = false;
    __block bool disposedSecond = false;
    __block bool disposedThird = false;
    __block int result = 0;
    
    SSignal *firstSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        dispatch_async(queue, ^
        {
            usleep(100);
            [subscriber putNext:@1];
            [subscriber putCompletion];
        });
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            disposedFirst = true;
        }];
    }];
    
    SSignal *secondSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        dispatch_async(queue, ^
        {
            usleep(100);
            [subscriber putNext:@2];
            [subscriber putCompletion];
        });
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            disposedSecond = true;
        }];
    }];
    
    SSignal *thirdSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        dispatch_async(queue, ^
        {
            usleep(100);
            [subscriber putNext:@3];
            [subscriber putCompletion];
        });
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            disposedThird = true;
        }];
    }];
    
    SSignal *signal = [[[[SSignal single:firstSignal] then:[SSignal single:secondSignal]] then:[SSignal single:thirdSignal]] queue];
    [signal startWithNext:^(id next)
    {
        result += [next intValue];
    }];
    
    usleep(1000);
    
    XCTAssertEqual(result, 6);
    XCTAssertTrue(disposedFirst);
    XCTAssertTrue(disposedSecond);
    XCTAssertTrue(disposedThird);
}

- (void)testQueueInterrupted
{
    dispatch_queue_t queue = dispatch_queue_create(NULL, 0);
    
    __block bool disposedFirst = false;
    __block bool disposedSecond = false;
    __block bool disposedThird = false;
    __block bool startedThird = false;
    __block int result = 0;
    
    SSignal *firstSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        dispatch_async(queue, ^
        {
            usleep(100);
            [subscriber putNext:@1];
            [subscriber putCompletion];
        });
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            disposedFirst = true;
        }];
    }];
    
    SSignal *secondSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        dispatch_async(queue, ^
        {
            usleep(100);
            [subscriber putNext:@2];
            [subscriber putError:nil];
        });
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            disposedSecond = true;
        }];
    }];
    
    SSignal *thirdSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        startedThird = true;
        
        dispatch_async(queue, ^
        {
            usleep(100);
            [subscriber putNext:@3];
            [subscriber putCompletion];
        });
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            disposedThird = true;
        }];
    }];
    
    SSignal *signal = [[[[SSignal single:firstSignal] then:[SSignal single:secondSignal]] then:[SSignal single:thirdSignal]] queue];
    [signal startWithNext:^(id next)
    {
        result += [next intValue];
    }];
    
    usleep(1000);
    
    XCTAssertEqual(result, 3);
    XCTAssertTrue(disposedFirst);
    XCTAssertTrue(disposedSecond);
    XCTAssertFalse(startedThird);
    XCTAssertFalse(disposedThird);
}

- (void)testQueueDisposed
{
    dispatch_queue_t queue = dispatch_queue_create(NULL, 0);
    
    __block bool disposedFirst = false;
    __block bool disposedSecond = false;
    __block bool disposedThird = false;
    __block bool startedFirst = false;
    __block bool startedSecond = false;
    __block bool startedThird = false;
    __block int result = 0;
    
    SSignal *firstSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        startedFirst = true;
        
        __block bool cancelled = false;
        dispatch_async(queue, ^
        {
            if (!cancelled)
            {
                usleep(100);
                [subscriber putNext:@1];
                [subscriber putCompletion];
            }
        });
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            cancelled = true;
            disposedFirst = true;
        }];
    }];
    
    SSignal *secondSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        startedSecond = true;
        
        __block bool cancelled = false;
        dispatch_async(queue, ^
        {
            if (!cancelled)
            {
                usleep(100);
                [subscriber putNext:@2];
                [subscriber putError:nil];
            }
        });
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            cancelled = true;
            disposedSecond = true;
        }];
    }];
    
    SSignal *thirdSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        startedThird = true;
        
        dispatch_async(queue, ^
        {
            usleep(100);
            [subscriber putNext:@3];
            [subscriber putCompletion];
        });
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            disposedThird = true;
        }];
    }];
    
    SSignal *signal = [[[[SSignal single:firstSignal] then:[SSignal single:secondSignal]] then:[SSignal single:thirdSignal]] queue];
    [[signal startWithNext:^(id next)
    {
        result += [next intValue];
    }] dispose];
    
    usleep(1000);
    
    XCTAssertEqual(result, 0);
    XCTAssertTrue(disposedFirst);
    XCTAssertFalse(disposedSecond);
    XCTAssertFalse(disposedThird);
    
    XCTAssertTrue(startedFirst);
    XCTAssertFalse(startedSecond);
    XCTAssertFalse(startedThird);
}

- (void)testRestart
{
    SSignal *signal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        [[SQueue concurrentDefaultQueue] dispatch:^
        {
            [subscriber putNext:@1];
            [subscriber putCompletion];
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
        }];
    }];
    
    __block int result = 0;
    
    [[[signal restart] take:3] startWithNext:^(id next)
    {
        result += [next intValue];
    } error:^(id error) {
        
    } completed:^{
        
    }];
    
    usleep(100 * 1000);
    
    XCTAssertEqual(result, 3);
}

- (void)testPipe
{
    SPipe *pipe = [[SPipe alloc] init];
    
    __block int result1 = 0;
    id<SDisposable> disposable1 = [pipe.signalProducer() startWithNext:^(id next)
    {
        result1 += [next intValue];
    }];
    
    __block int result2 = 0;
    id<SDisposable> disposable2 = [pipe.signalProducer() startWithNext:^(id next)
    {
        result2 += [next intValue];
    }];
    
    pipe.sink(@1);
    
    XCTAssertEqual(result1, 1);
    XCTAssertEqual(result2, 1);
    
    [disposable1 dispose];
    
    pipe.sink(@1);
    
    XCTAssertEqual(result1, 1);
    XCTAssertEqual(result2, 2);
    
    [disposable2 dispose];
    
    pipe.sink(@1);
    
    XCTAssertEqual(result1, 1);
    XCTAssertEqual(result2, 2);
}

- (void)testDisposableDeadlock {
    @autoreleasepool {
        DisposableHolder *holder = [[DisposableHolder alloc] init];
        holder = nil;
        sleep(10);
    }
}

- (void)testRetryIfNoError {
    SSignal *s = [[SSignal single:@1] retryIf:^bool(__unused id error) {
        return true;
    }];
    [s startWithNext:^(id next) {
        XCTAssertEqual(next, @1);
    }];
}

- (void)testRetryErrorNoMatch {
    SSignal *s = [[SSignal fail:@false] retryIf:^bool(id error) {
        return false;
    }];
}

- (void)testRetryErrorMatch {
    __block counter = 1;
    SSignal *s = [[[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber) {
        if (counter == 1) {
            counter++;
            [subscriber putError:@true];
        } else {
            [subscriber putNext:@(counter)];
        }
        return nil;
    }] retryIf:^bool(id error) {
        return [error boolValue];
    }];
    
    __block int value = 0;
    [s startWithNext:^(id next) {
        value = [next intValue];
    }];
    
    XCTAssertEqual(value, 2);
}

- (void)testRetryErrorFailNoMatch {
    __block counter = 1;
    SSignal *s = [[[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber) {
        if (counter == 1) {
            counter++;
            [subscriber putError:@true];
        } else {
            [subscriber putError:@false];
        }
        return nil;
    }] retryIf:^bool(id error) {
        return [error boolValue];
    }];
    
    __block bool errorMatches = false;
    [s startWithNext:nil error:^(id error) {
        errorMatches = ![error boolValue];
    } completed:nil];
    
    XCTAssert(errorMatches);
}

@end
