@import XCTest;

#import "IDBlockDocument.h"
#import "IDCanonicalTextProjection.h"

static NSAttributedStringKey const IDTestStyleAttribute = @"IDTestStyleAttribute";

@interface IDBlockDocumentTests : XCTestCase
@end

@implementation IDBlockDocumentTests

- (IDBlockDocument *)twoBlockDocument {
    return [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[
            [[NSAttributedString alloc] initWithString:@"alpha"
                                            attributes:@{IDTestStyleAttribute : @"first"}],
            [[NSAttributedString alloc] initWithString:@"beta"
                                            attributes:@{IDTestStyleAttribute : @"second"}],
        ]
        defaultAttributes:@{IDTestStyleAttribute : @"default"}];
}

- (void)testProjectionJoinsBlocksWithAttributedVirtualNewline {
    IDBlockDocument *document = [self twoBlockDocument];
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];

    XCTAssertEqualObjects(projection.string, @"alpha\nbeta");
    XCTAssertEqual(projection.string.length, 10U);
    XCTAssertEqual(projection.attributedString.length, projection.string.length);
    XCTAssertEqual(document.canonicalLength, projection.string.length);
    XCTAssertEqualObjects([projection.attributedString attribute:IDTestStyleAttribute
                                                       atIndex:5
                                                effectiveRange:NULL],
                          @"first");
    XCTAssertEqualObjects(document.blocks[0].separatorAttributes[IDTestStyleAttribute],
                          @"first");
}

- (void)testProjectionMapsBothSidesOfStructuralSeparator {
    IDBlockDocument *document = [self twoBlockDocument];
    IDBlock *first = document.blocks[0];
    IDBlock *second = document.blocks[1];
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];

    IDCanonicalLocation *text = [projection locationForCanonicalOffset:2];
    XCTAssertEqualObjects(text.blockIdentifier, first.identifier);
    XCTAssertEqual(text.localOffset, 2U);
    XCTAssertEqual(text.boundarySide, IDCanonicalBoundarySideText);

    IDCanonicalLocation *before = [projection locationForCanonicalOffset:5];
    XCTAssertEqualObjects(before.blockIdentifier, first.identifier);
    XCTAssertEqual(before.localOffset, 5U);
    XCTAssertEqual(before.boundarySide, IDCanonicalBoundarySideBeforeSeparator);

    IDCanonicalLocation *after = [projection locationForCanonicalOffset:6];
    XCTAssertEqualObjects(after.blockIdentifier, second.identifier);
    XCTAssertEqual(after.localOffset, 0U);
    XCTAssertEqual(after.boundarySide, IDCanonicalBoundarySideAfterSeparator);

    IDCanonicalLocation *end = [projection locationForCanonicalOffset:10];
    XCTAssertEqualObjects(end.blockIdentifier, second.identifier);
    XCTAssertEqual(end.localOffset, 4U);
    XCTAssertEqual(end.boundarySide, IDCanonicalBoundarySideText);
    XCTAssertNil([projection locationForCanonicalOffset:11]);

    XCTAssertEqual([projection canonicalOffsetForBlockIdentifier:first.identifier
                                                       localOffset:5],
                   5U);
    XCTAssertEqual([projection canonicalOffsetForBlockIdentifier:second.identifier
                                                       localOffset:0],
                   6U);
}

- (void)testInsertingSeparatorSplitsBlockAndRetainsLeftIdentity {
    IDBlockDocument *document = [self twoBlockDocument];
    NSUUID *firstIdentifier = document.blocks[0].identifier;
    NSUUID *secondIdentifier = document.blocks[1].identifier;

    IDBlockDocumentChange *change = [document
        replaceCanonicalRange:NSMakeRange(2, 0)
        withAttributedString:[[NSAttributedString alloc] initWithString:@"\n"
                                                              attributes:@{
                                                                  IDTestStyleAttribute : @"split"
                                                              }]];
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];

    XCTAssertEqualObjects(projection.string, @"al\npha\nbeta");
    XCTAssertEqual(document.blocks.count, 3U);
    XCTAssertEqualObjects(document.blocks[0].identifier, firstIdentifier);
    XCTAssertNotEqualObjects(document.blocks[1].identifier, firstIdentifier);
    XCTAssertEqualObjects(document.blocks[2].identifier, secondIdentifier);
    XCTAssertEqualObjects(document.blocks[0].separatorAttributes[IDTestStyleAttribute],
                          @"split");
    XCTAssertEqualObjects(document.blocks[1].separatorAttributes[IDTestStyleAttribute],
                          @"first");
    XCTAssertEqual(change.replacedCanonicalRange.location, 2U);
    XCTAssertEqual(change.replacedCanonicalRange.length, 0U);
    XCTAssertEqual(change.replacementLength, 1U);
    XCTAssertTrue([change.affectedBlockIdentifiers containsObject:firstIdentifier]);
    XCTAssertTrue([change.affectedBlockIdentifiers containsObject:document.blocks[1].identifier]);
    XCTAssertFalse([change.affectedBlockIdentifiers containsObject:secondIdentifier]);
    XCTAssertEqual(document.documentRevision, 1U);
}

- (void)testDeletingSeparatorMergesIntoPrecedingIdentity {
    IDBlockDocument *document = [self twoBlockDocument];
    NSUUID *firstIdentifier = document.blocks[0].identifier;
    NSUUID *secondIdentifier = document.blocks[1].identifier;
    [document replaceCanonicalRange:NSMakeRange(2, 0)
               withAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
    NSUUID *splitRightIdentifier = document.blocks[1].identifier;

    IDBlockDocumentChange *change =
        [document replaceCanonicalRange:NSMakeRange(2, 1)
                   withAttributedString:[[NSAttributedString alloc] initWithString:@""]];
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];

    XCTAssertEqualObjects(projection.string, @"alpha\nbeta");
    XCTAssertEqual(document.blocks.count, 2U);
    XCTAssertEqualObjects(document.blocks[0].identifier, firstIdentifier);
    XCTAssertEqualObjects(document.blocks[1].identifier, secondIdentifier);
    XCTAssertTrue([change.affectedBlockIdentifiers containsObject:firstIdentifier]);
    XCTAssertTrue([change.affectedBlockIdentifiers containsObject:splitRightIdentifier]);
    XCTAssertFalse([change.affectedBlockIdentifiers containsObject:secondIdentifier]);
    XCTAssertEqual(document.documentRevision, 2U);
}

- (void)testSpanningReplacementUsesPrefixIdentityAndNewAdditionalIdentity {
    IDBlockDocument *document = [self twoBlockDocument];
    NSUUID *firstIdentifier = document.blocks[0].identifier;
    NSUUID *secondIdentifier = document.blocks[1].identifier;

    IDBlockDocumentChange *change = [document
        replaceCanonicalRange:NSMakeRange(2, 5)
        withAttributedString:[[NSAttributedString alloc] initWithString:@"X\nY"
                                                              attributes:@{
                                                                  IDTestStyleAttribute : @"replacement"
                                                              }]];
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];

    XCTAssertEqualObjects(projection.string, @"alX\nYeta");
    XCTAssertEqual(document.blocks.count, 2U);
    XCTAssertEqualObjects(document.blocks[0].identifier, firstIdentifier);
    XCTAssertNotEqualObjects(document.blocks[1].identifier, secondIdentifier);
    XCTAssertNotEqualObjects(document.blocks[1].identifier, firstIdentifier);
    XCTAssertEqualObjects([projection.attributedString attribute:IDTestStyleAttribute
                                                       atIndex:2
                                                effectiveRange:NULL],
                          @"replacement");
    XCTAssertEqualObjects([projection.attributedString attribute:IDTestStyleAttribute
                                                       atIndex:5
                                                effectiveRange:NULL],
                          @"second");
    XCTAssertEqual(change.replacedCanonicalRange.location, 2U);
    XCTAssertEqual(change.replacedCanonicalRange.length, 5U);
    XCTAssertEqual(change.replacementLength, 3U);
    XCTAssertTrue([change.affectedBlockIdentifiers containsObject:firstIdentifier]);
    XCTAssertTrue([change.affectedBlockIdentifiers containsObject:secondIdentifier]);
    XCTAssertTrue([change.affectedBlockIdentifiers containsObject:document.blocks[1].identifier]);
    XCTAssertEqual(document.documentRevision, 1U);
}

- (void)testDeletingWholeDocumentLeavesOneEmptyBlock {
    IDBlockDocument *document = [self twoBlockDocument];
    NSUUID *firstIdentifier = document.blocks[0].identifier;

    [document replaceCanonicalRange:NSMakeRange(0, document.canonicalLength)
               withAttributedString:[[NSAttributedString alloc] initWithString:@""]];

    XCTAssertEqual(document.blocks.count, 1U);
    XCTAssertEqualObjects(document.blocks[0].identifier, firstIdentifier);
    XCTAssertEqual(document.blocks[0].attributedText.length, 0U);
    XCTAssertEqual(document.canonicalLength, 0U);
    XCTAssertEqualObjects([[[IDCanonicalTextProjection alloc] initWithDocument:document] string],
                          @"");
}

- (void)testCanonicalOffsetsAreNSStringUTF16Offsets {
    NSString *text = @"a👨‍👩‍👧‍👦b";
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[[[NSAttributedString alloc] initWithString:text]]
        defaultAttributes:@{}];
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];

    XCTAssertEqual(document.canonicalLength, text.length);
    XCTAssertEqual(projection.string.length, text.length);
    XCTAssertEqual([projection locationForCanonicalOffset:text.length - 1].localOffset,
                   text.length - 1);
    XCTAssertEqual([projection canonicalOffsetForBlockIdentifier:document.blocks[0].identifier
                                                       localOffset:text.length],
                   text.length);
}

- (void)testAttributeTransactionUpdatesTextAndSeparatorOnceWithoutChangingIdentity {
    IDBlockDocument *document = [self twoBlockDocument];
    NSArray<NSUUID *> *identifiers = [document.blocks valueForKey:@"identifier"];

    [document setAttributes:@{IDTestStyleAttribute : @"updated"}
             canonicalRange:NSMakeRange(4, 3)];
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];

    XCTAssertEqual(document.documentRevision, 1U);
    XCTAssertEqualObjects([document.blocks valueForKey:@"identifier"], identifiers);
    for (NSUInteger offset = 4; offset < 7; offset += 1) {
        XCTAssertEqualObjects([projection.attributedString attribute:IDTestStyleAttribute
                                                           atIndex:offset
                                                    effectiveRange:NULL],
                              @"updated");
    }
    XCTAssertEqualObjects(document.blocks[0].separatorAttributes[IDTestStyleAttribute],
                          @"updated");
}

- (void)testInvalidCanonicalRangesThrowRangeException {
    IDBlockDocument *document = [self twoBlockDocument];
    NSAttributedString *replacement = [[NSAttributedString alloc] initWithString:@"x"];

    XCTAssertThrowsSpecificNamed([document replaceCanonicalRange:NSMakeRange(11, 0)
                                            withAttributedString:replacement],
                                 NSException,
                                 NSRangeException);
    XCTAssertThrowsSpecificNamed([document replaceCanonicalRange:NSMakeRange(9, 2)
                                            withAttributedString:replacement],
                                 NSException,
                                 NSRangeException);
    XCTAssertThrowsSpecificNamed([document setAttributes:@{}
                                        canonicalRange:NSMakeRange(NSUIntegerMax, 2)],
                                 NSException,
                                 NSRangeException);
    XCTAssertEqual(document.documentRevision, 0U);
}

- (void)testInitializerRejectsStructuralNewlineInsideBlock {
    NSException *caughtException = nil;
    @try {
        __unused IDBlockDocument *document = [[IDBlockDocument alloc]
            initWithAttributedBlocks:@[
                [[NSAttributedString alloc] initWithString:@"alpha\nbeta"]
            ]
            defaultAttributes:@{}];
    } @catch (NSException *exception) {
        caughtException = exception;
    }

    XCTAssertEqualObjects(caughtException.name, NSInvalidArgumentException);
    XCTAssertEqualObjects(
        caughtException.reason,
        @"IDBlockDocument attributed blocks must not contain U+000A structural newlines.");
}

@end
