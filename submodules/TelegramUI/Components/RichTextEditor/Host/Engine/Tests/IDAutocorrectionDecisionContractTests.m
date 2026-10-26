@import XCTest;

#import "IDAutocorrectionDecisionTestSupport.h"
#import "IDBlockDocument.h"
#import "IDBlockTextView.h"
#import "IDCanonicalTextProjection.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDInlineTextFormatting.h"
#import "IDRichTextAnchor.h"
#import "IDRichTextPosition.h"

static NSDictionary<NSString *, id> *IDValidStatusDictionary(void) {
    return @{
        @"schema": @1,
        @"scenario": @"autocorrection-interior-accept-space",
        @"canonical": @"A quiet adress lantern waits.\nSecond block stays unchanged.",
        @"blocks": @[@"A quiet adress lantern waits.", @"Second block stays unchanged."],
        @"selection": @{@"location": @14, @"length": @0},
        @"affinity": @"forward",
        @"markedRange": @{@"location": @(NSNotFound), @"length": @0},
        @"structuralNewlineLocations": @[@29],
        @"checkingRanges": @[@{@"location": @8, @"length": @6}],
        @"candidateDescriptor": @{
            @"candidate": @"address", @"original": @"adress", @"actionable": @YES,
        },
        @"mutationTrace": @[],
        @"eventTrace": @[],
        @"keyboardState": @{
            @"visible": @YES, @"locale": @"en_US", @"learnedOriginal": @NO,
        },
        @"correctionGeometry": @{
            @"x": @10, @"y": @20, @"width": @30, @"height": @22,
        },
        @"coordinateSpaceIdentity": @"document-interaction-container",
        @"documentRevision": @1,
        @"textEpoch": @1,
        @"selectionEpoch": @1,
        @"checkingEpoch": @1,
        @"firstResponder": @YES,
    };
}

static NSString *IDJSONString(NSDictionary<NSString *, id> *dictionary) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary
                                                   options:NSJSONWritingSortedKeys
                                                     error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@interface IDAutocorrectionDecisionContractTests : XCTestCase
@end

@implementation IDAutocorrectionDecisionContractTests

- (void)testAutocorrectionReplacementKeepsActiveSemanticTraits {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
        attributedBlocks:@[
            [[NSAttributedString alloc] initWithString:@""],
        ]];
    [view toggleInlineTextTrait:IDInlineTextTraitBold];
    [view insertText:@"adress"];
    UITextPosition *start = [view positionFromPosition:view.beginningOfDocument
                                               offset:0];
    UITextPosition *end = [view positionFromPosition:start offset:6];

    [view replaceRange:[view textRangeFromPosition:start toPosition:end]
              withText:@"address"];

    XCTAssertEqualObjects(view.text, @"address");
    for (NSUInteger index = 0; index < 7; index++) {
        XCTAssertTrue([[view.attributedBlocks[0]
            attribute:IDInlineTextBoldAttributeName
              atIndex:index
       effectiveRange:NULL] boolValue]);
    }
}

- (void)testDecisionMatrixContainsTwentyOneUniqueLocationMajorRows {
    NSArray<IDAutocorrectionDecisionRow *> *rows = IDAutocorrectionDecisionMatrix();
    XCTAssertEqual(rows.count, 21U);
    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
    for (NSUInteger index = 0; index < rows.count; index += 1) {
        IDAutocorrectionDecisionRow *row = rows[index];
        XCTAssertEqual(row.location, (IDAutocorrectionLocation)(index / 7));
        XCTAssertEqual(row.decision, (IDAutocorrectionDecision)(index % 7));
        XCTAssertGreaterThan(row.identifier.length, 0U);
        [identifiers addObject:row.identifier];
    }
    XCTAssertEqual(identifiers.count, 21U);
}

- (void)testExactRowIdentifierSelectsOneMatrixRow {
    NSArray<IDAutocorrectionDecisionRow *> *rows =
        IDAutocorrectionDecisionRowsMatchingIdentifier(
            @"before-boundary-undo-punctuation");
    XCTAssertEqual(rows.count, 1U);
    XCTAssertEqualObjects(rows.firstObject.identifier,
                          @"before-boundary-undo-punctuation");
    XCTAssertEqual(rows.firstObject.location,
                   IDAutocorrectionLocationBeforeBoundary);
    XCTAssertEqual(rows.firstObject.decision,
                   IDAutocorrectionDecisionUndoPunctuation);
}

- (void)testMissingRowIdentifierFailsClosedWhileNilSelectsTheFullMatrix {
    XCTAssertEqual(IDAutocorrectionDecisionRowsMatchingIdentifier(nil).count, 21U);
    XCTAssertEqual(
        IDAutocorrectionDecisionRowsMatchingIdentifier(@"unknown-row").count,
        0U);
}

- (void)testStatusParserAcceptsCompleteVersionOnePayload {
    NSError *error = nil;
    IDAutocorrectionStatus *status = IDParseAutocorrectionStatus(
        IDJSONString(IDValidStatusDictionary()), &error);
    XCTAssertNotNil(status);
    XCTAssertNil(error);
    XCTAssertEqualObjects(status.canonical,
        @"A quiet adress lantern waits.\nSecond block stays unchanged.");
    XCTAssertEqual(status.selection.location, 14U);
    XCTAssertEqual(status.checkingRanges.count, 1U);
    XCTAssertEqualObjects(status.coordinateSpaceIdentity,
                          @"document-interaction-container");
}

- (void)testStatusParserRejectsMissingSchema {
    NSMutableDictionary *payload = [IDValidStatusDictionary() mutableCopy];
    [payload removeObjectForKey:@"schema"];
    NSError *error = nil;
    XCTAssertNil(IDParseAutocorrectionStatus(IDJSONString(payload), &error));
    XCTAssertEqualObjects(error.domain, IDAutocorrectionStatusErrorDomain);
}

- (void)testStatusParserRejectsWrongSchemaVersion {
    NSMutableDictionary *payload = [IDValidStatusDictionary() mutableCopy];
    payload[@"schema"] = @2;
    NSError *error = nil;
    XCTAssertNil(IDParseAutocorrectionStatus(IDJSONString(payload), &error));
    XCTAssertEqualObjects(error.domain, IDAutocorrectionStatusErrorDomain);
}

- (void)testStatusParserRejectsMalformedCandidateDescriptorSchema {
    for (NSDictionary *descriptor in @[
        @{},
        @{@"candidate": @"address", @"original": @"adress"},
        @{
            @"candidate": @"address", @"original": @"adress",
            @"actionable": @YES, @"unexpected": @1,
        },
        @{
            @"candidate": @1, @"original": @"adress",
            @"actionable": @YES,
        },
        @{
            @"candidate": @"address", @"original": @"adress",
            @"actionable": @1,
        },
    ]) {
        NSMutableDictionary *payload = [IDValidStatusDictionary() mutableCopy];
        payload[@"candidateDescriptor"] = descriptor;
        NSError *error = nil;
        XCTAssertNil(IDParseAutocorrectionStatus(IDJSONString(payload), &error),
                     @"Accepted malformed candidate descriptor: %@", descriptor);
        XCTAssertEqualObjects(error.domain, IDAutocorrectionStatusErrorDomain);
    }
}

- (void)testStatusParserRejectsMalformedKeyboardStateSchema {
    for (NSDictionary *keyboardState in @[
        @{},
        @{@"visible": @YES, @"locale": @"en_US"},
        @{
            @"visible": @YES, @"locale": @"en_US",
            @"learnedOriginal": @NO, @"unexpected": @1,
        },
        @{
            @"visible": @1, @"locale": @"en_US",
            @"learnedOriginal": @NO,
        },
        @{
            @"visible": @YES, @"locale": @1,
            @"learnedOriginal": @NO,
        },
        @{
            @"visible": @YES, @"locale": @"en_US",
            @"learnedOriginal": @0,
        },
    ]) {
        NSMutableDictionary *payload = [IDValidStatusDictionary() mutableCopy];
        payload[@"keyboardState"] = keyboardState;
        NSError *error = nil;
        XCTAssertNil(IDParseAutocorrectionStatus(IDJSONString(payload), &error),
                     @"Accepted malformed keyboard state: %@", keyboardState);
        XCTAssertEqualObjects(error.domain, IDAutocorrectionStatusErrorDomain);
    }
}

- (void)testCandidateAbsenceIsAnErrorInsteadOfASkip {
    NSError *error = nil;
    XCTAssertFalse(IDAutocorrectionCandidateDescriptorIsActionable(
        nil, @"address", &error));
    XCTAssertEqualObjects(error.domain, IDAutocorrectionStatusErrorDomain);
    XCTAssertTrue([error.localizedDescription containsString:@"candidate"]);
}

- (void)testUnexpectedCandidateIsAnErrorInsteadOfASkip {
    NSError *error = nil;
    NSDictionary *descriptor = @{
        @"candidate": @"addres", @"original": @"adress", @"actionable": @YES,
    };
    XCTAssertFalse(IDAutocorrectionCandidateDescriptorIsActionable(
        descriptor, @"address", &error));
    XCTAssertEqualObjects(error.domain, IDAutocorrectionStatusErrorDomain);
    XCTAssertTrue([error.localizedDescription containsString:@"address"]);
}

- (void)testOrdinaryTypingPredictionIsNotAnActionableCorrectionCandidate {
    XCTAssertFalse(IDAutocorrectionCandidateSignalsAreActionable(YES, NO));
    XCTAssertFalse(IDAutocorrectionCandidateSignalsAreActionable(NO, YES));
    XCTAssertFalse(IDAutocorrectionCandidateSignalsAreActionable(NO, NO));
    XCTAssertTrue(IDAutocorrectionCandidateSignalsAreActionable(YES, YES));
}

- (void)testInteriorCorrectionReplacesExactCanonicalTokenInOneTransaction {
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleBody],
    };
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[
            [[NSAttributedString alloc]
                initWithString:@"A quiet adress lantern waits."
                    attributes:attributes],
            [[NSAttributedString alloc]
                initWithString:@"Second block stays unchanged."
                    attributes:attributes],
        ]
        defaultAttributes:attributes];
    NSUUID *firstIdentifier = document.blocks[0].identifier;
    NSUUID *secondIdentifier = document.blocks[1].identifier;
    IDCanonicalTextStorageAdapter *storage =
        [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];
    __block NSUInteger processedEditCount = 0;
    id observer = [NSNotificationCenter.defaultCenter
        addObserverForName:NSTextStorageDidProcessEditingNotification
                    object:storage
                     queue:nil
                usingBlock:^(NSNotification *notification) {
                    (void)notification;
                    processedEditCount += 1;
                }];

    [storage replaceCharactersInRange:NSMakeRange(8, 6)
                           withString:@"address"];

    [NSNotificationCenter.defaultCenter removeObserver:observer];
    XCTAssertEqualObjects(storage.string,
        @"A quiet address lantern waits.\nSecond block stays unchanged.");
    XCTAssertEqual(document.documentRevision, 1U);
    XCTAssertEqual(processedEditCount, 1U);
    XCTAssertEqual(document.blocks.count, 2U);
    XCTAssertEqualObjects(document.blocks[0].identifier, firstIdentifier);
    XCTAssertEqualObjects(document.blocks[1].identifier, secondIdentifier);
    XCTAssertEqualObjects(document.blocks[1].attributedText.string,
                          @"Second block stays unchanged.");
    XCTAssertTrue(NSMaxRange(NSMakeRange(8, 7)) <= storage.length);
}

- (void)assertBoundaryCorrectionWithBlocks:(NSArray<NSString *> *)strings
                            canonicalRange:(NSRange)range
                         oldSelectionOffset:(NSUInteger)oldSelectionOffset
                         newSelectionOffset:(NSUInteger)newSelectionOffset
                    expectedCanonicalString:(NSString *)expectedCanonical {
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleBody],
    };
    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc] initWithString:string
                                                         attributes:attributes]];
    }
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:blocks defaultAttributes:attributes];
    NSArray<NSUUID *> *identifiers = [document.blocks valueForKey:@"identifier"];
    IDCanonicalTextProjection *projection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];
    IDCanonicalLocation *selectionLocation =
        [projection locationForCanonicalOffset:oldSelectionOffset];
    IDRichTextAnchor *selectionAnchor = [[IDRichTextAnchor alloc]
        initWithDocument:document
        blockIdentifier:selectionLocation.blockIdentifier
        localOffset:selectionLocation.localOffset
        bias:IDRichTextAnchorBiasAfter];
    IDRichTextPosition *selection = [[IDRichTextPosition alloc]
        initWithAnchor:selectionAnchor affinity:UITextStorageDirectionForward];
    IDCanonicalTextStorageAdapter *storage =
        [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];
    __block NSUInteger processedEditCount = 0;
    id observer = [NSNotificationCenter.defaultCenter
        addObserverForName:NSTextStorageDidProcessEditingNotification
                    object:storage
                     queue:nil
                usingBlock:^(__unused NSNotification *notification) {
                    processedEditCount += 1;
                }];

    [storage replaceCharactersInRange:range withString:@"address"];

    [NSNotificationCenter.defaultCenter removeObserver:observer];
    IDCanonicalTextProjection *updatedProjection =
        [[IDCanonicalTextProjection alloc] initWithDocument:document];
    XCTAssertEqualObjects(storage.string, expectedCanonical);
    XCTAssertEqual(document.documentRevision, 1U);
    XCTAssertEqual(processedEditCount, 1U);
    XCTAssertEqual(document.blocks.count, 2U);
    XCTAssertEqualObjects([document.blocks valueForKey:@"identifier"], identifiers);
    XCTAssertEqual([selection.anchor canonicalOffsetInProjection:updatedProjection],
                   newSelectionOffset);
    XCTAssertEqual(selection.affinity, UITextStorageDirectionForward);
    XCTAssertEqual([storage.string rangeOfString:@"\n"].location,
                   [expectedCanonical rangeOfString:@"\n"].location);
}

- (void)testCorrectionImmediatelyBeforeStructuralNewlineIsAtomic {
    [self assertBoundaryCorrectionWithBlocks:@[@"A quiet adress", @"lantern waits."]
                               canonicalRange:NSMakeRange(8, 6)
                            oldSelectionOffset:14
                            newSelectionOffset:15
                       expectedCanonicalString:@"A quiet address\nlantern waits."];
}

- (void)testCorrectionImmediatelyAfterStructuralNewlineIsAtomic {
    [self assertBoundaryCorrectionWithBlocks:@[@"A quiet scene.",
                                                @"adress lantern waits."]
                               canonicalRange:NSMakeRange(15, 6)
                            oldSelectionOffset:21
                            newSelectionOffset:22
                       expectedCanonicalString:@"A quiet scene.\naddress lantern waits."];
}

- (void)testDelimiterCommitThenImmediateDeletesStayOrderedAcrossBlockBoundaries {
    NSArray<NSDictionary<NSString *, id> *> *fixtures = @[
        @{@"blocks": @[@"A quiet adress lantern waits.", @"Second block stays unchanged."],
          @"range": [NSValue valueWithRange:NSMakeRange(8, 6)], @"insertion": @15,
          @"space": @"A quiet address  lantern waits.\nSecond block stays unchanged.",
          @"punctuation": @"A quiet address. lantern waits.\nSecond block stays unchanged."},
        @{@"blocks": @[@"A quiet adress", @"lantern waits."],
          @"range": [NSValue valueWithRange:NSMakeRange(8, 6)], @"insertion": @15,
          @"space": @"A quiet address \nlantern waits.",
          @"punctuation": @"A quiet address.\nlantern waits."},
        @{@"blocks": @[@"A quiet scene.", @"adress lantern waits."],
          @"range": [NSValue valueWithRange:NSMakeRange(15, 6)], @"insertion": @22,
          @"space": @"A quiet scene.\naddress  lantern waits.",
          @"punctuation": @"A quiet scene.\naddress. lantern waits."},
    ];
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleBody],
    };

    for (NSDictionary<NSString *, id> *fixture in fixtures) {
        for (NSString *delimiter in @[@" ", @"."]) {
            NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
            for (NSString *string in fixture[@"blocks"]) {
                [blocks addObject:[[NSAttributedString alloc]
                    initWithString:string attributes:attributes]];
            }
            IDBlockDocument *document = [[IDBlockDocument alloc]
                initWithAttributedBlocks:blocks defaultAttributes:attributes];
            NSArray<NSUUID *> *identifiers = [document.blocks valueForKey:@"identifier"];
            IDCanonicalTextStorageAdapter *storage =
                [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];
            __block NSUInteger notifications = 0;
            id observer = [NSNotificationCenter.defaultCenter
                addObserverForName:NSTextStorageDidProcessEditingNotification
                            object:storage queue:nil
                        usingBlock:^(__unused NSNotification *notification) {
                            notifications += 1;
                        }];

            [storage replaceCharactersInRange:[fixture[@"range"] rangeValue]
                                     withString:@"address"];
            NSUInteger insertion = [fixture[@"insertion"] unsignedIntegerValue];
            [storage replaceCharactersInRange:NSMakeRange(insertion, 0)
                                     withString:delimiter];
            NSString *committed = [delimiter isEqualToString:@" "]
                ? fixture[@"space"] : fixture[@"punctuation"];
            XCTAssertEqualObjects(storage.string, committed);
            XCTAssertEqual(document.documentRevision, 2U);

            [storage replaceCharactersInRange:NSMakeRange(insertion, 1) withString:@""];
            [storage replaceCharactersInRange:NSMakeRange(insertion - 1, 1) withString:@""];

            XCTAssertEqual(document.documentRevision, 4U);
            XCTAssertEqual(notifications, 4U);
            XCTAssertEqualObjects([document.blocks valueForKey:@"identifier"], identifiers);
            XCTAssertTrue([[storage.string substringWithRange:
                NSMakeRange(insertion - 7, 6)] isEqualToString:@"addres"]);
            [NSNotificationCenter.defaultCenter removeObserver:observer];
        }
    }
}

- (void)testCandidateCommitThenOrdinaryDeletesRemainControllerIndependent {
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleBody],
    };
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[
            [[NSAttributedString alloc] initWithString:@"A quiet adress"
                                            attributes:attributes],
            [[NSAttributedString alloc] initWithString:@"lantern waits."
                                            attributes:attributes],
        ] defaultAttributes:attributes];
    NSArray<NSUUID *> *identifiers = [document.blocks valueForKey:@"identifier"];
    IDCanonicalTextStorageAdapter *storage =
        [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];

    [storage replaceCharactersInRange:NSMakeRange(8, 6) withString:@"address"];
    [storage replaceCharactersInRange:NSMakeRange(15, 0) withString:@" "];
    [storage replaceCharactersInRange:NSMakeRange(15, 1) withString:@""];
    [storage replaceCharactersInRange:NSMakeRange(14, 1) withString:@""];

    XCTAssertEqualObjects(storage.string, @"A quiet addres\nlantern waits.");
    XCTAssertEqual(document.documentRevision, 4U);
    XCTAssertEqualObjects([document.blocks valueForKey:@"identifier"], identifiers);
}

@end
