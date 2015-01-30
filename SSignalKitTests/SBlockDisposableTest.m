#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import <libkern/OSAtomic.h>

@import SSignalKit;

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

- (void)testBlockDisposable
{
}

- (void)testPerformanceExample
{
    [self measureBlock:^
    {
        SSignal *signal = [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
        {
            //SSubscriber_putNext(subscriber, @1);
            //SSubscriber_putCompletion(subscriber);
        }];
        
        for (int i = 0; i < 1000000; i++)
        {
            [signal startWithNext:^(id next)
            {
                
            } error:^(id error)
            {
                
            } completed:^
            {
                
            }];
            //SSignal_start(signal, ^(id next){}, ^(id error){}, ^{});
        }
    }];
}

@end
