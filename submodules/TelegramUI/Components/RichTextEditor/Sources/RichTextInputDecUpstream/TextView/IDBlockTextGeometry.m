#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDBlockTextGeometry.h"

#import "IDBlockLayoutSnapshot.h"
#import "IDRichTextSelectionRect.h"

#include <math.h>

@interface IDBlockTextGeometry ()

@property(nonatomic, strong) NSTextContentStorage *contentStorage;
@property(nonatomic, strong) NSTextLayoutManager *layoutManager;
@property(nonatomic, strong) NSTextContainer *textContainer;

@end

@implementation IDBlockTextGeometry

static BOOL IDBlockTextGeometryRectIsFinite(CGRect rect) {
    return !CGRectIsNull(rect) &&
        isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height);
}

static IDBlockCaretStop IDBlockCaretStopNotFound(void) {
    return (IDBlockCaretStop){
        .localOffset = 0,
        .affinity = UITextStorageDirectionForward,
        .anchorPositionOffset = 0.0,
        .found = NO,
    };
}

- (nullable NSTextSelection *)id_normalizedSelectionForLocation:(id<NSTextLocation>)location
                                                        affinity:(UITextStorageDirection)affinity {
    NSTextRange *range = [[NSTextRange alloc] initWithLocation:location
                                                  endLocation:location];
    NSTextSelectionAffinity selectionAffinity =
        affinity == UITextStorageDirectionForward
            ? NSTextSelectionAffinityDownstream
            : NSTextSelectionAffinityUpstream;
    NSTextSelection *selection = [[NSTextSelection alloc]
        initWithRanges:@[range]
              affinity:selectionAffinity
           granularity:NSTextSelectionGranularityCharacter];
    self.layoutManager.textSelections = @[selection];
    NSTextSelection *normalizedSelection = self.layoutManager.textSelections.firstObject;
    return normalizedSelection.textRanges.count == 1 &&
            normalizedSelection.textRanges.firstObject.empty
        ? normalizedSelection
        : nil;
}

- (IDBlockCaretStop)id_caretStopForSelection:(nullable NSTextSelection *)selection {
    if (selection.textRanges.count != 1) {
        return IDBlockCaretStopNotFound();
    }
    NSTextRange *range = selection.textRanges.firstObject;
    if (!range.empty) {
        return IDBlockCaretStopNotFound();
    }

    @try {
        NSTextRange *documentRange = self.contentStorage.documentRange;
        id<NSTextLocation> destinationLocation =
            selection.affinity == NSTextSelectionAffinityUpstream
                ? selection.textRanges.firstObject.location
                : selection.textRanges.lastObject.endLocation;
        NSInteger destinationOffset = [self.contentStorage
            offsetFromLocation:documentRange.location
                    toLocation:destinationLocation];
        NSUInteger length = self.contentStorage.textStorage.length;
        if (destinationOffset < 0 || (NSUInteger)destinationOffset > length) {
            return IDBlockCaretStopNotFound();
        }
        id<NSTextLocation> expected = [self.contentStorage
            locationFromLocation:documentRange.location
                      withOffset:destinationOffset];
        if (expected == nil || [expected compare:destinationLocation] != NSOrderedSame) {
            return IDBlockCaretStopNotFound();
        }
        return (IDBlockCaretStop){
            .localOffset = (NSUInteger)destinationOffset,
            .affinity = selection.affinity == NSTextSelectionAffinityUpstream
                ? UITextStorageDirectionBackward
                : UITextStorageDirectionForward,
            .anchorPositionOffset = selection.anchorPositionOffset,
            .found = YES,
        };
    } @catch (__unused NSException *exception) {
        return IDBlockCaretStopNotFound();
    }
}

- (instancetype)initWithContentStorage:(NSTextContentStorage *)contentStorage
                          layoutManager:(NSTextLayoutManager *)layoutManager
                          textContainer:(NSTextContainer *)textContainer {
    self = [super init];
    if (self == nil) {
        return nil;
    }
    _contentStorage = contentStorage;
    _layoutManager = layoutManager;
    _textContainer = textContainer;
    return self;
}

- (CGRect)id_insertionRectForRange:(NSTextRange *)range
                          upstream:(BOOL)upstream {
    [self.layoutManager ensureLayoutForRange:range];
    __block CGRect insertionRect = CGRectNull;
    NSTextLayoutManagerSegmentOptions options =
        NSTextLayoutManagerSegmentOptionsRangeNotRequired;
    if (upstream) {
        options |= NSTextLayoutManagerSegmentOptionsUpstreamAffinity;
    }
    [self.layoutManager enumerateTextSegmentsInRange:range
                                                type:NSTextLayoutManagerSegmentTypeStandard
                                             options:options
                                          usingBlock:^BOOL(NSTextRange *segmentRange,
                                                           CGRect frame,
                                                           CGFloat baselinePosition,
                                                           NSTextContainer *textContainer) {
        (void)segmentRange;
        (void)baselinePosition;
        (void)textContainer;
        if (CGRectIsNull(insertionRect) && IDBlockTextGeometryRectIsFinite(frame)) {
            insertionRect = CGRectMake(CGRectGetMinX(frame) - 1.0,
                                       CGRectGetMinY(frame),
                                       2.0,
                                       CGRectGetHeight(frame));
        }
        return YES;
    }];
    return insertionRect;
}

- (CGFloat)id_resolvedCaretOffsetForLocation:(id<NSTextLocation>)location
                                     affinity:(UITextStorageDirection)affinity
                                standardOffset:(CGFloat)standardOffset {
    (void)affinity;
    id<NSTextSelectionDataSource> dataSource =
        (id<NSTextSelectionDataSource>)self.layoutManager;
    NSTextRange *documentRange = self.contentStorage.documentRange;
    BOOL atDocumentStart = [location compare:documentRange.location] == NSOrderedSame;
    BOOL atDocumentEnd = [location compare:documentRange.endLocation] == NSOrderedSame;
    id<NSTextLocation> previousLocation = atDocumentStart
        ? nil
        : [dataSource locationFromLocation:location withOffset:-1];
    id<NSTextLocation> queryLocation = atDocumentEnd ? previousLocation : location;
    if (queryLocation == nil) {
        return standardOffset;
    }

    __block CGFloat currentLeadingOffset = NAN;
    __block CGFloat currentTrailingOffset = NAN;
    __block CGFloat previousLeadingOffset = NAN;
    __block CGFloat previousTrailingOffset = NAN;
    [dataSource enumerateCaretOffsetsInLineFragmentAtLocation:queryLocation
                                                   usingBlock:^(CGFloat caretOffset,
                                                                id<NSTextLocation> candidateLocation,
                                                                BOOL leadingEdge,
                                                                BOOL *stop) {
        (void)stop;
        if (!isfinite(caretOffset)) return;
        if (leadingEdge && [candidateLocation compare:location] == NSOrderedSame) {
            currentLeadingOffset = caretOffset;
        }
        if (!leadingEdge && [candidateLocation compare:location] == NSOrderedSame) {
            currentTrailingOffset = caretOffset;
        }
        if (leadingEdge && previousLocation != nil &&
            [candidateLocation compare:previousLocation] == NSOrderedSame) {
            previousLeadingOffset = caretOffset;
        }
        if (!leadingEdge && previousLocation != nil &&
            [candidateLocation compare:previousLocation] == NSOrderedSame) {
            previousTrailingOffset = caretOffset;
        }
    }];

    if (atDocumentStart) {
        return isfinite(currentLeadingOffset) ? currentLeadingOffset : standardOffset;
    }
    if (atDocumentEnd) {
        return isfinite(previousTrailingOffset) ? previousTrailingOffset : standardOffset;
    }
    // The enumerated caret offsets are ALIGNMENT-AWARE; the standard segment's midX is not.
    //
    // It reports a position measured from a left origin, so on a centred or right-aligned line the
    // caret sat where left-aligned text would have put it — displaced by exactly that line's
    // alignment offset. A WRAPPED line fills the width and is displaced by zero, which is why this
    // was invisible on every line but the short last one, and why the end of the text looked right
    // (that path already used these offsets).
    if (!isfinite(currentLeadingOffset)) {
        return standardOffset;
    }
    if (!isfinite(previousTrailingOffset) ||
        fabs(currentLeadingOffset - previousTrailingOffset) <= 0.001) {
        return currentLeadingOffset;
    }

    if (isfinite(currentTrailingOffset) && isfinite(previousLeadingOffset)) {
        NSTextSelectionNavigationWritingDirection baseDirection =
            [dataSource baseWritingDirectionAtLocation:location];
        BOOL baseIsRTL =
            baseDirection == NSTextSelectionNavigationWritingDirectionRightToLeft;
        BOOL currentIsRTL = currentLeadingOffset > currentTrailingOffset;
        BOOL previousIsRTL = previousLeadingOffset > previousTrailingOffset;
        if (currentIsRTL != previousIsRTL) {
            if (previousIsRTL == baseIsRTL) return previousTrailingOffset;
            if (currentIsRTL == baseIsRTL) return currentLeadingOffset;
        }
    }
    return currentLeadingOffset;
}

- (CGRect)insertionRectForLocation:(id<NSTextLocation>)location
                           affinity:(UITextStorageDirection)affinity {
    @try {
        NSTextSelection *normalizedSelection =
            [self id_normalizedSelectionForLocation:location affinity:affinity];
        NSTextRange *normalizedRange = normalizedSelection.textRanges.firstObject;
        if (normalizedRange == nil || !normalizedRange.empty) {
            return CGRectNull;
        }

        BOOL upstream = affinity == UITextStorageDirectionBackward;
        BOOL isDocumentEnd =
            [normalizedRange.location compare:self.contentStorage.documentRange.endLocation] ==
                NSOrderedSame;
        CGRect insertionRect = [self id_insertionRectForRange:normalizedRange
                                                     upstream:upstream];
        if (!IDBlockTextGeometryRectIsFinite(insertionRect) &&
            !upstream && isDocumentEnd) {
            insertionRect = [self id_insertionRectForRange:normalizedRange upstream:YES];
        }
        if (!IDBlockTextGeometryRectIsFinite(insertionRect)) {
            return CGRectNull;
        }

        CGFloat standardOffset = CGRectGetMidX(insertionRect);
        CGFloat resolvedOffset = [self
            id_resolvedCaretOffsetForLocation:normalizedRange.location
                                      affinity:affinity
                                 standardOffset:standardOffset];
        insertionRect.origin.x = resolvedOffset - 1.0;
        return insertionRect;
    } @catch (__unused NSException *exception) {
        return CGRectNull;
    }
    return CGRectNull;
}

- (CGRect)boundingRectForLocalRange:(NSRange)range {
    NSUInteger length = self.contentStorage.textStorage.length;
    if (range.location == NSNotFound || range.location > length ||
        range.length > length - range.location) {
        return CGRectNull;
    }
    id<NSTextLocation> start = [self.contentStorage
        locationFromLocation:self.contentStorage.documentRange.location
                 withOffset:(NSInteger)range.location];
    id<NSTextLocation> end = [self.contentStorage
        locationFromLocation:self.contentStorage.documentRange.location
                 withOffset:(NSInteger)NSMaxRange(range)];
    if (start == nil || end == nil) return CGRectNull;

    NSTextRange *textRange = [[NSTextRange alloc] initWithLocation:start
                                                        endLocation:end];
    [self.layoutManager ensureLayoutForRange:textRange];
    __block CGRect result = CGRectNull;
    [self.layoutManager enumerateTextSegmentsInRange:textRange
                                                type:NSTextLayoutManagerSegmentTypeStandard
                                             options:NSTextLayoutManagerSegmentOptionsRangeNotRequired
                                          usingBlock:^BOOL(NSTextRange *segmentRange,
                                                            CGRect frame,
                                                            CGFloat baseline,
                                                            NSTextContainer *container) {
        (void)segmentRange;
        (void)baseline;
        (void)container;
        if (IDBlockTextGeometryRectIsFinite(frame)) {
            result = CGRectIsNull(result) ? frame : CGRectUnion(result, frame);
        }
        return YES;
    }];
    return result;
}

/// A selected paragraph break on a line with no glyphs, as a fraction of the line's height — about
/// the width of a space in that line's font, so it reads as a mark and not as a covered line.
static const CGFloat IDBlockTextGeometryBreakMarkWidthRatio = 0.22;
/// ...and never so thin that it disappears, whatever the style.
static const CGFloat IDBlockTextGeometryMinimumBreakMarkWidth = 4.0;

- (NSArray<IDRichTextSelectionRect *> *)selectionRectsForLocalRange:(NSRange)range
                                                         extendHead:(BOOL)extendHead
                                                         extendTail:(BOOL)extendTail {
    NSUInteger length = self.contentStorage.textStorage.length;
    if (range.location == NSNotFound || range.location > length ||
        range.length > length - range.location ||
        (range.length == 0 && !extendHead && !extendTail)) {
        return @[];
    }

    @try {
        NSTextRange *documentRange = self.contentStorage.documentRange;
        id<NSTextLocation> start = [self.contentStorage
            locationFromLocation:documentRange.location
                      withOffset:(NSInteger)range.location];
        id<NSTextLocation> end = [self.contentStorage
            locationFromLocation:documentRange.location
                      withOffset:(NSInteger)NSMaxRange(range)];
        if (start == nil || end == nil) return @[];

        NSTextRange *requestedRange = [[NSTextRange alloc] initWithLocation:start
                                                                endLocation:end];
        NSTextSelection *selection = [[NSTextSelection alloc]
            initWithRanges:@[requestedRange]
                  affinity:NSTextSelectionAffinityDownstream
               granularity:NSTextSelectionGranularityCharacter];
        self.layoutManager.textSelections = @[selection];
        NSTextSelection *normalizedSelection =
            self.layoutManager.textSelections.firstObject;
        if (normalizedSelection.textRanges.count != 1) return @[];
        NSTextRange *normalizedRange = normalizedSelection.textRanges.firstObject;
        if (normalizedRange == nil) return @[];

        NSTextSelectionNavigationWritingDirection nativeDirection =
            [(id<NSTextSelectionDataSource>)self.layoutManager
                baseWritingDirectionAtLocation:normalizedRange.location];
        NSWritingDirection writingDirection =
            nativeDirection == NSTextSelectionNavigationWritingDirectionRightToLeft
                ? NSWritingDirectionRightToLeft
                : NSWritingDirectionLeftToRight;
        NSTextLayoutManagerSegmentOptions options = 0;
        if (extendHead) {
            options |= NSTextLayoutManagerSegmentOptionsHeadSegmentExtended;
        }
        if (extendTail) {
            options |= NSTextLayoutManagerSegmentOptionsTailSegmentExtended;
            if (range.length == 0) {
                options |= NSTextLayoutManagerSegmentOptionsUpstreamAffinity;
            }
        }

        [self.layoutManager ensureLayoutForRange:normalizedRange];
        CGRect containerBounds = (CGRect){CGPointZero, self.textContainer.size};
        NSMutableArray<IDRichTextSelectionRect *> *rects = [NSMutableArray array];
        __block NSUInteger startIndex = NSNotFound;
        __block NSUInteger endIndex = NSNotFound;
        [self.layoutManager enumerateTextSegmentsInRange:normalizedRange
                                                    type:NSTextLayoutManagerSegmentTypeSelection
                                                 options:options
                                              usingBlock:^BOOL(NSTextRange *segmentRange,
                                                               CGRect frame,
                                                               CGFloat baselinePosition,
                                                               NSTextContainer *textContainer) {
            if (!IDBlockTextGeometryRectIsFinite(frame)) return YES;
            // TextKit's baseline is measured from the unclipped frame's top; the rect handed
            // out may lose its top to the container, so re-measure from the clipped edge.
            CGFloat baselineY = CGRectGetMinY(frame) + baselinePosition;
            if (range.length == 0 && extendTail && CGRectGetWidth(frame) == 0.0) {
                CGFloat centerX = CGRectGetMinX(frame);
                CGFloat padding = textContainer.lineFragmentPadding;
                CGFloat lineMinX = CGRectGetMinX(containerBounds) + padding;
                CGFloat lineMaxX = CGRectGetMaxX(containerBounds) - padding;
                if (writingDirection == NSWritingDirectionRightToLeft) {
                    frame.origin.x = lineMinX;
                    frame.size.width = centerX - lineMinX;
                } else {
                    frame.origin.x = centerX;
                    frame.size.width = lineMaxX - centerX;
                }
                frame = CGRectStandardize(frame);
            }
            CGRect clipped = CGRectIntersection(frame, containerBounds);
            if (!IDBlockTextGeometryRectIsFinite(clipped) || CGRectIsEmpty(clipped)) {
                return YES;
            }
            NSUInteger index = rects.count;
            CGFloat baselineOffset = isfinite(baselineY)
                ? baselineY - CGRectGetMinY(clipped) : 0.0;
            [rects addObject:[[IDRichTextSelectionRect alloc]
                initWithRect:clipped
                baselineOffset:baselineOffset
                containsStart:NO
                containsEnd:NO
                isVertical:NO
                writingDirection:writingDirection]];
            if (segmentRange != nil) {
                if (startIndex == NSNotFound &&
                    [segmentRange containsLocation:normalizedRange.location]) {
                    startIndex = index;
                }
                if (endIndex == NSNotFound &&
                    ([segmentRange containsLocation:normalizedRange.endLocation] ||
                     [segmentRange.endLocation compare:normalizedRange.endLocation] ==
                         NSOrderedSame)) {
                    endIndex = index;
                }
            }
            return YES;
        }];
        if (rects.count == 0) return @[];
        if (startIndex == NSNotFound) startIndex = 0;
        if (endIndex == NSNotFound) endIndex = rects.count - 1;
        NSMutableArray<IDRichTextSelectionRect *> *results =
            [NSMutableArray arrayWithCapacity:rects.count];
        [rects enumerateObjectsUsingBlock:^(IDRichTextSelectionRect *rect,
                                            NSUInteger index,
                                            BOOL *stop) {
            (void)stop;
            [results addObject:[[IDRichTextSelectionRect alloc]
                initWithRect:rect.rect
                baselineOffset:rect.baselineOffset
                containsStart:index == startIndex
                containsEnd:index == endIndex
                isVertical:rect.isVertical
                writingDirection:rect.writingDirection]];
        }];
        return results.copy;
    } @catch (__unused NSException *exception) {
        return @[];
    }
}

- (NSArray<IDBlockSelectionSegment *> *)selectionSegmentsForLocalRange:
    (NSRange)range
                                                                      extendHead:
    (BOOL)extendHead
                                                                      extendTail:
    (BOOL)extendTail
                                                                layoutGeneration:
    (NSUInteger)layoutGeneration {
    NSUInteger length = self.contentStorage.textStorage.length;
    if (range.location == NSNotFound || range.location > length ||
        range.length > length - range.location || layoutGeneration == 0) return nil;
    if (range.length == 0 && !extendHead && !extendTail) return @[];

    @try {
        NSTextRange *documentRange = self.contentStorage.documentRange;
        id<NSTextLocation> start = [self.contentStorage
            locationFromLocation:documentRange.location
                      withOffset:(NSInteger)range.location];
        id<NSTextLocation> end = [self.contentStorage
            locationFromLocation:documentRange.location
                      withOffset:(NSInteger)NSMaxRange(range)];
        if (start == nil || end == nil) {
            return nil;
        }

        NSTextRange *requestedRange = [[NSTextRange alloc] initWithLocation:start
                                                                endLocation:end];
        NSTextSelection *selection = [[NSTextSelection alloc]
            initWithRanges:@[requestedRange]
                  affinity:NSTextSelectionAffinityDownstream
               granularity:NSTextSelectionGranularityCharacter];
        self.layoutManager.textSelections = @[selection];
        NSTextSelection *normalizedSelection = self.layoutManager.textSelections.firstObject;
        if (normalizedSelection.textRanges.count != 1) {
            return nil;
        }
        NSTextRange *normalizedRange = normalizedSelection.textRanges.firstObject;
        if (normalizedRange == nil) {
            return nil;
        }

        NSTextLayoutManagerSegmentOptions options = 0;
        if (extendHead) {
            options |= NSTextLayoutManagerSegmentOptionsHeadSegmentExtended;
        }
        if (extendTail) {
            options |= NSTextLayoutManagerSegmentOptionsTailSegmentExtended;
            if (range.length == 0) {
                options |= NSTextLayoutManagerSegmentOptionsUpstreamAffinity;
            }
        }

        [self.layoutManager ensureLayoutForRange:normalizedRange];
        CGRect containerBounds = (CGRect){CGPointZero, self.textContainer.size};
        NSMutableArray<IDBlockSelectionSegment *> *segments = [NSMutableArray array];
        __block BOOL exact = YES;
        // The first zero-width segment of a NON-EMPTY range whose characters draw nothing (a
        // bidi mark), kept in case it is the whole answer (see below).
        __block BOOL hasInvisibleSegment = NO;
        __block NSRange invisibleLocalRange = NSMakeRange(NSNotFound, 0);
        __block CGRect invisibleFrame = CGRectNull;
        __block CGFloat invisibleBaseline = 0.0;
        __block IDBlockWritingDirection invisibleDirection = IDBlockWritingDirectionLeftToRight;
        NSString *blockString = self.contentStorage.textStorage.string;
        [self.layoutManager enumerateTextSegmentsInRange:normalizedRange
                                                    type:NSTextLayoutManagerSegmentTypeSelection
                                                 options:options
                                              usingBlock:^BOOL(NSTextRange *segmentRange,
                                                               CGRect frame,
                                                               CGFloat baselinePosition,
                                                               NSTextContainer *textContainer) {
            if (segmentRange == nil || !IDBlockTextGeometryRectIsFinite(frame)) {
                exact = NO;
                return NO;
            }
            NSInteger startOffset = [self.contentStorage
                offsetFromLocation:documentRange.location
                        toLocation:segmentRange.location];
            NSInteger endOffset = [self.contentStorage
                offsetFromLocation:documentRange.location
                        toLocation:segmentRange.endLocation];
            if (startOffset < 0 || endOffset < startOffset ||
                (NSUInteger)endOffset > length) {
                exact = NO;
                return NO;
            }
            id<NSTextLocation> exactStart = [self.contentStorage
                locationFromLocation:documentRange.location withOffset:startOffset];
            id<NSTextLocation> exactEnd = [self.contentStorage
                locationFromLocation:documentRange.location withOffset:endOffset];
            if (exactStart == nil || exactEnd == nil ||
                [exactStart compare:segmentRange.location] != NSOrderedSame ||
                [exactEnd compare:segmentRange.endLocation] != NSOrderedSame) {
                exact = NO;
                return NO;
            }
            NSTextSelectionNavigationWritingDirection nativeDirection =
                [(id<NSTextSelectionDataSource>)self.layoutManager
                    baseWritingDirectionAtLocation:segmentRange.location];
            IDBlockWritingDirection writingDirection =
                nativeDirection ==
                    NSTextSelectionNavigationWritingDirectionRightToLeft
                    ? IDBlockWritingDirectionRightToLeft
                    : IDBlockWritingDirectionLeftToRight;
            // A NON-EMPTY range can still come back zero-width, and that is NOTHING TO DRAW for
            // that segment, not a failure to measure (composer harness p19). Two shapes do it:
            //
            // - a line separator (`U+2028`, a soft break inside the block) selected on its own:
            //   TextKit widens a selected separator to its line's end only when the selection
            //   continues past it. It stands for the same thing a selected paragraph break does, so
            //   it is drawn the way the tail extension below draws one — from the caret to the
            //   line's end (`HarnessSoftLineBreakSelectionGeometryTests`);
            // - a character that draws nothing (a right-to-left mark leading the paragraph): its
            //   segment is dropped, the promotion below hands its endpoint to the neighbour, and
            //   when it is the WHOLE selection it is stood up as a narrow mark after the loop
            //   (`HarnessBidiMarkSelectionGeometryTests`).
            //
            // Reported as inexact, either one made `IDDocumentLayoutCoordinator` discard the
            // geometry for the whole document, so nothing was highlighted and UIKit placed the
            // edit menu at infinity.
            BOOL separatorOnly = NO;
            if (range.length != 0 && CGRectGetWidth(frame) == 0.0 && CGRectGetHeight(frame) > 0.0 &&
                endOffset > startOffset) {
                separatorOnly = YES;
                for (NSInteger offset = startOffset; offset < endOffset; offset += 1) {
                    unichar character = [blockString characterAtIndex:(NSUInteger)offset];
                    if (character != 0x2028 && character != 0x2029 &&
                        character != '\n' && character != '\r') {
                        separatorOnly = NO;
                        break;
                    }
                }
                if (!separatorOnly) {
                    if (!hasInvisibleSegment) {
                        hasInvisibleSegment = YES;
                        invisibleLocalRange = NSMakeRange((NSUInteger)startOffset,
                                                          (NSUInteger)(endOffset - startOffset));
                        invisibleFrame = frame;
                        invisibleBaseline = isfinite(baselinePosition) ? baselinePosition : 0.0;
                        invisibleDirection = writingDirection;
                    }
                    return YES;
                }
            }
            if ((separatorOnly || (range.length == 0 && extendTail)) &&
                CGRectGetWidth(frame) == 0.0) {
                CGFloat centerX = CGRectGetMinX(frame);
                CGFloat padding = textContainer.lineFragmentPadding;
                CGFloat lineMinX = CGRectGetMinX(containerBounds) + padding;
                CGFloat lineMaxX = CGRectGetMaxX(containerBounds) - padding;
                if (writingDirection == IDBlockWritingDirectionRightToLeft) {
                    frame.origin.x = lineMinX;
                    frame.size.width = centerX - lineMinX;
                } else {
                    frame.origin.x = centerX;
                    frame.size.width = lineMaxX - centerX;
                }
                frame = CGRectStandardize(frame);
                // The caret already stands at the line's end — an atom that fills its line (a
                // button row, an audio item) or a line of text set to the edge — so there is no
                // line left to fill and the break had nothing to draw: its selection had no
                // geometry at all, because the block after a break with glyphs contributes nothing
                // either (`HarnessAtomLineBreakSelectionGeometryTests`). Draw the break as the
                // narrow mark an empty line gets, against the line's trailing edge.
                if (CGRectGetWidth(frame) <= 0.0 && CGRectGetHeight(frame) > 0.0) {
                    CGFloat markWidth = MAX(IDBlockTextGeometryMinimumBreakMarkWidth,
                                            CGRectGetHeight(frame) *
                                                IDBlockTextGeometryBreakMarkWidthRatio);
                    frame.origin.x = writingDirection == IDBlockWritingDirectionRightToLeft
                        ? lineMinX
                        : lineMaxX - markWidth;
                    frame.size.width = markWidth;
                    frame = CGRectStandardize(frame);
                }
            }
            frame = CGRectStandardize(frame);
            if (!IDBlockTextGeometryRectIsFinite(frame)) {
                exact = NO;
                return NO;
            }
            if (CGRectIsEmpty(frame)) {
                // NOTHING TO DRAW is not the same as FAILED TO MEASURE, and answering the first
                // with the second took the whole document's selection down.
                //
                // A zero-length range is empty on the page unless an extension widens it, and only
                // the TAIL extension can: the head extension reaches the line's leading edge, which
                // a range at the block's offset 0 already sits on. The coordinator offers every
                // structural separator to both of its sides, so this arrives for the head side of
                // each one — an ordinary question with an empty answer. Reporting it as inexact
                // made `IDDocumentLayoutCoordinator` discard the geometry for EVERY block, and the
                // selection disappeared from the screen (2026-09-15).
                if (range.length != 0) {
                    exact = NO;
                    return NO;
                }
                // ...but on an EMPTY line, nothing to draw left nothing on screen, and the line the
                // finger had just been dragged onto read as skipped. A document ending in a blank
                // line showed nothing there under select-all (device, 2026-09-15).
                //
                // The block's whole text is that paragraph break, so stand it up as a narrow mark
                // at the line's leading edge: wide enough to see, far too narrow to read as a
                // covered line — which is what this line gets from the tail branch above when the
                // selection passes THROUGH it. Proportional to the line so it holds at any style,
                // being about the width of the space the break stands in for. Only where the line
                // has no glyphs of its own: a line with text says it is in the selection by the
                // text that is washed.
                // EMPTY lines only. A line with text needs no mark — it says it is in the
                // selection by the text that is washed — and in fact never reaches here: a block
                // with glyphs contributes no segment at all for a zero-length range at its start,
                // and the endpoint rect on that line is a zero-width one synthesised above this
                // layer. Generalising this guard was measured to be inert, and would draw a mark
                // over a line's first glyph if it ever stopped being (2026-09-15).
                if (length != 0 || !extendHead || extendTail) {
                    return YES;
                }
                if (CGRectGetHeight(frame) <= 0.0) {
                    return YES;
                }
                // The mark measures the GLYPH box here, which on an empty line falls short of the
                // pinned line. `IDBlockLayout` stretches it, because the line's height is its
                // `usedSize` and nothing at this level knows it: the layout fragment enumeration
                // returns no fragment at all for an empty block, the container's height is
                // unbounded, `insertionRectForLocation:` answers the same glyph-height caret, and a
                // tail-extended re-measure of the same range answers the same box. All four were
                // measured, 2026-09-15.
                // The mark KEEPS its head boundary role, and so carries the selection's logical
                // end. That end lies on the break, whose caret sits at the start of this line — so
                // this is the segment the trailing handle belongs on, and leaving the claim with the
                // block before put the handle a line above the mark (device, 2026-09-15). Exactly
                // one segment may own an endpoint: `id_selectionGeometryAttemptForCanonicalRange`
                // makes the block before yield it under precisely the condition that brings us
                // here, so there is no second claimant and the duplicate guard stays quiet.
                CGFloat markWidth = MAX(IDBlockTextGeometryMinimumBreakMarkWidth,
                                        CGRectGetHeight(frame) *
                                            IDBlockTextGeometryBreakMarkWidthRatio);
                if (writingDirection == IDBlockWritingDirectionRightToLeft) {
                    frame.origin.x = CGRectGetMinX(frame) - markWidth;
                }
                frame.size.width = markWidth;
                frame = CGRectStandardize(frame);
                frame = CGRectIntersection(frame, containerBounds);
                if (!IDBlockTextGeometryRectIsFinite(frame) || CGRectIsEmpty(frame)) {
                    return YES;
                }
            }
            BOOL containsStart =
                [segmentRange containsLocation:normalizedRange.location];
            BOOL containsEnd =
                [segmentRange containsLocation:normalizedRange.endLocation] ||
                [segmentRange.endLocation compare:normalizedRange.endLocation] ==
                    NSOrderedSame;
            IDBlockSelectionBoundaryRole boundaryRole =
                IDBlockSelectionBoundaryRoleNone;
            if (extendHead && containsStart) {
                boundaryRole |= IDBlockSelectionBoundaryRoleHead;
            }
            if (extendTail && containsEnd) {
                boundaryRole |= IDBlockSelectionBoundaryRoleTail;
            }
            [segments addObject:[[IDBlockSelectionSegment alloc]
                initWithLocalRange:NSMakeRange((NSUInteger)startOffset,
                                                (NSUInteger)(endOffset - startOffset))
                             rect:frame
                   baselineOffset:isfinite(baselinePosition) ? baselinePosition : 0.0
                     boundaryRole:boundaryRole
               containsLocalStart:containsStart
                 containsLocalEnd:containsEnd
                 writingDirection:writingDirection
                         vertical:NO
                 layoutGeneration:layoutGeneration]];
            return YES;
        }];
        if (exact && segments.count == 0 && hasInvisibleSegment) {
            // The whole selection is characters that draw nothing: a narrow mark where they are,
            // carrying both endpoints, so the selection still has a place on screen.
            CGFloat markWidth = MAX(IDBlockTextGeometryMinimumBreakMarkWidth,
                                    CGRectGetHeight(invisibleFrame) *
                                        IDBlockTextGeometryBreakMarkWidthRatio);
            CGRect mark = invisibleFrame;
            if (invisibleDirection == IDBlockWritingDirectionRightToLeft) {
                mark.origin.x = CGRectGetMinX(invisibleFrame) - markWidth;
            }
            mark.size.width = markWidth;
            mark = CGRectIntersection(CGRectStandardize(mark), containerBounds);
            if (IDBlockTextGeometryRectIsFinite(mark) && !CGRectIsEmpty(mark)) {
                IDBlockSelectionBoundaryRole boundaryRole = IDBlockSelectionBoundaryRoleNone;
                if (extendHead) boundaryRole |= IDBlockSelectionBoundaryRoleHead;
                if (extendTail) boundaryRole |= IDBlockSelectionBoundaryRoleTail;
                [segments addObject:[[IDBlockSelectionSegment alloc]
                    initWithLocalRange:invisibleLocalRange
                                 rect:mark
                       baselineOffset:invisibleBaseline
                         boundaryRole:boundaryRole
                   containsLocalStart:YES
                     containsLocalEnd:YES
                     writingDirection:invisibleDirection
                             vertical:NO
                     layoutGeneration:layoutGeneration]];
            }
        }
        if (!exact || segments.count == 0) {
            return exact ? @[] : nil;
        }

        BOOL hasStart = NO;
        BOOL hasEnd = NO;
        for (IDBlockSelectionSegment *segment in segments) {
            hasStart |= segment.containsLocalStart;
            hasEnd |= segment.containsLocalEnd;
        }
        if (hasStart && hasEnd) {
            return segments.copy;
        }

        NSMutableArray<IDBlockSelectionSegment *> *promoted =
            [NSMutableArray arrayWithCapacity:segments.count];
        [segments enumerateObjectsUsingBlock:^(IDBlockSelectionSegment *segment,
                                                NSUInteger index,
                                                BOOL *stop) {
            (void)stop;
            BOOL containsStart = segment.containsLocalStart ||
                (!hasStart && index == 0);
            BOOL containsEnd = segment.containsLocalEnd ||
                (!hasEnd && index == segments.count - 1);
            IDBlockSelectionBoundaryRole boundaryRole = segment.boundaryRole;
            if (extendHead && containsStart) {
                boundaryRole |= IDBlockSelectionBoundaryRoleHead;
            }
            if (extendTail && containsEnd) {
                boundaryRole |= IDBlockSelectionBoundaryRoleTail;
            }
            [promoted addObject:[[IDBlockSelectionSegment alloc]
                initWithLocalRange:segment.localRange
                             rect:segment.rect
                   baselineOffset:segment.baselineOffset
                     boundaryRole:boundaryRole
               containsLocalStart:containsStart
                 containsLocalEnd:containsEnd
                 writingDirection:segment.writingDirection
                         vertical:segment.isVertical
                 layoutGeneration:segment.layoutGeneration]];
        }];
        return promoted.copy;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

- (IDBlockCaretStop)caretStopForLocation:(id<NSTextLocation>)location
                                affinity:(UITextStorageDirection)affinity
                               direction:(UITextLayoutDirection)direction
                    anchorPositionOffset:(CGFloat)anchorPositionOffset {
    NSTextSelectionNavigationDirection navigationDirection;
    switch (direction) {
        case UITextLayoutDirectionLeft:
            navigationDirection = NSTextSelectionNavigationDirectionLeft;
            break;
        case UITextLayoutDirectionRight:
            navigationDirection = NSTextSelectionNavigationDirectionRight;
            break;
        case UITextLayoutDirectionUp:
            navigationDirection = NSTextSelectionNavigationDirectionUp;
            break;
        case UITextLayoutDirectionDown:
            navigationDirection = NSTextSelectionNavigationDirectionDown;
            break;
        default:
            return IDBlockCaretStopNotFound();
    }

    @try {
        NSTextSelection *source = [[NSTextSelection alloc]
            initWithLocation:location
                     affinity:affinity == UITextStorageDirectionForward
                         ? NSTextSelectionAffinityDownstream
                         : NSTextSelectionAffinityUpstream];
        source.anchorPositionOffset = anchorPositionOffset;
        NSTextSelection *destination = [self.layoutManager.textSelectionNavigation
            destinationSelectionForTextSelection:source
                                        direction:navigationDirection
                                      destination:NSTextSelectionNavigationDestinationCharacter
                                        extending:NO
                                         confined:NO];
        return [self id_caretStopForSelection:destination];
    } @catch (__unused NSException *exception) {
        return IDBlockCaretStopNotFound();
    }
}

- (IDBlockCaretStop)caretStopForPoint:(CGPoint)point {
    if (self.contentStorage.textStorage.length == 0) {
        if (!isfinite(point.x) || !isfinite(point.y)) {
            return IDBlockCaretStopNotFound();
        }
        return (IDBlockCaretStop){
            .localOffset = 0,
            .affinity = UITextStorageDirectionForward,
            .anchorPositionOffset = point.x,
            .found = YES,
        };
    }
    @try {
        NSTextSelectionNavigation *navigation = self.layoutManager.textSelectionNavigation;
        NSArray<NSTextSelection *> *selections = [navigation
            textSelectionsInteractingAtPoint:point
                       inContainerAtLocation:self.layoutManager.documentRange.location
                                      anchors:@[]
                                    modifiers:0
                                     selecting:YES
                                        bounds:(CGRect){CGPointZero,
                                                        self.textContainer.size}];
        for (NSTextSelection *selection in selections) {
            IDBlockCaretStop stop = [self id_caretStopForSelection:selection];
            if (stop.found) {
                return stop;
            }
        }
    } @catch (__unused NSException *exception) {
    }
    return IDBlockCaretStopNotFound();
}

@end

#endif
