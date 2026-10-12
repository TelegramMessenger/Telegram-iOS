@import XCTest;

#import "IDBlockDocument.h"
#import "IDBlockLayout.h"
#import "IDBlockLayoutSnapshot.h"
#import "IDBlockStackCanvasView.h"
#import "IDBlockTextTestSupport.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDDocumentLayoutCoordinator.h"
#import "IDRichTextLayoutController.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDRichTextPosition.h"
#import "IDTextLayoutCanvasView.h"

#include <math.h>

@interface IDCoordinatorMalformedCaretGeometry : IDBlockCaretGeometry
@end

@implementation IDCoordinatorMalformedCaretGeometry

- (CGRect)rect {
    return CGRectMake(NAN, 2.0, 2.0, 18.0);
}

@end

@interface IDCoordinatorFakeSnapshot : NSObject <IDBlockLayoutSnapshot>
@property(nonatomic, copy) NSUUID *blockIdentifier;
@property(nonatomic) NSUInteger utf16Length;
@property(nonatomic) NSUInteger documentRevision;
@property(nonatomic) NSUInteger contentRevision;
@property(nonatomic) NSUInteger layoutGeneration;
@property(nonatomic) IDBlockLayoutConstraints layoutConstraints;
@property(nonatomic) IDBlockLayoutCapability capabilities;
@property(nonatomic, getter=isValid) BOOL valid;
@property(nonatomic) CGSize usedSize;
@property(nonatomic) IDBlockWritingDirection baseWritingDirection;
@property(nonatomic) CGFloat lastNavigationAnchor;
@property(nonatomic) CGFloat returnedAnchorDelta;
@property(nonatomic) BOOL returnsSameLineVerticalStop;
@property(nonatomic) CGFloat lineMidY;
@property(nonatomic) CGFloat recordedHitTestX;
@property(nonatomic) NSUInteger forcedPointOffset;
@property(nonatomic) IDBlockTextAffinity forcedPointAffinity;
@property(nonatomic) BOOL returnsNonfiniteCaretRect;
@property(nonatomic) BOOL invalidatesAfterCaretGeometry;
@property(nonatomic, copy, nullable) void (^onCaretGeometry)(void);
@property(nonatomic, copy, nullable) void (^onPointHit)(void);
@property(nonatomic, copy, nullable) void (^onLineRange)(void);
@property(nonatomic) BOOL usesLineRangeOverride;
@property(nonatomic) NSRange lineRangeOverride;
@property(nonatomic) BOOL usesLineResolvedAffinityOverride;
@property(nonatomic) IDBlockTextAffinity lineResolvedAffinity;
@property(nonatomic) NSUInteger caretGeometryRequestCount;
@property(nonatomic) NSUInteger pointHitRequestCount;
@property(nonatomic) NSUInteger lineRangeRequestCount;
@property(nonatomic) NSUInteger selectionSegmentRequestCount;
@property(nonatomic, copy, nullable) NSArray<IDBlockSelectionSegment *> *selectionSegments;
@property(nonatomic, copy, nullable) void (^onSelectionSegments)(void);
@end

@implementation IDCoordinatorFakeSnapshot

- (NSArray<IDBlockSelectionSegment *> *)selectionSegmentsForLocalRange:
    (NSRange)range
                                                          extendHead:
    (BOOL)extendHead
                                                          extendTail:
    (BOOL)extendTail {
    (void)range;
    (void)extendHead;
    (void)extendTail;
    self.selectionSegmentRequestCount += 1;
    if (self.onSelectionSegments != nil) self.onSelectionSegments();
    return self.selectionSegments;
}

- (IDBlockCaretGeometry *)caretGeometryForPosition:
    (IDBlockTextPosition)position {
    self.caretGeometryRequestCount += 1;
    if (!self.valid ||
        !(self.capabilities & IDBlockLayoutCapabilityCaretGeometry) ||
        position.utf16Offset > self.utf16Length) {
        return nil;
    }
    if (self.onCaretGeometry != nil) {
        self.onCaretGeometry();
    }
    Class geometryClass = self.returnsNonfiniteCaretRect
        ? IDCoordinatorMalformedCaretGeometry.class
        : IDBlockCaretGeometry.class;
    IDBlockCaretGeometry *geometry = [[geometryClass alloc]
        initWithPosition:position
                    rect:CGRectMake(position.utf16Offset * 10.0,
                                    self.lineMidY - 9.0,
                                    2.0,
                                    18.0)
        writingDirection:IDBlockWritingDirectionLeftToRight
          lineIdentifier:[[IDBlockLineIdentifier alloc]
              initWithLocalRange:NSMakeRange(0, self.utf16Length)
                layoutGeneration:self.layoutGeneration]];
    if (self.invalidatesAfterCaretGeometry) {
        self.valid = NO;
    }
    return geometry;
}

- (IDBlockCaretNavigationResult)caretNavigationResultForPoint:(CGPoint)point {
    self.pointHitRequestCount += 1;
    self.recordedHitTestX = point.x;
    if (self.onPointHit != nil) {
        self.onPointHit();
    }
    IDBlockTextPosition fallback =
        IDBlockTextPositionMake(0, IDBlockTextAffinityDownstream);
    if (!self.valid ||
        !(self.capabilities & IDBlockLayoutCapabilityPointHitTesting) ||
        !isfinite(point.x) || !isfinite(point.y)) {
        return (IDBlockCaretNavigationResult){
            .found = NO,
            .position = fallback,
        };
    }
    CGFloat local = floor(MAX(point.x, 0) / 10.0);
    NSUInteger offset = self.forcedPointOffset == NSNotFound
        ? MIN((NSUInteger)local, self.utf16Length)
        : MIN(self.forcedPointOffset, self.utf16Length);
    IDBlockTextAffinity affinity = self.forcedPointOffset == NSNotFound
        ? IDBlockTextAffinityDownstream
        : self.forcedPointAffinity;
    return (IDBlockCaretNavigationResult){
        .found = YES,
        .position = IDBlockTextPositionMake(offset, affinity),
        .anchorPositionOffset = point.x,
    };
}

- (NSRange)lineRangeEnclosingPosition:(IDBlockTextPosition)position
                     resolvedAffinity:(IDBlockTextAffinity *)affinity {
    self.lineRangeRequestCount += 1;
    if (self.onLineRange != nil) {
        self.onLineRange();
    }
    if (!self.valid ||
        !(self.capabilities & IDBlockLayoutCapabilityLineRanges) ||
        position.utf16Offset > self.utf16Length) {
        return NSMakeRange(NSNotFound, 0);
    }
    if (affinity != NULL) {
        *affinity = self.usesLineResolvedAffinityOverride
            ? self.lineResolvedAffinity
            : position.affinity;
    }
    return self.usesLineRangeOverride
        ? self.lineRangeOverride
        : NSMakeRange(0, self.utf16Length);
}

- (IDBlockWritingDirection)id_snapshotBaseWritingDirectionAtPosition:
    (IDBlockTextPosition)position {
    if (position.utf16Offset > self.utf16Length) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Fake direction offset out of bounds"];
    }
    return self.baseWritingDirection;
}

- (IDBlockCaretNavigationResult)caretNavigationResultFromPosition:
    (IDBlockTextPosition)position
                                                    direction:
    (IDBlockLayoutDirection)direction
                                         anchorPositionOffset:
    (CGFloat)anchorPositionOffset {
    self.lastNavigationAnchor = anchorPositionOffset;
    if (!self.valid ||
        !(self.capabilities & IDBlockLayoutCapabilityVisualNavigation) ||
        !isfinite(anchorPositionOffset)) {
        return (IDBlockCaretNavigationResult){
            .found = NO,
            .position = position,
            .anchorPositionOffset = anchorPositionOffset,
        };
    }
    if (direction == IDBlockLayoutDirectionUp ||
        direction == IDBlockLayoutDirectionDown) {
        return (IDBlockCaretNavigationResult){
            .found = self.returnsSameLineVerticalStop,
            .position = position,
            .anchorPositionOffset = anchorPositionOffset,
        };
    }
    NSUInteger target = position.utf16Offset;
    BOOL found = YES;
    BOOL movesForward = direction == IDBlockLayoutDirectionRight
        ? self.baseWritingDirection != IDBlockWritingDirectionRightToLeft
        : self.baseWritingDirection == IDBlockWritingDirectionRightToLeft;
    if (movesForward && target < self.utf16Length) {
        target += 1;
    } else if (!movesForward && target > 0) {
        target -= 1;
    } else {
        found = NO;
    }
    return (IDBlockCaretNavigationResult){
        .found = found,
        .position = IDBlockTextPositionMake(target, position.affinity),
        .anchorPositionOffset = anchorPositionOffset + self.returnedAnchorDelta,
    };
}

@end

@interface IDCoordinatorFakeSource : NSObject <IDDocumentLayoutSnapshotSource>
@property(nonatomic, weak) IDBlockDocument *document;
@property(nonatomic, copy) NSDictionary<NSUUID *, NSValue *> *origins;
@property(nonatomic) NSUInteger geometryGeneration;
@property(nonatomic, copy, nullable) NSArray<NSUUID *> *eligibleIdentifiers;
@property(nonatomic) NSUInteger eligibilityRequestCount;
@property(nonatomic, copy, nullable) void (^onEligibility)(NSUInteger requestIndex);
@property(nonatomic, strong) NSMutableArray<NSUUID *> *requestedIdentifiers;
@property(nonatomic) IDBlockLayoutCapability capabilities;
@property(nonatomic, copy, nullable) void (^onSnapshot)(NSUInteger requestIndex);
@property(nonatomic) NSUInteger snapshotRequestCount;
@property(nonatomic, copy, nullable) NSUUID *omittedSnapshotIdentifier;
@property(nonatomic, copy, nullable) NSUUID *wrongIdentitySnapshotIdentifier;
@property(nonatomic, copy, nullable) NSUUID *capabilityLimitedSnapshotIdentifier;
@property(nonatomic) IDBlockLayoutCapability limitedCapabilities;
@property(nonatomic, copy, nullable) NSUUID *nonfiniteOriginIdentifier;
@property(nonatomic, copy)
    NSDictionary<NSUUID *, IDCoordinatorFakeSnapshot *> *snapshotsByIdentifier;
@end

@implementation IDCoordinatorFakeSource

- (IDDocumentGeometryEligibilitySnapshot *)
    selectionGeometryEligibilityForDocumentRevision:
        (NSUInteger)documentRevision {
    (void)documentRevision;
    NSUInteger requestIndex = self.eligibilityRequestCount++;
    if (self.onEligibility != nil) self.onEligibility(requestIndex);
    return [[IDDocumentGeometryEligibilitySnapshot alloc]
        initWithGeometryGeneration:MAX(self.geometryGeneration, 1)
              orderedBlockIdentifiers:self.eligibleIdentifiers ?:
                  self.orderedBlockIdentifiers];
}

- (NSArray<NSUUID *> *)orderedBlockIdentifiers {
    return [self.document.blocks valueForKey:@"identifier"];
}

- (id<IDBlockLayoutSnapshot>)snapshotForBlockIdentifier:(NSUUID *)identifier
                                        documentRevision:(NSUInteger)documentRevision {
    [self.requestedIdentifiers addObject:identifier];
    NSUInteger requestIndex = self.snapshotRequestCount;
    self.snapshotRequestCount += 1;
    if (self.onSnapshot != nil) {
        self.onSnapshot(requestIndex);
    }
    if ([identifier isEqual:self.omittedSnapshotIdentifier]) {
        return nil;
    }
    IDBlock *matched = nil;
    for (IDBlock *block in self.document.blocks) {
        if ([block.identifier isEqual:identifier]) {
            matched = block;
            break;
        }
    }
    if (matched == nil) {
        return nil;
    }
    IDCoordinatorFakeSnapshot *snapshot = self.snapshotsByIdentifier[identifier];
    if (snapshot == nil) {
        snapshot = [IDCoordinatorFakeSnapshot new];
        snapshot.baseWritingDirection = IDBlockWritingDirectionLeftToRight;
        snapshot.lineMidY = 11.0;
        snapshot.forcedPointOffset = NSNotFound;
        snapshot.lineResolvedAffinity = IDBlockTextAffinityDownstream;
    }
    snapshot.blockIdentifier = [identifier isEqual:self.wrongIdentitySnapshotIdentifier]
        ? [NSUUID UUID]
        : identifier;
    snapshot.utf16Length = matched.attributedText.length;
    snapshot.documentRevision = documentRevision;
    snapshot.contentRevision = 1;
    snapshot.layoutGeneration = 1;
    snapshot.layoutConstraints = IDBlockLayoutConstraintsMake(100, 1);
    snapshot.capabilities = [identifier
            isEqual:self.capabilityLimitedSnapshotIdentifier]
        ? self.limitedCapabilities
        : self.capabilities;
    snapshot.valid = YES;
    snapshot.usedSize = CGSizeMake(100, 20);
    return snapshot;
}

- (CGPoint)documentOriginForBlockIdentifier:(NSUUID *)identifier {
    if ([identifier isEqual:self.nonfiniteOriginIdentifier]) {
        return CGPointMake(NAN, 0.0);
    }
    return self.origins[identifier].CGPointValue;
}

- (NSUUID *)nearestBlockIdentifierForDocumentPoint:(CGPoint)point {
    NSUUID *nearest = self.orderedBlockIdentifiers.firstObject;
    for (NSUUID *identifier in self.orderedBlockIdentifiers) {
        if (point.y < [self documentOriginForBlockIdentifier:identifier].y) {
            break;
        }
        nearest = identifier;
    }
    return nearest;
}

@end

@interface IDCoordinatorHybridSource : NSObject <IDDocumentLayoutSnapshotSource>
@property(nonatomic, weak) IDBlockDocument *document;
@property(nonatomic, strong) IDBlockStackCanvasView *stack;
@property(nonatomic, copy) NSUUID *scriptedIdentifier;
@property(nonatomic, strong) IDCoordinatorFakeSnapshot *scriptedSnapshot;
@end

@implementation IDCoordinatorHybridSource

- (IDDocumentGeometryEligibilitySnapshot *)
    selectionGeometryEligibilityForDocumentRevision:
        (NSUInteger)documentRevision {
    return [self.stack
        selectionGeometryEligibilityForDocumentRevision:documentRevision];
}

- (NSArray<NSUUID *> *)orderedBlockIdentifiers {
    return self.stack.orderedBlockIdentifiers;
}

- (id<IDBlockLayoutSnapshot>)snapshotForBlockIdentifier:(NSUUID *)identifier
                                        documentRevision:(NSUInteger)documentRevision {
    if (![identifier isEqual:self.scriptedIdentifier]) {
        return [self.stack snapshotForBlockIdentifier:identifier
                                     documentRevision:documentRevision];
    }
    self.scriptedSnapshot.blockIdentifier = identifier;
    self.scriptedSnapshot.utf16Length = 0;
    self.scriptedSnapshot.documentRevision = documentRevision;
    self.scriptedSnapshot.contentRevision = 1;
    self.scriptedSnapshot.layoutGeneration = 1;
    self.scriptedSnapshot.layoutConstraints =
        IDBlockLayoutConstraintsMake(180.0, 1.0);
    self.scriptedSnapshot.capabilities =
        IDBlockLayoutCapabilityCaretGeometry |
        IDBlockLayoutCapabilityPointHitTesting |
        IDBlockLayoutCapabilityLineRanges |
        IDBlockLayoutCapabilityVisualNavigation |
        IDBlockLayoutCapabilityBaseWritingDirection;
    self.scriptedSnapshot.valid = YES;
    self.scriptedSnapshot.usedSize = CGSizeMake(180.0, 20.0);
    return self.scriptedSnapshot;
}

- (CGPoint)documentOriginForBlockIdentifier:(NSUUID *)identifier {
    return [self.stack documentOriginForBlockIdentifier:identifier];
}

- (NSUUID *)nearestBlockIdentifierForDocumentPoint:(CGPoint)point {
    return [self.stack nearestBlockIdentifierForDocumentPoint:point];
}

@end

@interface IDDocumentLayoutCoordinatorTests : XCTestCase
@end

@interface IDDocumentLayoutCoordinator (IDEligibilityTesting)
- (nullable IDDocumentGeometryEligibilitySnapshot *)
    id_validatedSelectionGeometryEligibilityForDocumentRevision:
        (NSUInteger)documentRevision;
@end

@implementation IDDocumentLayoutCoordinatorTests

- (void)testEligibilitySnapshotAtomicallyCopiesGenerationAndOrderedIdentifiers {
    NSUUID *first = [NSUUID UUID];
    NSUUID *second = [NSUUID UUID];
    NSMutableArray<NSUUID *> *identifiers =
        [NSMutableArray arrayWithObjects:first, second, nil];

    IDDocumentGeometryEligibilitySnapshot *snapshot =
        [[IDDocumentGeometryEligibilitySnapshot alloc]
            initWithGeometryGeneration:17
                  orderedBlockIdentifiers:identifiers];
    [identifiers removeAllObjects];

    XCTAssertEqual(snapshot.geometryGeneration, 17U);
    XCTAssertEqualObjects(snapshot.orderedBlockIdentifiers,
                          (@[first, second]));
    XCTAssertNotEqual(snapshot.orderedBlockIdentifiers, identifiers);
}

- (void)testEligibilitySnapshotRejectsZeroGenerationDuplicatesAndUnknownBlocks {
    NSUUID *first = [NSUUID UUID];
    NSArray<NSUUID *> *duplicates = @[first, first];
    XCTAssertThrowsSpecificNamed(
        [[IDDocumentGeometryEligibilitySnapshot alloc]
            initWithGeometryGeneration:0
                  orderedBlockIdentifiers:@[first]],
        NSException, NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed(
        [[IDDocumentGeometryEligibilitySnapshot alloc]
            initWithGeometryGeneration:1
                  orderedBlockIdentifiers:(id)nil],
        NSException, NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed(
        [[IDDocumentGeometryEligibilitySnapshot alloc]
            initWithGeometryGeneration:1
                  orderedBlockIdentifiers:(id)@[@"not-a-uuid"]],
        NSException, NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed(
        [[IDDocumentGeometryEligibilitySnapshot alloc]
            initWithGeometryGeneration:1
                  orderedBlockIdentifiers:duplicates],
        NSException, NSInvalidArgumentException);

    IDBlockDocument *document = IDBlockTextTestDocument(@[@"one", @"two"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    IDDocumentLayoutCoordinator *coordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:document
                                                       source:source];
    source.eligibleIdentifiers = @[
        document.blocks.firstObject.identifier, [NSUUID UUID],
    ];
    XCTAssertNil([coordinator
        id_validatedSelectionGeometryEligibilityForDocumentRevision:
            document.documentRevision]);

    source.eligibleIdentifiers = @[
        document.blocks[1].identifier, document.blocks[0].identifier,
    ];
    XCTAssertNil([coordinator
        id_validatedSelectionGeometryEligibilityForDocumentRevision:
            document.documentRevision]);
}

- (void)testBlockStackAdvancesGeometryGenerationWhenOriginsOrLayoutsChange {
    IDBlockDocument *document = IDBlockTextTestDocument(@[
        @"first wrapped block with enough text to move the next origin",
        @"second",
    ]);
    IDBlockStackCanvasView *stack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    [stack updateForDocumentChange:nil width:180.0];
    IDDocumentGeometryEligibilitySnapshot *initial = [stack
        selectionGeometryEligibilityForDocumentRevision:
            document.documentRevision];
    XCTAssertNotNil(initial);
    XCTAssertGreaterThan(initial.geometryGeneration, 0U);
    XCTAssertEqualObjects(initial.orderedBlockIdentifiers,
                          [document.blocks valueForKey:@"identifier"]);

    [stack updateForDocumentChange:nil width:180.0];
    IDDocumentGeometryEligibilitySnapshot *unchanged = [stack
        selectionGeometryEligibilityForDocumentRevision:
            document.documentRevision];
    XCTAssertEqual(unchanged.geometryGeneration,
                   initial.geometryGeneration);

    [stack updateForDocumentChange:nil width:110.0];
    IDDocumentGeometryEligibilitySnapshot *reflowed = [stack
        selectionGeometryEligibilityForDocumentRevision:
            document.documentRevision];
    XCTAssertEqual(reflowed.geometryGeneration,
                   initial.geometryGeneration + 1);

    IDBlockDocumentChange *change = [document
        replaceCanonicalRange:NSMakeRange(0, 0)
          withAttributedString:IDBlockTextTestAttributedString(
              @"more words that alter the first block height ")];
    [stack updateForDocumentChange:change width:110.0];
    IDDocumentGeometryEligibilitySnapshot *contentChanged = [stack
        selectionGeometryEligibilityForDocumentRevision:
            document.documentRevision];
    XCTAssertEqual(contentChanged.geometryGeneration,
                   reflowed.geometryGeneration + 1);
}

- (IDCoordinatorFakeSource *)sourceForDocument:(IDBlockDocument *)document {
    IDCoordinatorFakeSource *source = [IDCoordinatorFakeSource new];
    source.document = document;
    source.geometryGeneration = 1;
    source.requestedIdentifiers = [NSMutableArray array];
    source.capabilities = IDBlockLayoutCapabilityCaretGeometry |
        IDBlockLayoutCapabilityPointHitTesting |
        IDBlockLayoutCapabilityLineRanges |
        IDBlockLayoutCapabilityVisualNavigation |
        IDBlockLayoutCapabilityBaseWritingDirection |
        IDBlockLayoutCapabilitySelectionSegments;
    NSMutableDictionary<NSUUID *, NSValue *> *origins = [NSMutableDictionary dictionary];
    [document.blocks enumerateObjectsUsingBlock:
        ^(IDBlock *block, NSUInteger index, BOOL *stop) {
        origins[block.identifier] =
            [NSValue valueWithCGPoint:CGPointMake(1, 10 + index * 30)];
    }];
    source.origins = origins;
    NSMutableDictionary<NSUUID *, IDCoordinatorFakeSnapshot *> *snapshots =
        [NSMutableDictionary dictionary];
    for (IDBlock *block in document.blocks) {
        IDCoordinatorFakeSnapshot *snapshot = [IDCoordinatorFakeSnapshot new];
        snapshot.blockIdentifier = block.identifier;
        snapshot.lineMidY = 11.0;
        snapshot.forcedPointOffset = NSNotFound;
        snapshot.lineResolvedAffinity = IDBlockTextAffinityDownstream;
        snapshots[block.identifier] = snapshot;
    }
    source.snapshotsByIdentifier = snapshots.copy;
    return source;
}

- (void)testSameBlockNavigationTranslatesAnchorBetweenDocumentAndSnapshotCoordinates {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abc"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    NSUUID *identifier = document.blocks.firstObject.identifier;
    source.origins = @{
        identifier: [NSValue valueWithCGPoint:CGPointMake(41.0, 10.0)],
    };
    IDCoordinatorFakeSnapshot *snapshot =
        source.snapshotsByIdentifier[identifier];
    snapshot.returnedAnchorDelta = 4.0;
    IDDocumentLayoutCoordinator *coordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:document
                                                       source:source];

    IDDocumentCaretNavigationResult *result = [coordinator
        visuallyAdjacentPositionFromCanonicalOffset:1
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionRight
                              anchorPositionOffset:73.5];

    XCTAssertNotNil(result);
    XCTAssertEqualWithAccuracy(snapshot.lastNavigationAnchor, 32.5, 0.001);
    XCTAssertEqualWithAccuracy(result.anchorPositionOffset, 77.5, 0.001);
    XCTAssertEqual(result.position.canonicalOffset, 2U);
    XCTAssertTrue(result.exact);
}

- (void)testHorizontalBoundaryTransitionsRespectBaseDirectionAffinityAndClusters {
    IDBlockDocument *ltrDocument = IDBlockTextTestDocument(@[@"ab", @"cd"]);
    IDCoordinatorFakeSource *ltrSource = [self sourceForDocument:ltrDocument];
    IDDocumentLayoutCoordinator *ltrCoordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:ltrDocument
                                                       source:ltrSource];

    IDDocumentCaretNavigationResult *ltrForward = [ltrCoordinator
        visuallyAdjacentPositionFromCanonicalOffset:2
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionRight
                              anchorPositionOffset:17.5];
    XCTAssertNotNil(ltrForward);
    XCTAssertEqual(ltrForward.position.canonicalOffset, 3U);
    XCTAssertEqualObjects(ltrForward.position.blockIdentifier,
                          ltrDocument.blocks[1].identifier);
    XCTAssertEqual(ltrForward.position.localPosition.utf16Offset, 0U);
    XCTAssertEqual(ltrForward.position.localPosition.affinity,
                   IDBlockTextAffinityDownstream);
    XCTAssertEqualWithAccuracy(ltrForward.anchorPositionOffset, 17.5, 0.001);
    XCTAssertEqual(ltrForward.position.documentRevision,
                   ltrDocument.documentRevision);
    XCTAssertTrue(ltrForward.exact);

    IDDocumentCaretNavigationResult *ltrBackward = [ltrCoordinator
        visuallyAdjacentPositionFromCanonicalOffset:3
                                          affinity:IDBlockTextAffinityUpstream
                                         direction:IDBlockLayoutDirectionLeft
                              anchorPositionOffset:29.0];
    XCTAssertNotNil(ltrBackward);
    XCTAssertEqual(ltrBackward.position.canonicalOffset, 2U);
    XCTAssertEqualObjects(ltrBackward.position.blockIdentifier,
                          ltrDocument.blocks[0].identifier);
    XCTAssertEqual(ltrBackward.position.localPosition.utf16Offset, 2U);
    XCTAssertEqual(ltrBackward.position.localPosition.affinity,
                   IDBlockTextAffinityUpstream);
    XCTAssertEqualWithAccuracy(ltrBackward.anchorPositionOffset, 29.0, 0.001);

    IDBlockDocument *rtlDocument = IDBlockTextTestDocument(@[@"אב", @"גד"]);
    IDCoordinatorFakeSource *rtlSource = [self sourceForDocument:rtlDocument];
    for (IDCoordinatorFakeSnapshot *snapshot in
         rtlSource.snapshotsByIdentifier.allValues) {
        snapshot.baseWritingDirection = IDBlockWritingDirectionRightToLeft;
    }
    IDDocumentLayoutCoordinator *rtlCoordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:rtlDocument
                                                       source:rtlSource];
    XCTAssertEqual([rtlCoordinator
        visuallyAdjacentPositionFromCanonicalOffset:2
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionLeft
                              anchorPositionOffset:11.0].position.canonicalOffset,
                   3U);
    XCTAssertEqual([rtlCoordinator
        visuallyAdjacentPositionFromCanonicalOffset:3
                                          affinity:IDBlockTextAffinityUpstream
                                         direction:IDBlockLayoutDirectionRight
                              anchorPositionOffset:11.0].position.canonicalOffset,
                   2U);

    IDBlockDocument *emojiDocument = IDBlockTextTestDocument(
        @[@"A👨‍👩‍👧‍👦", @"B"]);
    IDCoordinatorFakeSource *emojiSource = [self sourceForDocument:emojiDocument];
    IDDocumentLayoutCoordinator *emojiCoordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:emojiDocument
                                                       source:emojiSource];
    NSUInteger emojiEdge = emojiDocument.blocks[0].attributedText.length;
    XCTAssertEqual([emojiCoordinator
        visuallyAdjacentPositionFromCanonicalOffset:emojiEdge
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionRight
                              anchorPositionOffset:7.0].position.canonicalOffset,
                   emojiEdge + 1);

    IDBlockDocument *emptyDocument = IDBlockTextTestDocument(@[@"", @"", @"x"]);
    IDCoordinatorFakeSource *emptySource = [self sourceForDocument:emptyDocument];
    IDDocumentLayoutCoordinator *emptyCoordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:emptyDocument
                                                       source:emptySource];
    IDDocumentCaretNavigationResult *firstEmpty = [emptyCoordinator
        visuallyAdjacentPositionFromCanonicalOffset:0
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionRight
                              anchorPositionOffset:5.0];
    XCTAssertEqual(firstEmpty.position.canonicalOffset, 1U);
    XCTAssertEqualObjects(firstEmpty.position.blockIdentifier,
                          emptyDocument.blocks[1].identifier);
    IDDocumentCaretNavigationResult *secondEmpty = [emptyCoordinator
        visuallyAdjacentPositionFromCanonicalOffset:1
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionRight
                              anchorPositionOffset:5.0];
    XCTAssertEqual(secondEmpty.position.canonicalOffset, 2U);
    XCTAssertEqualObjects(secondEmpty.position.blockIdentifier,
                          emptyDocument.blocks[2].identifier);

    XCTAssertNil([ltrCoordinator
        visuallyAdjacentPositionFromCanonicalOffset:0
                                          affinity:IDBlockTextAffinityUpstream
                                         direction:IDBlockLayoutDirectionLeft
                              anchorPositionOffset:0]);
    XCTAssertNil([ltrCoordinator
        visuallyAdjacentPositionFromCanonicalOffset:ltrDocument.canonicalLength
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionRight
                              anchorPositionOffset:0]);
}

- (void)testTextKit2CoordinatorHorizontalBoundaryResultsMatchEstablishedController {
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:17.0],
    };
    NSArray<NSArray<NSString *> *> *fixtures = @[
        @[@"alpha", @"beta"],
        @[@"אבגדה", @"וזחטי"],
        @[@"abc אבג", @"דהו xyz"],
        @[@"A👨‍👩‍👧‍👦", @"B"],
        @[@"", @"", @"x"],
    ];
    for (NSArray<NSString *> *fixture in fixtures) {
        NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
        for (NSString *string in fixture) {
            [blocks addObject:[[NSAttributedString alloc]
                initWithString:string attributes:attributes]];
        }
        IDBlockDocument *document = [[IDBlockDocument alloc]
            initWithAttributedBlocks:blocks defaultAttributes:attributes];
        IDBlockStackCanvasView *stack = [[IDBlockStackCanvasView alloc]
            initWithDocument:document];
        [stack updateForDocumentChange:nil width:200.0];
        IDCanonicalTextStorageAdapter *adapter =
            [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];
        IDRichTextLayoutController *controller = [[IDRichTextLayoutController alloc]
            initWithDocument:document
           textStorageAdapter:adapter
                    blockStack:stack];
        IDDocumentLayoutCoordinator *coordinator =
            controller.id_documentLayoutCoordinator;
        NSUInteger blockStart = 0;
        for (NSUInteger blockIndex = 0;
             blockIndex + 1 < document.blocks.count;
             blockIndex += 1) {
            NSUInteger beforeSeparator = blockStart +
                document.blocks[blockIndex].attributedText.length;
            for (NSNumber *sourceOffsetValue in
                 @[@(beforeSeparator), @(beforeSeparator + 1)]) {
                NSUInteger sourceOffset = sourceOffsetValue.unsignedIntegerValue;
                for (NSNumber *affinityValue in
                     @[@(UITextStorageDirectionBackward),
                       @(UITextStorageDirectionForward)]) {
                    UITextStorageDirection affinity =
                        affinityValue.integerValue;
                    IDBlockTextAffinity neutralAffinity =
                        affinity == UITextStorageDirectionBackward
                            ? IDBlockTextAffinityUpstream
                            : IDBlockTextAffinityDownstream;
                    IDRichTextPosition *source = [controller
                        positionForCanonicalOffset:sourceOffset
                                          affinity:affinity];
                    for (NSNumber *directionValue in
                         @[@(UITextLayoutDirectionLeft),
                           @(UITextLayoutDirectionRight)]) {
                        UITextLayoutDirection direction =
                            directionValue.integerValue;
                        IDRichTextPosition *established =
                            (IDRichTextPosition *)[controller
                                id_positionFromPosition:source
                                            inDirection:direction
                                                 offset:1
                                               affinity:affinity
                                   anchorPositionOffset:17.5];
                        IDDocumentCaretNavigationResult *neutral = [coordinator
                            visuallyAdjacentPositionFromCanonicalOffset:sourceOffset
                                                                affinity:neutralAffinity
                                                               direction:direction == UITextLayoutDirectionLeft
                                                                   ? IDBlockLayoutDirectionLeft
                                                                   : IDBlockLayoutDirectionRight
                                                    anchorPositionOffset:17.5];
                        NSString *context = [NSString stringWithFormat:
                            @"fixture=%@ source=%lu affinity=%ld direction=%ld",
                            fixture,
                            (unsigned long)sourceOffset,
                            (long)affinity,
                            (long)direction];
                        XCTAssertEqual(neutral == nil, established == nil,
                                       @"%@", context);
                        if (neutral != nil && established != nil) {
                            NSUInteger establishedOffset = [controller
                                id_canonicalOffsetForPosition:established];
                            XCTAssertEqual(neutral.position.canonicalOffset,
                                           establishedOffset,
                                           @"%@", context);
                            XCTAssertEqual(neutral.position.localPosition.affinity,
                                           established.affinity == UITextStorageDirectionBackward
                                               ? IDBlockTextAffinityUpstream
                                               : IDBlockTextAffinityDownstream,
                                           @"%@", context);
                        }
                    }
                }
            }
            blockStart = beforeSeparator + 1;
        }
    }
}

- (void)testVerticalDownBoundaryUsesOnlyImmediateAdjacentBlock {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abc", @"def", @"ghi"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    IDCoordinatorFakeSnapshot *second =
        source.snapshotsByIdentifier[document.blocks[1].identifier];
    second.forcedPointOffset = 1;
    second.forcedPointAffinity = IDBlockTextAffinityDownstream;
    IDCoordinatorFakeSnapshot *third =
        source.snapshotsByIdentifier[document.blocks[2].identifier];
    third.forcedPointOffset = 2;
    IDDocumentLayoutCoordinator *coordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:document source:source];

    IDDocumentCaretNavigationResult *result = [coordinator
        visuallyAdjacentPositionFromCanonicalOffset:2
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionDown
                              anchorPositionOffset:21.0];

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.position.blockIdentifier,
                          document.blocks[1].identifier);
    XCTAssertEqual(result.position.canonicalOffset, 5U);
    XCTAssertEqual(result.position.localPosition.utf16Offset, 1U);
    XCTAssertEqual(result.position.localPosition.affinity,
                   IDBlockTextAffinityDownstream);
    XCTAssertTrue(result.exact);
    XCTAssertEqual(third.recordedHitTestX, 0.0);
}

- (void)testVerticalUpBoundaryUsesOnlyImmediateAdjacentBlock {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abc", @"def", @"ghi"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    IDCoordinatorFakeSnapshot *first =
        source.snapshotsByIdentifier[document.blocks[0].identifier];
    first.forcedPointOffset = 2;
    IDCoordinatorFakeSnapshot *second =
        source.snapshotsByIdentifier[document.blocks[1].identifier];
    second.forcedPointOffset = 1;
    second.forcedPointAffinity = IDBlockTextAffinityUpstream;
    IDDocumentLayoutCoordinator *coordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:document source:source];

    IDDocumentCaretNavigationResult *result = [coordinator
        visuallyAdjacentPositionFromCanonicalOffset:9
                                          affinity:IDBlockTextAffinityUpstream
                                         direction:IDBlockLayoutDirectionUp
                              anchorPositionOffset:31.0];

    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result.position.blockIdentifier,
                          document.blocks[1].identifier);
    XCTAssertEqual(result.position.canonicalOffset, 5U);
    XCTAssertEqual(result.position.localPosition.utf16Offset, 1U);
    XCTAssertEqual(result.position.localPosition.affinity,
                   IDBlockTextAffinityUpstream);
    XCTAssertEqual(first.recordedHitTestX, 0.0);
}

- (void)testVerticalBoundaryTreatsSameLineLocalStopAsExit {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abc", @"def"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    IDCoordinatorFakeSnapshot *first =
        source.snapshotsByIdentifier[document.blocks[0].identifier];
    first.returnsSameLineVerticalStop = YES;
    IDCoordinatorFakeSnapshot *second =
        source.snapshotsByIdentifier[document.blocks[1].identifier];
    second.forcedPointOffset = 2;
    IDDocumentLayoutCoordinator *coordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:document source:source];

    IDDocumentCaretNavigationResult *result = [coordinator
        visuallyAdjacentPositionFromCanonicalOffset:1
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionDown
                              anchorPositionOffset:18.0];

    XCTAssertEqual(result.position.canonicalOffset, 6U);
    XCTAssertEqualObjects(result.position.blockIdentifier,
                          document.blocks[1].identifier);
}

- (void)testVerticalBoundaryStopsOnEmptyAdjacentBlock {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abc", @"", @"def"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    IDCoordinatorFakeSnapshot *empty =
        source.snapshotsByIdentifier[document.blocks[1].identifier];
    empty.forcedPointOffset = 0;
    IDCoordinatorFakeSnapshot *third =
        source.snapshotsByIdentifier[document.blocks[2].identifier];
    third.forcedPointOffset = 2;
    IDDocumentLayoutCoordinator *coordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:document source:source];

    IDDocumentCaretNavigationResult *result = [coordinator
        visuallyAdjacentPositionFromCanonicalOffset:2
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionDown
                              anchorPositionOffset:14.0];

    XCTAssertEqual(result.position.canonicalOffset, 4U);
    XCTAssertEqualObjects(result.position.blockIdentifier,
                          document.blocks[1].identifier);
    XCTAssertEqual(result.position.localPosition.utf16Offset, 0U);
    XCTAssertEqual(third.recordedHitTestX, 0.0);
}

- (void)testVerticalBoundaryPreservesDocumentAnchorAcrossAsymmetricOrigins {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abc", @"def"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    source.origins = @{
        document.blocks[0].identifier:
            [NSValue valueWithCGPoint:CGPointMake(31.0, 10.0)],
        document.blocks[1].identifier:
            [NSValue valueWithCGPoint:CGPointMake(83.0, 40.0)],
    };
    IDCoordinatorFakeSnapshot *destination =
        source.snapshotsByIdentifier[document.blocks[1].identifier];
    destination.forcedPointOffset = 1;
    destination.forcedPointAffinity = IDBlockTextAffinityDownstream;
    IDDocumentLayoutCoordinator *coordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:document source:source];

    IDDocumentCaretNavigationResult *result = [coordinator
        visuallyAdjacentPositionFromCanonicalOffset:2
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionDown
                              anchorPositionOffset:117.0];

    XCTAssertNotNil(result);
    XCTAssertEqualWithAccuracy(destination.recordedHitTestX, 34.0, 0.001);
    XCTAssertEqualWithAccuracy(result.anchorPositionOffset, 117.0, 0.001);
    XCTAssertEqual(result.position.canonicalOffset, 5U);
    XCTAssertEqual(result.position.documentRevision,
                   document.documentRevision);
    XCTAssertTrue(result.exact);
}

- (void)testTextKit2CoordinatorVerticalBoundaryResultsMatchEstablishedController {
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:17.0],
    };
    NSArray<NSArray<NSString *> *> *fixtures = @[
        @[@"abcdefghijklmno", @"xy", @"abcdefghijklmno"],
        @[@"abc", @"", @"def"],
        @[@"אבגדה long text", @"xy", @"abc אבג xyz"],
    ];
    for (NSArray<NSString *> *fixture in fixtures) {
        NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
        for (NSString *string in fixture) {
            [blocks addObject:[[NSAttributedString alloc]
                initWithString:string attributes:attributes]];
        }
        IDBlockDocument *document = [[IDBlockDocument alloc]
            initWithAttributedBlocks:blocks defaultAttributes:attributes];
        IDBlockStackCanvasView *stack = [[IDBlockStackCanvasView alloc]
            initWithDocument:document];
        [stack updateForDocumentChange:nil width:200.0];
        IDCanonicalTextStorageAdapter *adapter =
            [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];
        IDRichTextLayoutController *controller = [[IDRichTextLayoutController alloc]
            initWithDocument:document
           textStorageAdapter:adapter
                    blockStack:stack];
        IDDocumentLayoutCoordinator *coordinator =
            controller.id_documentLayoutCoordinator;

        UITextView *stock = [[UITextView alloc]
            initWithFrame:CGRectMake(0, 0, 200.0, 300.0)];
        stock.textContainerInset = UIEdgeInsetsZero;
        stock.attributedText = adapter;
        [stock layoutIfNeeded];

        NSUInteger blockStart = 0;
        for (NSUInteger blockIndex = 0;
             blockIndex + 1 < document.blocks.count;
             blockIndex += 1) {
            NSUInteger beforeSeparator = blockStart +
                document.blocks[blockIndex].attributedText.length;
            NSArray<NSDictionary<NSString *, NSNumber *> *> *moves = @[
                @{
                    @"offset": @(beforeSeparator),
                    @"direction": @(UITextLayoutDirectionDown),
                },
                @{
                    @"offset": @(beforeSeparator + 1),
                    @"direction": @(UITextLayoutDirectionUp),
                },
            ];
            for (NSDictionary<NSString *, NSNumber *> *move in moves) {
                NSUInteger sourceOffset = move[@"offset"].unsignedIntegerValue;
                UITextLayoutDirection direction =
                    move[@"direction"].integerValue;
                for (NSNumber *affinityValue in
                     @[@(UITextStorageDirectionBackward),
                       @(UITextStorageDirectionForward)]) {
                    UITextStorageDirection affinity =
                        affinityValue.integerValue;
                    IDBlockTextAffinity neutralAffinity =
                        affinity == UITextStorageDirectionBackward
                            ? IDBlockTextAffinityUpstream
                            : IDBlockTextAffinityDownstream;
                    IDDocumentCaretGeometry *sourceCaret = [coordinator
                        caretGeometryForCanonicalOffset:sourceOffset
                                                affinity:neutralAffinity];
                    XCTAssertNotNil(sourceCaret);
                    CGFloat sourceCaretX = CGRectGetMinX(sourceCaret.documentRect);
                    NSArray<NSNumber *> *anchors = @[
                        @(sourceCaretX), @17.5, @63.0,
                    ];
                    for (NSNumber *anchorValue in anchors) {
                        CGFloat anchor = anchorValue.doubleValue;
                        IDRichTextPosition *source = [controller
                            positionForCanonicalOffset:sourceOffset
                                              affinity:affinity];
                        IDRichTextPosition *established =
                            (IDRichTextPosition *)[controller
                                id_positionFromPosition:source
                                            inDirection:direction
                                                 offset:1
                                               affinity:affinity
                                   anchorPositionOffset:anchor];
                        IDDocumentCaretNavigationResult *neutral = [coordinator
                            visuallyAdjacentPositionFromCanonicalOffset:sourceOffset
                                                                affinity:neutralAffinity
                                                               direction:direction == UITextLayoutDirectionDown
                                                                   ? IDBlockLayoutDirectionDown
                                                                   : IDBlockLayoutDirectionUp
                                                    anchorPositionOffset:anchor];
                        NSString *context = [NSString stringWithFormat:
                            @"fixture=%@ source=%lu affinity=%ld direction=%ld anchor=%g",
                            fixture,
                            (unsigned long)sourceOffset,
                            (long)affinity,
                            (long)direction,
                            anchor];
                        XCTAssertEqual(neutral == nil, established == nil,
                                       @"%@", context);
                        if (neutral != nil && established != nil) {
                            XCTAssertEqual(neutral.position.canonicalOffset,
                                           [controller id_canonicalOffsetForPosition:established],
                                           @"%@", context);
                            XCTAssertEqual(neutral.position.localPosition.affinity,
                                           established.affinity == UITextStorageDirectionBackward
                                               ? IDBlockTextAffinityUpstream
                                               : IDBlockTextAffinityDownstream,
                                           @"%@", context);
                            XCTAssertEqualWithAccuracy(neutral.anchorPositionOffset,
                                                       anchor, 0.001,
                                                       @"%@", context);
                            XCTAssertTrue(neutral.exact, @"%@", context);
                        }

                        if ([anchorValue isEqualToNumber:anchors.firstObject] &&
                            affinity == UITextStorageDirectionForward) {
                            UITextPosition *stockSource = [stock
                                positionFromPosition:stock.beginningOfDocument
                                             offset:(NSInteger)sourceOffset];
                            UITextPosition *stockResult = [stock
                                positionFromPosition:stockSource
                                         inDirection:direction
                                              offset:1];
                            XCTAssertEqual(stockResult == nil, neutral == nil,
                                           @"%@", context);
                            if (stockResult != nil && neutral != nil) {
                                NSInteger stockOffset = [stock
                                    offsetFromPosition:stock.beginningOfDocument
                                           toPosition:stockResult];
                                XCTAssertEqual(neutral.position.canonicalOffset,
                                               (NSUInteger)stockOffset,
                                               @"%@", context);
                            }
                        }
                    }
                }
            }
            blockStart = beforeSeparator + 1;
        }
    }
}

- (void)testHorizontalBoundaryRejectsMissingOrWrongDestinationSnapshot {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abc", @"def"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    IDDocumentLayoutCoordinator *coordinator = [[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source];
    NSUUID *destinationIdentifier = document.blocks[1].identifier;

    source.omittedSnapshotIdentifier = destinationIdentifier;
    XCTAssertNil([coordinator
        visuallyAdjacentPositionFromCanonicalOffset:3
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionRight
                              anchorPositionOffset:19.0]);

    source.omittedSnapshotIdentifier = nil;
    source.wrongIdentitySnapshotIdentifier = destinationIdentifier;
    XCTAssertNil([coordinator
        visuallyAdjacentPositionFromCanonicalOffset:3
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionRight
                              anchorPositionOffset:19.0]);
}

- (void)testVerticalBoundaryRejectsMissingDestinationCapabilities {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abc", @"def"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    source.capabilityLimitedSnapshotIdentifier = document.blocks[1].identifier;
    source.limitedCapabilities = IDBlockLayoutCapabilityCaretGeometry;
    IDDocumentLayoutCoordinator *coordinator = [[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source];

    XCTAssertNil([coordinator
        visuallyAdjacentPositionFromCanonicalOffset:3
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionDown
                              anchorPositionOffset:21.0]);
}

- (void)testBoundaryNavigationRejectsNonfiniteOriginsAndProviderGeometry {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abc", @"def"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    IDDocumentLayoutCoordinator *coordinator = [[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source];

    source.nonfiniteOriginIdentifier = document.blocks[0].identifier;
    __block IDDocumentCaretNavigationResult *nonfiniteOriginResult = nil;
    XCTAssertNoThrow(nonfiniteOriginResult = [coordinator
        visuallyAdjacentPositionFromCanonicalOffset:3
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionRight
                              anchorPositionOffset:17.0]);
    XCTAssertNil(nonfiniteOriginResult);

    source.nonfiniteOriginIdentifier = nil;
    IDCoordinatorFakeSnapshot *destination =
        source.snapshotsByIdentifier[document.blocks[1].identifier];
    destination.returnsNonfiniteCaretRect = YES;
    XCTAssertNil([coordinator
        visuallyAdjacentPositionFromCanonicalOffset:3
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionDown
                              anchorPositionOffset:17.0]);

    destination.returnsNonfiniteCaretRect = NO;
    destination.invalidatesAfterCaretGeometry = YES;
    NSUInteger pointHitRequests = destination.pointHitRequestCount;
    XCTAssertNil([coordinator
        visuallyAdjacentPositionFromCanonicalOffset:3
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionDown
                              anchorPositionOffset:17.0]);
    XCTAssertEqual(destination.pointHitRequestCount, pointHitRequests);
}

- (void)testBoundaryNavigationRetriesWholeSourceAndDestinationTransactionOnce {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abc", @"def"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    IDCoordinatorFakeSnapshot *destination =
        source.snapshotsByIdentifier[document.blocks[1].identifier];
    __weak IDBlockDocument *weakDocument = document;
    __block NSUInteger mutations = 0;
    destination.onCaretGeometry = ^{
        if (mutations == 0) {
            mutations += 1;
            [weakDocument replaceCanonicalRange:
                NSMakeRange(weakDocument.canonicalLength, 0)
                    withAttributedString:IDBlockTextTestAttributedString(@"x")];
        }
    };
    IDDocumentLayoutCoordinator *coordinator = [[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source];

    IDDocumentCaretNavigationResult *result = [coordinator
        visuallyAdjacentPositionFromCanonicalOffset:3
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionDown
                              anchorPositionOffset:23.0];

    XCTAssertNotNil(result);
    XCTAssertTrue(result.exact);
    XCTAssertEqual(result.position.documentRevision, 1U);
    XCTAssertEqualObjects(result.position.blockIdentifier,
                          document.blocks[1].identifier);
    XCTAssertEqual(source.snapshotRequestCount, 4U);
    XCTAssertEqual(destination.caretGeometryRequestCount, 2U);
    XCTAssertEqual(destination.pointHitRequestCount, 1U);
}

- (void)testBoundaryNavigationReturnsNonexactAfterSecondRevisionChange {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abc", @"def"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    IDCoordinatorFakeSnapshot *destination =
        source.snapshotsByIdentifier[document.blocks[1].identifier];
    __weak IDBlockDocument *weakDocument = document;
    destination.onCaretGeometry = ^{
        [weakDocument replaceCanonicalRange:
            NSMakeRange(weakDocument.canonicalLength, 0)
                withAttributedString:IDBlockTextTestAttributedString(@"x")];
    };
    IDDocumentLayoutCoordinator *coordinator = [[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source];

    IDDocumentCaretNavigationResult *result = [coordinator
        visuallyAdjacentPositionFromCanonicalOffset:3
                                          affinity:IDBlockTextAffinityUpstream
                                         direction:IDBlockLayoutDirectionDown
                              anchorPositionOffset:29.5];

    XCTAssertNotNil(result);
    XCTAssertFalse(result.exact);
    XCTAssertEqual(result.position.canonicalOffset, 3U);
    XCTAssertEqual(result.position.documentRevision, 2U);
    XCTAssertEqual(result.position.localPosition.affinity,
                   IDBlockTextAffinityUpstream);
    XCTAssertEqualWithAccuracy(result.anchorPositionOffset, 29.5, 0.001);
    XCTAssertEqual(destination.pointHitRequestCount, 0U);
}

- (void)testUnmountedDestinationCanvasStillProvidesExactCrossBlockNavigation {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"", @"beta"]);
    IDBlockStackCanvasView *stack = [[IDBlockStackCanvasView alloc]
        initWithDocument:document];
    [stack updateForDocumentChange:nil width:180.0];
    IDCoordinatorHybridSource *source = [IDCoordinatorHybridSource new];
    source.document = document;
    source.stack = stack;
    source.scriptedIdentifier = document.blocks[0].identifier;
    source.scriptedSnapshot = [IDCoordinatorFakeSnapshot new];
    source.scriptedSnapshot.baseWritingDirection =
        IDBlockWritingDirectionLeftToRight;
    source.scriptedSnapshot.lineMidY = 11.0;
    source.scriptedSnapshot.forcedPointOffset = NSNotFound;
    IDDocumentLayoutCoordinator *coordinator = [[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source];
    IDBlockLayout *destinationLayout = stack.blockLayouts[1];
    [destinationLayout.canvasView removeFromSuperview];

    IDDocumentCaretNavigationResult *horizontal = [coordinator
        visuallyAdjacentPositionFromCanonicalOffset:0
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionRight
                              anchorPositionOffset:17.0];
    IDDocumentCaretGeometry *sourceCaret = [coordinator
        caretGeometryForCanonicalOffset:0
                                affinity:IDBlockTextAffinityDownstream];
    IDDocumentCaretNavigationResult *vertical = [coordinator
        visuallyAdjacentPositionFromCanonicalOffset:0
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionDown
                              anchorPositionOffset:CGRectGetMinX(
                                  sourceCaret.documentRect)];

    XCTAssertTrue(horizontal.exact);
    XCTAssertEqual(horizontal.position.canonicalOffset, 1U);
    XCTAssertTrue(vertical.exact);
    XCTAssertEqualObjects(vertical.position.blockIdentifier,
                          document.blocks[1].identifier);
    XCTAssertNil(destinationLayout.canvasView.superview);
}

- (void)testCoordinatorMapsCanonicalBoundariesAndViewIndependentGeometry {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"ab", @"", @"xyz"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    IDDocumentLayoutCoordinator *coordinator = [[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source];

    IDDocumentCaretGeometry *beforeFirstSeparator = [coordinator
        caretGeometryForCanonicalOffset:2
                                affinity:IDBlockTextAffinityDownstream];
    XCTAssertEqualObjects(beforeFirstSeparator.position.blockIdentifier,
                          document.blocks[0].identifier);
    XCTAssertEqual(beforeFirstSeparator.position.localPosition.utf16Offset, 2U);

    IDDocumentCaretGeometry *emptyBoundary = [coordinator
        caretGeometryForCanonicalOffset:3
                                affinity:IDBlockTextAffinityDownstream];
    XCTAssertEqualObjects(emptyBoundary.position.blockIdentifier,
                          document.blocks[1].identifier);
    XCTAssertEqual(emptyBoundary.position.localPosition.utf16Offset, 0U);

    IDDocumentCaretGeometry *thirdCaret = [coordinator
        caretGeometryForCanonicalOffset:5
                                affinity:IDBlockTextAffinityDownstream];
    XCTAssertTrue(thirdCaret.exact);
    XCTAssertEqualObjects(thirdCaret.position.blockIdentifier,
                          document.blocks[2].identifier);
    XCTAssertEqual(thirdCaret.position.localPosition.utf16Offset, 1U);
    XCTAssertTrue(CGRectEqualToRect(thirdCaret.documentRect,
                                   CGRectMake(11, 72, 2, 18)));

    IDDocumentTextPosition *pointPosition =
        [coordinator nearestPositionToDocumentPoint:CGPointMake(16, 75)];
    XCTAssertEqual(pointPosition.canonicalOffset, 5U);
    XCTAssertEqualObjects(pointPosition.blockIdentifier,
                          document.blocks[2].identifier);

    IDDocumentLineGeometry *line = [coordinator
        lineGeometryForCanonicalOffset:5
                              affinity:IDBlockTextAffinityDownstream];
    XCTAssertTrue(line.exact);
    XCTAssertTrue(NSEqualRanges(line.canonicalRange, NSMakeRange(4, 3)));

    IDDocumentCaretNavigationResult *move = [coordinator
        visuallyAdjacentPositionFromCanonicalOffset:5
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionRight
                              anchorPositionOffset:17.5];
    XCTAssertTrue(move.exact);
    XCTAssertEqual(move.position.canonicalOffset, 6U);
    XCTAssertEqualWithAccuracy(move.anchorPositionOffset, 17.5, 0.001);
    XCTAssertNil([coordinator
        visuallyAdjacentPositionFromCanonicalOffset:7
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionRight
                              anchorPositionOffset:17.5]);
}

- (void)testCoordinatorReportsUnsupportedSnapshotCapabilities {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abc"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    source.capabilities = IDBlockLayoutCapabilityCaretGeometry;
    IDDocumentLayoutCoordinator *coordinator = [[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source];

    XCTAssertNotNil([coordinator
        caretGeometryForCanonicalOffset:1
                                affinity:IDBlockTextAffinityDownstream]);
    XCTAssertNil([coordinator nearestPositionToDocumentPoint:CGPointMake(10, 10)]);
    XCTAssertNil([coordinator
        lineGeometryForCanonicalOffset:1
                              affinity:IDBlockTextAffinityDownstream]);
    XCTAssertNil([coordinator
        visuallyAdjacentPositionFromCanonicalOffset:1
                                          affinity:IDBlockTextAffinityDownstream
                                         direction:IDBlockLayoutDirectionRight
                              anchorPositionOffset:0]);
}

- (void)testCoordinatorRetriesOnceAfterDocumentRevisionChanges {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"a"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    __weak IDBlockDocument *weakDocument = document;
    source.onSnapshot = ^(NSUInteger requestIndex) {
        if (requestIndex == 0) {
            [weakDocument replaceCanonicalRange:
                NSMakeRange(weakDocument.canonicalLength, 0)
                    withAttributedString:IDBlockTextTestAttributedString(@"b")];
        }
    };
    IDDocumentLayoutCoordinator *coordinator = [[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source];

    IDDocumentCaretGeometry *geometry = [coordinator
        caretGeometryForCanonicalOffset:1
                                affinity:IDBlockTextAffinityDownstream];

    XCTAssertTrue(geometry.exact);
    XCTAssertEqual(geometry.position.documentRevision, 1U);
    XCTAssertEqual(geometry.position.canonicalOffset, 1U);
    XCTAssertEqual(source.snapshotRequestCount, 2U);
}

- (void)testCaretAndPointGeometryReturnNilAfterSecondRevisionChange {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"a"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    __weak IDBlockDocument *weakDocument = document;
    source.onSnapshot = ^(__unused NSUInteger requestIndex) {
        [weakDocument replaceCanonicalRange:
            NSMakeRange(weakDocument.canonicalLength, 0)
                withAttributedString:IDBlockTextTestAttributedString(@"x")];
    };
    IDDocumentLayoutCoordinator *coordinator = [[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source];

    IDDocumentCaretGeometry *geometry = [coordinator
        caretGeometryForCanonicalOffset:1
                                affinity:IDBlockTextAffinityDownstream];

    XCTAssertNil(geometry);
    XCTAssertEqual(source.snapshotRequestCount, 2U);

    IDBlockDocument *pointDocument = IDBlockTextTestDocument(@[@"a"]);
    IDCoordinatorFakeSource *pointSource = [self sourceForDocument:pointDocument];
    __weak IDBlockDocument *weakPointDocument = pointDocument;
    pointSource.onSnapshot = ^(__unused NSUInteger requestIndex) {
        [weakPointDocument replaceCanonicalRange:
            NSMakeRange(weakPointDocument.canonicalLength, 0)
                withAttributedString:IDBlockTextTestAttributedString(@"x")];
    };
    IDDocumentLayoutCoordinator *pointCoordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:pointDocument
                                                       source:pointSource];

    XCTAssertNil([pointCoordinator
        nearestPositionToDocumentPoint:CGPointMake(10.0, 10.0)]);
    XCTAssertEqual(pointSource.snapshotRequestCount, 2U);
}

- (void)testLineGeometryCarriesRangeResolvedAffinityIdentityAndRevision {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"ab", @"", @"xyz"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    IDCoordinatorFakeSnapshot *snapshot =
        source.snapshotsByIdentifier[document.blocks[2].identifier];
    snapshot.usesLineResolvedAffinityOverride = YES;
    snapshot.lineResolvedAffinity = IDBlockTextAffinityUpstream;
    IDDocumentLayoutCoordinator *coordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:document
                                                       source:source];

    IDDocumentLineGeometry *line = [coordinator
        lineGeometryForCanonicalOffset:5
                              affinity:IDBlockTextAffinityDownstream];

    XCTAssertTrue(line.exact);
    XCTAssertTrue(NSEqualRanges(line.canonicalRange, NSMakeRange(4, 3)));
    XCTAssertEqual(line.resolvedAffinity, IDBlockTextAffinityUpstream);
    XCTAssertEqualObjects(line.position.blockIdentifier,
                          document.blocks[2].identifier);
    XCTAssertEqual(line.position.localPosition.utf16Offset, 1U);
    XCTAssertEqual(line.position.localPosition.affinity,
                   IDBlockTextAffinityUpstream);
    XCTAssertEqual(line.position.documentRevision, document.documentRevision);
    XCTAssertEqual(snapshot.lineRangeRequestCount, 1U);
}

- (void)testLineGeometryRetriesOnceAndReturnsNilAfterSecondRevisionChange {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"a"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    __weak IDBlockDocument *weakDocument = document;
    source.onSnapshot = ^(__unused NSUInteger requestIndex) {
        [weakDocument replaceCanonicalRange:
            NSMakeRange(weakDocument.canonicalLength, 0)
                withAttributedString:IDBlockTextTestAttributedString(@"x")];
    };
    IDDocumentLayoutCoordinator *coordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:document
                                                       source:source];

    XCTAssertNil([coordinator
        lineGeometryForCanonicalOffset:1
                              affinity:IDBlockTextAffinityDownstream]);
    XCTAssertEqual(source.snapshotRequestCount, 2U);
}

- (void)testGeometryQueriesRejectInvalidAffinityWithoutCallingProvider {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abc"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    IDCoordinatorFakeSnapshot *snapshot =
        source.snapshotsByIdentifier[document.blocks.firstObject.identifier];
    IDDocumentLayoutCoordinator *coordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:document
                                                       source:source];
    IDBlockTextAffinity invalid = (IDBlockTextAffinity)99;

    XCTAssertNil([coordinator caretGeometryForCanonicalOffset:1
                                                      affinity:invalid]);
    XCTAssertNil([coordinator lineGeometryForCanonicalOffset:1
                                                    affinity:invalid]);
    XCTAssertEqual(snapshot.caretGeometryRequestCount, 0U);
    XCTAssertEqual(snapshot.lineRangeRequestCount, 0U);
}

- (void)testLineGeometryRejectsStructuralSeparatorOverflowAndWrongIdentity {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"ab", @"xyz"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    IDCoordinatorFakeSnapshot *snapshot =
        source.snapshotsByIdentifier[document.blocks.firstObject.identifier];
    snapshot.usesLineRangeOverride = YES;
    snapshot.lineRangeOverride = NSMakeRange(1, 2);
    IDDocumentLayoutCoordinator *coordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:document
                                                       source:source];

    XCTAssertNil([coordinator
        lineGeometryForCanonicalOffset:1
                              affinity:IDBlockTextAffinityDownstream]);

    snapshot.usesLineRangeOverride = NO;
    source.wrongIdentitySnapshotIdentifier = document.blocks.firstObject.identifier;
    XCTAssertNil([coordinator
        lineGeometryForCanonicalOffset:1
                              affinity:IDBlockTextAffinityDownstream]);
}

- (void)testBlockStackSnapshotSourceDoesNotRequireMountedCanvasView {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"alpha", @"beta"]);
    IDBlockStackCanvasView *stack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    [stack updateForDocumentChange:nil width:180.0];
    IDBlockLayout *layout = stack.blockLayouts[1];
    [layout.canvasView removeFromSuperview];

    id<IDBlockLayoutSnapshot> snapshot = [stack
        snapshotForBlockIdentifier:layout.blockIdentifier
                  documentRevision:document.documentRevision];
    XCTAssertTrue(snapshot.valid);
    XCTAssertNotNil([snapshot caretGeometryForPosition:
        IDBlockTextPositionMake(1, IDBlockTextAffinityDownstream)]);
    XCTAssertTrue([snapshot caretNavigationResultForPoint:CGPointMake(10, 10)].found);
    XCTAssertNotEqual([snapshot
        lineRangeEnclosingPosition:
            IDBlockTextPositionMake(1, IDBlockTextAffinityDownstream)
                 resolvedAffinity:NULL].location,
                      NSNotFound);
    XCTAssertNil(layout.canvasView.superview);
}

- (IDBlockSelectionSegment *)selectionSegmentWithRange:(NSRange)range
                                                  rect:(CGRect)rect
                                             direction:(IDBlockWritingDirection)direction
                                          containsStart:(BOOL)containsStart
                                            containsEnd:(BOOL)containsEnd {
    return [[IDBlockSelectionSegment alloc]
        initWithLocalRange:range
                     rect:rect
             boundaryRole:IDBlockSelectionBoundaryRoleNone
       containsLocalStart:containsStart
         containsLocalEnd:containsEnd
         writingDirection:direction
                 vertical:NO
         layoutGeneration:1];
}

- (void)configureSelectionSegmentsForSource:(IDCoordinatorFakeSource *)source {
    for (IDBlock *block in source.document.blocks) {
        IDCoordinatorFakeSnapshot *snapshot =
            source.snapshotsByIdentifier[block.identifier];
        snapshot.selectionSegments = @[[self
            selectionSegmentWithRange:NSMakeRange(0, block.attributedText.length)
                                  rect:CGRectMake(2, 3, 40, 18)
                             direction:IDBlockWritingDirectionLeftToRight
                          containsStart:YES
                            containsEnd:YES]];
    }
}

- (void)testSelectionGeometryQueriesOnlyEligibleParticipatingBlocks {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"aa", @"bb", @"cc"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    [self configureSelectionSegmentsForSource:source];
    source.eligibleIdentifiers = @[document.blocks[1].identifier];
    IDDocumentLayoutCoordinator *coordinator =
        [[IDDocumentLayoutCoordinator alloc] initWithDocument:document source:source];

    IDDocumentSelectionGeometry *geometry =
        [coordinator selectionGeometryForCanonicalRange:
            NSMakeRange(0, document.canonicalLength)];

    XCTAssertNotNil(geometry);
    XCTAssertEqualObjects(source.requestedIdentifiers,
                          source.eligibleIdentifiers);
    XCTAssertEqual(geometry.segments.count, 1U);
}

- (void)testSelectionGeometryPublishesExactEmptyResultWhenNothingIsEligible {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"aa", @"bb"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    source.eligibleIdentifiers = @[];
    IDDocumentSelectionGeometry *geometry = [[[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source]
        selectionGeometryForCanonicalRange:NSMakeRange(0, document.canonicalLength)];
    XCTAssertNotNil(geometry);
    XCTAssertTrue(geometry.exact);
    XCTAssertEqual(geometry.segments.count, 0U);
    XCTAssertEqual(source.requestedIdentifiers.count, 0U);
}

- (void)testSelectionGeometryComposesDocumentOriginsAndStructuralSeparators {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"aa", @"bb"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    NSUUID *second = document.blocks[1].identifier;
    source.eligibleIdentifiers = @[second];
    source.origins = @{second: [NSValue valueWithCGPoint:CGPointMake(11, 23)]};
    source.snapshotsByIdentifier[second].selectionSegments = @[
        [[IDBlockSelectionSegment alloc]
            initWithLocalRange:NSMakeRange(0, 0)
                         rect:CGRectMake(2, 3, 40, 18)
                 boundaryRole:IDBlockSelectionBoundaryRoleHead
           containsLocalStart:YES
             containsLocalEnd:YES
             writingDirection:IDBlockWritingDirectionLeftToRight
                     vertical:NO
             layoutGeneration:1],
    ];
    IDDocumentSelectionGeometry *geometry = [[[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source]
        selectionGeometryForCanonicalRange:NSMakeRange(2, 1)];
    XCTAssertEqual(geometry.segments.count, 1U);
    IDDocumentSelectionSegment *segment = geometry.segments.firstObject;
    XCTAssertTrue(NSEqualRanges(segment.canonicalRange, NSMakeRange(2, 1)));
    XCTAssertTrue(CGRectEqualToRect(segment.documentRect,
                                   CGRectMake(13, 26, 40, 18)));
}

- (void)testSelectionGeometryUsesUpstreamTailForSeparatorOnlyRange {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abc", @"def"]);
    IDBlockStackCanvasView *stack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    [stack updateForDocumentChange:nil width:200.0];
    IDDocumentSelectionGeometry *geometry = [[[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:stack]
        selectionGeometryForCanonicalRange:NSMakeRange(3, 1)];

    XCTAssertNotNil(geometry);
    XCTAssertEqual(geometry.segments.count, 1U);
    IDDocumentSelectionSegment *segment = geometry.segments.firstObject;
    XCTAssertEqualObjects(segment.blockIdentifier,
                          document.blocks.firstObject.identifier);
    XCTAssertTrue((segment.boundaryRole &
                   IDBlockSelectionBoundaryRoleTail) != 0);
    XCTAssertTrue(segment.containsLogicalStart);
    XCTAssertTrue(segment.containsLogicalEnd);
}

- (void)testSelectionGeometryPreservesPerSegmentBiDiDirectionAndOrder {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abcd"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    IDCoordinatorFakeSnapshot *snapshot =
        source.snapshotsByIdentifier[document.blocks[0].identifier];
    snapshot.selectionSegments = @[
        [self selectionSegmentWithRange:NSMakeRange(0, 2) rect:CGRectMake(20, 0, 20, 18)
                              direction:IDBlockWritingDirectionRightToLeft
                           containsStart:YES containsEnd:NO],
        [self selectionSegmentWithRange:NSMakeRange(2, 2) rect:CGRectMake(0, 0, 20, 18)
                              direction:IDBlockWritingDirectionLeftToRight
                           containsStart:NO containsEnd:YES],
    ];
    IDDocumentSelectionGeometry *geometry = [[[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source]
        selectionGeometryForCanonicalRange:NSMakeRange(0, 4)];
    XCTAssertEqual(geometry.segments.count, 2U);
    XCTAssertEqual(geometry.segments[0].writingDirection,
                   IDBlockWritingDirectionRightToLeft);
    XCTAssertEqual(geometry.segments[1].writingDirection,
                   IDBlockWritingDirectionLeftToRight);
}

- (void)testSelectionGeometryLeavesUnavailableEndpointRolesUnclaimed {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"aa", @"bb", @"cc"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    [self configureSelectionSegmentsForSource:source];
    source.eligibleIdentifiers = @[document.blocks[1].identifier];
    IDDocumentSelectionGeometry *geometry = [[[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source]
        selectionGeometryForCanonicalRange:NSMakeRange(0, document.canonicalLength)];
    for (IDDocumentSelectionSegment *segment in geometry.segments) {
        XCTAssertFalse(segment.containsLogicalStart);
        XCTAssertFalse(segment.containsLogicalEnd);
    }
}

- (void)testSelectionGeometryRejectsDuplicateOrContradictoryEndpointClaims {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abcd"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    IDCoordinatorFakeSnapshot *snapshot =
        source.snapshotsByIdentifier[document.blocks[0].identifier];
    snapshot.selectionSegments = @[
        [self selectionSegmentWithRange:NSMakeRange(0, 2) rect:CGRectMake(0, 0, 20, 18)
                              direction:IDBlockWritingDirectionLeftToRight
                           containsStart:YES containsEnd:NO],
        [self selectionSegmentWithRange:NSMakeRange(0, 4) rect:CGRectMake(20, 0, 20, 18)
                              direction:IDBlockWritingDirectionLeftToRight
                           containsStart:YES containsEnd:YES],
    ];
    XCTAssertNil([[[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source]
        selectionGeometryForCanonicalRange:NSMakeRange(0, 4)]);
}

- (void)testSelectionGeometryRetriesWholeTransactionOnceForDocumentRevision {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"aa"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    [self configureSelectionSegmentsForSource:source];
    __weak IDBlockDocument *weakDocument = document;
    source.onSnapshot = ^(NSUInteger requestIndex) {
        if (requestIndex == 0) [weakDocument replaceCanonicalRange:NSMakeRange(0, 0)
            withAttributedString:IDBlockTextTestAttributedString(@"x")];
    };
    (void)[[[IDDocumentLayoutCoordinator alloc] initWithDocument:document source:source]
        selectionGeometryForCanonicalRange:NSMakeRange(0, 1)];
    XCTAssertEqual(source.snapshotRequestCount, 2U);
}

- (void)testSelectionGeometryRetriesWholeTransactionOnceForSourceGeneration {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"aa"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    [self configureSelectionSegmentsForSource:source];
    source.onEligibility = ^(NSUInteger requestIndex) {
        if (requestIndex == 1) source.geometryGeneration += 1;
    };
    XCTAssertNotNil([[[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source]
        selectionGeometryForCanonicalRange:NSMakeRange(0, 1)]);
    XCTAssertGreaterThanOrEqual(source.eligibilityRequestCount, 4U);
}

- (void)testSelectionGeometryReturnsNilAfterSecondGenerationChange {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"aa"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    [self configureSelectionSegmentsForSource:source];
    source.onEligibility = ^(__unused NSUInteger requestIndex) {
        source.geometryGeneration += 1;
    };
    XCTAssertNil([[[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source]
        selectionGeometryForCanonicalRange:NSMakeRange(0, 1)]);
}

- (void)testSelectionGeometryRejectsMissingCapabilitySnapshotMutationAndNonfiniteGeometry {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"aa"]);
    IDCoordinatorFakeSource *source = [self sourceForDocument:document];
    [self configureSelectionSegmentsForSource:source];
    source.capabilityLimitedSnapshotIdentifier = document.blocks[0].identifier;
    source.limitedCapabilities = IDBlockLayoutCapabilityCaretGeometry;
    IDDocumentLayoutCoordinator *coordinator = [[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:source];
    XCTAssertNil([coordinator selectionGeometryForCanonicalRange:NSMakeRange(0, 1)]);
    source.capabilityLimitedSnapshotIdentifier = nil;
    source.nonfiniteOriginIdentifier = document.blocks[0].identifier;
    XCTAssertNil([coordinator selectionGeometryForCanonicalRange:NSMakeRange(0, 1)]);
}

/// A separator is offered to BOTH the block before it and the block after it, and only one of them
/// may own it.
///
/// `extendTail` on block i and `extendHead` on block i+1 are the same condition — the separator's
/// offset is inside the selection — so both sides are always asked. The block BEFORE draws it (a
/// tail extension widens its last segment to the line's end, which is the newline's highlight);
/// the block AFTER has nothing to draw there. When the selection STARTS on that separator both
/// sides also claimed the logical start, and the duplicate-endpoint guard then discarded the
/// geometry for the entire document — a selection that simply did not appear (2026-09-15).
- (void)testASeparatorStartingASelectionIsClaimedOnceByTheBlockBeforeIt {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abc", @"def"]);
    IDBlockStackCanvasView *stack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    [stack updateForDocumentChange:nil width:200.0];

    IDDocumentSelectionGeometry *geometry = [[[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:stack]
        selectionGeometryForCanonicalRange:NSMakeRange(3, 2)];

    XCTAssertNotNil(geometry, @"the selection \"\\nd\" produced no geometry at all");
    NSUInteger starts = 0;
    NSUInteger ends = 0;
    for (IDDocumentSelectionSegment *segment in geometry.segments) {
        starts += segment.containsLogicalStart ? 1 : 0;
        ends += segment.containsLogicalEnd ? 1 : 0;
    }
    XCTAssertEqual(geometry.segments.count, 2U, @"one line of highlight each");
    XCTAssertEqual(starts, 1U);
    XCTAssertEqual(ends, 1U);
    XCTAssertEqualObjects(geometry.segments.firstObject.blockIdentifier,
                          document.blocks.firstObject.identifier);
    XCTAssertTrue(geometry.segments.firstObject.containsLogicalStart,
                  @"the start handle belongs to the separator's own line, not the next one");
}

/// The reported symptom, at the layer that produced it: a selection whose boundary lands on an
/// empty line. Every one of these is a selection whose boundary is a separator, which is why an
/// empty line made the selection disappear while the same document's other selections were fine.
- (void)testSelectionsBoundedByAnEmptyBlockKeepTheirGeometry {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abc", @"", @"def"]);
    IDBlockStackCanvasView *stack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    [stack updateForDocumentChange:nil width:200.0];
    IDDocumentLayoutCoordinator *coordinator = [[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:stack];

    // "abc\n" — ends ON the empty line.        "\ndef" — starts ON the empty line.
    NSArray<NSValue *> *ranges = @[[NSValue valueWithRange:NSMakeRange(0, 4)],
                                   [NSValue valueWithRange:NSMakeRange(4, 4)],
                                   [NSValue valueWithRange:NSMakeRange(2, 3)],
                                   [NSValue valueWithRange:NSMakeRange(0, 8)]];
    for (NSValue *value in ranges) {
        NSRange range = value.rangeValue;
        IDDocumentSelectionGeometry *geometry =
            [coordinator selectionGeometryForCanonicalRange:range];
        XCTAssertNotNil(geometry, @"range=%@", NSStringFromRange(range));
        XCTAssertGreaterThan(geometry.segments.count, 0U, @"range=%@",
                             NSStringFromRange(range));
        NSUInteger starts = 0;
        NSUInteger ends = 0;
        for (IDDocumentSelectionSegment *segment in geometry.segments) {
            XCTAssertFalse(CGRectIsEmpty(segment.documentRect), @"range=%@",
                           NSStringFromRange(range));
            starts += segment.containsLogicalStart ? 1 : 0;
            ends += segment.containsLogicalEnd ? 1 : 0;
        }
        XCTAssertEqual(starts, 1U, @"range=%@", NSStringFromRange(range));
        XCTAssertEqual(ends, 1U, @"range=%@", NSStringFromRange(range));
    }
}

/// Every empty line in a run of them keeps its own highlight.
///
/// An empty block IS a separator and nothing else, so the rule that stops a block claiming a
/// separator its neighbour already owns must not also stop it drawing its own line. It did: a
/// selection starting on the first of two empty lines left the second one blank (2026-09-15).
- (void)testEveryEmptyLineInARunKeepsItsOwnHighlight {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"a", @"", @"", @"b"]);
    IDBlockStackCanvasView *stack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    [stack updateForDocumentChange:nil width:200.0];

    // From the first empty line through the second and into "b".
    IDDocumentSelectionGeometry *geometry = [[[IDDocumentLayoutCoordinator alloc]
        initWithDocument:document source:stack]
        selectionGeometryForCanonicalRange:NSMakeRange(2, 3)];

    XCTAssertNotNil(geometry);
    NSMutableSet<NSUUID *> *blocks = [NSMutableSet set];
    for (IDDocumentSelectionSegment *segment in geometry.segments) {
        [blocks addObject:segment.blockIdentifier];
    }
    XCTAssertEqual(blocks.count, 3U, @"one highlight per selected line");
    XCTAssertTrue([blocks containsObject:document.blocks[2].identifier],
                  @"the second empty line drew nothing");
}

@end
