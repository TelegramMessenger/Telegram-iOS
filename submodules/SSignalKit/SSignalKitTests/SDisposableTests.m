#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>
#else
#import <Foundation/Foundation.h>
#endif
#import <XCTest/XCTest.h>

#import <libkern/OSAtomic.h>

@import SSignalKit;

#import "DeallocatingObject.h"

@interface SDisposableTests : XCTestCase

@end

@implementation SDisposableTests

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
    __block bool disposed = false;
    {
        DeallocatingObject *object = [[DeallocatingObject alloc] initWithDeallocated:&deallocated];
        dispatch_block_t block = ^{
            [object description];
            disposed = true;
        };
        SBlockDisposable *disposable = [[SBlockDisposable alloc] initWithBlock:[block copy]];
        object = nil;
        block = nil;
        [disposable dispose];
    }
    
    XCTAssertTrue(deallocated);
    XCTAssertTrue(disposed);
}

- (void)testBlockDisposableNotDisposed
{
    bool deallocated = false;
    __block bool disposed = false;
    {
        DeallocatingObject *object = [[DeallocatingObject alloc] initWithDeallocated:&deallocated];
        dispatch_block_t block = ^{
            [object description];
            disposed = true;
        };
        SBlockDisposable *disposable = [[SBlockDisposable alloc] initWithBlock:[block copy]];
        [disposable description];
    }
    
    XCTAssertTrue(deallocated);
    XCTAssertFalse(disposed);
}

- (void)testMetaDisposableDisposed
{
    bool deallocated = false;
    __block bool disposed = false;
    {
        DeallocatingObject *object = [[DeallocatingObject alloc] initWithDeallocated:&deallocated];
        dispatch_block_t block = ^{
            [object description];
            disposed = true;
        };
        SBlockDisposable *blockDisposable = [[SBlockDisposable alloc] initWithBlock:[block copy]];
        
        SMetaDisposable *metaDisposable = [[SMetaDisposable alloc] init];
        [metaDisposable setDisposable:blockDisposable];
        [metaDisposable dispose];
    }
    
    XCTAssertTrue(deallocated);
    XCTAssertTrue(disposed);
}

- (void)testMetaDisposableDisposedMultipleTimes
{
    bool deallocated1 = false;
    __block bool disposed1 = false;
    bool deallocated2 = false;
    __block bool disposed2 = false;
    {
        DeallocatingObject *object1 = [[DeallocatingObject alloc] initWithDeallocated:&deallocated1];
        dispatch_block_t block1 = ^{
            [object1 description];
            disposed1 = true;
        };
        SBlockDisposable *blockDisposable1 = [[SBlockDisposable alloc] initWithBlock:[block1 copy]];
        
        DeallocatingObject *object2 = [[DeallocatingObject alloc] initWithDeallocated:&deallocated2];
        dispatch_block_t block2 = ^{
            [object2 description];
            disposed2 = true;
        };
        SBlockDisposable *blockDisposable2 = [[SBlockDisposable alloc] initWithBlock:[block2 copy]];
        
        SMetaDisposable *metaDisposable = [[SMetaDisposable alloc] init];
        [metaDisposable setDisposable:blockDisposable1];
        [metaDisposable setDisposable:blockDisposable2];
        [metaDisposable dispose];
    }
    
    XCTAssertTrue(deallocated1);
    XCTAssertTrue(disposed1);
    XCTAssertTrue(deallocated2);
    XCTAssertTrue(disposed2);
}

- (void)testMetaDisposableNotDisposed
{
    bool deallocated = false;
    __block bool disposed = false;
    {
        DeallocatingObject *object = [[DeallocatingObject alloc] initWithDeallocated:&deallocated];
        dispatch_block_t block = ^{
            [object description];
            disposed = true;
        };
        SBlockDisposable *blockDisposable = [[SBlockDisposable alloc] initWithBlock:[block copy]];
        
        SMetaDisposable *metaDisposable = [[SMetaDisposable alloc] init];
        [metaDisposable setDisposable:blockDisposable];
    }
    
    XCTAssertTrue(deallocated);
    XCTAssertFalse(disposed);
}

- (void)testDisposableSetSingleDisposed
{
    bool deallocated = false;
    __block bool disposed = false;
    {
        DeallocatingObject *object = [[DeallocatingObject alloc] initWithDeallocated:&deallocated];
        dispatch_block_t block = ^{
            [object description];
            disposed = true;
        };
        SBlockDisposable *blockDisposable = [[SBlockDisposable alloc] initWithBlock:[block copy]];
        
        SDisposableSet *disposableSet = [[SDisposableSet alloc] init];
        [disposableSet add:blockDisposable];
        [disposableSet dispose];
    }
    
    XCTAssertTrue(deallocated);
    XCTAssertTrue(disposed);
}

- (void)testDisposableSetMultipleDisposed
{
    bool deallocated1 = false;
    __block bool disposed1 = false;
    bool deallocated2 = false;
    __block bool disposed2 = false;
    {
        DeallocatingObject *object1 = [[DeallocatingObject alloc] initWithDeallocated:&deallocated1];
        dispatch_block_t block1 = ^{
            [object1 description];
            disposed1 = true;
        };
        SBlockDisposable *blockDisposable1 = [[SBlockDisposable alloc] initWithBlock:[block1 copy]];
        
        DeallocatingObject *object2 = [[DeallocatingObject alloc] initWithDeallocated:&deallocated2];
        dispatch_block_t block2 = ^{
            [object2 description];
            disposed2 = true;
        };
        SBlockDisposable *blockDisposable2 = [[SBlockDisposable alloc] initWithBlock:[block2 copy]];
        
        SDisposableSet *disposableSet = [[SDisposableSet alloc] init];
        [disposableSet add:blockDisposable1];
        [disposableSet add:blockDisposable2];
        [disposableSet dispose];
    }
    
    XCTAssertTrue(deallocated1);
    XCTAssertTrue(disposed1);
    XCTAssertTrue(deallocated2);
    XCTAssertTrue(disposed2);
}

- (void)testDisposableSetSingleNotDisposed
{
    bool deallocated = false;
    __block bool disposed = false;
    {
        DeallocatingObject *object = [[DeallocatingObject alloc] initWithDeallocated:&deallocated];
        dispatch_block_t block = ^{
            [object description];
            disposed = true;
        };
        SBlockDisposable *blockDisposable = [[SBlockDisposable alloc] initWithBlock:[block copy]];
        
        SDisposableSet *disposableSet = [[SDisposableSet alloc] init];
        [disposableSet add:blockDisposable];
    }
    
    XCTAssertTrue(deallocated);
    XCTAssertFalse(disposed);
}

- (void)testDisposableSetMultipleNotDisposed
{
    bool deallocated1 = false;
    __block bool disposed1 = false;
    bool deallocated2 = false;
    __block bool disposed2 = false;
    {
        DeallocatingObject *object1 = [[DeallocatingObject alloc] initWithDeallocated:&deallocated1];
        dispatch_block_t block1 = ^{
            [object1 description];
            disposed1 = true;
        };
        SBlockDisposable *blockDisposable1 = [[SBlockDisposable alloc] initWithBlock:[block1 copy]];
        
        DeallocatingObject *object2 = [[DeallocatingObject alloc] initWithDeallocated:&deallocated2];
        dispatch_block_t block2 = ^{
            [object2 description];
            disposed2 = true;
        };
        SBlockDisposable *blockDisposable2 = [[SBlockDisposable alloc] initWithBlock:[block2 copy]];
        
        SDisposableSet *disposableSet = [[SDisposableSet alloc] init];
        [disposableSet add:blockDisposable1];
        [disposableSet add:blockDisposable2];
    }
    
    XCTAssertTrue(deallocated1);
    XCTAssertFalse(disposed1);
    XCTAssertTrue(deallocated2);
    XCTAssertFalse(disposed2);
}

- (void)testMetaDisposableAlreadyDisposed
{
    bool deallocated1 = false;
    __block bool disposed1 = false;
    bool deallocated2 = false;
    __block bool disposed2 = false;
    
    @autoreleasepool
    {
        DeallocatingObject *object1 = [[DeallocatingObject alloc] initWithDeallocated:&deallocated1];
        dispatch_block_t block1 = ^{
            [object1 description];
            disposed1 = true;
        };
        SBlockDisposable *blockDisposable1 = [[SBlockDisposable alloc] initWithBlock:[block1 copy]];
        
        DeallocatingObject *object2 = [[DeallocatingObject alloc] initWithDeallocated:&deallocated2];
        dispatch_block_t block2 = ^{
            [object2 description];
            disposed2 = true;
        };
        SBlockDisposable *blockDisposable2 = [[SBlockDisposable alloc] initWithBlock:[block2 copy]];
        
        SMetaDisposable *metaDisposable = [[SMetaDisposable alloc] init];
        [metaDisposable setDisposable:blockDisposable1];
        [metaDisposable dispose];
        [metaDisposable setDisposable:blockDisposable2];
    }
    
    XCTAssertTrue(deallocated1);
    XCTAssertTrue(disposed1);
    XCTAssertTrue(deallocated2);
    XCTAssertTrue(disposed2);
}

- (void)testDisposableSetAlreadyDisposed
{
    bool deallocated1 = false;
    __block bool disposed1 = false;
    bool deallocated2 = false;
    __block bool disposed2 = false;
    
    @autoreleasepool
    {
        DeallocatingObject *object1 = [[DeallocatingObject alloc] initWithDeallocated:&deallocated1];
        dispatch_block_t block1 = ^{
            [object1 description];
            disposed1 = true;
        };
        SBlockDisposable *blockDisposable1 = [[SBlockDisposable alloc] initWithBlock:[block1 copy]];
        
        DeallocatingObject *object2 = [[DeallocatingObject alloc] initWithDeallocated:&deallocated2];
        dispatch_block_t block2 = ^{
            [object2 description];
            disposed2 = true;
        };
        SBlockDisposable *blockDisposable2 = [[SBlockDisposable alloc] initWithBlock:[block2 copy]];
        
        SMetaDisposable *metaDisposable = [[SMetaDisposable alloc] init];
        [metaDisposable setDisposable:blockDisposable1];
        [metaDisposable dispose];
        [metaDisposable setDisposable:blockDisposable2];
    }
    
    XCTAssertTrue(deallocated1);
    XCTAssertTrue(disposed1);
    XCTAssertTrue(deallocated2);
    XCTAssertTrue(disposed2);
}

@end
