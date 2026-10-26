@import XCTest;

#import "IDBlockLayoutSnapshot.h"
#import "IDBlockDocument.h"
#import "IDBlockDocumentInternal.h"
#import "IDBlockLayout.h"
#import "IDBlockStackCanvasView.h"
#import "IDBlockTextTestSupport.h"
#import "IDRichTextSelectionRect.h"
#import "IDTextKit2BlockLayoutProvider.h"

#include <math.h>

static UITextStorageDirection IDTestUIKitAffinity(
    IDBlockTextAffinity affinity) {
    return affinity == IDBlockTextAffinityUpstream
        ? UITextStorageDirectionBackward
        : UITextStorageDirectionForward;
}

static IDBlockTextAffinity IDTestNeutralAffinity(
    UITextStorageDirection affinity) {
    return affinity == UITextStorageDirectionBackward
        ? IDBlockTextAffinityUpstream
        : IDBlockTextAffinityDownstream;
}

static UITextLayoutDirection IDTestUIKitDirection(
    IDBlockLayoutDirection direction) {
    switch (direction) {
        case IDBlockLayoutDirectionLeft:
            return UITextLayoutDirectionLeft;
        case IDBlockLayoutDirectionRight:
            return UITextLayoutDirectionRight;
        case IDBlockLayoutDirectionUp:
            return UITextLayoutDirectionUp;
        case IDBlockLayoutDirectionDown:
            return UITextLayoutDirectionDown;
    }
    return (UITextLayoutDirection)-1;
}

@interface IDBlockLayoutSnapshotTests : XCTestCase
@end

@implementation IDBlockLayoutSnapshotTests

- (IDBlockStackCanvasView *)stackForDocument:(IDBlockDocument *)document
                                        width:(CGFloat)width {
    IDBlockStackCanvasView *stack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    [stack updateForDocumentChange:nil width:width];
    return stack;
}

- (void)testNeutralPositionAndRangePreserveLiteralOffsetsAndAffinities {
    IDBlockTextPosition start = IDBlockTextPositionMake(
        3, IDBlockTextAffinityUpstream);
    IDBlockTextPosition end = IDBlockTextPositionMake(
        11, IDBlockTextAffinityDownstream);
    IDBlockTextRange range = IDBlockTextRangeMake(start, end);

    XCTAssertEqual(range.start.utf16Offset, 3U);
    XCTAssertEqual(range.start.affinity, IDBlockTextAffinityUpstream);
    XCTAssertEqual(range.end.utf16Offset, 11U);
    XCTAssertEqual(range.end.affinity, IDBlockTextAffinityDownstream);
    XCTAssertTrue(IDBlockTextPositionEqual(
        start, IDBlockTextPositionMake(3, IDBlockTextAffinityUpstream)));
    XCTAssertFalse(IDBlockTextPositionEqual(start, end));
}

- (void)testNeutralConstraintsPreserveWidthAndScale {
    IDBlockLayoutConstraints constraints =
        IDBlockLayoutConstraintsMake(240.5, 1.0);

    XCTAssertEqualWithAccuracy(constraints.containerWidth, 240.5, 0.001);
    XCTAssertEqualWithAccuracy(constraints.layoutScale, 1.0, 0.001);
    XCTAssertTrue(IDBlockLayoutConstraintsEqual(
        constraints, IDBlockLayoutConstraintsMake(240.5, 1.0)));
    XCTAssertFalse(IDBlockLayoutConstraintsEqual(
        constraints, IDBlockLayoutConstraintsMake(200.0, 1.0)));
}

- (void)testNeutralCapabilitiesComposeWithoutUIKitTypes {
    IDBlockLayoutCapability capabilities =
        IDBlockLayoutCapabilityCaretGeometry |
        IDBlockLayoutCapabilityPointHitTesting |
        IDBlockLayoutCapabilityLineRanges |
        IDBlockLayoutCapabilityVisualNavigation |
        IDBlockLayoutCapabilityBaseWritingDirection;

    XCTAssertTrue(capabilities & IDBlockLayoutCapabilityCaretGeometry);
    XCTAssertTrue(capabilities & IDBlockLayoutCapabilityPointHitTesting);
    XCTAssertTrue(capabilities & IDBlockLayoutCapabilityLineRanges);
    XCTAssertTrue(capabilities & IDBlockLayoutCapabilityVisualNavigation);
    XCTAssertTrue(capabilities & IDBlockLayoutCapabilityBaseWritingDirection);
}

- (void)testSelectionSegmentPreservesRangeBoundaryRolesAndDirection {
    IDBlockSelectionSegment *segment = [[IDBlockSelectionSegment alloc]
        initWithLocalRange:NSMakeRange(4, 3)
                     rect:CGRectMake(12.5, 8.0, 40.0, 19.0)
             boundaryRole:(IDBlockSelectionBoundaryRoleHead |
                           IDBlockSelectionBoundaryRoleTail)
       containsLocalStart:YES
         containsLocalEnd:NO
         writingDirection:IDBlockWritingDirectionRightToLeft
                 vertical:YES
         layoutGeneration:7];

    XCTAssertTrue(NSEqualRanges(segment.localRange, NSMakeRange(4, 3)));
    XCTAssertTrue(CGRectEqualToRect(segment.rect,
                                    CGRectMake(12.5, 8.0, 40.0, 19.0)));
    XCTAssertEqual(segment.boundaryRole,
                   IDBlockSelectionBoundaryRoleHead |
                   IDBlockSelectionBoundaryRoleTail);
    XCTAssertTrue(segment.containsLocalStart);
    XCTAssertFalse(segment.containsLocalEnd);
    XCTAssertEqual(segment.writingDirection,
                   IDBlockWritingDirectionRightToLeft);
    XCTAssertTrue(segment.isVertical);
    XCTAssertEqual(segment.layoutGeneration, 7U);
}

- (void)testSelectionSegmentRejectsMalformedRangeGeometryAndMetadata {
    CGRect validRect = CGRectMake(1, 2, 3, 4);
    XCTAssertThrowsSpecificNamed(
        [[IDBlockSelectionSegment alloc]
            initWithLocalRange:NSMakeRange(NSNotFound, 0)
                         rect:validRect
                 boundaryRole:IDBlockSelectionBoundaryRoleNone
           containsLocalStart:NO containsLocalEnd:NO
             writingDirection:IDBlockWritingDirectionLeftToRight
                     vertical:NO layoutGeneration:1],
        NSException, NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed(
        [[IDBlockSelectionSegment alloc]
            initWithLocalRange:NSMakeRange(NSUIntegerMax - 1, 3)
                         rect:validRect
                 boundaryRole:IDBlockSelectionBoundaryRoleNone
           containsLocalStart:NO containsLocalEnd:NO
             writingDirection:IDBlockWritingDirectionLeftToRight
                     vertical:NO layoutGeneration:1],
        NSException, NSInvalidArgumentException);
    for (NSValue *value in @[
        [NSValue valueWithCGRect:CGRectNull],
        [NSValue valueWithCGRect:CGRectInfinite],
        [NSValue valueWithCGRect:CGRectMake(NAN, 0, 3, 4)],
        [NSValue valueWithCGRect:CGRectMake(0, 0, 0, 4)],
        [NSValue valueWithCGRect:CGRectMake(0, 0, 3, 0)],
    ]) {
        XCTAssertThrowsSpecificNamed(
            [[IDBlockSelectionSegment alloc]
                initWithLocalRange:NSMakeRange(0, 1)
                             rect:value.CGRectValue
                     boundaryRole:IDBlockSelectionBoundaryRoleNone
               containsLocalStart:NO containsLocalEnd:NO
                 writingDirection:IDBlockWritingDirectionLeftToRight
                         vertical:NO layoutGeneration:1],
            NSException, NSInvalidArgumentException);
    }
    XCTAssertThrowsSpecificNamed(
        [[IDBlockSelectionSegment alloc]
            initWithLocalRange:NSMakeRange(0, 1) rect:validRect
                 boundaryRole:(IDBlockSelectionBoundaryRole)(1 << 8)
           containsLocalStart:NO containsLocalEnd:NO
             writingDirection:IDBlockWritingDirectionLeftToRight
                     vertical:NO layoutGeneration:1],
        NSException, NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed(
        [[IDBlockSelectionSegment alloc]
            initWithLocalRange:NSMakeRange(0, 1) rect:validRect
                 boundaryRole:IDBlockSelectionBoundaryRoleNone
           containsLocalStart:NO containsLocalEnd:NO
             writingDirection:(IDBlockWritingDirection)99
                     vertical:NO layoutGeneration:1],
        NSException, NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed(
        [[IDBlockSelectionSegment alloc]
            initWithLocalRange:NSMakeRange(0, 1) rect:validRect
                 boundaryRole:IDBlockSelectionBoundaryRoleNone
           containsLocalStart:NO containsLocalEnd:NO
             writingDirection:IDBlockWritingDirectionLeftToRight
                     vertical:NO layoutGeneration:0],
        NSException, NSInvalidArgumentException);
}

- (void)testSelectionSegmentCapabilityComposesWithoutUIKitTypes {
    IDBlockLayoutCapability capabilities =
        IDBlockLayoutCapabilityCaretGeometry |
        IDBlockLayoutCapabilitySelectionSegments;
    XCTAssertTrue(capabilities & IDBlockLayoutCapabilityCaretGeometry);
    XCTAssertTrue(capabilities & IDBlockLayoutCapabilitySelectionSegments);
}

- (void)testTextKit2SnapshotSelectionSegmentsMatchEstablishedBlockLayout {
    for (NSString *text in @[
        @"alpha beta wrapped words", @"אבגדה six mixed text",
        @"A👨‍👩‍👧‍👦B composed tail", @"",
    ]) {
        IDBlockDocument *document = IDBlockTextTestDocument(@[text]);
        IDBlockStackCanvasView *stack = [self stackForDocument:document
                                                         width:130.0];
        IDBlockLayout *layout = stack.blockLayouts.firstObject;
        id<IDBlockLayoutSnapshot> snapshot =
            [[[IDTextKit2BlockLayoutProvider alloc] initWithBlockLayout:layout]
                snapshotForDocumentRevision:document.documentRevision];
        NSArray<NSDictionary *> *queries = @[
            @{@"range": [NSValue valueWithRange:NSMakeRange(0, text.length)],
              @"head": @NO, @"tail": @NO},
            @{@"range": [NSValue valueWithRange:NSMakeRange(text.length, 0)],
              @"head": @NO, @"tail": @YES},
        ];
        for (NSDictionary *query in queries) {
            NSRange range = [query[@"range"] rangeValue];
            BOOL extendHead = [query[@"head"] boolValue];
            BOOL extendTail = [query[@"tail"] boolValue];
            NSArray<IDBlockSelectionSegment *> *segments = [snapshot
                selectionSegmentsForLocalRange:range
                                     extendHead:extendHead
                                     extendTail:extendTail];
            NSArray<IDRichTextSelectionRect *> *rects = [layout
                selectionRectsForLocalRange:range
                                  extendHead:extendHead
                                  extendTail:extendTail];
            XCTAssertNotNil(segments);
            XCTAssertEqual(segments.count, rects.count,
                           @"text=%@ range=%@", text, NSStringFromRange(range));
            for (NSUInteger index = 0;
                 index < MIN(segments.count, rects.count); index += 1) {
                IDBlockSelectionSegment *segment = segments[index];
                IDRichTextSelectionRect *rect = rects[index];
                XCTAssertTrue(CGRectEqualToRect(segment.rect, rect.rect));
                XCTAssertEqual(segment.containsLocalStart, rect.containsStart);
                XCTAssertEqual(segment.containsLocalEnd, rect.containsEnd);
                XCTAssertEqual(segment.isVertical, rect.isVertical);
                XCTAssertEqual(segment.writingDirection,
                    rect.writingDirection == NSWritingDirectionRightToLeft
                        ? IDBlockWritingDirectionRightToLeft
                        : IDBlockWritingDirectionLeftToRight);
                XCTAssertEqual(segment.layoutGeneration,
                               snapshot.layoutGeneration);
            }
        }
    }
}

- (void)testTextKit2SnapshotBaseWritingDirectionMatchesBlockLayoutAtEveryOffset {
    for (NSString *text in @[@"alpha", @"אבגדה", @"abc אבג def", @""]) {
        IDBlockDocument *document = IDBlockTextTestDocument(@[text]);
        IDBlockStackCanvasView *stack = [self stackForDocument:document
                                                         width:200.0];
        IDBlockLayout *layout = stack.blockLayouts.firstObject;
        id<IDBlockLayoutSnapshot> snapshot =
            [[[IDTextKit2BlockLayoutProvider alloc] initWithBlockLayout:layout]
                snapshotForDocumentRevision:document.documentRevision];

        XCTAssertTrue(snapshot.capabilities &
                      IDBlockLayoutCapabilityBaseWritingDirection);
        for (NSUInteger offset = 0; offset <= text.length; offset += 1) {
            IDBlockWritingDirection actual = [snapshot
                id_snapshotBaseWritingDirectionAtPosition:
                    IDBlockTextPositionMake(offset,
                                            IDBlockTextAffinityDownstream)];
            IDBlockWritingDirection expected =
                [layout baseWritingDirectionAtLocalOffset:offset] ==
                    NSWritingDirectionRightToLeft
                ? IDBlockWritingDirectionRightToLeft
                : IDBlockWritingDirectionLeftToRight;
            XCTAssertEqual(actual, expected, @"%@ offset=%lu", text,
                           (unsigned long)offset);
        }
    }
}

- (void)testNeutralValueConstructionRejectsInvalidInputs {
    XCTAssertThrowsSpecificNamed(
        IDBlockTextPositionMake(0, (IDBlockTextAffinity)99),
        NSException,
        NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed(
        IDBlockLayoutConstraintsMake(-1.0, 1.0),
        NSException,
        NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed(
        IDBlockLayoutConstraintsMake(100.0, 0.0),
        NSException,
        NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed(
        IDBlockLayoutConstraintsMake(NAN, 1.0),
        NSException,
        NSInvalidArgumentException);
}

- (void)testLineIdentityCopiesAndComparesByRangeAndGeneration {
    IDBlockLineIdentifier *line = [[IDBlockLineIdentifier alloc]
        initWithLocalRange:NSMakeRange(4, 8)
          layoutGeneration:7];
    IDBlockLineIdentifier *equalLine = [[IDBlockLineIdentifier alloc]
        initWithLocalRange:NSMakeRange(4, 8)
          layoutGeneration:7];
    IDBlockLineIdentifier *otherGeneration = [[IDBlockLineIdentifier alloc]
        initWithLocalRange:NSMakeRange(4, 8)
          layoutGeneration:8];

    XCTAssertEqualObjects(line, equalLine);
    XCTAssertEqual(line.hash, equalLine.hash);
    XCTAssertNotEqualObjects(line, otherGeneration);
    XCTAssertEqualObjects([line copy], line);
    XCTAssertThrowsSpecificNamed(
        [[IDBlockLineIdentifier alloc]
            initWithLocalRange:NSMakeRange(NSNotFound, 0)
              layoutGeneration:7],
        NSException,
        NSInvalidArgumentException);
}

- (void)testCaretGeometryPreservesNeutralValuesAndRejectsNonfiniteRectangles {
    IDBlockTextPosition position = IDBlockTextPositionMake(
        5, IDBlockTextAffinityDownstream);
    IDBlockLineIdentifier *line = [[IDBlockLineIdentifier alloc]
        initWithLocalRange:NSMakeRange(2, 6)
          layoutGeneration:9];
    IDBlockCaretGeometry *geometry = [[IDBlockCaretGeometry alloc]
        initWithPosition:position
                    rect:CGRectMake(12.5, 3.0, 2.0, 19.0)
        writingDirection:IDBlockWritingDirectionRightToLeft
          lineIdentifier:line];

    XCTAssertTrue(IDBlockTextPositionEqual(geometry.position, position));
    XCTAssertTrue(CGRectEqualToRect(
        geometry.rect, CGRectMake(12.5, 3.0, 2.0, 19.0)));
    XCTAssertEqual(geometry.writingDirection,
                   IDBlockWritingDirectionRightToLeft);
    XCTAssertEqualObjects(geometry.lineIdentifier, line);

    XCTAssertThrowsSpecificNamed(
        [[IDBlockCaretGeometry alloc]
            initWithPosition:position
                        rect:CGRectMake(NAN, 0, 2, 19)
            writingDirection:IDBlockWritingDirectionLeftToRight
              lineIdentifier:line],
        NSException,
        NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed(
        [[IDBlockCaretGeometry alloc]
            initWithPosition:position
                        rect:CGRectMake(0, 0, 2, 19)
            writingDirection:(IDBlockWritingDirection)99
              lineIdentifier:line],
        NSException,
        NSInvalidArgumentException);
}

- (void)testTextKit2ProviderSnapshotStaysValidAcrossNoOpAndStalesOnWidthChange {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"alpha beta"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:200.0];
    IDBlockLayout *layout = stack.blockLayouts.firstObject;
    NSUInteger generation = layout.layoutGeneration;
    NSUInteger contentRevision = layout.contentRevision;
    IDTextKit2BlockLayoutProvider *provider =
        [[IDTextKit2BlockLayoutProvider alloc] initWithBlockLayout:layout];
    id<IDBlockLayoutSnapshot> snapshot =
        [provider snapshotForDocumentRevision:document.documentRevision];

    XCTAssertTrue(snapshot.valid);
    XCTAssertEqualObjects(provider.blockIdentifier, layout.blockIdentifier);
    XCTAssertEqualObjects(snapshot.blockIdentifier, layout.blockIdentifier);
    XCTAssertEqual(snapshot.documentRevision, document.documentRevision);
    XCTAssertEqual(snapshot.layoutGeneration, generation);
    XCTAssertEqual(snapshot.contentRevision, contentRevision);
    XCTAssertEqual(snapshot.utf16Length,
                   layout.contentStorage.textStorage.length);
    XCTAssertEqualWithAccuracy(snapshot.layoutConstraints.containerWidth,
                               200.0,
                               0.001);
    XCTAssertEqualWithAccuracy(snapshot.layoutConstraints.layoutScale, 1.0, 0.001);
    XCTAssertEqual(snapshot.capabilities,
        IDBlockLayoutCapabilityCaretGeometry |
        IDBlockLayoutCapabilityPointHitTesting |
        IDBlockLayoutCapabilityLineRanges |
        IDBlockLayoutCapabilityVisualNavigation |
        IDBlockLayoutCapabilityBaseWritingDirection |
        IDBlockLayoutCapabilitySelectionSegments);

    [stack updateForDocumentChange:nil width:200.0];
    XCTAssertEqual(layout.layoutGeneration, generation);
    XCTAssertEqual(layout.contentRevision, contentRevision);
    XCTAssertTrue(snapshot.valid);

    [stack updateForDocumentChange:nil width:120.0];
    XCTAssertGreaterThan(layout.layoutGeneration, generation);
    XCTAssertEqual(layout.contentRevision, contentRevision);
    XCTAssertFalse(snapshot.valid);
}

- (void)testTextKit2ProviderSnapshotStalesOnceForAttributedContentChange {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"alpha beta"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:200.0];
    IDBlockLayout *layout = stack.blockLayouts.firstObject;
    NSUInteger generation = layout.layoutGeneration;
    NSUInteger contentRevision = layout.contentRevision;
    IDTextKit2BlockLayoutProvider *provider =
        [[IDTextKit2BlockLayoutProvider alloc] initWithBlockLayout:layout];
    id<IDBlockLayoutSnapshot> snapshot =
        [provider snapshotForDocumentRevision:document.documentRevision];

    IDBlockDocumentChange *change = [document
        replaceCanonicalRange:NSMakeRange(1, 1)
        withAttributedString:IDBlockTextTestAttributedString(@"L")];
    [stack updateForDocumentChange:change width:200.0];

    XCTAssertEqual(layout.contentRevision, contentRevision + 1);
    XCTAssertEqual(layout.layoutGeneration, generation + 1);
    XCTAssertFalse(snapshot.valid);
}

- (void)testSeparatorAttributeChangeAdvancesContentAndLayoutRevisionsOnce {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"alpha", @"beta"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:200.0];
    IDBlockLayout *layout = stack.blockLayouts.firstObject;
    NSUInteger generation = layout.layoutGeneration;
    NSUInteger contentRevision = layout.contentRevision;

    NSDictionary<NSAttributedStringKey, id> *separatorAttributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:23.0],
        NSForegroundColorAttributeName: UIColor.systemRedColor,
    };
    IDBlockDocumentChange *change = [document
        id_setAttributes:separatorAttributes
        canonicalRange:NSMakeRange(document.blocks.firstObject.attributedText.length,
                                   1)];
    [stack updateForDocumentChange:change width:200.0];

    XCTAssertEqual(layout.contentRevision, contentRevision + 1);
    XCTAssertEqual(layout.layoutGeneration, generation + 1);
}

- (void)testTextKit2SnapshotCaretAndLineGeometryMatchesEstablishedBlockLayout {
    for (NSString *text in @[@"alpha beta", @"אבגדה six", @"A👨‍👩‍👧‍👦B", @""]) {
        IDBlockDocument *document = IDBlockTextTestDocument(@[text]);
        IDBlockStackCanvasView *stack = [self stackForDocument:document width:130.0];
        IDBlockLayout *layout = stack.blockLayouts.firstObject;
        IDTextKit2BlockLayoutProvider *provider =
            [[IDTextKit2BlockLayoutProvider alloc] initWithBlockLayout:layout];
        id<IDBlockLayoutSnapshot> snapshot =
            [provider snapshotForDocumentRevision:document.documentRevision];

        for (NSUInteger offset = 0; offset <= text.length; offset += 1) {
            for (NSNumber *affinityValue in @[
                @(IDBlockTextAffinityUpstream),
                @(IDBlockTextAffinityDownstream),
            ]) {
                IDBlockTextAffinity affinity = affinityValue.integerValue;
                UITextStorageDirection expectedAffinity =
                    IDTestUIKitAffinity(affinity);
                CGRect expectedRect = [layout
                    caretRectForLocalOffset:offset
                                   affinity:expectedAffinity];
                NSRange expectedLine = [layout
                    localLineRangeEnclosingOffset:offset
                                effectiveAffinity:&expectedAffinity];
                IDBlockCaretGeometry *actual = [snapshot
                    caretGeometryForPosition:IDBlockTextPositionMake(offset,
                                                                     affinity)];

                XCTAssertNotNil(actual, @"%@ offset=%lu affinity=%ld",
                                text,
                                (unsigned long)offset,
                                (long)affinity);
                XCTAssertEqualWithAccuracy(actual.rect.origin.x,
                                           expectedRect.origin.x,
                                           0.001);
                XCTAssertEqualWithAccuracy(actual.rect.origin.y,
                                           expectedRect.origin.y,
                                           0.001);
                XCTAssertEqualWithAccuracy(actual.rect.size.width,
                                           expectedRect.size.width,
                                           0.001);
                XCTAssertEqualWithAccuracy(actual.rect.size.height,
                                           expectedRect.size.height,
                                           0.001);
                XCTAssertEqual(actual.position.utf16Offset, offset);
                XCTAssertEqual(actual.position.affinity,
                               IDTestNeutralAffinity(expectedAffinity));
                XCTAssertEqualObjects(actual.lineIdentifier,
                    [[IDBlockLineIdentifier alloc]
                        initWithLocalRange:expectedLine
                          layoutGeneration:snapshot.layoutGeneration]);
                IDBlockWritingDirection expectedDirection =
                    [layout baseWritingDirectionAtLocalOffset:offset] ==
                            NSWritingDirectionRightToLeft
                        ? IDBlockWritingDirectionRightToLeft
                        : IDBlockWritingDirectionLeftToRight;
                XCTAssertEqual(actual.writingDirection, expectedDirection);
            }
        }
    }
}

- (void)testTextKit2SnapshotPointQueriesMatchEstablishedBlockLayout {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"alpha beta gamma"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:90.0];
    IDBlockLayout *layout = stack.blockLayouts.firstObject;
    id<IDBlockLayoutSnapshot> snapshot =
        [[[IDTextKit2BlockLayoutProvider alloc] initWithBlockLayout:layout]
            snapshotForDocumentRevision:document.documentRevision];
    CGRect firstCaret = [layout caretRectForLocalOffset:0
                                               affinity:UITextStorageDirectionForward];
    CGRect middleCaret = [layout caretRectForLocalOffset:5
                                                affinity:UITextStorageDirectionForward];
    NSArray<NSValue *> *points = @[
        [NSValue valueWithCGPoint:CGPointMake(0, -10)],
        [NSValue valueWithCGPoint:CGPointMake(CGRectGetMidX(firstCaret),
                                               CGRectGetMidY(firstCaret))],
        [NSValue valueWithCGPoint:CGPointMake(CGRectGetMidX(middleCaret) + 1.5,
                                               CGRectGetMidY(middleCaret))],
        [NSValue valueWithCGPoint:CGPointMake(40,
                                               layout.usedSize.height + 20)],
    ];

    for (NSValue *pointValue in points) {
        CGPoint point = pointValue.CGPointValue;
        IDBlockCaretStop expected = [layout caretStopForPoint:point];
        IDBlockCaretNavigationResult actual =
            [snapshot caretNavigationResultForPoint:point];
        XCTAssertEqual(actual.found, expected.found, @"%@", pointValue);
        if (expected.found) {
            XCTAssertEqual(actual.position.utf16Offset, expected.localOffset);
            XCTAssertEqual(actual.position.affinity,
                           IDTestNeutralAffinity(expected.affinity));
            XCTAssertEqualWithAccuracy(actual.anchorPositionOffset,
                                       expected.anchorPositionOffset,
                                       0.001);
        }
    }
}

- (void)testEmptyTextKit2PointQueryReturnsTheOnlyCaretStop {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@""]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:90.0];
    IDBlockLayout *layout = stack.blockLayouts.firstObject;
    id<IDBlockLayoutSnapshot> snapshot =
        [[[IDTextKit2BlockLayoutProvider alloc] initWithBlockLayout:layout]
            snapshotForDocumentRevision:document.documentRevision];
    CGRect caret = [layout caretRectForLocalOffset:0
                                          affinity:UITextStorageDirectionForward];
    CGPoint point = CGPointMake(32.0, CGRectGetMidY(caret));

    IDBlockCaretStop established = [layout caretStopForPoint:point];
    IDBlockCaretNavigationResult neutral =
        [snapshot caretNavigationResultForPoint:point];

    XCTAssertTrue(established.found);
    XCTAssertEqual(established.localOffset, 0U);
    XCTAssertEqual(established.affinity, UITextStorageDirectionForward);
    XCTAssertEqualWithAccuracy(established.anchorPositionOffset, 32.0, 0.001);
    XCTAssertTrue(neutral.found);
    XCTAssertEqual(neutral.position.utf16Offset, 0U);
    XCTAssertEqual(neutral.position.affinity, IDBlockTextAffinityDownstream);
    XCTAssertEqualWithAccuracy(neutral.anchorPositionOffset, 32.0, 0.001);
}

- (void)testTextKit2SnapshotGeometryRefusesStaleAndInvalidQueries {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"alpha beta"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:160.0];
    IDBlockLayout *layout = stack.blockLayouts.firstObject;
    id<IDBlockLayoutSnapshot> snapshot =
        [[[IDTextKit2BlockLayoutProvider alloc] initWithBlockLayout:layout]
            snapshotForDocumentRevision:document.documentRevision];

    XCTAssertNil([snapshot caretGeometryForPosition:
        IDBlockTextPositionMake(100, IDBlockTextAffinityDownstream)]);
    XCTAssertFalse([snapshot caretNavigationResultForPoint:
        CGPointMake(NAN, 0)].found);

    [stack updateForDocumentChange:nil width:80.0];
    XCTAssertFalse(snapshot.valid);
    XCTAssertNil([snapshot caretGeometryForPosition:
        IDBlockTextPositionMake(0, IDBlockTextAffinityDownstream)]);
    XCTAssertTrue(NSEqualRanges(
        [snapshot lineRangeEnclosingPosition:
            IDBlockTextPositionMake(0, IDBlockTextAffinityDownstream)
                           resolvedAffinity:NULL],
        NSMakeRange(NSNotFound, 0)));
    XCTAssertFalse([snapshot caretNavigationResultForPoint:CGPointZero].found);
}

- (void)testTextKit2SnapshotVisualNavigationMatchesEstablishedBlockLayout {
    NSArray<NSString *> *fixtures = @[
        @"alpha beta",
        @"אבגדה six",
        @"abc אבג xyz",
        @"A👨‍👩‍👧‍👦B",
        @"first line wraps into another line",
    ];
    NSArray<NSNumber *> *directions = @[
        @(IDBlockLayoutDirectionLeft),
        @(IDBlockLayoutDirectionRight),
        @(IDBlockLayoutDirectionUp),
        @(IDBlockLayoutDirectionDown),
    ];
    for (NSString *text in fixtures) {
        IDBlockDocument *document = IDBlockTextTestDocument(@[text]);
        IDBlockStackCanvasView *stack = [self stackForDocument:document width:95.0];
        IDBlockLayout *layout = stack.blockLayouts.firstObject;
        id<IDBlockLayoutSnapshot> snapshot =
            [[[IDTextKit2BlockLayoutProvider alloc] initWithBlockLayout:layout]
                snapshotForDocumentRevision:document.documentRevision];
        for (NSUInteger offset = 0; offset <= text.length; offset += 1) {
            for (NSNumber *affinityValue in @[
                @(IDBlockTextAffinityUpstream),
                @(IDBlockTextAffinityDownstream),
            ]) {
                IDBlockTextAffinity affinity = affinityValue.integerValue;
                for (NSNumber *directionValue in directions) {
                    IDBlockLayoutDirection direction = directionValue.integerValue;
                    for (NSNumber *anchorValue in @[@0.0, @17.5, @63.0]) {
                        CGFloat anchor = anchorValue.doubleValue;
                        IDBlockCaretStop expected = [layout
                            caretStopFromLocalOffset:offset
                                             affinity:IDTestUIKitAffinity(affinity)
                                            direction:IDTestUIKitDirection(direction)
                                 anchorPositionOffset:anchor];
                        IDBlockCaretNavigationResult actual = [snapshot
                            caretNavigationResultFromPosition:
                                IDBlockTextPositionMake(offset, affinity)
                                                        direction:direction
                                             anchorPositionOffset:anchor];
                        XCTAssertEqual(actual.found, expected.found,
                            @"%@ offset=%lu affinity=%ld direction=%ld anchor=%g",
                            text,
                            (unsigned long)offset,
                            (long)affinity,
                            (long)direction,
                            anchor);
                        if (expected.found) {
                            XCTAssertEqual(actual.position.utf16Offset,
                                           expected.localOffset);
                            XCTAssertEqual(actual.position.affinity,
                                           IDTestNeutralAffinity(expected.affinity));
                            XCTAssertEqualWithAccuracy(actual.anchorPositionOffset,
                                                       expected.anchorPositionOffset,
                                                       0.001);
                        }
                    }
                }
            }
        }
    }
}

- (void)testTextKit2SnapshotVisualNavigationRejectsInvalidArguments {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"alpha"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:160.0];
    id<IDBlockLayoutSnapshot> snapshot =
        [[[IDTextKit2BlockLayoutProvider alloc]
            initWithBlockLayout:stack.blockLayouts.firstObject]
            snapshotForDocumentRevision:document.documentRevision];

    XCTAssertFalse([snapshot
        caretNavigationResultFromPosition:
            IDBlockTextPositionMake(99, IDBlockTextAffinityDownstream)
                                direction:IDBlockLayoutDirectionRight
                     anchorPositionOffset:0].found);
    XCTAssertFalse([snapshot
        caretNavigationResultFromPosition:
            IDBlockTextPositionMake(0, IDBlockTextAffinityDownstream)
                                direction:IDBlockLayoutDirectionRight
                     anchorPositionOffset:NAN].found);
    XCTAssertThrowsSpecificNamed(
        [snapshot
            caretNavigationResultFromPosition:
                IDBlockTextPositionMake(0, IDBlockTextAffinityDownstream)
                                    direction:(IDBlockLayoutDirection)99
                         anchorPositionOffset:0],
        NSException,
        NSInvalidArgumentException);
}


- (void)testSelectionSegmentCarriesItsBaselineAndRejectsANonFiniteOne {
    IDBlockSelectionSegment *measured = [[IDBlockSelectionSegment alloc]
        initWithLocalRange:NSMakeRange(4, 3)
                     rect:CGRectMake(12.5, 8.0, 40.0, 19.0)
           baselineOffset:14.25
             boundaryRole:IDBlockSelectionBoundaryRoleNone
       containsLocalStart:YES
         containsLocalEnd:YES
         writingDirection:IDBlockWritingDirectionLeftToRight
                 vertical:NO
         layoutGeneration:3];
    XCTAssertEqual(measured.baselineOffset, 14.25);

    IDBlockSelectionSegment *unknown = [[IDBlockSelectionSegment alloc]
        initWithLocalRange:NSMakeRange(4, 3)
                     rect:CGRectMake(12.5, 8.0, 40.0, 19.0)
             boundaryRole:IDBlockSelectionBoundaryRoleNone
       containsLocalStart:YES
         containsLocalEnd:YES
         writingDirection:IDBlockWritingDirectionLeftToRight
                 vertical:NO
         layoutGeneration:3];
    XCTAssertEqual(unknown.baselineOffset, 0.0);

    XCTAssertThrowsSpecificNamed(
        [[IDBlockSelectionSegment alloc] initWithLocalRange:NSMakeRange(0, 1)
                                                       rect:CGRectMake(0, 0, 10, 10)
                                             baselineOffset:INFINITY
                                               boundaryRole:IDBlockSelectionBoundaryRoleNone
                                         containsLocalStart:YES
                                           containsLocalEnd:YES
                                           writingDirection:IDBlockWritingDirectionLeftToRight
                                                   vertical:NO
                                           layoutGeneration:1],
        NSException, NSInvalidArgumentException);
}

@end
