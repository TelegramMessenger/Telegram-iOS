@import XCTest;
@interface IDProjectUITests : XCTestCase @end
@implementation IDProjectUITests
- (void)testApplicationLaunchesInForeground {
    XCUIApplication *app = [XCUIApplication new];
    [app launch];
    XCTAssertEqual(app.state, XCUIApplicationStateRunningForeground);
}
@end
