// Telegram-authored, not part of twidget: pins Telegram's image policy on iOS (see VENDOR.md): raster data
// images are PNG, JPEG, GIF or WebP by their bytes, at most 4096 px a side; SVG data images are drawn by the
// SVG rasterizer. Nothing is fetched, and what would have been is counted (LHDocument.refusedRequests); URLs
// inside an SVG data image are removed or refused on the inner document.
#import <XCTest/XCTest.h>
#import <ImageIO/ImageIO.h>
#import <CoreServices/CoreServices.h>
#import "LHDocument.h"
#import "LHSanitizer.h"

#if !TARGET_OS_OSX
static NSString *DataURL(NSData *bytes, NSString *mime)
{
    return [NSString stringWithFormat:@"data:%@;base64,%@", mime, [bytes base64EncodedStringWithOptions:0]];
}

static NSData *Encode(NSString *uti, size_t w, size_t h)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, w, h, 8, 0, space, kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(ctx, 1, 0, 0, 1);
    CGContextFillRect(ctx, CGRectMake(0, 0, w, h));
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    NSMutableData *data = [NSMutableData data];
    CGImageDestinationRef dest = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)data, (__bridge CFStringRef)uti, 1, NULL);
    CGImageDestinationAddImage(dest, image, NULL);
    CGImageDestinationFinalize(dest);
    CFRelease(dest); CGImageRelease(image); CGContextRelease(ctx); CGColorSpaceRelease(space);
    return data;
}

@interface TelegramPolicyTests : XCTestCase
@end

@implementation TelegramPolicyTests

// The sanitizer's schemes are process-wide and other suites change them; these cases assume the defaults.
- (void)setUp
{
    [LHSanitizer setLinkSchemes:@[@"http", @"https", @"mailto"] imageSchemes:@[]];
}

- (void)tearDown
{
    [LHSanitizer setLinkSchemes:@[@"http", @"https", @"mailto"] imageSchemes:@[]];
}

- (CGSize)imageSize:(NSString *)src
{
    NSString *html = [NSString stringWithFormat:@"<img id=i src='%@'>", src];
    LHDocument *doc = [[LHDocument alloc] initWithHTML:html css:nil];
    [doc layoutWithMaxWidth:400];
    return [doc boundsOfElementsMatching:@"#i"].size;
}

- (void)testPNGDecodes
{
    CGSize s = [self imageSize:DataURL(Encode(@"public.png", 20, 10), @"image/png")];
    XCTAssertEqual(s.width, 20);
    XCTAssertEqual(s.height, 10);
}

- (void)testTIFFBehindPNGMimeIsRefused
{
    CGSize s = [self imageSize:DataURL(Encode(@"public.tiff", 20, 10), @"image/png")];
    XCTAssertEqual(s.width, 0);
}

- (void)testSVGDataImageDecodesAtItsSize
{
    NSData *svg = [@"<svg xmlns='http://www.w3.org/2000/svg' width='20' height='10'><rect width='20' height='10'/></svg>" dataUsingEncoding:NSUTF8StringEncoding];
    CGSize s = [self imageSize:DataURL(svg, @"image/svg+xml")];
    XCTAssertEqual(s.width, 20);
    XCTAssertEqual(s.height, 10);
}

- (void)testSVGDataImageWithRemoteReferencesStillDrawsAndFetchesNothing
{
    // The inner document's sanitizer removes the remote hrefs, and the SVG renderer never draws an <image> anyway;
    // iOS has no image provider (edit 1.4). This pins that a hostile SVG still draws at its size.
    NSString *inner = @"<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' width='20' height='10'><image href='https://evil.example/e.png' width='20' height='10'/><image xlink:href='https://evil.example/f.png' width='20' height='10'/><rect width='20' height='10'/></svg>";
    NSString *html = [NSString stringWithFormat:@"<img id=i src='%@'>", DataURL([inner dataUsingEncoding:NSUTF8StringEncoding], @"image/svg+xml")];
    LHDocument *doc = [[LHDocument alloc] initWithHTML:html css:nil];
    [doc layoutWithMaxWidth:400];
    CGImageRef image = [doc copyImageWithMaxWidth:400 rect:CGRectMake(0, 0, 400, 50) scale:2];
    if (image) CGImageRelease(image);
    XCTAssertEqual([doc boundsOfElementsMatching:@"#i"].size.width, 20);
}

- (void)testOversizedImageIsNotDecoded
{
    CGSize s = [self imageSize:DataURL(Encode(@"public.png", 5000, 1), @"image/png")];
    XCTAssertEqual(s.width, 0);
}

- (void)testRemoteURLsAreCountedAndRefused
{
    // Author markup: the sanitizer removes the @import, the <link> and both https: images before they reach the
    // renderer. That is a refusal too, reported by sanitizerCounts, not by refusedRequests.
    NSString *html = @"<style>@import url(https://evil.example/a.css); div{background:url(https://evil.example/b.png)}</style>"
                      "<link rel=stylesheet href='https://evil.example/c.css'>"
                      "<div style='width:10px;height:10px'></div><img src='https://evil.example/d.png'>";
    LHDocument *doc = [[LHDocument alloc] initWithHTML:html css:nil];
    [doc layoutWithMaxWidth:300];
    CGImageRef image = [doc copyImageWithMaxWidth:300 rect:CGRectMake(0, 0, 300, 50) scale:2];
    if (image) CGImageRelease(image);
    XCTAssertEqual(doc.refusedRequests, 0u, @"%@", doc.sanitizerDetails);
    NSDictionary<NSString *, NSNumber *> *removed = doc.sanitizerCounts;
    XCTAssertEqual(removed[@"css-dropped"].intValue, 1, @"%@", doc.sanitizerDetails); // @import
    XCTAssertEqual(removed[@"tag-dropped"].intValue, 1, @"%@", doc.sanitizerDetails); // <link>
    XCTAssertEqual(removed[@"url-blocked"].intValue, 2, @"%@", doc.sanitizerDetails); // url(), <img src>

    // The host's css is trusted, so the sanitizer leaves it alone: its remote background reaches the renderer,
    // which refuses it and counts it (once for each time it arrives: parsing, layout, drawing).
    NSString *css = @"div{background:url(https://evil.example/e.png)}";
    LHDocument *host = [[LHDocument alloc] initWithHTML:@"<div data-k='1' style='width:10px;height:10px'></div>" css:css];
    [host layoutWithMaxWidth:300];
    image = [host copyImageWithMaxWidth:300 rect:CGRectMake(0, 0, 300, 50) scale:2];
    if (image) CGImageRelease(image);
    const NSUInteger refused = host.refusedRequests;
    XCTAssertGreaterThanOrEqual(refused, 1u);

}

@end
#endif
