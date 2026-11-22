@import XCTest;

#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDPrivateUIKit.h"
#import "IDPrivateUIKit+Testing.h"
#import "IDUIKitInteractionCapability.h"

#import <objc/runtime.h>
#import "IDEngineSourceLayout.h"

@interface IDBlockTextView (IDFloatingCursorContractTesting)
- (void)beginFloatingCursorAtPoint:(CGPoint)point;
- (void)updateFloatingCursorAtPoint:(CGPoint)point;
- (void)updateFloatingCursorAtPoint:(CGPoint)point animated:(BOOL)animated;
- (void)endFloatingCursor;
@end

@interface IDUIKitInteractionCapability (IDFloatingCursorContractTesting)
@property(nonatomic, strong, readwrite, nullable) id privateAssistant;
@end

@interface IDFloatingCursorAssistantSpy : NSObject
@property(nonatomic) NSUInteger beginCount;
@property(nonatomic) NSUInteger updateCount;
@property(nonatomic) NSUInteger endCount;
@property(nonatomic) CGPoint beginPoint;
@property(nonatomic) CGPoint updatePoint;
@property(nonatomic) BOOL updateAnimated;
@property(nonatomic) NSUInteger resignedCount;
@property(nonatomic) NSUInteger detachCount;
@property(nonatomic) BOOL detachForce;
@property(nonatomic) NSUInteger clearCount;
@property(nonatomic) BOOL lastClearForce;
@property(nonatomic, strong) NSMutableArray<NSString *> *lifecycleCalls;
@property(nonatomic, strong) id forwardingTarget;
@end


// RETIRED (2026-09-15). It reads `.superpowers/sdd/floating-task-6-report.md` — a subagent workflow
// scratch report from an upstream session — and asserts it carries no stale disassembly addresses.
// This repository's standing rules forbid committing `.superpowers/` at all, so the file it audits
// can never exist here and the rule can never hold. Its sibling cases, which audit real source, stay.

@implementation IDFloatingCursorAssistantSpy
- (void)beginFloatingCursorAtPoint:(CGPoint)point {
    self.beginCount += 1;
    self.beginPoint = point;
}
- (void)updateFloatingCursorAtPoint:(CGPoint)point animated:(BOOL)animated {
    self.updateCount += 1;
    self.updatePoint = point;
    self.updateAnimated = animated;
}
- (void)endFloatingCursor { self.endCount += 1; }
- (void)resignedFirstResponder { self.resignedCount += 1; }
- (void)detach:(BOOL)force {
    self.detachCount += 1;
    self.detachForce = force;
    [self.lifecycleCalls addObject:force ? @"detach:YES" : @"detach:NO"];
}
- (void)clearGestureRecognizers:(BOOL)force {
    self.clearCount += 1;
    self.lastClearForce = force;
    [self.lifecycleCalls addObject:force ? @"clear:YES" : @"clear:NO"];
}
- (BOOL)respondsToSelector:(SEL)selector {
    return [super respondsToSelector:selector] ||
        [self.forwardingTarget respondsToSelector:selector];
}
- (id)forwardingTargetForSelector:(SEL)selector {
    return [self.forwardingTarget respondsToSelector:selector]
        ? self.forwardingTarget : [super forwardingTargetForSelector:selector];
}
@end

@interface IDFloatingCursorCompatibleAssistant : NSObject
@end

@implementation IDFloatingCursorCompatibleAssistant
- (void)selectionChanged {}
- (void)activateSelection {}
- (void)deactivateSelection {}
- (void)setSelectionDisplayVisible:(BOOL)value { (void)value; }
- (void)setNeedsSelectionDisplayUpdate {}
- (void)setGestureRecognizers {}
- (void)clearGestureRecognizers:(BOOL)value { (void)value; }
- (void)beginFloatingCursorAtPoint:(CGPoint)point { (void)point; }
- (void)updateFloatingCursorAtPoint:(CGPoint)point animated:(BOOL)animated {
    (void)point; (void)animated;
}
- (void)endFloatingCursor {}
- (void)resignedFirstResponder {}
- (void)detach:(BOOL)force { (void)force; }
@end

@interface IDFloatingCursorEditableBoundaryTextView : IDBlockTextView
@property(nonatomic) BOOL editableAtResignBoundary;
@end

@implementation IDFloatingCursorEditableBoundaryTextView
- (BOOL)resignFirstResponder {
    self.editableAtResignBoundary = self.isEditable;
    return [super resignFirstResponder];
}
@end

static void IDFloatingWrongSizeBegin(id self, SEL selector, CGSize size) {
    (void)self; (void)selector; (void)size;
}

typedef uint8_t IDFloatingWrongBoolType;

static NSString *IDFloatingExpectedInteractionInstallationHost(void) {
    return @"outer";
}

static NSSet<NSString *> *IDFloatingTopologyInteractionIdentities(
    NSDictionary *topology,
    BOOL allHosts) {
    NSMutableSet<NSString *> *identities = [NSMutableSet set];
    NSArray<NSString *> *hosts = allHosts
        ? @[@"outer", @"blockStack", @"external"]
        : @[topology[@"installationHost"] ?: @"none"];
    for (NSString *host in hosts) {
        [identities addObjectsFromArray:
            topology[@"hosts"][host][@"interactionIdentitySignature"] ?: @[]];
    }
    return identities.copy;
}

static BOOL IDFloatingTopologyHasOneActiveOwner(NSDictionary *topology) {
    return [topology[@"installationHost"] isEqualToString:
                IDFloatingExpectedInteractionInstallationHost()] &&
        [topology[@"liveHostCount"] isEqual:@1] &&
        [topology[@"duplicateRecognizerIdentityCount"] isEqual:@0] &&
        [topology[@"duplicateInteractionIdentityCount"] isEqual:@0];
}

static BOOL IDFloatingTopologyIsStableActive(NSDictionary *topology) {
    return IDFloatingTopologyHasOneActiveOwner(topology) &&
        [topology[@"stableForEpoch"] isEqual:@YES];
}

static void IDFloatingWrongIntegerUpdate(id self,
                                         SEL selector,
                                         CGPoint point,
                                         IDFloatingWrongBoolType animated) {
    (void)self; (void)selector; (void)point; (void)animated;
}

static NSInteger IDFloatingWrongResignedReturn(id self, SEL selector) {
    (void)self; (void)selector; return 0;
}

static void IDFloatingWrongDetachArgument(id self, SEL selector,
                                          IDFloatingWrongBoolType force) {
    (void)self; (void)selector; (void)force;
}

static NSMethodSignature *IDFloatingSignature(Class cls, NSString *selectorName) {
    Method method = class_getInstanceMethod(cls, NSSelectorFromString(selectorName));
    return method == NULL ? nil :
        [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
}

static void IDFloatingAssertSignature(XCTestCase *testCase,
                                      Class cls,
                                      NSString *selectorName,
                                      const char *returnType,
                                      NSArray<NSString *> *argumentTypes) {
    NSMethodSignature *signature = IDFloatingSignature(cls, selectorName);
    XCTAssertNotNil(signature, @"%@ %@", NSStringFromClass(cls), selectorName);
    if (signature == nil) return;
    XCTAssertTrue(strcmp(signature.methodReturnType, returnType) == 0,
                  @"%@ return=%s", selectorName, signature.methodReturnType);
    XCTAssertEqual(signature.numberOfArguments, argumentTypes.count);
    for (NSUInteger index = 0; index < MIN(signature.numberOfArguments,
                                           argumentTypes.count); index += 1) {
        XCTAssertTrue(strcmp([signature getArgumentTypeAtIndex:index],
                             argumentTypes[index].UTF8String) == 0,
                      @"%@ argument %lu=%s", selectorName, (unsigned long)index,
                      [signature getArgumentTypeAtIndex:index]);
    }
    (void)testCase;
}

@interface IDFloatingCursorContractTests : XCTestCase
@end

@implementation IDFloatingCursorContractTests

- (IDFloatingCursorAssistantSpy *)installAssistantSpyInView:
    (IDBlockTextView *)view {
    IDUIKitInteractionCapability *capability =
        view.id_interactionCapability;
    XCTAssertNotNil(capability);
    id original = capability.privateAssistant;
    IDFloatingCursorAssistantSpy *spy =
        [IDFloatingCursorAssistantSpy new];
    spy.forwardingTarget = original;
    capability.privateAssistant = spy;
    [self addTeardownBlock:^{
        if (view.id_interactionCapability == capability &&
            capability.privateAssistant == spy) {
            capability.privateAssistant = original;
        }
    }];
    return spy;
}

- (void)testPrivateUIKitContainsNoTextViewTokenJoiningOrRecognizerDuplicateClaim {
    NSString *root = IDEngineSourceRoot();
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"PrivateUIKit/IDPrivateUIKit.m")
        encoding:NSUTF8StringEncoding error:nil];
    XCTAssertFalse([source containsString:@"@\"UI\" @\"TextView\""]);
    XCTAssertFalse([source containsString:@"recognizerDuplicateCount"]);
}

- (void)testHostedTruthSourceContainsNoCrossTimeFusionSyntheticRetentionOrDeallocationNames {
    NSString *root = IDEngineSourceRoot();
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"UITests/IDFloatingCursorUITests.m")
        encoding:NSUTF8StringEncoding error:nil];
    XCTAssertFalse([source containsString:@"truthRetentionForLifecycle"]);
    XCTAssertFalse([source containsString:@"stockRetention = @{"]);
    XCTAssertFalse([source containsString:@"deallocation-after"]);
    XCTAssertTrue([source containsString:@"IDFloatingCursorTruthSnapshotIsAtomic"]);
    NSString *host = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"StockOracleHost/main.m")
        encoding:NSUTF8StringEncoding error:nil];
    XCTAssertTrue([host containsString:@"copyAtomicFloatingSnapshot"]);
}

- (void)testStockSessionObserverUsesValidatedIvarsInsteadOfSelectorGuessing {
    NSString *root = IDEngineSourceRoot();
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"PrivateUIKit/IDPrivateUIKit.m")
        encoding:NSUTF8StringEncoding error:nil];
    // The private names are spelled through their encoded table entries (`TGPrivateRuntimeNames.h`).
    XCTAssertTrue([source containsString:
        @"assistant, TGPN__floatingCursorSession().UTF8String, TGPN__UITextFloatingCursorSession()"]);
    XCTAssertTrue([source containsString:
        @"display, TGPN__activeFloatingCursorSession().UTF8String, TGPN__UITextFloatingCursorSession()"]);
    XCTAssertTrue([source containsString:@"IDPrivateTestingBoolIvar(session, TGPN__isValid().UTF8String"]);
    XCTAssertFalse([source containsString:
        @"NSSelectorFromString(TGPN__activeFloatingCursorSession())"]);
    XCTAssertFalse([source containsString:@"static __strong UITextPosition"]);
}

- (void)testBlockResignMatchesStockCleanupOrderWithoutAssistantResignedCallback {
    NSString *root = IDEngineSourceRoot();
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDBlockTextView.m")
        encoding:NSUTF8StringEncoding error:nil];
    NSRange start = [source rangeOfString:@"- (BOOL)resignFirstResponder {"];
    NSRange finish = [source rangeOfString:@"- (NSString *)text" options:0
        range:NSMakeRange(NSMaxRange(start), source.length - NSMaxRange(start))];
    XCTAssertNotEqual(start.location, NSNotFound);
    XCTAssertNotEqual(finish.location, NSNotFound);
    NSString *method = [source substringWithRange:
        NSMakeRange(start.location, finish.location - start.location)];
    XCTAssertFalse([method containsString:@"IDPrivateInteractionResignedFirstResponder"]);
    XCTAssertFalse([method containsString:@"id_updateSelectionPresentation"]);
    NSArray<NSString *> *ordered = @[@"[super resignFirstResponder]",
        @"[self.id_interactionCapability",
        @"setSelectionActive:NO visible:NO]",
        @"[self id_updateSelectionGestures]",
        @"IDPrivateRecordFloatingLifecycleEventForUITesting(self, @\"responderLoss\")"];
    NSUInteger previous = 0;
    for (NSString *needle in ordered) {
        NSRange range = [method rangeOfString:needle];
        XCTAssertNotEqual(range.location, NSNotFound, @"missing %@", needle);
        XCTAssertGreaterThanOrEqual(range.location, previous, @"out of order %@", needle);
        previous = NSMaxRange(range);
    }
}

- (void)testLiteralFloatingContainerCountBridgeOwnsEveryTruthStatus {
    NSString *root = IDEngineSourceRoot();
    NSDictionary<NSString *, NSString *> *sources = @{
        @"private": @"PrivateUIKit/IDPrivateUIKit.m",
        @"app": @"App/IDDemoViewController.m",
        @"stock": @"StockOracleHost/main.m",
    };
    for (NSString *name in sources) {
        NSString *source = [NSString stringWithContentsOfFile:
            IDEngineSourceFile(sources[name])
            encoding:NSUTF8StringEncoding error:nil];
        XCTAssertTrue([source containsString:
            @"IDPrivateFloatingContainerCreationCountForUITesting"], @"%@", name);
        XCTAssertFalse([source containsString:
            @"@(![lifecycle[@\"containerToken\"]"], @"%@", name);
    }
}

- (void)testStockFloatingContainerCountUsesContainerOwnedNumericTokens {
    NSString *root = IDEngineSourceRoot();
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"PrivateUIKit/IDPrivateUIKit.m")
        encoding:NSUTF8StringEncoding error:nil];
    NSRange start = [source rangeOfString:
        @"@interface IDPrivateFloatingContainerIdentityTracker"];
    NSRange finish = [source rangeOfString:
        @"@interface IDPrivateFloatingLifecycleWeakReferences" options:0
        range:NSMakeRange(NSMaxRange(start), source.length - NSMaxRange(start))];
    XCTAssertNotEqual(start.location, NSNotFound);
    XCTAssertNotEqual(finish.location, NSNotFound);
    NSString *trackerSource = [source substringWithRange:
        NSMakeRange(start.location, finish.location - start.location)];
    XCTAssertFalse([trackerSource containsString:@"NSMutableSet<NSValue *>"]);
    XCTAssertFalse([trackerSource containsString:@"valueWithPointer:"]);
    XCTAssertTrue([trackerSource containsString:
        @"NSMutableSet<NSNumber *> *seenIdentities"]);
    XCTAssertTrue([trackerSource containsString:
        @"IDPrivateFloatingContainerIdentityTokenKey"]);
    XCTAssertTrue([trackerSource containsString:@"objc_setAssociatedObject(container"]);
    XCTAssertTrue([trackerSource containsString:@"@synchronized"]);
}



- (void)testEditableAndSelectableTerminalEventsPublishAfterCleanupBoundaries {
    NSString *root = IDEngineSourceRoot();
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDBlockTextView.m")
        encoding:NSUTF8StringEncoding error:nil];
    NSArray<NSDictionary<NSString *, id> *> *methods = @[
        @{@"start": @"- (void)setEditable:(BOOL)editable {",
          @"finish": @"- (void)setSelectable:(BOOL)selectable {",
          @"ordered": @[@"[self resignFirstResponder]", @"_editable = editable",
              @"[self id_updateSelectionGestures]",
              @"IDPrivateRecordFloatingLifecycleEventForUITesting(self, @\"editableOff\")"]},
        @{@"start": @"- (void)setSelectable:(BOOL)selectable {",
          @"finish": @"- (BOOL)becomeFirstResponder {",
          @"ordered": @[@"_selectable = selectable",
              @"IDUIKitInteractionCapability *interaction =",
              @"_id_interactionCapability",
              @"[self resignFirstResponder]",
              @"[interaction clearGestureRecognizersForced:YES]",
              @"[interaction clearGestureRecognizersForced:NO]",
              @"[interaction detach]",
              @"self.id_interactionAssistant = nil",
              @"self.id_interactionCapability = nil",
              @"IDPrivateRecordFloatingLifecycleEventForUITesting(self, @\"selectableOff\")"]},
    ];
    for (NSDictionary<NSString *, id> *expectation in methods) {
        NSRange start = [source rangeOfString:expectation[@"start"]];
        NSRange finish = [source rangeOfString:expectation[@"finish"] options:0
            range:NSMakeRange(NSMaxRange(start), source.length - NSMaxRange(start))];
        XCTAssertNotEqual(start.location, NSNotFound);
        XCTAssertNotEqual(finish.location, NSNotFound);
        NSString *method = [source substringWithRange:
            NSMakeRange(start.location, finish.location - start.location)];
        NSUInteger previous = 0;
        for (NSString *needle in expectation[@"ordered"]) {
            NSRange range = [method rangeOfString:needle];
            XCTAssertNotEqual(range.location, NSNotFound, @"missing %@", needle);
            XCTAssertGreaterThanOrEqual(range.location, previous, @"out of order %@", needle);
            previous = NSMaxRange(range);
        }
        if ([expectation[@"start"] containsString:@"setSelectable:"]) {
            XCTAssertFalse([method containsString:@"self.id_interactionAssistant);"]);
        }
    }
}

- (void)testTerminalObserverUsesUniformCommonModeZeroTimerAfterCleanup {
    NSString *root = IDEngineSourceRoot();
    NSString *privateSource = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"PrivateUIKit/IDPrivateUIKit.m")
        encoding:NSUTF8StringEncoding error:nil];
    NSString *textViewSource = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDBlockTextView.m")
        encoding:NSUTF8StringEncoding error:nil];

    NSRange helperStart = [privateSource rangeOfString:
        @"void IDPrivateRecordFloatingLifecycleEventForUITesting("];
    XCTAssertNotEqual(helperStart.location, NSNotFound);
    if (helperStart.location == NSNotFound) return;
    NSRange helperFinish = [privateSource rangeOfString:
        @"void IDPrivateSetFloatingLifecycleTerminalObserverForUITesting(" options:0
        range:NSMakeRange(NSMaxRange(helperStart),
                         privateSource.length - NSMaxRange(helperStart))];
    XCTAssertNotEqual(helperFinish.location, NSNotFound);
    if (helperFinish.location == NSNotFound) return;
    NSString *helper = [privateSource substringWithRange:NSMakeRange(
        helperStart.location, helperFinish.location - helperStart.location)];
    XCTAssertTrue([helper containsString:@"timerWithTimeInterval:0"]);
    XCTAssertTrue([helper containsString:@"[[NSRunLoop mainRunLoop] addTimer:timer"]);
    XCTAssertTrue([helper containsString:@"forMode:NSRunLoopCommonModes"]);
    XCTAssertFalse([helper containsString:@"dispatch_async(dispatch_get_main_queue()"]);
    XCTAssertFalse([privateSource containsString:
        @"IDPrivateDeferFloatingLifecycleTerminalEventForUITesting"]);
    XCTAssertFalse([textViewSource containsString:
        @"IDPrivateDeferFloatingLifecycleTerminalEventForUITesting"]);
}

- (void)testRecognizerIdentityBaselineFreezesOnlyAtImmutableHeldCapture {
    NSString *root = IDEngineSourceRoot();
    NSString *privateSource = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"PrivateUIKit/IDPrivateUIKit.m")
        encoding:NSUTF8StringEncoding error:nil];
    NSString *appSource = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"App/IDDemoViewController.m")
        encoding:NSUTF8StringEncoding error:nil];
    NSString *freeze = @"IDPrivateFreezeRecognizerBaselineAtHeldCapture(editor);";
    XCTAssertEqual([privateSource componentsSeparatedByString:freeze].count, 2U);
    XCTAssertFalse([appSource containsString:@"IDPrivateResetRecognizerBaselineForUITesting"]);

    NSRange start = [privateSource rangeOfString:
        @"- (void)beginHeldSnapshotPollingForTerminalEvent:"];
    NSRange finish = [privateSource rangeOfString:
        @"- (void)id_capturePostLiftSnapshotAtTarget:" options:0
        range:NSMakeRange(NSMaxRange(start), privateSource.length - NSMaxRange(start))];
    XCTAssertNotEqual(start.location, NSNotFound);
    XCTAssertNotEqual(finish.location, NSNotFound);
    if (start.location == NSNotFound || finish.location == NSNotFound) return;
    NSString *method = [privateSource substringWithRange:
        NSMakeRange(start.location, finish.location - start.location)];
    NSRange held = [method rangeOfString:@"if (held) {"];
    NSRange freezeRange = [method rangeOfString:freeze];
    NSRange snapshot = [method rangeOfString:@"self.heldSnapshot ="];
    XCTAssertNotEqual(held.location, NSNotFound);
    XCTAssertNotEqual(freezeRange.location, NSNotFound);
    XCTAssertNotEqual(snapshot.location, NSNotFound);
    XCTAssertLessThan(NSMaxRange(held), freezeRange.location);
    XCTAssertLessThan(NSMaxRange(freezeRange), snapshot.location);
}

- (void)testReleaseInterruptionObservesActionOnCurrentReferencesBeforeTerminal {
    NSString *root = IDEngineSourceRoot();
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"StockOracleHost/main.m")
        encoding:NSUTF8StringEncoding error:nil];
    NSRange start = [source rangeOfString:
        @"if ([releaseMode isEqualToString:@\"after-normal\"] ||"];
    NSRange finish = [source rangeOfString:
        @"} else if (truthTerminalEvent.length > 0) {" options:0
        range:NSMakeRange(NSMaxRange(start), source.length - NSMaxRange(start))];
    XCTAssertNotEqual(start.location, NSNotFound);
    XCTAssertNotEqual(finish.location, NSNotFound);
    if (start.location == NSNotFound || finish.location == NSNotFound) return;
    NSString *branch = [source substringWithRange:
        NSMakeRange(start.location, finish.location - start.location)];
    NSRange actionObserver = [branch rangeOfString:
        @"IDPrivateSetFloatingLifecycleActionObserverForUITesting("];
    NSRange currentReferences = [branch rangeOfString:
        @"[status.references markActionObservationAtEpoch:actionEpoch"];
    NSRange terminalObserver = [branch rangeOfString:
        @"IDPrivateSetFloatingLifecycleTerminalObserverForUITesting("];
    XCTAssertNotEqual(actionObserver.location, NSNotFound);
    XCTAssertNotEqual(currentReferences.location, NSNotFound);
    XCTAssertNotEqual(terminalObserver.location, NSNotFound);
    XCTAssertLessThan(actionObserver.location, terminalObserver.location);
    XCTAssertLessThan(currentReferences.location, terminalObserver.location);
}

- (void)testLifecycleRecognizerAuthorityUsesOnlyImmutableStoredPhases {
    NSString *root = IDEngineSourceRoot();
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"UITests/IDFloatingCursorUITests.m")
        encoding:NSUTF8StringEncoding error:nil];
    NSRange start = [source rangeOfString:
        @"- (void)assertLifecycleStock:(IDFloatingCursorLifecycleRun *)stock"];
    NSRange finish = [source rangeOfString:
        @"- (void)testLifecycleInterruptionTimingRejectsActionAfterKeyboardLift" options:0
        range:NSMakeRange(NSMaxRange(start), source.length - NSMaxRange(start))];
    XCTAssertNotEqual(start.location, NSNotFound);
    XCTAssertNotEqual(finish.location, NSNotFound);
    if (start.location == NSNotFound || finish.location == NSNotFound) return;
    NSString *method = [source substringWithRange:
        NSMakeRange(start.location, finish.location - start.location)];
    NSRange mutableStart = [method rangeOfString:
        @"stock.initialTrace, stock.heldTrace, stock.endedTrace"];
    NSRange storedStart = [method rangeOfString:
        @"NSArray<NSDictionary *> *stockStored = @["];
    XCTAssertNotEqual(mutableStart.location, NSNotFound);
    XCTAssertNotEqual(storedStart.location, NSNotFound);
    XCTAssertLessThan(mutableStart.location, storedStart.location);
    NSString *mutableChecks = [method substringWithRange:NSMakeRange(
        mutableStart.location, storedStart.location - mutableStart.location)];
    XCTAssertFalse([mutableChecks containsString:@"recognizer"]);
    NSString *storedAuthority = [method substringFromIndex:storedStart.location];
    XCTAssertFalse([storedAuthority containsString:@"initialTrace"]);
    XCTAssertTrue([storedAuthority containsString:
        @"stock.heldTrace, stock.endedTrace, stock.immediateTrace"]);
    XCTAssertTrue([storedAuthority containsString:
        @"stock.settledTrace, stock.quiescedTrace"]);
    XCTAssertTrue([storedAuthority containsString:
        @"stock.heldTrace[@\"recognizerBaselineCount\"]"]);
    XCTAssertTrue([storedAuthority containsString:@"recognizerUnexpectedNewCount"]);
    XCTAssertTrue([storedAuthority containsString:@"recognizerSubsetOfBaseline"]);
    XCTAssertTrue([storedAuthority containsString:@"recognizerIdentitySignature"]);
}

- (void)testEditableOffResignsWhileStillEditable {
    IDFloatingCursorEditableBoundaryTextView *view =
        [[IDFloatingCursorEditableBoundaryTextView alloc]
            initWithFrame:CGRectMake(0, 0, 370, 360)
            attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"editable"]]];
    XCTAssertTrue(view.isEditable);
    view.editable = NO;
    XCTAssertTrue(view.editableAtResignBoundary);
    XCTAssertFalse(view.isEditable);
}

- (void)testEqualSnapshotTargetsCoalesceInExactThenPostLiftOrder {
    NSString *root = IDEngineSourceRoot();
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"PrivateUIKit/IDPrivateUIKit.m")
        encoding:NSUTF8StringEncoding error:nil];
    NSRange start = [source rangeOfString:@"- (void)scheduleReleaseSnapshots {"];
    NSRange finish = [source rangeOfString:@"- (NSDictionary<NSString *, id> *)copyTerminalSnapshot"
        options:0 range:NSMakeRange(NSMaxRange(start), source.length - NSMaxRange(start))];
    XCTAssertNotEqual(start.location, NSNotFound);
    XCTAssertNotEqual(finish.location, NSNotFound);
    NSString *method = [source substringWithRange:
        NSMakeRange(start.location, finish.location - start.location)];
    XCTAssertTrue([method containsString:@"BOOL coalescesEqualTargets"]);
    XCTAssertTrue([method containsString:@"if (coalescesEqualTargets)"]);
    NSRange exact = [method rangeOfString:@"self.exactSnapshot ="];
    NSRange post = [method rangeOfString:@"[self id_capturePostLiftSnapshotAtTarget:"];
    XCTAssertNotEqual(exact.location, NSNotFound);
    XCTAssertNotEqual(post.location, NSNotFound);
    XCTAssertLessThan(NSMaxRange(exact), post.location);
}

- (void)testStockOracleHostContainsNoPrivateRuntimeKnowledgeOrSyntheticLifecycleCounters {
    NSString *testsDirectory = [@(__FILE__) stringByDeletingLastPathComponent];
    NSString *root = [testsDirectory stringByDeletingLastPathComponent];
    NSString *path = IDEngineSourceFile(@"StockOracleHost/main.m");
    NSString *source = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    XCTAssertNotNil(source);
    for (NSString *forbidden in @[
        @"<objc/message.h>", @"<objc/runtime.h>", @"objc_msgSend",
        @"objc_msgSendSuper", @"NSSelectorFromString", @"class_getInstanceMethod",
        @"method_setImplementation", @"class_getInstanceVariable", @"object_getIvar",
        @"_selectionViewManager", @"_activeFloatingCursorSession",
        @"_floatingCursorSession", @"_autoscroll", @"_textAutoscroll",
    ]) {
        XCTAssertFalse([source containsString:forbidden], @"escaped token=%@", forbidden);
    }
    NSRegularExpression *buttonCounterMutation = [NSRegularExpression
        regularExpressionWithPattern:@"button\\([^;]+lifecycle[A-Za-z]+Count\\s*\\+="
                              options:NSRegularExpressionDotMatchesLineSeparators error:nil];
    XCTAssertEqual([buttonCounterMutation numberOfMatchesInString:source options:0
        range:NSMakeRange(0, source.length)], 0U);
}

- (IDBlockTextView *)view {
    UIFont *font = [UIFont systemFontOfSize:20.0];
    NSArray<NSString *> *strings = @[
        @"First wrapped paragraph contains constellation and punctuation for precise cursor travel.",
        @"Second wrapped paragraph spans enough text to test vertical floating-cursor movement.",
        @"Third paragraph provides a stable lower destination without leaving the viewport.",
    ];
    NSMutableArray *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc] initWithString:string
            attributes:@{NSFontAttributeName: font, NSForegroundColorAttributeName: UIColor.blackColor}]];
    }
    IDBlockTextView *view = [[IDBlockTextView alloc] initWithFrame:CGRectMake(0, 0, 370, 360)
                                                   attributedBlocks:blocks];
    view.font = font;
    return view;
}

- (void)testFloatingLifecycleTopologyPreservesOneOwnerThroughTerminalPaths {
    IDBlockTextView *view = [self view];
    UIViewController *controller = [UIViewController new];
    UIWindow *window = [[UIWindow alloc] initWithFrame:view.bounds];
    window.rootViewController = controller;
    [controller.view addSubview:view];
    [window makeKeyAndVisible];

    IDPrivateResetInteractionHostTopologyBaselineForUITesting(
        view, view.id_blockStack, nil);
    NSDictionary *initial = IDPrivateCopyInteractionHostTopologyForUITesting(
        view, view.id_blockStack, nil);
    XCTAssertTrue(IDFloatingTopologyIsStableActive(initial), @"%@", initial);

    XCTAssertTrue([view becomeFirstResponder]);
    [view beginFloatingCursorAtPoint:CGPointMake(30, 30)];
    [view updateFloatingCursorAtPoint:CGPointMake(45, 30) animated:YES];
    [view endFloatingCursor];
    XCTAssertTrue(IDFloatingTopologyIsStableActive(
        IDPrivateCopyInteractionHostTopologyForUITesting(
            view, view.id_blockStack, nil)));
    XCTAssertTrue([view resignFirstResponder]);
    NSDictionary *resigned =
        IDPrivateCopyInteractionHostTopologyForUITesting(
            view, view.id_blockStack, nil);
    XCTAssertTrue(IDFloatingTopologyHasOneActiveOwner(resigned), @"%@", resigned);
    IDPrivateResetInteractionHostTopologyBaselineForUITesting(
        view, view.id_blockStack, nil);
    XCTAssertTrue(IDFloatingTopologyIsStableActive(
        IDPrivateCopyInteractionHostTopologyForUITesting(
            view, view.id_blockStack, nil)));

    NSDictionary *preSelectableOff =
        IDPrivateCopyInteractionHostTopologyForUITesting(
            view, view.id_blockStack, nil);
    NSSet *activeIdentities =
        IDFloatingTopologyInteractionIdentities(preSelectableOff, NO);
    view.selectable = NO;
    NSDictionary *cleared = IDPrivateCopyInteractionHostTopologyForUITesting(
        view, view.id_blockStack, nil);
    NSMutableSet *removed = [activeIdentities mutableCopy];
    [removed minusSet:IDFloatingTopologyInteractionIdentities(cleared, YES)];
    XCTAssertGreaterThan(removed.count, 0U, @"active=%@ cleared=%@",
                         preSelectableOff, cleared);

    view.selectable = YES;
    IDPrivateResetInteractionHostTopologyBaselineForUITesting(
        view, view.id_blockStack, nil);
    NSDictionary *restored = IDPrivateCopyInteractionHostTopologyForUITesting(
        view, view.id_blockStack, nil);
    XCTAssertTrue(IDFloatingTopologyIsStableActive(restored), @"%@", restored);
    [view id_tearDownEditorGraph];
    NSDictionary *tornDown = IDPrivateCopyInteractionHostTopologyForUITesting(
        view, view.id_blockStack, nil);
    NSMutableSet *removedOnTearDown =
        [IDFloatingTopologyInteractionIdentities(restored, NO) mutableCopy];
    [removedOnTearDown minusSet:IDFloatingTopologyInteractionIdentities(
        tornDown, YES)];
    XCTAssertGreaterThan(removedOnTearDown.count, 0U,
                         @"restored=%@ tornDown=%@", restored, tornDown);
    XCTAssertTrue(IDFloatingTopologyHasOneActiveOwner(tornDown), @"%@", tornDown);
    window.hidden = YES;
}

- (void)testFloatingCursorHostForwardsExactPointsAnimationAndLifecycleOnly {
    IDBlockTextView *view = [self view];
    NSRange initial = [view id_NSRangeForTextRange:view.selectedTextRange];
    NSUInteger creations = view.id_selectionPresentationBackend.selectionContainerCreationCount;
    IDFloatingCursorAssistantSpy *spy =
        [self installAssistantSpyInView:view];

    CGPoint begin = CGPointMake(17.25, 33.75);
    CGPoint firstUpdate = CGPointMake(41.5, 33.75);
    CGPoint secondUpdate = CGPointMake(65.5, 15.75);
    [view beginFloatingCursorAtPoint:begin];
    XCTAssertEqual(spy.beginCount, 1U);
    XCTAssertTrue(CGPointEqualToPoint(spy.beginPoint, begin));
    [view updateFloatingCursorAtPoint:firstUpdate];
    XCTAssertEqual(spy.updateCount, 1U);
    XCTAssertTrue(CGPointEqualToPoint(spy.updatePoint, firstUpdate));
    XCTAssertFalse(spy.updateAnimated);
    [view updateFloatingCursorAtPoint:secondUpdate animated:YES];
    XCTAssertEqual(spy.updateCount, 2U);
    XCTAssertTrue(CGPointEqualToPoint(spy.updatePoint, secondUpdate));
    XCTAssertTrue(spy.updateAnimated);
    [view endFloatingCursor];
    XCTAssertEqual(spy.endCount, 1U);

    XCTAssertTrue(NSEqualRanges([view id_NSRangeForTextRange:view.selectedTextRange], initial));
    XCTAssertEqual(view.id_selectionPresentationBackend.selectionContainerCreationCount,
                   creations);
}

- (void)testResponderLossAndGraphTeardownUseRecoveredAssistantLifecycleOperations {
    IDBlockTextView *view = [self view];
    IDFloatingCursorAssistantSpy *spy =
        [self installAssistantSpyInView:view];

    [view.id_interactionCapability id_resignedFirstResponder];
    XCTAssertEqual(spy.resignedCount, 1U);
    XCTAssertEqual(spy.endCount, 0U);

    [view id_tearDownEditorGraph];
    XCTAssertEqual(spy.detachCount, 1U);
    XCTAssertTrue(spy.detachForce);
    XCTAssertNil(view.id_interactionCapability);
    XCTAssertNil(view.id_interactionAssistant);
}

- (void)testSelectableTeardownCanSendRecoveredNonforcedGestureCleanup {
    IDFloatingCursorAssistantSpy *spy = [IDFloatingCursorAssistantSpy new];
    IDPrivateInteractionClearGestureRecognizersNonforced(spy);
    XCTAssertEqual(spy.clearCount, 1U);
    XCTAssertFalse(spy.lastClearForce);
}

- (void)testSelectableOffReleasesAssistantAndOnReconstructsIt {
    IDBlockTextView *view = [self view];
    __weak id weakOriginalAssistant = view.id_interactionAssistant;

    view.selectable = NO;

    XCTAssertNil(view.id_interactionAssistant);
    XCTAssertNil(weakOriginalAssistant);

    view.selectable = YES;

    XCTAssertNotNil(view.id_interactionAssistant);
}

- (void)testEditableTransitionRefreshesGesturesAfterBitChangeForBothDirections {
    NSString *root = IDEngineSourceRoot();
    NSString *source = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"TextView/IDBlockTextView.m")
        encoding:NSUTF8StringEncoding error:nil];
    NSRange start = [source rangeOfString:@"- (void)setEditable:(BOOL)editable {"];
    NSRange finish = [source rangeOfString:@"- (void)setSelectable:(BOOL)selectable {" options:0
        range:NSMakeRange(NSMaxRange(start), source.length - NSMaxRange(start))];
    XCTAssertNotEqual(start.location, NSNotFound);
    XCTAssertNotEqual(finish.location, NSNotFound);
    if (start.location == NSNotFound || finish.location == NSNotFound) return;
    NSString *setter = [source substringWithRange:
        NSMakeRange(start.location, finish.location - start.location)];
    NSString *refresh = @"[self id_updateSelectionGestures];";
    XCTAssertEqual([setter componentsSeparatedByString:refresh].count, 2U);
    NSRange bitChange = [setter rangeOfString:@"_editable = editable;"];
    NSRange refreshRange = [setter rangeOfString:refresh];
    NSRange offOnly = [setter rangeOfString:@"if (!editable) {" options:0
        range:NSMakeRange(NSMaxRange(bitChange), setter.length - NSMaxRange(bitChange))];
    NSRange terminal = [setter rangeOfString:
        @"IDPrivateRecordFloatingLifecycleEventForUITesting(self, @\"editableOff\")"];
    XCTAssertNotEqual(bitChange.location, NSNotFound);
    XCTAssertNotEqual(refreshRange.location, NSNotFound);
    XCTAssertNotEqual(offOnly.location, NSNotFound);
    XCTAssertNotEqual(terminal.location, NSNotFound);
    XCTAssertLessThan(NSMaxRange(bitChange), refreshRange.location);
    XCTAssertLessThan(NSMaxRange(refreshRange), offOnly.location);
    XCTAssertLessThan(NSMaxRange(offOnly), terminal.location);
}

- (void)testSelectableOffDetachesAfterGestureCleanupWhileAssistantIsReachable {
    IDBlockTextView *view = [self view];
    IDFloatingCursorAssistantSpy *spy =
        [self installAssistantSpyInView:view];
    spy.lifecycleCalls = [NSMutableArray array];

    view.selectable = NO;

    XCTAssertEqualObjects(spy.lifecycleCalls,
                          (@[@"clear:YES", @"clear:NO", @"detach:YES"]));
    XCTAssertEqual(spy.detachCount, 1U);
    XCTAssertTrue(spy.detachForce);
    XCTAssertNil(view.id_interactionAssistant);
    XCTAssertNil(view.id_interactionCapability);
}

- (void)testStockFloatingCursorTraceSelectorsHaveExactRuntimeABIs {
    NSString *objectType = [NSString stringWithUTF8String:@encode(id)];
    NSString *selectorType = [NSString stringWithUTF8String:@encode(SEL)];
    NSString *pointType = [NSString stringWithUTF8String:@encode(CGPoint)];
    NSString *boolType = [NSString stringWithUTF8String:@encode(BOOL)];
    NSArray *hidden = @[objectType, selectorType];
    NSArray *point = @[objectType, selectorType, pointType];
    NSArray *pointAnimated = @[objectType, selectorType, pointType, boolType];
    NSArray *pointObject = @[objectType, selectorType, pointType, objectType];
    NSArray *pointTwoBools = @[objectType, selectorType, pointType, boolType, boolType];
    NSArray *twoBools = @[objectType, selectorType, boolType, boolType];
    NSArray *object = @[objectType, selectorType, objectType];
    NSArray *boolValue = @[objectType, selectorType, boolType];
    IDFloatingAssertSignature(self, UITextView.class, @"beginFloatingCursorAtPoint:",
                              @encode(void), point);
    IDFloatingAssertSignature(self, UITextView.class, @"updateFloatingCursorAtPoint:",
                              @encode(void), point);
    IDFloatingAssertSignature(self, UITextView.class, @"updateFloatingCursorAtPoint:animated:",
                              @encode(void), pointAnimated);
    IDFloatingAssertSignature(self, UITextView.class, @"endFloatingCursor",
                              @encode(void), hidden);
    IDBlockTextView *view = [self view];
    Class assistantClass = [view.id_interactionAssistant class];
    IDFloatingAssertSignature(self, assistantClass, @"beginFloatingCursorAtPoint:",
                              @encode(void), point);
    IDFloatingAssertSignature(self, assistantClass, @"updateFloatingCursorAtPoint:animated:",
                              @encode(void), pointAnimated);
    IDFloatingAssertSignature(self, assistantClass, @"endFloatingCursor",
                              @encode(void), hidden);
    IDFloatingAssertSignature(self, assistantClass, @"setSelectionWithPoint:",
                              @encode(void), point);
    IDFloatingAssertSignature(self, assistantClass, @"extendSelectionToPoint:",
                              @encode(void), point);
    IDFloatingAssertSignature(self, assistantClass, @"extendSelectionToLoupeOrSetToPoint:",
                              @encode(void), point);
    IDFloatingAssertSignature(self, assistantClass, @"startAutoscroll:",
                              @encode(void), point);
    IDFloatingAssertSignature(self, assistantClass, @"updateAutoscroll:",
                              @encode(void), object);
    IDFloatingAssertSignature(self, assistantClass, @"cancelAutoscroll",
                              @encode(void), hidden);
    IDFloatingAssertSignature(self, assistantClass, @"rangeSelectionCanceled",
                              @encode(void), hidden);
    IDFloatingAssertSignature(self, assistantClass,
                              @"textRangeAdjustmentInteractionWasCancelled:",
                              @encode(void), object);
    IDFloatingAssertSignature(self, assistantClass, @"resignedFirstResponder",
                              @encode(void), hidden);

    Class displayInteraction = NSClassFromString(@"UITextSelectionDisplayInteraction");
    IDFloatingAssertSignature(self, displayInteraction,
                              @"_beginFloatingCursorSessionAtPoint:inContainer:",
                              @encode(id), pointObject);
    IDFloatingAssertSignature(self, displayInteraction,
                              @"_setCursorFadedHiddenForFloatingCursor:animated:",
                              @encode(void), twoBools);

    Class session = NSClassFromString(@"_UITextFloatingCursorSession");
    IDFloatingAssertSignature(self, session, @"updateWithPoint:inContainer:animated:",
                              @encode(void),
                              @[objectType, selectorType, pointType, objectType, boolType]);
    IDFloatingAssertSignature(self, session,
                              @"floatingCursorPositionForPoint:lineSnapping:",
                              @encode(CGPoint), pointAnimated);
    IDFloatingAssertSignature(self, session,
                              @"_updateCursorFadedHiddenForFloatingCursorAtPoint:",
                              @encode(void), point);
    IDFloatingAssertSignature(self, session, @"_invalidate", @encode(void), hidden);
    IDFloatingAssertSignature(self, session, @"_invalidateAnimated:",
                              @encode(void), boolValue);

    Class selectionView = NSClassFromString(@"UITextSelectionView");
    IDFloatingAssertSignature(self, selectionView, @"beginFloatingCursorAtPoint:",
                              @encode(void), point);
    IDFloatingAssertSignature(self, selectionView,
                              @"floatingCursorPositionForPoint:lineSnapping:",
                              @encode(CGPoint), pointAnimated);
    IDFloatingAssertSignature(self, selectionView, @"updateFloatingCursorAtPoint:animated:",
                              @encode(void), pointAnimated);
    IDFloatingAssertSignature(self, selectionView, @"endFloatingCursor",
                              @encode(void), hidden);

    Class selection = NSClassFromString(@"UITextSelection");
    IDFloatingAssertSignature(self, selection, @"updateBaseAndInitialExtent",
                              @encode(void), hidden);
    IDFloatingAssertSignature(self, selection,
                              @"setRangedSelectionExtentPoint:baseIsStart:allowFlipping:",
                              @encode(BOOL), pointTwoBools);
}

- (void)testAssistantPreflightRejectsCGSizeForCGPointAndSameSizedNonBoolForBOOL {
    XCTAssertEqual(sizeof(IDFloatingWrongBoolType), sizeof(BOOL));
    XCTAssertNotEqual(strcmp(@encode(IDFloatingWrongBoolType), @encode(BOOL)), 0);
    static Class wrongSizeClass;
    static Class wrongIntegerClass;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wrongSizeClass = objc_allocateClassPair(IDFloatingCursorCompatibleAssistant.class,
                                                "IDFloatingCursorWrongSizeAssistant", 0);
        class_addMethod(wrongSizeClass, @selector(beginFloatingCursorAtPoint:),
                        (IMP)IDFloatingWrongSizeBegin, "v@:{CGSize=dd}");
        objc_registerClassPair(wrongSizeClass);
        wrongIntegerClass = objc_allocateClassPair(IDFloatingCursorCompatibleAssistant.class,
                                                   "IDFloatingCursorWrongIntegerAssistant", 0);
        NSString *wrongIntegerEncoding = [NSString stringWithFormat:
            @"v@:%s%s", @encode(CGPoint), @encode(IDFloatingWrongBoolType)];
        class_addMethod(wrongIntegerClass,
                        @selector(updateFloatingCursorAtPoint:animated:),
                        (IMP)IDFloatingWrongIntegerUpdate, wrongIntegerEncoding.UTF8String);
        objc_registerClassPair(wrongIntegerClass);
    });
    XCTAssertThrowsSpecificNamed([IDPrivateUIKit requireInteractionAssistant:[wrongSizeClass new]
                                                                          stage:@"wrong size"],
                                 NSException, NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed([IDPrivateUIKit requireInteractionAssistant:[wrongIntegerClass new]
                                                                          stage:@"wrong integer"],
                                 NSException, NSInternalInconsistencyException);
}

- (void)testAssistantPreflightRejectsWrongResponderAndDetachLifecycleABIs {
    static Class wrongResignedClass;
    static Class wrongDetachClass;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wrongResignedClass = objc_allocateClassPair(
            IDFloatingCursorCompatibleAssistant.class,
            "IDFloatingWrongResignedAssistant", 0);
        class_addMethod(wrongResignedClass,
                        NSSelectorFromString(@"resignedFirstResponder"),
                        (IMP)IDFloatingWrongResignedReturn, "q@:");
        objc_registerClassPair(wrongResignedClass);
        wrongDetachClass = objc_allocateClassPair(
            IDFloatingCursorCompatibleAssistant.class,
            "IDFloatingWrongDetachAssistant", 0);
        NSString *encoding = [NSString stringWithFormat:
            @"v@:%s", @encode(IDFloatingWrongBoolType)];
        class_addMethod(wrongDetachClass, NSSelectorFromString(@"detach:"),
                        (IMP)IDFloatingWrongDetachArgument, encoding.UTF8String);
        objc_registerClassPair(wrongDetachClass);
    });
    XCTAssertThrowsSpecificNamed(
        [IDPrivateUIKit requireInteractionAssistant:[wrongResignedClass new]
                                              stage:@"wrong resigned ABI"],
        NSException, NSInternalInconsistencyException);
    XCTAssertThrowsSpecificNamed(
        [IDPrivateUIKit requireInteractionAssistant:[wrongDetachClass new]
                                              stage:@"wrong detach ABI"],
        NSException, NSInternalInconsistencyException);
}

@end
