// Telegram-authored, not part of twidget: pins the iOS twin of LHContainer.mm's ResolveFont (see
// VENDOR.md, "The iOS font resolver"). The resolved font is the CTFontRef the document hands its
// painter for each text run (lhx::TextStyle::nativeFont), so these go through the real cascade.
#import <XCTest/XCTest.h>
#import "LHDocument.h"
#import "LHDocumentPainting.h"

#if !TARGET_OS_OSX
#import <CoreText/CoreText.h>

#include <cmath>
#include <vector>

namespace
{
struct FontRecordingPainter : lhx::Painter
{
    std::vector<CTFontRef> fonts;

    ~FontRecordingPainter() override
    {
        for(CTFontRef font : fonts)
            CFRelease(font);
    }

    void text(const char* text, const lhx::TextStyle& style, const litehtml::web_color& color, const litehtml::position& pos) override
    {
        if(style.nativeFont)
            fonts.push_back((CTFontRef)CFRetain(style.nativeFont));
    }
};

const int kWeightAxis = 0x77676874; // 'wght'

NSString* PostScriptName(CTFontRef font)
{
    return CFBridgingRelease(CTFontCopyPostScriptName(font));
}

NSString* FamilyName(CTFontRef font)
{
    return CFBridgingRelease(CTFontCopyFamilyName(font));
}

NSNumber* WeightVariation(CTFontRef font)
{
    NSDictionary* variation = CFBridgingRelease(CTFontCopyVariation(font));
    return variation[@(kWeightAxis)];
}

// Horizontal shift per unit of height of the ink of a single glyph drawn by the document: the slant
// the reader sees (0 upright, 0.2 for the italic fallback's skew).
CGFloat VisibleSlant(NSString* style)
{
    NSString*   html     = [NSString stringWithFormat:@"<div style=\"margin:0;padding:20px 60px;line-height:1;font-size:100px;%@\">I</div>", style];
    LHDocument* document = [[LHDocument alloc] initWithHTML:html css:@"body{margin:0}"];
    CGSize      size     = [document layoutWithMaxWidth:240 preferredWidth:240];
    CGImageRef  image    = [document copyImageWithMaxWidth:240 rect:CGRectMake(0, 0, 240, std::ceil(size.height)) scale:1];
    if(!image)
        return NAN;
    const size_t         w = CGImageGetWidth(image), h = CGImageGetHeight(image);
    std::vector<uint8_t> pixels(w * h * 4);
    CGColorSpaceRef      space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef         ctx   = CGBitmapContextCreate(pixels.data(), w, h, 8, w * 4, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), image);
    CGContextRelease(ctx);
    CGColorSpaceRelease(space);
    CGImageRelease(image);
    // Ink centre of each row (rows run top down in the bitmap), then a least-squares line x = a + slope * y.
    double sy = 0, sx = 0, syy = 0, sxy = 0;
    int    rows = 0;
    for(size_t y = 0; y < h; y++)
    {
        double weight = 0, moment = 0;
        for(size_t x = 0; x < w; x++)
        {
            const double ink = pixels[(y * w + x) * 4 + 3] / 255.0;
            weight += ink;
            moment += ink * x;
        }
        if(weight < 2)
            continue;
        const double cx = moment / weight;
        sy += y;
        sx += cx;
        syy += double(y) * y;
        sxy += double(y) * cx;
        rows++;
    }
    if(rows < 20)
        return NAN;
    const double slope = (rows * sxy - sy * sx) / (rows * syy - sy * sy);
    return -slope; // y grows downwards: a forward slant moves the ink right going up
}
}

@interface TelegramFontTests : XCTestCase
@end

@implementation TelegramFontTests

- (std::vector<CTFontRef>)fontsFor:(NSString*)style painter:(FontRecordingPainter&)painter
{
    NSString*   html     = [NSString stringWithFormat:@"<p style=\"margin:0;font-size:16px;%@\">Hamburgefonstiv</p>", style];
    LHDocument* document = [[LHDocument alloc] initWithHTML:html css:nil];
    [document paintWithMaxWidth:400 clip:CGRectMake(0, 0, 400, 400) painter:painter];
    return painter.fonts;
}

- (CTFontRef)fontFor:(NSString*)style painter:(FontRecordingPainter&)painter
{
    std::vector<CTFontRef> fonts = [self fontsFor:style painter:painter];
    XCTAssertGreaterThan(fonts.size(), 0u, @"%@ drew no text", style);
    if(fonts.empty())
        return nullptr;
    for(CTFontRef font : fonts)
        XCTAssertEqualObjects(PostScriptName(font), PostScriptName(fonts[0]), @"%@ drew with more than one font", style);
    return fonts[0];
}

- (void)testAnUnknownFamilyFallsThroughToTheNextOne
{
    FontRecordingPainter painter;
    CTFontRef            font = [self fontFor:@"font-family:NoSuchFamily, Georgia" painter:painter];
    XCTAssertEqualObjects(PostScriptName(font), @"Georgia");
}

- (void)testSerifIsTimesNewRoman
{
    // macOS has Times itself; iOS's CoreText resolves the Times family to Times New Roman.
    FontRecordingPainter painter;
    CTFontRef            font = [self fontFor:@"font-family:serif" painter:painter];
    XCTAssertEqualObjects(PostScriptName(font), @"TimesNewRomanPSMT");
}

- (void)testItalicWithoutAnItalicFaceIsSkewed
{
    // American Typewriter has no italic face, so italic is the upright face slanted by 0.2, as on macOS.
    FontRecordingPainter painter;
    CTFontRef            font = [self fontFor:@"font-family:'American Typewriter';font-style:italic" painter:painter];
    XCTAssertEqualObjects(PostScriptName(font), @"AmericanTypewriter");
    const CGAffineTransform matrix = CTFontGetMatrix(font);
    XCTAssertEqualWithAccuracy(matrix.c / matrix.a, 0.2, 0.001);

    const CGFloat upright = VisibleSlant(@"font-family:'American Typewriter'");
    const CGFloat slanted = VisibleSlant(@"font-family:'American Typewriter';font-style:italic");
    XCTAssertEqualWithAccuracy(upright, 0, 0.03);
    XCTAssertEqualWithAccuracy(slanted, 0.2, 0.03);
}

- (void)testSystemFontAtCSS700CarriesWeight700
{
    FontRecordingPainter painter;
    CTFontRef            font = [self fontFor:@"font-family:-apple-system;font-weight:700" painter:painter];
    const bool           bold = (CTFontGetSymbolicTraits(font) & kCTFontTraitBold) != 0;
    XCTAssertTrue(WeightVariation(font).doubleValue == 700 || bold, @"%@ %@", PostScriptName(font), WeightVariation(font));
}

- (void)testSystemFontBoldItalicKeepsItsWeight
{
    // Below iOS 27 the italic of the text-size system font dropped the weight variation, so bold italic
    // drew at regular weight (iOS 26.5, 16 px).
    FontRecordingPainter boldPainter, regularPainter;
    CTFontRef            bold    = [self fontFor:@"font-family:-apple-system;font-weight:700;font-style:italic" painter:boldPainter];
    CTFontRef            regular = [self fontFor:@"font-family:-apple-system;font-weight:400;font-style:italic" painter:regularPainter];
    XCTAssertTrue(CTFontGetSymbolicTraits(bold) & kCTFontTraitItalic);
    XCTAssertTrue(WeightVariation(bold).doubleValue == 700 || (CTFontGetSymbolicTraits(bold) & kCTFontTraitBold), @"%@ %@", PostScriptName(bold),
                  WeightVariation(bold));
    // Visible: the bold italic's stems are heavier, so its glyphs are wider.
    UniChar  character = 'H';
    CGGlyph  glyphs[2];
    CTFontGetGlyphsForCharacters(bold, &character, &glyphs[0], 1);
    CTFontGetGlyphsForCharacters(regular, &character, &glyphs[1], 1);
    const double boldAdvance    = CTFontGetAdvancesForGlyphs(bold, kCTFontOrientationHorizontal, &glyphs[0], nullptr, 1);
    const double regularAdvance = CTFontGetAdvancesForGlyphs(regular, kCTFontOrientationHorizontal, &glyphs[1], nullptr, 1);
    XCTAssertGreaterThan(boldAdvance, regularAdvance * 1.03);
}

- (void)testItalicSemiboldInAFamilyWithoutItalicsKeepsSemibold
{
    // NSFontManager's chain on macOS: no italic member, so the bold preference is dropped and the face
    // nearest the CSS weight is taken (Semibold for 600), then slanted.
    FontRecordingPainter painter;
    CTFontRef            font = [self fontFor:@"font-family:'American Typewriter';font-weight:600;font-style:italic" painter:painter];
    XCTAssertEqualObjects(FamilyName(font), @"American Typewriter");
    XCTAssertEqualObjects(PostScriptName(font), @"AmericanTypewriter-Semibold");
    const CGAffineTransform matrix = CTFontGetMatrix(font);
    XCTAssertEqualWithAccuracy(matrix.c / matrix.a, 0.2, 0.001);

    FontRecordingPainter uprightPainter;
    CTFontRef            upright = [self fontFor:@"font-family:'American Typewriter';font-weight:600" painter:uprightPainter];
    XCTAssertEqualObjects(PostScriptName(upright), @"AmericanTypewriter-Bold");
}

- (void)testTabularNumsGiveEveryDigitOneAdvance
{
    // font-variant-numeric: tabular-nums is the font's monospaced-numbers feature (Telegram's fork change). The
    // system font's digits are proportional by default: "1111" is narrower than "0000" unless tabular.
    NSString* html = @"<style>span{display:inline-block}</style><div style=\"font-family:-apple-system;font-size:16px\">"
                      "<span id=\"p1\">1111</span><br><span id=\"p0\">0000</span><br>"
                      "<span id=\"t1\" style=\"font-variant-numeric:tabular-nums\">1111</span><br>"
                      "<span id=\"t0\" style=\"font-variant-numeric:tabular-nums\">0000</span></div>";
    LHDocument* document = [[LHDocument alloc] initWithHTML:html css:nil];
    [document layoutWithMaxWidth:300];
    const CGFloat p1 = [document boundsOfElementsMatching:@"#p1"].size.width, p0 = [document boundsOfElementsMatching:@"#p0"].size.width;
    const CGFloat t1 = [document boundsOfElementsMatching:@"#t1"].size.width, t0 = [document boundsOfElementsMatching:@"#t0"].size.width;
    XCTAssertGreaterThan(p0, p1 + 4, @"proportional %f %f", p1, p0);
    XCTAssertGreaterThan(t1, 0);
    XCTAssertEqualWithAccuracy(t1, t0, 0.01);

    // The run is drawn with that font: its digits share one advance, and the size and the weight are kept.
    FontRecordingPainter painter;
    CTFontRef            font = [self fontFor:@"font-family:-apple-system;font-weight:700;font-variant-numeric:tabular-nums" painter:painter];
    if(!font)
        return;
    auto lineWidth = [font](NSString* text) {
        NSAttributedString* string = [[NSAttributedString alloc] initWithString:text attributes:@{(__bridge NSString*)kCTFontAttributeName: (__bridge id)font}];
        CTLineRef           line   = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)string);
        const double        width  = CTLineGetTypographicBounds(line, nullptr, nullptr, nullptr);
        CFRelease(line);
        return width;
    };
    XCTAssertEqualWithAccuracy(lineWidth(@"1111"), lineWidth(@"0000"), 0.01);
    XCTAssertEqualWithAccuracy(CTFontGetSize(font), 16, 0.01);
    XCTAssertTrue(WeightVariation(font).doubleValue == 700 || (CTFontGetSymbolicTraits(font) & kCTFontTraitBold), @"%@", WeightVariation(font));
}

@end
#endif
