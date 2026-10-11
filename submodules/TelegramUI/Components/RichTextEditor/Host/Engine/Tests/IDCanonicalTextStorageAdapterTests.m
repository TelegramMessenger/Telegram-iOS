@import XCTest;

#import <objc/runtime.h>

#import "IDBlockDocument.h"
#import "IDCanonicalTextProjection.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDRichTextAnchor.h"

static NSAttributedStringKey const IDStyleAttribute = @"IDStyleAttribute";

@interface NSTextStorage (IDCanonicalTextStorageCoordinationTesting)
- (void)coordinateReading:(void (NS_NOESCAPE ^)(void))block;
- (void)coordinateEditing:(void (NS_NOESCAPE ^)(void))block;
@end

@interface IDRecordingCanonicalTextStorageAdapter : IDCanonicalTextStorageAdapter
@property(nonatomic) NSUInteger editedCallCount;
@property(nonatomic) NSTextStorageEditActions recordedEditedMask;
@property(nonatomic) NSRange recordedEditedRange;
@property(nonatomic) NSInteger recordedChangeInLength;
@end

@implementation IDRecordingCanonicalTextStorageAdapter

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

@interface IDCanonicalTextStorageAdapterTests : XCTestCase
@end

@implementation IDCanonicalTextStorageAdapterTests

- (NSAttributedString *)text:(NSString *)string style:(NSString *)style {
    return [[NSAttributedString alloc] initWithString:string
                                           attributes:@{IDStyleAttribute: style}];
}

- (IDCanonicalTextStorageAdapter *)twoBlockStorage {
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[
            [self text:@"alpha" style:@"leading"],
            [self text:@"beta" style:@"trailing"],
        ]
        defaultAttributes:@{IDStyleAttribute: @"default"}];
    return [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];
}

- (void)testIsRealTextStoragePrimitiveWithCanonicalStringAttributesAndInheritedCoordination {
    IDCanonicalTextStorageAdapter *storage = [self twoBlockStorage];

    XCTAssertTrue([storage isKindOfClass:NSTextStorage.class]);
    XCTAssertEqual(class_getSuperclass(IDCanonicalTextStorageAdapter.class), NSTextStorage.class);
    XCTAssertEqualObjects(storage.string, @"alpha\nbeta");
    XCTAssertEqualObjects(storage.projection.string, storage.string);

    __block BOOL readRan = NO;
    [storage coordinateReading:^{
        readRan = YES;
        NSRange effectiveRange = NSMakeRange(NSNotFound, 0);
        NSDictionary<NSAttributedStringKey, id> *attributes =
            [storage attributesAtIndex:5 effectiveRange:&effectiveRange];
        XCTAssertEqualObjects(attributes[IDStyleAttribute], @"leading");
        XCTAssertTrue(NSEqualRanges(effectiveRange, NSMakeRange(0, 6)));

        attributes = [storage attributesAtIndex:6 effectiveRange:&effectiveRange];
        XCTAssertEqualObjects(attributes[IDStyleAttribute], @"trailing");
        XCTAssertTrue(NSEqualRanges(effectiveRange, NSMakeRange(6, 4)));
    }];
    XCTAssertTrue(readRan);

    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(IDCanonicalTextStorageAdapter.class, &methodCount);
    BOOL overridesCoordinateReading = NO;
    BOOL overridesCoordinateEditing = NO;
    for (unsigned int index = 0; index < methodCount; index += 1) {
        SEL selector = method_getName(methods[index]);
        overridesCoordinateReading |= selector == @selector(coordinateReading:);
        overridesCoordinateEditing |= selector == @selector(coordinateEditing:);
    }
    free(methods);
    XCTAssertFalse(overridesCoordinateReading);
    XCTAssertFalse(overridesCoordinateEditing);
}

- (void)testPlainStringReplacementUsesDeterministicCanonicalInsertionAttributesAndSplitsBlocks {
    IDCanonicalTextStorageAdapter *storage = [self twoBlockStorage];
    IDCanonicalTextProjection *oldProjection = storage.projection;

    __block NSUInteger notificationCount = 0;
    __block NSTextStorageEditActions editedMask = 0;
    __block NSRange editedRange = NSMakeRange(NSNotFound, 0);
    __block NSInteger changeInLength = NSIntegerMax;
    id observer = [NSNotificationCenter.defaultCenter
        addObserverForName:NSTextStorageDidProcessEditingNotification
                    object:storage
                     queue:nil
                usingBlock:^(NSNotification *notification) {
                    notificationCount += 1;
                    editedMask = storage.editedMask;
                    editedRange = storage.editedRange;
                    changeInLength = storage.changeInLength;
                }];

    [storage replaceCharactersInRange:NSMakeRange(2, 0) withString:@"\nZ"];

    [NSNotificationCenter.defaultCenter removeObserver:observer];
    XCTAssertEqualObjects(storage.string, @"al\nZpha\nbeta");
    XCTAssertEqual(storage.document.blocks.count, 3U);
    XCTAssertEqualObjects(storage.document.blocks[0].attributedText.string, @"al");
    XCTAssertEqualObjects(storage.document.blocks[1].attributedText.string, @"Zpha");
    XCTAssertEqualObjects(storage.document.blocks[2].attributedText.string, @"beta");
    XCTAssertEqualObjects([storage attributesAtIndex:2 effectiveRange:NULL][IDStyleAttribute],
                          @"leading");
    XCTAssertEqualObjects([storage attributesAtIndex:3 effectiveRange:NULL][IDStyleAttribute],
                          @"leading");
    XCTAssertNotEqual(storage.projection, oldProjection);
    XCTAssertEqual(notificationCount, 1U);
    XCTAssertEqual(editedMask,
                   NSTextStorageEditedCharacters | NSTextStorageEditedAttributes);
    XCTAssertTrue(NSEqualRanges(editedRange, NSMakeRange(2, 2)));
    XCTAssertEqual(changeInLength, 2);
}

- (void)testAttributedReplacementPreservesEverySuppliedAttributeInOneCoordinatedEdit {
    IDCanonicalTextStorageAdapter *storage = [self twoBlockStorage];
    NSMutableAttributedString *replacement = [[NSMutableAttributedString alloc]
        initWithString:@"X\nY"
            attributes:@{IDStyleAttribute: @"replacement-left"}];
    [replacement setAttributes:@{IDStyleAttribute: @"replacement-separator"}
                         range:NSMakeRange(1, 1)];
    [replacement setAttributes:@{IDStyleAttribute: @"replacement-right"}
                         range:NSMakeRange(2, 1)];

    __block NSUInteger notificationCount = 0;
    id observer = [NSNotificationCenter.defaultCenter
        addObserverForName:NSTextStorageDidProcessEditingNotification
                    object:storage
                     queue:nil
                usingBlock:^(NSNotification *notification) {
                    notificationCount += 1;
                }];
    __block BOOL editRan = NO;
    [storage coordinateEditing:^{
        editRan = YES;
        [storage replaceCharactersInRange:NSMakeRange(0, 5)
                     withAttributedString:replacement];
    }];

    [NSNotificationCenter.defaultCenter removeObserver:observer];
    XCTAssertTrue(editRan);
    XCTAssertEqual(notificationCount, 1U);
    XCTAssertEqualObjects(storage.string, @"X\nY\nbeta");
    XCTAssertEqual(storage.document.blocks.count, 3U);
    XCTAssertEqualObjects([storage attributesAtIndex:0 effectiveRange:NULL][IDStyleAttribute],
                          @"replacement-left");
    XCTAssertEqualObjects([storage attributesAtIndex:1 effectiveRange:NULL][IDStyleAttribute],
                          @"replacement-separator");
    XCTAssertEqualObjects([storage attributesAtIndex:2 effectiveRange:NULL][IDStyleAttribute],
                          @"replacement-right");
}

- (void)testSetAttributesUpdatesCanonicalTextAndSeparatorWithAttributeOnlyNotification {
    IDCanonicalTextStorageAdapter *storage = [self twoBlockStorage];
    NSDictionary<NSAttributedStringKey, id> *attributes =
        @{IDStyleAttribute: @"restyled"};
    __block NSUInteger notificationCount = 0;
    __block NSTextStorageEditActions editedMask = 0;
    __block NSRange editedRange = NSMakeRange(NSNotFound, 0);
    __block NSInteger changeInLength = NSIntegerMax;
    id observer = [NSNotificationCenter.defaultCenter
        addObserverForName:NSTextStorageDidProcessEditingNotification
                    object:storage
                     queue:nil
                usingBlock:^(NSNotification *notification) {
                    notificationCount += 1;
                    editedMask = storage.editedMask;
                    editedRange = storage.editedRange;
                    changeInLength = storage.changeInLength;
                }];

    [storage setAttributes:attributes range:NSMakeRange(4, 3)];

    [NSNotificationCenter.defaultCenter removeObserver:observer];
    XCTAssertEqualObjects(storage.string, @"alpha\nbeta");
    XCTAssertEqualObjects([storage attributesAtIndex:4 effectiveRange:NULL][IDStyleAttribute],
                          @"restyled");
    XCTAssertEqualObjects([storage attributesAtIndex:5 effectiveRange:NULL][IDStyleAttribute],
                          @"restyled");
    XCTAssertEqualObjects([storage attributesAtIndex:6 effectiveRange:NULL][IDStyleAttribute],
                          @"restyled");
    XCTAssertEqual(notificationCount, 1U);
    XCTAssertEqual(editedMask, NSTextStorageEditedAttributes);
    XCTAssertTrue(NSEqualRanges(editedRange, NSMakeRange(4, 3)));
    XCTAssertEqual(changeInLength, 0);
}

- (void)testDeletingStructuralNewlineMergesBlocksWithOneExactCompletedNotification {
    IDCanonicalTextStorageAdapter *baseStorage = [self twoBlockStorage];
    IDRecordingCanonicalTextStorageAdapter *storage =
        [[IDRecordingCanonicalTextStorageAdapter alloc]
            initWithDocument:baseStorage.document];
    __block NSUInteger notificationCount = 0;
    __block NSTextStorageEditActions editedMask = 0;
    __block NSRange editedRange = NSMakeRange(NSNotFound, 0);
    __block NSInteger changeInLength = NSIntegerMax;
    __block NSRange publishedEditedRange = NSMakeRange(NSNotFound, 0);
    __block NSInteger publishedChangeInLength = NSIntegerMax;
    id observer = [NSNotificationCenter.defaultCenter
        addObserverForName:NSTextStorageDidProcessEditingNotification
                    object:storage
                     queue:nil
                usingBlock:^(NSNotification *notification) {
                    notificationCount += 1;
                    editedMask = storage.recordedEditedMask;
                    editedRange = storage.recordedEditedRange;
                    changeInLength = storage.recordedChangeInLength;
                    publishedEditedRange = storage.editedRange;
                    publishedChangeInLength = storage.changeInLength;
                }];

    [storage replaceCharactersInRange:NSMakeRange(5, 1) withString:@""];

    [NSNotificationCenter.defaultCenter removeObserver:observer];
    XCTAssertEqual(notificationCount, 1U);
    XCTAssertEqual(storage.editedCallCount, 1U);
    XCTAssertEqual(editedMask,
                   NSTextStorageEditedCharacters | NSTextStorageEditedAttributes);
    XCTAssertEqual(editedRange.location, 5U);
    XCTAssertEqual(editedRange.length, 1U);
    XCTAssertEqual(changeInLength, -1);
    XCTAssertTrue(NSEqualRanges(publishedEditedRange, NSMakeRange(5, 0)));
    XCTAssertEqual(publishedChangeInLength, -1);
    XCTAssertEqualObjects(storage.string, @"alphabeta");
    XCTAssertEqual(storage.document.blocks.count, 1U);
    XCTAssertEqualObjects(storage.document.blocks[0].attributedText.string, @"alphabeta");
}

- (void)testPlainInsertionIntoEmptyDocumentUsesDocumentDefaultAttributes {
    NSDictionary<NSAttributedStringKey, id> *defaultAttributes =
        @{IDStyleAttribute: @"default"};
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[[[NSAttributedString alloc] initWithString:@""]]
        defaultAttributes:defaultAttributes];
    IDCanonicalTextStorageAdapter *storage =
        [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];

    [storage replaceCharactersInRange:NSMakeRange(0, 0) withString:@"A"];

    XCTAssertEqualObjects(storage.string, @"A");
    XCTAssertEqualObjects([storage attributesAtIndex:0 effectiveRange:NULL][IDStyleAttribute],
                          @"default");
    XCTAssertNotNil([storage attributesAtIndex:0 effectiveRange:NULL][NSFontAttributeName]);
}

- (void)testPlainInsertionAtAdjacentRichRunBoundaryUsesPrecedingSurvivingRun {
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
        initWithString:@"AB"
            attributes:@{IDStyleAttribute: @"left"}];
    [text setAttributes:@{IDStyleAttribute: @"right"} range:NSMakeRange(1, 1)];
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[text]
               defaultAttributes:@{IDStyleAttribute: @"default"}];
    IDCanonicalTextStorageAdapter *storage =
        [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];

    [storage replaceCharactersInRange:NSMakeRange(1, 0) withString:@"X"];

    XCTAssertEqualObjects(storage.string, @"AXB");
    XCTAssertEqualObjects([storage attribute:IDStyleAttribute atIndex:1 effectiveRange:NULL],
                          @"left");
}

- (void)testPlainReplacementAtDocumentStartUsesFollowingSurvivingRunNotReplacedText {
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
        initWithString:@"AB"
            attributes:@{IDStyleAttribute: @"replaced"}];
    [text setAttributes:@{IDStyleAttribute: @"survivor"} range:NSMakeRange(1, 1)];
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[text]
               defaultAttributes:@{IDStyleAttribute: @"default"}];
    IDCanonicalTextStorageAdapter *storage =
        [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];

    [storage replaceCharactersInRange:NSMakeRange(0, 1) withString:@"X"];

    XCTAssertEqualObjects(storage.string, @"XB");
    XCTAssertEqualObjects([storage attribute:IDStyleAttribute atIndex:0 effectiveRange:NULL],
                          @"survivor");
}

- (void)testPlainWholeDocumentReplacementUsesDefaultsInsteadOfReplacedText {
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[[self text:@"old" style:@"replaced"]]
               defaultAttributes:@{IDStyleAttribute: @"default"}];
    IDCanonicalTextStorageAdapter *storage =
        [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];

    [storage replaceCharactersInRange:NSMakeRange(0, storage.length) withString:@"new"];

    XCTAssertEqualObjects(storage.string, @"new");
    XCTAssertEqualObjects([storage attribute:IDStyleAttribute atIndex:0 effectiveRange:NULL],
                          @"default");
}

- (void)testPlainInsertionAtStructuralBlockBoundaryUsesPrecedingSeparatorRun {
    IDCanonicalTextStorageAdapter *storage = [self twoBlockStorage];

    [storage replaceCharactersInRange:NSMakeRange(6, 0) withString:@"X"];

    XCTAssertEqualObjects(storage.string, @"alpha\nXbeta");
    XCTAssertEqualObjects([storage attribute:IDStyleAttribute atIndex:6 effectiveRange:NULL],
                          @"leading");
    XCTAssertEqualObjects([storage attribute:IDStyleAttribute atIndex:7 effectiveRange:NULL],
                          @"trailing");
}

- (void)testCanonicalProjectionAndStorageRejectNilDocument {
    IDBlockDocument *missingDocument = nil;
    XCTAssertThrowsSpecificNamed([[IDCanonicalTextProjection alloc]
                                     initWithDocument:missingDocument],
                                 NSException,
                                 NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed([[IDCanonicalTextStorageAdapter alloc]
                                     initWithDocument:missingDocument],
                                 NSException,
                                 NSInvalidArgumentException);
}

- (void)testInvalidEditPublishesNothingAndLeavesLiveAnchorForFollowingValidNotification {
    IDCanonicalTextStorageAdapter *storage = [self twoBlockStorage];
    IDBlock *first = storage.document.blocks.firstObject;
    IDRichTextAnchor *anchor = [[IDRichTextAnchor alloc]
        initWithDocument:storage.document
         blockIdentifier:first.identifier
              localOffset:2
                     bias:IDRichTextAnchorBiasAfter];
    __block NSUInteger notificationCount = 0;
    id observer = [NSNotificationCenter.defaultCenter
        addObserverForName:NSTextStorageDidProcessEditingNotification
                    object:storage
                     queue:nil
                usingBlock:^(__unused NSNotification *notification) {
                    notificationCount += 1;
                }];

    XCTAssertThrowsSpecificNamed([storage replaceCharactersInRange:NSMakeRange(99, 1)
                                                          withString:@"X"],
                                 NSException,
                                 NSRangeException);
    XCTAssertEqual(notificationCount, 0U);
    XCTAssertEqual(anchor.localOffset, 2U);
    XCTAssertEqualObjects(anchor.blockIdentifier, first.identifier);

    [storage replaceCharactersInRange:NSMakeRange(0, 0) withString:@"XY"];
    [NSNotificationCenter.defaultCenter removeObserver:observer];
    XCTAssertEqual(notificationCount, 1U);
    XCTAssertEqual(anchor.localOffset, 4U);
    XCTAssertEqualObjects(anchor.blockIdentifier, first.identifier);
}

@end
