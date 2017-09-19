// TTTAttributedLabel.m
//
// Copyright (c) 2011 Mattt Thompson (http://mattt.me)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_FEEDBACK

#import "BITAttributedLabel.h"

#import <QuartzCore/QuartzCore.h>
#import <Availability.h>
#import <objc/runtime.h>

#define kBITLineBreakWordWrapTextWidthScalingFactor (M_PI / M_E)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wunused-variable"
#pragma clang diagnostic ignored "-Wunused-parameter"
#pragma clang diagnostic ignored "-Wcast-qual"
#pragma clang diagnostic ignored "-Wdouble-promotion"
#pragma clang diagnostic ignored "-Wdirect-ivar-access"
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"
#pragma clang diagnostic ignored "-Wvla"

static CGFloat const BITFLOAT_MAX = 100000;

NSString * const kBITStrikeOutAttributeName = @"BITStrikeOutAttribute";
NSString * const kBITBackgroundFillColorAttributeName = @"BITBackgroundFillColor";
NSString * const kBITBackgroundFillPaddingAttributeName = @"BITBackgroundFillPadding";
NSString * const kBITBackgroundStrokeColorAttributeName = @"BITBackgroundStrokeColor";
NSString * const kBITBackgroundLineWidthAttributeName = @"BITBackgroundLineWidth";
NSString * const kBITBackgroundCornerRadiusAttributeName = @"BITBackgroundCornerRadius";

static const NSTextAlignment BITTextAlignmentLeft = NSTextAlignmentLeft;
static const NSTextAlignment BITTextAlignmentCenter = NSTextAlignmentCenter;
static const NSTextAlignment BITTextAlignmentRight = NSTextAlignmentRight;
static const NSTextAlignment BITTextAlignmentJustified = NSTextAlignmentJustified;
static const NSTextAlignment BITTextAlignmentNatural = NSTextAlignmentNatural;

static const NSLineBreakMode BITLineBreakByWordWrapping = NSLineBreakByWordWrapping;
static const NSLineBreakMode BITLineBreakByCharWrapping = NSLineBreakByCharWrapping;
static const NSLineBreakMode BITLineBreakByClipping = NSLineBreakByClipping;
static const NSLineBreakMode BITLineBreakByTruncatingHead = NSLineBreakByTruncatingHead;
static const NSLineBreakMode BITLineBreakByTruncatingMiddle = NSLineBreakByTruncatingMiddle;
static const NSLineBreakMode BITLineBreakByTruncatingTail = NSLineBreakByTruncatingTail;

typedef NSTextAlignment BITTextAlignment;
typedef NSLineBreakMode BITLineBreakMode;


static inline CGFLOAT_TYPE CGFloat_ceil(CGFLOAT_TYPE cgfloat) {
#if CGFLOAT_IS_DOUBLE
    return ceil(cgfloat);
#else
    return ceilf(cgfloat);
#endif
}

static inline CGFLOAT_TYPE CGFloat_floor(CGFLOAT_TYPE cgfloat) {
#if CGFLOAT_IS_DOUBLE
    return floor(cgfloat);
#else
    return floorf(cgfloat);
#endif
}

static inline CGFLOAT_TYPE CGFloat_round(CGFLOAT_TYPE cgfloat) {
#if CGFLOAT_IS_DOUBLE
    return round(cgfloat);
#else
    return roundf(cgfloat);
#endif
}

static inline CGFLOAT_TYPE CGFloat_sqrt(CGFLOAT_TYPE cgfloat) {
#if CGFLOAT_IS_DOUBLE
    return sqrt(cgfloat);
#else
    return sqrtf(cgfloat);
#endif
}

static inline CGFloat BITFlushFactorForTextAlignment(NSTextAlignment textAlignment) {
    switch (textAlignment) {
        case BITTextAlignmentCenter:
            return 0.5f;
        case BITTextAlignmentRight:
            return 1.0f;
        case BITTextAlignmentLeft:
        default:
            return 0.0f;
    }
}

static inline NSDictionary * NSAttributedStringAttributesFromLabel(BITAttributedLabel *label) {
    NSMutableDictionary *mutableAttributes = [NSMutableDictionary dictionary];

    [mutableAttributes setObject:label.font forKey:(NSString *)kCTFontAttributeName];
    [mutableAttributes setObject:label.textColor forKey:(NSString *)kCTForegroundColorAttributeName];
    [mutableAttributes setObject:@(label.kern) forKey:(NSString *)kCTKernAttributeName];

    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = label.textAlignment;
    paragraphStyle.lineSpacing = label.lineSpacing;
    paragraphStyle.minimumLineHeight = label.minimumLineHeight > 0 ? label.minimumLineHeight : label.font.lineHeight * label.lineHeightMultiple;
    paragraphStyle.maximumLineHeight = label.maximumLineHeight > 0 ? label.maximumLineHeight : label.font.lineHeight * label.lineHeightMultiple;
    paragraphStyle.lineHeightMultiple = label.lineHeightMultiple;
    paragraphStyle.firstLineHeadIndent = label.firstLineIndent;

    if (label.numberOfLines == 1) {
        paragraphStyle.lineBreakMode = label.lineBreakMode;
    } else {
        paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    }

    [mutableAttributes setObject:paragraphStyle forKey:(NSString *)kCTParagraphStyleAttributeName];

    return [NSDictionary dictionaryWithDictionary:mutableAttributes];
}

static inline CGColorRef CGColorRefFromColor(id color);
static inline NSDictionary * convertNSAttributedStringAttributesToCTAttributes(NSDictionary *attributes);

static inline NSAttributedString * NSAttributedStringByScalingFontSize(NSAttributedString *attributedString, CGFloat scale) {
    NSMutableAttributedString *mutableAttributedString = [attributedString mutableCopy];
    [mutableAttributedString enumerateAttribute:(NSString *)kCTFontAttributeName inRange:NSMakeRange(0, [mutableAttributedString length]) options:0 usingBlock:^(id value, NSRange range, BOOL * __unused stop) {
        UIFont *font = (UIFont *)value;
        if (font) {
            NSString *fontName;
            CGFloat pointSize;

            if ([font isKindOfClass:[UIFont class]]) {
                fontName = font.fontName;
                pointSize = font.pointSize;
            } else {
                fontName = (NSString *)CFBridgingRelease(CTFontCopyName((__bridge CTFontRef)font, kCTFontPostScriptNameKey));
                pointSize = CTFontGetSize((__bridge CTFontRef)font);
            }

            [mutableAttributedString removeAttribute:(NSString *)kCTFontAttributeName range:range];
            CTFontRef fontRef = CTFontCreateWithName((__bridge CFStringRef)fontName, CGFloat_floor(pointSize * scale), NULL);
            [mutableAttributedString addAttribute:(NSString *)kCTFontAttributeName value:(__bridge id)fontRef range:range];
            CFRelease(fontRef);
        }
    }];

    return mutableAttributedString;
}

static inline NSAttributedString * NSAttributedStringBySettingColorFromContext(NSAttributedString *attributedString, UIColor *color) {
    if (!color) {
        return attributedString;
    }

    NSMutableAttributedString *mutableAttributedString = [attributedString mutableCopy];
    [mutableAttributedString enumerateAttribute:(NSString *)kCTForegroundColorFromContextAttributeName inRange:NSMakeRange(0, [mutableAttributedString length]) options:0 usingBlock:^(id value, NSRange range, __unused BOOL *stop) {
        BOOL usesColorFromContext = (BOOL)value;
        if (usesColorFromContext) {
            [mutableAttributedString setAttributes:[NSDictionary dictionaryWithObject:color forKey:(NSString *)kCTForegroundColorAttributeName] range:range];
            [mutableAttributedString removeAttribute:(NSString *)kCTForegroundColorFromContextAttributeName range:range];
        }
    }];

    return mutableAttributedString;
}

static inline CGSize CTFramesetterSuggestFrameSizeForAttributedStringWithConstraints(CTFramesetterRef framesetter, NSAttributedString *attributedString, CGSize size, NSUInteger numberOfLines) {
    CFRange rangeToSize = CFRangeMake(0, (CFIndex)[attributedString length]);
    CGSize constraints = CGSizeMake(size.width, BITFLOAT_MAX);

    if (numberOfLines == 1) {
        // If there is one line, the size that fits is the full width of the line
        constraints = CGSizeMake(BITFLOAT_MAX, BITFLOAT_MAX);
    } else if (numberOfLines > 0) {
        // If the line count of the label more than 1, limit the range to size to the number of lines that have been set
        CGMutablePathRef path = CGPathCreateMutable();
        CGPathAddRect(path, NULL, CGRectMake(0.0f, 0.0f, constraints.width, BITFLOAT_MAX));
        CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, NULL);
        CFArrayRef lines = CTFrameGetLines(frame);

        if (CFArrayGetCount(lines) > 0) {
            NSInteger lastVisibleLineIndex = MIN((CFIndex)numberOfLines, CFArrayGetCount(lines)) - 1;
            CTLineRef lastVisibleLine = CFArrayGetValueAtIndex(lines, lastVisibleLineIndex);

            CFRange rangeToLayout = CTLineGetStringRange(lastVisibleLine);
            rangeToSize = CFRangeMake(0, rangeToLayout.location + rangeToLayout.length);
        }

        CFRelease(frame);
        CGPathRelease(path);
    }

    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, rangeToSize, NULL, constraints, NULL);

    return CGSizeMake(CGFloat_ceil(suggestedSize.width), CGFloat_ceil(suggestedSize.height));
}

@interface BITAccessibilityElement : UIAccessibilityElement
@property (nonatomic, weak) UIView *superview;
@property (nonatomic, assign) CGRect boundingRect;
@end

@implementation BITAccessibilityElement

- (CGRect)accessibilityFrame {
    return UIAccessibilityConvertFrameToScreenCoordinates(self.boundingRect, self.superview);
}

@end

@interface BITAttributedLabel ()
@property (readwrite, nonatomic, copy) NSAttributedString *inactiveAttributedText;
@property (readwrite, nonatomic, copy) NSAttributedString *renderedAttributedText;
@property (readwrite, atomic, strong) NSDataDetector *dataDetector;
@property (readwrite, nonatomic, strong) NSArray *linkModels;
@property (readwrite, nonatomic, strong) BITAttributedLabelLink *activeLink;
@property (readwrite, nonatomic, strong) NSArray *accessibilityElements;

- (void) longPressGestureDidFire:(UILongPressGestureRecognizer *)sender;
@end

@implementation BITAttributedLabel {
@private
    BOOL _needsFramesetter;
    CTFramesetterRef _framesetter;
    CTFramesetterRef _highlightFramesetter;
}

@dynamic text;
@synthesize attributedText = _attributedText;

#ifndef kCFCoreFoundationVersionNumber_iOS_7_0
#define kCFCoreFoundationVersionNumber_iOS_7_0 847.2
#endif

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0) {
            Class class = [self class];
            Class superclass = class_getSuperclass(class);

            NSArray *strings = @[
                                 NSStringFromSelector(@selector(isAccessibilityElement)),
                                 NSStringFromSelector(@selector(accessibilityElementCount)),
                                 NSStringFromSelector(@selector(accessibilityElementAtIndex:)),
                                 NSStringFromSelector(@selector(indexOfAccessibilityElement:)),
                                 ];

            for (NSString *string in strings) {
                SEL selector = NSSelectorFromString(string);
                IMP superImplementation = class_getMethodImplementation(superclass, selector);
                Method method = class_getInstanceMethod(class, selector);
                const char *types = method_getTypeEncoding(method);
                class_replaceMethod(class, selector, superImplementation, types);
            }
        }
    });
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    [self commonInit];

    return self;
}

- (void)commonInit {
    self.userInteractionEnabled = YES;
#if !TARGET_OS_TV
    self.multipleTouchEnabled = NO;
#endif

    self.textInsets = UIEdgeInsetsZero;
    self.lineHeightMultiple = 1.0f;

    self.linkModels = [NSArray array];

    self.linkBackgroundEdgeInset = UIEdgeInsetsMake(0.0f, -1.0f, 0.0f, -1.0f);

    NSMutableDictionary *mutableLinkAttributes = [NSMutableDictionary dictionary];
    [mutableLinkAttributes setObject:[NSNumber numberWithBool:YES] forKey:(NSString *)kCTUnderlineStyleAttributeName];

    NSMutableDictionary *mutableActiveLinkAttributes = [NSMutableDictionary dictionary];
    [mutableActiveLinkAttributes setObject:[NSNumber numberWithBool:NO] forKey:(NSString *)kCTUnderlineStyleAttributeName];

    NSMutableDictionary *mutableInactiveLinkAttributes = [NSMutableDictionary dictionary];
    [mutableInactiveLinkAttributes setObject:[NSNumber numberWithBool:NO] forKey:(NSString *)kCTUnderlineStyleAttributeName];

    if ([NSMutableParagraphStyle class]) {
        [mutableLinkAttributes setObject:[UIColor blueColor] forKey:(NSString *)kCTForegroundColorAttributeName];
        [mutableActiveLinkAttributes setObject:[UIColor redColor] forKey:(NSString *)kCTForegroundColorAttributeName];
        [mutableInactiveLinkAttributes setObject:[UIColor grayColor] forKey:(NSString *)kCTForegroundColorAttributeName];
    } else {
        [mutableLinkAttributes setObject:(__bridge id)[[UIColor blueColor] CGColor] forKey:(NSString *)kCTForegroundColorAttributeName];
        [mutableActiveLinkAttributes setObject:(__bridge id)[[UIColor redColor] CGColor] forKey:(NSString *)kCTForegroundColorAttributeName];
        [mutableInactiveLinkAttributes setObject:(__bridge id)[[UIColor grayColor] CGColor] forKey:(NSString *)kCTForegroundColorAttributeName];
    }

    self.linkAttributes = [NSDictionary dictionaryWithDictionary:mutableLinkAttributes];
    self.activeLinkAttributes = [NSDictionary dictionaryWithDictionary:mutableActiveLinkAttributes];
    self.inactiveLinkAttributes = [NSDictionary dictionaryWithDictionary:mutableInactiveLinkAttributes];
    _extendsLinkTouchArea = NO;
    _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                                action:@selector(longPressGestureDidFire:)];
    self.longPressGestureRecognizer.delegate = self;
    [self addGestureRecognizer:self.longPressGestureRecognizer];
}

- (void)dealloc {
    if (_framesetter) {
        CFRelease(_framesetter);
    }

    if (_highlightFramesetter) {
        CFRelease(_highlightFramesetter);
    }

    if (_longPressGestureRecognizer) {
        [self removeGestureRecognizer:_longPressGestureRecognizer];
    }
}

#pragma mark -

+ (CGSize)sizeThatFitsAttributedString:(NSAttributedString *)attributedString
                       withConstraints:(CGSize)size
                limitedToNumberOfLines:(NSUInteger)numberOfLines
{
    if (!attributedString || attributedString.length == 0) {
        return CGSizeZero;
    }

    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)attributedString);

    CGSize calculatedSize = CTFramesetterSuggestFrameSizeForAttributedStringWithConstraints(framesetter, attributedString, size, numberOfLines);

    CFRelease(framesetter);

    return calculatedSize;
}

#pragma mark -

- (void)setAttributedText:(NSAttributedString *)text {
    if ([text isEqualToAttributedString:_attributedText]) {
        return;
    }

    _attributedText = [text copy];

    [self setNeedsFramesetter];
    [self setNeedsDisplay];

    if ([self respondsToSelector:@selector(invalidateIntrinsicContentSize)]) {
        [self invalidateIntrinsicContentSize];
    }

    [super setText:[self.attributedText string]];
}

- (NSAttributedString *)renderedAttributedText {
    if (!_renderedAttributedText) {
        NSMutableAttributedString *fullString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];

        if (self.attributedTruncationToken) {
            [fullString appendAttributedString:self.attributedTruncationToken];
        }

        NSAttributedString *string = [[NSAttributedString alloc] initWithAttributedString:fullString];
        self.renderedAttributedText = NSAttributedStringBySettingColorFromContext(string, self.textColor);
    }

    return _renderedAttributedText;
}

- (NSArray *) links {
    return [_linkModels valueForKey:@"result"];
}

- (void)setLinkModels:(NSArray *)linkModels {
    _linkModels = linkModels;

    self.accessibilityElements = nil;
}

- (void)setNeedsFramesetter {
    // Reset the rendered attributed text so it has a chance to regenerate
    self.renderedAttributedText = nil;

    _needsFramesetter = YES;
}

- (CTFramesetterRef)framesetter {
    if (_needsFramesetter) {
        @synchronized(self) {
            CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)self.renderedAttributedText);
            [self setFramesetter:framesetter];
            [self setHighlightFramesetter:nil];
            _needsFramesetter = NO;

            if (framesetter) {
                CFRelease(framesetter);
            }
        }
    }

    return _framesetter;
}

- (void)setFramesetter:(CTFramesetterRef)framesetter {
    if (framesetter) {
        CFRetain(framesetter);
    }

    if (_framesetter) {
        CFRelease(_framesetter);
    }

    _framesetter = framesetter;
}

- (CTFramesetterRef)highlightFramesetter {
    return _highlightFramesetter;
}

- (void)setHighlightFramesetter:(CTFramesetterRef)highlightFramesetter {
    if (highlightFramesetter) {
        CFRetain(highlightFramesetter);
    }

    if (_highlightFramesetter) {
        CFRelease(_highlightFramesetter);
    }

    _highlightFramesetter = highlightFramesetter;
}

#pragma mark -

- (void)setEnabledTextCheckingTypes:(NSTextCheckingTypes)enabledTextCheckingTypes {
    if (self.enabledTextCheckingTypes == enabledTextCheckingTypes) {
        return;
    }

    _enabledTextCheckingTypes = enabledTextCheckingTypes;

    // one detector instance per type (combination), fast reuse e.g. in cells
    static NSMutableDictionary *dataDetectorsByType = nil;

    if (!dataDetectorsByType) {
        dataDetectorsByType = [NSMutableDictionary dictionary];
    }

    if (enabledTextCheckingTypes) {
        if (![dataDetectorsByType objectForKey:@(enabledTextCheckingTypes)]) {
            NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:enabledTextCheckingTypes
                                                                       error:nil];
            if (detector) {
                [dataDetectorsByType setObject:detector forKey:@(enabledTextCheckingTypes)];
            }
        }
        self.dataDetector = [dataDetectorsByType objectForKey:@(enabledTextCheckingTypes)];
    } else {
        self.dataDetector = nil;
    }
}

- (void)addLink:(BITAttributedLabelLink *)link {
    [self addLinks:@[link]];
}

- (void)addLinks:(NSArray *)links {
    NSMutableArray *mutableLinkModels = [NSMutableArray arrayWithArray:self.linkModels];

    NSMutableAttributedString *mutableAttributedString = [self.attributedText mutableCopy];

    for (BITAttributedLabelLink *link in links) {
        if (link.attributes) {
            [mutableAttributedString addAttributes:link.attributes range:link.result.range];
        }
    }

    self.attributedText = mutableAttributedString;
    [self setNeedsDisplay];

    [mutableLinkModels addObjectsFromArray:links];

    self.linkModels = [NSArray arrayWithArray:mutableLinkModels];
}

- (BITAttributedLabelLink *)addLinkWithTextCheckingResult:(NSTextCheckingResult *)result
                                               attributes:(NSDictionary *)attributes
{
    return [self addLinksWithTextCheckingResults:@[result] attributes:attributes].firstObject;
}

- (NSArray *)addLinksWithTextCheckingResults:(NSArray *)results
                                  attributes:(NSDictionary *)attributes
{
    NSMutableArray *links = [NSMutableArray array];

    for (NSTextCheckingResult *result in results) {
        NSDictionary *activeAttributes = attributes ? self.activeLinkAttributes : nil;
        NSDictionary *inactiveAttributes = attributes ? self.inactiveLinkAttributes : nil;

        BITAttributedLabelLink *link = [[BITAttributedLabelLink alloc] initWithAttributes:attributes
                                                                         activeAttributes:activeAttributes
                                                                       inactiveAttributes:inactiveAttributes
                                                                       textCheckingResult:result];

        [links addObject:link];
    }

    [self addLinks:links];

    return links;
}

- (BITAttributedLabelLink *)addLinkWithTextCheckingResult:(NSTextCheckingResult *)result {
    return [self addLinkWithTextCheckingResult:result attributes:self.linkAttributes];
}

- (BITAttributedLabelLink *)addLinkToURL:(NSURL *)url
                               withRange:(NSRange)range
{
    return [self addLinkWithTextCheckingResult:[NSTextCheckingResult linkCheckingResultWithRange:range URL:url]];
}

- (BITAttributedLabelLink *)addLinkToAddress:(NSDictionary *)addressComponents
                                   withRange:(NSRange)range
{
    return [self addLinkWithTextCheckingResult:[NSTextCheckingResult addressCheckingResultWithRange:range components:addressComponents]];
}

- (BITAttributedLabelLink *)addLinkToPhoneNumber:(NSString *)phoneNumber
                                       withRange:(NSRange)range
{
    return [self addLinkWithTextCheckingResult:[NSTextCheckingResult phoneNumberCheckingResultWithRange:range phoneNumber:phoneNumber]];
}

- (BITAttributedLabelLink *)addLinkToDate:(NSDate *)date
                                withRange:(NSRange)range
{
    return [self addLinkWithTextCheckingResult:[NSTextCheckingResult dateCheckingResultWithRange:range date:date]];
}

- (BITAttributedLabelLink *)addLinkToDate:(NSDate *)date
                                 timeZone:(NSTimeZone *)timeZone
                                 duration:(NSTimeInterval)duration
                                withRange:(NSRange)range
{
    return [self addLinkWithTextCheckingResult:[NSTextCheckingResult dateCheckingResultWithRange:range date:date timeZone:timeZone duration:duration]];
}

- (BITAttributedLabelLink *)addLinkToTransitInformation:(NSDictionary *)components
                                              withRange:(NSRange)range
{
    return [self addLinkWithTextCheckingResult:[NSTextCheckingResult transitInformationCheckingResultWithRange:range components:components]];
}

#pragma mark -

- (BOOL)containslinkAtPoint:(CGPoint)point {
    return [self linkAtPoint:point] != nil;
}

- (BITAttributedLabelLink *)linkAtPoint:(CGPoint)point {

    // Stop quickly if none of the points to be tested are in the bounds.
    if (!CGRectContainsPoint(CGRectInset(self.bounds, -15.f, -15.f), point) || self.links.count == 0) {
        return nil;
    }

    BITAttributedLabelLink *result = [self linkAtCharacterIndex:[self characterIndexAtPoint:point]];

    if (!result && self.extendsLinkTouchArea) {
        result = [self linkAtRadius:2.5f aroundPoint:point]
        ?: [self linkAtRadius:5.f aroundPoint:point]
        ?: [self linkAtRadius:7.5f aroundPoint:point]
        ?: [self linkAtRadius:12.5f aroundPoint:point]
        ?: [self linkAtRadius:15.f aroundPoint:point];
    }

    return result;
}

- (BITAttributedLabelLink *)linkAtRadius:(const CGFloat)radius aroundPoint:(CGPoint)point {
    const CGFloat diagonal = CGFloat_sqrt(2 * radius * radius);
    const CGPoint deltas[] = {
        CGPointMake(0, -radius), CGPointMake(0, radius), // Above and below
        CGPointMake(-radius, 0), CGPointMake(radius, 0), // Beside
        CGPointMake(-diagonal, -diagonal), CGPointMake(-diagonal, diagonal),
        CGPointMake(diagonal, diagonal), CGPointMake(diagonal, -diagonal) // Diagonal
    };
    const size_t count = sizeof(deltas) / sizeof(CGPoint);

    BITAttributedLabelLink *link = nil;

    for (NSUInteger i = 0; i < count && link.result == nil; i ++) {
        CGPoint currentPoint = CGPointMake(point.x + deltas[i].x, point.y + deltas[i].y);
        link = [self linkAtCharacterIndex:[self characterIndexAtPoint:currentPoint]];
    }

    return link;
}

- (BITAttributedLabelLink *)linkAtCharacterIndex:(CFIndex)idx {
    // Do not enumerate if the index is outside of the bounds of the text.
    if (!NSLocationInRange((NSUInteger)idx, NSMakeRange(0, self.attributedText.length))) {
        return nil;
    }

    NSEnumerator *enumerator = [self.linkModels reverseObjectEnumerator];
    BITAttributedLabelLink *link = nil;
    while ((link = [enumerator nextObject])) {
        if (NSLocationInRange((NSUInteger)idx, link.result.range)) {
            return link;
        }
    }

    return nil;
}

- (CFIndex)characterIndexAtPoint:(CGPoint)p {
    if (!CGRectContainsPoint(self.bounds, p)) {
        return NSNotFound;
    }

    CGRect textRect = [self textRectForBounds:self.bounds limitedToNumberOfLines:self.numberOfLines];
    if (!CGRectContainsPoint(textRect, p)) {
        return NSNotFound;
    }

    // Offset tap coordinates by textRect origin to make them relative to the origin of frame
    p = CGPointMake(p.x - textRect.origin.x, p.y - textRect.origin.y);
    // Convert tap coordinates (start at top left) to CT coordinates (start at bottom left)
    p = CGPointMake(p.x, textRect.size.height - p.y);

    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, textRect);
    CTFrameRef frame = CTFramesetterCreateFrame([self framesetter], CFRangeMake(0, (CFIndex)[self.attributedText length]), path, NULL);
    if (frame == NULL) {
        CGPathRelease(path);
        return NSNotFound;
    }

    CFArrayRef lines = CTFrameGetLines(frame);
    NSInteger numberOfLines = self.numberOfLines > 0 ? MIN(self.numberOfLines, CFArrayGetCount(lines)) : CFArrayGetCount(lines);
    if (numberOfLines == 0) {
        CFRelease(frame);
        CGPathRelease(path);
        return NSNotFound;
    }

    CFIndex idx = NSNotFound;

    CGPoint lineOrigins[numberOfLines];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, numberOfLines), lineOrigins);

    for (CFIndex lineIndex = 0; lineIndex < numberOfLines; lineIndex++) {
        CGPoint lineOrigin = lineOrigins[lineIndex];
        CTLineRef line = CFArrayGetValueAtIndex(lines, lineIndex);

        // Get bounding information of line
        CGFloat ascent = 0.0f, descent = 0.0f, leading = 0.0f;
        CGFloat width = (CGFloat)CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
        CGFloat yMin = (CGFloat)floor(lineOrigin.y - descent);
        CGFloat yMax = (CGFloat)ceil(lineOrigin.y + ascent);

        // Apply penOffset using flushFactor for horizontal alignment to set lineOrigin since this is the horizontal offset from drawFramesetter
        CGFloat flushFactor = BITFlushFactorForTextAlignment(self.textAlignment);
        CGFloat penOffset = (CGFloat)CTLineGetPenOffsetForFlush(line, flushFactor, textRect.size.width);
        lineOrigin.x = penOffset;

        // Check if we've already passed the line
        if (p.y > yMax) {
            break;
        }
        // Check if the point is within this line vertically
        if (p.y >= yMin) {
            // Check if the point is within this line horizontally
            if (p.x >= lineOrigin.x && p.x <= lineOrigin.x + width) {
                // Convert CT coordinates to line-relative coordinates
                CGPoint relativePoint = CGPointMake(p.x - lineOrigin.x, p.y - lineOrigin.y);
                idx = CTLineGetStringIndexForPosition(line, relativePoint);
                break;
            }
        }
    }

    CFRelease(frame);
    CGPathRelease(path);

    return idx;
}

- (CGRect)boundingRectForCharacterRange:(NSRange)range {
    NSMutableAttributedString *mutableAttributedString = [self.attributedText mutableCopy];

    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:mutableAttributedString];

    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [textStorage addLayoutManager:layoutManager];

    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:self.bounds.size];
    [layoutManager addTextContainer:textContainer];

    NSRange glyphRange;
    [layoutManager characterRangeForGlyphRange:range actualGlyphRange:&glyphRange];

    return [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
}

- (void)drawFramesetter:(CTFramesetterRef)framesetter
       attributedString:(NSAttributedString *)attributedString
              textRange:(CFRange)textRange
                 inRect:(CGRect)rect
                context:(CGContextRef)c
{
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, rect);
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, textRange, path, NULL);

    [self drawBackground:frame inRect:rect context:c];

    CFArrayRef lines = CTFrameGetLines(frame);
    NSInteger numberOfLines = self.numberOfLines > 0 ? MIN(self.numberOfLines, CFArrayGetCount(lines)) : CFArrayGetCount(lines);
    BOOL truncateLastLine = (self.lineBreakMode == BITLineBreakByTruncatingHead || self.lineBreakMode == BITLineBreakByTruncatingMiddle || self.lineBreakMode == BITLineBreakByTruncatingTail);

    CGPoint lineOrigins[numberOfLines];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, numberOfLines), lineOrigins);

    for (CFIndex lineIndex = 0; lineIndex < numberOfLines; lineIndex++) {
        CGPoint lineOrigin = lineOrigins[lineIndex];
        CGContextSetTextPosition(c, lineOrigin.x, lineOrigin.y);
        CTLineRef line = CFArrayGetValueAtIndex(lines, lineIndex);

        CGFloat descent = 0.0f;
        CTLineGetTypographicBounds((CTLineRef)line, NULL, &descent, NULL);

        // Adjust pen offset for flush depending on text alignment
        CGFloat flushFactor = BITFlushFactorForTextAlignment(self.textAlignment);

        if (lineIndex == numberOfLines - 1 && truncateLastLine) {
            // Check if the range of text in the last line reaches the end of the full attributed string
            CFRange lastLineRange = CTLineGetStringRange(line);

            if (!(lastLineRange.length == 0 && lastLineRange.location == 0) && lastLineRange.location + lastLineRange.length < textRange.location + textRange.length) {
                // Get correct truncationType and attribute position
                CTLineTruncationType truncationType;
                CFIndex truncationAttributePosition = lastLineRange.location;
                BITLineBreakMode lineBreakMode = self.lineBreakMode;

                // Multiple lines, only use UILineBreakModeTailTruncation
                if (numberOfLines != 1) {
                    lineBreakMode = BITLineBreakByTruncatingTail;
                }

                switch (lineBreakMode) {
                    case BITLineBreakByTruncatingHead:
                        truncationType = kCTLineTruncationStart;
                        break;
                    case BITLineBreakByTruncatingMiddle:
                        truncationType = kCTLineTruncationMiddle;
                        truncationAttributePosition += (lastLineRange.length / 2);
                        break;
                    case BITLineBreakByTruncatingTail:
                    default:
                        truncationType = kCTLineTruncationEnd;
                        truncationAttributePosition += (lastLineRange.length - 1);
                        break;
                }

                NSAttributedString *attributedTruncationString = self.attributedTruncationToken;
                if (!attributedTruncationString) {
                    NSString *truncationTokenString = @"\u2026"; // Unicode Character 'HORIZONTAL ELLIPSIS' (U+2026)

                    NSDictionary *truncationTokenStringAttributes = truncationTokenStringAttributes = [attributedString attributesAtIndex:(NSUInteger)truncationAttributePosition effectiveRange:NULL];

                    attributedTruncationString = [[NSAttributedString alloc] initWithString:truncationTokenString attributes:truncationTokenStringAttributes];
                }
                CTLineRef truncationToken = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attributedTruncationString);

                // Append truncationToken to the string
                // because if string isn't too long, CT won't add the truncationToken on its own.
                // There is no chance of a double truncationToken because CT only adds the
                // token if it removes characters (and the one we add will go first)
                NSMutableAttributedString *truncationString = [[NSMutableAttributedString alloc] initWithAttributedString:
                                                               [attributedString attributedSubstringFromRange:
                                                                NSMakeRange((NSUInteger)lastLineRange.location,
                                                                            (NSUInteger)lastLineRange.length)]];
                if (lastLineRange.length > 0) {
                    // Remove any newline at the end (we don't want newline space between the text and the truncation token). There can only be one, because the second would be on the next line.
                    unichar lastCharacter = [[truncationString string] characterAtIndex:(NSUInteger)(lastLineRange.length - 1)];
                    if ([[NSCharacterSet newlineCharacterSet] characterIsMember:lastCharacter]) {
                        [truncationString deleteCharactersInRange:NSMakeRange((NSUInteger)(lastLineRange.length - 1), 1)];
                    }
                }
                [truncationString appendAttributedString:attributedTruncationString];
                CTLineRef truncationLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)truncationString);

                // Truncate the line in case it is too long.
                CTLineRef truncatedLine = CTLineCreateTruncatedLine(truncationLine, rect.size.width, truncationType, truncationToken);
                if (!truncatedLine) {
                    // If the line is not as wide as the truncationToken, truncatedLine is NULL
                    truncatedLine = CFRetain(truncationToken);
                }

                CGFloat penOffset = (CGFloat)CTLineGetPenOffsetForFlush(truncatedLine, flushFactor, rect.size.width);
                CGContextSetTextPosition(c, penOffset, lineOrigin.y - descent - self.font.descender);

                CTLineDraw(truncatedLine, c);

                NSRange linkRange;
                if ([attributedTruncationString attribute:NSLinkAttributeName atIndex:0 effectiveRange:&linkRange]) {
                    NSRange tokenRange = [truncationString.string rangeOfString:attributedTruncationString.string];
                    NSRange tokenLinkRange = NSMakeRange((NSUInteger)(lastLineRange.location+lastLineRange.length)-tokenRange.length, (NSUInteger)tokenRange.length);

                    [self addLinkToURL:[attributedTruncationString attribute:NSLinkAttributeName atIndex:0 effectiveRange:&linkRange] withRange:tokenLinkRange];
                }

                CFRelease(truncatedLine);
                CFRelease(truncationLine);
                CFRelease(truncationToken);
            } else {
                CGFloat penOffset = (CGFloat)CTLineGetPenOffsetForFlush(line, flushFactor, rect.size.width);
                CGContextSetTextPosition(c, penOffset, lineOrigin.y - descent - self.font.descender);
                CTLineDraw(line, c);
            }
        } else {
            CGFloat penOffset = (CGFloat)CTLineGetPenOffsetForFlush(line, flushFactor, rect.size.width);
            CGContextSetTextPosition(c, penOffset, lineOrigin.y - descent - self.font.descender);
            CTLineDraw(line, c);
        }
    }

    [self drawStrike:frame inRect:rect context:c];

    CFRelease(frame);
    CGPathRelease(path);
}

- (void)drawBackground:(CTFrameRef)frame
                inRect:(CGRect)rect
               context:(CGContextRef)c
{
    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frame);
    CGPoint origins[[lines count]];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), origins);

    CFIndex lineIndex = 0;
    for (id line in lines) {
        CGFloat ascent = 0.0f, descent = 0.0f, leading = 0.0f;
        CGFloat width = (CGFloat)CTLineGetTypographicBounds((__bridge CTLineRef)line, &ascent, &descent, &leading) ;

        for (id glyphRun in (__bridge NSArray *)CTLineGetGlyphRuns((__bridge CTLineRef)line)) {
            NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes((__bridge CTRunRef) glyphRun);
            CGColorRef strokeColor = CGColorRefFromColor([attributes objectForKey:kBITBackgroundStrokeColorAttributeName]);
            CGColorRef fillColor = CGColorRefFromColor([attributes objectForKey:kBITBackgroundFillColorAttributeName]);
            UIEdgeInsets fillPadding = [[attributes objectForKey:kBITBackgroundFillPaddingAttributeName] UIEdgeInsetsValue];
            CGFloat cornerRadius = [[attributes objectForKey:kBITBackgroundCornerRadiusAttributeName] floatValue];
            CGFloat lineWidth = [[attributes objectForKey:kBITBackgroundLineWidthAttributeName] floatValue];

            if (strokeColor || fillColor) {
                CGRect runBounds = CGRectZero;
                CGFloat runAscent = 0.0f;
                CGFloat runDescent = 0.0f;

                runBounds.size.width = (CGFloat)CTRunGetTypographicBounds((__bridge CTRunRef)glyphRun, CFRangeMake(0, 0), &runAscent, &runDescent, NULL) + fillPadding.left + fillPadding.right;
                runBounds.size.height = runAscent + runDescent + fillPadding.top + fillPadding.bottom;

                CGFloat xOffset = 0.0f;
                CFRange glyphRange = CTRunGetStringRange((__bridge CTRunRef)glyphRun);
                switch (CTRunGetStatus((__bridge CTRunRef)glyphRun)) {
                    case kCTRunStatusRightToLeft:
                        xOffset = CTLineGetOffsetForStringIndex((__bridge CTLineRef)line, glyphRange.location + glyphRange.length, NULL);
                        break;
                    default:
                        xOffset = CTLineGetOffsetForStringIndex((__bridge CTLineRef)line, glyphRange.location, NULL);
                        break;
                }

                runBounds.origin.x = origins[lineIndex].x + rect.origin.x + xOffset - fillPadding.left - rect.origin.x;
                runBounds.origin.y = origins[lineIndex].y + rect.origin.y - fillPadding.bottom - rect.origin.y;
                runBounds.origin.y -= runDescent;

                // Don't draw higlightedLinkBackground too far to the right
                if (CGRectGetWidth(runBounds) > width) {
                    runBounds.size.width = width;
                }

                CGPathRef path = [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(UIEdgeInsetsInsetRect(runBounds, self.linkBackgroundEdgeInset), lineWidth, lineWidth) cornerRadius:cornerRadius] CGPath];

                CGContextSetLineJoin(c, kCGLineJoinRound);

                if (fillColor) {
                    CGContextSetFillColorWithColor(c, fillColor);
                    CGContextAddPath(c, path);
                    CGContextFillPath(c);
                }

                if (strokeColor) {
                    CGContextSetStrokeColorWithColor(c, strokeColor);
                    CGContextAddPath(c, path);
                    CGContextStrokePath(c);
                }
            }
        }

        lineIndex++;
    }
}

- (void)drawStrike:(CTFrameRef)frame
            inRect:(__unused CGRect)rect
           context:(CGContextRef)c
{
    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frame);
    CGPoint origins[[lines count]];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), origins);

    CFIndex lineIndex = 0;
    for (id line in lines) {
        CGFloat ascent = 0.0f, descent = 0.0f, leading = 0.0f;
        CGFloat width = (CGFloat)CTLineGetTypographicBounds((__bridge CTLineRef)line, &ascent, &descent, &leading) ;

        for (id glyphRun in (__bridge NSArray *)CTLineGetGlyphRuns((__bridge CTLineRef)line)) {
            NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes((__bridge CTRunRef) glyphRun);
            BOOL strikeOut = [[attributes objectForKey:kBITStrikeOutAttributeName] boolValue];
            NSInteger superscriptStyle = [[attributes objectForKey:(id)kCTSuperscriptAttributeName] integerValue];

            if (strikeOut) {
                CGRect runBounds = CGRectZero;
                CGFloat runAscent = 0.0f;
                CGFloat runDescent = 0.0f;

                runBounds.size.width = (CGFloat)CTRunGetTypographicBounds((__bridge CTRunRef)glyphRun, CFRangeMake(0, 0), &runAscent, &runDescent, NULL);
                runBounds.size.height = runAscent + runDescent;

                CGFloat xOffset = 0.0f;
                CFRange glyphRange = CTRunGetStringRange((__bridge CTRunRef)glyphRun);
                switch (CTRunGetStatus((__bridge CTRunRef)glyphRun)) {
                    case kCTRunStatusRightToLeft:
                        xOffset = CTLineGetOffsetForStringIndex((__bridge CTLineRef)line, glyphRange.location + glyphRange.length, NULL);
                        break;
                    default:
                        xOffset = CTLineGetOffsetForStringIndex((__bridge CTLineRef)line, glyphRange.location, NULL);
                        break;
                }
                runBounds.origin.x = origins[lineIndex].x + xOffset;
                runBounds.origin.y = origins[lineIndex].y;
                runBounds.origin.y -= runDescent;

                // Don't draw strikeout too far to the right
                if (CGRectGetWidth(runBounds) > width) {
                    runBounds.size.width = width;
                }

                switch (superscriptStyle) {
                    case 1:
                        runBounds.origin.y -= runAscent * 0.47f;
                        break;
                    case -1:
                        runBounds.origin.y += runAscent * 0.25f;
                        break;
                    default:
                        break;
                }

                // Use text color, or default to black
                id color = [attributes objectForKey:(id)kCTForegroundColorAttributeName];
                if (color) {
                    CGContextSetStrokeColorWithColor(c, CGColorRefFromColor(color));
                } else {
                    CGContextSetGrayStrokeColor(c, 0.0f, 1.0);
                }

                CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)self.font.fontName, self.font.pointSize, NULL);
                CGContextSetLineWidth(c, CTFontGetUnderlineThickness(font));
                CFRelease(font);

                CGFloat y = CGFloat_round(runBounds.origin.y + runBounds.size.height / 2.0f);
                CGContextMoveToPoint(c, runBounds.origin.x, y);
                CGContextAddLineToPoint(c, runBounds.origin.x + runBounds.size.width, y);

                CGContextStrokePath(c);
            }
        }

        lineIndex++;
    }
}

#pragma mark - BITAttributedLabel

- (void)setText:(id)text {
    NSParameterAssert(!text || [text isKindOfClass:[NSAttributedString class]] || [text isKindOfClass:[NSString class]]);

    if ([text isKindOfClass:[NSString class]]) {
        [self setText:text afterInheritingLabelAttributesAndConfiguringWithBlock:nil];
        return;
    }

    self.attributedText = text;
    self.activeLink = nil;

    self.linkModels = [NSArray array];
    if (text && self.attributedText && self.enabledTextCheckingTypes) {
        __weak __typeof(self)weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            __strong __typeof(weakSelf)strongSelf = weakSelf;

            NSDataDetector *dataDetector = strongSelf.dataDetector;
            if (dataDetector && [dataDetector respondsToSelector:@selector(matchesInString:options:range:)]) {
                NSArray *results = [dataDetector matchesInString:[(NSAttributedString *)text string] options:0 range:NSMakeRange(0, [(NSAttributedString *)text length])];
                if ([results count] > 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([[strongSelf.attributedText string] isEqualToString:[(NSAttributedString *)text string]]) {
                            [strongSelf addLinksWithTextCheckingResults:results attributes:strongSelf.linkAttributes];
                        }
                    });
                }
            }
        });
    }

    [self.attributedText enumerateAttribute:NSLinkAttributeName inRange:NSMakeRange(0, self.attributedText.length) options:0 usingBlock:^(id value, NSRange range, __unused BOOL *stop) {
        if (value) {
            NSURL *URL = [value isKindOfClass:[NSString class]] ? [NSURL URLWithString:value] : value;
            [self addLinkToURL:URL withRange:range];
        }
    }];
}

- (void)setText:(id)text
afterInheritingLabelAttributesAndConfiguringWithBlock:(NSMutableAttributedString * (^)(NSMutableAttributedString *mutableAttributedString))block
{
    NSMutableAttributedString *mutableAttributedString = nil;
    if ([text isKindOfClass:[NSString class]]) {
        mutableAttributedString = [[NSMutableAttributedString alloc] initWithString:text attributes:NSAttributedStringAttributesFromLabel(self)];
    } else {
        mutableAttributedString = [[NSMutableAttributedString alloc] initWithAttributedString:text];
        [mutableAttributedString addAttributes:NSAttributedStringAttributesFromLabel(self) range:NSMakeRange(0, [mutableAttributedString length])];
    }

    if (block) {
        mutableAttributedString = block(mutableAttributedString);
    }

    [self setText:mutableAttributedString];
}

- (void)setActiveLink:(BITAttributedLabelLink *)activeLink {
    _activeLink = activeLink;

    NSDictionary *activeAttributes = activeLink.activeAttributes ?: self.activeLinkAttributes;

    if (_activeLink && activeAttributes.count > 0) {
        if (!self.inactiveAttributedText) {
            self.inactiveAttributedText = [self.attributedText copy];
        }

        NSMutableAttributedString *mutableAttributedString = [self.inactiveAttributedText mutableCopy];
        if (self.activeLink.result.range.length > 0 && NSLocationInRange(NSMaxRange(self.activeLink.result.range) - 1, NSMakeRange(0, [self.inactiveAttributedText length]))) {
            [mutableAttributedString addAttributes:activeAttributes range:self.activeLink.result.range];
        }

        self.attributedText = mutableAttributedString;
        [self setNeedsDisplay];

        [CATransaction flush];
    } else if (self.inactiveAttributedText) {
        self.attributedText = self.inactiveAttributedText;
        self.inactiveAttributedText = nil;

        [self setNeedsDisplay];
    }
}

- (void)setLinkAttributes:(NSDictionary *)linkAttributes {
    _linkAttributes = convertNSAttributedStringAttributesToCTAttributes(linkAttributes);
}

- (void)setActiveLinkAttributes:(NSDictionary *)activeLinkAttributes {
    _activeLinkAttributes = convertNSAttributedStringAttributesToCTAttributes(activeLinkAttributes);
}

- (void)setInactiveLinkAttributes:(NSDictionary *)inactiveLinkAttributes {
    _inactiveLinkAttributes = convertNSAttributedStringAttributesToCTAttributes(inactiveLinkAttributes);
}

#pragma mark - UILabel

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [self setNeedsDisplay];
}

// Fixes crash when loading from a UIStoryboard
- (UIColor *)textColor {
    UIColor *color = [super textColor];
    if (!color) {
        color = [UIColor blackColor];
    }

    return color;
}

- (void)setTextColor:(UIColor *)textColor {
    UIColor *oldTextColor = self.textColor;
    [super setTextColor:textColor];

    // Redraw to allow any ColorFromContext attributes a chance to update
    if (textColor != oldTextColor) {
        [self setNeedsFramesetter];
        [self setNeedsDisplay];
    }
}

- (CGRect)textRectForBounds:(CGRect)bounds
     limitedToNumberOfLines:(NSInteger)numberOfLines
{
    bounds = UIEdgeInsetsInsetRect(bounds, self.textInsets);
    if (!self.attributedText) {
        return [super textRectForBounds:bounds limitedToNumberOfLines:numberOfLines];
    }

    CGRect textRect = bounds;

    // Calculate height with a minimum of double the font pointSize, to ensure that CTFramesetterSuggestFrameSizeWithConstraints doesn't return CGSizeZero, as it would if textRect height is insufficient.
    textRect.size.height = MAX(self.font.lineHeight * MAX(2, numberOfLines), bounds.size.height);

    // Adjust the text to be in the center vertically, if the text size is smaller than bounds
    CGSize textSize = CTFramesetterSuggestFrameSizeWithConstraints([self framesetter], CFRangeMake(0, (CFIndex)[self.attributedText length]), NULL, textRect.size, NULL);
    textSize = CGSizeMake(CGFloat_ceil(textSize.width), CGFloat_ceil(textSize.height)); // Fix for iOS 4, CTFramesetterSuggestFrameSizeWithConstraints sometimes returns fractional sizes

    if (textSize.height < bounds.size.height) {
        CGFloat yOffset = 0.0f;
        switch (self.verticalAlignment) {
            case BITAttributedLabelVerticalAlignmentCenter:
                yOffset = CGFloat_floor((bounds.size.height - textSize.height) / 2.0f);
                break;
            case BITAttributedLabelVerticalAlignmentBottom:
                yOffset = bounds.size.height - textSize.height;
                break;
            case BITAttributedLabelVerticalAlignmentTop:
            default:
                break;
        }

        textRect.origin.y += yOffset;
    }

    return textRect;
}

- (void)drawTextInRect:(CGRect)rect {
    CGRect insetRect = UIEdgeInsetsInsetRect(rect, self.textInsets);
    if (!self.attributedText) {
        [super drawTextInRect:insetRect];
        return;
    }

    NSAttributedString *originalAttributedText = nil;

    // Adjust the font size to fit width, if necessarry
    if (self.adjustsFontSizeToFitWidth && self.numberOfLines > 0) {
        // Framesetter could still be working with a resized version of the text;
        // need to reset so we start from the original font size.
        // See #393.
        [self setNeedsFramesetter];
        [self setNeedsDisplay];

        if ([self respondsToSelector:@selector(invalidateIntrinsicContentSize)]) {
            [self invalidateIntrinsicContentSize];
        }

        // Use infinite width to find the max width, which will be compared to availableWidth if needed.
        CGSize maxSize = (self.numberOfLines > 1) ? CGSizeMake(BITFLOAT_MAX, BITFLOAT_MAX) : CGSizeZero;

        CGFloat textWidth = [self sizeThatFits:maxSize].width;
        CGFloat availableWidth = self.frame.size.width * self.numberOfLines;
        if (self.numberOfLines > 1 && self.lineBreakMode == BITLineBreakByWordWrapping) {
            textWidth *= kBITLineBreakWordWrapTextWidthScalingFactor;
        }

        if (textWidth > availableWidth && textWidth > 0.0f) {
            originalAttributedText = [self.attributedText copy];

            CGFloat scaleFactor = availableWidth / textWidth;
            if ([self respondsToSelector:@selector(minimumScaleFactor)] && self.minimumScaleFactor > scaleFactor) {
                scaleFactor = self.minimumScaleFactor;
            }

            self.attributedText = NSAttributedStringByScalingFontSize(self.attributedText, scaleFactor);
        }
    }

    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSaveGState(c);
    {
        CGContextSetTextMatrix(c, CGAffineTransformIdentity);

        // Inverts the CTM to match iOS coordinates (otherwise text draws upside-down; Mac OS's system is different)
        CGContextTranslateCTM(c, 0.0f, insetRect.size.height);
        CGContextScaleCTM(c, 1.0f, -1.0f);

        CFRange textRange = CFRangeMake(0, (CFIndex)[self.attributedText length]);

        // First, get the text rect (which takes vertical centering into account)
        CGRect textRect = [self textRectForBounds:rect limitedToNumberOfLines:self.numberOfLines];

        // CoreText draws its text aligned to the bottom, so we move the CTM here to take our vertical offsets into account
        CGContextTranslateCTM(c, insetRect.origin.x, insetRect.size.height - textRect.origin.y - textRect.size.height);

        // Second, trace the shadow before the actual text, if we have one
        if (self.shadowColor && !self.highlighted) {
            CGContextSetShadowWithColor(c, self.shadowOffset, self.shadowRadius, [self.shadowColor CGColor]);
        } else if (self.highlightedShadowColor) {
            CGContextSetShadowWithColor(c, self.highlightedShadowOffset, self.highlightedShadowRadius, [self.highlightedShadowColor CGColor]);
        }

        // Finally, draw the text or highlighted text itself (on top of the shadow, if there is one)
        if (self.highlightedTextColor && self.highlighted) {
            NSMutableAttributedString *highlightAttributedString = [self.renderedAttributedText mutableCopy];
            [highlightAttributedString addAttribute:(__bridge NSString *)kCTForegroundColorAttributeName value:(id)[self.highlightedTextColor CGColor] range:NSMakeRange(0, highlightAttributedString.length)];

            if (![self highlightFramesetter]) {
                CTFramesetterRef highlightFramesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)highlightAttributedString);
                [self setHighlightFramesetter:highlightFramesetter];
                CFRelease(highlightFramesetter);
            }

            [self drawFramesetter:[self highlightFramesetter] attributedString:highlightAttributedString textRange:textRange inRect:textRect context:c];
        } else {
            [self drawFramesetter:[self framesetter] attributedString:self.renderedAttributedText textRange:textRange inRect:textRect context:c];
        }

        // If we adjusted the font size, set it back to its original size
        if (originalAttributedText) {
            // Use ivar directly to avoid clearing out framesetter and renderedAttributedText
            _attributedText = originalAttributedText;
        }
    }
    CGContextRestoreGState(c);
}

#pragma mark - UIAccessibilityElement

- (BOOL)isAccessibilityElement {
    return NO;
}

- (NSInteger)accessibilityElementCount {
    return (NSInteger)[[self accessibilityElements] count];
}

- (id)accessibilityElementAtIndex:(NSInteger)index {
    return [[self accessibilityElements] objectAtIndex:(NSUInteger)index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element {
    return (NSInteger)[[self accessibilityElements] indexOfObject:element];
}

- (NSArray *)accessibilityElements {
    if (!_accessibilityElements) {
        @synchronized(self) {
            NSMutableArray *mutableAccessibilityItems = [NSMutableArray array];

            for (BITAttributedLabelLink *link in self.linkModels) {

                if (link.result.range.location == NSNotFound) {
                    continue;
                }

                NSString *sourceText = [self.text isKindOfClass:[NSString class]] ? self.text : [(NSAttributedString *)self.text string];

                NSString *accessibilityLabel = [sourceText substringWithRange:link.result.range];
                NSString *accessibilityValue = link.accessibilityValue;

                if (accessibilityLabel) {
                    BITAccessibilityElement *linkElement = [[BITAccessibilityElement alloc] initWithAccessibilityContainer:self];
                    linkElement.accessibilityTraits = UIAccessibilityTraitLink;
                    linkElement.boundingRect = [self boundingRectForCharacterRange:link.result.range];
                    linkElement.superview = self;
                    linkElement.accessibilityLabel = accessibilityLabel;

                    if (![accessibilityLabel isEqualToString:accessibilityValue]) {
                        linkElement.accessibilityValue = accessibilityValue;
                    }

                    [mutableAccessibilityItems addObject:linkElement];
                }
            }

            BITAccessibilityElement *baseElement = [[BITAccessibilityElement alloc] initWithAccessibilityContainer:self];
            baseElement.accessibilityLabel = [super accessibilityLabel];
            baseElement.accessibilityHint = [super accessibilityHint];
            baseElement.accessibilityValue = [super accessibilityValue];
            baseElement.boundingRect = self.bounds;
            baseElement.superview = self;
            baseElement.accessibilityTraits = [super accessibilityTraits];

            [mutableAccessibilityItems addObject:baseElement];

            self.accessibilityElements = [NSArray arrayWithArray:mutableAccessibilityItems];
        }
    }

    return _accessibilityElements;
}

#pragma mark - UIView

- (CGSize)sizeThatFits:(CGSize)size {
    if (!self.attributedText) {
        return [super sizeThatFits:size];
    } else {
        NSAttributedString *string = [self renderedAttributedText];

        CGSize labelSize = CTFramesetterSuggestFrameSizeForAttributedStringWithConstraints([self framesetter], string, size, (NSUInteger)self.numberOfLines);
        labelSize.width += self.textInsets.left + self.textInsets.right;
        labelSize.height += self.textInsets.top + self.textInsets.bottom;

        return labelSize;
    }
}

- (CGSize)intrinsicContentSize {
    // There's an implicit width from the original UILabel implementation
    return [self sizeThatFits:[super intrinsicContentSize]];
}

- (void)tintColorDidChange {
    if (!self.inactiveLinkAttributes || [self.inactiveLinkAttributes count] == 0) {
        return;
    }

    BOOL isInactive = (self.tintAdjustmentMode == UIViewTintAdjustmentModeDimmed);

    NSMutableAttributedString *mutableAttributedString = [self.attributedText mutableCopy];
    for (BITAttributedLabelLink *link in self.linkModels) {
        NSDictionary *attributesToRemove = isInactive ? link.attributes : link.inactiveAttributes;
        NSDictionary *attributesToAdd = isInactive ? link.inactiveAttributes : link.attributes;

        [attributesToRemove enumerateKeysAndObjectsUsingBlock:^(NSString *name, __unused id value, __unused BOOL *stop) {
            if (NSMaxRange(link.result.range) <= mutableAttributedString.length) {
                [mutableAttributedString removeAttribute:name range:link.result.range];
            }
        }];

        if (attributesToAdd) {
            if (NSMaxRange(link.result.range) <= mutableAttributedString.length) {
                [mutableAttributedString addAttributes:attributesToAdd range:link.result.range];
            }
        }
    }

    self.attributedText = mutableAttributedString;

    [self setNeedsDisplay];
}

- (UIView *)hitTest:(CGPoint)point
          withEvent:(UIEvent *)event
{
    if (![self linkAtPoint:point] || !self.userInteractionEnabled || self.hidden || self.alpha < 0.01) {
        return [super hitTest:point withEvent:event];
    }

    return self;
}

#pragma mark - UIResponder

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)canPerformAction:(SEL)action
              withSender:(__unused id)sender
{
#if !TARGET_OS_TV
    return (action == @selector(copy:));
#else
    return NO;
#endif
}

- (void)touchesBegan:(NSSet *)touches
           withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];

    self.activeLink = [self linkAtPoint:[touch locationInView:self]];

    if (!self.activeLink) {
        [super touchesBegan:touches withEvent:event];
    }
}

- (void)touchesMoved:(NSSet *)touches
           withEvent:(UIEvent *)event
{
    if (self.activeLink) {
        UITouch *touch = [touches anyObject];

        if (self.activeLink != [self linkAtPoint:[touch locationInView:self]]) {
            self.activeLink = nil;
        }
    } else {
        [super touchesMoved:touches withEvent:event];
    }
}

- (void)touchesEnded:(NSSet *)touches
           withEvent:(UIEvent *)event
{
    if (self.activeLink) {
        if (self.activeLink.linkTapBlock) {
            self.activeLink.linkTapBlock(self, self.activeLink);
            self.activeLink = nil;
            return;
        }

        NSTextCheckingResult *result = self.activeLink.result;
        self.activeLink = nil;

        switch (result.resultType) {
            case NSTextCheckingTypeLink:
                if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithURL:)]) {
                    [self.delegate attributedLabel:self didSelectLinkWithURL:result.URL];
                    return;
                }
                break;
            case NSTextCheckingTypeAddress:
                if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithAddress:)]) {
                    [self.delegate attributedLabel:self didSelectLinkWithAddress:result.addressComponents];
                    return;
                }
                break;
            case NSTextCheckingTypePhoneNumber:
                if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithPhoneNumber:)]) {
                    [self.delegate attributedLabel:self didSelectLinkWithPhoneNumber:result.phoneNumber];
                    return;
                }
                break;
            case NSTextCheckingTypeDate:
                if (result.timeZone && [self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithDate:timeZone:duration:)]) {
                    [self.delegate attributedLabel:self didSelectLinkWithDate:result.date timeZone:result.timeZone duration:result.duration];
                    return;
                } else if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithDate:)]) {
                    [self.delegate attributedLabel:self didSelectLinkWithDate:result.date];
                    return;
                }
                break;
            case NSTextCheckingTypeTransitInformation:
                if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithTransitInformation:)]) {
                    [self.delegate attributedLabel:self didSelectLinkWithTransitInformation:result.components];
                    return;
                }
            default:
                break;
        }

        // Fallback to `attributedLabel:didSelectLinkWithTextCheckingResult:` if no other delegate method matched.
        if ([self.delegate respondsToSelector:@selector(attributedLabel:didSelectLinkWithTextCheckingResult:)]) {
            [self.delegate attributedLabel:self didSelectLinkWithTextCheckingResult:result];
        }
    } else {
        [super touchesEnded:touches withEvent:event];
    }
}

- (void)touchesCancelled:(NSSet *)touches
               withEvent:(UIEvent *)event
{
    if (self.activeLink) {
        self.activeLink = nil;
    } else {
        [super touchesCancelled:touches withEvent:event];
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return [self containslinkAtPoint:[touch locationInView:self]];
}

#pragma mark - UILongPressGestureRecognizer

- (void)longPressGestureDidFire:(UILongPressGestureRecognizer *)sender {
    switch (sender.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint touchPoint = [sender locationInView:self];
            BITAttributedLabelLink *link = [self linkAtPoint:touchPoint];

            if (link) {
                if (link.linkLongPressBlock) {
                    link.linkLongPressBlock(self, link);
                    return;
                }

                NSTextCheckingResult *result = link.result;

                if (!result) {
                    return;
                }

                switch (result.resultType) {
                    case NSTextCheckingTypeLink:
                        if ([self.delegate respondsToSelector:@selector(attributedLabel:didLongPressLinkWithURL:atPoint:)]) {
                            [self.delegate attributedLabel:self didLongPressLinkWithURL:result.URL atPoint:touchPoint];
                            return;
                        }
                        break;
                    case NSTextCheckingTypeAddress:
                        if ([self.delegate respondsToSelector:@selector(attributedLabel:didLongPressLinkWithAddress:atPoint:)]) {
                            [self.delegate attributedLabel:self didLongPressLinkWithAddress:result.addressComponents atPoint:touchPoint];
                            return;
                        }
                        break;
                    case NSTextCheckingTypePhoneNumber:
                        if ([self.delegate respondsToSelector:@selector(attributedLabel:didLongPressLinkWithPhoneNumber:atPoint:)]) {
                            [self.delegate attributedLabel:self didLongPressLinkWithPhoneNumber:result.phoneNumber atPoint:touchPoint];
                            return;
                        }
                        break;
                    case NSTextCheckingTypeDate:
                        if (result.timeZone && [self.delegate respondsToSelector:@selector(attributedLabel:didLongPressLinkWithDate:timeZone:duration:atPoint:)]) {
                            [self.delegate attributedLabel:self didLongPressLinkWithDate:result.date timeZone:result.timeZone duration:result.duration atPoint:touchPoint];
                            return;
                        } else if ([self.delegate respondsToSelector:@selector(attributedLabel:didLongPressLinkWithDate:atPoint:)]) {
                            [self.delegate attributedLabel:self didLongPressLinkWithDate:result.date atPoint:touchPoint];
                            return;
                        }
                        break;
                    case NSTextCheckingTypeTransitInformation:
                        if ([self.delegate respondsToSelector:@selector(attributedLabel:didLongPressLinkWithTransitInformation:atPoint:)]) {
                            [self.delegate attributedLabel:self didLongPressLinkWithTransitInformation:result.components atPoint:touchPoint];
                            return;
                        }
                    default:
                        break;
                }

                // Fallback to `attributedLabel:didLongPressLinkWithTextCheckingResult:atPoint:` if no other delegate method matched.
                if ([self.delegate respondsToSelector:@selector(attributedLabel:didLongPressLinkWithTextCheckingResult:atPoint:)]) {
                    [self.delegate attributedLabel:self didLongPressLinkWithTextCheckingResult:result atPoint:touchPoint];
                }
            }
            break;
        }
        default:
            break;
    }
}

#if !TARGET_OS_TV
#pragma mark - UIResponderStandardEditActions

- (void)copy:(__unused id)sender {
    [[UIPasteboard generalPasteboard] setString:self.text];
}
#endif

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];

    [coder encodeObject:@(self.enabledTextCheckingTypes) forKey:NSStringFromSelector(@selector(enabledTextCheckingTypes))];

    [coder encodeObject:self.linkModels forKey:NSStringFromSelector(@selector(linkModels))];
    if ([NSMutableParagraphStyle class]) {
        [coder encodeObject:self.linkAttributes forKey:NSStringFromSelector(@selector(linkAttributes))];
        [coder encodeObject:self.activeLinkAttributes forKey:NSStringFromSelector(@selector(activeLinkAttributes))];
        [coder encodeObject:self.inactiveLinkAttributes forKey:NSStringFromSelector(@selector(inactiveLinkAttributes))];
    }
    [coder encodeObject:@(self.shadowRadius) forKey:NSStringFromSelector(@selector(shadowRadius))];
    [coder encodeObject:@(self.highlightedShadowRadius) forKey:NSStringFromSelector(@selector(highlightedShadowRadius))];
    [coder encodeCGSize:self.highlightedShadowOffset forKey:NSStringFromSelector(@selector(highlightedShadowOffset))];
    [coder encodeObject:self.highlightedShadowColor forKey:NSStringFromSelector(@selector(highlightedShadowColor))];
    [coder encodeObject:@(self.kern) forKey:NSStringFromSelector(@selector(kern))];
    [coder encodeObject:@(self.firstLineIndent) forKey:NSStringFromSelector(@selector(firstLineIndent))];
    [coder encodeObject:@(self.lineSpacing) forKey:NSStringFromSelector(@selector(lineSpacing))];
    [coder encodeObject:@(self.lineHeightMultiple) forKey:NSStringFromSelector(@selector(lineHeightMultiple))];
    [coder encodeUIEdgeInsets:self.textInsets forKey:NSStringFromSelector(@selector(textInsets))];
    [coder encodeInteger:self.verticalAlignment forKey:NSStringFromSelector(@selector(verticalAlignment))];

    [coder encodeObject:self.attributedTruncationToken forKey:NSStringFromSelector(@selector(attributedTruncationToken))];

    [coder encodeObject:NSStringFromUIEdgeInsets(self.linkBackgroundEdgeInset) forKey:NSStringFromSelector(@selector(linkBackgroundEdgeInset))];
    [coder encodeObject:self.attributedText forKey:NSStringFromSelector(@selector(attributedText))];
    [coder encodeObject:self.text forKey:NSStringFromSelector(@selector(text))];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (!self) {
        return nil;
    }

    [self commonInit];

    if ([coder containsValueForKey:NSStringFromSelector(@selector(enabledTextCheckingTypes))]) {
        self.enabledTextCheckingTypes = [[coder decodeObjectForKey:NSStringFromSelector(@selector(enabledTextCheckingTypes))] unsignedLongLongValue];
    }

    if ([NSMutableParagraphStyle class]) {
        if ([coder containsValueForKey:NSStringFromSelector(@selector(linkAttributes))]) {
            self.linkAttributes = [coder decodeObjectForKey:NSStringFromSelector(@selector(linkAttributes))];
        }

        if ([coder containsValueForKey:NSStringFromSelector(@selector(activeLinkAttributes))]) {
            self.activeLinkAttributes = [coder decodeObjectForKey:NSStringFromSelector(@selector(activeLinkAttributes))];
        }

        if ([coder containsValueForKey:NSStringFromSelector(@selector(inactiveLinkAttributes))]) {
            self.inactiveLinkAttributes = [coder decodeObjectForKey:NSStringFromSelector(@selector(inactiveLinkAttributes))];
        }
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(links))]) {
        NSArray *oldLinks = [coder decodeObjectForKey:NSStringFromSelector(@selector(links))];
        [self addLinksWithTextCheckingResults:oldLinks attributes:nil];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(linkModels))]) {
        self.linkModels = [coder decodeObjectForKey:NSStringFromSelector(@selector(linkModels))];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(shadowRadius))]) {
        self.shadowRadius = [[coder decodeObjectForKey:NSStringFromSelector(@selector(shadowRadius))] floatValue];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(highlightedShadowRadius))]) {
        self.highlightedShadowRadius = [[coder decodeObjectForKey:NSStringFromSelector(@selector(highlightedShadowRadius))] floatValue];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(highlightedShadowOffset))]) {
        self.highlightedShadowOffset = [coder decodeCGSizeForKey:NSStringFromSelector(@selector(highlightedShadowOffset))];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(highlightedShadowColor))]) {
        self.highlightedShadowColor = [coder decodeObjectForKey:NSStringFromSelector(@selector(highlightedShadowColor))];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(kern))]) {
        self.kern = [[coder decodeObjectForKey:NSStringFromSelector(@selector(kern))] floatValue];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(firstLineIndent))]) {
        self.firstLineIndent = [[coder decodeObjectForKey:NSStringFromSelector(@selector(firstLineIndent))] floatValue];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(lineSpacing))]) {
        self.lineSpacing = [[coder decodeObjectForKey:NSStringFromSelector(@selector(lineSpacing))] floatValue];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(minimumLineHeight))]) {
        self.minimumLineHeight = [[coder decodeObjectForKey:NSStringFromSelector(@selector(minimumLineHeight))] floatValue];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(maximumLineHeight))]) {
        self.maximumLineHeight = [[coder decodeObjectForKey:NSStringFromSelector(@selector(maximumLineHeight))] floatValue];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(lineHeightMultiple))]) {
        self.lineHeightMultiple = [[coder decodeObjectForKey:NSStringFromSelector(@selector(lineHeightMultiple))] floatValue];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(textInsets))]) {
        self.textInsets = [coder decodeUIEdgeInsetsForKey:NSStringFromSelector(@selector(textInsets))];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(verticalAlignment))]) {
        self.verticalAlignment = [coder decodeIntegerForKey:NSStringFromSelector(@selector(verticalAlignment))];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(attributedTruncationToken))]) {
        self.attributedTruncationToken = [coder decodeObjectForKey:NSStringFromSelector(@selector(attributedTruncationToken))];
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(linkBackgroundEdgeInset))]) {
        self.linkBackgroundEdgeInset = UIEdgeInsetsFromString([coder decodeObjectForKey:NSStringFromSelector(@selector(linkBackgroundEdgeInset))]);
    }

    if ([coder containsValueForKey:NSStringFromSelector(@selector(attributedText))]) {
        self.attributedText = [coder decodeObjectForKey:NSStringFromSelector(@selector(attributedText))];
    } else {
        self.text = super.text;
    }

    return self;
}

@end

#pragma mark - BITAttributedLabelLink

@implementation BITAttributedLabelLink

- (instancetype)initWithAttributes:(NSDictionary *)attributes
                  activeAttributes:(NSDictionary *)activeAttributes
                inactiveAttributes:(NSDictionary *)inactiveAttributes
                textCheckingResult:(NSTextCheckingResult *)result {

    if ((self = [super init])) {
        _result = result;
        _attributes = [attributes copy];
        _activeAttributes = [activeAttributes copy];
        _inactiveAttributes = [inactiveAttributes copy];
    }

    return self;
}

- (instancetype)initWithAttributesFromLabel:(BITAttributedLabel*)label
                         textCheckingResult:(NSTextCheckingResult *)result {

    return [self initWithAttributes:label.linkAttributes
                   activeAttributes:label.activeLinkAttributes
                 inactiveAttributes:label.inactiveLinkAttributes
                 textCheckingResult:result];
}

#pragma mark - Accessibility

- (NSString *) accessibilityValue {
    if ([_accessibilityValue length] == 0) {
        switch (self.result.resultType) {
            case NSTextCheckingTypeLink:
                _accessibilityValue = self.result.URL.absoluteString;
                break;
            case NSTextCheckingTypePhoneNumber:
                _accessibilityValue = self.result.phoneNumber;
                break;
            case NSTextCheckingTypeDate:
                _accessibilityValue = [NSDateFormatter localizedStringFromDate:self.result.date
                                                                     dateStyle:NSDateFormatterLongStyle
                                                                     timeStyle:NSDateFormatterLongStyle];
                break;
            default:
                break;
        }
    }

    return _accessibilityValue;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.result forKey:NSStringFromSelector(@selector(result))];
    [aCoder encodeObject:self.attributes forKey:NSStringFromSelector(@selector(attributes))];
    [aCoder encodeObject:self.activeAttributes forKey:NSStringFromSelector(@selector(activeAttributes))];
    [aCoder encodeObject:self.inactiveAttributes forKey:NSStringFromSelector(@selector(inactiveAttributes))];
    [aCoder encodeObject:self.accessibilityValue forKey:NSStringFromSelector(@selector(accessibilityValue))];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super init])) {
        _result = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(result))];
        _attributes = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(attributes))];
        _activeAttributes = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(activeAttributes))];
        _inactiveAttributes = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(inactiveAttributes))];
        self.accessibilityValue = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(accessibilityValue))];
    }

    return self;
}

@end

#pragma mark -

static inline CGColorRef CGColorRefFromColor(id color) {
    return [color isKindOfClass:[UIColor class]] ? [color CGColor] : (__bridge CGColorRef)color;
}

static inline CTFontRef CTFontRefFromUIFont(UIFont * font) {
    CTFontRef ctfont = CTFontCreateWithName((__bridge CFStringRef)font.fontName, font.pointSize, NULL);
    return CFAutorelease(ctfont);
}

static inline NSDictionary * convertNSAttributedStringAttributesToCTAttributes(NSDictionary *attributes) {
    if (!attributes) return nil;
    
    NSMutableDictionary *mutableAttributes = [NSMutableDictionary dictionary];
    
    NSDictionary *NSToCTAttributeNamesMap = @{
                                              NSFontAttributeName:            (NSString *)kCTFontAttributeName,
                                              NSBackgroundColorAttributeName: (NSString *)kBITBackgroundFillColorAttributeName,
                                              NSForegroundColorAttributeName: (NSString *)kCTForegroundColorAttributeName,
                                              NSUnderlineColorAttributeName:  (NSString *)kCTUnderlineColorAttributeName,
                                              NSUnderlineStyleAttributeName:  (NSString *)kCTUnderlineStyleAttributeName,
                                              NSStrokeWidthAttributeName:     (NSString *)kCTStrokeWidthAttributeName,
                                              NSStrokeColorAttributeName:     (NSString *)kCTStrokeWidthAttributeName,
                                              NSKernAttributeName:            (NSString *)kCTKernAttributeName,
                                              NSLigatureAttributeName:        (NSString *)kCTLigatureAttributeName
                                              };
    
    [attributes enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        key = [NSToCTAttributeNamesMap objectForKey:key] ? : key;
        
        if (![NSMutableParagraphStyle class]) {
            if ([value isKindOfClass:[UIFont class]]) {
                value = (__bridge id)CTFontRefFromUIFont(value);
            } else if ([value isKindOfClass:[UIColor class]]) {
                value = (__bridge id)((UIColor *)value).CGColor;
            }
        }
        
        [mutableAttributes setObject:value forKey:key];
    }];
    
    return [NSDictionary dictionaryWithDictionary:mutableAttributes];
}

#pragma clang diagnostic pop

#endif
