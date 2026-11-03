#import "IDFloatingCursorTestSupport.h"

#import <QuartzCore/QuartzCore.h>

@implementation IDFloatingCursorHoldObservation
@end

NSValue *IDFloatingCursorStatusValue(IDFloatingCursorStatus status) {
    return [NSValue value:&status withObjCType:@encode(IDFloatingCursorStatus)];
}

IDFloatingCursorStatus IDFloatingCursorStatusFromValue(NSValue *value) {
    IDFloatingCursorStatus status = {0};
    if (strcmp(value.objCType, @encode(IDFloatingCursorStatus)) == 0) {
        [value getValue:&status size:sizeof(status)];
    }
    return status;
}

static NSUInteger IDFloatingActiveEndpoint(IDFloatingCursorStatus status,
                                           NSUInteger fixedOffset) {
    if (status.selection.length == 0) return status.selection.location;
    if (status.selection.location == fixedOffset) return NSMaxRange(status.selection);
    if (NSMaxRange(status.selection) == fixedOffset) return status.selection.location;
    return NSNotFound;
}

NSUInteger IDFloatingCursorFirstDirectionalProgressIndex(
    IDFloatingCursorStatus initial, NSArray<NSValue *> *samples, BOOL lower) {
    for (NSUInteger index = 0; index < samples.count; index += 1) {
        IDFloatingCursorStatus sample = IDFloatingCursorStatusFromValue(samples[index]);
        NSUInteger active = IDFloatingActiveEndpoint(sample, initial.selection.location);
        BOOL endpointMovesInDirection = active != NSNotFound &&
            (lower ? active > initial.selection.location
                   : active < initial.selection.location);
        BOOL viewportMovesInDirection = lower
            ? sample.contentOffset.y > initial.contentOffset.y
            : sample.contentOffset.y < initial.contentOffset.y;
        if (endpointMovesInDirection && viewportMovesInDirection) return index;
    }
    return NSNotFound;
}

BOOL IDFloatingCursorHeldCaptureIsAtomic(
    IDFloatingCursorStatus before,
    IDFloatingCursorStatus after,
    IDFloatingCursorObservationPhase beforePhase,
    IDFloatingCursorObservationPhase afterPhase,
    CFTimeInterval screenshotCompletionTime,
    CFTimeInterval afterReadCompletionTime,
    CFTimeInterval liftDeadline) {
    return beforePhase == IDFloatingCursorObservationPhaseHeldAfterDirectionalProgress &&
        afterPhase == beforePhase && screenshotCompletionTime < liftDeadline &&
        afterReadCompletionTime < liftDeadline &&
        NSEqualRanges(before.selection, after.selection) &&
        before.startAffinity == after.startAffinity &&
        before.endAffinity == after.endAffinity &&
        CGPointEqualToPoint(before.contentOffset, after.contentOffset);
}

BOOL IDFloatingCursorHeldCaptureShouldRetry(BOOL retainedAtomicCapture,
                                            CFTimeInterval now,
                                            CFTimeInterval liftDeadline) {
    return !retainedAtomicCapture && now < liftDeadline;
}

CFTimeInterval IDFloatingCursorMonotonicTime(void) {
    return CACurrentMediaTime();
}

static void IDFloatingRecordFailure(XCTestCase *testCase, NSString *description) {
    [testCase recordIssue:[[XCTIssue alloc] initWithType:XCTIssueTypeAssertionFailure
                                      compactDescription:description]];
}

static BOOL IDFloatingIsNumber(id value) {
    return [value isKindOfClass:NSNumber.class] &&
        CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID();
}

static BOOL IDFloatingFiniteNumber(id value, CGFloat *result) {
    if (!IDFloatingIsNumber(value) || !isfinite([value doubleValue])) return NO;
    if (result != NULL) *result = (CGFloat)[value doubleValue];
    return YES;
}

static BOOL IDFloatingUnsignedNumber(id value, NSUInteger *result) {
    if (!IDFloatingIsNumber(value)) return NO;
    NSDecimal number = [value decimalValue];
    NSNumber *zeroValue = @0;
    NSNumber *maximumValue = [NSNumber numberWithUnsignedInteger:NSUIntegerMax];
    NSDecimal zero = zeroValue.decimalValue;
    NSDecimal maximum = maximumValue.decimalValue;
    if (NSDecimalIsNotANumber(&number)) return NO;
    NSDecimal integral = {0};
    NSDecimalRound(&integral, &number, 0, NSRoundPlain);
    if (NSDecimalCompare(&number, &integral) != NSOrderedSame ||
        NSDecimalCompare(&number, &zero) == NSOrderedAscending ||
        NSDecimalCompare(&number, &maximum) == NSOrderedDescending) {
        return NO;
    }
    if (result != NULL) {
        *result = (NSUInteger)[[NSDecimalNumber decimalNumberWithDecimal:number]
            unsignedLongLongValue];
    }
    return YES;
}

static BOOL IDFloatingExactKeys(NSDictionary *dictionary, NSArray<NSString *> *keys) {
    return [dictionary isKindOfClass:NSDictionary.class] &&
        [[NSSet setWithArray:dictionary.allKeys] isEqualToSet:[NSSet setWithArray:keys]];
}

static BOOL IDFloatingParsePoint(id value, CGPoint *result) {
    if (!IDFloatingExactKeys(value, @[@"x", @"y"])) return NO;
    NSDictionary *dictionary = value;
    CGPoint point = CGPointZero;
    if (!IDFloatingFiniteNumber(dictionary[@"x"], &point.x) ||
        !IDFloatingFiniteNumber(dictionary[@"y"], &point.y)) return NO;
    if (result != NULL) *result = point;
    return YES;
}

static BOOL IDFloatingParseRect(id value, CGRect *result) {
    if (!IDFloatingExactKeys(value, @[@"height", @"width", @"x", @"y"])) return NO;
    NSDictionary *dictionary = value;
    CGRect rect = CGRectZero;
    if (!IDFloatingFiniteNumber(dictionary[@"x"], &rect.origin.x) ||
        !IDFloatingFiniteNumber(dictionary[@"y"], &rect.origin.y) ||
        !IDFloatingFiniteNumber(dictionary[@"width"], &rect.size.width) ||
        !IDFloatingFiniteNumber(dictionary[@"height"], &rect.size.height)) return NO;
    if (result != NULL) *result = rect;
    return YES;
}

static BOOL IDFloatingVisualEndpointIsValid(id value) {
    if (!IDFloatingExactKeys(value, @[@"affinity", @"offset"])) return NO;
    NSUInteger affinity = 0;
    NSUInteger offset = 0;
    return IDFloatingUnsignedNumber(value[@"affinity"], &affinity) &&
        IDFloatingUnsignedNumber(value[@"offset"], &offset) &&
        (affinity == UITextStorageDirectionForward ||
         affinity == UITextStorageDirectionBackward);
}

static BOOL IDFloatingCursorCallbackIsValid(id value) {
    if (value == NSNull.null) return YES;
    if (!IDFloatingExactKeys(value,
            @[@"interactionContainer", @"kind", @"output", @"point", @"sequence"])) {
        return NO;
    }
    if (![value[@"kind"] isKindOfClass:NSString.class] ||
        (![(NSString *)value[@"kind"] isEqualToString:@"cursor"] &&
         ![(NSString *)value[@"kind"] isEqualToString:@"nearest"]) ||
        CFGetTypeID((__bridge CFTypeRef)value[@"interactionContainer"]) !=
            CFBooleanGetTypeID() ||
        ![value[@"interactionContainer"] boolValue]) return NO;
    NSUInteger sequence = 0;
    return IDFloatingUnsignedNumber(value[@"sequence"], &sequence) && sequence > 0 &&
        IDFloatingParsePoint(value[@"point"], NULL) &&
        (value[@"output"] == NSNull.null ||
         IDFloatingVisualEndpointIsValid(value[@"output"]));
}

static BOOL IDFloatingLifecycleIsValid(id value) {
    NSArray<NSString *> *keys = @[
        @"normalEndCount", @"windowDetachActionCount", @"windowDetachCount",
        @"resignActionCount", @"keyboardDismissActionCount",
        @"editableOffActionCount", @"selectableOffActionCount",
        @"responderLossCount", @"editableOffCount", @"selectableOffCount",
        @"startCount", @"cancelCount", @"editable", @"selectable",
        @"presentationUpdates", @"containerToken", @"containerStable",
        @"containerSubviews", @"sessionObject", @"assistantSessionObject",
        @"displaySessionObject", @"sessionOwnersMatch", @"assistantSessionToken",
        @"displaySessionToken", @"sessionActive",
        @"autoscrollObject", @"autoscrollActive", @"recognizerCount",
        @"recognizerBaselineCount", @"recognizerUnexpectedNewCount",
        @"recognizerSubsetOfBaseline", @"recognizerBaselineIdentitySignature",
        @"recognizerIdentitySignature", @"recognizerSignature", @"startAffinity",
        @"endAffinity",
    ];
    if (!IDFloatingExactKeys(value, keys)) return NO;
    NSDictionary *dictionary = value;
    for (NSString *key in @[
        @"normalEndCount", @"windowDetachActionCount", @"windowDetachCount",
        @"resignActionCount", @"keyboardDismissActionCount",
        @"editableOffActionCount", @"selectableOffActionCount",
        @"responderLossCount", @"editableOffCount", @"selectableOffCount",
        @"startCount", @"cancelCount", @"presentationUpdates",
        @"containerSubviews", @"recognizerCount", @"recognizerBaselineCount",
        @"recognizerUnexpectedNewCount",
        @"startAffinity", @"endAffinity",
    ]) {
        if (!IDFloatingUnsignedNumber(dictionary[key], NULL)) return NO;
    }
    for (NSString *key in @[
        @"editable", @"selectable", @"containerStable", @"sessionObject",
        @"assistantSessionObject", @"displaySessionObject", @"sessionOwnersMatch",
        @"sessionActive",
        @"autoscrollObject", @"autoscrollActive",
        @"recognizerSubsetOfBaseline",
    ]) {
        if (![dictionary[key] isKindOfClass:NSNumber.class] ||
            CFGetTypeID((__bridge CFTypeRef)dictionary[key]) != CFBooleanGetTypeID()) return NO;
    }
    if (![dictionary[@"containerToken"] isKindOfClass:NSString.class] ||
        ![dictionary[@"assistantSessionToken"] isKindOfClass:NSString.class] ||
        ![dictionary[@"displaySessionToken"] isKindOfClass:NSString.class]) return NO;
    for (NSString *arrayKey in @[@"recognizerSignature",
                                 @"recognizerBaselineIdentitySignature",
                                 @"recognizerIdentitySignature"]) {
        if (![dictionary[arrayKey] isKindOfClass:NSArray.class]) return NO;
        for (id value in dictionary[arrayKey]) {
            if (![value isKindOfClass:NSString.class]) return NO;
        }
    }
    return YES;
}

BOOL IDFloatingCursorTruthSnapshotIsAtomic(id value) {
    NSArray<NSString *> *keys = @[@"selection", @"startAffinity", @"endAffinity",
        @"firstResponder", @"keyboardVisible", @"containerCreations",
        @"containerStable", @"presentationUpdates", @"contentOffset", @"lifecycle",
        @"retention", @"observation"];
    if (!IDFloatingExactKeys(value, keys)) return NO;
    NSDictionary *snapshot = value;
    if (!IDFloatingExactKeys(snapshot[@"selection"], @[@"length", @"location"]) ||
        !IDFloatingUnsignedNumber(snapshot[@"selection"][@"location"], NULL) ||
        !IDFloatingUnsignedNumber(snapshot[@"selection"][@"length"], NULL) ||
        !IDFloatingUnsignedNumber(snapshot[@"startAffinity"], NULL) ||
        !IDFloatingUnsignedNumber(snapshot[@"endAffinity"], NULL) ||
        !IDFloatingUnsignedNumber(snapshot[@"containerCreations"], NULL) ||
        !IDFloatingUnsignedNumber(snapshot[@"presentationUpdates"], NULL) ||
        !IDFloatingParsePoint(snapshot[@"contentOffset"], NULL) ||
        !IDFloatingLifecycleIsValid(snapshot[@"lifecycle"])) return NO;
    for (NSString *key in @[@"firstResponder", @"keyboardVisible", @"containerStable"]) {
        id flag = snapshot[key];
        if (![flag isKindOfClass:NSNumber.class] ||
            CFGetTypeID((__bridge CFTypeRef)flag) != CFBooleanGetTypeID()) return NO;
    }
    NSDictionary *retention = snapshot[@"retention"];
    if (!IDFloatingExactKeys(retention, @[@"editorRetained", @"assistantRetained",
            @"containerRetained", @"sessionRetained", @"autoscrollRetained"])) return NO;
    for (id flag in retention.allValues) {
        if (![flag isKindOfClass:NSNumber.class] ||
            CFGetTypeID((__bridge CFTypeRef)flag) != CFBooleanGetTypeID()) return NO;
    }
    NSDictionary *observation = snapshot[@"observation"];
    if (!IDFloatingExactKeys(observation, @[@"source", @"sequence",
            @"lifecycleSequence", @"retentionSequence", @"capturedAt", @"actionEpoch",
            @"releaseEpoch",
            @"terminalEpoch", @"liftTargetEpoch", @"captureTargetEpoch", @"phase",
            @"terminalEvent", @"terminalCountAtRelease"])) return NO;
    if (![observation[@"source"] isEqualToString:@"app-side-weak-reference-snapshot"] ||
        ![observation[@"terminalEvent"] isKindOfClass:NSString.class] ||
        ![observation[@"phase"] isKindOfClass:NSString.class]) return NO;
    NSUInteger sequence = 0, lifecycleSequence = 0, retentionSequence = 0;
    CGFloat capturedAt = 0, actionEpoch = 0, releaseEpoch = 0, terminalEpoch = 0;
    CGFloat liftTargetEpoch = 0, captureTargetEpoch = 0;
    if (!IDFloatingUnsignedNumber(observation[@"sequence"], &sequence) || sequence == 0 ||
        !IDFloatingUnsignedNumber(observation[@"lifecycleSequence"], &lifecycleSequence) ||
        !IDFloatingUnsignedNumber(observation[@"retentionSequence"], &retentionSequence) ||
        sequence != lifecycleSequence || sequence != retentionSequence ||
        !IDFloatingFiniteNumber(observation[@"capturedAt"], &capturedAt) ||
        !IDFloatingFiniteNumber(observation[@"actionEpoch"], &actionEpoch) ||
        !IDFloatingFiniteNumber(observation[@"releaseEpoch"], &releaseEpoch) ||
        !IDFloatingFiniteNumber(observation[@"terminalEpoch"], &terminalEpoch) ||
        !IDFloatingFiniteNumber(observation[@"liftTargetEpoch"], &liftTargetEpoch) ||
        !IDFloatingFiniteNumber(observation[@"captureTargetEpoch"], &captureTargetEpoch) ||
        !IDFloatingUnsignedNumber(observation[@"terminalCountAtRelease"], NULL)) return NO;
    return capturedAt >= 0 && actionEpoch >= 0 && releaseEpoch >= 0 && terminalEpoch >= 0 &&
        liftTargetEpoch >= 0 && captureTargetEpoch >= 0;
}

BOOL IDFloatingCursorTruthPhasesHaveValidChronology(
    NSArray<NSDictionary<NSString *, id> *> *phases, BOOL releaseAttempt) {
    if (phases.count != 5) return NO;
    for (NSDictionary *phase in phases) {
        if (!IDFloatingCursorTruthSnapshotIsAtomic(phase)) return NO;
    }
    NSDictionary *held = phases[0][@"observation"];
    NSDictionary *terminal = phases[1][@"observation"];
    NSDictionary *immediate = phases[2][@"observation"];
    NSDictionary *exact = phases[3][@"observation"];
    NSDictionary *postLift = phases[4][@"observation"];
    if ([held[@"actionEpoch"] doubleValue] != 0 ||
        [held[@"terminalEpoch"] doubleValue] != 0 ||
        [held[@"releaseEpoch"] doubleValue] != 0) return NO;
    double actionEpoch = [terminal[@"actionEpoch"] doubleValue];
    double terminalEpoch = [terminal[@"terminalEpoch"] doubleValue];
    double releaseEpoch = [terminal[@"releaseEpoch"] doubleValue];
    double baseEpoch = releaseAttempt ? releaseEpoch :
        (actionEpoch > 0 ? actionEpoch : terminalEpoch);
    if (terminalEpoch <= 0 || baseEpoch <= 0) return NO;
    if (releaseAttempt ? terminalEpoch > releaseEpoch :
        (actionEpoch > 0 ? actionEpoch > terminalEpoch : actionEpoch != 0)) return NO;
    double immediateCapture = [immediate[@"capturedAt"] doubleValue];
    double exactCapture = [exact[@"capturedAt"] doubleValue];
    double exactTarget = [exact[@"captureTargetEpoch"] doubleValue];
    double liftTarget = [postLift[@"liftTargetEpoch"] doubleValue];
    double postCapture = [postLift[@"capturedAt"] doubleValue];
    double postTarget = [postLift[@"captureTargetEpoch"] doubleValue];
    NSUInteger heldSequence = [held[@"sequence"] unsignedIntegerValue];
    NSUInteger terminalSequence = [terminal[@"sequence"] unsignedIntegerValue];
    NSUInteger immediateSequence = [immediate[@"sequence"] unsignedIntegerValue];
    NSUInteger exactSequence = [exact[@"sequence"] unsignedIntegerValue];
    NSUInteger postSequence = [postLift[@"sequence"] unsignedIntegerValue];
    BOOL prefixOrdered = heldSequence < terminalSequence &&
        terminalSequence < immediateSequence;
    BOOL deferredOrdered = exactSequence > immediateSequence &&
        postSequence > immediateSequence &&
        (exactTarget <= postTarget ? exactSequence < postSequence
                                   : postSequence < exactSequence);
    return immediateCapture >= terminalEpoch &&
        prefixOrdered && deferredOrdered &&
        fabs(exactTarget - (baseEpoch + 0.500)) <= 0.001 &&
        fabs(exactCapture - exactTarget) <= 0.08 &&
        fabs(postTarget - (liftTarget + 0.500)) <= 0.001 &&
        fabs(postCapture - postTarget) <= 0.08;
}

static BOOL IDFloatingSessionRelationsAreValid(NSDictionary *phase) {
    BOOL assistant = [phase[@"assistantSessionObject"] boolValue];
    BOOL display = [phase[@"displaySessionObject"] boolValue];
    BOOL assistantToken = ![phase[@"assistantSessionToken"] isEqualToString:@"nil"];
    BOOL displayToken = ![phase[@"displaySessionToken"] isEqualToString:@"nil"];
    BOOL ownersMatch = assistant && display &&
        [phase[@"assistantSessionToken"] isEqualToString:phase[@"displaySessionToken"]];
    return assistant == assistantToken && display == displayToken &&
        [phase[@"sessionOwnersMatch"] boolValue] == ownersMatch;
}

BOOL IDFloatingCursorLifecyclePhasesHaveCompleteParity(
    NSArray<NSDictionary<NSString *, id> *> *stockPhases,
    NSArray<NSDictionary<NSString *, id> *> *customPhases,
    NSString *actionEvent) {
    if (stockPhases.count != 5 || customPhases.count != 5) return NO;
    BOOL selectableOff = [actionEvent isEqualToString:@"selectableOffAction"];
    NSArray *topParity = @[@"selection", @"startAffinity", @"endAffinity",
        @"firstResponder", @"keyboardVisible", @"containerCreations",
        @"containerStable", @"contentOffset"];
    NSArray *retentionParity = @[@"editorRetained", @"assistantRetained",
        @"containerRetained", @"sessionRetained", @"autoscrollRetained"];
    NSArray *lifecycleParity = @[@"normalEndCount", @"windowDetachActionCount",
        @"windowDetachCount", @"resignActionCount", @"keyboardDismissActionCount",
        @"editableOffActionCount", @"selectableOffActionCount", @"responderLossCount",
        @"editableOffCount", @"selectableOffCount", @"startCount", @"cancelCount",
        @"editable", @"selectable", @"containerStable", @"containerSubviews",
        @"sessionObject", @"assistantSessionObject", @"displaySessionObject",
        @"sessionOwnersMatch", @"sessionActive", @"autoscrollObject",
        @"autoscrollActive", @"startAffinity", @"endAffinity"];
    NSString *stockContainer = stockPhases.firstObject[@"lifecycle"][@"containerToken"];
    NSString *customContainer = customPhases.firstObject[@"lifecycle"][@"containerToken"];
    NSUInteger previousStockPresentation = 0, previousCustomPresentation = 0;
    NSUInteger stockInitialPresentation =
        [stockPhases.firstObject[@"presentationUpdates"] unsignedIntegerValue];
    NSUInteger customInitialPresentation =
        [customPhases.firstObject[@"presentationUpdates"] unsignedIntegerValue];
    NSDictionary *stockHeld = stockPhases.firstObject;
    NSDictionary *customHeld = customPhases.firstObject;
    NSDictionary *stockTerminal = stockPhases[1];
    NSDictionary *customTerminal = customPhases[1];
    NSArray *stableTop = @[@"selection", @"startAffinity", @"endAffinity",
        @"containerCreations", @"containerStable", @"contentOffset"];
    NSArray *countKeys = @[@"normalEndCount", @"windowDetachActionCount",
        @"windowDetachCount", @"resignActionCount", @"keyboardDismissActionCount",
        @"editableOffActionCount", @"selectableOffActionCount", @"responderLossCount",
        @"editableOffCount", @"selectableOffCount", @"startCount", @"cancelCount"];
    for (NSUInteger index = 0; index < 5; index += 1) {
        NSDictionary *stock = stockPhases[index];
        NSDictionary *custom = customPhases[index];
        if (!IDFloatingCursorTruthSnapshotIsAtomic(stock) ||
            !IDFloatingCursorTruthSnapshotIsAtomic(custom)) return NO;
        for (NSString *key in topParity) {
            if (![stock[key] isEqual:custom[key]]) return NO;
        }
        for (NSString *key in retentionParity) {
            BOOL weakSelectableWindow = selectableOff &&
                [key isEqualToString:@"sessionRetained"] && (index == 1 || index == 2);
            if (!weakSelectableWindow &&
                ![stock[@"retention"][key] isEqual:custom[@"retention"][key]]) return NO;
        }
        NSDictionary *stockLifecycle = stock[@"lifecycle"];
        NSDictionary *customLifecycle = custom[@"lifecycle"];
        for (NSString *key in lifecycleParity) {
            if (![stockLifecycle[key] isEqual:customLifecycle[key]]) return NO;
        }
        if (![stockLifecycle[@"containerToken"] isEqual:stockContainer] ||
            ![customLifecycle[@"containerToken"] isEqual:customContainer] ||
            !IDFloatingSessionRelationsAreValid(stockLifecycle) ||
            !IDFloatingSessionRelationsAreValid(customLifecycle)) return NO;
        NSSet *stockCurrent = [NSSet setWithArray:
            stockLifecycle[@"recognizerIdentitySignature"]];
        NSSet *stockBaseline = [NSSet setWithArray:
            stockLifecycle[@"recognizerBaselineIdentitySignature"]];
        NSSet *customCurrent = [NSSet setWithArray:
            customLifecycle[@"recognizerIdentitySignature"]];
        NSSet *customBaseline = [NSSet setWithArray:
            customLifecycle[@"recognizerBaselineIdentitySignature"]];
        BOOL stockRecognizerRelation = stockCurrent.count ==
            [stockLifecycle[@"recognizerCount"] unsignedIntegerValue] &&
            stockBaseline.count ==
            [stockLifecycle[@"recognizerBaselineCount"] unsignedIntegerValue] &&
            [stockCurrent isSubsetOfSet:stockBaseline] &&
            [stockLifecycle[@"recognizerUnexpectedNewCount"] unsignedIntegerValue] == 0 &&
            [stockLifecycle[@"recognizerSubsetOfBaseline"] boolValue];
        BOOL customRecognizerRelation = customCurrent.count ==
            [customLifecycle[@"recognizerCount"] unsignedIntegerValue] &&
            customBaseline.count ==
            [customLifecycle[@"recognizerBaselineCount"] unsignedIntegerValue] &&
            [customCurrent isSubsetOfSet:customBaseline] &&
            [customLifecycle[@"recognizerUnexpectedNewCount"] unsignedIntegerValue] == 0 &&
            [customLifecycle[@"recognizerSubsetOfBaseline"] boolValue];
        if (!stockRecognizerRelation || !customRecognizerRelation) return NO;
        NSUInteger stockPresentation = [stock[@"presentationUpdates"] unsignedIntegerValue];
        NSUInteger customPresentation = [custom[@"presentationUpdates"] unsignedIntegerValue];
        if (index > 0 && (stockPresentation < previousStockPresentation ||
                         customPresentation < previousCustomPresentation)) return NO;
        if (customPresentation - customInitialPresentation <
            stockPresentation - stockInitialPresentation) return NO;
        previousStockPresentation = stockPresentation;
        previousCustomPresentation = customPresentation;
        if (selectableOff) {
            for (NSDictionary *host in @[stock, custom]) {
                NSDictionary *held = host == stock ? stockHeld : customHeld;
                NSDictionary *terminal = host == stock ? stockTerminal : customTerminal;
                NSDictionary *lifecycle = host[@"lifecycle"];
                NSDictionary *heldLifecycle = held[@"lifecycle"];
                NSDictionary *terminalLifecycle = terminal[@"lifecycle"];
                for (NSString *key in stableTop) {
                    if (![host[key] isEqual:held[key]]) return NO;
                }
                if (![lifecycle[@"containerToken"] isEqual:heldLifecycle[@"containerToken"]] ||
                    ![lifecycle[@"containerSubviews"] isEqual:
                        heldLifecycle[@"containerSubviews"]]) return NO;
                if (index > 0) {
                    for (NSString *key in @[@"assistantSessionObject",
                        @"displaySessionObject", @"sessionObject", @"sessionOwnersMatch",
                        @"sessionActive", @"autoscrollActive"]) {
                        if ([lifecycle[key] boolValue]) return NO;
                    }
                    if (![host[@"firstResponder"] isEqual:terminal[@"firstResponder"]])
                        return NO;
                    if (index == 2 &&
                        ![host[@"keyboardVisible"] isEqual:terminal[@"keyboardVisible"]])
                        return NO;
                    if (index >= 3 && ![host[@"keyboardVisible"] isEqual:
                        (host == stock ? stockPhases[3] : customPhases[3])
                            [@"keyboardVisible"]]) return NO;
                    if (index >= 2 && ![host[@"presentationUpdates"] isEqual:
                        terminal[@"presentationUpdates"]]) return NO;
                    if (index >= 2) {
                        for (NSString *key in countKeys) {
                            if (![lifecycle[key] isEqual:terminalLifecycle[key]]) return NO;
                        }
                    }
                }
                if (index >= 3 && [host[@"retention"][@"sessionRetained"] boolValue])
                    return NO;
                if (index == 4 && ![lifecycle[@"recognizerIdentitySignature"] isEqual:
                    (host == stock ? stockPhases[3] : customPhases[3])
                        [@"lifecycle"][@"recognizerIdentitySignature"]]) return NO;
            }
        }
    }
    return YES;
}

BOOL IDFloatingCursorNormalPhasesHaveCompleteParity(
    NSArray<NSDictionary<NSString *, id> *> *stockPhases,
    NSArray<NSDictionary<NSString *, id> *> *customPhases) {
    return IDFloatingCursorLifecyclePhasesHaveCompleteParity(
        stockPhases, customPhases, nil);
}

BOOL IDFloatingCursorParseStatus(id value, IDFloatingCursorStatus *status) {
    NSString *string = [value isKindOfClass:NSString.class] ? value : nil;
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil) return NO;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray<NSString *> *keys = @[
        @"blockCount", @"canonical", @"caret", @"containerCreations",
        @"containerStable", @"contentOffset", @"firstResponder",
        @"presentationUpdates", @"scenario", @"selection", @"startAffinity",
        @"endAffinity", @"visible", @"cursorCallback", @"autoscrollTrace",
        @"interactionHostTopology", @"lifecycle",
    ];
    if (!IDFloatingExactKeys(object, keys)) return NO;
    NSDictionary *dictionary = object;
    if (![dictionary[@"canonical"] isKindOfClass:NSString.class] ||
        ![dictionary[@"scenario"] isKindOfClass:NSString.class] ||
        CFGetTypeID((__bridge CFTypeRef)dictionary[@"containerStable"]) !=
            CFBooleanGetTypeID() ||
        CFGetTypeID((__bridge CFTypeRef)dictionary[@"firstResponder"]) !=
            CFBooleanGetTypeID()) return NO;

    IDFloatingCursorStatus parsed = {0};
    NSUInteger startAffinity = 0;
    NSUInteger endAffinity = 0;
    NSDictionary *selection = dictionary[@"selection"];
    if (!IDFloatingExactKeys(selection, @[@"length", @"location"]) ||
        !IDFloatingUnsignedNumber(selection[@"location"], &parsed.selection.location) ||
        !IDFloatingUnsignedNumber(selection[@"length"], &parsed.selection.length) ||
        !IDFloatingUnsignedNumber(dictionary[@"startAffinity"], &startAffinity) ||
        !IDFloatingUnsignedNumber(dictionary[@"endAffinity"], &endAffinity) ||
        !IDFloatingParseRect(dictionary[@"caret"], &parsed.caret) ||
        !IDFloatingParseRect(dictionary[@"visible"], &parsed.visible) ||
        !IDFloatingParsePoint(dictionary[@"contentOffset"], &parsed.contentOffset) ||
        !IDFloatingUnsignedNumber(dictionary[@"blockCount"], &parsed.blockCount) ||
        !IDFloatingUnsignedNumber(dictionary[@"presentationUpdates"],
                                  &parsed.presentationUpdates) ||
        !IDFloatingUnsignedNumber(dictionary[@"containerCreations"],
                                  &parsed.containerCreations) ||
        (startAffinity != UITextStorageDirectionForward &&
         startAffinity != UITextStorageDirectionBackward) ||
        (endAffinity != UITextStorageDirectionForward &&
         endAffinity != UITextStorageDirectionBackward) ||
        !IDFloatingCursorCallbackIsValid(dictionary[@"cursorCallback"]) ||
        ![dictionary[@"autoscrollTrace"] isKindOfClass:NSDictionary.class] ||
        ![dictionary[@"interactionHostTopology"] isKindOfClass:NSDictionary.class] ||
        !IDFloatingLifecycleIsValid(dictionary[@"lifecycle"])) return NO;
    parsed.startAffinity = (NSInteger)startAffinity;
    parsed.endAffinity = (NSInteger)endAffinity;
    parsed.containerStable = [dictionary[@"containerStable"] boolValue];
    parsed.firstResponder = [dictionary[@"firstResponder"] boolValue];
    if (status != NULL) *status = parsed;
    return YES;
}

NSString *IDFloatingCursorCopyCanonical(id value) {
    IDFloatingCursorStatus ignored = {0};
    if (!IDFloatingCursorParseStatus(value, &ignored)) return nil;
    NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:0 error:nil];
    return [dictionary[@"canonical"] copy];
}

NSDictionary<NSString *, id> *IDFloatingCursorCopyCursorCallback(id value) {
    IDFloatingCursorStatus ignored = {0};
    if (!IDFloatingCursorParseStatus(value, &ignored)) return nil;
    NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:0 error:nil];
    id record = dictionary[@"cursorCallback"];
    return record == NSNull.null ? nil : [record copy];
}

NSDictionary<NSString *, id> *IDFloatingCursorCopyAutoscrollTrace(id value) {
    IDFloatingCursorStatus ignored = {0};
    if (!IDFloatingCursorParseStatus(value, &ignored)) return nil;
    NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:0 error:nil];
    return [dictionary[@"autoscrollTrace"] copy];
}

NSDictionary<NSString *, id> *IDFloatingCursorCopyLifecycle(id value) {
    IDFloatingCursorStatus ignored = {0};
    if (!IDFloatingCursorParseStatus(value, &ignored)) return nil;
    NSData *data = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:0 error:nil];
    return [dictionary[@"lifecycle"] copy];
}

BOOL IDFloatingCursorFrameIsValid(CGRect frame) {
    return !CGRectIsNull(frame) && !CGRectIsInfinite(frame) &&
        isfinite(frame.origin.x) && isfinite(frame.origin.y) &&
        isfinite(frame.size.width) && isfinite(frame.size.height);
}

XCUIApplication *IDFloatingCursorLaunchCustom(XCTestCase *testCase, NSString *scenario) {
    return IDFloatingCursorLaunchCustomWithTruthEvent(testCase, scenario, nil, nil);
}

XCUIApplication *IDFloatingCursorLaunchCustomWithTruthEvent(
    XCTestCase *testCase, NSString *scenario, NSString *terminalEvent,
    NSString *actionEvent) {
    XCUIApplication *application = [XCUIApplication new];
    [application terminate];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)", @"-AppleLocale", @"en_US",
        @"--id-block-ui-scenario", scenario,
    ];
    NSMutableDictionary *environment = [NSMutableDictionary dictionary];
    if (terminalEvent.length > 0)
        environment[@"IDFloatingTruthTerminalEvent"] = terminalEvent;
    if (actionEvent.length > 0)
        environment[@"IDFloatingTruthActionEvent"] = actionEvent;
    application.launchEnvironment = environment;
    [application launch];
    XCUIElement *editor =
        [application descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCUIElement *status =
        [application descendantsMatchingType:XCUIElementTypeAny][@"floating-status"];
    if (![editor waitForExistenceWithTimeout:4.0] ||
        ![status waitForExistenceWithTimeout:4.0]) {
        IDFloatingRecordFailure(testCase, @"Custom floating-cursor fixture did not launch");
    }
    return application;
}

XCUIApplication *IDFloatingCursorLaunchStock(XCTestCase *testCase,
                                             NSString *scenario,
                                             CGRect editorFrame) {
    return IDFloatingCursorLaunchStockWithTruthEvent(
        testCase, scenario, editorFrame, nil, nil);
}

XCUIApplication *IDFloatingCursorLaunchStockWithTruthEvent(
    XCTestCase *testCase, NSString *scenario, CGRect editorFrame,
    NSString *terminalEvent, NSString *actionEvent) {
    XCUIApplication *application = [[XCUIApplication alloc]
        initWithBundleIdentifier:@"com.inputdec.stockoracle"];
    [application terminate];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)", @"-AppleLocale", @"en_US",
    ];
    NSMutableDictionary *environment = [@{
        @"IDStockEditorFrame": NSStringFromCGRect(editorFrame),
        @"IDStockTouchScenario": scenario,
    } mutableCopy];
    if (terminalEvent.length > 0) {
        environment[@"IDStockTruthTerminalEvent"] = terminalEvent;
    }
    if (actionEvent.length > 0) {
        environment[@"IDStockTruthActionEvent"] = actionEvent;
    }
    application.launchEnvironment = environment;
    [application launch];
    XCUIElement *editor =
        [application descendantsMatchingType:XCUIElementTypeAny][@"stock-text-view"];
    XCUIElement *status =
        [application descendantsMatchingType:XCUIElementTypeAny][@"floating-status"];
    if (![editor waitForExistenceWithTimeout:4.0] ||
        ![status waitForExistenceWithTimeout:4.0]) {
        IDFloatingRecordFailure(testCase, @"Stock floating-cursor fixture did not launch");
    } else if (!CGRectEqualToRect(editor.frame, editorFrame)) {
        IDFloatingRecordFailure(testCase, [NSString stringWithFormat:
            @"Stock editor frame %@ differs from custom %@",
            NSStringFromCGRect(editor.frame), NSStringFromCGRect(editorFrame)]);
    }
    return application;
}

XCUIApplication *IDFloatingCursorLaunchCustomScroll(XCTestCase *testCase, BOOL lower,
                                                     BOOL selectionExtension) {
    XCUIApplication *application = [XCUIApplication new];
    [application terminate];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)", @"-AppleLocale", @"en_US",
        @"--id-block-ui-scenario", @"floating-scroll",
    ];
    application.launchEnvironment = @{
        @"IDFloatingScrollEdge": lower ? @"lower" : @"upper",
        @"IDFloatingScrollSelection": selectionExtension ? @"1" : @"0",
    };
    [application launch];
    XCUIElement *editor =
        [application descendantsMatchingType:XCUIElementTypeAny][@"block-text-view"];
    XCUIElement *status =
        [application descendantsMatchingType:XCUIElementTypeAny][@"floating-status"];
    if (![editor waitForExistenceWithTimeout:4.0] ||
        ![status waitForExistenceWithTimeout:4.0]) {
        IDFloatingRecordFailure(testCase, @"Custom floating-scroll fixture did not launch");
    }
    return application;
}

XCUIApplication *IDFloatingCursorLaunchStockScroll(XCTestCase *testCase,
                                                    CGRect editorFrame,
                                                    BOOL lower,
                                                    BOOL selectionExtension) {
    XCUIApplication *application = [[XCUIApplication alloc]
        initWithBundleIdentifier:@"com.inputdec.stockoracle"];
    [application terminate];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)", @"-AppleLocale", @"en_US",
    ];
    application.launchEnvironment = @{
        @"IDFloatingScrollEdge": lower ? @"lower" : @"upper",
        @"IDFloatingScrollSelection": selectionExtension ? @"1" : @"0",
        @"IDStockEditorFrame": NSStringFromCGRect(editorFrame),
        @"IDStockTouchScenario": @"floating-scroll",
    };
    [application launch];
    XCUIElement *editor =
        [application descendantsMatchingType:XCUIElementTypeAny][@"stock-text-view"];
    XCUIElement *status =
        [application descendantsMatchingType:XCUIElementTypeAny][@"floating-status"];
    if (![editor waitForExistenceWithTimeout:4.0] ||
        ![status waitForExistenceWithTimeout:4.0]) {
        IDFloatingRecordFailure(testCase, @"Stock floating-scroll fixture did not launch");
    } else if (!CGRectEqualToRect(editor.frame, editorFrame)) {
        IDFloatingRecordFailure(testCase, [NSString stringWithFormat:
            @"Stock editor frame %@ differs from custom %@",
            NSStringFromCGRect(editor.frame), NSStringFromCGRect(editorFrame)]);
    }
    return application;
}

CGRect IDFloatingCursorSpacebarFrame(XCTestCase *testCase,
                                     XCUIApplication *application) {
    XCUIElementQuery *spacebars = [application.keyboards.keys matchingIdentifier:@"space"];
    if (spacebars.count != 1) {
        IDFloatingRecordFailure(testCase, [NSString stringWithFormat:
            @"Expected exactly one software-keyboard space key, found %lu",
            (unsigned long)spacebars.count]);
        return CGRectNull;
    }
    XCUIElement *spacebar = spacebars.element;
    if (![spacebar waitForExistenceWithTimeout:4.0] || !spacebar.hittable) {
        IDFloatingRecordFailure(testCase, @"Software-keyboard space key is not hittable");
        return CGRectNull;
    }
    CGRect frame = spacebar.frame;
    if (!IDFloatingCursorFrameIsValid(frame)) {
        IDFloatingRecordFailure(testCase, [NSString stringWithFormat:
            @"Software-keyboard space key has invalid frame %@", NSStringFromCGRect(frame)]);
        return CGRectNull;
    }
    return frame;
}

BOOL IDFloatingCursorWaitForStatus(XCUIElement *statusElement,
                                   NSTimeInterval timeout,
                                   BOOL (^predicate)(IDFloatingCursorStatus status),
                                   IDFloatingCursorStatus *result,
                                   NSString **canonicalResult) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    IDFloatingCursorStatus latest = {0};
    do {
        id value = statusElement.value;
        if (IDFloatingCursorParseStatus(value, &latest) && predicate(latest)) {
            if (result != NULL) *result = latest;
            if (canonicalResult != NULL) {
                *canonicalResult = IDFloatingCursorCopyCanonical(value);
            }
            return YES;
        }
        [NSThread sleepForTimeInterval:0.025];
    } while (deadline.timeIntervalSinceNow > 0.0);
    return NO;
}
