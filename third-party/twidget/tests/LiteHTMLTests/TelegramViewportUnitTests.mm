// Telegram (VENDOR.md edit 11): since twidget b5878f9, viewport units fold to pixels while a declaration is parsed,
// against the viewport the document is built with; the process-wide declaration cache must not hand one document's
// fold to another built at a different viewport.
#import <XCTest/XCTest.h>
#import "LHDocument.h"

@interface TelegramViewportUnitTests : XCTestCase
@end

@implementation TelegramViewportUnitTests

- (CGFloat)widthOfHalfViewportAt:(CGFloat)viewportWidth
{
    NSString *html = @"<html><body style='margin:0'><div id=a style='width:50vw;height:4px'></div></body></html>";
    LHDocument *doc = [[LHDocument alloc] initWithHTML:html css:nil viewportSize:CGSizeMake(viewportWidth, 0)];
    [doc layoutWithMaxWidth:viewportWidth];
    return [doc boundsOfElementsMatching:@"#a"].size.width;
}

- (void)testViewportUnitsFollowEachDocumentsViewport
{
    XCTAssertEqual([self widthOfHalfViewportAt:360], 180);
    // The same declaration text, parsed again for a document with another viewport.
    XCTAssertEqual([self widthOfHalfViewportAt:500], 250);
    XCTAssertEqual([self widthOfHalfViewportAt:360], 180);
}

@end
