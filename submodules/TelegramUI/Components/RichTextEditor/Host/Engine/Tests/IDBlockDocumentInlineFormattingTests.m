@import XCTest;

#import "IDBlockDocument.h"
#import "IDCanonicalTextStorageAdapterInternal.h"
#import "IDInlineTextFormatting.h"

static NSAttributedStringKey const IDUnrelatedAttribute =
    @"IDUnrelatedAttribute";

@interface IDRecordingInlineFormattingStorage :
    IDCanonicalTextStorageAdapter
@property(nonatomic) NSUInteger editedCallCount;
@property(nonatomic) NSTextStorageEditActions recordedEditedMask;
@property(nonatomic) NSRange recordedEditedRange;
@property(nonatomic) NSInteger recordedChangeInLength;
@end

@implementation IDRecordingInlineFormattingStorage

- (void)edited:(NSTextStorageEditActions)editedMask
          range:(NSRange)editedRange
 changeInLength:(NSInteger)delta {
    self.editedCallCount += 1;
    self.recordedEditedMask = editedMask;
    self.recordedEditedRange = editedRange;
    self.recordedChangeInLength = delta;
    [super edited:editedMask range:editedRange changeInLength:delta];
}

@end

@interface IDBlockDocumentInlineFormattingTests : XCTestCase
@end

@implementation IDBlockDocumentInlineFormattingTests

- (IDRecordingInlineFormattingStorage *)storage {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[
            [[NSAttributedString alloc]
                initWithString:@"ab"
                    attributes:@{
                        IDUnrelatedAttribute: @"first",
                        NSFontAttributeName: font,
                    }],
            [[NSAttributedString alloc]
                initWithString:@"cd"
                    attributes:@{
                        IDUnrelatedAttribute: @"second",
                        NSFontAttributeName: font,
                    }],
        ]
        defaultAttributes:@{
            IDUnrelatedAttribute: @"default",
            NSFontAttributeName: font,
        }];
    return [[IDRecordingInlineFormattingStorage alloc]
        initWithDocument:document];
}

- (IDBlockDocumentChange *)applyBoldToRange:(NSRange)range
                                   storage:
    (IDCanonicalTextStorageAdapter *)storage {
    return [storage
        id_transformTextAttributesInCanonicalRange:range
        usingBlock:^NSDictionary<NSAttributedStringKey, id> *(
            NSDictionary<NSAttributedStringKey, id> *attributes) {
            NSMutableDictionary<NSAttributedStringKey, id> *next =
                attributes.mutableCopy;
            next[IDInlineTextBoldAttributeName] = @YES;
            return next.copy;
        }];
}

- (void)testTransformSpansBlocksButNeverTouchesStructuralSeparator {
    IDRecordingInlineFormattingStorage *storage = [self storage];

    [self applyBoldToRange:NSMakeRange(1, 3) storage:storage];

    XCTAssertNotNil([storage attribute:IDInlineTextBoldAttributeName
                              atIndex:1
                       effectiveRange:NULL]);
    XCTAssertNil([storage attribute:IDInlineTextBoldAttributeName
                           atIndex:2
                    effectiveRange:NULL]);
    XCTAssertNotNil([storage attribute:IDInlineTextBoldAttributeName
                              atIndex:3
                       effectiveRange:NULL]);
}

- (void)testTransformPreservesUnrelatedAttributesAndBlockIdentifiers {
    IDRecordingInlineFormattingStorage *storage = [self storage];
    NSArray<NSUUID *> *identifiers =
        [storage.document.blocks valueForKey:@"identifier"];

    [self applyBoldToRange:NSMakeRange(1, 3) storage:storage];

    XCTAssertEqualObjects(
        [storage.document.blocks valueForKey:@"identifier"],
        identifiers);
    XCTAssertEqualObjects(
        [storage attribute:IDUnrelatedAttribute
                  atIndex:1
           effectiveRange:NULL],
        @"first");
    XCTAssertEqualObjects(
        [storage attribute:IDUnrelatedAttribute
                  atIndex:3
           effectiveRange:NULL],
        @"second");
}

- (void)testTransformPublishesOneAttributeEditAndOneDocumentChange {
    IDRecordingInlineFormattingStorage *storage = [self storage];
    __block NSUInteger changeCount = 0;
    __block IDBlockDocumentChange *publishedChange = nil;
    storage.documentChangeHandler =
        ^(IDBlockDocumentChange *change) {
            changeCount += 1;
            publishedChange = change;
        };

    IDBlockDocumentChange *returnedChange =
        [self applyBoldToRange:NSMakeRange(1, 3) storage:storage];

    XCTAssertEqual(storage.editedCallCount, 1U);
    XCTAssertEqual(storage.recordedEditedMask,
                   NSTextStorageEditedAttributes);
    XCTAssertTrue(NSEqualRanges(storage.recordedEditedRange,
                               NSMakeRange(1, 3)));
    XCTAssertEqual(storage.recordedChangeInLength, 0);
    XCTAssertEqual(changeCount, 1U);
    XCTAssertEqual(publishedChange, returnedChange);
    XCTAssertEqual(returnedChange.affectedBlockIdentifiers.count, 2U);
    XCTAssertEqual(storage.document.documentRevision, 1U);
}

- (void)testRestoreAttributedBlocksRestoresAttributesAndPreservesStructure {
    IDRecordingInlineFormattingStorage *storage = [self storage];
    NSArray<NSAttributedString *> *snapshot =
        [storage.document.blocks valueForKey:@"attributedText"];
    NSArray<NSUUID *> *identifiers =
        [storage.document.blocks valueForKey:@"identifier"];
    NSDictionary<NSAttributedStringKey, id> *separatorAttributes =
        storage.document.blocks[0].separatorAttributes;
    [self applyBoldToRange:NSMakeRange(0, storage.length)
                  storage:storage];

    IDBlockDocumentChange *change =
        [storage id_restoreAttributedBlocks:snapshot];

    XCTAssertNotNil(change);
    XCTAssertEqualObjects(
        [storage.document.blocks valueForKey:@"attributedText"],
        snapshot);
    XCTAssertEqualObjects(
        [storage.document.blocks valueForKey:@"identifier"],
        identifiers);
    XCTAssertEqualObjects(
        storage.document.blocks[0].separatorAttributes,
        separatorAttributes);
    XCTAssertEqualObjects(storage.string, @"ab\ncd");
}

- (void)testRestoreRejectsChangedStringsOrBlockCount {
    IDRecordingInlineFormattingStorage *storage = [self storage];
    NSArray<NSAttributedString *> *changedStrings = @[
        [[NSAttributedString alloc] initWithString:@"changed"],
        [[NSAttributedString alloc] initWithString:@"cd"],
    ];
    NSArray<NSAttributedString *> *changedCount = @[
        [[NSAttributedString alloc] initWithString:@"ab"],
    ];

    XCTAssertThrowsSpecificNamed(
        [storage id_restoreAttributedBlocks:changedStrings],
        NSException,
        NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed(
        [storage id_restoreAttributedBlocks:changedCount],
        NSException,
        NSInvalidArgumentException);
    XCTAssertEqual(storage.document.documentRevision, 0U);
}

- (void)testEmptyRangeDoesNotMutateTheDocument {
    IDRecordingInlineFormattingStorage *storage = [self storage];

    IDBlockDocumentChange *change =
        [self applyBoldToRange:NSMakeRange(1, 0) storage:storage];

    XCTAssertNil(change);
    XCTAssertEqual(storage.document.documentRevision, 0U);
    XCTAssertEqual(storage.editedCallCount, 0U);
    XCTAssertNil([storage attribute:IDInlineTextBoldAttributeName
                           atIndex:1
                    effectiveRange:NULL]);
}

@end
