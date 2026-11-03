@import XCTest;

#import "IDTextInputScenario.h"
#import "IDTextInputStateRecorder.h"
#import "IDTextInputTestHost.h"
#import "IDTextInputTransactionDriver.h"

@interface IDTextInputTransaction (IDDriverTesting)
@property(nonatomic, readwrite) IDTextInputTransactionKind kind;
@property(nonatomic, copy, readwrite, nullable) NSString *text;
@property(nonatomic, copy, readwrite, nullable) NSValue *rangeValue;
@property(nonatomic, copy, readwrite, nullable) NSValue *selectedRangeValue;
@property(nonatomic, copy, readwrite) NSDictionary<NSString *, id> *traits;
@property(nonatomic, copy, readwrite, nullable) NSString *phase;
@property(nonatomic, copy, readwrite, nullable) NSString *trait;
@end

@interface IDTextInputScenario (IDDriverTesting)
@property(nonatomic, copy, readwrite) NSString *initialText;
@property(nonatomic, readwrite) NSRange initialSelection;
@end

@interface IDTextInputTransactionDriverTests : XCTestCase
@end

@implementation IDTextInputTransactionDriverTests

- (NSURL *)fixtureURL {
    NSString *testPath = [NSString stringWithUTF8String:__FILE__];
    NSURL *root = [NSURL fileURLWithPath:
        [[testPath stringByDeletingLastPathComponent]
            stringByDeletingLastPathComponent]
                              isDirectory:YES];
    return [root URLByAppendingPathComponent:
        @"TestFixtures/TextInputScenarios/ime-ios26.5-v1.json"];
}

- (IDTextInputScenario *)scenarioWithText:(NSString *)text {
    NSError *error = nil;
    IDTextInputScenario *scenario =
        IDLoadTextInputScenarios(self.fixtureURL, &error).firstObject;
    XCTAssertNotNil(scenario, @"%@", error);
    scenario.initialText = text;
    scenario.initialSelection = NSMakeRange(0, 0);
    return scenario;
}

- (IDTextInputTestHost *)hostWithText:(NSString *)text {
    return [self hostWithText:text kind:IDTextInputHostKindReference];
}

- (IDTextInputTestHost *)hostWithText:(NSString *)text
                                  kind:(IDTextInputHostKind)kind {
    NSError *error = nil;
    IDTextInputTestHost *host =
        [IDTextInputTestHost hostWithKind:kind
                                 scenario:[self scenarioWithText:text]
                                    error:&error];
    XCTAssertNotNil(host, @"%@", error);
    return host;
}

- (IDTextInputTransaction *)transaction:
    (IDTextInputTransactionKind)kind
                                      text:(nullable NSString *)text
                                     range:(NSRange)range
                             selectedRange:(NSRange)selectedRange
                                    traits:(NSDictionary *)traits
                                     phase:(nullable NSString *)phase {
    IDTextInputTransaction *transaction = [IDTextInputTransaction new];
    transaction.kind = kind;
    transaction.text = text;
    transaction.rangeValue =
        range.location == NSNotFound ? nil : [NSValue valueWithRange:range];
    transaction.selectedRangeValue = selectedRange.location == NSNotFound
        ? nil : [NSValue valueWithRange:selectedRange];
    transaction.traits = traits ?: @{};
    transaction.phase = phase;
    return transaction;
}

- (NSString *)textOfHost:(IDTextInputTestHost *)host {
    UITextRange *range =
        [host.input textRangeFromPosition:host.input.beginningOfDocument
                              toPosition:host.input.endOfDocument];
    return [host.input textInRange:range];
}

- (IDTextInputTransactionDriver *)driverForHost:
    (IDTextInputTestHost *)host {
    IDTextInputStateRecorder *recorder =
        [[IDTextInputStateRecorder alloc] initWithHost:host];
    return [[IDTextInputTransactionDriver alloc]
        initWithHost:host recorder:recorder];
}

- (void)testToggleInlineTraitProducesEquivalentStockAndCustomTypingState {
    NSMutableArray<NSArray<NSString *> *> *typingStates =
        [NSMutableArray array];
    for (NSNumber *kindValue in @[
             @(IDTextInputHostKindStock),
             @(IDTextInputHostKindReference),
         ]) {
        IDTextInputTestHost *host =
            [self hostWithText:@"A" kind:kindValue.integerValue];
        IDTextInputStateRecorder *recorder =
            [[IDTextInputStateRecorder alloc] initWithHost:host];
        IDTextInputTransactionDriver *driver =
            [[IDTextInputTransactionDriver alloc]
                initWithHost:host recorder:recorder];
        IDTextInputTransaction *toggle = [self
            transaction:IDTextInputTransactionKindToggleInlineTrait
                   text:nil
                  range:NSMakeRange(NSNotFound, 0)
          selectedRange:NSMakeRange(NSNotFound, 0)
                 traits:@{}
                  phase:nil];
        toggle.trait = @"bold";
        NSError *error = nil;

        XCTAssertNil([driver applyTransaction:toggle index:0 error:&error]);
        XCTAssertNil(error);
        IDTextInputSnapshot *snapshot =
            [recorder capturePhase:@"after-toggle"];
        [typingStates addObject:snapshot.state[@"typingInlineTraits"]];
    }

    XCTAssertEqualObjects(typingStates[0], (@[@"bold"]));
    XCTAssertEqualObjects(typingStates[1], typingStates[0]);
}

- (void)testStockRangeToggleCanAddRemoveAndAddTraitAgain {
    IDTextInputTestHost *host =
        [self hostWithText:@"AB" kind:IDTextInputHostKindStock];
    ((UITextView *)host.input).selectedRange = NSMakeRange(0, 2);
    IDTextInputStateRecorder *recorder =
        [[IDTextInputStateRecorder alloc] initWithHost:host];
    IDTextInputTransactionDriver *driver =
        [[IDTextInputTransactionDriver alloc]
            initWithHost:host recorder:recorder];
    IDTextInputTransaction *toggle = [self
        transaction:IDTextInputTransactionKindToggleInlineTrait
               text:nil
              range:NSMakeRange(NSNotFound, 0)
      selectedRange:NSMakeRange(NSNotFound, 0)
             traits:@{}
              phase:nil];
    toggle.trait = @"bold";

    for (NSUInteger index = 0; index < 3; index++) {
        NSError *error = nil;
        XCTAssertNil([driver applyTransaction:toggle
                                        index:index
                                        error:&error]);
        XCTAssertNil(error);
    }

    XCTAssertEqualObjects(
        IDNormalizedInlineTraitNames(
            [host.observedTextStorage attributesAtIndex:0
                                         effectiveRange:NULL]),
        (@[@"bold"]));
}

- (void)testTextSelectionMarkedAndReplacementOperationsUseUITextInput {
    IDTextInputTestHost *host = [self hostWithText:@"alpha\nbeta"];
    IDTextInputTransactionDriver *driver = [self driverForHost:host];
    NSError *error = nil;
    IDTextInputTransaction *selection = [self
        transaction:IDTextInputTransactionKindSetSelection
               text:nil
              range:NSMakeRange(2, 0)
      selectedRange:NSMakeRange(NSNotFound, 0)
             traits:@{}
              phase:nil];
    XCTAssertNil([driver applyTransaction:selection index:0 error:&error]);
    XCTAssertNil(error);

    IDTextInputTransaction *marked = [self
        transaction:IDTextInputTransactionKindSetMarkedText
               text:@"かな"
              range:NSMakeRange(NSNotFound, 0)
      selectedRange:NSMakeRange(1, 0)
             traits:@{}
              phase:nil];
    XCTAssertNil([driver applyTransaction:marked index:1 error:&error]);
    XCTAssertEqualObjects([host.input textInRange:host.input.markedTextRange],
                          @"かな");
    NSRange selected = NSMakeRange(
        [host.input offsetFromPosition:host.input.beginningOfDocument
                            toPosition:host.input.selectedTextRange.start],
        0);
    XCTAssertEqual(selected.location, 3U);

    IDTextInputTransaction *unmark =
        [self transaction:IDTextInputTransactionKindUnmarkText
                     text:nil
                    range:NSMakeRange(NSNotFound, 0)
            selectedRange:NSMakeRange(NSNotFound, 0)
                   traits:@{}
                    phase:nil];
    XCTAssertNil([driver applyTransaction:unmark index:2 error:&error]);
    XCTAssertNil(host.input.markedTextRange);

    IDTextInputTransaction *replace = [self
        transaction:IDTextInputTransactionKindReplaceRange
               text:@"X"
              range:NSMakeRange(2, 5)
      selectedRange:NSMakeRange(NSNotFound, 0)
             traits:@{}
              phase:nil];
    XCTAssertNil([driver applyTransaction:replace index:3 error:&error]);
    XCTAssertEqualObjects([self textOfHost:host], @"alX\nbeta");

    IDTextInputTransaction *insert =
        [self transaction:IDTextInputTransactionKindInsertText
                     text:@"!"
                    range:NSMakeRange(NSNotFound, 0)
            selectedRange:NSMakeRange(NSNotFound, 0)
                   traits:@{}
                    phase:nil];
    XCTAssertNil([driver applyTransaction:insert index:4 error:&error]);
    IDTextInputTransaction *delete =
        [self transaction:IDTextInputTransactionKindDeleteBackward
                     text:nil
                    range:NSMakeRange(NSNotFound, 0)
            selectedRange:NSMakeRange(NSNotFound, 0)
                   traits:@{}
                    phase:nil];
    XCTAssertNil([driver applyTransaction:delete index:5 error:&error]);
    XCTAssertEqualObjects([self textOfHost:host], @"alX\nbeta");
}

- (void)testResponderTraitsCheckpointAndUndoRedoFamily {
    IDTextInputTestHost *host = [self hostWithText:@"abc"];
    IDTextInputStateRecorder *recorder =
        [[IDTextInputStateRecorder alloc] initWithHost:host];
    IDTextInputTransactionDriver *driver =
        [[IDTextInputTransactionDriver alloc]
            initWithHost:host recorder:recorder];
    NSError *error = nil;
#define APPLY(kindValue, traitsValue, phaseValue) \
    [driver applyTransaction:[self transaction:(kindValue) text:nil \
        range:NSMakeRange(NSNotFound, 0) \
        selectedRange:NSMakeRange(NSNotFound, 0) traits:(traitsValue) \
        phase:(phaseValue)] index:0 error:&error]
    XCTAssertNil(APPLY(IDTextInputTransactionKindBecomeFirstResponder,
                       @{}, nil));
    XCTAssertTrue(host.input.isFirstResponder);
    XCTAssertNil(APPLY(IDTextInputTransactionKindSetTraits,
                       (@{@"keyboardType": @(UIKeyboardTypeEmailAddress),
                          @"secureTextEntry": @YES}), nil));
    XCTAssertEqual([(id)host.input keyboardType],
                   UIKeyboardTypeEmailAddress);
    XCTAssertTrue([(id)host.input isSecureTextEntry]);

    XCTAssertNil(APPLY(IDTextInputTransactionKindBeginUndoGroup, @{}, nil));
    IDTextInputTransaction *insert =
        [self transaction:IDTextInputTransactionKindInsertText
                     text:@"z"
                    range:NSMakeRange(NSNotFound, 0)
            selectedRange:NSMakeRange(NSNotFound, 0)
                   traits:@{}
                    phase:nil];
    XCTAssertNil([driver applyTransaction:insert index:1 error:&error]);
    XCTAssertNil(APPLY(IDTextInputTransactionKindEndUndoGroup, @{}, nil));
    NSString *edited = [self textOfHost:host];
    XCTAssertNil(APPLY(IDTextInputTransactionKindUndo, @{}, nil));
    XCTAssertNotEqualObjects([self textOfHost:host], edited);
    XCTAssertNil(APPLY(IDTextInputTransactionKindRedo, @{}, nil));
    XCTAssertEqualObjects([self textOfHost:host], edited);

    IDTextInputSnapshot *snapshot =
        APPLY(IDTextInputTransactionKindCheckpoint, @{}, @"terminal");
    XCTAssertEqualObjects(snapshot.phase, @"terminal");
    XCTAssertNil(APPLY(IDTextInputTransactionKindResignFirstResponder,
                       @{}, nil));
    XCTAssertFalse(host.input.isFirstResponder);
#undef APPLY
}

- (void)testDriverFailsClosedForInvalidStateRangesAndFields {
    IDTextInputTestHost *host = [self hostWithText:@"abc"];
    IDTextInputTransactionDriver *driver = [self driverForHost:host];
    NSArray<IDTextInputTransaction *> *invalid = @[
        [self transaction:IDTextInputTransactionKindResignFirstResponder
                     text:nil range:NSMakeRange(NSNotFound, 0)
            selectedRange:NSMakeRange(NSNotFound, 0) traits:@{} phase:nil],
        [self transaction:IDTextInputTransactionKindSetSelection
                     text:nil range:NSMakeRange(4, 0)
            selectedRange:NSMakeRange(NSNotFound, 0) traits:@{} phase:nil],
        [self transaction:IDTextInputTransactionKindEndUndoGroup
                     text:nil range:NSMakeRange(NSNotFound, 0)
            selectedRange:NSMakeRange(NSNotFound, 0) traits:@{} phase:nil],
        [self transaction:IDTextInputTransactionKindUndo
                     text:nil range:NSMakeRange(NSNotFound, 0)
            selectedRange:NSMakeRange(NSNotFound, 0) traits:@{} phase:nil],
        [self transaction:IDTextInputTransactionKindSetTraits
                     text:nil range:NSMakeRange(NSNotFound, 0)
            selectedRange:NSMakeRange(NSNotFound, 0)
                   traits:@{@"unknownTrait": @1} phase:nil],
        [self transaction:IDTextInputTransactionKindInsertText
                     text:@"x" range:NSMakeRange(NSNotFound, 0)
            selectedRange:NSMakeRange(NSNotFound, 0) traits:@{}
                    phase:@"illegal"],
    ];
    for (NSUInteger index = 0; index < invalid.count; index++) {
        NSError *error = nil;
        XCTAssertNil([driver applyTransaction:invalid[index]
                                        index:index
                                        error:&error]);
        XCTAssertEqualObjects(error.domain,
                              IDTextInputTransactionErrorDomain);
    }
}

- (void)testDriverSourceContainsNoDirectStorageOrDocumentMutation {
    NSString *sourcePath = [[NSString stringWithUTF8String:__FILE__]
        stringByDeletingLastPathComponent];
    sourcePath = [sourcePath stringByAppendingPathComponent:
        @"TextInputDifferential/IDTextInputTransactionDriver.m"];
    NSString *source =
        [NSString stringWithContentsOfFile:sourcePath
                                 encoding:NSUTF8StringEncoding
                                    error:nil];
    XCTAssertNotNil(source);
    NSArray<NSString *> *forbidden = @[
        @"replaceCharactersInRange:", @"id_replaceRange:",
        @"id_document", @"IDBlockDocument",
    ];
    for (NSString *token in forbidden) {
        XCTAssertEqual([source rangeOfString:token].location, NSNotFound,
                       @"%@", token);
    }
}

@end
