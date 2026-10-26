#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDDocumentLayoutCoordinator.h"

#import "IDBlockDocument.h"
#import "IDCanonicalTextProjection.h"

#include <math.h>

static const CGFloat IDCoordinatorVerticalProgressEpsilon = 0.5;

static BOOL IDCoordinatorPointIsFinite(CGPoint point) {
    return isfinite(point.x) && isfinite(point.y);
}

static BOOL IDCoordinatorRectIsFinite(CGRect rect) {
    return isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height);
}

static BOOL IDCoordinatorAffinityIsValid(IDBlockTextAffinity affinity) {
    return affinity == IDBlockTextAffinityUpstream ||
        affinity == IDBlockTextAffinityDownstream;
}

static BOOL IDCoordinatorWritingDirectionIsValid(
    IDBlockWritingDirection direction) {
    return direction == IDBlockWritingDirectionLeftToRight ||
        direction == IDBlockWritingDirectionRightToLeft;
}

@interface IDDocumentGeometryEligibilitySnapshot ()
@property(nonatomic, readwrite) NSUInteger geometryGeneration;
@property(nonatomic, copy, readwrite) NSArray<NSUUID *> *orderedBlockIdentifiers;
@end

@implementation IDDocumentGeometryEligibilitySnapshot

- (instancetype)initWithGeometryGeneration:(NSUInteger)geometryGeneration
                    orderedBlockIdentifiers:(NSArray<NSUUID *> *)identifiers {
    if (geometryGeneration == 0 || identifiers == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Eligibility requires a generation and identifiers."];
    }
    NSMutableSet<NSUUID *> *seen = [NSMutableSet set];
    for (id identifier in identifiers) {
        if (![identifier isKindOfClass:NSUUID.class] ||
            [seen containsObject:identifier]) {
            [NSException raise:NSInvalidArgumentException
                        format:@"Eligibility identifiers must be unique UUIDs."];
        }
        [seen addObject:identifier];
    }
    self = [super init];
    if (self != nil) {
        _geometryGeneration = geometryGeneration;
        _orderedBlockIdentifiers = [identifiers copy];
    }
    return self;
}

@end

@interface IDDocumentTextPosition ()
@property(nonatomic, copy, readwrite) NSUUID *blockIdentifier;
@property(nonatomic, readwrite) IDBlockTextPosition localPosition;
@property(nonatomic, readwrite) NSUInteger canonicalOffset;
@property(nonatomic, readwrite) NSUInteger documentRevision;
- (instancetype)initWithBlockIdentifier:(NSUUID *)blockIdentifier
                           localPosition:(IDBlockTextPosition)localPosition
                         canonicalOffset:(NSUInteger)canonicalOffset
                        documentRevision:(NSUInteger)documentRevision;
@end

@implementation IDDocumentTextPosition

- (instancetype)initWithBlockIdentifier:(NSUUID *)blockIdentifier
                           localPosition:(IDBlockTextPosition)localPosition
                         canonicalOffset:(NSUInteger)canonicalOffset
                        documentRevision:(NSUInteger)documentRevision {
    self = [super init];
    if (self != nil) {
        _blockIdentifier = [blockIdentifier copy];
        _localPosition = localPosition;
        _canonicalOffset = canonicalOffset;
        _documentRevision = documentRevision;
    }
    return self;
}

@end

@interface IDDocumentCaretGeometry ()
@property(nonatomic, strong, readwrite) IDDocumentTextPosition *position;
@property(nonatomic, readwrite) CGRect documentRect;
@property(nonatomic, copy, nullable, readwrite)
    IDBlockLineIdentifier *lineIdentifier;
@property(nonatomic, readwrite, getter=isExact) BOOL exact;
- (instancetype)initWithPosition:(IDDocumentTextPosition *)position
                    documentRect:(CGRect)documentRect
                  lineIdentifier:(nullable IDBlockLineIdentifier *)lineIdentifier
                           exact:(BOOL)exact;
@end

@implementation IDDocumentCaretGeometry

- (instancetype)initWithPosition:(IDDocumentTextPosition *)position
                    documentRect:(CGRect)documentRect
                  lineIdentifier:(IDBlockLineIdentifier *)lineIdentifier
                           exact:(BOOL)exact {
    self = [super init];
    if (self != nil) {
        _position = position;
        _documentRect = documentRect;
        _lineIdentifier = [lineIdentifier copy];
        _exact = exact;
    }
    return self;
}

@end

@interface IDDocumentLineGeometry ()
@property(nonatomic, strong, readwrite) IDDocumentTextPosition *position;
@property(nonatomic, readwrite) NSRange canonicalRange;
@property(nonatomic, readwrite) IDBlockTextAffinity resolvedAffinity;
@property(nonatomic, readwrite, getter=isExact) BOOL exact;
- (instancetype)initWithPosition:(IDDocumentTextPosition *)position
                  canonicalRange:(NSRange)canonicalRange
                resolvedAffinity:(IDBlockTextAffinity)resolvedAffinity
                           exact:(BOOL)exact;
@end

@implementation IDDocumentLineGeometry

- (instancetype)initWithPosition:(IDDocumentTextPosition *)position
                  canonicalRange:(NSRange)canonicalRange
                resolvedAffinity:(IDBlockTextAffinity)resolvedAffinity
                           exact:(BOOL)exact {
    self = [super init];
    if (self != nil) {
        _position = position;
        _canonicalRange = canonicalRange;
        _resolvedAffinity = resolvedAffinity;
        _exact = exact;
    }
    return self;
}

@end

@interface IDDocumentCaretNavigationResult ()
@property(nonatomic, strong, readwrite) IDDocumentTextPosition *position;
@property(nonatomic, readwrite) CGFloat anchorPositionOffset;
@property(nonatomic, readwrite, getter=isExact) BOOL exact;
- (instancetype)initWithPosition:(IDDocumentTextPosition *)position
            anchorPositionOffset:(CGFloat)anchorPositionOffset
                           exact:(BOOL)exact;
@end

@implementation IDDocumentCaretNavigationResult

- (instancetype)initWithPosition:(IDDocumentTextPosition *)position
            anchorPositionOffset:(CGFloat)anchorPositionOffset
                           exact:(BOOL)exact {
    self = [super init];
    if (self != nil) {
        _position = position;
        _anchorPositionOffset = anchorPositionOffset;
        _exact = exact;
    }
    return self;
}

@end

@interface IDDocumentSelectionSegment ()
@property(nonatomic, copy, readwrite) NSUUID *blockIdentifier;
@property(nonatomic, readwrite) NSRange canonicalRange;
@property(nonatomic, readwrite) IDBlockSelectionBoundaryRole boundaryRole;
@property(nonatomic, readwrite) CGRect documentRect;
@property(nonatomic, readwrite) CGFloat baselineOffset;
@property(nonatomic, readwrite) IDBlockWritingDirection writingDirection;
@property(nonatomic, readwrite, getter=isVertical) BOOL vertical;
@property(nonatomic, readwrite) BOOL containsLogicalStart;
@property(nonatomic, readwrite) BOOL containsLogicalEnd;
- (instancetype)initWithBlockIdentifier:(NSUUID *)blockIdentifier
                          canonicalRange:(NSRange)canonicalRange
                            boundaryRole:(IDBlockSelectionBoundaryRole)boundaryRole
                            documentRect:(CGRect)documentRect
                          baselineOffset:(CGFloat)baselineOffset
                        writingDirection:(IDBlockWritingDirection)writingDirection
                                vertical:(BOOL)vertical
                    containsLogicalStart:(BOOL)containsLogicalStart
                      containsLogicalEnd:(BOOL)containsLogicalEnd;
@end

@implementation IDDocumentSelectionSegment
- (instancetype)initWithBlockIdentifier:(NSUUID *)blockIdentifier
                          canonicalRange:(NSRange)canonicalRange
                            boundaryRole:(IDBlockSelectionBoundaryRole)boundaryRole
                            documentRect:(CGRect)documentRect
                          baselineOffset:(CGFloat)baselineOffset
                        writingDirection:(IDBlockWritingDirection)writingDirection
                                vertical:(BOOL)vertical
                    containsLogicalStart:(BOOL)containsLogicalStart
                      containsLogicalEnd:(BOOL)containsLogicalEnd {
    self = [super init];
    if (self != nil) {
        _blockIdentifier = [blockIdentifier copy];
        _canonicalRange = canonicalRange;
        _boundaryRole = boundaryRole;
        _documentRect = documentRect;
        _baselineOffset = baselineOffset;
        _writingDirection = writingDirection;
        _vertical = vertical;
        _containsLogicalStart = containsLogicalStart;
        _containsLogicalEnd = containsLogicalEnd;
    }
    return self;
}
@end

@interface IDDocumentSelectionGeometry ()
@property(nonatomic, readwrite) NSRange canonicalSelection;
@property(nonatomic, readwrite) NSUInteger documentRevision;
@property(nonatomic, readwrite) NSUInteger sourceGeometryGeneration;
@property(nonatomic, copy, readwrite) NSArray<IDDocumentSelectionSegment *> *segments;
@property(nonatomic, readwrite, getter=isExact) BOOL exact;
- (instancetype)initWithCanonicalSelection:(NSRange)canonicalSelection
                           documentRevision:(NSUInteger)documentRevision
                   sourceGeometryGeneration:(NSUInteger)sourceGeometryGeneration
                                   segments:(NSArray<IDDocumentSelectionSegment *> *)segments;
@end

@implementation IDDocumentSelectionGeometry
- (instancetype)initWithCanonicalSelection:(NSRange)canonicalSelection
                           documentRevision:(NSUInteger)documentRevision
                   sourceGeometryGeneration:(NSUInteger)sourceGeometryGeneration
                                   segments:(NSArray<IDDocumentSelectionSegment *> *)segments {
    self = [super init];
    if (self != nil) {
        _canonicalSelection = canonicalSelection;
        _documentRevision = documentRevision;
        _sourceGeometryGeneration = sourceGeometryGeneration;
        _segments = [segments copy];
        _exact = YES;
    }
    return self;
}
@end

@interface IDDocumentLayoutCoordinator ()
@property(nonatomic, strong, readwrite) IDBlockDocument *document;
@property(nonatomic, weak, nullable, readwrite)
    id<IDDocumentLayoutSnapshotSource> source;
@end

@implementation IDDocumentLayoutCoordinator

- (IDDocumentGeometryEligibilitySnapshot *)
    id_validatedSelectionGeometryEligibilityForDocumentRevision:
        (NSUInteger)documentRevision {
    id<IDDocumentLayoutSnapshotSource> source = self.source;
    if (source == nil || self.document.documentRevision != documentRevision) {
        return nil;
    }
    IDDocumentGeometryEligibilitySnapshot *eligibility = nil;
    @try {
        eligibility = [source
            selectionGeometryEligibilityForDocumentRevision:documentRevision];
    } @catch (__unused NSException *exception) {
        return nil;
    }
    if (eligibility == nil || eligibility.geometryGeneration == 0 ||
        self.document.documentRevision != documentRevision) {
        return nil;
    }

    NSArray<NSUUID *> *canonicalIdentifiers =
        [self.document.blocks valueForKey:@"identifier"];
    NSUInteger nextCanonicalIndex = 0;
    for (NSUUID *identifier in eligibility.orderedBlockIdentifiers) {
        NSUInteger index = [canonicalIdentifiers
            indexOfObject:identifier
              inRange:NSMakeRange(nextCanonicalIndex,
                                  canonicalIdentifiers.count -
                                      nextCanonicalIndex)];
        if (index == NSNotFound) {
            return nil;
        }
        nextCanonicalIndex = index + 1;
    }
    return eligibility;
}

- (IDDocumentSelectionGeometry *)id_selectionGeometryAttemptForCanonicalRange:
    (NSRange)range
                                                                      retry:
    (BOOL *)retry {
    *retry = NO;
    NSUInteger revision = self.document.documentRevision;
    NSUInteger documentLength = self.document.canonicalLength;
    if (range.location == NSNotFound || range.length == 0 ||
        range.location > documentLength ||
        range.length > documentLength - range.location) {
        return nil;
    }
    id<IDDocumentLayoutSnapshotSource> source = self.source;
    IDDocumentGeometryEligibilitySnapshot *eligibility = [self
        id_validatedSelectionGeometryEligibilityForDocumentRevision:revision];
    if (source == nil || eligibility == nil) return nil;

    NSSet<NSUUID *> *eligible =
        [NSSet setWithArray:eligibility.orderedBlockIdentifiers];
    NSMutableArray<IDDocumentSelectionSegment *> *results =
        [NSMutableArray array];
    NSMutableDictionary<NSUUID *, NSValue *> *capturedOrigins =
        [NSMutableDictionary dictionary];
    NSMutableDictionary<NSUUID *, NSValue *> *capturedSlots =
        [NSMutableDictionary dictionary];
    NSMutableSet<NSNumber *> *claimedSeparatorLocations =
        [NSMutableSet set];
    BOOL hasLogicalStart = NO;
    BOOL hasLogicalEnd = NO;
    // Where an endpoint would go if the yield below finds no taker. Scoped to the BLOCK that
    // contains the endpoint — its own text plus the separators on either side of it — because a
    // segment's canonical range is not a reliable test: a block that owns both separators keeps only
    // one of them in its range, and an endpoint on the other is then inside no segment at all.
    NSUInteger startFallbackIndex = NSNotFound;
    NSUInteger endFallbackIndex = NSNotFound;
    NSUInteger selectionEnd = NSMaxRange(range);
    NSUInteger cursor = 0;
    NSArray<IDBlock *> *blocks = self.document.blocks;
    for (NSUInteger index = 0; index < blocks.count; index += 1) {
        IDBlock *block = blocks[index];
        NSUInteger blockLength = block.attributedText.length;
        NSRange blockRange = NSMakeRange(cursor, blockLength);
        NSRange intersection = NSIntersectionRange(range, blockRange);
        BOOL extendHead = index > 0 &&
            NSLocationInRange(blockRange.location - 1, range);
        BOOL extendTail = index + 1 < blocks.count &&
            NSLocationInRange(NSMaxRange(blockRange), range);
        // THE BLOCK AFTER A SELECTED BREAK OWNS THE SELECTION'S END.
        //
        // A separator belongs to the block before it, and so does its canonical range — but the
        // selection's logical END is a place on screen, and that place is the caret for the end
        // offset, which sits at the START of the line after the break. Leaving the claim with the
        // block before put the trailing handle a line above the caret (device, 2026-09-15); it was
        // reported on an empty line, where the mark drawn there contradicts it visibly, and it was
        // just as wrong on a line with text where nothing contradicted it.
        //
        // This is the exact condition under which `IDBlockTextGeometry` draws that mark — the next
        // block's head extension is this separator and the selection stops there — so the mark and
        // this yield cannot disagree about who owns the end.
        BOOL nextBlockDrawsTheEndMark = index + 1 < blocks.count &&
            selectionEnd == NSMaxRange(blockRange) + 1;
        // A SEPARATOR BELONGS TO THE BLOCK BEFORE IT.
        //
        // `extendTail` here and `extendHead` on the next block are the same condition — the
        // separator's offset is selected — so both sides of every selected separator are always
        // asked about it. The block before draws it, by widening its last segment to the end of
        // its line; the block after has nothing of its own to add there. Both sides claiming it is
        // what the ownership rules below resolve, and a block still participates for its OWN line:
        // an empty block between two selected separators is nothing BUT a separator, and
        // suppressing it here left an empty line in a run of them with no highlight at all.
        BOOL participates = intersection.length > 0 || extendHead || extendTail;
        if (participates && [eligible containsObject:block.identifier]) {
            NSRange localRange = intersection.length > 0
                ? NSMakeRange(intersection.location - cursor,
                              intersection.length)
                : NSMakeRange(extendHead ? 0 : blockLength, 0);
            id<IDBlockLayoutSnapshot> snapshot = [source
                snapshotForBlockIdentifier:block.identifier
                          documentRevision:revision];
            if (self.document.documentRevision != revision) {
                *retry = YES;
                return nil;
            }
            if (snapshot == nil || !snapshot.valid ||
                ![snapshot.blockIdentifier isEqual:block.identifier] ||
                snapshot.documentRevision != revision ||
                (snapshot.capabilities & IDBlockLayoutCapabilitySelectionSegments) == 0 ||
                NSMaxRange(localRange) > snapshot.utf16Length) {
                return nil;
            }
            NSArray<IDBlockSelectionSegment *> *localSegments = [snapshot
                selectionSegmentsForLocalRange:localRange
                                     extendHead:extendHead
                                     extendTail:extendTail];
            if (self.document.documentRevision != revision) {
                *retry = YES;
                return nil;
            }
            CGPoint origin = [source
                documentOriginForBlockIdentifier:block.identifier];
            if (!IDCoordinatorPointIsFinite(origin)) return nil;
            capturedOrigins[block.identifier] =
                [NSValue value:&origin withObjCType:@encode(CGPoint)];
            // The box this block's selection may reach. Refused on the same terms as a bad origin:
            // the geometry is all-or-nothing, so a block that cannot be measured makes the pass
            // answer nil and UIKit asks again, rather than drawing a document with one block
            // missing from its selection.
            // A source that does not answer has nothing to say, and a block then grows no further
            // than its own glyphs — what every source did before slots existed. Only a source that
            // DOES answer, with something unmeasurable, is a failure.
            CGRect slot = CGRectNull;
            if ([source respondsToSelector:@selector(selectionSlotForBlockIdentifier:)]) {
                slot = [source selectionSlotForBlockIdentifier:block.identifier];
                if (!IDCoordinatorRectIsFinite(slot) || CGRectIsEmpty(slot)) return nil;
            }
            BOOL hasSlot = !CGRectIsNull(slot);
            // The part of that slot which is the BLOCK rather than the space between blocks. Null
            // for a block with no box of its own, which is not a failure — it means every part of
            // its slot is rhythm.
            CGRect ownBox = CGRectNull;
            if ([source respondsToSelector:@selector(selectionBoxForBlockIdentifier:)]) {
                ownBox = [source selectionBoxForBlockIdentifier:block.identifier];
            }
            BOOL hasOwnBox = !CGRectIsNull(ownBox) && IDCoordinatorRectIsFinite(ownBox);
            if (hasSlot) {
                capturedSlots[block.identifier] =
                    [NSValue value:&slot withObjCType:@encode(CGRect)];
            }
            if (localSegments == nil || !snapshot.valid) return nil;
            NSUInteger blockFirstResultIndex = results.count;
            for (NSUInteger segmentIndex = 0; segmentIndex < localSegments.count;
                 segmentIndex += 1) {
                IDBlockSelectionSegment *local = localSegments[segmentIndex];
                if (local.layoutGeneration != snapshot.layoutGeneration ||
                    local.localRange.location == NSNotFound ||
                    local.localRange.location > snapshot.utf16Length ||
                    local.localRange.length > snapshot.utf16Length -
                        local.localRange.location ||
                    !IDCoordinatorRectIsFinite(local.rect) ||
                    CGRectIsEmpty(local.rect) ||
                    !IDCoordinatorWritingDirectionIsValid(local.writingDirection)) {
                    return nil;
                }
                NSRange canonicalRange = NSMakeRange(
                    cursor + local.localRange.location, local.localRange.length);
                // The head side yields the separator to the tail side that already took it, so
                // exactly one segment owns its canonical range — and, with it, the logical
                // endpoint that lands there. Both sides claiming the start of a selection that
                // BEGINS on a separator tripped the duplicate-endpoint guard below, which
                // discarded the whole document's geometry and drew no selection at all
                // (2026-09-15).
                BOOL separatorHead = extendHead &&
                    (local.boundaryRole & IDBlockSelectionBoundaryRoleHead) != 0 &&
                    ![claimedSeparatorLocations containsObject:@(cursor - 1)];
                BOOL separatorTail = extendTail &&
                    (local.boundaryRole & IDBlockSelectionBoundaryRoleTail) != 0;
                if (local.localRange.length == 0 && separatorHead) {
                    canonicalRange = NSMakeRange(cursor - 1, 1);
                } else if (local.localRange.length == 0 && separatorTail) {
                    canonicalRange = NSMakeRange(cursor + blockLength, 1);
                }
                BOOL logicalStart = (intersection.length > 0 &&
                    range.location >= cursor && range.location < cursor + blockLength &&
                    local.containsLocalStart) ||
                    (separatorHead && range.location == cursor - 1) ||
                    (separatorTail && range.location == cursor + blockLength);
                BOOL logicalEnd = (intersection.length > 0 && selectionEnd > 0 &&
                    selectionEnd - 1 >= cursor &&
                    selectionEnd - 1 < cursor + blockLength &&
                    local.containsLocalEnd) ||
                    (separatorHead && selectionEnd == cursor) ||
                    (separatorTail && !nextBlockDrawsTheEndMark &&
                     selectionEnd == cursor + blockLength + 1);
                if ((logicalStart && hasLogicalStart) ||
                    (logicalEnd && hasLogicalEnd)) return nil;
                hasLogicalStart |= logicalStart;
                hasLogicalEnd |= logicalEnd;
                CGRect documentRect = CGRectOffset(local.rect, origin.x, origin.y);
                // A COVERED side reaches the block's slot; an uncovered side keeps hugging its
                // glyphs. The horizontal pair is the rule the legacy canvas already draws its wash
                // by; the vertical pair is its counterpart for the space reserved AROUND the block,
                // which is where every gap in a multi-block selection used to be. Growth only — no
                // rect that could be drawn before becomes empty or unmeasurable here.
                // WHICH LINE this segment is on, and where it sits across that line.
                //
                // The fill rule borrowed from the legacy canvas is per LINE — a line covered to its
                // end reaches the trailing edge, one covered from its beginning reaches the leading
                // edge — and there it enumerates line FRAGMENTS, so one line is one segment. Here it
                // is not: a line of MIXED DIRECTION yields one segment per directional run, and
                // reading "not the first segment" as "not the first line" made every run after the
                // first stretch to the container's edge, filling the whole width of a bidirectional
                // line (engine suite, 2026-09-15: minX 0 against stock's 113.33).
                BOOL isFirstSegment = YES;
                BOOL isLastSegment = YES;
                BOOL leadsItsLine = YES;
                BOOL trailsItsLine = YES;
                for (NSUInteger other = 0; other < localSegments.count; other += 1) {
                    if (other == segmentIndex) continue;
                    CGRect mine = local.rect;
                    CGRect theirs = localSegments[other].rect;
                    if (CGRectGetMinY(theirs) < CGRectGetMinY(mine) - 0.5) {
                        isFirstSegment = NO;
                    }
                    if (CGRectGetMinY(theirs) > CGRectGetMinY(mine) + 0.5) {
                        isLastSegment = NO;
                    }
                    if (ABS(CGRectGetMinY(theirs) - CGRectGetMinY(mine)) > 0.5) continue;
                    if (CGRectGetMinX(theirs) < CGRectGetMinX(mine) - 0.5) {
                        leadsItsLine = NO;
                    }
                    if (CGRectGetMaxX(theirs) > CGRectGetMaxX(mine) + 0.5) {
                        trailsItsLine = NO;
                    }
                }
                // "From its beginning" and "to its end" are LOGICAL, so in a right-to-left line the
                // beginning is the RIGHT edge. Which physical side grows is decided just below.
                BOOL coveredFromLineStart =
                    !isFirstSegment || localRange.location == 0 || extendHead;
                BOOL coveredToLineEnd = !isLastSegment || extendTail;
                BOOL rightToLeft =
                    local.writingDirection == IDBlockWritingDirectionRightToLeft;
                // Only the run at each END of the line may reach that end of it; runs between are
                // hemmed in by their neighbours, whatever the line as a whole is covered to.
                BOOL growLeading = (rightToLeft ? coveredToLineEnd : coveredFromLineStart) &&
                    leadsItsLine;
                BOOL growTrailing = (rightToLeft ? coveredFromLineStart : coveredToLineEnd) &&
                    trailsItsLine;
                // A covered side reaches the slot's edge. For a block with a BOX of its own that edge
                // is exact, not a minimum: TextKit already fills a line covered to a side out to its
                // text CONTAINER's edge, and a box can be narrower than its container. A pull quote
                // is the case — its text lays out across the whole column, centred, while its pill
                // hugs the text — so growth-only kept TextKit's fill and a two-line selection ran to
                // the column's edges on both sides, outside the pill (composer harness, 2026-09-23:
                // x 0 and 267 against a pill at 38..229). Without a box the slot IS the column and
                // growth-only is unchanged. A box that would leave nothing to draw keeps the old
                // answer rather than failing the whole pass.
                CGFloat slotMinX = CGRectGetMinX(documentRect);
                CGFloat slotMaxX = CGRectGetMaxX(documentRect);
                if (growLeading && hasSlot) {
                    slotMinX = hasOwnBox ? CGRectGetMinX(slot)
                                         : MIN(slotMinX, CGRectGetMinX(slot));
                }
                if (growTrailing && hasSlot) {
                    slotMaxX = hasOwnBox ? CGRectGetMaxX(slot)
                                         : MAX(slotMaxX, CGRectGetMaxX(slot));
                }
                if (slotMaxX <= slotMinX) {
                    slotMinX = (growLeading && hasSlot)
                        ? MIN(CGRectGetMinX(documentRect), CGRectGetMinX(slot))
                        : CGRectGetMinX(documentRect);
                    slotMaxX = (growTrailing && hasSlot)
                        ? MAX(CGRectGetMaxX(documentRect), CGRectGetMaxX(slot))
                        : CGRectGetMaxX(documentRect);
                }
                // Vertically a block's reserved space is two different things, and they are washed
                // on different conditions. The padding INSIDE the block's own box belongs to the
                // block, so it is covered when the block's content is covered up to that side of
                // the box. The rhythm OUTSIDE that box separates this block from its neighbours, so
                // it is covered only when the selection actually reaches past — the same condition
                // that decides whether a line is filled to its end. Collapsed into one rule,
                // selecting a quote on its own hugged its text and left its band bare (device,
                // 2026-09-15).
                //
                // "Up to that side" is the block's START for the top padding and its END for the
                // bottom, not "this is the selection's first/last segment in the block": that reads
                // a word on the first line of a two-line code block, quote or pull quote as both,
                // and drew one rect from the box's top padding to its bottom padding — every line of
                // the block (composer harness, 2026-09-22).
                BOOL coversBlockStart = localRange.location == 0 || extendHead;
                BOOL coversBlockEnd = NSMaxRange(localRange) == blockLength || extendTail;
                CGFloat interiorTop = (hasOwnBox && coversBlockStart)
                    ? MIN(CGRectGetMinY(documentRect), CGRectGetMinY(ownBox))
                    : CGRectGetMinY(documentRect);
                CGFloat interiorBottom = (hasOwnBox && coversBlockEnd)
                    ? MAX(CGRectGetMaxY(documentRect), CGRectGetMaxY(ownBox))
                    : CGRectGetMaxY(documentRect);
                CGFloat slotMinY = CGRectGetMinY(documentRect);
                if (isFirstSegment) {
                    slotMinY = (extendHead && hasSlot)
                        ? MIN(CGRectGetMinY(documentRect), CGRectGetMinY(slot))
                        : interiorTop;
                }
                CGFloat slotMaxY = CGRectGetMaxY(documentRect);
                if (isLastSegment) {
                    slotMaxY = (extendTail && hasSlot)
                        ? MAX(CGRectGetMaxY(documentRect), CGRectGetMaxY(slot))
                        : interiorBottom;
                }
                documentRect = CGRectMake(slotMinX, slotMinY,
                                          slotMaxX - slotMinX, slotMaxY - slotMinY);
                if (!IDCoordinatorRectIsFinite(documentRect) ||
                    CGRectIsEmpty(documentRect)) return nil;
                [results addObject:[[IDDocumentSelectionSegment alloc]
                    initWithBlockIdentifier:block.identifier
                              canonicalRange:canonicalRange
                                boundaryRole:local.boundaryRole
                                documentRect:documentRect
                              baselineOffset:local.baselineOffset
                            writingDirection:local.writingDirection
                                    vertical:local.isVertical
                        containsLogicalStart:logicalStart
                          containsLogicalEnd:logicalEnd]];
                if (results.count > blockFirstResultIndex) {
                    NSUInteger blockFirst = cursor == 0 ? 0 : cursor - 1;
                    NSUInteger blockLast = cursor + blockLength;
                    if (startFallbackIndex == NSNotFound &&
                        range.location >= blockFirst &&
                        range.location <= blockLast) {
                        startFallbackIndex = blockFirstResultIndex;
                    }
                    if (selectionEnd >= 1 && selectionEnd - 1 >= blockFirst &&
                        selectionEnd - 1 <= blockLast) {
                        endFallbackIndex = results.count - 1;
                    }
                }
                if ((separatorHead || separatorTail) &&
                    canonicalRange.length == 1) {
                    [claimedSeparatorLocations addObject:
                        @(canonicalRange.location)];
                }
            }
        }
        cursor += blockLength;
        if (index + 1 < blocks.count) cursor += 1;
    }

    // THE GEOMETRY ALWAYS NAMES ITS OWN ENDPOINTS.
    //
    // A block yields the selection's end to the block after the separator, because that is where the
    // caret for that offset is. The yield is decided BEFORE the block after has been asked for
    // anything, though, and that block may contribute no segment at all — a block with glyphs
    // answers nothing for a zero-length range at its start. The end was then claimed by nobody, and
    // the geometry described a selection with no end: invisible in the app, because UIKit
    // synthesises a rect of its own when none carries the flag, and a contract violation all the
    // same (engine suite, 2026-09-15).
    //
    // So the yield is an optimisation and not a transfer of ownership: where it found a taker,
    // nothing to do; where it did not, the claim stays with the last segment that could hold it.
    //
    // Only a segment that actually CONTAINS the endpoint may take it back. An endpoint can be
    // legitimately unclaimed — when it lies in a block that is not eligible, none of the segments
    // present is where it is, and naming one would put a handle on text the user did not select.
    // That is a rule of its own and this repair must not break it.
    if (results.count > 0 && (!hasLogicalStart || !hasLogicalEnd)) {
        NSUInteger startIndex = hasLogicalStart ? NSNotFound : startFallbackIndex;
        NSUInteger endIndex = hasLogicalEnd ? NSNotFound : endFallbackIndex;
        for (NSUInteger index = 0; index < results.count; index += 1) {
            if (index != startIndex && index != endIndex) continue;
            IDDocumentSelectionSegment *segment = results[index];
            results[index] = [[IDDocumentSelectionSegment alloc]
                initWithBlockIdentifier:segment.blockIdentifier
                          canonicalRange:segment.canonicalRange
                            boundaryRole:segment.boundaryRole
                            documentRect:segment.documentRect
                          baselineOffset:segment.baselineOffset
                        writingDirection:segment.writingDirection
                                vertical:segment.isVertical
                    containsLogicalStart:segment.containsLogicalStart ||
                                         index == startIndex
                      containsLogicalEnd:segment.containsLogicalEnd ||
                                         index == endIndex];
        }
        hasLogicalStart |= startIndex != NSNotFound;
        hasLogicalEnd |= endIndex != NSNotFound;
    }

    if (self.document.documentRevision != revision) {
        *retry = YES;
        return nil;
    }
    for (NSUUID *identifier in capturedOrigins) {
        CGPoint current = [source documentOriginForBlockIdentifier:identifier];
        CGPoint captured = CGPointZero;
        [capturedOrigins[identifier] getValue:&captured size:sizeof(captured)];
        if (!CGPointEqualToPoint(current, captured)) {
            *retry = YES;
            return nil;
        }
    }
    for (NSUUID *identifier in capturedSlots) {
        // A slot read against a layout that has since moved is a WRONG rect, not a missing one, and
        // a wrong one gets drawn. Re-read on the same terms as the origin above.
        if (![source respondsToSelector:@selector(selectionSlotForBlockIdentifier:)]) continue;
        CGRect current = [source selectionSlotForBlockIdentifier:identifier];
        CGRect captured = CGRectNull;
        [capturedSlots[identifier] getValue:&captured size:sizeof(captured)];
        if (!CGRectEqualToRect(current, captured)) {
            *retry = YES;
            return nil;
        }
    }
    IDDocumentGeometryEligibilitySnapshot *fresh = [self
        id_validatedSelectionGeometryEligibilityForDocumentRevision:revision];
    if (fresh == nil ||
        fresh.geometryGeneration != eligibility.geometryGeneration ||
        ![fresh.orderedBlockIdentifiers
            isEqual:eligibility.orderedBlockIdentifiers]) {
        *retry = YES;
        return nil;
    }
    return [[IDDocumentSelectionGeometry alloc]
        initWithCanonicalSelection:range
                   documentRevision:revision
           sourceGeometryGeneration:eligibility.geometryGeneration
                           segments:results];
}

- (IDDocumentSelectionGeometry *)selectionGeometryForCanonicalRange:
    (NSRange)range {
    for (NSUInteger attempt = 0; attempt < 2; attempt += 1) {
        BOOL retry = NO;
        IDDocumentSelectionGeometry *result = [self
            id_selectionGeometryAttemptForCanonicalRange:range retry:&retry];
        if (result != nil || !retry) return result;
    }
    return nil;
}

- (instancetype)initWithDocument:(IDBlockDocument *)document
                            source:(id<IDDocumentLayoutSnapshotSource>)source {
    if (document == nil || source == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Document layout coordinator requires document and source."];
    }
    self = [super init];
    if (self != nil) {
        _document = document;
        _source = source;
    }
    return self;
}

- (IDDocumentTextPosition *)id_positionForLocation:
    (IDCanonicalLocation *)location
                                             affinity:
    (IDBlockTextAffinity)affinity
                                           projection:
    (IDCanonicalTextProjection *)projection
                                     documentRevision:
    (NSUInteger)documentRevision {
    NSUInteger canonicalOffset = [projection
        canonicalOffsetForBlockIdentifier:location.blockIdentifier
                               localOffset:location.localOffset];
    return [[IDDocumentTextPosition alloc]
        initWithBlockIdentifier:location.blockIdentifier
                   localPosition:IDBlockTextPositionMake(location.localOffset,
                                                          affinity)
                 canonicalOffset:canonicalOffset
                documentRevision:documentRevision];
}

- (id<IDBlockLayoutSnapshot>)id_snapshotForLocation:
    (IDCanonicalLocation *)location
                                             revision:(NSUInteger)revision
                                         capabilities:
    (IDBlockLayoutCapability)capabilities {
    id<IDDocumentLayoutSnapshotSource> source = self.source;
    if (source == nil) {
        return nil;
    }
    if (![[source orderedBlockIdentifiers]
            containsObject:location.blockIdentifier]) {
        return nil;
    }
    id<IDBlockLayoutSnapshot> snapshot = [source
        snapshotForBlockIdentifier:location.blockIdentifier
                  documentRevision:revision];
    if (snapshot == nil) {
        return nil;
    }
    if (![snapshot.blockIdentifier isEqual:location.blockIdentifier] ||
        snapshot.documentRevision != revision || !snapshot.valid ||
        (snapshot.capabilities & capabilities) != capabilities ||
        location.localOffset > snapshot.utf16Length) {
        return nil;
    }
    return snapshot;
}

- (BOOL)id_snapshot:(id<IDBlockLayoutSnapshot>)snapshot
    remainsValidForIdentifier:(NSUUID *)identifier
                     revision:(NSUInteger)revision
                 capabilities:(IDBlockLayoutCapability)capabilities
               requiredOffset:(NSUInteger)requiredOffset {
    return snapshot != nil &&
        [snapshot.blockIdentifier isEqual:identifier] &&
        snapshot.documentRevision == revision && snapshot.valid &&
        (snapshot.capabilities & capabilities) == capabilities &&
        requiredOffset <= snapshot.utf16Length;
}

- (CGPoint)id_originForIdentifier:(NSUUID *)identifier {
    return [self.source documentOriginForBlockIdentifier:identifier];
}

- (IDDocumentTextPosition *)id_finalPositionForRequestedOffset:
    (NSUInteger)requestedOffset
                                                   affinity:
    (IDBlockTextAffinity)affinity {
    NSUInteger revision = self.document.documentRevision;
    NSUInteger offset = MIN(requestedOffset, self.document.canonicalLength);
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
    IDCanonicalLocation *location =
        [projection locationForCanonicalOffset:offset];
    if (location == nil) {
        return nil;
    }
    return [self id_positionForLocation:location
                               affinity:affinity
                             projection:projection
                       documentRevision:revision];
}

- (IDDocumentCaretGeometry *)caretGeometryForCanonicalOffset:
    (NSUInteger)offset
                                                               affinity:
    (IDBlockTextAffinity)affinity {
    if (!IDCoordinatorAffinityIsValid(affinity)) {
        return nil;
    }
    for (NSUInteger attempt = 0; attempt < 2; attempt += 1) {
        NSUInteger revision = self.document.documentRevision;
        IDCanonicalTextProjection *projection =
            [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
        IDCanonicalLocation *location =
            [projection locationForCanonicalOffset:offset];
        if (location == nil) {
            return nil;
        }
        id<IDBlockLayoutSnapshot> snapshot = [self
            id_snapshotForLocation:location
                          revision:revision
                      capabilities:IDBlockLayoutCapabilityCaretGeometry];
        if (self.document.documentRevision != revision) {
            continue;
        }
        if (snapshot == nil) {
            return nil;
        }
        IDBlockCaretGeometry *local = [snapshot
            caretGeometryForPosition:IDBlockTextPositionMake(location.localOffset,
                                                              affinity)];
        if (self.document.documentRevision != revision) {
            continue;
        }
        if (local == nil ||
            ![self id_snapshot:snapshot
                remainsValidForIdentifier:location.blockIdentifier
                                 revision:revision
                             capabilities:IDBlockLayoutCapabilityCaretGeometry
                           requiredOffset:location.localOffset] ||
            local.position.utf16Offset != location.localOffset ||
            !IDCoordinatorAffinityIsValid(local.position.affinity) ||
            !IDCoordinatorRectIsFinite(local.rect)) {
            return nil;
        }
        CGPoint origin = [self id_originForIdentifier:location.blockIdentifier];
        if (self.document.documentRevision != revision) {
            continue;
        }
        if (!IDCoordinatorPointIsFinite(origin) ||
            ![self id_snapshot:snapshot
                remainsValidForIdentifier:location.blockIdentifier
                                 revision:revision
                             capabilities:IDBlockLayoutCapabilityCaretGeometry
                           requiredOffset:location.localOffset]) {
            return nil;
        }
        CGRect documentRect = CGRectOffset(local.rect, origin.x, origin.y);
        if (!IDCoordinatorRectIsFinite(documentRect)) {
            return nil;
        }
        IDDocumentTextPosition *position = [self
            id_positionForLocation:location
                          affinity:local.position.affinity
                        projection:projection
                  documentRevision:revision];
        return [[IDDocumentCaretGeometry alloc]
            initWithPosition:position
                documentRect:documentRect
              lineIdentifier:local.lineIdentifier
                       exact:YES];
    }
    return nil;
}

- (IDDocumentTextPosition *)nearestPositionToDocumentPoint:(CGPoint)point {
    if (!IDCoordinatorPointIsFinite(point)) {
        return nil;
    }
    for (NSUInteger attempt = 0; attempt < 2; attempt += 1) {
        NSUInteger revision = self.document.documentRevision;
        id<IDDocumentLayoutSnapshotSource> source = self.source;
        NSUUID *identifier =
            [source nearestBlockIdentifierForDocumentPoint:point];
        if (self.document.documentRevision != revision) {
            continue;
        }
        if (identifier == nil) {
            return nil;
        }
        IDCanonicalTextProjection *projection =
            [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
        NSUInteger blockStart = [projection
            canonicalOffsetForBlockIdentifier:identifier localOffset:0];
        IDCanonicalLocation *location =
            [projection locationForCanonicalOffset:blockStart];
        id<IDBlockLayoutSnapshot> snapshot = [self
            id_snapshotForLocation:location
                          revision:revision
                      capabilities:IDBlockLayoutCapabilityPointHitTesting];
        if (self.document.documentRevision != revision) {
            continue;
        }
        if (snapshot == nil) {
            return nil;
        }
        CGPoint origin = [self id_originForIdentifier:identifier];
        if (self.document.documentRevision != revision) {
            continue;
        }
        if (!IDCoordinatorPointIsFinite(origin) ||
            ![self id_snapshot:snapshot
                remainsValidForIdentifier:identifier
                                 revision:revision
                             capabilities:IDBlockLayoutCapabilityPointHitTesting
                           requiredOffset:location.localOffset]) {
            return nil;
        }
        CGPoint localPoint = CGPointMake(point.x - origin.x,
                                         point.y - origin.y);
        IDBlockCaretNavigationResult local =
            [snapshot caretNavigationResultForPoint:localPoint];
        if (self.document.documentRevision != revision) {
            continue;
        }
        if (!local.found ||
            local.position.utf16Offset > snapshot.utf16Length ||
            !IDCoordinatorAffinityIsValid(local.position.affinity) ||
            ![self id_snapshot:snapshot
                remainsValidForIdentifier:identifier
                                 revision:revision
                             capabilities:IDBlockLayoutCapabilityPointHitTesting
                           requiredOffset:local.position.utf16Offset]) {
            return nil;
        }
        NSUInteger canonicalOffset = [projection
            canonicalOffsetForBlockIdentifier:identifier
                                   localOffset:local.position.utf16Offset];
        return [[IDDocumentTextPosition alloc]
            initWithBlockIdentifier:identifier
                       localPosition:local.position
                     canonicalOffset:canonicalOffset
                    documentRevision:revision];
    }
    return nil;
}

- (IDDocumentLineGeometry *)lineGeometryForCanonicalOffset:(NSUInteger)offset
                                                   affinity:(IDBlockTextAffinity)affinity {
    if (!IDCoordinatorAffinityIsValid(affinity)) {
        return nil;
    }
    for (NSUInteger attempt = 0; attempt < 2; attempt += 1) {
        NSUInteger revision = self.document.documentRevision;
        IDCanonicalTextProjection *projection =
            [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
        IDCanonicalLocation *location =
            [projection locationForCanonicalOffset:offset];
        if (location == nil) {
            return nil;
        }
        id<IDBlockLayoutSnapshot> snapshot = [self
            id_snapshotForLocation:location
                          revision:revision
                      capabilities:IDBlockLayoutCapabilityLineRanges];
        if (self.document.documentRevision != revision) {
            continue;
        }
        if (snapshot == nil) {
            return nil;
        }
        IDBlockTextAffinity resolvedAffinity = affinity;
        NSRange local = [snapshot
            lineRangeEnclosingPosition:
                IDBlockTextPositionMake(location.localOffset, affinity)
                     resolvedAffinity:&resolvedAffinity];
        if (self.document.documentRevision != revision) {
            continue;
        }
        if (![self id_snapshot:snapshot
                remainsValidForIdentifier:location.blockIdentifier
                                 revision:revision
                             capabilities:IDBlockLayoutCapabilityLineRanges
                           requiredOffset:location.localOffset] ||
            !IDCoordinatorAffinityIsValid(resolvedAffinity) ||
            local.location == NSNotFound ||
            local.location > snapshot.utf16Length ||
            local.length > snapshot.utf16Length - local.location ||
            location.localOffset < local.location ||
            location.localOffset > local.location + local.length) {
            return nil;
        }
        NSUInteger start = [projection
            canonicalOffsetForBlockIdentifier:location.blockIdentifier
                                   localOffset:local.location];
        NSRange canonicalRange = NSMakeRange(start, local.length);
        if (self.document.documentRevision != revision ||
            canonicalRange.location > self.document.canonicalLength ||
            canonicalRange.length >
                self.document.canonicalLength - canonicalRange.location) {
            continue;
        }
        IDCanonicalLocation *roundTrip =
            [projection locationForCanonicalOffset:offset];
        if (roundTrip == nil ||
            ![roundTrip.blockIdentifier isEqual:location.blockIdentifier] ||
            roundTrip.localOffset != location.localOffset) {
            return nil;
        }
        IDDocumentTextPosition *position = [self
            id_positionForLocation:location
                          affinity:resolvedAffinity
                        projection:projection
                  documentRevision:revision];
        return [[IDDocumentLineGeometry alloc]
            initWithPosition:position
              canonicalRange:canonicalRange
            resolvedAffinity:resolvedAffinity
                       exact:YES];
    }
    return nil;
}

- (IDDocumentCaretNavigationResult *)
    visuallyAdjacentPositionFromCanonicalOffset:(NSUInteger)offset
                                        affinity:(IDBlockTextAffinity)affinity
                                       direction:(IDBlockLayoutDirection)direction
                            anchorPositionOffset:(CGFloat)anchorPositionOffset {
    if (!isfinite(anchorPositionOffset)) {
        return nil;
    }
    BOOL horizontal = direction == IDBlockLayoutDirectionLeft ||
        direction == IDBlockLayoutDirectionRight;
    BOOL vertical = direction == IDBlockLayoutDirectionUp ||
        direction == IDBlockLayoutDirectionDown;
    if (!horizontal && !vertical) {
        return nil;
    }
    for (NSUInteger attempt = 0; attempt < 2; attempt += 1) {
        NSUInteger revision = self.document.documentRevision;
        IDCanonicalTextProjection *projection =
            [[IDCanonicalTextProjection alloc] initWithDocument:self.document];
        IDCanonicalLocation *location =
            [projection locationForCanonicalOffset:offset];
        if (location == nil) {
            return nil;
        }
        id<IDBlockLayoutSnapshot> snapshot = [self
            id_snapshotForLocation:location
                          revision:revision
                      capabilities:IDBlockLayoutCapabilityVisualNavigation |
                          (horizontal
                              ? IDBlockLayoutCapabilityBaseWritingDirection
                              : IDBlockLayoutCapabilityCaretGeometry)];
        if (self.document.documentRevision != revision) {
            continue;
        }
        if (snapshot == nil) {
            return nil;
        }
        CGPoint sourceOrigin = [self
            id_originForIdentifier:location.blockIdentifier];
        if (self.document.documentRevision != revision) {
            continue;
        }
        if (!IDCoordinatorPointIsFinite(sourceOrigin)) {
            return nil;
        }
        CGFloat localAnchorPositionOffset =
            anchorPositionOffset - sourceOrigin.x;
        if (!isfinite(localAnchorPositionOffset)) {
            return nil;
        }
        IDBlockCaretNavigationResult local = [snapshot
            caretNavigationResultFromPosition:
                IDBlockTextPositionMake(location.localOffset, affinity)
                                    direction:direction
                         anchorPositionOffset:localAnchorPositionOffset];
        if (self.document.documentRevision != revision) {
            continue;
        }
        IDBlockLayoutCapability sourceCapabilities =
            IDBlockLayoutCapabilityVisualNavigation |
            (horizontal
                ? IDBlockLayoutCapabilityBaseWritingDirection
                : IDBlockLayoutCapabilityCaretGeometry);
        if (![self id_snapshot:snapshot
            remainsValidForIdentifier:location.blockIdentifier
                             revision:revision
                         capabilities:sourceCapabilities
                       requiredOffset:location.localOffset]) {
            return nil;
        }
        if (local.found &&
            (local.position.utf16Offset > snapshot.utf16Length ||
             !IDCoordinatorAffinityIsValid(local.position.affinity) ||
             !isfinite(local.anchorPositionOffset))) {
            return nil;
        }
        BOOL localIsDestination = local.found;
        if (localIsDestination && vertical) {
            IDBlockCaretGeometry *sourceCaret = [snapshot
                caretGeometryForPosition:
                    IDBlockTextPositionMake(location.localOffset, affinity)];
            if (self.document.documentRevision != revision) {
                continue;
            }
            if (![self id_snapshot:snapshot
                remainsValidForIdentifier:location.blockIdentifier
                                 revision:revision
                             capabilities:sourceCapabilities
                           requiredOffset:location.localOffset]) {
                return nil;
            }
            IDBlockCaretGeometry *destinationCaret = [snapshot
                caretGeometryForPosition:local.position];
            if (self.document.documentRevision != revision) {
                continue;
            }
            if (![self id_snapshot:snapshot
                remainsValidForIdentifier:location.blockIdentifier
                                 revision:revision
                             capabilities:sourceCapabilities
                           requiredOffset:local.position.utf16Offset]) {
                return nil;
            }
            localIsDestination = sourceCaret != nil && destinationCaret != nil &&
                IDCoordinatorRectIsFinite(sourceCaret.rect) &&
                IDCoordinatorRectIsFinite(destinationCaret.rect);
            if (localIsDestination) {
                CGFloat sourceMidY = CGRectGetMidY(sourceCaret.rect);
                CGFloat destinationMidY = CGRectGetMidY(destinationCaret.rect);
                localIsDestination = direction == IDBlockLayoutDirectionDown
                    ? destinationMidY > sourceMidY +
                        IDCoordinatorVerticalProgressEpsilon
                    : destinationMidY < sourceMidY -
                        IDCoordinatorVerticalProgressEpsilon;
            }
        }
        if (!localIsDestination && horizontal) {
            IDBlockWritingDirection writingDirection = [snapshot
                id_snapshotBaseWritingDirectionAtPosition:
                    IDBlockTextPositionMake(location.localOffset, affinity)];
            if (self.document.documentRevision != revision) {
                continue;
            }
            if (![self id_snapshot:snapshot
                remainsValidForIdentifier:location.blockIdentifier
                                 revision:revision
                             capabilities:sourceCapabilities
                           requiredOffset:location.localOffset] ||
                !IDCoordinatorWritingDirectionIsValid(writingDirection)) {
                return nil;
            }
            BOOL movesForward = direction == IDBlockLayoutDirectionRight
                ? writingDirection != IDBlockWritingDirectionRightToLeft
                : writingDirection == IDBlockWritingDirectionRightToLeft;
            NSString *string = projection.string;
            NSUInteger adjacentOffset = NSNotFound;
            if (movesForward) {
                if (offset >= string.length) {
                    return nil;
                }
                adjacentOffset = NSMaxRange(
                    [string rangeOfComposedCharacterSequenceAtIndex:offset]);
            } else {
                if (offset == 0) {
                    return nil;
                }
                adjacentOffset = [string
                    rangeOfComposedCharacterSequenceAtIndex:offset - 1].location;
            }
            IDCanonicalLocation *destination = [projection
                locationForCanonicalOffset:adjacentOffset];
            if (destination == nil || [self
                    id_snapshotForLocation:destination
                                  revision:revision
                              capabilities:0] == nil) {
                return nil;
            }
            if (self.document.documentRevision != revision) {
                continue;
            }
            IDDocumentTextPosition *position = [self
                id_positionForLocation:destination
                               affinity:affinity
                             projection:projection
                       documentRevision:revision];
            return [[IDDocumentCaretNavigationResult alloc]
                initWithPosition:position
                    anchorPositionOffset:anchorPositionOffset
                                   exact:YES];
        }
        if (!localIsDestination) {
            id<IDDocumentLayoutSnapshotSource> source = self.source;
            NSArray<NSUUID *> *orderedIdentifiers =
                [source orderedBlockIdentifiers];
            if (self.document.documentRevision != revision) {
                continue;
            }
            NSUInteger sourceIndex = [orderedIdentifiers
                indexOfObject:location.blockIdentifier];
            if (sourceIndex == NSNotFound) {
                return nil;
            }
            NSUUID *destinationIdentifier = nil;
            if ([source respondsToSelector:@selector(verticallyAdjacentBlockIdentifierFromBlockIdentifier:downward:anchorPositionOffset:)]) {
                destinationIdentifier = [source
                    verticallyAdjacentBlockIdentifierFromBlockIdentifier:location.blockIdentifier
                                                                downward:direction == IDBlockLayoutDirectionDown
                                                    anchorPositionOffset:anchorPositionOffset];
                if (self.document.documentRevision != revision) {
                    continue;
                }
            } else {
                NSUInteger destinationIndex = NSNotFound;
                if (direction == IDBlockLayoutDirectionDown) {
                    if (sourceIndex + 1 < orderedIdentifiers.count) {
                        destinationIndex = sourceIndex + 1;
                    }
                } else if (sourceIndex > 0) {
                    destinationIndex = sourceIndex - 1;
                }
                if (destinationIndex != NSNotFound) {
                    destinationIdentifier = orderedIdentifiers[destinationIndex];
                }
            }
            if (destinationIdentifier == nil) {
                return nil;
            }
            NSUInteger destinationStartOffset = [projection
                canonicalOffsetForBlockIdentifier:destinationIdentifier
                                       localOffset:0];
            IDCanonicalLocation *destinationLocation = [projection
                locationForCanonicalOffset:destinationStartOffset];
            if (destinationLocation == nil || ![destinationLocation.blockIdentifier
                    isEqual:destinationIdentifier]) {
                return nil;
            }
            IDBlockLayoutCapability destinationCapabilities =
                IDBlockLayoutCapabilityCaretGeometry |
                IDBlockLayoutCapabilityPointHitTesting;
            id<IDBlockLayoutSnapshot> destinationSnapshot = [self
                id_snapshotForLocation:destinationLocation
                              revision:revision
                          capabilities:destinationCapabilities];
            if (self.document.documentRevision != revision) {
                continue;
            }
            if (destinationSnapshot == nil) {
                return nil;
            }
            IDBlockTextPosition edgePosition = direction ==
                    IDBlockLayoutDirectionDown
                ? IDBlockTextPositionMake(0,
                                          IDBlockTextAffinityDownstream)
                : IDBlockTextPositionMake(destinationSnapshot.utf16Length,
                                          IDBlockTextAffinityUpstream);
            IDBlockCaretGeometry *edgeCaret = [destinationSnapshot
                caretGeometryForPosition:edgePosition];
            if (self.document.documentRevision != revision) {
                continue;
            }
            if (![self id_snapshot:destinationSnapshot
                remainsValidForIdentifier:destinationIdentifier
                                 revision:revision
                             capabilities:destinationCapabilities
                           requiredOffset:edgePosition.utf16Offset]) {
                return nil;
            }
            if (edgeCaret == nil || !IDCoordinatorRectIsFinite(edgeCaret.rect)) {
                return nil;
            }
            CGPoint destinationOrigin = [self
                id_originForIdentifier:destinationIdentifier];
            if (self.document.documentRevision != revision) {
                continue;
            }
            if (!IDCoordinatorPointIsFinite(destinationOrigin)) {
                return nil;
            }
            CGPoint destinationPoint = CGPointMake(
                anchorPositionOffset - destinationOrigin.x,
                CGRectGetMidY(edgeCaret.rect));
            if (!IDCoordinatorPointIsFinite(destinationPoint)) {
                return nil;
            }
            IDBlockCaretNavigationResult destination = [destinationSnapshot
                caretNavigationResultForPoint:destinationPoint];
            if (self.document.documentRevision != revision) {
                continue;
            }
            if (![self id_snapshot:destinationSnapshot
                remainsValidForIdentifier:destinationIdentifier
                                 revision:revision
                             capabilities:destinationCapabilities
                           requiredOffset:edgePosition.utf16Offset]) {
                return nil;
            }
            if (!destination.found ||
                destination.position.utf16Offset >
                    destinationSnapshot.utf16Length ||
                !IDCoordinatorAffinityIsValid(destination.position.affinity) ||
                !isfinite(destination.anchorPositionOffset)) {
                return nil;
            }
            NSUInteger canonicalOffset = [projection
                canonicalOffsetForBlockIdentifier:destinationIdentifier
                                       localOffset:destination.position.utf16Offset];
            IDDocumentTextPosition *position = [[IDDocumentTextPosition alloc]
                initWithBlockIdentifier:destinationIdentifier
                           localPosition:destination.position
                         canonicalOffset:canonicalOffset
                        documentRevision:revision];
            return [[IDDocumentCaretNavigationResult alloc]
                initWithPosition:position
                    anchorPositionOffset:anchorPositionOffset
                                   exact:YES];
        }
        CGFloat documentAnchorPositionOffset = horizontal
            ? local.anchorPositionOffset + sourceOrigin.x
            : anchorPositionOffset;
        if (!isfinite(documentAnchorPositionOffset)) {
            return nil;
        }
        NSUInteger canonicalOffset = [projection
            canonicalOffsetForBlockIdentifier:location.blockIdentifier
                                   localOffset:local.position.utf16Offset];
        IDDocumentTextPosition *position = [[IDDocumentTextPosition alloc]
            initWithBlockIdentifier:location.blockIdentifier
                       localPosition:local.position
                     canonicalOffset:canonicalOffset
                    documentRevision:revision];
        return [[IDDocumentCaretNavigationResult alloc]
            initWithPosition:position
                anchorPositionOffset:documentAnchorPositionOffset
                               exact:YES];
    }
    IDDocumentTextPosition *position = [self
        id_finalPositionForRequestedOffset:offset affinity:affinity];
    if (position == nil) {
        return nil;
    }
    return [[IDDocumentCaretNavigationResult alloc]
        initWithPosition:position
            anchorPositionOffset:anchorPositionOffset
                           exact:NO];
}

@end

#endif
