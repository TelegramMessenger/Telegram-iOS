@import XCTest;

#include <math.h>

#import "IDTextInputScenario.h"
#import "IDTextInputStateRecorder.h"
#import "IDTextInputTestHost.h"

@interface IDTextInputRecorderPriorDelegate : NSObject <UITextInputDelegate>
@end

@implementation IDTextInputRecorderPriorDelegate
- (void)selectionWillChange:(id<UITextInput>)textInput {
    (void)textInput;
}
- (void)selectionDidChange:(id<UITextInput>)textInput {
    (void)textInput;
}
- (void)textWillChange:(id<UITextInput>)textInput {
    (void)textInput;
}
- (void)textDidChange:(id<UITextInput>)textInput {
    (void)textInput;
}
- (void)conversationContext:(UIConversationContext *)context
                  didChange:(id<UITextInput>)textInput {
    (void)context;
    (void)textInput;
}
@end

@interface IDTextInputStateRecorderTests : XCTestCase
@end

@implementation IDTextInputStateRecorderTests

- (void)testInlineNormalizerUsesStableSemanticNames {
    UIFont *font = [UIFont systemFontOfSize:17.0
                                    weight:UIFontWeightBold];
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
    };

    XCTAssertEqualObjects(
        IDNormalizedInlineTraitNames(attributes),
        (@[@"bold", @"underline"]));
}

- (void)testInlineRunNormalizerCoalescesEquivalentRuns {
    NSMutableAttributedString *text =
        [[NSMutableAttributedString alloc] initWithString:@"abc"];
    [text addAttribute:NSUnderlineStyleAttributeName
                 value:@(NSUnderlineStyleSingle)
                 range:NSMakeRange(0, 2)];
    NSTextStorage *storage =
        [[NSTextStorage alloc] initWithAttributedString:text];

    XCTAssertEqualObjects(IDNormalizedInlineRuns(storage), (@[
        @{@"range": @{@"location": @0, @"length": @2},
          @"traits": @[@"underline"]},
        @{@"range": @{@"location": @2, @"length": @1},
          @"traits": @[]},
    ]));
}

- (void)testInlineRunNormalizerTreatsNewlineAsStructural {
    NSMutableAttributedString *text =
        [[NSMutableAttributedString alloc] initWithString:@"a\nb"];
    [text addAttribute:NSUnderlineStyleAttributeName
                 value:@(NSUnderlineStyleSingle)
                 range:NSMakeRange(0, text.length)];
    NSTextStorage *storage =
        [[NSTextStorage alloc] initWithAttributedString:text];

    XCTAssertEqualObjects(IDNormalizedInlineRuns(storage), (@[
        @{@"range": @{@"location": @0, @"length": @1},
          @"traits": @[@"underline"]},
        @{@"range": @{@"location": @1, @"length": @1},
          @"traits": @[]},
        @{@"range": @{@"location": @2, @"length": @1},
          @"traits": @[@"underline"]},
    ]));
}

- (NSURL *)fixtureURLNamed:(NSString *)name {
    NSString *testPath = [NSString stringWithUTF8String:__FILE__];
    NSURL *root = [NSURL fileURLWithPath:
        [[testPath stringByDeletingLastPathComponent]
            stringByDeletingLastPathComponent]
                              isDirectory:YES];
    return [[root URLByAppendingPathComponent:
        @"TestFixtures/TextInputScenarios" isDirectory:YES]
        URLByAppendingPathComponent:
            [name stringByAppendingPathExtension:@"json"]];
}

- (IDTextInputScenario *)representativeScenario {
    NSError *error = nil;
    IDTextInputScenario *scenario =
        IDLoadTextInputScenarios(
            [self fixtureURLNamed:@"ime-ios26.5-v1"], &error).firstObject;
    XCTAssertNotNil(scenario, @"%@", error);
    return scenario;
}

- (IDTextInputTestHost *)hostWithKind:(IDTextInputHostKind)kind {
    NSError *error = nil;
    IDTextInputTestHost *host =
        [IDTextInputTestHost hostWithKind:kind
                                 scenario:[self representativeScenario]
                                    error:&error];
    XCTAssertNotNil(host, @"%@", error);
    return host;
}

- (void)assertFiniteRectDictionary:(NSDictionary<NSString *, id> *)rect {
    NSSet *actualKeys = [NSSet setWithArray:rect.allKeys];
    NSSet *expectedKeys =
        [NSSet setWithArray:@[@"x", @"y", @"width", @"height"]];
    XCTAssertEqualObjects(actualKeys, expectedKeys);
    for (NSString *key in @[@"x", @"y", @"width", @"height"]) {
        XCTAssertTrue([rect[key] isKindOfClass:NSNumber.class]);
        XCTAssertTrue(isfinite([rect[key] doubleValue]),
                      @"non-finite %@ in %@", key, rect);
    }
}

- (void)testEquivalentFreshHostsProduceEquivalentBaselineSnapshot {
    IDTextInputTestHost *stock = [self hostWithKind:IDTextInputHostKindStock];
    IDTextInputTestHost *reference =
        [self hostWithKind:IDTextInputHostKindReference];
    IDTextInputTestHost *minimal =
        [self hostWithKind:IDTextInputHostKindMinimal];
    IDTextInputStateRecorder *stockRecorder =
        [[IDTextInputStateRecorder alloc] initWithHost:stock];
    IDTextInputStateRecorder *referenceRecorder =
        [[IDTextInputStateRecorder alloc] initWithHost:reference];
    IDTextInputStateRecorder *minimalRecorder =
        [[IDTextInputStateRecorder alloc] initWithHost:minimal];
    IDTextInputSnapshot *stockState =
        [stockRecorder capturePhase:@"baseline"];
    IDTextInputSnapshot *referenceState =
        [referenceRecorder capturePhase:@"baseline"];
    IDTextInputSnapshot *minimalState =
        [minimalRecorder capturePhase:@"baseline"];
    for (NSString *field in @[
        @"canonical", @"blocks", @"selection", @"markedRange",
        @"markedText", @"affinity", @"traits", @"canUndo", @"canRedo",
        @"firstResponder",
    ]) {
        XCTAssertEqualObjects(stockState.state[field],
                              referenceState.state[field], @"reference %@", field);
        XCTAssertEqualObjects(stockState.state[field],
                              minimalState.state[field], @"minimal %@", field);
    }
    NSArray<NSString *> *expectedBlocks =
        [[self representativeScenario].initialText
            componentsSeparatedByString:@"\n"];
    XCTAssertEqualObjects(referenceState.state[@"blocks"], expectedBlocks);
    XCTAssertEqualObjects(minimalState.state[@"blocks"], expectedBlocks);
}

- (void)testHostUsesObservableStorageAndSuppressesSystemKeyboardUI {
    for (NSNumber *kind in @[
        @(IDTextInputHostKindStock), @(IDTextInputHostKindReference),
        @(IDTextInputHostKindMinimal),
    ]) {
        IDTextInputTestHost *host =
            [self hostWithKind:(IDTextInputHostKind)kind.integerValue];
        XCTAssertNotNil(host.window);
        XCTAssertNotNil(host.input);
        XCTAssertNotNil(host.observedTextStorage);
        XCTAssertEqual(host.kind, kind.integerValue);
        XCTAssertNotNil(host.input.inputView);
        XCTAssertEqual(host.input.inputView.bounds.size.height, 0.0);
    }
}

- (void)testSnapshotHasExactKeysAndFiniteGeometry {
    IDTextInputTestHost *host =
        [self hostWithKind:IDTextInputHostKindMinimal];
    IDTextInputStateRecorder *recorder =
        [[IDTextInputStateRecorder alloc] initWithHost:host];
    IDTextInputSnapshot *snapshot = [recorder capturePhase:@"baseline"];
    XCTAssertEqualObjects(snapshot.phase, @"baseline");
    NSSet *actualKeys = [NSSet setWithArray:snapshot.state.allKeys];
    NSSet *expectedKeys = [NSSet setWithArray:@[
        @"canonical", @"blocks", @"selection", @"markedRange",
        @"markedText", @"affinity", @"firstResponder", @"canUndo",
        @"canRedo", @"traits", @"caretRect", @"selectionRects",
        @"inputDelegateTrace", @"storageMutationTrace",
        @"typingInlineTraits", @"inlineRuns", @"annotationRanges",
        @"behaviorCapabilities", @"behaviorDetached",
    ]];
    XCTAssertEqualObjects(actualKeys, expectedKeys);
    NSDictionary *expectedMarkedRange =
        @{@"location": @(NSNotFound), @"length": @0};
    XCTAssertEqualObjects(snapshot.state[@"markedRange"], expectedMarkedRange);
    [self assertFiniteRectDictionary:snapshot.state[@"caretRect"]];
    XCTAssertTrue([snapshot.state[@"behaviorCapabilities"]
        isKindOfClass:NSArray.class]);
    XCTAssertEqualObjects(snapshot.state[@"behaviorDetached"], @NO);
    for (NSDictionary *selectionRect in snapshot.state[@"selectionRects"]) {
        [self assertFiniteRectDictionary:selectionRect[@"rect"]];
    }
}

- (void)testInputOriginInsertProducesStockTruthDelegateAndStorageTraces {
    NSMutableArray<IDTextInputSnapshot *> *snapshots = [NSMutableArray array];
    for (NSNumber *kind in @[
        @(IDTextInputHostKindStock), @(IDTextInputHostKindReference),
        @(IDTextInputHostKindMinimal),
    ]) {
        IDTextInputTestHost *host =
            [self hostWithKind:(IDTextInputHostKind)kind.integerValue];
        IDTextInputStateRecorder *recorder =
            [[IDTextInputStateRecorder alloc] initWithHost:host];
        [host.input insertText:@"x"];
        IDTextInputSnapshot *snapshot =
            [recorder capturePhase:@"afterInsert"];
        XCTAssertEqualObjects(snapshot.state[@"inputDelegateTrace"], @[]);
        XCTAssertEqual(
            [snapshot.state[@"storageMutationTrace"] count], 1U);
        NSDictionary *mutation =
            [snapshot.state[@"storageMutationTrace"] firstObject];
        NSSet *actualKeys = [NSSet setWithArray:mutation.allKeys];
        NSSet *expectedKeys =
            [NSSet setWithArray:@[@"editedMask", @"range", @"delta"]];
        XCTAssertEqualObjects(actualKeys, expectedKeys);
        [snapshots addObject:snapshot];
    }
    for (NSUInteger index = 1; index < snapshots.count; index++) {
        XCTAssertEqualObjects(snapshots[0].state[@"inputDelegateTrace"],
                              snapshots[index].state[@"inputDelegateTrace"]);
        XCTAssertEqualObjects(snapshots[0].state[@"storageMutationTrace"],
                              snapshots[index].state[@"storageMutationTrace"]);
    }
}

- (void)testRecorderCapturesAndForwardsOrderedInputDelegateCallbacks {
    IDTextInputTestHost *host =
        [self hostWithKind:IDTextInputHostKindReference];
    IDTextInputRecorderPriorDelegate *prior =
        [IDTextInputRecorderPriorDelegate new];
    host.input.inputDelegate = prior;
    IDTextInputStateRecorder *recorder =
        [[IDTextInputStateRecorder alloc] initWithHost:host];
    id<UITextInputDelegate> delegate = host.input.inputDelegate;
    [delegate selectionWillChange:host.input];
    [delegate textWillChange:host.input];
    [delegate textDidChange:host.input];
    [delegate selectionDidChange:host.input];
    NSArray<NSString *> *expectedCallbacks = @[
        @"selectionWillChange", @"textWillChange",
        @"textDidChange", @"selectionDidChange",
    ];
    XCTAssertEqualObjects(
        [recorder capturePhase:@"callbacks"].state[@"inputDelegateTrace"],
        expectedCallbacks);
}

- (void)testResetClearsTransactionTraces {
    IDTextInputTestHost *host =
        [self hostWithKind:IDTextInputHostKindReference];
    IDTextInputStateRecorder *recorder =
        [[IDTextInputStateRecorder alloc] initWithHost:host];
    [host.input.inputDelegate textWillChange:host.input];
    XCTAssertGreaterThan(
        [[recorder capturePhase:@"mutated"].state[@"inputDelegateTrace"] count],
        0U);
    [recorder resetTransactionTraces];
    IDTextInputSnapshot *reset = [recorder capturePhase:@"reset"];
    XCTAssertEqualObjects(reset.state[@"inputDelegateTrace"], @[]);
    XCTAssertEqualObjects(reset.state[@"storageMutationTrace"], @[]);
}

- (void)testCapabilityDiagnosticsUseStableHostSentinels {
    IDTextInputSnapshot *stock = [[[IDTextInputStateRecorder alloc]
        initWithHost:[self hostWithKind:IDTextInputHostKindStock]]
        capturePhase:@"baseline"];
    IDTextInputSnapshot *reference = [[[IDTextInputStateRecorder alloc]
        initWithHost:[self hostWithKind:IDTextInputHostKindReference]]
        capturePhase:@"baseline"];
    IDTextInputSnapshot *minimal = [[[IDTextInputStateRecorder alloc]
        initWithHost:[self hostWithKind:IDTextInputHostKindMinimal]]
        capturePhase:@"baseline"];

    XCTAssertEqualObjects(stock.state[@"behaviorCapabilities"],
                          (@[@{@"identifier": @"stock-uikit",
                               @"state": @"system"}]));
    XCTAssertEqualObjects(reference.state[@"behaviorCapabilities"],
                          (@[@{@"identifier": @"reference-uikit",
                               @"state": @"system"}]));
    XCTAssertEqualObjects(stock.state[@"behaviorDetached"], @NO);
    XCTAssertEqualObjects(reference.state[@"behaviorDetached"], @NO);
    XCTAssertTrue([minimal.state[@"behaviorCapabilities"] count] > 0U);
    XCTAssertEqualObjects(minimal.state[@"behaviorDetached"], @NO);
    XCTAssertFalse([stock.state.description containsString:@"0x"]);
    XCTAssertFalse([reference.state.description containsString:@"0x"]);
}

- (void)testDetachRestoresPriorInputDelegate {
    IDTextInputTestHost *host =
        [self hostWithKind:IDTextInputHostKindStock];
    IDTextInputRecorderPriorDelegate *prior =
        [IDTextInputRecorderPriorDelegate new];
    host.input.inputDelegate = prior;
    IDTextInputStateRecorder *recorder =
        [[IDTextInputStateRecorder alloc] initWithHost:host];
    XCTAssertNotEqual(host.input.inputDelegate, prior);
    [recorder detach];
    XCTAssertEqual(host.input.inputDelegate, prior);
}

@end
