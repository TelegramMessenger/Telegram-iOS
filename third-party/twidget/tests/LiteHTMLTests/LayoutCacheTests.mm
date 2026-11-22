#import <XCTest/XCTest.h>
#import "LHDocument.h"

#include <random>
#include <string>
#include <vector>

@interface LayoutCacheTests : XCTestCase
@end

@implementation LayoutCacheTests

static NSString *const Sheet = @"body{margin:4px;font:12px -apple-system}table{border-collapse:collapse}td{padding:1px 4px;border-bottom:1px solid #ddd}"
                                ".mid{vertical-align:middle}.bot{vertical-align:bottom}.top{vertical-align:top}.two{height:34px}"
                                ".ib{display:inline-block;padding:2px;border:1px solid #888}.fl{float:left;width:18px;height:10px;background:#c00}"
                                ".row{display:flex;gap:4px}.row>span{flex:1 1 auto}.card{padding:3px;border:1px solid #ccc;margin:2px 0}"
                                ".full{width:100%}.hot{color:#c00}.mono{font-family:Menlo}.v{width:90px;text-align:right}";

static NSData *Image(LHDocument *document, CGFloat width)
{
    CGSize     size  = [document layoutWithMaxWidth:width preferredWidth:width];
    CGImageRef image = [document copyImageWithMaxWidth:width rect:CGRectMake(0, 0, width, MAX(1, ceil(size.height))) scale:2];
    if(!image)
        return [NSData data];
    NSData *data = (__bridge_transfer NSData *)CGDataProviderCopyData(CGImageGetDataProvider(image));
    CGImageRelease(image);
    return data;
}

static NSString *Page(const std::string &body)
{
    return [NSString stringWithFormat:@"<!DOCTYPE html><html data-lh-id=\"1\"><head data-lh-id=\"2\"><style data-lh-id=\"3\">%@</style></head>"
                                       "<body data-lh-id=\"4\">%@</body></html>",
                                       Sheet, @(body.c_str())];
}

- (void)expect:(LHDocument *)patched like:(LHDocument *)fresh width:(CGFloat)width label:(NSString *)label
{
    NSData *a = Image(patched, width), *b = Image(fresh, width);
    XCTAssertEqualObjects(patched.layoutSignature, fresh.layoutSignature, @"bounds %@", label);
    XCTAssertEqual(patched.size.height, fresh.size.height, @"height %@", label);
    XCTAssertEqualObjects(a, b, @"pixels %@", label);
}

static long Hits()
{
    return [LHDocument.layoutCacheStats[@"hits"] longValue];
}

static bool CacheFastPathEnabled()
{
    return !getenv("LH_NO_LAYOUT_CACHE") && !getenv("LH_LAYOUT_CACHE_CHECK");
}

- (void)testInitialFlexLayoutReusesMeasurements
{
    std::string body = "<div style='display:flex;flex-direction:column'>";
    for(int row = 0; row < 8; row++)
    {
        body += "<div class='row card'><div style='display:flex;flex:1'><span>Nested heading with wrapping words</span>";
        body += "<div style='display:flex;flex-direction:column'><b>Value</b><span>42</span></div></div>";
        body += "<span style='margin-left:auto'>Details</span></div>";
    }
    body += "</div>";
    LHDocument *document = [[LHDocument alloc] initWithHTML:Page(body) css:nil];
    const long hits = Hits();
    const long mismatches = [LHDocument.layoutCacheStats[@"mismatches"] longValue];
    NSData *initial = Image(document, 320);
    if(CacheFastPathEnabled())
        XCTAssertGreaterThan(Hits(), hits);
    NSString *signature = document.layoutSignature;
    Image(document, 280);
    XCTAssertEqualObjects(initial, Image(document, 320));
    XCTAssertEqualObjects(signature, document.layoutSignature);
    XCTAssertEqual([LHDocument.layoutCacheStats[@"mismatches"] longValue], mismatches);
}

- (void)testClippedFlexItemsMatchAnExplicitZeroMinimum
{
    for(NSString *overflow in @[@"hidden", @"auto", @"scroll"])
    {
        for(NSString *basis in @[@"auto", @"0px", @"35%", @"min-content", @"max-content", @"content"])
        {
            for(NSNumber *width in @[@180, @320])
            {
                NSString *body = [NSString stringWithFormat:
                    @"<div style='display:flex;width:100%%;gap:7px;align-items:baseline'>"
                     "<div data-lh-id='5' style='overflow:%@;flex:1 1 %@;width:140px;padding:3%%;border:2px solid;MINIMUM'>"
                     "<div style='display:flex'><span>A long nested label with wrapping words</span><b>42</b></div>"
                     "<textarea style='width:100%%;height:40px'>Editable contents</textarea></div>"
                     "<div style='flex:none;width:68px'>Adjacent label</div></div>", overflow, basis];
                NSString *automatic = Page([[body stringByReplacingOccurrencesOfString:@"MINIMUM" withString:@""] UTF8String]);
                NSString *explicitMinimum = Page([[body stringByReplacingOccurrencesOfString:@"MINIMUM" withString:@"min-width:0"] UTF8String]);
                LHDocument *a = [[LHDocument alloc] initWithHTML:automatic css:nil];
                LHDocument *b = [[LHDocument alloc] initWithHTML:explicitMinimum css:nil];
                [self expect:a like:b width:width.doubleValue label:[NSString stringWithFormat:@"clipped %@ %@ %@", overflow, basis, width]];
            }
        }
    }
}

static NSData *Raw(LHDocument *document, CGFloat width, size_t *stride)
{
    CGSize     size  = [document layoutWithMaxWidth:width preferredWidth:width];
    CGImageRef image = [document copyImageWithMaxWidth:width rect:CGRectMake(0, 0, width, MAX(1, ceil(size.height))) scale:2];
    NSData    *data  = (__bridge_transfer NSData *)CGDataProviderCopyData(CGImageGetDataProvider(image));
    *stride          = CGImageGetBytesPerRow(image);
    CGImageRelease(image);
    return data;
}

@end
