@import XCTest;

#import "IDBlockDocument.h"
#import "IDCanonicalTextProjection.h"
#import "IDRichTextAnchor.h"
#import "IDRichTextPosition.h"
#import "IDRichTextRange.h"
#import "IDRichTextSelectionRect.h"

@interface IDRichTextPositionTests : XCTestCase
@end

@implementation IDRichTextPositionTests

- (IDBlockDocument *)documentWithBlocks:(NSArray<NSString *> *)strings {
    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc] initWithString:string]];
    }
    return [[IDBlockDocument alloc] initWithAttributedBlocks:blocks
                                           defaultAttributes:@{}];
}

- (IDRichTextAnchor *)anchorInDocument:(IDBlockDocument *)document
                       canonicalOffset:(NSUInteger)offset
                                  bias:(IDRichTextAnchorBias)bias {
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];
    IDCanonicalLocation *location = [projection locationForCanonicalOffset:offset];
    return [[IDRichTextAnchor alloc] initWithDocument:document
                                      blockIdentifier:location.blockIdentifier
                                           localOffset:location.localOffset
                                                  bias:bias];
}

- (NSUInteger)offsetForAnchor:(IDRichTextAnchor *)anchor {
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:anchor.document];
    return [anchor canonicalOffsetInProjection:projection];
}

- (void)testReplacementRebasesBeforeInsideAndAfterAnchorsByBias {
    IDBlockDocument *document = [self documentWithBlocks:@[@"abcdef"]];
    IDRichTextAnchor *before = [self anchorInDocument:document
                                      canonicalOffset:1
                                                 bias:IDRichTextAnchorBiasAfter];
    IDRichTextAnchor *insideBefore = [self anchorInDocument:document
                                            canonicalOffset:3
                                                       bias:IDRichTextAnchorBiasBefore];
    IDRichTextAnchor *insideAfter = [self anchorInDocument:document
                                           canonicalOffset:3
                                                      bias:IDRichTextAnchorBiasAfter];
    IDRichTextAnchor *after = [self anchorInDocument:document
                                     canonicalOffset:6
                                                bias:IDRichTextAnchorBiasBefore];

    [document replaceCanonicalRange:NSMakeRange(2, 3)
               withAttributedString:[[NSAttributedString alloc] initWithString:@"XY"]];

    XCTAssertEqual([self offsetForAnchor:before], 1U);
    XCTAssertEqual([self offsetForAnchor:insideBefore], 2U);
    XCTAssertEqual([self offsetForAnchor:insideAfter], 4U);
    XCTAssertEqual([self offsetForAnchor:after], 5U);
    XCTAssertEqual(insideBefore.bias, IDRichTextAnchorBiasBefore);
    XCTAssertEqual(insideAfter.bias, IDRichTextAnchorBiasAfter);
}

- (void)testNonemptyReplacementStartUsesBiasAndOldEndShiftsToReplacementEnd {
    IDBlockDocument *document = [self documentWithBlocks:@[@"abcdef"]];
    IDRichTextAnchor *startBefore = [self anchorInDocument:document
                                           canonicalOffset:2
                                                      bias:IDRichTextAnchorBiasBefore];
    IDRichTextAnchor *startAfter = [self anchorInDocument:document
                                          canonicalOffset:2
                                                     bias:IDRichTextAnchorBiasAfter];
    IDRichTextAnchor *oldEndBefore = [self anchorInDocument:document
                                            canonicalOffset:5
                                                       bias:IDRichTextAnchorBiasBefore];
    IDRichTextAnchor *oldEndAfter = [self anchorInDocument:document
                                           canonicalOffset:5
                                                      bias:IDRichTextAnchorBiasAfter];

    [document replaceCanonicalRange:NSMakeRange(2, 3)
               withAttributedString:[[NSAttributedString alloc] initWithString:@"XY"]];

    XCTAssertEqual([self offsetForAnchor:startBefore], 2U);
    XCTAssertEqual([self offsetForAnchor:startAfter], 4U);
    XCTAssertEqual([self offsetForAnchor:oldEndBefore], 4U);
    XCTAssertEqual([self offsetForAnchor:oldEndAfter], 4U);
}

- (void)testInsertionAtAnchorUsesBeforeAndAfterBias {
    IDBlockDocument *document = [self documentWithBlocks:@[@"abcd"]];
    IDRichTextAnchor *before = [self anchorInDocument:document
                                      canonicalOffset:2
                                                 bias:IDRichTextAnchorBiasBefore];
    IDRichTextAnchor *after = [self anchorInDocument:document
                                     canonicalOffset:2
                                                bias:IDRichTextAnchorBiasAfter];

    [document replaceCanonicalRange:NSMakeRange(2, 0)
               withAttributedString:[[NSAttributedString alloc] initWithString:@"XY"]];

    XCTAssertEqual([self offsetForAnchor:before], 2U);
    XCTAssertEqual([self offsetForAnchor:after], 4U);
}

- (void)testInsertionShiftsAnchorAfterInsertionPointRegardlessOfBias {
    IDBlockDocument *document = [self documentWithBlocks:@[@"abcd"]];
    IDRichTextAnchor *laterBefore = [self anchorInDocument:document
                                           canonicalOffset:4
                                                      bias:IDRichTextAnchorBiasBefore];
    IDRichTextAnchor *laterAfter = [self anchorInDocument:document
                                          canonicalOffset:4
                                                     bias:IDRichTextAnchorBiasAfter];

    [document replaceCanonicalRange:NSMakeRange(2, 0)
               withAttributedString:[[NSAttributedString alloc] initWithString:@"XY"]];

    XCTAssertEqual([self offsetForAnchor:laterBefore], 6U);
    XCTAssertEqual([self offsetForAnchor:laterAfter], 6U);
}

- (void)testSplitAndMergeRebaseBlockIdentityAndLocalOffset {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDRichTextAnchor *anchor = [self anchorInDocument:document
                                      canonicalOffset:4
                                                 bias:IDRichTextAnchorBiasAfter];
    NSUUID *originalIdentifier = anchor.blockIdentifier;

    [document replaceCanonicalRange:NSMakeRange(2, 0)
               withAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];

    XCTAssertEqual([self offsetForAnchor:anchor], 5U);
    XCTAssertNotEqualObjects(anchor.blockIdentifier, originalIdentifier);
    XCTAssertEqualObjects(anchor.blockIdentifier, document.blocks[1].identifier);
    XCTAssertEqual(anchor.localOffset, 2U);

    [document replaceCanonicalRange:NSMakeRange(2, 1)
               withAttributedString:[[NSAttributedString alloc] initWithString:@""]];

    XCTAssertEqual([self offsetForAnchor:anchor], 4U);
    XCTAssertEqualObjects(anchor.blockIdentifier, originalIdentifier);
    XCTAssertEqual(anchor.localOffset, 4U);
}

- (void)testSpanningReplacementRebasesAnchorsAcrossRemovedBlockIdentities {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDRichTextAnchor *insideBefore = [self anchorInDocument:document
                                            canonicalOffset:4
                                                       bias:IDRichTextAnchorBiasBefore];
    IDRichTextAnchor *insideAfter = [self anchorInDocument:document
                                           canonicalOffset:7
                                                      bias:IDRichTextAnchorBiasAfter];
    IDRichTextAnchor *later = [self anchorInDocument:document
                                     canonicalOffset:10
                                                bias:IDRichTextAnchorBiasBefore];

    [document replaceCanonicalRange:NSMakeRange(2, 6)
               withAttributedString:[[NSAttributedString alloc] initWithString:@"X\nY"]];

    XCTAssertEqual([self offsetForAnchor:insideBefore], 2U);
    XCTAssertEqual([self offsetForAnchor:insideAfter], 5U);
    XCTAssertEqual([self offsetForAnchor:later], 7U);
    XCTAssertEqualObjects(insideBefore.blockIdentifier, document.blocks[0].identifier);
    XCTAssertEqualObjects(insideAfter.blockIdentifier, document.blocks[1].identifier);
}

- (void)testStructuralBoundaryIdentityIsIndependentOfPositionAffinity {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha", @"beta"]];
    IDRichTextAnchor *beforeSeparator = [self anchorInDocument:document
                                               canonicalOffset:5
                                                          bias:IDRichTextAnchorBiasBefore];
    IDRichTextAnchor *afterSeparator = [self anchorInDocument:document
                                              canonicalOffset:6
                                                         bias:IDRichTextAnchorBiasAfter];
    IDRichTextPosition *upstream = [[IDRichTextPosition alloc]
        initWithAnchor:beforeSeparator
              affinity:UITextStorageDirectionBackward];
    IDRichTextPosition *downstream = [[IDRichTextPosition alloc]
        initWithAnchor:afterSeparator
              affinity:UITextStorageDirectionForward];

    XCTAssertEqualObjects(beforeSeparator.blockIdentifier, document.blocks[0].identifier);
    XCTAssertEqual(beforeSeparator.localOffset, 5U);
    XCTAssertEqualObjects(afterSeparator.blockIdentifier, document.blocks[1].identifier);
    XCTAssertEqual(afterSeparator.localOffset, 0U);
    XCTAssertEqual(upstream.affinity, UITextStorageDirectionBackward);
    XCTAssertEqual(downstream.affinity, UITextStorageDirectionForward);
    XCTAssertEqual([self offsetForAnchor:upstream.anchor], 5U);
    XCTAssertEqual([self offsetForAnchor:downstream.anchor], 6U);
}

- (void)testPositionCapturesRevisionAndCopiesAsOpaqueValue {
    IDBlockDocument *document = [self documentWithBlocks:@[@"abc"]];
    IDRichTextAnchor *anchor = [self anchorInDocument:document
                                      canonicalOffset:1
                                                 bias:IDRichTextAnchorBiasAfter];
    IDRichTextPosition *position = [[IDRichTextPosition alloc]
        initWithAnchor:anchor
              affinity:UITextStorageDirectionForward];
    [document replaceCanonicalRange:NSMakeRange(0, 0)
               withAttributedString:[[NSAttributedString alloc] initWithString:@"x"]];
    IDRichTextPosition *copy = [position copy];

    XCTAssertEqual(position.documentRevision, 0U);
    XCTAssertEqual(copy.documentRevision, position.documentRevision);
    XCTAssertEqualObjects(copy.anchor, position.anchor);
    XCTAssertEqual(copy.affinity, position.affinity);
}

- (void)testEquivalentPositionsAndRangesUseSemanticValueEquality {
    IDBlockDocument *document = [self documentWithBlocks:@[@"alpha beta"]];
    IDRichTextPosition *(^position)(NSUInteger, UITextStorageDirection) =
        ^IDRichTextPosition *(NSUInteger offset, UITextStorageDirection affinity) {
            IDRichTextAnchorBias bias = affinity == UITextStorageDirectionBackward
                ? IDRichTextAnchorBiasBefore
                : IDRichTextAnchorBiasAfter;
            return [[IDRichTextPosition alloc]
                initWithAnchor:[self anchorInDocument:document
                                      canonicalOffset:offset
                                                 bias:bias]
                      affinity:affinity];
        };
    IDRichTextPosition *firstStart = position(0, UITextStorageDirectionBackward);
    IDRichTextPosition *secondStart = position(0, UITextStorageDirectionBackward);
    IDRichTextPosition *firstEnd = position(5, UITextStorageDirectionForward);
    IDRichTextPosition *secondEnd = position(5, UITextStorageDirectionForward);
    IDRichTextRange *firstRange = [[IDRichTextRange alloc] initWithStart:firstStart
                                                                     end:firstEnd];
    IDRichTextRange *secondRange = [[IDRichTextRange alloc] initWithStart:secondStart
                                                                      end:secondEnd];

    XCTAssertEqualObjects(firstStart, secondStart);
    XCTAssertEqual(firstStart.hash, secondStart.hash);
    XCTAssertEqualObjects(firstRange, secondRange);
    XCTAssertEqual(firstRange.hash, secondRange.hash);
    XCTAssertEqualObjects(firstStart,
        position(0, UITextStorageDirectionForward));
    XCTAssertNotEqualObjects(firstRange,
        [[IDRichTextRange alloc] initWithStart:secondStart
                                           end:position(6, UITextStorageDirectionForward)]);
}

- (void)testPositionRejectsAnchorWhoseWeakDocumentExpired {
    __strong IDRichTextAnchor *anchor = nil;
    @autoreleasepool {
        IDBlockDocument *document = [self documentWithBlocks:@[@"abc"]];
        anchor = [self anchorInDocument:document
                        canonicalOffset:1
                                   bias:IDRichTextAnchorBiasAfter];
        XCTAssertNotNil(anchor.document);
    }

    XCTAssertNil(anchor.document);
    XCTAssertThrowsSpecificNamed(
        [[IDRichTextPosition alloc] initWithAnchor:anchor
                                          affinity:UITextStorageDirectionForward],
        NSException,
        NSInvalidArgumentException);
}

- (void)testDocumentTracksAnchorsWeakly {
    IDBlockDocument *document = [self documentWithBlocks:@[@"abc"]];
    __weak IDRichTextAnchor *weakAnchor = nil;
    @autoreleasepool {
        IDRichTextAnchor *anchor = [self anchorInDocument:document
                                          canonicalOffset:1
                                                     bias:IDRichTextAnchorBiasAfter];
        weakAnchor = anchor;
        XCTAssertNotNil(weakAnchor);
    }

    XCTAssertNil(weakAnchor);
}

- (void)testRangeRejectsCrossDocumentEndpoints {
    IDBlockDocument *firstDocument = [self documentWithBlocks:@[@"abc"]];
    IDBlockDocument *secondDocument = [self documentWithBlocks:@[@"abc"]];
    IDRichTextPosition *first = [[IDRichTextPosition alloc]
        initWithAnchor:[self anchorInDocument:firstDocument
                              canonicalOffset:0
                                         bias:IDRichTextAnchorBiasBefore]
              affinity:UITextStorageDirectionForward];
    IDRichTextPosition *second = [[IDRichTextPosition alloc]
        initWithAnchor:[self anchorInDocument:secondDocument
                              canonicalOffset:0
                                         bias:IDRichTextAnchorBiasBefore]
              affinity:UITextStorageDirectionForward];

    XCTAssertThrowsSpecificNamed([[IDRichTextRange alloc] initWithStart:first end:second],
                                 NSException,
                                 NSInvalidArgumentException);
}

- (void)testRangeOrdersReversedCanonicalEndpoints {
    IDBlockDocument *document = [self documentWithBlocks:@[@"abcd"]];
    IDRichTextPosition *later = [[IDRichTextPosition alloc]
        initWithAnchor:[self anchorInDocument:document
                              canonicalOffset:3
                                         bias:IDRichTextAnchorBiasAfter]
              affinity:UITextStorageDirectionForward];
    IDRichTextPosition *earlier = [[IDRichTextPosition alloc]
        initWithAnchor:[self anchorInDocument:document
                              canonicalOffset:1
                                         bias:IDRichTextAnchorBiasBefore]
              affinity:UITextStorageDirectionBackward];

    IDRichTextRange *range = [[IDRichTextRange alloc] initWithStart:later end:earlier];

    XCTAssertEqualObjects(range.start, earlier);
    XCTAssertEqualObjects(range.end, later);
}

- (void)testRangeOrdersEqualOffsetBeforeBiasAheadOfAfterBiasAcrossInsertion {
    IDBlockDocument *document = [self documentWithBlocks:@[@"abcd"]];
    IDRichTextPosition *after = [[IDRichTextPosition alloc]
        initWithAnchor:[self anchorInDocument:document
                              canonicalOffset:2
                                         bias:IDRichTextAnchorBiasAfter]
              affinity:UITextStorageDirectionForward];
    IDRichTextPosition *before = [[IDRichTextPosition alloc]
        initWithAnchor:[self anchorInDocument:document
                              canonicalOffset:2
                                         bias:IDRichTextAnchorBiasBefore]
              affinity:UITextStorageDirectionBackward];
    IDRichTextRange *range = [[IDRichTextRange alloc] initWithStart:after end:before];

    XCTAssertEqualObjects(range.start, before);
    XCTAssertEqualObjects(range.end, after);

    [document replaceCanonicalRange:NSMakeRange(2, 0)
               withAttributedString:[[NSAttributedString alloc] initWithString:@"XY"]];

    XCTAssertEqual([self offsetForAnchor:range.start.anchor], 2U);
    XCTAssertEqual([self offsetForAnchor:range.end.anchor], 4U);
}

- (void)testRangeReordersLiveEndpointsThatCrossInsideNonemptyReplacement {
    IDBlockDocument *document = [self documentWithBlocks:@[@"abcdef"]];
    IDRichTextPosition *startAfter = [[IDRichTextPosition alloc]
        initWithAnchor:[self anchorInDocument:document
                              canonicalOffset:2
                                         bias:IDRichTextAnchorBiasAfter]
              affinity:UITextStorageDirectionForward];
    IDRichTextPosition *endBefore = [[IDRichTextPosition alloc]
        initWithAnchor:[self anchorInDocument:document
                              canonicalOffset:3
                                         bias:IDRichTextAnchorBiasBefore]
              affinity:UITextStorageDirectionBackward];
    IDRichTextRange *range = [[IDRichTextRange alloc] initWithStart:startAfter end:endBefore];

    [document replaceCanonicalRange:NSMakeRange(1, 3)
               withAttributedString:[[NSAttributedString alloc] initWithString:@"XY"]];

    XCTAssertEqualObjects(range.start, endBefore);
    XCTAssertEqualObjects(range.end, startAfter);
    XCTAssertEqual([self offsetForAnchor:range.start.anchor], 1U);
    XCTAssertEqual([self offsetForAnchor:range.end.anchor], 3U);
    XCTAssertFalse(range.empty);
}

- (void)testRangeIsEmptyOnlyWhenLiveCanonicalEndpointsMatch {
    IDBlockDocument *document = [self documentWithBlocks:@[@"abcd"]];
    IDRichTextPosition *first = [[IDRichTextPosition alloc]
        initWithAnchor:[self anchorInDocument:document
                              canonicalOffset:1
                                         bias:IDRichTextAnchorBiasBefore]
              affinity:UITextStorageDirectionBackward];
    IDRichTextPosition *same = [[IDRichTextPosition alloc]
        initWithAnchor:[self anchorInDocument:document
                              canonicalOffset:1
                                         bias:IDRichTextAnchorBiasAfter]
              affinity:UITextStorageDirectionForward];
    IDRichTextPosition *later = [[IDRichTextPosition alloc]
        initWithAnchor:[self anchorInDocument:document
                              canonicalOffset:2
                                         bias:IDRichTextAnchorBiasAfter]
              affinity:UITextStorageDirectionForward];
    IDRichTextRange *empty = [[IDRichTextRange alloc] initWithStart:first end:same];
    IDRichTextRange *nonempty = [[IDRichTextRange alloc] initWithStart:first end:later];
    IDRichTextRange *copy = [nonempty copy];

    XCTAssertTrue(empty.empty);
    XCTAssertFalse(nonempty.empty);
    XCTAssertEqualObjects(copy.start, nonempty.start);
    XCTAssertEqualObjects(copy.end, nonempty.end);

    [document replaceCanonicalRange:NSMakeRange(1, 1)
               withAttributedString:[[NSAttributedString alloc] initWithString:@""]];
    XCTAssertTrue(nonempty.empty);
}

- (void)testSelectionRectReturnsEveryConcreteAccessorValue {
    CGRect rect = CGRectMake(11.5, 22.25, 33.75, 44.5);
    IDRichTextSelectionRect *selectionRect = [[IDRichTextSelectionRect alloc]
        initWithRect:rect
        containsStart:YES
        containsEnd:NO
        isVertical:YES
        writingDirection:NSWritingDirectionRightToLeft];

    XCTAssertTrue(CGRectEqualToRect(selectionRect.rect, rect));
    XCTAssertTrue(selectionRect.containsStart);
    XCTAssertFalse(selectionRect.containsEnd);
    XCTAssertTrue(selectionRect.isVertical);
    XCTAssertEqual(selectionRect.writingDirection, NSWritingDirectionRightToLeft);
}


- (void)testSelectionRectCarriesItsBaselineAndTheBaselineLessInitializerLeavesItUnknown {
    CGRect rect = CGRectMake(11.5, 22.25, 33.75, 44.5);
    IDRichTextSelectionRect *measured = [[IDRichTextSelectionRect alloc]
        initWithRect:rect
        baselineOffset:16.25
        containsStart:YES
        containsEnd:NO
        isVertical:NO
        writingDirection:NSWritingDirectionLeftToRight];
    XCTAssertEqual(measured.baselineOffset, 16.25);
    XCTAssertTrue(CGRectEqualToRect(measured.rect, rect));
    XCTAssertTrue(measured.containsStart);
    XCTAssertFalse(measured.containsEnd);

    IDRichTextSelectionRect *unknown = [[IDRichTextSelectionRect alloc]
        initWithRect:rect
        containsStart:NO
        containsEnd:YES
        isVertical:NO
        writingDirection:NSWritingDirectionLeftToRight];
    XCTAssertEqual(unknown.baselineOffset, 0.0,
                   @"0 is the value UIKit falls back from; anything else is placed literally");

    IDRichTextSelectionRect *nonFinite = [[IDRichTextSelectionRect alloc]
        initWithRect:rect
        baselineOffset:INFINITY
        containsStart:NO
        containsEnd:NO
        isVertical:NO
        writingDirection:NSWritingDirectionLeftToRight];
    XCTAssertEqual(nonFinite.baselineOffset, 0.0);
}

@end
