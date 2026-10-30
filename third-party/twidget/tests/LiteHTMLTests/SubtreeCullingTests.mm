#import <XCTest/XCTest.h>
#import "LHDocument.h"

#include <random>
#include <string>
#include <vector>

@interface SubtreeCullingTests : XCTestCase
@end

@implementation SubtreeCullingTests

static NSArray<NSString *> *CullingSeeds(void)
{
    NSMutableArray<NSString *> *seeds = [NSMutableArray array];
#if TARGET_OS_OSX
    NSString *dir = [[@(__FILE__) stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"../../Examples/chats"];
#else
    NSString *dir = LHTestExamplesChatsDirectory([SubtreeCullingTests class]);
#endif
    for(NSString *name in [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil] sortedArrayUsingSelector:@selector(compare:)])
    {
        NSString *text = [NSString stringWithContentsOfFile:[dir stringByAppendingPathComponent:name] encoding:NSUTF8StringEncoding error:nil];
        if(text.length > 0)
            [seeds addObject:[text substringWithRange:[text rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, MIN(text.length, (NSUInteger)20000))]]];
    }
    NSString *rows = @"";
    for(int r = 0; r < 30; r++)
    {
        rows = [rows stringByAppendingString:@"<tr>"];
        for(int c = 0; c < 5; c++)
            rows = [rows stringByAppendingFormat:@"<td style=\"%@\">%d.%02d</td>", (r + c) % 7 == 0 ? @"box-shadow:0 0 12px #f00;position:relative;top:9px" : @"", r * 5 + c, r];
        rows = [rows stringByAppendingString:@"</tr>"];
    }
    [seeds addObject:[NSString stringWithFormat:@"<style>body{margin:0;font:11px -apple-system} td{padding:2px 4px;border:1px solid #ccc}</style><table style=\"border-collapse:collapse;width:100%%\"><caption style=\"text-shadow:0 30px 4px #00f\">Caption</caption>%@</table>", rows]];
    [seeds addObject:@"<style>body{margin:0} li{padding:2px;line-height:18px}</style><ul><li>one</li><li style=\"list-style:square\">two</li><li style=\"list-style-position:inside\">three</li></ul><ol start=998><li>a</li><li>b</li><li style=\"height:0\">c<br>d</li></ol><ol style=\"margin-left:-30px\"><li>e</li></ol>"];
    [seeds addObject:@"<style>body{margin:0} .c{width:60px;height:40px;margin:10px;background:#0a0}</style>"
                      "<div class=\"c\" style=\"transform:rotate(45deg) translateX(80px)\">rot</div>"
                      "<div class=\"c\" style=\"transform:scale(3);transform-origin:0 0\">big</div>"
                      "<div class=\"c\" style=\"opacity:.5;box-shadow:40px 60px 30px #00f\">shadow</div>"
                      "<div class=\"c\" style=\"outline:6px solid #f0f;outline-offset:20px\">outline</div>"
                      "<div class=\"c\" style=\"position:absolute;top:300px;left:120px;z-index:3\">abs<div style=\"position:absolute;top:-250px;left:-100px;width:30px;height:30px;background:#f00\"></div></div>"
                      "<div class=\"c\" style=\"position:fixed;bottom:5px;right:5px;z-index:-1\">fixed</div>"
                      "<div class=\"c\" style=\"position:relative;top:120px;z-index:-2\">rel</div>"
                      "<div class=\"c\" style=\"float:right;height:200px;background:linear-gradient(#f00,#00f)\">float</div>"
                      "<p style=\"text-shadow:0 0 25px #000,50px 50px #f00\">Shadowed text that wraps across a couple of lines in a narrow column</p>"
                      "<span style=\"display:inline-block;width:80px;height:80px;background:#ff0;transform:translateY(-60px)\">ib</span>"
                      "<span style=\"background:#0ff;border:2px solid #000;padding:6px\">inline box text that wraps around inline box text that wraps</span>"
                      "<div style=\"overflow:hidden;height:50px;border-radius:12px\"><div style=\"height:200px;background:radial-gradient(#f00,#00f)\">clipped</div></div>"
                      "<div style=\"overflow:auto;height:60px\"><div style=\"height:300px;background:#ccc\">scroll</div></div>"
                      "<svg width=\"120\" height=\"60\" viewBox=\"0 0 10 5\"><circle cx=\"5\" cy=\"2.5\" r=\"9\" fill=\"#f80\"/></svg>"
                      "<img style=\"width:40px;height:40px;border:3px solid red\" src=\"missing.png\">"
                      "<input type=\"range\" value=\"30\"><input type=\"color\" value=\"#ff0000\">"
                      "<div style=\"backface-visibility:hidden;transform:rotateY(180deg)\">hidden back</div>"
                      "<div style=\"margin-top:-40px;height:20px;background:#00f;position:relative;left:-30px\"></div>"
                      "<div style=\"transform:translateX(3px)\"><p style=\"text-shadow:0 70px 3px #f00,0 -50px #0f0\">shadow in a group</p></div>"
                      "<table><tr style=\"background:#eef;box-shadow:0 0 30px #f00\"><td>row</td><td>bg</td></tr></table>"];
    return seeds;
}

static NSData *Render(LHDocument *document, CGRect clip, CGFloat scale, CGFloat margin, BOOL cull)
{
    document.subtreeCulling = cull;
    size_t pw = (size_t)std::ceil(clip.size.width * scale), ph = (size_t)std::ceil(clip.size.height * scale);
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef    ctx   = CGBitmapContextCreate(nullptr, pw, ph, 8, pw * 4, space, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(space);
    CGContextTranslateCTM(ctx, 0, ph);
    CGContextScaleCTM(ctx, scale, -scale);
    CGContextTranslateCTM(ctx, -clip.origin.x, -clip.origin.y);
    CGContextSetAllowsFontSmoothing(ctx, false);
    CGContextSetShouldAntialias(ctx, true);
    CGContextClipToRect(ctx, clip);
    [document drawInContext:ctx origin:CGPointZero clip:CGRectInset(clip, -margin, -margin)];
    NSData *data = [NSData dataWithBytes:CGBitmapContextGetData(ctx) length:pw * ph * 4];
    CGContextRelease(ctx);
    return data;
}

static void CheckClips(XCTestCase *test, LHDocument *document, CGSize size, std::mt19937 &rng, int count, NSString *label, int *painted)
{
    for(int i = 0; i < count; i++)
    {
        CGFloat w      = 4 + rng() % 160;
        CGFloat h      = 4 + rng() % 160;
        CGFloat x      = (CGFloat)(int)(rng() % (int)std::max<CGFloat>(1, size.width + 40)) - 20;
        CGFloat y      = (CGFloat)(int)(rng() % (int)std::max<CGFloat>(1, size.height + 40)) - 20;
        CGFloat scale  = rng() % 2 ? 2 : 1;
        CGFloat margin = rng() % 2 ? 32 : 0;
        CGRect  clip   = CGRectMake(x, y, w, h);
        NSData *a      = Render(document, clip, scale, margin, NO);
        NSData *b      = Render(document, clip, scale, margin, YES);
        XCTAssertEqualObjects(a, b, @"%@ clip %@ scale %g margin %g", label, NSStringFromRect(NSRectFromCGRect(clip)), scale, margin);
        const uint8_t *p = (const uint8_t *)a.bytes;
        for(NSUInteger k = 3; k < a.length; k += 4)
        {
            if(p[k])
            {
                (*painted)++;
                break;
            }
        }
    }
}

- (void)testClippedRasterDoesNotPopulateCache
{
    LHDocument *document = [[LHDocument alloc] initWithHTML:@"<style>body{margin:0;width:280px;height:280px}div{position:absolute;left:180px;top:180px;width:40px;height:40px;box-shadow:0 0 12px red}</style><div></div>" css:nil];
    [document layoutWithMaxWidth:280 preferredWidth:280];
    [LHDocument purgeCaches];
    NSData *clipped = Render(document, CGRectMake(0, 0, 24, 24), 2, 300, NO);
    XCTAssertEqualObjects(clipped, [NSMutableData dataWithLength:clipped.length]);
    XCTAssertEqual([LHDocument rasterCacheBytes], 0u);
    NSData *visible = Render(document, CGRectMake(160, 160, 80, 80), 2, 300, NO);
    XCTAssertNotEqualObjects(visible, [NSMutableData dataWithLength:visible.length]);
    XCTAssertGreaterThan([LHDocument rasterCacheBytes], 0u);
}

- (void)testCulledDrawsMatchFullTraversal
{
    std::mt19937 rng(20261012);
    NSArray<NSString *> *seeds   = CullingSeeds();
    int                  painted = 0;
    for(NSString *html in seeds)
    {
        for(CGFloat width : {120.0, 333.0})
        {
            LHDocument *document = [[LHDocument alloc] initWithHTML:html css:nil];
            CGSize      size     = [document layoutWithMaxWidth:width];
            CheckClips(self, document, size, rng, 24, [NSString stringWithFormat:@"seed %lu width %g", (unsigned long)[seeds indexOfObject:html], width], &painted);
        }
    }
    XCTAssertGreaterThan(painted, 100);
}

- (void)testCulledDrawsMatchAfterMutations
{
    std::mt19937 rng(7);
    NSArray<NSString *> *seeds = CullingSeeds();
    const std::vector<std::string> inserts = {"<div style=\"position:absolute;top:-20px\">x</div>", "<b>", "</div>", "<li>", "<td>", "<span style=\"transform:rotate(20deg);display:inline-block\">r</span>",
                                              "<div style=\"box-shadow:0 0 40px red\">s</div>", "<table><tr><td>t</td></tr></table>", "<p style=\"position:fixed;top:0\">f</p>", "<svg width=9 height=9><rect width=99 height=99/></svg>"};
    int painted = 0;
    for(int n = 0; n < 40; n++)
    {
        @autoreleasepool
        {
            std::string text = [seeds[rng() % seeds.count] UTF8String] ?: "";
            for(int e = 0; e < 1 + (int)(rng() % 12) && !text.empty(); e++)
            {
                size_t at = rng() % text.size();
                if(rng() % 3)
                    text.insert(at, inserts[rng() % inserts.size()]);
                else
                    text.erase(at, 1 + rng() % 40);
            }
            NSString *html = [[NSString alloc] initWithBytes:text.data() length:text.size() encoding:NSUTF8StringEncoding] ?: @"";
            LHDocument *document = [[LHDocument alloc] initWithHTML:html css:nil];
            CGSize      size     = [document layoutWithMaxWidth:(CGFloat)(80 + rng() % 400)];
            CheckClips(self, document, size, rng, 8, [NSString stringWithFormat:@"mutation %d", n], &painted);
        }
    }
    XCTAssertGreaterThan(painted, 40);
}

@end
