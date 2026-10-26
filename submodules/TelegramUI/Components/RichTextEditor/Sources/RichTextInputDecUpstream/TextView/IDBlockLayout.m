#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDBlockLayout.h"

#import "IDBlockDocument.h"
#import "IDBlockLayoutSnapshot.h"
#import "IDBlockTextGeometry.h"
#import "IDPrivateUIKit.h"
#import "IDRichTextSelectionRect.h"
#import "IDTextLayoutCanvasView.h"

@import CoreText;

#include <math.h>

@interface IDBlockLayout ()

@property(nonatomic, copy, readwrite) NSUUID *blockIdentifier;
@property(nonatomic, strong, readwrite) NSTextContentStorage *contentStorage;
@property(nonatomic, strong) NSTextLayoutManager *blockLayoutManager;
@property(nonatomic, strong, readwrite) NSTextContainer *textContainer;
@property(nonatomic, strong) IDBlockTextGeometry *textGeometry;
@property(nonatomic, strong, readwrite) IDTextLayoutCanvasView *canvasView;
@property(nonatomic, readwrite) CGSize usedSize;
@property(nonatomic, readwrite) NSUInteger contentRevision;
@property(nonatomic, readwrite) NSUInteger layoutGeneration;
@property(nonatomic, copy)
    NSDictionary<NSAttributedStringKey, id> *emptyTextAttributes;
@property(nonatomic) CGPoint canvasBoundsOrigin;
/// Attributes an EMPTY block's line is measured with, and the prototype built from them. An empty
/// text storage carries no attributes at all, so nothing about the intended line — neither the font
/// nor a pinned paragraph line height — is reachable from it.
@property(nonatomic, copy, nullable) NSDictionary<NSAttributedStringKey, id> *id_emptyLineAttributes;
@property(nonatomic, strong, nullable) NSTextContentStorage *id_emptyLinePrototypeStorage;
@property(nonatomic, strong, nullable) NSTextLayoutManager *id_emptyLinePrototypeLayout;
@property(nonatomic, strong, nullable) NSTextContainer *id_emptyLinePrototypeContainer;
@property(nonatomic, strong, nullable) IDBlockTextGeometry *id_emptyLinePrototypeGeometry;
@property(nonatomic, copy, nullable) NSDictionary<NSAttributedStringKey, id> *id_emptyLinePrototypeAttributes;
@property(nonatomic) CGFloat id_emptyLinePrototypeWidth;
@property(nonatomic) CGFloat id_emptyLinePrototypePadding;
@property(nonatomic, weak, nullable) id canvasHost;

@end

// `IDBlockLayout+PrivateCanvasCallbacks.m`: adds the canvas context's callbacks, which TextKit's
// private rendering path sends under private names.
FOUNDATION_EXTERN void IDBlockLayoutInstallPrivateCallbacks(Class cls);

@implementation IDBlockLayout

+ (void)initialize {
    IDBlockLayoutInstallPrivateCallbacks(self);
}

@dynamic layoutManager;

- (instancetype)initWithBlock:(IDBlock *)block width:(CGFloat)width {
    if (block == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"IDBlockLayout requires a block."];
    }

    self = [super init];
    if (self == nil) {
        return nil;
    }

    _blockIdentifier = [block.identifier copy];
    _emptyTextAttributes = [block.separatorAttributes copy];
    _contentStorage = [NSTextContentStorage new];
    _contentStorage.textStorage = [[NSTextStorage alloc]
        initWithAttributedString:block.attributedText];
    // The decorator is set by the canvas immediately after construction, so a freshly created block
    // is decorated by the `updateContentFromBlock:` that follows rather than here.
    _blockLayoutManager = [NSTextLayoutManager new];
    // A pinned line box (`minimumLineHeight == maximumLineHeight`) clamps a run's ascent and
    // descent, but the substituted face's LEADING is added on top of the clamped box and no
    // paragraph-style property reaches it. Latin declares none, so the pin looked absolute until a
    // run substituted a face that does: at 17pt body against a 21pt box, Arabic laid out at 22.1621
    // and Thai at 22.1355, PER LINE. The host's renderer advances on a grid derived from the
    // paragraph's own font and never reads a substituted run's metrics, so the two diverged and a
    // composer field grew as soon as Arabic was typed into it. See `RichTextFontLeading` in
    // RichTextEditorUIKit, which states the rule for the two layouts above this module.
    _blockLayoutManager.usesFontLeading = NO;
    [_contentStorage addTextLayoutManager:_blockLayoutManager];
    _textContainer = [[NSTextContainer alloc] initWithSize:CGSizeZero];
    _blockLayoutManager.textContainer = _textContainer;
    _textGeometry = [[IDBlockTextGeometry alloc]
        initWithContentStorage:_contentStorage
                 layoutManager:_blockLayoutManager
                 textContainer:_textContainer];
    _canvasView = [[IDTextLayoutCanvasView alloc]
        initWithTextLayoutManager:_blockLayoutManager
                    textContainer:_textContainer];
    _canvasView.context = self;
    IDPrivateTextContainerSetTextView(_textContainer, _canvasView);
    (void)[self updateLayoutFromBlock:block width:width];
    _contentRevision = 1;
    _layoutGeneration = 1;
    return self;
}

- (void)updateFromBlock:(IDBlock *)block width:(CGFloat)width {
    BOOL contentChanged = [self updateContentFromBlock:block];
    BOOL layoutChanged = [self updateLayoutFromBlock:block width:width];
    [self id_advanceRevisionsForContentChange:contentChanged
                                 layoutChange:layoutChanged];
}

- (void)id_requireMatchingBlock:(IDBlock *)block {
    if (![block.identifier isEqual:self.blockIdentifier]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"IDBlockLayout %@ cannot display block %@",
                           self.blockIdentifier.UUIDString,
                           block.identifier.UUIDString];
    }
}

/// The block's text as it should be DRAWN.
- (NSAttributedString *)id_displayTextForBlock:(IDBlock *)block {
    IDBlockTextDisplayDecorator decorator = self.displayDecorator;
    if (decorator == nil) {
        return block.attributedText;
    }
    return decorator(block.attributedText, self.blockIdentifier) ?: block.attributedText;
}

- (BOOL)updateContentFromBlock:(IDBlock *)block {
    [self id_requireMatchingBlock:block];
    // Compare against the DECORATED text, not the block's. Comparing against the block's would report
    // "changed" on every pass whenever a decorator is installed, and would miss a change that is
    // purely decorative — the selection moving over a spoiler, which is the case this exists for.
    NSAttributedString *displayText = [self id_displayTextForBlock:block];
    BOOL textChanged = ![self.contentStorage.textStorage
        isEqualToAttributedString:displayText];
    BOOL separatorChanged = ![self.emptyTextAttributes
        isEqualToDictionary:block.separatorAttributes];
    if (textChanged) {
        [self.contentStorage.textStorage setAttributedString:displayText];
    }
    if (separatorChanged) {
        self.emptyTextAttributes = block.separatorAttributes;
    }
    return textChanged || separatorChanged;
}

- (BOOL)updateLayoutFromBlock:(IDBlock *)block width:(CGFloat)width {
    [self id_requireMatchingBlock:block];
    CGSize previousContainerSize = self.textContainer.size;
    CGSize previousUsedSize = self.usedSize;
    CGPoint previousCanvasBoundsOrigin = self.canvasBoundsOrigin;
    CGFloat layoutWidth = isfinite(width) ? MAX(width, 0) : 0;
    CGSize containerSize = CGSizeMake(layoutWidth, CGFLOAT_MAX);
    if (!CGSizeEqualToSize(self.textContainer.size, containerSize)) {
        self.textContainer.size = containerSize;
    }
    [self.layoutManager ensureLayoutForRange:self.contentStorage.documentRange];

    CGRect usageBounds = CGRectStandardize(self.layoutManager.usageBoundsForTextContainer);
    CGFloat usedWidth = 0;
    CGFloat usedHeight = 0;
    CGPoint canvasBoundsOrigin = CGPointZero;
    CGFloat minimumX = CGRectGetMinX(usageBounds);
    CGFloat minimumY = CGRectGetMinY(usageBounds);
    CGFloat maximumX = CGRectGetMaxX(usageBounds);
    CGFloat maximumY = CGRectGetMaxY(usageBounds);
    if (isfinite(minimumX) && isfinite(minimumY) &&
        isfinite(maximumX) && isfinite(maximumY)) {
        minimumX = MIN(minimumX, 0);
        minimumY = MIN(minimumY, 0);
        maximumX = MAX(maximumX, 0);
        maximumY = MAX(maximumY, 0);
        usedWidth = maximumX - minimumX;
        usedHeight = maximumY - minimumY;
        canvasBoundsOrigin = CGPointMake(minimumX, minimumY);
    }
    if (block.attributedText.length == 0) {
        // The host's own answer for this block wins over the separator's.
        //
        // The separator is the newline that FOLLOWS the block, so the LAST block has none and falls
        // back to the document's defaults — an empty trailing line was measured in the default font
        // and its caret placed at the container's leading edge, whatever the line was going to be.
        // Nothing about the intended line is recoverable from an empty string, so it has to be told.
        NSDictionary<NSAttributedStringKey, id> *intended =
            self.id_hostEmptyLineAttributes.count > 0
                ? self.id_hostEmptyLineAttributes
                : block.separatorAttributes;
        UIFont *font = intended[NSFontAttributeName];
        if (![font isKindOfClass:UIFont.class]) {
            font = [UIFont systemFontOfSize:17.0];
        }
        self.id_emptyLineAttributes = intended;
        // The line a real character WOULD produce with these attributes, which is the only way to
        // honour a pinned paragraph line height: `font.lineHeight` ignores it, so a block whose style
        // pins a taller line came out short and its caret with it.
        CGFloat prototypeHeight = [self id_emptyLinePrototypeLineHeightForWidth:layoutWidth];
        usedHeight = prototypeHeight > 0.0 ? prototypeHeight : font.lineHeight;
        canvasBoundsOrigin = CGPointZero;
    } else {
        self.id_emptyLineAttributes = nil;
    }
    self.usedSize = CGSizeMake(usedWidth, usedHeight);
    self.canvasBoundsOrigin = canvasBoundsOrigin;
    return !CGSizeEqualToSize(previousContainerSize, containerSize) ||
        !CGSizeEqualToSize(previousUsedSize, self.usedSize) ||
        !CGPointEqualToPoint(previousCanvasBoundsOrigin,
                             self.canvasBoundsOrigin);
}

- (void)id_advanceRevisionsForContentChange:(BOOL)contentChanged
                               layoutChange:(BOOL)layoutChanged {
    if (contentChanged) {
        self.contentRevision += 1;
    }
    if (contentChanged || layoutChanged) {
        self.layoutGeneration += 1;
    }
}

- (id<NSTextLocation>)locationForLocalOffset:(NSUInteger)offset {
    NSUInteger length = self.contentStorage.textStorage.length;
    if (offset > length) {
        return nil;
    }
    return [self.contentStorage locationFromLocation:self.contentStorage.documentRange.location
                                         withOffset:(NSInteger)offset];
}

- (NSUInteger)localOffsetForLocation:(id<NSTextLocation>)location {
    if (location == nil) {
        return NSNotFound;
    }
    @try {
        NSInteger offset = [self.contentStorage
            offsetFromLocation:self.contentStorage.documentRange.location
                    toLocation:location];
        if (offset < 0 || (NSUInteger)offset > self.contentStorage.textStorage.length) {
            return NSNotFound;
        }
        id<NSTextLocation> expected = [self locationForLocalOffset:(NSUInteger)offset];
        if (expected == nil || [expected compare:location] != NSOrderedSame) {
            return NSNotFound;
        }
        return (NSUInteger)offset;
    } @catch (__unused NSException *exception) {
        return NSNotFound;
    }
}

- (CGRect)caretRectForLocalOffset:(NSUInteger)offset
                         affinity:(UITextStorageDirection)affinity {
    if (self.contentStorage.textStorage.length == 0) {
        // An empty storage has no attributes for TextKit to size an insertion point from, so it falls
        // back to a system default and the caret comes out visibly shorter than on a typed line. Take
        // it from a prototype laid out with the attributes this line WOULD have instead.
        CGRect prototype = [self id_emptyLineInsertionRect];
        if (!CGRectIsNull(prototype)) {
            return prototype;
        }
    }
    id<NSTextLocation> location = [self locationForLocalOffset:offset];
    if (location == nil) return CGRectNull;
    return [self.textGeometry insertionRectForLocation:location affinity:affinity];
}

/// A one-space line laid out with `id_emptyLineAttributes`, cached until those or the width change.
/// Built rather than derived, because the intended height can come from the font OR from a pinned
/// paragraph line height, and replicating TextKit's choice between them would be a guess.
- (nullable NSTextLayoutManager *)id_emptyLinePrototypeForWidth:(CGFloat)width {
    NSDictionary<NSAttributedStringKey, id> *attributes = self.id_emptyLineAttributes;
    if (attributes[NSFontAttributeName] == nil) {
        return nil;
    }
    // The padding is part of the KEY, not just of the build. It decides where the line begins, and a
    // host may change it after a prototype has been cached — the composer sets it to zero — leaving a
    // stale prototype whose caret sat one padding to the right of where a typed line's caret starts.
    CGFloat padding = self.textContainer.lineFragmentPadding;
    if (self.id_emptyLinePrototypeLayout != nil &&
        self.id_emptyLinePrototypeWidth == width &&
        self.id_emptyLinePrototypePadding == padding &&
        [self.id_emptyLinePrototypeAttributes isEqualToDictionary:attributes]) {
        return self.id_emptyLinePrototypeLayout;
    }
    NSTextContentStorage *storage = [NSTextContentStorage new];
    storage.textStorage = [[NSTextStorage alloc]
        initWithAttributedString:[[NSAttributedString alloc] initWithString:@" "
                                                                attributes:attributes]];
    NSTextLayoutManager *layout = [NSTextLayoutManager new];
    // The same rule as the block layout above, and it must be set here too: this prototype is what
    // an EMPTY line's height is measured from, so a prototype on a different grid than the typed
    // lines around it would reintroduce the divergence for exactly the blank paragraphs.
    layout.usesFontLeading = NO;
    [storage addTextLayoutManager:layout];
    NSTextContainer *container =
        [[NSTextContainer alloc] initWithSize:CGSizeMake(MAX(width, 0), CGFLOAT_MAX)];
    container.lineFragmentPadding = padding;
    layout.textContainer = container;
    [layout ensureLayoutForRange:storage.documentRange];

    self.id_emptyLinePrototypeStorage = storage;
    self.id_emptyLinePrototypeLayout = layout;
    self.id_emptyLinePrototypeContainer = container;
    self.id_emptyLinePrototypeGeometry =
        [[IDBlockTextGeometry alloc] initWithContentStorage:storage
                                             layoutManager:layout
                                             textContainer:container];
    self.id_emptyLinePrototypeAttributes = attributes;
    self.id_emptyLinePrototypeWidth = width;
    self.id_emptyLinePrototypePadding = padding;
    return layout;
}

- (CGFloat)id_emptyLinePrototypeLineHeightForWidth:(CGFloat)width {
    NSTextLayoutManager *layout = [self id_emptyLinePrototypeForWidth:width];
    if (layout == nil) {
        return 0.0;
    }
    return CGRectGetHeight(CGRectStandardize(layout.usageBoundsForTextContainer));
}

- (CGRect)id_emptyLineInsertionRect {
    NSTextLayoutManager *layout =
        [self id_emptyLinePrototypeForWidth:self.textContainer.size.width];
    IDBlockTextGeometry *geometry = self.id_emptyLinePrototypeGeometry;
    if (layout == nil || geometry == nil) {
        return CGRectNull;
    }
    // Through the SAME insertion-rect path a real line uses, not a raw line-fragment frame. A
    // fragment's origin is where the line begins; an insertion rect is CENTRED on the insertion point
    // and has the caret's width. Returning the fragment gave a zero-width rect half a point to the
    // right, which at zero container padding sits against the container's edge and draws clipped.
    CGRect rect =
        [geometry insertionRectForLocation:layout.textContentManager.documentRange.location
                                  affinity:UITextStorageDirectionForward];
    if (!CGRectIsNull(rect)) {
        rect.origin.x += self.id_hostEmptyLineCaretOffset;
    }
    return rect;
}

- (CGRect)attachmentFrameForLocalOffset:(NSUInteger)offset {
    id<NSTextLocation> location = [self locationForLocalOffset:offset];
    if (location == nil) {
        return CGRectNull;
    }
    __block CGRect result = CGRectNull;
    [self.blockLayoutManager
        enumerateTextLayoutFragmentsFromLocation:location
                                         options:NSTextLayoutFragmentEnumerationOptionsEnsuresLayout
                                      usingBlock:^BOOL(NSTextLayoutFragment *fragment) {
        CGRect frame = [fragment frameForTextAttachmentAtLocation:location];
        if (!CGRectIsNull(frame) && !CGRectIsEmpty(frame)) {
            // Fragment-relative, like everything else this class returns block-locally.
            result = CGRectOffset(frame, fragment.layoutFragmentFrame.origin.x,
                                  fragment.layoutFragmentFrame.origin.y);
        }
        return NO;
    }];
    return result;
}

- (CGRect)boundingRectForLocalRange:(NSRange)range {
    return [self.textGeometry boundingRectForLocalRange:range];
}

- (NSArray<IDRichTextSelectionRect *> *)selectionRectsForLocalRange:(NSRange)range {
    return [self selectionRectsForLocalRange:range extendHead:NO extendTail:NO];
}

- (NSArray<IDRichTextSelectionRect *> *)selectionRectsForLocalRange:(NSRange)range
                                                         extendHead:(BOOL)extendHead
                                                         extendTail:(BOOL)extendTail {
    return [self.textGeometry selectionRectsForLocalRange:range
                                                extendHead:extendHead
                                                extendTail:extendTail];
}

- (NSArray<IDBlockSelectionSegment *> *)selectionSegmentsForLocalRange:
    (NSRange)range
                                                            extendHead:
    (BOOL)extendHead
                                                            extendTail:
    (BOOL)extendTail {
    NSArray<IDBlockSelectionSegment *> *segments =
        [self.textGeometry selectionSegmentsForLocalRange:range
                                               extendHead:extendHead
                                               extendTail:extendTail
                                         layoutGeneration:self.layoutGeneration];
    // A break MARK on an EMPTY line takes THE LINE, and this is the level that knows what that is.
    //
    // The mark stands for the paragraph break a selection ends on. Measured in the geometry it is
    // the GLYPH box, which is neither the line nor the box around it, so the mark read small beside
    // the full-width fill the same line gets from a pass-through selection and the handle sat high.
    //
    // The line is NOT `usedSize` either, and using it put the mark's top into the line above
    // (device, 2026-09-15). `usedSize` is the PINNED BOX — `pitch`, which the stylesheet sets as
    // minimum == maximum line height — and a pinned box is the line PLUS the spacing that separates
    // it from its neighbour. TextKit bottom-aligns the line inside that box, the baseline sitting
    // one descender above its bottom, so the spacing is all at the TOP and that is what reached up.
    // Measured here: box 23.00, ascender 16.19, descender -4.10, so the line is 20.29 and the 2.71
    // above it belongs between the blocks.
    //
    // So: bottom-aligned, `ascender - descender` tall. An empty block is one line by definition,
    // which is what lets `usedSize` stand in for the box; nothing a level down can say any of this
    // (four sources measured there, all short or silent).
    if (self.contentStorage.textStorage.length != 0 || segments.count != 1 ||
        range.length != 0 || !extendHead || extendTail) {
        return segments;
    }
    IDBlockSelectionSegment *mark = segments.firstObject;
    if (mark == nil) {
        return segments;
    }
    UIFont *lineFont = self.id_hostEmptyLineAttributes[NSFontAttributeName];
    CGFloat box = self.usedSize.height;
    CGFloat lineHeight = lineFont != nil ? (lineFont.ascender - lineFont.descender) : 0.0;
    if (lineHeight <= 0.0 || lineHeight > box || lineHeight <= CGRectGetHeight(mark.rect)) {
        return segments;
    }
    CGRect stretched = CGRectMake(CGRectGetMinX(mark.rect), box - lineHeight,
                                  CGRectGetWidth(mark.rect), lineHeight);
    return @[[[IDBlockSelectionSegment alloc]
        initWithLocalRange:mark.localRange
                      rect:stretched
            baselineOffset:mark.baselineOffset
              boundaryRole:mark.boundaryRole
        containsLocalStart:mark.containsLocalStart
          containsLocalEnd:mark.containsLocalEnd
          writingDirection:mark.writingDirection
                  vertical:mark.isVertical
          layoutGeneration:mark.layoutGeneration]];
}

- (NSUInteger)nearestLocalOffsetForPoint:(CGPoint)point {
    [self.layoutManager ensureLayoutForRange:self.contentStorage.documentRange];
    IDBlockCaretStop stop = [self caretStopForPoint:point];
    if (stop.found) return stop.localOffset;
    return point.y <= 0 ? 0 : self.contentStorage.textStorage.length;
}

- (IDBlockCaretStop)caretStopForPoint:(CGPoint)point {
    return [self.textGeometry caretStopForPoint:point];
}

- (NSRange)localLineRangeEnclosingOffset:(NSUInteger)offset
                        effectiveAffinity:(UITextStorageDirection *)affinity {
    NSUInteger length = self.contentStorage.textStorage.length;
    if (offset > length) return NSMakeRange(NSNotFound, 0);
    if (length == 0) {
        if (affinity != NULL) *affinity = UITextStorageDirectionForward;
        return NSMakeRange(0, 0);
    }
    UITextStorageDirection resolved = affinity == NULL
        ? UITextStorageDirectionForward
        : *affinity;
    id<NSTextLocation> location = [self locationForLocalOffset:offset];
    NSTextLayoutFragment *fragment = [self.layoutManager textLayoutFragmentForLocation:location];
    NSTextLineFragment *line = [fragment textLineFragmentForTextLocation:location
                                                       isUpstreamAffinity:
        resolved == UITextStorageDirectionBackward];
    if (line == nil && offset == length) {
        resolved = UITextStorageDirectionBackward;
        line = [fragment textLineFragmentForTextLocation:location isUpstreamAffinity:YES];
    }
    if (affinity != NULL) *affinity = resolved;
    if (line == nil) return NSMakeRange(offset, 0);
    NSRange result = line.characterRange;
    if (result.location > length) return NSMakeRange(offset, 0);
    result.length = MIN(result.length, length - result.location);
    return result;
}

static NSWritingDirection IDBlockDirectionForRun(CTRunRef run) {
    return (CTRunGetStatus(run) & kCTRunStatusRightToLeft) != 0
        ? NSWritingDirectionRightToLeft
        : NSWritingDirectionLeftToRight;
}

- (NSAttributedString *)id_coreTextParagraphAtOffset:(NSUInteger)offset
                                                range:(NSRange *)range {
    NSString *string = self.contentStorage.textStorage.string;
    if (string.length == 0) {
        if (range != NULL) *range = NSMakeRange(0, 0);
        return [[NSAttributedString alloc] initWithString:@""];
    }
    NSUInteger probe = MIN(offset, string.length - 1);
    NSRange paragraph = [string paragraphRangeForRange:NSMakeRange(probe, 0)];
    paragraph.length = MIN(paragraph.length, string.length - paragraph.location);
    if (range != NULL) *range = paragraph;
    return [self.contentStorage.textStorage attributedSubstringFromRange:paragraph];
}

- (NSWritingDirection)baseWritingDirectionAtLocalOffset:(NSUInteger)offset {
    NSString *string = self.contentStorage.textStorage.string;
    if (string.length == 0) return NSWritingDirectionLeftToRight;
    NSUInteger probe = MIN(offset, string.length - 1);
    NSParagraphStyle *style = [self.contentStorage.textStorage
        attribute:NSParagraphStyleAttributeName
        atIndex:probe
        effectiveRange:NULL];
    if (style != nil && style.baseWritingDirection != NSWritingDirectionNatural) {
        return style.baseWritingDirection;
    }

    NSRange paragraphRange = NSMakeRange(0, 0);
    NSMutableAttributedString *paragraph =
        [[self id_coreTextParagraphAtOffset:offset range:&paragraphRange] mutableCopy];
    NSMutableParagraphStyle *naturalStyle = style.mutableCopy ?: [NSMutableParagraphStyle new];
    naturalStyle.alignment = NSTextAlignmentNatural;
    naturalStyle.baseWritingDirection = NSWritingDirectionNatural;
    [paragraph addAttribute:NSParagraphStyleAttributeName
                      value:naturalStyle
                      range:NSMakeRange(0, paragraph.length)];

    CTFramesetterRef framesetter =
        CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)paragraph);
    CGMutablePathRef path = CGPathCreateMutable();
    const CGFloat probeWidth = 16384.0;
    CGPathAddRect(path, NULL, CGRectMake(0, 0, probeWidth, 4096.0));
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter,
                                                CFRangeMake(0, paragraph.length),
                                                path,
                                                NULL);
    NSArray *lines = (__bridge NSArray *)CTFrameGetLines(frame);
    NSWritingDirection result = NSWritingDirectionLeftToRight;
    if (lines.count > 0) {
        CTLineRef line = (__bridge CTLineRef)lines.firstObject;
        CGPoint origin = CGPointZero;
        CTFrameGetLineOrigins(frame, CFRangeMake(0, 1), &origin);
        CGFloat width = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
        result = origin.x > MAX(1.0, (probeWidth - width) * 0.5)
            ? NSWritingDirectionRightToLeft
            : NSWritingDirectionLeftToRight;
    }
    CFRelease(frame);
    CGPathRelease(path);
    CFRelease(framesetter);
    return result;
}

- (NSWritingDirection)resolvedWritingDirectionAtLocalOffset:(NSUInteger)offset {
    NSString *string = self.contentStorage.textStorage.string;
    if (string.length == 0) return NSWritingDirectionLeftToRight;
    NSRange paragraphRange = NSMakeRange(0, 0);
    NSAttributedString *paragraph = [self id_coreTextParagraphAtOffset:offset
                                                                 range:&paragraphRange];
    CTLineRef line = CTLineCreateWithAttributedString(
        (__bridge CFAttributedStringRef)paragraph);
    NSArray *runs = (__bridge NSArray *)CTLineGetGlyphRuns(line);
    NSUInteger probe = MIN(offset, string.length - 1) - paragraphRange.location;
    NSWritingDirection result = [self baseWritingDirectionAtLocalOffset:offset];
    for (id value in runs) {
        CTRunRef run = (__bridge CTRunRef)value;
        CFRange runRange = CTRunGetStringRange(run);
        if (runRange.location != kCFNotFound &&
            probe >= (NSUInteger)runRange.location &&
            probe < (NSUInteger)(runRange.location + runRange.length)) {
            result = IDBlockDirectionForRun(run);
            break;
        }
    }
    CFRelease(line);
    return result;
}

- (NSUInteger)visuallyAdjacentLocalOffsetFromOffset:(NSUInteger)offset
                                            affinity:(UITextStorageDirection)affinity
                                           direction:(UITextLayoutDirection)direction
                                    resultingAffinity:(UITextStorageDirection *)resultingAffinity {
    IDBlockCaretStop stop = [self caretStopFromLocalOffset:offset
                                                   affinity:affinity
                                                  direction:direction
                                       anchorPositionOffset:0.0];
    if (!stop.found) return NSNotFound;
    if (resultingAffinity != NULL) *resultingAffinity = stop.affinity;
    return stop.localOffset;
}

- (IDBlockCaretStop)caretStopFromLocalOffset:(NSUInteger)offset
                                     affinity:(UITextStorageDirection)affinity
                                    direction:(UITextLayoutDirection)direction
                         anchorPositionOffset:(CGFloat)anchorPositionOffset {
    id<NSTextLocation> location = [self locationForLocalOffset:offset];
    if (location == nil) {
        return (IDBlockCaretStop){ .found = NO };
    }
    return [self.textGeometry caretStopForLocation:location
                                          affinity:affinity
                                         direction:direction
                              anchorPositionOffset:anchorPositionOffset];
}

- (NSDictionary<NSAttributedStringKey, id> *)attributesAtLocalOffset:(NSUInteger)offset
                                                            direction:(UITextStorageDirection)direction {
    NSUInteger length = self.contentStorage.textStorage.length;
    if (length == 0) return self.emptyTextAttributes ?: @{};
    NSUInteger index = direction == UITextStorageDirectionBackward && offset > 0
        ? offset - 1
        : MIN(offset, length - 1);
    return [self.contentStorage.textStorage attributesAtIndex:index effectiveRange:NULL];
}

- (id)id_canvasHost {
    return self.canvasHost;
}

- (NSTextLayoutManager *)id_blockLayoutManager {
    return self.blockLayoutManager;
}

- (CGPoint)id_textContainerOrigin {
    return CGPointZero;
}

- (CGPoint)id_canvasBoundsOrigin {
    return self.canvasBoundsOrigin;
}

- (void)id_setCanvasHost:(id)host {
    self.canvasHost = host;
}

@end

#endif
