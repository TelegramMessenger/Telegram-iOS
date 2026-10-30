#import <XCTest/XCTest.h>
#import "LHDocument.h"

@interface TextPaintExclusionTests : XCTestCase
@end

@implementation TextPaintExclusionTests

static NSString *Page(NSString *text)
{
    return [NSString stringWithFormat:@"<style>body{margin:0;font:16px/24px sans-serif}textarea{display:block;width:200px;height:100px;padding:8px;color:#c03070;background:#ccc;border:3px solid currentColor;text-shadow:1px 2px #fff}</style><textarea data-id='field'>%@</textarea><div>Neighbor text</div>", text];
}

static NSData *Pixels(LHDocument *document)
{
    [document layoutWithMaxWidth:260 preferredWidth:260];
    CGImageRef image = [document copyImageWithMaxWidth:260 rect:CGRectMake(0, 0, 260, 180) scale:2];
    NSData *pixels = CFBridgingRelease(CGDataProviderCopyData(CGImageGetDataProvider(image)));
    CGImageRelease(image);
    return pixels;
}

- (void)testTextExclusionPreservesTheBoxAndComputedColor
{
    LHDocument *document = [[LHDocument alloc] initWithHTML:Page(@"Color changes") css:nil];
    LHDocument *empty = [[LHDocument alloc] initWithHTML:Page(@"") css:nil];
    NSData *before = Pixels(document);
    NSString *bounds = document.layoutSignature;
    NSDictionary *style = [document computedStyleForAttribute:@"data-id" value:@"field"];
    [document setTextPaintExclusions:[NSSet setWithObject:@"field"] attribute:@"data-id"];
    NSData *hidden = Pixels(document);
    XCTAssertNotEqualObjects(before, hidden);
    XCTAssertEqualObjects(hidden, Pixels(empty));
    XCTAssertEqualObjects(document.layoutSignature, bounds);
    XCTAssertEqualObjects([document computedStyleForAttribute:@"data-id" value:@"field"], style);
    [document setTextPaintExclusions:[NSSet set] attribute:@"data-id"];
    XCTAssertEqualObjects(Pixels(document), before);
}

@end
