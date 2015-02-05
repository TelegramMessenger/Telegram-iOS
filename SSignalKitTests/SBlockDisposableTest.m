#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import <libkern/OSAtomic.h>

@import SSignalKit;

@interface TestObject : NSObject
{
    bool *_deallocated;
}

@end

@implementation TestObject

- (instancetype)initWithDeallocated:(bool *)deallocated
{
    self = [super init];
    if (self != nil)
    {
        _deallocated = deallocated;
    }
    return self;
}

- (void)dealloc
{
    *_deallocated = true;
}

@end

@interface SBlockDisposableTest : XCTestCase

@end

@implementation SBlockDisposableTest

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testBlockDisposableDisposed
{
    bool deallocated = false;
    {
        TestObject *object = [[TestObject alloc] initWithDeallocated:&deallocated];
        dispatch_block_t block = ^{
            [object description];
        };
        SBlockDisposable *disposable = [[SBlockDisposable alloc] initWithBlock:[block copy]];
        object = nil;
        block = nil;
        [disposable dispose];
    }
    
    XCTAssertTrue(deallocated);
}

- (void)testBlockDisposableNotDisposed
{
    bool deallocated = false;
    {
        TestObject *object = [[TestObject alloc] initWithDeallocated:&deallocated];
        dispatch_block_t block = ^{
            [object description];
        };
        SBlockDisposable *disposable = [[SBlockDisposable alloc] initWithBlock:[block copy]];
        object = nil;
        block = nil;
        disposable = nil;
    }
    
    XCTAssertTrue(deallocated);
}

@end
