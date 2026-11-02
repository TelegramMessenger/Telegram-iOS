#import <XCTest/XCTest.h>
#import "LHDocument.h"

#include <random>

@interface StylePatchTests : XCTestCase
@end

@implementation StylePatchTests

static NSString *const Attribute = @"data-lh-id";

static NSString *Page(NSString *a, NSString *b, NSString *fill)
{
    return [NSString stringWithFormat:@"<!DOCTYPE html><div data-lh-id=\"1\" style=\"padding:8px;%@\">"
                                       "<div data-lh-id=\"2\" style=\"%@\">Hello <b>world</b></div>"
                                       "<svg data-lh-id=\"3\" width=\"40\" height=\"20\" viewBox=\"0 0 40 20\"><circle data-lh-id=\"4\" cx=\"10\" cy=\"10\" r=\"8\" style=\"%@\"/></svg>"
                                       "<span data-lh-id=\"5\">inline</span>"
                                       "<div data-lh-id=\"6\" style=\"transform:rotate(5deg)\"><div data-lh-id=\"7\" style=\"height:10px;background-color:red;\">x</div></div>"
                                       "<p data-lh-id=\"8\">plain</p></div>",
                                       a, b, fill];
}

static NSData *Pixels(LHDocument *document)
{
    CGSize     size  = [document layoutWithMaxWidth:240 preferredWidth:240];
    CGImageRef image = [document copyImageWithMaxWidth:240 rect:CGRectMake(0, 0, 240, ceil(size.height)) scale:2];
    if(!image)
        return [NSData data];
    NSData *data = (__bridge_transfer NSData *)CGDataProviderCopyData(CGImageGetDataProvider(image));
    CGImageRelease(image);
    return data;
}

static LHDocument *Laid(NSString *html)
{
    LHDocument *document = [[LHDocument alloc] initWithHTML:html css:nil];
    [document layoutWithMaxWidth:240 preferredWidth:240];
    return document;
}

- (void)testDeclarationsSkipUndisplayedElements
{
    LHDocument *document = Laid(@"<style>@keyframes k{to{opacity:0}}.a{animation:k 1s}</style>"
                                 "<div data-lh-id=\"1\" class=\"a\">shown</div>"
                                 "<div data-lh-id=\"2\" class=\"a\" hidden>hidden</div>"
                                 "<div style=\"display:none\"><div data-lh-id=\"3\" class=\"a\">inside</div></div>");
    NSDictionary *found = [document declarations:@[@"animation"] byAttribute:Attribute requiringAny:@[@"animation"]];
    XCTAssertNotNil(found[@"1"]);
    XCTAssertNil(found[@"2"]);
    XCTAssertNil(found[@"3"]);
}

- (void)testFontCacheStaysBoundedAndKeepsFontsInUse
{
    LHDocument *kept   = Laid(@"<p style=\"font-size:13.37px;font-family:Georgia\">kept alive</p>");
    NSData     *before = Pixels(kept);
    for(int i = 0; i < 600; i++)
    {
        @autoreleasepool
        {
            Laid([NSString stringWithFormat:@"<p style=\"font-size:%.3fpx\">size %d</p>", 9.0 + i * 0.013, i]);
        }
    }
    Laid(@"<p style=\"font-size:77.7px\">last</p>");
    XCTAssertLessThanOrEqual(LHDocument.cachedFontCount, (NSUInteger)260);
    XCTAssertEqualObjects(Pixels(kept), before);
}

- (void)testSVGHonoursDisplayAndVisibilityAttributes
{
    NSString *(^svg)(NSString *) = ^NSString *(NSString *body) {
        return [NSString stringWithFormat:@"<svg width=\"60\" height=\"20\" viewBox=\"0 0 60 20\">%@</svg>", body];
    };
    NSData *empty = Pixels(Laid(svg(@"")));
    NSData *one   = Pixels(Laid(svg(@"<circle cx=\"10\" cy=\"10\" r=\"6\" fill=\"red\"/>")));
    XCTAssertNotEqualObjects(one, empty);
    XCTAssertEqualObjects(Pixels(Laid(svg(@"<circle cx=\"10\" cy=\"10\" r=\"6\" fill=\"red\" display=\" None \"/>"))), empty);
    XCTAssertEqualObjects(Pixels(Laid(svg(@"<circle cx=\"10\" cy=\"10\" r=\"6\" fill=\"red\" visibility=\"hidden\"/>"))), empty);
    XCTAssertEqualObjects(Pixels(Laid(svg(@"<circle cx=\"10\" cy=\"10\" r=\"6\" fill=\"red\" style=\"visibility:hidden\"/>"))), empty);
    XCTAssertEqualObjects(Pixels(Laid(svg(@"<g display=\"none\"><circle cx=\"10\" cy=\"10\" r=\"6\" fill=\"red\"/></g>"))), empty);
    XCTAssertEqualObjects(Pixels(Laid(svg(@"<g visibility=\"hidden\"><circle cx=\"10\" cy=\"10\" r=\"6\" fill=\"red\"/></g>"))), empty);
    XCTAssertEqualObjects(Pixels(Laid(svg(@"<g visibility=\"hidden\"><circle cx=\"10\" cy=\"10\" r=\"6\" fill=\"red\" visibility=\"visible\"/></g>"))), one);
    XCTAssertEqualObjects(Pixels(Laid(svg(@"<circle cx=\"10\" cy=\"10\" r=\"6\" fill=\"red\" display=\"inline\" visibility=\"visible\"/>"))), one);
}

@end
