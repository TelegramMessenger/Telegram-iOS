#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

@import SSignalKit;

#import "DeallocatingObject.h"

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

- (void)testInplaceMap
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
            }] _mapInplace:^id(id value)
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

@end
