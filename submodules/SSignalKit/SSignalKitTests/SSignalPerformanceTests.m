#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>
#else
#import <Foundation/Foundation.h>
#endif
#import <XCTest/XCTest.h>

@import SSignalKit;

@interface SSignalPerformanceTests : XCTestCase

@end

@implementation SSignalPerformanceTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testMap
{
    [self measureBlock:^
    {
        SSignal *signal = [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            [subscriber putNext:@1];
            [subscriber putCompletion];
            return nil;
        }] map:^id (id value)
        {
            return value;
        }];
        
        for (int i = 0; i < 100000; i++)
        {
            [signal startWithNext:^(__unused id next)
            {
                
            }];
        }
    }];
}

@end
