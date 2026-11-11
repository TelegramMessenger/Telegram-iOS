#import <XCTest/XCTest.h>
#import "LHDocument.h"

@interface SVGGeometryTests : XCTestCase
@end

@implementation SVGGeometryTests

static NSData *SVGCachePixels(LHDocument *document)
{
    [document layoutWithMaxWidth:400 preferredWidth:400];
    CGImageRef image = [document copyImageWithMaxWidth:400 rect:CGRectMake(0, 0, 400, 240) scale:2];
    if(!image)
    {
        XCTFail(@"SVG render failed");
        return [NSData data];
    }
    NSData *data = CFBridgingRelease(CGDataProviderCopyData(CGImageGetDataProvider(image)));
    CGImageRelease(image);
    return data;
}

- (NSString *)groupScene:(NSString *)attributes extra:(NSString *)extra style:(NSString *)style
{
    NSMutableString *html = [NSMutableString stringWithFormat:@"<style>body{margin:0;background:#fff;color:#246b92}</style><svg id='svg' style='%@' width='200' height='100' viewBox='0 0 100 100'>%@<g %@>", style, extra, attributes];
    for(int i = 0; i < 12; i++)
        [html appendFormat:@"<circle cx='%d' cy='%d' r='9' stroke-width='2'/>", i * 12 - 15, 20 + i % 3 * 20];
    [html appendString:@"</g><path id='hand' style='opacity:1' d='M5 90 L90 85' stroke='orange' stroke-width='3'/></svg>"];
    return html;
}

- (void)assertPixels:(NSData *)a match:(NSData *)b
{
    XCTAssertEqual(a.length, b.length);
    if(a.length != b.length) return;
    const uint8_t *left = (const uint8_t *)a.bytes, *right = (const uint8_t *)b.bytes;
    int worst = 0;
    for(NSUInteger i = 0; i < a.length; i++)
        worst = MAX(worst, abs((int)left[i] - (int)right[i]));
    XCTAssertLessThanOrEqual(worst, 1);
}

- (void)testStaticSVGDoesNotAllocateGroupImages
{
    NSString *html = [self groupScene:@"fill='currentColor' stroke='#c74880'" extra:@"" style:@"display:block"];
    [LHDocument setSVGGroupCacheEnabled:NO];
    [LHDocument purgeCaches];
    LHDocument *plain = [[LHDocument alloc] initWithHTML:html css:nil];
    SVGCachePixels(plain);
    NSUInteger plainBytes = [LHDocument rasterCacheBytes];
    [LHDocument setSVGGroupCacheEnabled:YES];
    [LHDocument purgeCaches];
    LHDocument *cached = [[LHDocument alloc] initWithHTML:html css:nil];
    SVGCachePixels(cached);
    XCTAssertEqual([LHDocument rasterCacheBytes], plainBytes);
}

- (LHDocument*)document
{
    NSString* html = @"<!doctype html><svg width='200' height='100' viewBox='0 0 200 100'>"
                     @"<line data-t=line x1='0' y1='0' x2='30' y2='40'/>"
                     @"<rect data-t=rect x='10' y='10' width='50' height='20'/>"
                     @"<circle data-t=circle cx='50' cy='50' r='10'/>"
                     @"<polyline data-t=poly points='0,0 10,0 10,10'/>"
                     @"<path data-t=path d='M10 80 C 40 10, 65 10, 95 80'/>"
                     @"<path data-t=arc d='M0 50 A50 50 0 0 1 100 50'/>"
                     @"<g data-t=group></g></svg>";
    LHDocument* doc = [[LHDocument alloc] initWithHTML:html css:nil];
    [doc layoutWithMaxWidth:300 preferredWidth:300];
    return doc;
}

- (double)length:(NSString*)key in:(LHDocument*)doc
{
    return [[doc svgGeometry:@"getTotalLength" at:0 attribute:@"data-t" value:key][@"length"] doubleValue];
}

- (void)testTotalLengthMatchesWebKitForBasicShapes
{
    LHDocument* doc = [self document];
    XCTAssertEqualWithAccuracy([self length:@"line" in:doc], 50, 0.01);
    XCTAssertEqualWithAccuracy([self length:@"rect" in:doc], 140, 0.01);
    XCTAssertEqualWithAccuracy([self length:@"circle" in:doc], 2 * M_PI * 10, 0.1);
    XCTAssertEqualWithAccuracy([self length:@"poly" in:doc], 20, 0.01);
    XCTAssertEqualWithAccuracy([self length:@"path" in:doc], 141.2, 1.0);
    XCTAssertEqualWithAccuracy([self length:@"arc" in:doc], M_PI * 50, 0.3);
    XCTAssertNil([doc svgGeometry:@"getTotalLength" at:0 attribute:@"data-t" value:@"group"]);
}

- (void)testPointAtLengthWalksTheOutline
{
    LHDocument*   doc = [self document];
    NSDictionary* p   = [doc svgGeometry:@"getPointAtLength" at:25 attribute:@"data-t" value:@"line"];
    XCTAssertEqualWithAccuracy([p[@"x"] doubleValue], 15, 0.01);
    XCTAssertEqualWithAccuracy([p[@"y"] doubleValue], 20, 0.01);
    p = [doc svgGeometry:@"getPointAtLength" at:15 attribute:@"data-t" value:@"poly"];
    XCTAssertEqualWithAccuracy([p[@"x"] doubleValue], 10, 0.01);
    XCTAssertEqualWithAccuracy([p[@"y"] doubleValue], 5, 0.01);
    p = [doc svgGeometry:@"getPointAtLength" at:1000 attribute:@"data-t" value:@"line"];
    XCTAssertEqualWithAccuracy([p[@"x"] doubleValue], 30, 0.01);
}

- (void)testBBoxCoversTheCurveNotItsControlPoints
{
    NSDictionary* b = [[self document] svgGeometry:@"getBBox" at:0 attribute:@"data-t" value:@"path"];
    XCTAssertEqualWithAccuracy([b[@"x"] doubleValue], 10, 0.5);
    XCTAssertEqualWithAccuracy([b[@"width"] doubleValue], 85, 0.5);
    XCTAssertEqualWithAccuracy([b[@"y"] doubleValue], 27.5, 0.5);
    XCTAssertEqualWithAccuracy([b[@"height"] doubleValue], 52.5, 0.5);
}

@end
