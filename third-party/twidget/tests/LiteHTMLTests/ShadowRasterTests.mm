#import <XCTest/XCTest.h>
#import "LHDocument.h"

#include <cmath>
#include <initializer_list>

@interface ShadowRasterTests : XCTestCase
@end

@implementation ShadowRasterTests

static NSData *RenderShadow(LHDocument *document, CGRect rect, CGFloat scale, bool flipped = true)
{
    size_t width = (size_t)std::llround(rect.size.width * scale);
    size_t height = (size_t)std::llround(rect.size.height * scale);
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(nullptr, width, height, 8, width * 4, space, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(space);
    if(flipped)
        CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, scale, flipped ? -scale : scale);
    CGContextTranslateCTM(context, -rect.origin.x, -rect.origin.y);
    CGContextSetAllowsFontSmoothing(context, false);
    [document drawInContext:context origin:CGPointZero clip:rect];
    NSData *result = [NSData dataWithBytes:CGBitmapContextGetData(context) length:width * height * 4];
    CGContextRelease(context);
    return result;
}

static LHDocument *ShadowDocument(NSString *style)
{
    NSString *html = [NSString stringWithFormat:@"<style>body{margin:0;width:640px;height:420px}div{position:absolute;left:68px;top:90px;width:504px;height:154px;border-radius:16px;box-shadow:0 10px 30px rgba(0,0,0,.1);%@}</style><div></div>", style];
    LHDocument *document = [[LHDocument alloc] initWithHTML:html css:nil];
    [document layoutWithMaxWidth:640 preferredWidth:640];
    return document;
}

- (void)tearDown
{
    unsetenv("LH_NO_SHADOW_SLICES");
    unsetenv("LH_EXACT_SHADOWS");
    [LHDocument purgeCaches];
    [super tearDown];
}

- (void)testScaledTilesReuseOneShadowRaster
{
    LHDocument *document = ShadowDocument(@"transform:scale(1.02)");
    NSMutableArray<NSData *> *cold = [NSMutableArray array];
    for(int y = 0; y < 3; y++)
        for(int x = 0; x < 5; x++)
        {
            [LHDocument purgeCaches];
            [cold addObject:RenderShadow(document, CGRectMake(x * 128, y * 128, 128, 128), 2)];
        }
    [LHDocument purgeCaches];
    RenderShadow(document, CGRectMake(0, 0, 640, 420), 2);
    NSUInteger single = [LHDocument rasterCacheBytes];
    XCTAssertGreaterThan(single, 0u);
    for(int y = 0; y < 3; y++)
        for(int x = 0; x < 5; x++)
            XCTAssertEqualObjects(cold[y * 5 + x], RenderShadow(document, CGRectMake(x * 128, y * 128, 128, 128), 2));
    XCTAssertEqual([LHDocument rasterCacheBytes], single);
}

- (void)testSlicedShadowsMatchFullRasterThroughLayoutAnimation
{
    NSUInteger maximum = 0, differing = 0, total = 0;
    for(CGFloat scale : {1.0, 1.5, 2.0})
        for(NSString *variant in @[@"", @"border-radius:8px 31px 14px 23px;box-shadow:-7px 6px 11px 4px #843aab", @"box-shadow:12px -9px 18px -3px #1686c8", @"box-shadow:0 1px 2px #1431,0 10px 30px #0002", @"box-shadow:0 6px 16px #0008 inset", @"border-radius:80% 20% / 30% 65%", @"width:236px;box-shadow:32px -24px 17px 7px #ffc028", @"box-shadow:-34px 12px 5px -10px #0cc", @"transform:rotate(3deg);box-shadow:0 6px 16px #0008", @"transform:scale(-1.02,1.013)", @"width:38px;border-radius:50%;box-shadow:0 10px 30px #0004"])
            for(int step = 0; step <= 16; step++)
            {
                NSString *style = [NSString stringWithFormat:@"height:%gpx;transform:translate(%gpx,%gpx) scale(%g);%@", 70.0 + step * 5.25, step * .03125, step * .0625, 1 + step * .00125, variant];
                LHDocument *document = ShadowDocument(style);
                setenv("LH_NO_SHADOW_SLICES", "1", 1);
                NSData *expected = RenderShadow(document, CGRectMake(0, 0, 640, 420), scale);
                unsetenv("LH_NO_SHADOW_SLICES");
                NSData *actual = RenderShadow(document, CGRectMake(0, 0, 640, 420), scale);
                XCTAssertEqual(expected.length, actual.length);
                const uint8_t *a = (const uint8_t *)expected.bytes, *b = (const uint8_t *)actual.bytes;
                NSUInteger frameMaximum = 0;
                for(NSUInteger i = 0; i < actual.length; i++)
                {
                    NSUInteger delta = abs((int)a[i] - (int)b[i]);
                    frameMaximum = MAX(frameMaximum, delta);
                    differing += delta != 0;
                }
                maximum = MAX(maximum, frameMaximum);
                total += actual.length;
                XCTAssertLessThanOrEqual(frameMaximum, 1u, @"scale %g %@", scale, style);
            }
    NSLog(@"SHADOW_PARITY max=%lu differing=%lu total=%lu", (unsigned long)maximum, (unsigned long)differing, (unsigned long)total);
}

- (void)testTallSlicedShadowsMatchFullRaster
{
    NSUInteger maximum = 0, differing = 0, total = 0;
    for(bool flipped : {false, true})
        for(CGFloat scale : {1.0, 1.5, 2.0})
            for(NSString *variant in @[@"", @"border-radius:12px 21px 7px 3px / 9px 24px 11px 18px;box-shadow:-11px 7px 9px 3px #bf528ecc", @"box-shadow:7px -17px 14px #15c8", @"box-shadow:0 3px 12px -2px #ae68", @"transform:scale(1.03,-1.02)"])
                for(int step = 0; step <= 12; step++)
                {
                    NSString *style = [NSString stringWithFormat:@"left:80px;top:50px;width:%gpx;height:%gpx;box-shadow:8px 0 24px #08f7;transform:translate(%gpx,%gpx) scale(%g);%@", 28 + step * 2.25, 210 + step * 5.5, step * .03125, step * .0625, 1 + step * .00125, variant];
                    LHDocument *document = ShadowDocument(style);
                    setenv("LH_NO_SHADOW_SLICES", "1", 1);
                    NSData *expected = RenderShadow(document, CGRectMake(0, 0, 640, 420), scale, flipped);
                    unsetenv("LH_NO_SHADOW_SLICES");
                    NSData *actual = RenderShadow(document, CGRectMake(0, 0, 640, 420), scale, flipped);
                    NSUInteger frameMaximum = 0;
                    const uint8_t *a = (const uint8_t *)expected.bytes, *b = (const uint8_t *)actual.bytes;
                    for(NSUInteger i = 0; i < actual.length; i++)
                    {
                        NSUInteger delta = abs((int)a[i] - (int)b[i]);
                        frameMaximum = MAX(frameMaximum, delta);
                        differing += delta != 0;
                    }
                    maximum = MAX(maximum, frameMaximum);
                    total += actual.length;
                    XCTAssertLessThanOrEqual(frameMaximum, 1u, @"flipped=%d scale=%g %@", flipped, scale, style);
                }
    NSLog(@"TALL_SHADOW_PARITY max=%lu differing=%lu total=%lu", (unsigned long)maximum, (unsigned long)differing, (unsigned long)total);
}

- (void)testFractionalPositionAndShadowChangesKeepDistinctCacheEntries
{
    for(NSString *style in @[@"transform:translate(.125px,.25px) scale(1.02)", @"height:93.5px;transform:scale(1.013)", @"box-shadow:7px 3px 20px 2px #e8349d", @"border-radius:5px 24px 40px 12px"])
    {
        [LHDocument purgeCaches];
        LHDocument *base = ShadowDocument(@"transform:scale(1.02)");
        NSData *before = RenderShadow(base, CGRectMake(0, 0, 640, 420), 2);
        LHDocument *changed = ShadowDocument(style);
        NSData *warm = RenderShadow(changed, CGRectMake(0, 0, 640, 420), 2);
        [LHDocument purgeCaches];
        NSData *cold = RenderShadow(changed, CGRectMake(0, 0, 640, 420), 2);
        XCTAssertNotEqualObjects(before, warm);
        XCTAssertEqualObjects(warm, cold);
    }
}

// Telegram (VENDOR.md edit 65): a blur past 24 device pixels is drawn from one low-resolution raster, laid out on the
// shadow's own ink whatever its sub-pixel position or rotation, so a moving or turning shadow keeps its cache entry.
// ShadowDocument's shadow is 0 10px 30px: 60 device pixels of blur at 2x.
- (void)testABlurredShadowKeepsOneRasterWhenItMoves
{
    [LHDocument purgeCaches];
    RenderShadow(ShadowDocument(@"transform:translate(.3px,.1px)"), CGRectMake(0, 0, 640, 420), 2);
    NSUInteger bytes = [LHDocument rasterCacheBytes];
    XCTAssertGreaterThan(bytes, 0u);
    RenderShadow(ShadowDocument(@"transform:translate(.7px,.45px)"), CGRectMake(0, 0, 640, 420), 2);
    XCTAssertEqual([LHDocument rasterCacheBytes], bytes);
}

- (void)testABlurredShadowKeepsOneRasterWhenItTurns
{
    [LHDocument purgeCaches];
    RenderShadow(ShadowDocument(@"transform:rotate(1deg)"), CGRectMake(0, 0, 640, 420), 2);
    NSUInteger bytes = [LHDocument rasterCacheBytes];
    XCTAssertGreaterThan(bytes, 0u);
    RenderShadow(ShadowDocument(@"transform:translate(.2px,.6px) rotate(-2.5deg)"), CGRectMake(0, 0, 640, 420), 2);
    XCTAssertEqual([LHDocument rasterCacheBytes], bytes);
}

// The low-resolution raster against the exact one (LH_EXACT_SHADOWS: full resolution, as before edit 65), for a still, a
// moved, a turned, an inset, a spread, a rounded and a layered shadow: 2 levels apart at most for the plain one, and up
// to 8 in the gradients of the others, where CoreGraphics' blur is shaped slightly differently at 24 px than at its full
// radius. With the raster clipped to the box, the largest difference was 112.
- (void)testBlurredShadowsStayCloseToTheExactOnes
{
    NSUInteger maximum = 0;
    for(CGFloat scale : {2.0, 3.0})
        for(NSString *variant in @[@"", @"transform:translate(.3px,.7px)", @"transform:rotate(3deg)", @"box-shadow:0 6px 40px #0008 inset;background:#fff", @"box-shadow:0 0 55px 6px #e0267480", @"border-radius:80% 20% / 30% 65%;box-shadow:12px -9px 28px #1686c8", @"background:#751778;box-shadow:0 0 25px #e0267480,0 0 55px #e0267440,0 12px 25px #0008"])
        {
            LHDocument *document = ShadowDocument(variant);
            setenv("LH_EXACT_SHADOWS", "1", 1);
            NSData *expected = RenderShadow(document, CGRectMake(0, 0, 640, 420), scale);
            unsetenv("LH_EXACT_SHADOWS");
            NSData *actual = RenderShadow(document, CGRectMake(0, 0, 640, 420), scale);
            XCTAssertEqual(expected.length, actual.length);
            const uint8_t *a = (const uint8_t *)expected.bytes, *b = (const uint8_t *)actual.bytes;
            NSUInteger frameMaximum = 0;
            for(NSUInteger i = 0; i < actual.length; i++)
                frameMaximum = MAX(frameMaximum, (NSUInteger)abs((int)a[i] - (int)b[i]));
            maximum = MAX(maximum, frameMaximum);
            NSLog(@"DOWNSAMPLED_SHADOW scale %g %@: max %lu", scale, variant, (unsigned long)frameMaximum);
            XCTAssertLessThanOrEqual(frameMaximum, 8u, @"scale %g %@", scale, variant);
        }
    NSLog(@"DOWNSAMPLED_SHADOW_PARITY max=%lu", (unsigned long)maximum);
}

@end
