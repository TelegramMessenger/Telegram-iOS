#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGPrivateRuntimeNames.h"
#import "IDPrivateUIKit.h"
#import "IDPrivateUIKit+Testing.h"
// telegram-ios DEVIATION 5 (see PROVENANCE.md) — for the pristine contract manifest.
#import "RichTextInputDecUpstreamPristineManifest.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>

#import <string.h>

static const void *IDPrivateTextAutoscrollTraceKey = &IDPrivateTextAutoscrollTraceKey;
static const void *IDPrivateStockPresentationKey = &IDPrivateStockPresentationKey;
static const void *IDPrivateRecognizerBaselineKey = &IDPrivateRecognizerBaselineKey;
static const void *IDPrivateInteractionHostTopologyBaselineKey =
    &IDPrivateInteractionHostTopologyBaselineKey;
static const void *IDPrivateFloatingContainerIdentityTrackerKey =
    &IDPrivateFloatingContainerIdentityTrackerKey;
static const void *IDPrivateFloatingContainerIdentityTokenKey =
    &IDPrivateFloatingContainerIdentityTokenKey;
static NSUInteger IDPrivateNextFloatingContainerIdentityToken;
static NSMutableArray<NSString *> *IDPrivateAutocorrectionTrace;
static NSDictionary<NSString *, NSNumber *> *IDPrivatePointJSON(CGPoint point);

void IDInstallAutocorrectionTraceForUITesting(void) {
    @synchronized (IDPrivateUIKit.class) {
        IDPrivateAutocorrectionTrace = [NSMutableArray array];
    }
}

void IDRecordAutocorrectionTraceForUITesting(NSString *event) {
    if (event.length == 0) return;
    @synchronized (IDPrivateUIKit.class) {
        [IDPrivateAutocorrectionTrace addObject:[event copy]];
    }
}

NSArray<NSString *> *IDCopyAutocorrectionTraceForUITesting(void) {
    @synchronized (IDPrivateUIKit.class) {
        return IDPrivateAutocorrectionTrace.copy ?: @[];
    }
}

void IDResetAutocorrectionTraceForUITesting(void) {
    @synchronized (IDPrivateUIKit.class) {
        IDPrivateAutocorrectionTrace = nil;
    }
}

static BOOL IDPrivateMethodHasNoExplicitArgumentsAndReturnType(
    Method method, const char *returnType) {
    if (method == NULL || method_getNumberOfArguments(method) != 2) return NO;
    char *actualReturnType = method_copyReturnType(method);
    BOOL matches = actualReturnType != NULL &&
        strcmp(actualReturnType, returnType) == 0;
    free(actualReturnType);
    return matches;
}

BOOL IDPrivateTestingDismissInlineTextCompletionWithKeyboardClass(
    Class keyboardClass) {
    if (keyboardClass == Nil) return NO;
    SEL activeSelector = NSSelectorFromString(TGPN_activeInstance());
    Method activeMethod = class_getClassMethod(keyboardClass, activeSelector);
    if (!IDPrivateMethodHasNoExplicitArgumentsAndReturnType(
            activeMethod, @encode(id))) {
        return NO;
    }
    id keyboard = IDPrivateObject0(keyboardClass, activeSelector);
    SEL removeSelector =
        NSSelectorFromString(TGPN_removeInlineTextCompletionPrompt());
    if (keyboard == nil) return NO;
    Method removeMethod =
        class_getInstanceMethod([keyboard class], removeSelector);
    if (!IDPrivateMethodHasNoExplicitArgumentsAndReturnType(
            removeMethod, @encode(void))) {
        return NO;
    }
    IDPrivateVoid0(keyboard, removeSelector);
    return YES;
}

BOOL IDPrivateDismissInlineTextCompletionForUITesting(void) {
    return IDPrivateTestingDismissInlineTextCompletionWithKeyboardClass(
        NSClassFromString(TGPN_UIKeyboardImpl()));
}

static NSArray<NSString *> *IDPrivateRecognizerIdentities(UIView *view) {
    NSMutableArray<NSString *> *identities = [NSMutableArray array];
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers ?: @[]) {
        [identities addObject:[NSString stringWithFormat:@"%p:%@", recognizer,
            NSStringFromClass(recognizer.class)]];
    }
    [identities sortUsingSelector:@selector(compare:)];
    return identities.copy;
}

static void IDPrivateFreezeRecognizerBaselineAtHeldCapture(UIView *view) {
    objc_setAssociatedObject(view, IDPrivateRecognizerBaselineKey,
        IDPrivateRecognizerIdentities(view), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSDictionary<NSString *, id> *IDPrivateRecognizerState(UIView *view) {
    NSArray<UIGestureRecognizer *> *recognizers = view.gestureRecognizers ?: @[];
    NSArray<NSString *> *identities = IDPrivateRecognizerIdentities(view);
    NSMutableArray<NSString *> *classes = [NSMutableArray array];
    for (UIGestureRecognizer *recognizer in recognizers) {
        [classes addObject:NSStringFromClass(recognizer.class)];
    }
    [classes sortUsingSelector:@selector(compare:)];
    NSArray<NSString *> *baseline = objc_getAssociatedObject(view,
        IDPrivateRecognizerBaselineKey);
    if (baseline == nil) {
        baseline = identities;
        objc_setAssociatedObject(view, IDPrivateRecognizerBaselineKey, baseline,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSMutableSet *unexpected = [NSMutableSet setWithArray:identities];
    [unexpected minusSet:[NSSet setWithArray:baseline]];
    return @{
        @"recognizerCount": @(recognizers.count),
        @"recognizerSignature": classes.copy,
        @"recognizerBaselineCount": @(baseline.count),
        @"recognizerUnexpectedNewCount": @(unexpected.count),
        @"recognizerSubsetOfBaseline": @((BOOL)(unexpected.count == 0)),
        @"recognizerBaselineIdentitySignature": baseline,
        @"recognizerIdentitySignature": identities,
    };
}

void IDPrivateResetRecognizerBaselineForUITesting(UIView *textInput) {
    objc_setAssociatedObject(textInput, IDPrivateRecognizerBaselineKey, nil,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSString *IDPrivateTopologyObjectIdentity(id object) {
    return [NSString stringWithFormat:@"%p:%@", object,
            NSStringFromClass([object class])];
}

static NSString *IDPrivateTopologyViewToken(UIView *view) {
    return view == nil ? @"nil" : [NSString stringWithFormat:@"%p", view];
}

static NSArray<NSString *> *IDPrivateTopologySortedDifference(
    NSArray<NSString *> *left,
    NSArray<NSString *> *right) {
    NSMutableSet<NSString *> *difference = [NSMutableSet setWithArray:left];
    [difference minusSet:[NSSet setWithArray:right]];
    return [[difference allObjects] sortedArrayUsingSelector:@selector(compare:)];
}

static NSString *IDPrivateTopologyAncestry(
    NSString *logicalName,
    UIView *view,
    UIView *outer) {
    if (view == nil) return @"none";
    if (view == outer) return @"outer";
    if ([view isDescendantOfView:outer]) return @"descendant";
    if ([logicalName isEqualToString:@"external"]) return @"external";
    return @"unrelated";
}

static NSDictionary<NSString *, id> *IDPrivateTopologyRawHostState(
    NSString *logicalName,
    UIView *view,
    UIView *outer) {
    NSArray<UIGestureRecognizer *> *recognizers = view.gestureRecognizers ?: @[];
    NSArray<id<UIInteraction>> *interactions = view.interactions ?: @[];
    NSMutableArray<NSString *> *recognizerClasses = [NSMutableArray array];
    NSMutableArray<NSString *> *recognizerIdentities = [NSMutableArray array];
    NSMutableArray<NSString *> *recognizerEnabled = [NSMutableArray array];
    NSMutableArray<NSString *> *recognizerOwners = [NSMutableArray array];
    for (UIGestureRecognizer *recognizer in recognizers) {
        NSString *identity = IDPrivateTopologyObjectIdentity(recognizer);
        [recognizerClasses addObject:NSStringFromClass(recognizer.class)];
        [recognizerIdentities addObject:identity];
        [recognizerEnabled addObject:[NSString stringWithFormat:@"%@:%d",
            identity, recognizer.enabled]];
        [recognizerOwners addObject:IDPrivateTopologyViewToken(recognizer.view)];
    }
    NSMutableArray<NSString *> *interactionClasses = [NSMutableArray array];
    NSMutableArray<NSString *> *interactionIdentities = [NSMutableArray array];
    NSMutableArray<NSString *> *interactionOwners = [NSMutableArray array];
    for (id<UIInteraction> interaction in interactions) {
        [interactionClasses addObject:NSStringFromClass([interaction class])];
        [interactionIdentities addObject:IDPrivateTopologyObjectIdentity(interaction)];
        [interactionOwners addObject:IDPrivateTopologyViewToken(interaction.view)];
    }
    for (NSMutableArray<NSString *> *signature in @[
            recognizerClasses, recognizerIdentities, recognizerEnabled,
            recognizerOwners, interactionClasses, interactionIdentities,
            interactionOwners]) {
        [signature sortUsingSelector:@selector(compare:)];
    }
    return @{
        @"present": @(view != nil),
        @"viewToken": IDPrivateTopologyViewToken(view),
        @"ancestry": IDPrivateTopologyAncestry(logicalName, view, outer),
        @"recognizerCount": @(recognizers.count),
        @"recognizerSignature": recognizerClasses.copy,
        @"recognizerIdentitySignature": recognizerIdentities.copy,
        @"recognizerEnabledSignature": recognizerEnabled.copy,
        @"recognizerOwnerIdentitySignature": recognizerOwners.copy,
        @"interactionCount": @(interactions.count),
        @"interactionSignature": interactionClasses.copy,
        @"interactionIdentitySignature": interactionIdentities.copy,
        @"interactionOwnerIdentitySignature": interactionOwners.copy,
    };
}

static NSUInteger IDPrivateTopologyEligibleRecognizerCount(
    NSString *logicalName,
    UIView *view,
    UIView *outer) {
    if (view == nil) return 0;
    NSUInteger count = 0;
    UIScrollView *outerScrollView = [outer isKindOfClass:UIScrollView.class]
        ? (UIScrollView *)outer : nil;
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers ?: @[]) {
        if ([logicalName isEqualToString:@"outer"] &&
            (recognizer == outerScrollView.panGestureRecognizer ||
             recognizer == outerScrollView.pinchGestureRecognizer)) {
            continue;
        }
        count += 1;
    }
    return count;
}

static NSString *IDPrivateTopologyInstallationHost(
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *rawHosts,
    NSDictionary<NSString *, UIView *> *views,
    UIView *outer,
    NSUInteger *liveHostCount) {
    UIView *inner = views[@"blockStack"];
    UIView *external = views[@"external"];
    BOOL aliasesLiveHost =
        (inner != nil && inner == outer &&
         [rawHosts[@"blockStack"][@"interactionCount"] unsignedIntegerValue] > 0) ||
        (external != nil && external == outer &&
         [rawHosts[@"external"][@"interactionCount"] unsignedIntegerValue] > 0) ||
        (inner != nil && external != nil && inner == external &&
         [rawHosts[@"blockStack"][@"interactionCount"] unsignedIntegerValue] > 0);
    if (aliasesLiveHost) {
        if (liveHostCount != NULL) *liveHostCount = 2;
        return @"multiple";
    }
    NSArray<NSString *> *alternateNames = @[@"blockStack", @"external"];
    NSMutableArray<NSString *> *live = [NSMutableArray array];
    for (NSString *name in alternateNames) {
        if ([rawHosts[name][@"interactionCount"] unsignedIntegerValue] > 0) {
            [live addObject:name];
        }
    }
    if (live.count == 0 &&
        [rawHosts[@"outer"][@"interactionCount"] unsignedIntegerValue] > 0) {
        [live addObject:@"outer"];
    }
    if (live.count == 0) {
        for (NSString *name in alternateNames) {
            if (IDPrivateTopologyEligibleRecognizerCount(
                    name, views[name], outer) > 0) {
                [live addObject:name];
            }
        }
        if (live.count == 0 && IDPrivateTopologyEligibleRecognizerCount(
                @"outer", views[@"outer"], outer) > 0) {
            [live addObject:@"outer"];
        }
    }
    if (liveHostCount != NULL) *liveHostCount = live.count;
    if (live.count == 0) return @"none";
    if (live.count > 1) return @"multiple";
    return live.firstObject;
}

static NSUInteger IDPrivateTopologyDuplicateIdentityCount(
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *hosts,
    NSString *identityKey) {
    NSMutableDictionary<NSString *, NSNumber *> *occurrences =
        [NSMutableDictionary dictionary];
    for (NSString *name in @[@"outer", @"blockStack", @"external"]) {
        for (NSString *identity in hosts[name][identityKey]) {
            occurrences[identity] = @([occurrences[identity] unsignedIntegerValue] + 1);
        }
    }
    NSUInteger duplicateCount = 0;
    for (NSNumber *count in occurrences.allValues) {
        if (count.unsignedIntegerValue > 1) duplicateCount += 1;
    }
    return duplicateCount;
}

NSDictionary<NSString *, id> *
IDPrivateCopyInteractionHostTopologyForUITesting(
    UIView *outer,
    UIView *inner,
    UIView *external) {
    NSCParameterAssert(outer != nil);
    NSDictionary<NSString *, UIView *> *views = @{
        @"outer": outer,
        @"blockStack": inner ?: (UIView *)NSNull.null,
        @"external": external ?: (UIView *)NSNull.null,
    };
    NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *rawHosts =
        [NSMutableDictionary dictionary];
    for (NSString *name in @[@"outer", @"blockStack", @"external"]) {
        id candidate = views[name];
        UIView *view = candidate == NSNull.null ? nil : candidate;
        rawHosts[name] = IDPrivateTopologyRawHostState(name, view, outer);
    }
    NSUInteger liveHostCount = 0;
    NSMutableDictionary<NSString *, UIView *> *nullableViews = [views mutableCopy];
    if (inner == nil) [nullableViews removeObjectForKey:@"blockStack"];
    if (external == nil) [nullableViews removeObjectForKey:@"external"];
    NSString *installationHost = IDPrivateTopologyInstallationHost(
        rawHosts, nullableViews, outer, &liveHostCount);

    NSDictionary<NSString *, id> *baseline = objc_getAssociatedObject(
        outer, IDPrivateInteractionHostTopologyBaselineKey);
    if (baseline == nil) {
        NSMutableDictionary *baselineHosts = [NSMutableDictionary dictionary];
        for (NSString *name in @[@"outer", @"blockStack", @"external"]) {
            baselineHosts[name] = @{
                @"recognizerIdentitySignature":
                    rawHosts[name][@"recognizerIdentitySignature"],
                @"interactionIdentitySignature":
                    rawHosts[name][@"interactionIdentitySignature"],
            };
        }
        baseline = @{
            @"installationHost": installationHost,
            @"hosts": baselineHosts.copy,
        };
        objc_setAssociatedObject(outer,
            IDPrivateInteractionHostTopologyBaselineKey, baseline,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    BOOL stable = [baseline[@"installationHost"] isEqualToString:installationHost];
    NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *hosts =
        [NSMutableDictionary dictionary];
    for (NSString *name in @[@"outer", @"blockStack", @"external"]) {
        NSDictionary *raw = rawHosts[name];
        NSDictionary *baselineHost = baseline[@"hosts"][name];
        NSArray *recognizerIdentities = raw[@"recognizerIdentitySignature"];
        NSArray *interactionIdentities = raw[@"interactionIdentitySignature"];
        NSArray *baselineRecognizers =
            baselineHost[@"recognizerIdentitySignature"] ?: @[];
        NSArray *baselineInteractions =
            baselineHost[@"interactionIdentitySignature"] ?: @[];
        if (![recognizerIdentities isEqualToArray:baselineRecognizers] ||
            ![interactionIdentities isEqualToArray:baselineInteractions]) {
            stable = NO;
        }
        NSMutableDictionary *host = [raw mutableCopy];
        host[@"baselineRecognizerIdentitySignature"] = baselineRecognizers;
        host[@"baselineInteractionIdentitySignature"] = baselineInteractions;
        host[@"addedRecognizerIdentitySignature"] =
            IDPrivateTopologySortedDifference(recognizerIdentities, baselineRecognizers);
        host[@"addedInteractionIdentitySignature"] =
            IDPrivateTopologySortedDifference(interactionIdentities, baselineInteractions);
        host[@"removedRecognizerIdentitySignature"] =
            IDPrivateTopologySortedDifference(baselineRecognizers, recognizerIdentities);
        host[@"removedInteractionIdentitySignature"] =
            IDPrivateTopologySortedDifference(baselineInteractions, interactionIdentities);
        hosts[name] = host.copy;
    }
    return @{
        @"schema": @1,
        @"installationHost": installationHost,
        @"liveHostCount": @(liveHostCount),
        @"duplicateRecognizerIdentityCount":
            @(IDPrivateTopologyDuplicateIdentityCount(
                rawHosts, @"recognizerIdentitySignature")),
        @"duplicateInteractionIdentityCount":
            @(IDPrivateTopologyDuplicateIdentityCount(
                rawHosts, @"interactionIdentitySignature")),
        @"stableForEpoch": @(stable),
        @"epochInstallationHost": baseline[@"installationHost"],
        @"hosts": hosts.copy,
    };
}

void IDPrivateResetInteractionHostTopologyBaselineForUITesting(
    UIView *outer,
    UIView *inner,
    UIView *external) {
    (void)inner;
    (void)external;
    objc_setAssociatedObject(outer,
        IDPrivateInteractionHostTopologyBaselineKey, nil,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static __attribute__((unused)) void IDPrivateStockOracleSelectorInventory(void) {
    (void)NSSelectorFromString(TGPN_interactionAssistant());
    (void)NSSelectorFromString(TGPN_selectionContainerView());
    (void)NSSelectorFromString(@"id_selectionPresentationBackend");
    (void)NSSelectorFromString(@"existingSelectionContainerView");
    (void)NSSelectorFromString(@"selectionContainerCreationCount");
    (void)NSSelectorFromString(TGPN_activeInstance());
    (void)NSSelectorFromString(TGPN_keyboardStateManager());
    (void)NSSelectorFromString(TGPN_inputDelegateManager());
}

static IMP IDPrivateStockOriginalCursorPositionIMP;
static NSUInteger IDPrivateStockCursorSequence;
static CGPoint IDPrivateStockCursorPoint;
static __weak UIView *IDPrivateStockCursorEditor;
static NSInteger IDPrivateStockCursorOutputOffset;
static NSInteger IDPrivateStockCursorOutputAffinity;
static BOOL IDPrivateStockCursorOutputValid;
static BOOL IDPrivateStockCursorUsedFirstContainer;
static const void *IDPrivateFloatingTerminalObserverKey =
    &IDPrivateFloatingTerminalObserverKey;
static const void *IDPrivateFloatingActionObserverKey =
    &IDPrivateFloatingActionObserverKey;

static void IDPrivateStockStartAutoscroll(id self, SEL selector, CGPoint point) {
    UIView *view = self;
    IDPrivateRecordTextAutoscrollStartForUITesting(
        self, point, point, view.bounds, view.bounds, 0, @"uikit");
    struct objc_super superInfo = { self, class_getSuperclass(object_getClass(self)) };
    ((void (*)(struct objc_super *, SEL, CGPoint))objc_msgSendSuper)(
        &superInfo, selector, point);
}

static void IDPrivateStockCancelAutoscroll(id self, SEL selector) {
    IDPrivateRecordTextAutoscrollCancelForUITesting(self);
    struct objc_super superInfo = { self, class_getSuperclass(object_getClass(self)) };
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&superInfo, selector);
}

static void IDPrivateStockEndFloatingCursor(id self, SEL selector) {
    IDPrivateRecordFloatingLifecycleEventForUITesting(self, @"normalEnd");
    struct objc_super superInfo = { self, class_getSuperclass(object_getClass(self)) };
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&superInfo, selector);
}

static BOOL IDPrivateStockResignFirstResponder(id self, SEL selector) {
    BOOL wasFirstResponder = [self isFirstResponder];
    struct objc_super superInfo = { self, class_getSuperclass(object_getClass(self)) };
    BOOL result = ((BOOL (*)(struct objc_super *, SEL))objc_msgSendSuper)(&superInfo, selector);
    if (result && wasFirstResponder) {
        IDPrivateRecordFloatingLifecycleEventForUITesting(self, @"responderLoss");
    }
    return result;
}

static void IDPrivateStockSetEditable(id self, SEL selector, BOOL editable) {
    BOOL changedOff = ((BOOL (*)(id, SEL))objc_msgSend)(
        self, NSSelectorFromString(@"isEditable")) && !editable;
    struct objc_super superInfo = { self, class_getSuperclass(object_getClass(self)) };
    ((void (*)(struct objc_super *, SEL, BOOL))objc_msgSendSuper)(
        &superInfo, selector, editable);
    if (changedOff) IDPrivateRecordFloatingLifecycleEventForUITesting(self, @"editableOff");
}

static void IDPrivateStockSetSelectable(id self, SEL selector, BOOL selectable) {
    BOOL changedOff = ((BOOL (*)(id, SEL))objc_msgSend)(
        self, NSSelectorFromString(@"isSelectable")) && !selectable;
    struct objc_super superInfo = { self, class_getSuperclass(object_getClass(self)) };
    ((void (*)(struct objc_super *, SEL, BOOL))objc_msgSendSuper)(
        &superInfo, selector, selectable);
    if (changedOff) IDPrivateRecordFloatingLifecycleEventForUITesting(self, @"selectableOff");
}

static UITextPosition *IDPrivateStockTracedCursorPosition(
    id controller, SEL selector, CGPoint point, id container) {
    UITextPosition *(*original)(id, SEL, CGPoint, id) =
        (UITextPosition *(*)(id, SEL, CGPoint, id))IDPrivateStockOriginalCursorPositionIMP;
    UITextPosition *result = original(controller, selector, point, container);
    id first = ((id (*)(id, SEL))objc_msgSend)(
        controller, NSSelectorFromString(TGPN_firstTextContainer()));
    @synchronized (controller) {
        UIView *editor = IDPrivateStockCursorEditor;
        id<UITextInput> input = (id<UITextInput>)editor;
        NSInteger offset = editor == nil || result == nil ? NSNotFound :
            [input offsetFromPosition:input.beginningOfDocument toPosition:result];
        NSInteger affinity = result == nil ? UITextStorageDirectionForward :
            ((NSInteger (*)(id, SEL, id))objc_msgSend)(controller,
                NSSelectorFromString(TGPN_affinityForPosition_()), result);
        IDPrivateStockCursorSequence += 1;
        IDPrivateStockCursorPoint = point;
        IDPrivateStockCursorOutputOffset = offset;
        IDPrivateStockCursorOutputAffinity = affinity;
        IDPrivateStockCursorOutputValid = offset >= 0;
        IDPrivateStockCursorUsedFirstContainer = container == first;
    }
    return result;
}

UIView *IDPrivateNewStockOracleTextView(Class baseClass, CGRect frame) {
    static Class stockClass;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSCAssert(baseClass != Nil, @"Stock oracle base class is required");
        stockClass = objc_allocateClassPair(baseClass, "IDPrivateStockOracleTextView", 0);
        NSDictionary<NSString *, NSValue *> *methods = @{
            TGPN_startAutoscroll_(): [NSValue valueWithPointer:IDPrivateStockStartAutoscroll],
            @"cancelAutoscroll": [NSValue valueWithPointer:IDPrivateStockCancelAutoscroll],
            @"endFloatingCursor": [NSValue valueWithPointer:IDPrivateStockEndFloatingCursor],
            @"resignFirstResponder": [NSValue valueWithPointer:IDPrivateStockResignFirstResponder],
            @"setEditable:": [NSValue valueWithPointer:IDPrivateStockSetEditable],
            @"setSelectable:": [NSValue valueWithPointer:IDPrivateStockSetSelectable],
        };
        [methods enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSValue *impValue,
                                                     BOOL *stop) {
            (void)stop;
            SEL selector = NSSelectorFromString(name);
            Method method = class_getInstanceMethod(baseClass, selector);
            NSCAssert(method != NULL, @"Stock oracle base is missing %@", name);
            class_addMethod(stockClass, selector, impValue.pointerValue,
                            method_getTypeEncoding(method));
        }];
        objc_registerClassPair(stockClass);
    });
    id value = ((id (*)(id, SEL))objc_msgSend)(stockClass, sel_registerName("alloc"));
    return ((id (*)(id, SEL, CGRect, id))objc_msgSend)(
        value, NSSelectorFromString(@"initWithFrame:textContainer:"), frame, nil);
}

void IDPrivateInstallStockCursorTraceForUITesting(UIView *editor) {
    id controller = IDPrivateTestingInternalTextLayoutController(editor);
    if (controller == nil) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
            reason:@"Stock cursor trace layout controller is unavailable" userInfo:nil];
    }
    IDPrivateStockCursorEditor = editor;
    IDPrivateStockCursorSequence = 0;
    IDPrivateStockCursorOutputValid = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL selector = NSSelectorFromString(TGPN_cursorPositionAtPoint_inContainer_());
        Method method = class_getInstanceMethod(object_getClass(controller), selector);
        if (method == NULL) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                reason:@"Stock cursor trace selector is unavailable" userInfo:nil];
        }
        IDPrivateStockOriginalCursorPositionIMP = method_getImplementation(method);
        method_setImplementation(method, (IMP)IDPrivateStockTracedCursorPosition);
    });
}

NSDictionary<NSString *, id> *IDPrivateCopyStockCursorTraceForUITesting(
    UIView *editor) {
    id controller = IDPrivateTestingInternalTextLayoutController(editor);
    @synchronized (controller) {
        if (IDPrivateStockCursorSequence == 0 || !IDPrivateStockCursorOutputValid) return nil;
        return @{
            @"sequence": @(IDPrivateStockCursorSequence), @"kind": @"cursor",
            @"interactionContainer": @(IDPrivateStockCursorUsedFirstContainer),
            @"point": IDPrivatePointJSON(IDPrivateStockCursorPoint),
            @"output": @{@"offset": @(IDPrivateStockCursorOutputOffset),
                          @"affinity": @(IDPrivateStockCursorOutputAffinity)},
        };
    }
}

static NSDictionary<NSString *, NSNumber *> *IDPrivatePointJSON(CGPoint point) {
    return @{ @"x": @(point.x), @"y": @(point.y) };
}

static NSDictionary<NSString *, NSNumber *> *IDPrivateRectJSON(CGRect rect) {
    return @{ @"x": @(rect.origin.x), @"y": @(rect.origin.y),
              @"width": @(rect.size.width), @"height": @(rect.size.height) };
}

void IDPrivateRecordTextAutoscrollStartForUITesting(
    UIScrollView *scrollContainer, CGPoint assistantPoint, CGPoint hostPoint,
    CGRect visible, CGRect safe, NSUInteger directions, NSString *engine) {
    NSDictionary *old = objc_getAssociatedObject(scrollContainer,
                                                   IDPrivateTextAutoscrollTraceKey);
    NSMutableDictionary *trace = [old mutableCopy] ?: [NSMutableDictionary dictionary];
    trace[@"startCount"] = @([old[@"startCount"] unsignedIntegerValue] + 1);
    trace[@"cancelCount"] = old[@"cancelCount"] ?: @0;
    trace[@"assistantPoint"] = IDPrivatePointJSON(assistantPoint);
    trace[@"hostPoint"] = IDPrivatePointJSON(hostPoint);
    trace[@"visible"] = IDPrivateRectJSON(visible);
    trace[@"safe"] = IDPrivateRectJSON(safe);
    trace[@"directions"] = @(directions);
    trace[@"engine"] = [engine copy];
    objc_setAssociatedObject(scrollContainer, IDPrivateTextAutoscrollTraceKey,
                             trace.copy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void IDPrivateRecordTextAutoscrollCancelForUITesting(UIScrollView *scrollContainer) {
    NSDictionary *old = objc_getAssociatedObject(scrollContainer,
                                                   IDPrivateTextAutoscrollTraceKey);
    NSMutableDictionary *trace = [old mutableCopy] ?: [NSMutableDictionary dictionary];
    trace[@"startCount"] = old[@"startCount"] ?: @0;
    trace[@"cancelCount"] = @([old[@"cancelCount"] unsignedIntegerValue] + 1);
    objc_setAssociatedObject(scrollContainer, IDPrivateTextAutoscrollTraceKey,
                             trace.copy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

NSDictionary<NSString *, id> *IDPrivateCopyTextAutoscrollTraceForUITesting(
    UIScrollView *scrollContainer) {
    return [objc_getAssociatedObject(scrollContainer,
                                     IDPrivateTextAutoscrollTraceKey) copy] ?: @{};
}

void IDPrivateRecordFloatingLifecycleEventForUITesting(
    UIScrollView *scrollContainer, NSString *event) {
    NSMutableDictionary *trace = [IDPrivateCopyTextAutoscrollTraceForUITesting(
        scrollContainer) mutableCopy];
    NSString *key = [event stringByAppendingString:@"Count"];
    trace[key] = @([trace[key] unsignedIntegerValue] + 1);
    trace[@"editable"] = @([(id)scrollContainer isEditable]);
    trace[@"selectable"] = @([(id)scrollContainer isSelectable]);
    objc_setAssociatedObject(scrollContainer, IDPrivateTextAutoscrollTraceKey,
                             trace.copy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSDictionary *terminal = objc_getAssociatedObject(
        scrollContainer, IDPrivateFloatingTerminalObserverKey);
    if ([terminal[@"event"] isEqualToString:event]) {
        IDPrivateFloatingLifecycleTerminalObserver observer = terminal[@"observer"];
        NSUInteger count = [trace[key] unsignedIntegerValue];
        CFTimeInterval terminalEpoch = CACurrentMediaTime();
        objc_setAssociatedObject(scrollContainer, IDPrivateFloatingTerminalObserverKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (observer != nil) {
            NSTimer *timer = [NSTimer timerWithTimeInterval:0 repeats:NO
                block:^(__unused NSTimer *scheduledTimer) {
                    observer(event, count, terminalEpoch);
                }];
            [[NSRunLoop mainRunLoop] addTimer:timer
                                      forMode:NSRunLoopCommonModes];
        }
    }
    NSDictionary *action = objc_getAssociatedObject(
        scrollContainer, IDPrivateFloatingActionObserverKey);
    if ([action[@"event"] isEqualToString:event]) {
        IDPrivateFloatingLifecycleTerminalObserver observer = action[@"observer"];
        NSUInteger count = [trace[key] unsignedIntegerValue];
        CFTimeInterval actionEpoch = CACurrentMediaTime();
        objc_setAssociatedObject(scrollContainer, IDPrivateFloatingActionObserverKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (observer != nil) observer(event, count, actionEpoch);
    }
}

void IDPrivateSetFloatingLifecycleTerminalObserverForUITesting(
    UIScrollView *scrollContainer, NSString *event,
    IDPrivateFloatingLifecycleTerminalObserver observer) {
    if (observer == nil) {
        objc_setAssociatedObject(scrollContainer, IDPrivateFloatingTerminalObserverKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    objc_setAssociatedObject(scrollContainer, IDPrivateFloatingTerminalObserverKey,
        @{@"event": [event copy], @"observer": [observer copy]},
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void IDPrivateSetFloatingLifecycleActionObserverForUITesting(
    UIScrollView *scrollContainer, NSString *event,
    IDPrivateFloatingLifecycleTerminalObserver observer) {
    if (observer == nil) {
        objc_setAssociatedObject(scrollContainer, IDPrivateFloatingActionObserverKey,
                                 nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    objc_setAssociatedObject(scrollContainer, IDPrivateFloatingActionObserverKey,
        @{@"event": [event copy], @"observer": [observer copy]},
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static CGRect IDPrivateTextAutoscrollSafeRectWithGeometry(
    CGRect visible, UIEdgeInsets textInsets, UIEdgeInsets adjustment,
    CGFloat horizontalAdjustment, UIEdgeInsets effective, CGFloat edgeInset) {
    textInsets.top = MAX(textInsets.top, adjustment.top);
    textInsets.left = MAX(textInsets.left, adjustment.left);
    textInsets.bottom = MAX(textInsets.bottom, adjustment.bottom);
    textInsets.right = MAX(textInsets.right, adjustment.right);
    if (horizontalAdjustment < 0) textInsets.left = horizontalAdjustment;

    visible.origin.x += textInsets.left;
    visible.origin.y += textInsets.top;
    visible.size.width -= textInsets.left + textInsets.right;
    visible.size.height -= textInsets.top + textInsets.bottom;
    visible.origin.x += effective.left;
    visible.origin.y += effective.top;
    visible.size.width -= effective.left + effective.right;
    visible.size.height -= effective.top + effective.bottom;
    return CGRectInset(visible, edgeInset, edgeInset);
}

CGRect IDPrivateTestingTextAutoscrollSafeRectWithGeometry(
    CGRect visible, UIEdgeInsets textInsets, UIEdgeInsets insetAdjustment,
    CGFloat horizontalAdjustment, UIEdgeInsets effectiveContentInset,
    CGFloat edgeInset) {
    return IDPrivateTextAutoscrollSafeRectWithGeometry(
        visible, textInsets, insetAdjustment, horizontalAdjustment,
        effectiveContentInset, edgeInset);
}

UIScrollView *IDPrivateTestingNewTextAutoscrollHostWithIncompatibleIvar(
    IDPrivateTestingIncompatibleAutoscrollIvar incompatibleIvar) {
    NSString *className = [NSString stringWithFormat:
        @"IDPrivateWrongAutoscrollIvarHost%lu", (unsigned long)incompatibleIvar];
    Class hostClass = NSClassFromString(className);
    if (hostClass == Nil) {
        hostClass = objc_allocateClassPair(UIScrollView.class, className.UTF8String, 0);
        const char *ivarName = incompatibleIvar ==
            IDPrivateTestingIncompatibleAutoscrollIvarTextContainerInsetAdjustment
            ? TGPN__textContainerInsetAdjustment().UTF8String
            : TGPN__horizontalTextContainerGeometryAdjustment().UTF8String;
        BOOL added = class_addIvar(hostClass, ivarName, sizeof(uint8_t), 0,
                                   @encode(uint8_t));
        if (!added) {
            objc_disposeClassPair(hostClass);
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                reason:@"Could not construct incompatible autoscroll test host"
              userInfo:nil];
        }
        objc_registerClassPair(hostClass);
    }
    UIScrollView *host = [[hostClass alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
    host.contentSize = CGSizeMake(320, 1000);
    return host;
}

static void IDPrivateRequireSignature(id target, SEL selector,
                                      const char *returnType,
                                      NSUInteger argumentCount,
                                      const char * _Nullable argumentType) {
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    BOOL valid = signature != nil && signature.numberOfArguments == argumentCount &&
        strcmp(signature.methodReturnType, returnType) == 0;
    if (valid && argumentType != NULL) {
        valid = strcmp([signature getArgumentTypeAtIndex:2], argumentType) == 0;
    }
    if (!valid) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
            reason:[NSString stringWithFormat:@"Private operation ABI is unavailable for %@",
                                                NSStringFromSelector(selector)]
          userInfo:nil];
    }
}

static const char *IDPrivateSkipEncodingFieldName(const char *encoding) {
    if (*encoding != '"') return encoding;
    encoding += 1;
    while (*encoding != '\0' && *encoding != '"') {
        if (*encoding == '\\' && encoding[1] != '\0') encoding += 1;
        encoding += 1;
    }
    return *encoding == '"' ? encoding + 1 : encoding;
}

static BOOL IDPrivateTypeEncodingsMatch(const char *actual, const char *expected) {
    while (*actual != '\0' || *expected != '\0') {
        actual = IDPrivateSkipEncodingFieldName(actual);
        expected = IDPrivateSkipEncodingFieldName(expected);
        if (*actual != *expected) return NO;
        if (*actual != '\0') actual += 1;
        if (*expected != '\0') expected += 1;
    }
    return YES;
}

static void IDPrivateRequireIvarABI(Ivar ivar, const char *expectedEncoding,
                                    NSString *name) {
    const char *encoding = ivar_getTypeEncoding(ivar);
    NSUInteger actualSize = 0;
    NSUInteger actualAlignment = 0;
    NSUInteger expectedSize = 0;
    NSUInteger expectedAlignment = 0;
    if (encoding != NULL) {
        NSGetSizeAndAlignment(encoding, &actualSize, &actualAlignment);
    }
    NSGetSizeAndAlignment(expectedEncoding, &expectedSize, &expectedAlignment);
    if (encoding == NULL || !IDPrivateTypeEncodingsMatch(encoding, expectedEncoding) ||
        actualSize != expectedSize || actualAlignment != expectedAlignment) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
            reason:[NSString stringWithFormat:@"Recovered %@ ABI is incompatible", name]
          userInfo:nil];
    }
}

UITextPosition *IDPrivateTestingCursorPositionAtPoint(
    UIView *textInput, id layoutController, CGPoint point, id *textContainer) {
    if (layoutController == nil) {
        SEL controllerSelector = NSSelectorFromString(TGPN__internalTextLayoutController());
        IDPrivateRequireSignature(textInput, controllerSelector, @encode(id), 2, NULL);
        layoutController = ((id (*)(id, SEL))objc_msgSend)(textInput, controllerSelector);
    }
    SEL containerSelector = NSSelectorFromString(TGPN_firstTextContainer());
    IDPrivateRequireSignature(layoutController, containerSelector, @encode(id), 2, NULL);
    id container = ((id (*)(id, SEL))objc_msgSend)(layoutController, containerSelector);
    SEL cursorSelector = NSSelectorFromString(TGPN_cursorPositionAtPoint_inContainer_());
    NSMethodSignature *signature = [layoutController methodSignatureForSelector:cursorSelector];
    BOOL valid = signature != nil && signature.numberOfArguments == 4 &&
        strcmp(signature.methodReturnType, @encode(id)) == 0 &&
        strcmp([signature getArgumentTypeAtIndex:2], @encode(CGPoint)) == 0 &&
        strcmp([signature getArgumentTypeAtIndex:3], @encode(id)) == 0;
    if (!valid) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
            reason:@"Private cursor resolution ABI is unavailable" userInfo:nil];
    }
    if (textContainer != NULL) *textContainer = container;
    return ((id (*)(id, SEL, CGPoint, id))objc_msgSend)(
        layoutController, cursorSelector, point, container);
}

id IDPrivateTestingInternalTextLayoutController(UIView *textInput) {
    SEL selector = NSSelectorFromString(TGPN__internalTextLayoutController());
    IDPrivateRequireSignature(textInput, selector, @encode(id), 2, NULL);
    return ((id (*)(id, SEL))objc_msgSend)(textInput, selector);
}

id IDPrivateTestingCustomRenderController(UIView *textInput) {
    SEL selector = NSSelectorFromString(TGPN_customRenderController());
    IDPrivateRequireSignature(textInput, selector, @encode(id), 2, NULL);
    return ((id (*)(id, SEL))objc_msgSend)(textInput, selector);
}

CGPoint IDPrivateTestingConvertPointFromRenderSpace(UIView *textInput, CGPoint point) {
    SEL selector = NSSelectorFromString(TGPN__convertPointFromRenderSpace_());
    IDPrivateRequireSignature(textInput, selector, @encode(CGPoint), 3, @encode(CGPoint));
    return ((CGPoint (*)(id, SEL, CGPoint))objc_msgSend)(textInput, selector, point);
}

CGPoint IDPrivateTestingTextContainerOrigin(UIView *containerView) {
    SEL selector = NSSelectorFromString(TGPN_textContainerOrigin());
    IDPrivateRequireSignature(containerView, selector, @encode(CGPoint), 2, NULL);
    return ((CGPoint (*)(id, SEL))objc_msgSend)(containerView, selector);
}

void IDPrivateTestingWithTextContainerInsetAdjustment(
    UIScrollView *scrollContainer, UIEdgeInsets adjustment,
    void (NS_NOESCAPE ^body)(void)) {
    Ivar ivar = class_getInstanceVariable(scrollContainer.class,
        TGPN__textContainerInsetAdjustment().UTF8String);
    if (ivar == NULL) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
            reason:@"Private inset-adjustment testing ABI is unavailable" userInfo:nil];
    }
    IDPrivateRequireIvarABI(ivar, @encode(UIEdgeInsets),
                           @"testing text-container inset adjustment");
    uint8_t *bytes = (uint8_t *)(__bridge void *)scrollContainer + ivar_getOffset(ivar);
    UIEdgeInsets original = UIEdgeInsetsZero;
    memcpy(&original, bytes, sizeof(original));
    memcpy(bytes, &adjustment, sizeof(adjustment));
    @try {
        body();
    } @finally {
        memcpy(bytes, &original, sizeof(original));
    }
}

CGRect IDPrivateTextAutoscrollSafeRect(UIScrollView *scrollContainer,
                                       UIEdgeInsets textInsets,
                                       CGFloat edgeInset) {
    SEL visibleSelector = NSSelectorFromString(@"visibleBounds");
    SEL effectiveInsetSelector = NSSelectorFromString(TGPN__effectiveContentInset());
    NSMethodSignature *visibleSignature =
        [scrollContainer methodSignatureForSelector:visibleSelector];
    NSMethodSignature *effectiveSignature =
        [scrollContainer methodSignatureForSelector:effectiveInsetSelector];
    if (visibleSignature == nil || visibleSignature.numberOfArguments != 2 ||
        strcmp(visibleSignature.methodReturnType, @encode(CGRect)) != 0 ||
        effectiveSignature == nil || effectiveSignature.numberOfArguments != 2 ||
        strcmp(effectiveSignature.methodReturnType, @encode(UIEdgeInsets)) != 0) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
            reason:@"Recovered text autoscroll geometry ABI is unavailable"
          userInfo:nil];
    }

    CGRect visible = ((CGRect (*)(id, SEL))objc_msgSend)(scrollContainer,
                                                         visibleSelector);
    UIEdgeInsets adjustment = UIEdgeInsetsZero;
    Ivar adjustmentIvar = class_getInstanceVariable(scrollContainer.class,
        TGPN__textContainerInsetAdjustment().UTF8String);
    if (adjustmentIvar != NULL) {
        IDPrivateRequireIvarABI(adjustmentIvar, @encode(UIEdgeInsets),
                               @"text-container inset adjustment");
        memcpy(&adjustment,
               (uint8_t *)(__bridge void *)scrollContainer + ivar_getOffset(adjustmentIvar),
               sizeof(adjustment));
    }
    CGFloat horizontalAdjustment = 0;
    Ivar horizontalIvar = class_getInstanceVariable(scrollContainer.class,
        TGPN__horizontalTextContainerGeometryAdjustment().UTF8String);
    if (horizontalIvar != NULL) {
        IDPrivateRequireIvarABI(horizontalIvar, @encode(CGFloat),
                               @"horizontal text-container geometry adjustment");
        memcpy(&horizontalAdjustment,
               (uint8_t *)(__bridge void *)scrollContainer + ivar_getOffset(horizontalIvar),
               sizeof(horizontalAdjustment));
    }
    UIEdgeInsets effective = ((UIEdgeInsets (*)(id, SEL))objc_msgSend)(
        scrollContainer, effectiveInsetSelector);
    return IDPrivateTextAutoscrollSafeRectWithGeometry(
        visible, textInsets, adjustment, horizontalAdjustment, effective, edgeInset);
}

NSUInteger IDPrivateTextAutoscrollDirections(UIScrollView *scrollContainer,
                                              UIEdgeInsets textInsets,
                                              CGPoint point,
                                              CGFloat edgeInset) {
    CGRect safe = IDPrivateTextAutoscrollSafeRect(scrollContainer, textInsets, edgeInset);
    if (CGRectGetHeight(safe) + 2.0 * edgeInset >= scrollContainer.contentSize.height) return 0;
    if (point.y > CGRectGetMaxY(safe)) return 8U;
    if (point.y < CGRectGetMinY(safe)) return 4U;
    return 0;
}

static CGRect IDPrivateVisibleDescendantBoundsInView(UIView *view, UIView *coordinateView) {
    if (view.hidden || view.alpha <= 0.01) return CGRectNull;
    CGRect result = [view convertRect:view.bounds toView:coordinateView];
    for (UIView *subview in view.subviews) {
        CGRect child = IDPrivateVisibleDescendantBoundsInView(subview, coordinateView);
        if (!CGRectIsNull(child)) result = CGRectUnion(result, child);
    }
    return result;
}

NSArray<NSValue *> *IDPrivateVisibleSelectionHandleRects(UIView *root) {
    NSMutableArray<NSValue *> *result = [NSMutableArray array];
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:root];
    while (pending.count > 0) {
        UIView *view = pending.lastObject;
        [pending removeLastObject];
        [pending addObjectsFromArray:view.subviews];
        if (![NSStringFromClass(view.class) containsString:TGPN__UITextSelectionLollipopView()] ||
            view.hidden || view.alpha <= 0.01) continue;
        CGRect rect = IDPrivateVisibleDescendantBoundsInView(view, root);
        if (!CGRectIsNull(rect) && !CGRectIsEmpty(rect))
            [result addObject:[NSValue valueWithCGRect:rect]];
    }
    return result.copy;
}

typedef struct {
    __unsafe_unretained NSString *className;
    BOOL classMethod;
    SEL selector;
    BOOL required;
} IDContract;

// telegram-ios DEVIATION 2 (the only source edit in the 78-file port; see PROVENANCE.md).
// The vendored kernel carve Host/TGRichTextInputDecHostPreflight.m ALSO defines a class
// named IDInteractionABISpec -- it was carved out of THIS file. Both link into the same
// binary, so the two would collide as duplicate _OBJC_CLASS_$_IDInteractionABISpec symbols.
// The carve is vendor-owned and must not be edited, so the rename happens here, and as a
// runtime-name attribute rather than an identifier rename so that the other 47 references
// to this class stay byte-identical to upstream.
__attribute__((objc_runtime_name("IDUpstreamInteractionABISpec")))
@interface IDInteractionABISpec : NSObject
@property(nonatomic, copy, readonly) NSString *selectorName;
@property(nonatomic, readonly) const char *returnType;
@property(nonatomic, copy, readonly) NSArray<NSString *> *argumentTypes;
- (instancetype)initWithSelectorName:(NSString *)selectorName
                          returnType:(const char *)returnType
                       argumentTypes:(NSArray<NSString *> *)argumentTypes;
@end

@implementation IDInteractionABISpec

- (instancetype)initWithSelectorName:(NSString *)selectorName
                          returnType:(const char *)returnType
                       argumentTypes:(NSArray<NSString *> *)argumentTypes {
    self = [super init];
    if (self) {
        _selectorName = [selectorName copy];
        _returnType = returnType;
        _argumentTypes = [argumentTypes copy];
    }
    return self;
}

@end

static IDInteractionABISpec *IDInteractionABISpecMake(
    NSString *selectorName,
    const char *returnType,
    NSArray<NSString *> *argumentTypes) {
    return [[IDInteractionABISpec alloc] initWithSelectorName:selectorName
                                                  returnType:returnType
                                               argumentTypes:argumentTypes];
}

static NSString *IDInteractionTypeEncoding(const char *encoding) {
    return encoding == NULL ? @"<missing>" : [NSString stringWithUTF8String:encoding];
}

static NSArray<IDInteractionABISpec *> *IDInteractionHostABISpecs(void) {
    return @[
        IDInteractionABISpecMake(TGPN_interactionAssistant(), @encode(id), @[]),
        IDInteractionABISpecMake(TGPN__textInputViewForAddingGestureRecognizers(), @encode(id), @[]),
        IDInteractionABISpecMake(TGPN_selectionContainerView(), @encode(id), @[]),
    ];
}

static const char *IDInteractionSkipTypeQualifiers(const char *encoding) {
    while (encoding != NULL && strchr("rnNoORV", encoding[0]) != NULL) {
        encoding += 1;
    }
    return encoding;
}

static BOOL IDInteractionTypeMatches(const char *actual, const char *expected) {
    actual = IDInteractionSkipTypeQualifiers(actual);
    expected = IDInteractionSkipTypeQualifiers(expected);
    if (actual == NULL || expected == NULL) return actual == expected;
    if (expected[0] == '@' && expected[1] == '\0') {
        return actual[0] == '@' && actual[1] != '?';
    }
    return strcmp(actual, expected) == 0;
}

static NSString *IDInteractionABIMismatchForSignature(
    NSMethodSignature *signature,
    IDInteractionABISpec *spec) {
    if (signature == nil) {
        return [NSString stringWithFormat:@"%@ is missing", spec.selectorName];
    }
    NSUInteger explicitCount = signature.numberOfArguments >= 2
        ? signature.numberOfArguments - 2
        : 0;
    BOOL matches = IDInteractionTypeMatches(signature.methodReturnType, spec.returnType) &&
        explicitCount == spec.argumentTypes.count;
    if (matches) {
        for (NSUInteger index = 0; index < explicitCount; index += 1) {
            if (!IDInteractionTypeMatches([signature getArgumentTypeAtIndex:index + 2],
                                          spec.argumentTypes[index].UTF8String)) {
                matches = NO;
                break;
            }
        }
    }
    if (matches) return nil;

    NSMutableArray<NSString *> *actualArguments = [NSMutableArray array];
    for (NSUInteger index = 0; index < explicitCount; index += 1) {
        [actualArguments addObject:IDInteractionTypeEncoding(
            [signature getArgumentTypeAtIndex:index + 2])];
    }
    return [NSString stringWithFormat:
        @"%@ expected return %s arguments (%@), got return %@ arguments (%@)",
        spec.selectorName,
        spec.returnType,
        [spec.argumentTypes componentsJoinedByString:@", "],
        IDInteractionTypeEncoding(signature.methodReturnType),
        [actualArguments componentsJoinedByString:@", "]];
}

static NSString *IDInteractionABIMismatch(id target, IDInteractionABISpec *spec) {
    SEL selector = NSSelectorFromString(spec.selectorName);
    return IDInteractionABIMismatchForSignature(
        [target methodSignatureForSelector:selector], spec);
}

static NSArray<NSString *> *IDInteractionInstanceABIMismatches(
    Class cls,
    NSArray<IDInteractionABISpec *> *specs) {
    NSMutableArray<NSString *> *mismatches = [NSMutableArray array];
    // Run `+initialize` first: it adds the callbacks UIKit calls under private names, and
    // `class_getInstanceMethod` does not run it (`TGPrivateMethodAliases.h`).
    (void)[cls class];
    for (IDInteractionABISpec *spec in specs) {
        Method method = class_getInstanceMethod(cls, NSSelectorFromString(spec.selectorName));
        NSMethodSignature *signature = method == NULL ? nil :
            [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
        NSString *mismatch = IDInteractionABIMismatchForSignature(signature, spec);
        if (mismatch != nil) [mismatches addObject:mismatch];
    }
    return mismatches.copy;
}

static NSArray<NSString *> *IDInteractionABIMismatches(
    id target,
    NSArray<IDInteractionABISpec *> *specs) {
    NSMutableArray<NSString *> *mismatches = [NSMutableArray array];
    for (IDInteractionABISpec *spec in specs) {
        NSString *mismatch = IDInteractionABIMismatch(target, spec);
        if (mismatch != nil) [mismatches addObject:mismatch];
    }
    return mismatches.copy;
}

static NSDictionary<NSString *, id> *IDProductionContractDictionary(void) {
    static NSDictionary<NSString *, id> *dictionary;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *name = @"UIKitBehaviorContracts-iOS26.5";
        NSURL *URL = [[NSBundle bundleForClass:IDPrivateUIKit.class]
            URLForResource:name withExtension:@"json"];
        if (URL == nil) {
            URL = [NSBundle.mainBundle URLForResource:name
                                        withExtension:@"json"];
        }
        NSData *data = URL == nil ? nil : [NSData dataWithContentsOfURL:URL];
        // telegram-ios DEVIATION 5 (see PROVENANCE.md), site 2 of 2 — and this is the one that
        // makes upstream's runtime gate REAL. Without it `data` is always nil here, this function
        // returns @{}, IDRequiredContracts() below is EMPTY, and +missingContracts iterates zero
        // rows — so requireCompatibleRuntime passes because it has nothing to check, on all ten
        // capabilities, before every host this module stands up. Same one-line additive shape as
        // site 1: upstream's lookup runs first, upstream's parse runs below, unchanged.
        if (data == nil) { data = TGRichTextInputDecUpstreamPristineContractJSON(); }
        id object = data == nil
            ? nil
            : [NSJSONSerialization JSONObjectWithData:data
                                              options:0
                                                error:nil];
        dictionary = [object isKindOfClass:NSDictionary.class]
            ? object
            : @{};
    });
    return dictionary;
}

static NSArray<NSValue *> *IDRequiredContracts(void) {
    static NSArray<NSValue *> *values;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSDictionary<NSString *, id> *root =
            IDProductionContractDictionary();
        NSMutableArray<NSDictionary<NSString *, id> *> *members =
            [NSMutableArray array];
        for (NSString *sectionName in @[@"capabilities", @"referenceOnly"]) {
            NSDictionary<NSString *, id> *section = root[sectionName];
            NSArray<NSString *> *capabilityNames =
                [section.allKeys sortedArrayUsingSelector:@selector(compare:)];
            for (NSString *capabilityName in capabilityNames) {
                NSArray<NSDictionary<NSString *, id> *> *capabilityMembers =
                    section[capabilityName][@"members"];
                [members addObjectsFromArray:capabilityMembers ?: @[]];
            }
        }
        NSMutableArray<NSValue *> *items =
            [NSMutableArray arrayWithCapacity:members.count];
        for (NSDictionary<NSString *, id> *member in members) {
            NSString *kind = member[@"kind"];
            if ([kind isEqualToString:@"protocol"]) {
                continue;
            }
            IDContract contract = {
                member[@"class"],
                [kind isEqualToString:@"classMethod"],
                NSSelectorFromString(member[@"name"]),
                [member[@"required"] boolValue],
            };
            [items addObject:
                [NSValue valueWithBytes:&contract
                               objCType:@encode(IDContract)]];
        }
        values = items.copy;
    });
    return values;
}

static NSArray<NSString *> *IDRequiredProtocolNames(void) {
    static NSArray<NSString *> *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSDictionary<NSString *, id> *root =
            IDProductionContractDictionary();
        NSMutableOrderedSet<NSString *> *required =
            [NSMutableOrderedSet orderedSet];
        for (NSString *sectionName in @[@"capabilities", @"referenceOnly"]) {
            NSDictionary<NSString *, id> *section = root[sectionName];
            for (NSDictionary<NSString *, id> *capability
                     in section.allValues) {
                for (NSDictionary<NSString *, id> *member
                         in capability[@"members"] ?: @[]) {
                    if ([member[@"kind"] isEqualToString:@"protocol"] &&
                        [member[@"required"] boolValue]) {
                        [required addObject:member[@"name"]];
                    }
                }
            }
        }
        names = required.array;
    });
    return names;
}

@implementation IDPrivateUIKit

+ (void)requireCompatibleRuntime {
    if (self.isCompatible) {
        return;
    }

    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:self.compatibilityReport
                                 userInfo:nil];
}

+ (void)requireObject:(id)object stage:(NSString *)stage {
    if (object != nil) {
        return;
    }

    NSString *reason = [NSString stringWithFormat:@"%@ failed.\n%@",
                                                  stage,
                                                  self.compatibilityReport];
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:reason
                                 userInfo:nil];
}

+ (void)requireObject:(id)object
    respondsToSelector:(SEL)selector
                 stage:(NSString *)stage {
    if (object != nil && [object respondsToSelector:selector]) {
        return;
    }

    NSString *reason = [NSString stringWithFormat:
        @"%@ failed: result %@ does not respond to %@.\n%@",
        stage,
        object ?: @"<nil>",
        NSStringFromSelector(selector),
        self.compatibilityReport];
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:reason
                                 userInfo:nil];
}

+ (NSArray<NSString *> *)missingContracts {
    NSMutableArray *missing = [NSMutableArray array];
    if (NSProtocolFromString(TGPN_UITextPasteConfigurationSupporting_Internal()) == nil) {
        [missing addObject:[@"protocol " stringByAppendingString:TGPN_UITextPasteConfigurationSupporting_Internal()]];
    }
    for (NSString *protocolName in IDRequiredProtocolNames()) {
        if (NSProtocolFromString(protocolName) == nil) {
            [missing addObject:[@"protocol "
                stringByAppendingString:protocolName]];
        }
    }
    for (NSValue *value in IDRequiredContracts()) {
        IDContract contract;
        [value getValue:&contract];
        Class cls = NSClassFromString(contract.className);
        (void)[cls class]; // runs `+initialize`, which adds callbacks under private names
        BOOL present = cls && (contract.classMethod
            ? [cls respondsToSelector:contract.selector]
            : class_getInstanceMethod(cls, contract.selector) != NULL);
        if (contract.required && !present) {
            [missing addObject:[NSString stringWithFormat:@"%@ %@%@",
                contract.className,
                contract.classMethod ? @"+" : @"-",
                NSStringFromSelector(contract.selector)]];
        }
    }
    return missing;
}

+ (BOOL)isCompatible {
    return self.missingContracts.count == 0;
}

+ (NSString *)compatibilityReport {
    NSArray *missing = self.missingContracts;
    __block NSUInteger requiredContractCount = 0;
    for (NSValue *value in IDRequiredContracts()) {
        IDContract contract;
        [value getValue:&contract];
        if (contract.required) requiredContractCount += 1;
    }
    Class baseClass = NSClassFromString(TGPN__UITextLayoutControllerBase());
    SEL factory = NSSelectorFromString(TGPN_layoutControllerWithTextView_textContainer_());
    NSString *layoutPath = [baseClass respondsToSelector:factory]
        ? [TGPN__UITextLayoutControllerBase() stringByAppendingString:@" factory"]
        : [NSString stringWithFormat:@"direct %@ initializer (factory unavailable)", TGPN__UITextKit2LayoutController()];
    // Assembled from parts: the private names are decoded at run time (`TGPrivateRuntimeNames.h`),
    // so the report reads as it always did and no private name is compiled in as text.
    NSArray<NSString *> *lines = @[
        [@"iOS " stringByAppendingString:UIDevice.currentDevice.systemVersion],
        [NSString stringWithFormat:@"%@ / %@", TGPN__UITextLayoutControllerBase(), TGPN__UITextKit2LayoutController()],
        TGPN_UITextInputController(),
        TGPN_UITextInteractionAssistant(),
        TGPN_UITextPasteConfigurationSupporting_Internal(),
        [@"Layout construction: " stringByAppendingString:layoutPath],
        [NSString stringWithFormat:@"Canvas map: %@.%@ (by name, not by offset)",
            TGPN__UITextKit2LayoutController(), TGPN__textCanvasViews()],
        @"Viewport contract: NSTextViewportLayoutController layoutViewport",
        @"Native fragment drawing path: NSTextLayoutFragment drawAtPoint:inContext:",
        [NSString stringWithFormat:@"Continuous-spelling bridge: %@ %@",
            TGPN_UITextInputController(), TGPN_setContinuousSpellCheckingEnabled_()],
        @"Text-input traits bridge: controller-owned UITextInputTraits with full-family forwarding",
        [NSString stringWithFormat:@"Required selector contracts preflighted: %lu", (unsigned long)requiredContractCount],
        [NSString stringWithFormat:@"Optional/fallback: base layout factory, insertDictationResult:, %@, custom renderer presence",
            TGPN_keyboardInputChangedSelection_()],
        [NSString stringWithFormat:@"Construction result preflight: %@ -> %@",
            TGPN__rangesForBackwardsDelete(), TGPN_unionRange()],
        [NSString stringWithFormat:@"Action-time contract validation: %@, %@, custom renderer setNeedsDisplay",
            TGPN_unionRange(), TGPN_textKit2Ranges()],
        missing.count
            ? [@"Missing:\n" stringByAppendingString:[missing componentsJoinedByString:@"\n"]]
            : @"All required contracts present",
    ];
    return [lines componentsJoinedByString:@"\n"];
}

+ (id)newLayoutControllerWithTextView:(UIView *)view textContainer:(NSTextContainer *)container {
    Class baseClass = NSClassFromString(TGPN__UITextLayoutControllerBase());
    SEL factory = NSSelectorFromString(TGPN_layoutControllerWithTextView_textContainer_());
    if ([baseClass respondsToSelector:factory]) {
        return ((id (*)(id, SEL, id, id))objc_msgSend)(baseClass, factory, view, container);
    }

    Class concreteClass = NSClassFromString(TGPN__UITextKit2LayoutController());
    return ((id (*)(id, SEL, id, id))objc_msgSend)(
        [concreteClass alloc],
        NSSelectorFromString(TGPN_initWithTextView_textContainer_()),
        view,
        container);
}

+ (id)newInputControllerWithLayoutController:(id)layoutController delegate:(id)delegate {
    Class cls = NSClassFromString(TGPN_UITextInputController());
    id controller = ((id (*)(id, SEL, id))objc_msgSend)(
        [cls alloc],
        NSSelectorFromString(TGPN_initWithTextLayoutController_()),
        layoutController);
    ((void (*)(id, SEL, id))objc_msgSend)(
        controller,
        NSSelectorFromString(@"setDelegate:"),
        delegate);
    return controller;
}

+ (id)newInteractionAssistantWithView:(UIView *)view {
    return [self newInteractionAssistantWithView:view
                                 assistantClass:NSClassFromString(TGPN_UITextInteractionAssistant())];
}

+ (id)newInteractionAssistantWithView:(UIView *)view assistantClass:(Class)assistantClass {
    __strong id assistant = [assistantClass alloc];
    @try {
        IDInteractionABISpec *initializer = IDInteractionABISpecMake(
            @"initWithView:",
            @encode(id),
            @[IDInteractionTypeEncoding(@encode(id))]);
        NSString *initializerMismatch = IDInteractionABIMismatch(assistant, initializer);
        if (initializerMismatch != nil) {
            NSString *reason = [NSString stringWithFormat:
                @"Interaction assistant factory preflight failed: %@\n%@",
                initializerMismatch,
                self.compatibilityReport];
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:reason
                                         userInfo:nil];
        }
        assistant = ((id (*)(id, SEL, id))objc_msgSend)(
            assistant,
            NSSelectorFromString(@"initWithView:"),
            view);
        [self requireInteractionAssistant:assistant
                                    stage:@"Interaction assistant construction preflight"];
        return assistant;
    } @catch (NSException *exception) {
        IDInteractionABISpec *clearRecognizers = IDInteractionABISpecMake(
            TGPN_clearGestureRecognizers_(),
            @encode(void),
            @[IDInteractionTypeEncoding(@encode(BOOL))]);
        NSException *cleanupException = nil;
        if (assistant != nil &&
            IDInteractionABIMismatch(assistant, clearRecognizers) == nil) {
            @try {
                ((void (*)(id, SEL, BOOL))objc_msgSend)(
                    assistant,
                    NSSelectorFromString(TGPN_clearGestureRecognizers_()),
                    YES);
            } @catch (NSException *caughtCleanupException) {
                cleanupException = caughtCleanupException;
            }
        }
        NSString *reason = [NSString stringWithFormat:
            @"Interaction assistant initialization/adoption failed (%@): %@%@",
            exception.name,
            exception.reason ?: @"<no reason>",
            cleanupException == nil
                ? @""
                : [NSString stringWithFormat:@"; cleanup also failed (%@): %@",
                                                   cleanupException.name,
                                                   cleanupException.reason ?: @"<no reason>"]];
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:exception
                                                                            forKey:@"IDPrivateUIKitUnderlyingException"];
        if (cleanupException != nil) {
            userInfo[@"IDPrivateUIKitCleanupException"] = cleanupException;
        }
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:reason
                                     userInfo:userInfo.copy];
    }
}

+ (void)requireInteractionHost:(id)host stage:(NSString *)stage {
    NSArray<IDInteractionABISpec *> *specs = IDInteractionHostABISpecs();
    NSArray<NSString *> *mismatches = IDInteractionABIMismatches(host, specs);
    if (mismatches.count == 0) return;
    NSString *reason = [NSString stringWithFormat:
        @"%@ failed: interaction host ABI mismatch:\n%@",
        stage,
        [mismatches componentsJoinedByString:@"\n"]];
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:reason
                                 userInfo:nil];
}

+ (void)requireInteractionAssistant:(id)assistant stage:(NSString *)stage {
    NSArray<IDInteractionABISpec *> *specs = @[
        IDInteractionABISpecMake(TGPN_selectionChanged(), @encode(void), @[]),
        IDInteractionABISpecMake(TGPN_activateSelection(), @encode(void), @[]),
        IDInteractionABISpecMake(TGPN_deactivateSelection(), @encode(void), @[]),
        IDInteractionABISpecMake(TGPN_setSelectionDisplayVisible_(), @encode(void),
            @[IDInteractionTypeEncoding(@encode(BOOL))]),
        IDInteractionABISpecMake(TGPN_setNeedsSelectionDisplayUpdate(), @encode(void), @[]),
        IDInteractionABISpecMake(TGPN_setGestureRecognizers(), @encode(void), @[]),
        IDInteractionABISpecMake(TGPN_clearGestureRecognizers_(), @encode(void),
            @[IDInteractionTypeEncoding(@encode(BOOL))]),
        IDInteractionABISpecMake(@"beginFloatingCursorAtPoint:", @encode(void),
            @[IDInteractionTypeEncoding(@encode(CGPoint))]),
        IDInteractionABISpecMake(@"updateFloatingCursorAtPoint:animated:", @encode(void), @[
            IDInteractionTypeEncoding(@encode(CGPoint)),
            IDInteractionTypeEncoding(@encode(BOOL)),
        ]),
        IDInteractionABISpecMake(@"endFloatingCursor", @encode(void), @[]),
        IDInteractionABISpecMake(TGPN_resignedFirstResponder(), @encode(void), @[]),
        IDInteractionABISpecMake(@"detach:", @encode(void), @[
            IDInteractionTypeEncoding(@encode(BOOL)),
        ]),
    ];
    NSArray<NSString *> *mismatches = assistant == nil
        ? @[@"assistant is nil"]
        : IDInteractionABIMismatches(assistant, specs);
    if (mismatches.count == 0) return;
    NSString *reason = [NSString stringWithFormat:
        @"%@ failed: interaction assistant ABI mismatch:\n%@\n%@",
        stage,
        [mismatches componentsJoinedByString:@"\n"],
        self.compatibilityReport];
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:reason
                                 userInfo:nil];
}

+ (void)installKeyboardInputSupportOnClass:(Class)viewClass {
    Protocol *protocol = NSProtocolFromString(TGPN_UIKeyboardInput());
    if (protocol == nil) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[TGPN_UIKeyboardInput() stringByAppendingString:@" protocol is unavailable"]
                                     userInfo:nil];
    }
    if (!class_conformsToProtocol(viewClass, protocol) &&
        !class_addProtocol(viewClass, protocol)) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"Could not install iOS 26 %@ support", TGPN_UIKeyboardInput()]
                                     userInfo:nil];
    }
}

+ (void)installTextPasteSupportOnClass:(Class)viewClass {
    Protocol *protocol = NSProtocolFromString(TGPN_UITextPasteConfigurationSupporting_Internal());
    if (class_conformsToProtocol(viewClass, protocol)) {
        return;
    }
    if (!class_addProtocol(viewClass, protocol)) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"Could not install iOS 26 internal text-paste support"
                                     userInfo:nil];
    }
}

+ (void)installTextAutoscrollingSupportOnClass:(Class)viewClass {
    Protocol *protocol = NSProtocolFromString(TGPN_UITextAutoscrolling());
    if (protocol == nil) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[TGPN_UITextAutoscrolling() stringByAppendingString:@" protocol is unavailable"]
                                     userInfo:nil];
    }
    NSArray<IDInteractionABISpec *> *specs = @[
        IDInteractionABISpecMake(TGPN_startAutoscroll_(), @encode(void),
            @[IDInteractionTypeEncoding(@encode(CGPoint))]),
        IDInteractionABISpecMake(@"cancelAutoscroll", @encode(void), @[]),
    ];
    NSArray<NSString *> *mismatches = IDInteractionInstanceABIMismatches(viewClass, specs);
    if (mismatches.count != 0) {
        NSString *reason = [NSString stringWithFormat:
            @"%@ host ABI mismatch:\n%@", TGPN_UITextAutoscrolling(),
            [mismatches componentsJoinedByString:@"\n"]];
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:reason
                                     userInfo:nil];
    }
    if (!class_conformsToProtocol(viewClass, protocol) &&
        !class_addProtocol(viewClass, protocol)) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:@"Could not install iOS 26 %@ support", TGPN_UITextAutoscrolling()]
                                     userInfo:nil];
    }
}

+ (BOOL)adoptResolvedTextAutoscrollingProtocol:(Protocol *)protocol
                                       onClass:(Class)viewClass {
    if (protocol == nil || viewClass == Nil) {
        return NO;
    }
    if (class_conformsToProtocol(viewClass, protocol)) {
        return YES;
    }
    return class_addProtocol(viewClass, protocol) &&
        class_conformsToProtocol(viewClass, protocol);
}

@end

static void IDPrivateRequireTextInputTraitsSignature(
    id target,
    NSString *selectorName,
    const char *returnType,
    NSArray<NSString *> *argumentTypes) {
    IDInteractionABISpec *spec =
        IDInteractionABISpecMake(selectorName, returnType, argumentTypes);
    Method method = class_getInstanceMethod(
        object_getClass(target), NSSelectorFromString(selectorName));
    NSMethodSignature *signature = method == NULL ? nil :
        [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    NSString *mismatch =
        IDInteractionABIMismatchForSignature(signature, spec);
    if (mismatch == nil) return;
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:
                                       @"Text-input traits ABI mismatch: %@", mismatch]
                                 userInfo:nil];
}

id IDPrivateDefaultTextInputTraits(void) {
    Class traitsClass = NSClassFromString(@"UITextInputTraits");
    SEL selector = NSSelectorFromString(TGPN_defaultTextInputTraits());
    Method method = class_getClassMethod(traitsClass, selector);
    NSMethodSignature *signature = method == NULL ? nil :
        [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    IDInteractionABISpec *spec =
        IDInteractionABISpecMake(NSStringFromSelector(selector), @encode(id), @[]);
    NSString *mismatch = IDInteractionABIMismatchForSignature(signature, spec);
    if (mismatch != nil) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[NSString stringWithFormat:
                                           @"Text-input traits ABI mismatch: %@", mismatch]
                                     userInfo:nil];
    }
    id traits = ((id (*)(id, SEL))objc_msgSend)(traitsClass, selector);
    [IDPrivateUIKit requireObject:traits stage:@"Default text-input traits"];
    return traits;
}

id IDPrivateInputTextInputTraits(id inputController) {
    SEL selector = NSSelectorFromString(TGPN__textInputTraits());
    IDPrivateRequireTextInputTraitsSignature(
        inputController, NSStringFromSelector(selector), @encode(id), @[]);
    id traits = ((id (*)(id, SEL))objc_msgSend)(inputController, selector);
    [IDPrivateUIKit requireObject:traits stage:@"Input-controller text-input traits"];
    return traits;
}

void IDPrivateSynchronizeTextInputTraits(
    id inputController,
    id<UITextInputTraits> source) {
    id traits = IDPrivateInputTextInputTraits(inputController);
    NSString *integerType = IDInteractionTypeEncoding(@encode(NSInteger));
    NSString *unsignedIntegerType =
        IDInteractionTypeEncoding(@encode(NSUInteger));
    NSString *boolType = IDInteractionTypeEncoding(@encode(BOOL));
    NSString *objectType = IDInteractionTypeEncoding(@encode(id));
    for (NSString *selectorName in @[
             @"setAutocapitalizationType:",
             @"setAutocorrectionType:",
             @"setSpellCheckingType:",
             @"setSmartQuotesType:",
             @"setSmartDashesType:",
             @"setSmartInsertDeleteType:",
             @"setInlinePredictionType:",
             @"setMathExpressionCompletionType:",
             @"setKeyboardType:",
             @"setKeyboardAppearance:",
             @"setReturnKeyType:",
             @"setWritingToolsBehavior:",
         ]) {
        IDPrivateRequireTextInputTraitsSignature(
            traits, selectorName, @encode(void), @[integerType]);
    }
    for (NSString *selectorName in @[
             @"setEnablesReturnKeyAutomatically:",
             @"setSecureTextEntry:",
             @"setAllowsNumberPadPopover:",
         ]) {
        IDPrivateRequireTextInputTraitsSignature(
            traits, selectorName, @encode(void), @[boolType]);
    }
    IDPrivateRequireTextInputTraitsSignature(
        traits,
        @"setAllowedWritingToolsResultOptions:",
        @encode(void),
        @[unsignedIntegerType]);
    for (NSString *selectorName in @[
             @"setTextContentType:",
             @"setPasswordRules:",
             @"setConversationContext:",
         ]) {
        IDPrivateRequireTextInputTraitsSignature(
            traits, selectorName, @encode(void), @[objectType]);
    }

#define ID_SET_INTEGER_TRAIT(NAME, VALUE) \
    ((void (*)(id, SEL, NSInteger))objc_msgSend)( \
        traits, NSSelectorFromString(@"set" NAME @":"), (NSInteger)(VALUE))
#define ID_SET_BOOL_TRAIT(NAME, VALUE) \
    ((void (*)(id, SEL, BOOL))objc_msgSend)( \
        traits, NSSelectorFromString(@"set" NAME @":"), (BOOL)(VALUE))
#define ID_SET_OBJECT_TRAIT(NAME, VALUE) \
    ((void (*)(id, SEL, id))objc_msgSend)( \
        traits, NSSelectorFromString(@"set" NAME @":"), (VALUE))

    ID_SET_INTEGER_TRAIT("AutocapitalizationType", source.autocapitalizationType);
    ID_SET_INTEGER_TRAIT("AutocorrectionType", source.autocorrectionType);
    ID_SET_INTEGER_TRAIT("SpellCheckingType", source.spellCheckingType);
    ID_SET_INTEGER_TRAIT("SmartQuotesType", source.smartQuotesType);
    ID_SET_INTEGER_TRAIT("SmartDashesType", source.smartDashesType);
    ID_SET_INTEGER_TRAIT("SmartInsertDeleteType", source.smartInsertDeleteType);
    ID_SET_INTEGER_TRAIT("InlinePredictionType", source.inlinePredictionType);
    ID_SET_INTEGER_TRAIT("MathExpressionCompletionType",
                         source.mathExpressionCompletionType);
    ID_SET_INTEGER_TRAIT("KeyboardType", source.keyboardType);
    ID_SET_INTEGER_TRAIT("KeyboardAppearance", source.keyboardAppearance);
    ID_SET_INTEGER_TRAIT("ReturnKeyType", source.returnKeyType);
    ID_SET_BOOL_TRAIT("EnablesReturnKeyAutomatically",
                      source.enablesReturnKeyAutomatically);
    ID_SET_BOOL_TRAIT("SecureTextEntry", source.isSecureTextEntry);
    ID_SET_OBJECT_TRAIT("TextContentType", source.textContentType);
    ID_SET_OBJECT_TRAIT("PasswordRules", source.passwordRules);
    ID_SET_INTEGER_TRAIT("WritingToolsBehavior", source.writingToolsBehavior);
    ((void (*)(id, SEL, NSUInteger))objc_msgSend)(
        traits,
        @selector(setAllowedWritingToolsResultOptions:),
        source.allowedWritingToolsResultOptions);
    ID_SET_OBJECT_TRAIT("ConversationContext", source.conversationContext);
    ID_SET_BOOL_TRAIT("AllowsNumberPadPopover", source.allowsNumberPadPopover);

#undef ID_SET_INTEGER_TRAIT
#undef ID_SET_BOOL_TRAIT
#undef ID_SET_OBJECT_TRAIT
}

void IDPrivateInteractionSelectionChanged(id assistant) {
    if ([assistant respondsToSelector:NSSelectorFromString(TGPN_selectionChanged())]) {
        ((void (*)(id, SEL))objc_msgSend)(assistant, NSSelectorFromString(TGPN_selectionChanged()));
    }
}

void IDPrivateInteractionActivateSelection(id assistant) {
    if ([assistant respondsToSelector:NSSelectorFromString(TGPN_activateSelection())]) {
        ((void (*)(id, SEL))objc_msgSend)(assistant, NSSelectorFromString(TGPN_activateSelection()));
    }
}

void IDPrivateInteractionDeactivateSelection(id assistant) {
    if ([assistant respondsToSelector:NSSelectorFromString(TGPN_deactivateSelection())]) {
        ((void (*)(id, SEL))objc_msgSend)(assistant, NSSelectorFromString(TGPN_deactivateSelection()));
    }
}


void IDPrivateInteractionSetSelectionVisible(id assistant, BOOL visible) {
    if ([assistant respondsToSelector:NSSelectorFromString(TGPN_setSelectionDisplayVisible_())]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(
            assistant,
            NSSelectorFromString(TGPN_setSelectionDisplayVisible_()),
            visible);
    }
}

void IDPrivateInteractionSetNeedsSelectionDisplayUpdate(id assistant) {
    ((void (*)(id, SEL))objc_msgSend)(
        assistant,
        NSSelectorFromString(TGPN_setNeedsSelectionDisplayUpdate()));
}

void IDPrivateInteractionSetGestureRecognizers(id assistant) {
    ((void (*)(id, SEL))objc_msgSend)(assistant, NSSelectorFromString(TGPN_setGestureRecognizers()));
}

void IDPrivateInteractionClearGestureRecognizers(id assistant) {
    ((void (*)(id, SEL, BOOL))objc_msgSend)(
        assistant,
        NSSelectorFromString(TGPN_clearGestureRecognizers_()),
        YES);
}

void IDPrivateInteractionClearGestureRecognizersNonforced(id assistant) {
    ((void (*)(id, SEL, BOOL))objc_msgSend)(
        assistant,
        NSSelectorFromString(TGPN_clearGestureRecognizers_()),
        NO);
}

void IDPrivateInteractionResignedFirstResponder(id assistant) {
    ((void (*)(id, SEL))objc_msgSend)(
        assistant, NSSelectorFromString(TGPN_resignedFirstResponder()));
}

void IDPrivateInteractionDetach(id assistant, BOOL force) {
    ((void (*)(id, SEL, BOOL))objc_msgSend)(
        assistant, NSSelectorFromString(@"detach:"), force);
}

static BOOL IDPrivateTestingIvarHasObjectABI(Ivar ivar) {
    if (ivar == NULL) return NO;
    const char *type = ivar_getTypeEncoding(ivar);
    if (type == NULL || type[0] != '@') return NO;
    NSUInteger size = 0;
    NSUInteger alignment = 0;
    NSGetSizeAndAlignment(type, &size, &alignment);
    ptrdiff_t offset = ivar_getOffset(ivar);
    return size == sizeof(id) && alignment == __alignof__(id) && alignment > 0 && offset >= 0 &&
        (NSUInteger)offset % alignment == 0;
}

static id IDPrivateTestingObjectIvar(id object, const char *name) {
    if (object == nil) return nil;
    Ivar ivar = class_getInstanceVariable(object_getClass(object), name);
    if (!IDPrivateTestingIvarHasObjectABI(ivar)) return nil;
    return object_getIvar(object, ivar);
}

static id IDPrivateTestingObjectIvarOfExactClass(
    id object, const char *name, NSString *className) {
    id value = IDPrivateTestingObjectIvar(object, name);
    Class expectedClass = NSClassFromString(className);
    return value != nil && expectedClass != Nil && [value class] == expectedClass
        ? value : nil;
}

static id IDPrivateTestingZeroArgumentObjectCall(id target, SEL selector,
                                                  BOOL classMethod) {
    if (target == nil || ![target respondsToSelector:selector]) return nil;
    Class cls = classMethod ? (Class)target : object_getClass(target);
    Method method = classMethod ? class_getClassMethod(cls, selector) :
        class_getInstanceMethod(cls, selector);
    const char *encoding = method == NULL ? NULL : method_getTypeEncoding(method);
    NSMethodSignature *signature = encoding == NULL ? nil :
        [NSMethodSignature signatureWithObjCTypes:encoding];
    if (signature == nil || signature.numberOfArguments != 2 ||
        signature.methodReturnType[0] != '@') return nil;
    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static NSString *IDPrivateTestingDelegateTarget(id owner, UIView *editor,
                                                 UIView *handoff) {
    if (owner == nil) return @"nil";
    if (owner == editor) return @"editor";
    if (owner == handoff) return @"handoff";
    for (Class cls = object_getClass(owner); cls != Nil; cls = class_getSuperclass(cls)) {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList(cls, &count);
        for (unsigned int index = 0; index < count; index += 1) {
            if (!IDPrivateTestingIvarHasObjectABI(ivars[index])) continue;
            id value = object_getIvar(owner, ivars[index]);
            if (value == editor || value == handoff) {
                free(ivars);
                return value == editor ? @"editor-wrapper" : @"handoff-wrapper";
            }
        }
        free(ivars);
    }
    return @"other";
}

NSDictionary<NSString *, id> *
IDPrivateCopyKeyboardInputDelegateOwnershipForUITesting(
    UIView *editor, UIView *handoff) {
    Class implementationClass = NSClassFromString(TGPN_UIKeyboardImpl());
    id implementation = IDPrivateTestingZeroArgumentObjectCall(
        implementationClass, NSSelectorFromString(TGPN_activeInstance()), YES);
    id stateManager = IDPrivateTestingZeroArgumentObjectCall(
        implementation, NSSelectorFromString(TGPN_keyboardStateManager()), NO);
    id delegateManager = IDPrivateTestingZeroArgumentObjectCall(
        stateManager, NSSelectorFromString(TGPN_inputDelegateManager()), NO);
    BOOL valid = implementation != nil &&
        [stateManager class] == NSClassFromString(TGPN__UIKeyboardStateManager()) &&
        [delegateManager class] == NSClassFromString(TGPN_UIKBInputDelegateManager());
    id key = valid ? IDPrivateTestingObjectIvar(delegateManager, TGPN__keyInputDelegate().UTF8String) : nil;
    id selectable = valid ?
        IDPrivateTestingObjectIvar(delegateManager, TGPN__selectableDelegate().UTF8String) : nil;
    id async = valid ?
        IDPrivateTestingObjectIvar(delegateManager, TGPN__asyncInputDelegate().UTF8String) : nil;
    return @{
        @"valid": @(valid),
        @"keyInputTarget": IDPrivateTestingDelegateTarget(key, editor, handoff),
        @"selectableTarget": IDPrivateTestingDelegateTarget(selectable, editor, handoff),
        @"asyncTarget": IDPrivateTestingDelegateTarget(async, editor, handoff),
    };
}

static BOOL IDPrivateTestingObjectHasLiveTimer(id object) {
    for (Class cls = object_getClass(object); cls != Nil; cls = class_getSuperclass(cls)) {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList(cls, &count);
        for (unsigned int index = 0; index < count; index += 1) {
            const char *name = ivar_getName(ivars[index]);
            if (name != NULL && strstr(name, "timer") != NULL &&
                IDPrivateTestingIvarHasObjectABI(ivars[index]) &&
                object_getIvar(object, ivars[index]) != nil) {
                free(ivars);
                return YES;
            }
        }
        free(ivars);
    }
    return NO;
}

NSDictionary<NSString *, id> *
IDPrivateTestingFloatingCursorLifecycleSnapshot(UIView *textInput) {
    id assistant = nil;
    SEL assistantSelector = NSSelectorFromString(TGPN_interactionAssistant());
    if ([textInput respondsToSelector:assistantSelector]) {
        assistant = ((id (*)(id, SEL))objc_msgSend)(textInput, assistantSelector);
    }
    id display = nil;
    SEL displaySelector = NSSelectorFromString(TGPN__selectionViewManager());
    if ([assistant respondsToSelector:displaySelector]) {
        display = ((id (*)(id, SEL))objc_msgSend)(assistant, displaySelector);
    }
    id assistantSession = IDPrivateTestingObjectIvarOfExactClass(
        assistant, TGPN__floatingCursorSession().UTF8String, TGPN__UITextFloatingCursorSession());
    id displaySession = IDPrivateTestingObjectIvarOfExactClass(
        display, TGPN__activeFloatingCursorSession().UTF8String, TGPN__UITextFloatingCursorSession());
    id session = assistantSession ?: displaySession;
    id autoscroll = IDPrivateTestingObjectIvar(textInput, TGPN__autoscroll().UTF8String);
    if (autoscroll == nil) {
        autoscroll = IDPrivateTestingObjectIvar(textInput, "_id_textAutoscroll");
    }
    UIView *container = nil;
    SEL backendSelector = NSSelectorFromString(@"id_selectionPresentationBackend");
    if ([textInput respondsToSelector:backendSelector]) {
        id backend = ((id (*)(id, SEL))objc_msgSend)(textInput, backendSelector);
        SEL existingSelector = NSSelectorFromString(@"existingSelectionContainerView");
        if ([backend respondsToSelector:existingSelector]) {
            container = ((id (*)(id, SEL))objc_msgSend)(backend, existingSelector);
        }
    } else {
        SEL containerSelector = NSSelectorFromString(TGPN_selectionContainerView());
        if ([textInput respondsToSelector:containerSelector]) {
            container = ((id (*)(id, SEL))objc_msgSend)(textInput, containerSelector);
        }
    }
    BOOL keyboardVisible = NO;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *candidateWindow in ((UIWindowScene *)scene).windows) {
            NSString *className = NSStringFromClass(candidateWindow.class);
            if ([className containsString:@"Keyboard"] && !candidateWindow.hidden &&
                candidateWindow.alpha > 0.0) keyboardVisible = YES;
        }
    }
    NSDictionary<NSString *, id> *recognizerState = IDPrivateRecognizerState(textInput);
    UITextRange *range = [(id<UITextInput>)textInput selectedTextRange];
    NSInteger location = NSNotFound;
    NSInteger length = 0;
    if (range != nil) {
        id<UITextInput> input = (id<UITextInput>)textInput;
        location = [input offsetFromPosition:input.beginningOfDocument toPosition:range.start];
        length = [input offsetFromPosition:range.start toPosition:range.end];
    }
    return @{
        @"selection": NSStringFromRange(location < 0 || length < 0
            ? NSMakeRange(NSNotFound, 0) : NSMakeRange((NSUInteger)location, (NSUInteger)length)),
        @"firstResponder": @(textInput.isFirstResponder),
        @"keyboardVisible": @(keyboardVisible),
        @"window": @((BOOL)(textInput.window != nil)),
        @"assistant": @((BOOL)(assistant != nil)),
        @"session": @((BOOL)(session != nil)),
        @"assistantSession": @((BOOL)(assistantSession != nil)),
        @"displaySession": @((BOOL)(displaySession != nil)),
        @"sessionOwnersMatch": @((BOOL)(assistantSession != nil &&
            assistantSession == displaySession)),
        @"sessionClass": session == nil ? @"nil" : NSStringFromClass([session class]),
        @"autoscroll": @((BOOL)(autoscroll != nil)),
        @"autoscrollActive": @(IDPrivateTestingObjectHasLiveTimer(autoscroll)),
        @"container": @((BOOL)(container != nil)),
        @"containerToken": container == nil ? @"nil" :
            [NSString stringWithFormat:@"%p", container],
        @"containerSubviews": @(container.subviews.count),
        @"gestures": @(textInput.gestureRecognizers.count),
        @"recognizerCount": recognizerState[@"recognizerCount"],
        @"recognizerSignature": recognizerState[@"recognizerSignature"],
        @"recognizerBaselineCount": recognizerState[@"recognizerBaselineCount"],
        @"recognizerUnexpectedNewCount": recognizerState[@"recognizerUnexpectedNewCount"],
        @"recognizerSubsetOfBaseline": recognizerState[@"recognizerSubsetOfBaseline"],
        @"recognizerBaselineIdentitySignature": recognizerState[@"recognizerBaselineIdentitySignature"],
        @"recognizerIdentitySignature": recognizerState[@"recognizerIdentitySignature"],
        @"editable": @([(id)textInput isEditable]),
        @"selectable": @([(id)textInput isSelectable]),
    };
}

static NSString *IDPrivatePresentationFingerprint(UIView *container) {
    if (container == nil) return @"nil";
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:container];
    while (pending.count > 0) {
        UIView *view = pending.lastObject;
        [pending removeLastObject];
        [pending addObjectsFromArray:view.subviews];
        [parts addObject:[NSString stringWithFormat:@"%@|%@|%d|%.4f",
            NSStringFromClass(view.class), NSStringFromCGRect(view.frame),
            view.hidden, view.alpha]];
    }
    return [parts componentsJoinedByString:@";"];
}

static NSUInteger IDPrivateObservedPresentationUpdates(UIView *editor, UIView *container) {
    NSString *fingerprint = IDPrivatePresentationFingerprint(container);
    NSDictionary *old = objc_getAssociatedObject(editor, IDPrivateStockPresentationKey);
    NSUInteger count = [old[@"count"] unsignedIntegerValue];
    if (![old[@"fingerprint"] isEqualToString:fingerprint]) count += 1;
    objc_setAssociatedObject(editor, IDPrivateStockPresentationKey,
        @{@"count": @(count), @"fingerprint": fingerprint},
        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return count;
}

static BOOL IDPrivateTestingBoolIvar(id object, const char *name, BOOL *value) {
    if (object == nil) return NO;
    Ivar ivar = class_getInstanceVariable(object_getClass(object), name);
    if (ivar == NULL || strcmp(ivar_getTypeEncoding(ivar), @encode(BOOL)) != 0) return NO;
    ptrdiff_t offset = ivar_getOffset(ivar);
    if (offset < 0) return NO;
    if (value != NULL) *value = *(BOOL *)((uint8_t *)(__bridge void *)object + offset);
    return YES;
}

static id IDPrivateStockAssistant(UIView *editor) {
    SEL selector = NSSelectorFromString(TGPN_interactionAssistant());
    return [editor respondsToSelector:selector]
        ? ((id (*)(id, SEL))objc_msgSend)(editor, selector) : nil;
}

static id IDPrivateStockFloatingSession(UIView *editor) {
    id assistant = IDPrivateStockAssistant(editor);
    id session = IDPrivateTestingObjectIvarOfExactClass(
        assistant, TGPN__floatingCursorSession().UTF8String, TGPN__UITextFloatingCursorSession());
    if (session != nil) return session;
    SEL displaySelector = NSSelectorFromString(TGPN__selectionViewManager());
    id display = [assistant respondsToSelector:displaySelector]
        ? ((id (*)(id, SEL))objc_msgSend)(assistant, displaySelector) : nil;
    return IDPrivateTestingObjectIvarOfExactClass(
        display, TGPN__activeFloatingCursorSession().UTF8String, TGPN__UITextFloatingCursorSession());
}

static id IDPrivateStockAutoscroll(UIView *editor) {
    id assistant = IDPrivateStockAssistant(editor);
    for (id owner in @[editor, assistant ?: NSNull.null]) {
        if (owner == NSNull.null) continue;
        id value = IDPrivateTestingObjectIvar(owner, TGPN__autoscroll().UTF8String);
        if (value == nil) value = IDPrivateTestingObjectIvar(owner, "_textAutoscroll");
        if (value == nil) value = IDPrivateTestingObjectIvar(owner, "_id_textAutoscroll");
        if (value != nil) return value;
        for (Class cls = object_getClass(owner); cls != Nil; cls = class_getSuperclass(cls)) {
            unsigned int count = 0;
            Ivar *ivars = class_copyIvarList(cls, &count);
            for (unsigned int index = 0; index < count; index += 1) {
                const char *type = ivar_getTypeEncoding(ivars[index]);
                if (type == NULL || type[0] != '@') continue;
                id candidate = object_getIvar(owner, ivars[index]);
                if ([NSStringFromClass([candidate class]) containsString:@"Autoscroll"]) {
                    free(ivars);
                    return candidate;
                }
            }
            free(ivars);
        }
    }
    return nil;
}

static UIView *IDPrivateStockSelectionContainer(UIView *editor) {
    SEL selector = NSSelectorFromString(TGPN_selectionContainerView());
    return [editor respondsToSelector:selector]
        ? ((UIView *(*)(id, SEL))objc_msgSend)(editor, selector) : nil;
}

@interface IDPrivateFloatingContainerIdentityTracker : NSObject
@property(nonatomic, strong) NSMutableSet<NSNumber *> *seenIdentities;
@end

@implementation IDPrivateFloatingContainerIdentityTracker
- (instancetype)init {
    self = [super init];
    if (self != nil) _seenIdentities = [NSMutableSet set];
    return self;
}
@end

static NSNumber *IDPrivateFloatingContainerIdentityToken(UIView *container) {
    @synchronized (IDPrivateFloatingContainerIdentityTracker.class) {
        id existing = objc_getAssociatedObject(
            container, IDPrivateFloatingContainerIdentityTokenKey);
        if (existing != nil) {
            if (![existing isKindOfClass:NSNumber.class] ||
                [existing unsignedIntegerValue] == 0) {
                @throw [NSException exceptionWithName:NSInternalInconsistencyException
                    reason:@"Floating container identity token has incompatible type"
                  userInfo:nil];
            }
            return existing;
        }
        if (IDPrivateNextFloatingContainerIdentityToken == NSUIntegerMax) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                reason:@"Floating container identity token sequence exhausted"
              userInfo:nil];
        }
        NSNumber *token = @(++IDPrivateNextFloatingContainerIdentityToken);
        objc_setAssociatedObject(container, IDPrivateFloatingContainerIdentityTokenKey,
                                 token, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return token;
    }
}

static BOOL IDPrivateNoArgumentSelectorHasReturnType(id target, SEL selector,
                                                      const char *returnType) {
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    return signature != nil && signature.numberOfArguments == 2 &&
        IDInteractionTypeMatches(signature.methodReturnType, returnType);
}

NSUInteger IDPrivateFloatingContainerCreationCountForUITesting(UIView *textInput) {
    if (textInput == nil) return 0;
    SEL backendSelector = NSSelectorFromString(@"id_selectionPresentationBackend");
    if ([textInput respondsToSelector:backendSelector]) {
        if (!IDPrivateNoArgumentSelectorHasReturnType(textInput, backendSelector, @encode(id))) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                reason:@"Floating container backend accessor has incompatible ABI"
              userInfo:nil];
        }
        id backend = ((id (*)(id, SEL))objc_msgSend)(textInput, backendSelector);
        SEL countSelector = NSSelectorFromString(@"selectionContainerCreationCount");
        if (!IDPrivateNoArgumentSelectorHasReturnType(
                backend, countSelector, @encode(NSUInteger))) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                reason:@"Floating container creation count has incompatible ABI"
              userInfo:nil];
        }
        return ((NSUInteger (*)(id, SEL))objc_msgSend)(backend, countSelector);
    }

    SEL containerSelector = NSSelectorFromString(TGPN_selectionContainerView());
    if (![textInput respondsToSelector:containerSelector]) return 0;
    if (!IDPrivateNoArgumentSelectorHasReturnType(
            textInput, containerSelector, @encode(id))) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
            reason:@"Stock floating container accessor has incompatible ABI"
          userInfo:nil];
    }
    IDPrivateFloatingContainerIdentityTracker *tracker = objc_getAssociatedObject(
        textInput, IDPrivateFloatingContainerIdentityTrackerKey);
    UIView *container = IDPrivateStockSelectionContainer(textInput);
    if (container == nil) return tracker.seenIdentities.count;
    if (tracker == nil) {
        tracker = [IDPrivateFloatingContainerIdentityTracker new];
        objc_setAssociatedObject(textInput, IDPrivateFloatingContainerIdentityTrackerKey,
                                 tracker, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSNumber *token = IDPrivateFloatingContainerIdentityToken(container);
    @synchronized (tracker) {
        [tracker.seenIdentities addObject:token];
        return tracker.seenIdentities.count;
    }
}

@interface IDPrivateFloatingLifecycleWeakReferences ()
@property(nonatomic, weak) UIView *editor;
@property(nonatomic, weak) id layoutController;
@property(nonatomic, weak) id assistant;
@property(nonatomic, weak) UIView *container;
@property(nonatomic, weak) id session;
@property(nonatomic, weak) id autoscroll;
@property(nonatomic) NSUInteger observationSequence;
@property(nonatomic) CFTimeInterval releaseEpoch;
@property(nonatomic) CFTimeInterval actionEpoch;
@property(nonatomic) CFTimeInterval terminalEpoch;
@property(nonatomic) CFTimeInterval liftTargetEpoch;
@property(nonatomic) CFTimeInterval captureTargetEpoch;
@property(nonatomic, copy) NSString *observationPhase;
@property(nonatomic, copy) NSString *terminalEvent;
@property(nonatomic) NSUInteger terminalCountAtRelease;
@property(nonatomic, copy) NSDictionary<NSString *, id> *terminalSnapshot;
@property(nonatomic, copy) NSDictionary<NSString *, id> *heldSnapshot;
@property(nonatomic, copy) NSDictionary<NSString *, id> *immediateSnapshot;
@property(nonatomic, copy) NSDictionary<NSString *, id> *exactSnapshot;
@property(nonatomic, copy) NSDictionary<NSString *, id> *postLiftSnapshot;
@property(nonatomic) BOOL keyboardVisible;
@end

@implementation IDPrivateFloatingLifecycleWeakReferences

// Not the default `_autoscroll`: that is a private UIKit ivar name read above, and it must not reach
// the binary as text (`TGPrivateRuntimeNames.h`).
@synthesize autoscroll = _id_autoscroll;

- (instancetype)initWithEditor:(UIView *)editor {
    return [self initWithEditor:editor
               layoutController:IDPrivateTestingInternalTextLayoutController(editor)];
}

- (instancetype)initWithEditor:(UIView *)editor
               layoutController:(id)layoutController {
    self = [super init];
    if (self != nil) {
        [self refreshWithEditor:editor layoutController:layoutController];
        [NSNotificationCenter.defaultCenter addObserver:self
            selector:@selector(id_keyboardWillShow:)
            name:UIKeyboardWillShowNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
            selector:@selector(id_keyboardDidHide:)
            name:UIKeyboardDidHideNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)id_keyboardWillShow:(NSNotification *)notification {
    (void)notification;
    self.keyboardVisible = YES;
}

- (void)id_keyboardDidHide:(NSNotification *)notification {
    (void)notification;
    self.keyboardVisible = NO;
}

- (void)refreshWithEditor:(UIView *)editor {
    [self refreshWithEditor:editor
            layoutController:IDPrivateTestingInternalTextLayoutController(editor)];
}

- (void)refreshWithEditor:(UIView *)editor
          layoutController:(id)layoutController {
    self.editor = editor;
    self.layoutController = layoutController;
    self.assistant = IDPrivateStockAssistant(editor);
    self.container = IDPrivateStockSelectionContainer(editor);
    id session = IDPrivateStockFloatingSession(editor);
    id autoscroll = IDPrivateStockAutoscroll(editor);
    if (session != nil) self.session = session;
    if (autoscroll != nil) self.autoscroll = autoscroll;
}

- (NSDictionary<NSString *, NSNumber *> *)copyRetentionState {
    return @{
        @"editorRetained": @((BOOL)(self.editor != nil)),
        @"assistantRetained": @((BOOL)(self.assistant != nil)),
        @"containerRetained": @((BOOL)(self.container != nil)),
        @"sessionRetained": @((BOOL)(self.session != nil)),
        @"autoscrollRetained": @((BOOL)(self.autoscroll != nil)),
    };
}

- (NSDictionary<NSString *, id> *)copyAtomicFloatingSnapshot {
    UIView *editor = self.editor;
    self.observationSequence += 1;
    NSUInteger sequence = self.observationSequence;
    NSDictionary *lifecycle = editor == nil ? @{} :
        IDPrivateCopyFloatingLifecycleStateWithLayoutControllerForUITesting(
            editor, self.layoutController);
    id<UITextInput> input = (id<UITextInput>)editor;
    UITextRange *range = input.selectedTextRange;
    NSInteger location = NSNotFound;
    NSInteger length = 0;
    if (range != nil) {
        location = [input offsetFromPosition:input.beginningOfDocument toPosition:range.start];
        length = [input offsetFromPosition:range.start toPosition:range.end];
    }
    NSRange selection = location < 0 || length < 0 ? NSMakeRange(NSNotFound, 0) :
        NSMakeRange((NSUInteger)location, (NSUInteger)length);
    CGPoint offset = [editor isKindOfClass:UIScrollView.class]
        ? ((UIScrollView *)editor).contentOffset : CGPointZero;
    return @{
        @"selection": @{@"location": @(selection.location), @"length": @(selection.length)},
        @"startAffinity": lifecycle[@"startAffinity"] ?: @0,
        @"endAffinity": lifecycle[@"endAffinity"] ?: @0,
        @"firstResponder": @((BOOL)editor.isFirstResponder),
        @"keyboardVisible": @(self.keyboardVisible),
        @"containerCreations":
            @(IDPrivateFloatingContainerCreationCountForUITesting(editor)),
        @"containerStable": lifecycle[@"containerStable"] ?: @NO,
        @"presentationUpdates": lifecycle[@"presentationUpdates"] ?: @0,
        @"contentOffset": @{@"x": @(offset.x), @"y": @(offset.y)},
        @"lifecycle": lifecycle,
        @"retention": [self copyRetentionState],
        @"observation": @{
            @"source": @"app-side-weak-reference-snapshot",
            @"sequence": @(sequence), @"lifecycleSequence": @(sequence),
            @"retentionSequence": @(sequence), @"capturedAt": @(CACurrentMediaTime()),
            @"actionEpoch": @(self.actionEpoch),
            @"releaseEpoch": @(self.releaseEpoch),
            @"terminalEpoch": @(self.terminalEpoch),
            @"liftTargetEpoch": @(self.liftTargetEpoch),
            @"captureTargetEpoch": @(self.captureTargetEpoch),
            @"phase": self.observationPhase ?: @"live",
            @"terminalEvent": self.terminalEvent ?: @"none",
            @"terminalCountAtRelease": @(self.terminalCountAtRelease),
        },
    };
}

- (void)markReleaseAttemptAfterTerminalEvent:(NSString *)event
                                       count:(NSUInteger)count
                               terminalEpoch:(CFTimeInterval)terminalEpoch
                             liftTargetEpoch:(CFTimeInterval)liftTargetEpoch {
    [self markTerminalObservationForEvent:event count:count
                            terminalEpoch:terminalEpoch liftTargetEpoch:liftTargetEpoch];
    self.releaseEpoch = CACurrentMediaTime();
    self.captureTargetEpoch = self.releaseEpoch;
    self.observationPhase = @"terminal";
    self.terminalSnapshot = [self copyAtomicFloatingSnapshot];
}

- (void)markTerminalObservationForEvent:(NSString *)event
                                  count:(NSUInteger)count
                          terminalEpoch:(CFTimeInterval)terminalEpoch
                        liftTargetEpoch:(CFTimeInterval)liftTargetEpoch {
    self.terminalEvent = [event copy];
    self.terminalCountAtRelease = count;
    self.terminalEpoch = terminalEpoch;
    if (self.liftTargetEpoch == 0) self.liftTargetEpoch = liftTargetEpoch;
    self.captureTargetEpoch = terminalEpoch;
    self.observationPhase = @"terminal";
    self.terminalSnapshot = [self copyAtomicFloatingSnapshot];
}

- (void)markActionObservationAtEpoch:(CFTimeInterval)actionEpoch
                           liftDelay:(NSTimeInterval)liftDelay {
    self.actionEpoch = actionEpoch;
    self.liftTargetEpoch = actionEpoch + liftDelay;
}

- (void)recordImmediateReleaseSnapshot {
    self.captureTargetEpoch = self.releaseEpoch > 0 ? self.releaseEpoch :
        (self.actionEpoch > 0 ? self.actionEpoch : self.terminalEpoch);
    self.observationPhase = @"immediate";
    self.immediateSnapshot = [self copyAtomicFloatingSnapshot];
}

- (void)beginHeldSnapshotPollingForTerminalEvent:(NSString *)event {
    UIView *armedEditor = self.editor;
    NSString *countKey = [event stringByAppendingString:@"Count"];
    NSDictionary *armedLifecycle = armedEditor == nil ? @{} :
        IDPrivateCopyFloatingLifecycleStateWithLayoutControllerForUITesting(
            armedEditor, self.layoutController);
    NSUInteger terminalCountAtArm = [armedLifecycle[countKey] unsignedIntegerValue];
    __weak typeof(self) weakSelf = self;
    __block void (^poll)(void) = nil;
    poll = ^{
        typeof(self) self = weakSelf;
        if (self == nil || self.heldSnapshot != nil || self.releaseEpoch > 0) {
            poll = nil;
            return;
        }
        UIView *editor = self.editor;
        NSDictionary *lifecycle = editor == nil ? @{} :
            IDPrivateCopyFloatingLifecycleStateWithLayoutControllerForUITesting(
                editor, self.layoutController);
        BOOL held = editor.isFirstResponder && self.keyboardVisible &&
            [lifecycle[@"sessionActive"] boolValue] &&
            [lifecycle[countKey] unsignedIntegerValue] == terminalCountAtArm &&
            [lifecycle[@"containerStable"] boolValue];
        if (held) {
            IDPrivateFreezeRecognizerBaselineAtHeldCapture(editor);
            [self refreshWithEditor:editor
                   layoutController:self.layoutController];
            self.captureTargetEpoch = CACurrentMediaTime();
            self.observationPhase = @"held";
            self.heldSnapshot = [self copyAtomicFloatingSnapshot];
            poll = nil;
            return;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_MSEC),
                       dispatch_get_main_queue(), poll);
    };
    dispatch_async(dispatch_get_main_queue(), poll);
}

- (void)id_capturePostLiftSnapshotAtTarget:(CFTimeInterval)targetEpoch {
    self.captureTargetEpoch = targetEpoch;
    self.observationPhase = @"post-keyboard-lift-500ms";
    self.postLiftSnapshot = [self copyAtomicFloatingSnapshot];
}

- (void)scheduleReleaseSnapshots {
    CFTimeInterval baseEpoch = self.releaseEpoch > 0 ? self.releaseEpoch :
        (self.actionEpoch > 0 ? self.actionEpoch : self.terminalEpoch);
    CFTimeInterval exactTargetEpoch = baseEpoch + 0.500;
    CFTimeInterval postTargetEpoch = self.liftTargetEpoch + 0.500;
    BOOL coalescesEqualTargets = exactTargetEpoch == postTargetEpoch;
    CFTimeInterval exactDelay = MAX(exactTargetEpoch - CACurrentMediaTime(), 0);
    NSTimer *exactTimer = [[NSTimer alloc]
        initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:exactDelay]
        interval:0 repeats:NO block:^(__unused NSTimer *timer) {
        self.captureTargetEpoch = exactTargetEpoch;
        self.observationPhase = self.releaseEpoch > 0 ? @"exact-release-500ms" :
            (self.actionEpoch > 0 ? @"exact-action-500ms" : @"exact-terminal-500ms");
        self.exactSnapshot = [self copyAtomicFloatingSnapshot];
        if (coalescesEqualTargets) {
            [self id_capturePostLiftSnapshotAtTarget:postTargetEpoch];
        }
    }];
    [NSRunLoop.mainRunLoop addTimer:exactTimer forMode:NSRunLoopCommonModes];
    if (coalescesEqualTargets) return;
    CFTimeInterval postDelay = MAX(postTargetEpoch - CACurrentMediaTime(), 0);
    NSTimer *postTimer = [[NSTimer alloc]
        initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:postDelay]
        interval:0 repeats:NO block:^(__unused NSTimer *timer) {
        [self id_capturePostLiftSnapshotAtTarget:postTargetEpoch];
    }];
    [NSRunLoop.mainRunLoop addTimer:postTimer forMode:NSRunLoopCommonModes];
}

- (NSDictionary<NSString *, id> *)copyTerminalSnapshot {
    return [self.terminalSnapshot copy];
}

- (NSDictionary<NSString *, id> *)copyReleaseSnapshotForPhase:(NSString *)phase {
    if ([phase isEqualToString:@"held"]) return [self.heldSnapshot copy];
    if ([phase isEqualToString:@"immediate"]) return [self.immediateSnapshot copy];
    if ([phase isEqualToString:@"exact-release-500ms"]) return [self.exactSnapshot copy];
    if ([phase isEqualToString:@"post-keyboard-lift-500ms"])
        return [self.postLiftSnapshot copy];
    return nil;
}

@end

static NSDictionary<NSString *, id> *
IDPrivateCopyFloatingLifecycleStateWithController(UIView *editor,
                                                  id controller) {
    UIView *firstContainer = IDPrivateStockSelectionContainer(editor);
    UIView *secondContainer = IDPrivateStockSelectionContainer(editor);
    id assistant = IDPrivateStockAssistant(editor);
    SEL displaySelector = NSSelectorFromString(TGPN__selectionViewManager());
    id display = [assistant respondsToSelector:displaySelector]
        ? ((id (*)(id, SEL))objc_msgSend)(assistant, displaySelector) : nil;
    id assistantSession = IDPrivateTestingObjectIvarOfExactClass(
        assistant, TGPN__floatingCursorSession().UTF8String, TGPN__UITextFloatingCursorSession());
    id displaySession = IDPrivateTestingObjectIvarOfExactClass(
        display, TGPN__activeFloatingCursorSession().UTF8String, TGPN__UITextFloatingCursorSession());
    id session = assistantSession ?: displaySession;
    BOOL sessionActive = NO;
    (void)IDPrivateTestingBoolIvar(session, TGPN__isValid().UTF8String, &sessionActive);
    id autoscroll = IDPrivateStockAutoscroll(editor);
    NSDictionary<NSString *, id> *recognizerState = IDPrivateRecognizerState(editor);
    NSMutableDictionary *trace = [editor isKindOfClass:UIScrollView.class]
        ? [IDPrivateCopyTextAutoscrollTraceForUITesting((UIScrollView *)editor) mutableCopy]
        : [NSMutableDictionary dictionary];
    id<UITextInput> input = (id<UITextInput>)editor;
    UITextRange *range = input.selectedTextRange;
    NSInteger startAffinity = UITextStorageDirectionForward;
    NSInteger endAffinity = UITextStorageDirectionForward;
    SEL affinitySelector = NSSelectorFromString(TGPN_affinityForPosition_());
    if (range != nil && [controller respondsToSelector:affinitySelector]) {
        startAffinity = ((NSInteger (*)(id, SEL, id))objc_msgSend)(
            controller, affinitySelector, range.start);
        endAffinity = ((NSInteger (*)(id, SEL, id))objc_msgSend)(
            controller, affinitySelector, range.end);
    }
    return @{
        @"normalEndCount": trace[@"normalEndCount"] ?: @0,
        @"windowDetachActionCount": trace[@"windowDetachActionCount"] ?: @0,
        @"windowDetachCount": trace[@"windowDetachCount"] ?: @0,
        @"resignActionCount": trace[@"resignActionCount"] ?: @0,
        @"keyboardDismissActionCount": trace[@"keyboardDismissActionCount"] ?: @0,
        @"editableOffActionCount": trace[@"editableOffActionCount"] ?: @0,
        @"selectableOffActionCount": trace[@"selectableOffActionCount"] ?: @0,
        @"responderLossCount": trace[@"responderLossCount"] ?: @0,
        @"editableOffCount": trace[@"editableOffCount"] ?: @0,
        @"selectableOffCount": trace[@"selectableOffCount"] ?: @0,
        @"startCount": trace[@"startCount"] ?: @0,
        @"cancelCount": trace[@"cancelCount"] ?: @0,
        @"presentationUpdates": @(IDPrivateObservedPresentationUpdates(editor, firstContainer)),
        @"containerToken": firstContainer == nil ? @"nil" :
            [NSString stringWithFormat:@"%p", firstContainer],
        @"containerStable": @((BOOL)(firstContainer != nil &&
            firstContainer == secondContainer && firstContainer.superview != nil)),
        @"containerSubviews": @(firstContainer.subviews.count),
        @"sessionObject": @((BOOL)(session != nil)),
        @"assistantSessionObject": @((BOOL)(assistantSession != nil)),
        @"displaySessionObject": @((BOOL)(displaySession != nil)),
        @"sessionOwnersMatch": @((BOOL)(assistantSession != nil &&
            assistantSession == displaySession)),
        @"assistantSessionToken": assistantSession == nil ? @"nil" :
            [NSString stringWithFormat:@"%p", assistantSession],
        @"displaySessionToken": displaySession == nil ? @"nil" :
            [NSString stringWithFormat:@"%p", displaySession],
        @"sessionActive": @(sessionActive),
        @"autoscrollObject": @((BOOL)(autoscroll != nil)),
        @"autoscrollActive": @(IDPrivateTestingObjectHasLiveTimer(autoscroll)),
        @"recognizerCount": recognizerState[@"recognizerCount"],
        @"recognizerSignature": recognizerState[@"recognizerSignature"],
        @"recognizerBaselineCount": recognizerState[@"recognizerBaselineCount"],
        @"recognizerUnexpectedNewCount": recognizerState[@"recognizerUnexpectedNewCount"],
        @"recognizerSubsetOfBaseline": recognizerState[@"recognizerSubsetOfBaseline"],
        @"recognizerBaselineIdentitySignature": recognizerState[@"recognizerBaselineIdentitySignature"],
        @"recognizerIdentitySignature": recognizerState[@"recognizerIdentitySignature"],
        @"editable": @([(id)editor isEditable]),
        @"selectable": @([(id)editor isSelectable]),
        @"startAffinity": @(startAffinity), @"endAffinity": @(endAffinity),
    };
}

NSDictionary<NSString *, id> *
IDPrivateCopyFloatingLifecycleStateWithLayoutControllerForUITesting(
    UIView *editor,
    id layoutController) {
    if (layoutController == nil) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException
            reason:@"Floating lifecycle diagnostics require an explicit layout controller"
          userInfo:nil];
    }
    return IDPrivateCopyFloatingLifecycleStateWithController(
        editor, layoutController);
}

NSDictionary<NSString *, id> *
IDPrivateCopyStockFloatingLifecycleStateForUITesting(UIView *editor) {
    return IDPrivateCopyFloatingLifecycleStateWithController(
        editor, IDPrivateTestingInternalTextLayoutController(editor));
}

NSDictionary<NSString *, id> *
IDPrivateCopyFloatingLifecycleStateForUITesting(UIView *editor) {
    return IDPrivateCopyStockFloatingLifecycleStateForUITesting(editor);
}

void IDPrivateTestingRequestResponderLoss(UIView *view) {
    if ([view isKindOfClass:UIScrollView.class]) {
        IDPrivateRecordFloatingLifecycleEventForUITesting(
            (UIScrollView *)view, @"resignAction");
    }
    [view resignFirstResponder];
}

void IDPrivateTestingRequestKeyboardDismissal(UIView *view) {
    if ([view isKindOfClass:UIScrollView.class]) {
        IDPrivateRecordFloatingLifecycleEventForUITesting(
            (UIScrollView *)view, @"keyboardDismissAction");
    }
    [view endEditing:YES];
}

static void IDPrivateTestingRequestBooleanOff(UIView *view,
                                               NSString *event,
                                               BOOL selectable) {
    NSString *countKey = [event stringByAppendingString:@"Count"];
    NSUInteger before = [IDPrivateCopyTextAutoscrollTraceForUITesting(
        (UIScrollView *)view)[countKey] unsignedIntegerValue];
    IDPrivateRecordFloatingLifecycleEventForUITesting((UIScrollView *)view,
        [event stringByAppendingString:@"Action"]);
    if (selectable) [(id)view setSelectable:NO];
    else [(id)view setEditable:NO];
    NSDictionary *afterTrace = IDPrivateCopyTextAutoscrollTraceForUITesting(
        (UIScrollView *)view);
    BOOL changedOff = selectable ? ![(id)view isSelectable] : ![(id)view isEditable];
    if (changedOff && [afterTrace[countKey] unsignedIntegerValue] == before) {
        IDPrivateRecordFloatingLifecycleEventForUITesting(
            (UIScrollView *)view, event);
    }
}

void IDPrivateTestingRequestEditableOff(UIView *view) {
    IDPrivateTestingRequestBooleanOff(view, @"editableOff", NO);
}

void IDPrivateTestingRequestSelectableOff(UIView *view) {
    IDPrivateTestingRequestBooleanOff(view, @"selectableOff", YES);
}

void IDPrivateTestingRequestWindowDetach(UIView *view) {
    if ([view isKindOfClass:UIScrollView.class]) {
        IDPrivateRecordFloatingLifecycleEventForUITesting(
            (UIScrollView *)view, @"windowDetachAction");
    }
    [view removeFromSuperview];
    if ([view isKindOfClass:UIScrollView.class]) {
        IDPrivateRecordFloatingLifecycleEventForUITesting(
            (UIScrollView *)view, @"windowDetach");
    }
}

NSArray<NSDictionary<NSString *, NSNumber *> *> *
IDPrivateCopyStockVisibleSelectionHandlesForUITesting(UIView *root) {
    NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *result = [NSMutableArray array];
    NSMutableArray<UIView *> *pending = [NSMutableArray arrayWithObject:root];
    while (pending.count > 0) {
        UIView *view = pending.lastObject;
        [pending removeLastObject];
        [pending addObjectsFromArray:view.subviews];
        if (![NSStringFromClass(view.class) containsString:TGPN__UITextSelectionLollipopView()] ||
            view.hidden || view.alpha <= 0.01) continue;
        CGRect rect = IDPrivateVisibleDescendantBoundsInView(view, root);
        if (CGRectIsNull(rect) || CGRectIsEmpty(rect)) continue;
        [result addObject:IDPrivateRectJSON(rect)];
    }
    return result.copy;
}



void IDPrivateInteractionBeginFloatingCursor(id assistant, CGPoint point) {
    ((void (*)(id, SEL, CGPoint))objc_msgSend)(
        assistant,
        NSSelectorFromString(@"beginFloatingCursorAtPoint:"),
        point);
}

void IDPrivateInteractionUpdateFloatingCursor(id assistant, CGPoint point, BOOL animated) {
    ((void (*)(id, SEL, CGPoint, BOOL))objc_msgSend)(
        assistant,
        NSSelectorFromString(@"updateFloatingCursorAtPoint:animated:"),
        point,
        animated);
}

void IDPrivateInteractionEndFloatingCursor(id assistant) {
    ((void (*)(id, SEL))objc_msgSend)(assistant, NSSelectorFromString(@"endFloatingCursor"));
}

void IDPrivateInteractionSelectWord(id assistant) {
    ((void (*)(id, SEL))objc_msgSend)(assistant, NSSelectorFromString(TGPN_selectWord()));
}

void IDPrivateInteractionSelectAll(id assistant, id sender) {
    ((void (*)(id, SEL, id))objc_msgSend)(
        assistant,
        NSSelectorFromString(@"selectAll:"),
        sender);
}

void IDPrivateInteractionAutoscrollWillNotStart(id assistant) {
    SEL selector = NSSelectorFromString(TGPN_autoscrollWillNotStart());
    if ([assistant respondsToSelector:selector]) {
        ((void (*)(id, SEL))objc_msgSend)(assistant, selector);
    }
}

id IDPrivateNewTextAutoscroll(void) {
    Class cls = NSClassFromString(TGPN_UIAutoscroll());
    if (cls == Nil) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:[TGPN_UIAutoscroll() stringByAppendingString:@" is unavailable"]
                                     userInfo:nil];
    }
    id autoscroll = [cls new];
    NSArray<IDInteractionABISpec *> *specs = @[
        IDInteractionABISpecMake(
            TGPN_startAutoscroll_scrollContainer_point_directions_repeatInterval_(),
            @encode(BOOL),
            @[IDInteractionTypeEncoding(@encode(id)),
              IDInteractionTypeEncoding(@encode(id)),
              IDInteractionTypeEncoding(@encode(CGPoint)),
              IDInteractionTypeEncoding(@encode(int)),
              IDInteractionTypeEncoding(@encode(double))]),
        IDInteractionABISpecMake(@"invalidate", @encode(void), @[]),
    ];
    NSArray<NSString *> *mismatches = IDInteractionABIMismatches(autoscroll, specs);
    if (mismatches.count != 0) {
        NSString *reason = [NSString stringWithFormat:
            @"%@ ABI mismatch:\n%@", TGPN_UIAutoscroll(),
            [mismatches componentsJoinedByString:@"\n"]];
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:reason
                                     userInfo:nil];
    }
    return autoscroll;
}

BOOL IDPrivateTextAutoscrollStart(id autoscroll,
                                  id target,
                                  UIScrollView *scrollContainer,
                                  CGPoint point,
                                  NSUInteger directions,
                                  NSTimeInterval repeatInterval) {
    return ((BOOL (*)(id, SEL, id, id, CGPoint, int, double))objc_msgSend)(
        autoscroll,
        NSSelectorFromString(
            TGPN_startAutoscroll_scrollContainer_point_directions_repeatInterval_()),
        target,
        scrollContainer,
        point,
        (int)directions,
        repeatInterval);
}

void IDPrivateTextAutoscrollInvalidate(id autoscroll) {
    if (autoscroll != nil) {
        ((void (*)(id, SEL))objc_msgSend)(autoscroll, NSSelectorFromString(@"invalidate"));
    }
}

static void IDPrivateTestingRequireUIKitAutoscrollGetter(
    id autoscroll,
    NSString *selectorName,
    const char *returnType) {
    SEL selector = NSSelectorFromString(selectorName);
    NSMethodSignature *signature =
        [autoscroll methodSignatureForSelector:selector];
    IDInteractionABISpec *spec =
        IDInteractionABISpecMake(selectorName, returnType, @[]);
    NSString *mismatch =
        IDInteractionABIMismatchForSignature(signature, spec);
    if (mismatch == nil) return;
    @throw [NSException
        exceptionWithName:NSInternalInconsistencyException
                   reason:[NSString stringWithFormat:
                       @"UIKit autoscroll oracle ABI mismatch: %@", mismatch]
                 userInfo:nil];
}

static id IDPrivateTestingUIKitAutoscrollTimer(id autoscroll) {
    for (Class cls = object_getClass(autoscroll);
         cls != Nil;
         cls = class_getSuperclass(cls)) {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList(cls, &count);
        for (unsigned int index = 0; index < count; index += 1) {
            const char *name = ivar_getName(ivars[index]);
            const char *type = ivar_getTypeEncoding(ivars[index]);
            if (name != NULL && strstr(name, "timer") != NULL &&
                type != NULL && type[0] == '@') {
                id timer = object_getIvar(autoscroll, ivars[index]);
                free(ivars);
                return timer;
            }
        }
        free(ivars);
    }
    return nil;
}

id IDPrivateTestingNewUIKitAutoscroll(void) {
    return IDPrivateNewTextAutoscroll();
}

BOOL IDPrivateTestingStartUIKitAutoscroll(
    id autoscroll,
    id target,
    UIScrollView *scrollContainer,
    CGPoint point,
    NSUInteger directions,
    NSTimeInterval repeatInterval) {
    return IDPrivateTextAutoscrollStart(
        autoscroll, target, scrollContainer, point, directions, repeatInterval);
}

NSDictionary<NSString *, id> *
IDPrivateTestingCopyUIKitAutoscrollSnapshot(id autoscroll) {
    NSCParameterAssert(autoscroll != nil);
    IDPrivateTestingRequireUIKitAutoscrollGetter(
        autoscroll, @"target", @encode(id));
    IDPrivateTestingRequireUIKitAutoscrollGetter(
        autoscroll, TGPN_scrollContainer(), @encode(id));
    IDPrivateTestingRequireUIKitAutoscrollGetter(
        autoscroll, @"point", @encode(CGPoint));
    IDPrivateTestingRequireUIKitAutoscrollGetter(
        autoscroll, @"directions", @encode(int));
    IDPrivateTestingRequireUIKitAutoscrollGetter(
        autoscroll, @"repeatInterval", @encode(NSTimeInterval));
    IDPrivateTestingRequireUIKitAutoscrollGetter(
        autoscroll, @"count", @encode(NSUInteger));
    IDPrivateTestingRequireUIKitAutoscrollGetter(
        autoscroll, @"active", @encode(BOOL));
    IDPrivateTestingRequireUIKitAutoscrollGetter(
        autoscroll, @"disabled", @encode(BOOL));

    id target = ((id (*)(id, SEL))objc_msgSend)(
        autoscroll, NSSelectorFromString(@"target"));
    id scrollContainer = ((id (*)(id, SEL))objc_msgSend)(
        autoscroll, NSSelectorFromString(TGPN_scrollContainer()));
    CGPoint point = ((CGPoint (*)(id, SEL))objc_msgSend)(
        autoscroll, NSSelectorFromString(@"point"));
    int directions = ((int (*)(id, SEL))objc_msgSend)(
        autoscroll, NSSelectorFromString(@"directions"));
    NSTimeInterval repeatInterval =
        ((NSTimeInterval (*)(id, SEL))objc_msgSend)(
            autoscroll, NSSelectorFromString(@"repeatInterval"));
    NSUInteger count = ((NSUInteger (*)(id, SEL))objc_msgSend)(
        autoscroll, NSSelectorFromString(@"count"));
    BOOL active = ((BOOL (*)(id, SEL))objc_msgSend)(
        autoscroll, NSSelectorFromString(@"active"));
    BOOL disabled = ((BOOL (*)(id, SEL))objc_msgSend)(
        autoscroll, NSSelectorFromString(@"disabled"));
    id timer = IDPrivateTestingUIKitAutoscrollTimer(autoscroll);
    NSDate *timerFireDate =
        [timer isKindOfClass:NSTimer.class] ? [(NSTimer *)timer fireDate] : nil;

    return @{
        @"active": @(active),
        @"disabled": @(disabled),
        @"targetPresent": @((BOOL)(target != nil)),
        @"containerPresent": @((BOOL)(scrollContainer != nil)),
        @"point": [NSValue valueWithCGPoint:point],
        @"directions": @((NSUInteger)(unsigned int)directions),
        @"repeatInterval": @(repeatInterval),
        @"count": @(count),
        @"timerIdentity":
            @((unsigned long long)(uintptr_t)(__bridge void *)timer),
        @"timerFireDate":
            @(timerFireDate == nil
                ? 0.0
                : timerFireDate.timeIntervalSinceReferenceDate),
    };
}

void IDPrivateTestingSetUIKitAutoscrollDisabled(
    id autoscroll,
    BOOL disabled) {
    NSString *selectorName = @"setDisabled:";
    SEL selector = NSSelectorFromString(selectorName);
    IDInteractionABISpec *spec = IDInteractionABISpecMake(
        selectorName,
        @encode(void),
        @[IDInteractionTypeEncoding(@encode(BOOL))]);
    NSString *mismatch = IDInteractionABIMismatchForSignature(
        [autoscroll methodSignatureForSelector:selector],
        spec);
    if (mismatch != nil) {
        @throw [NSException
            exceptionWithName:NSInternalInconsistencyException
                       reason:[NSString stringWithFormat:
                           @"UIKit autoscroll oracle ABI mismatch: %@", mismatch]
                     userInfo:nil];
    }
    ((void (*)(id, SEL, BOOL))objc_msgSend)(
        autoscroll, selector, disabled);
}

void IDPrivateTestingFireUIKitAutoscroll(id autoscroll) {
    NSString *selectorName = @"timerFired:";
    SEL selector = NSSelectorFromString(selectorName);
    IDInteractionABISpec *spec = IDInteractionABISpecMake(
        selectorName,
        @encode(void),
        @[IDInteractionTypeEncoding(@encode(id))]);
    NSString *mismatch = IDInteractionABIMismatchForSignature(
        [autoscroll methodSignatureForSelector:selector],
        spec);
    if (mismatch != nil) {
        @throw [NSException
            exceptionWithName:NSInternalInconsistencyException
                       reason:[NSString stringWithFormat:
                           @"UIKit autoscroll oracle ABI mismatch: %@", mismatch]
                     userInfo:nil];
    }
    ((void (*)(id, SEL, id))objc_msgSend)(
        autoscroll, selector, nil);
}

void IDPrivateTestingInvalidateUIKitAutoscroll(id autoscroll) {
    IDPrivateTextAutoscrollInvalidate(autoscroll);
}

void IDPrivateKeyboardInputChangedSelection(id delegate, id input) {
    SEL selector = NSSelectorFromString(TGPN_keyboardInputChangedSelection_());
    if ([delegate respondsToSelector:selector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(delegate, selector, input);
    }
}

NSUndoManager *IDPrivateInputUndoManager(id controller) {
    return ((id (*)(id, SEL))objc_msgSend)(
        controller,
        NSSelectorFromString(@"undoManager"));
}

void IDPrivateInputCut(id controller, id sender) {
    ((void (*)(id, SEL, id))objc_msgSend)(controller, NSSelectorFromString(@"cut:"), sender);
}

void IDPrivateInputCopy(id controller, id sender) {
    ((void (*)(id, SEL, id))objc_msgSend)(controller, NSSelectorFromString(@"copy:"), sender);
}

void IDPrivateInputPaste(id controller, id sender) {
    ((void (*)(id, SEL, id))objc_msgSend)(controller, NSSelectorFromString(@"paste:"), sender);
}

void IDPrivateInputDetachFromLayoutManager(id controller) {
    ((void (*)(id, SEL))objc_msgSend)(
        controller,
        NSSelectorFromString(TGPN__detachFromLayoutManager()));
}

BOOL IDPrivateInputShouldHandlePaste(id controller, id sender) {
    SEL action = @selector(paste:);
    BOOL canHandle = ((BOOL (*)(id, SEL, SEL))objc_msgSend)(
        controller,
        NSSelectorFromString(TGPN__canHandleResponderAction_()),
        action);
    if (!canHandle) {
        return NO;
    }
    return ((BOOL (*)(id, SEL, SEL, id))objc_msgSend)(
        controller,
        NSSelectorFromString(TGPN__shouldHandleResponderAction_withSender_()),
        action,
        sender);
}

UITextStorageDirection IDPrivateInputSelectionAffinity(id controller) {
    return ((UITextStorageDirection (*)(id, SEL))objc_msgSend)(
        controller,
        NSSelectorFromString(@"selectionAffinity"));
}

NSDictionary<NSAttributedStringKey, id> *
IDPrivateInputTypingAttributes(id controller) {
    SEL selector = NSSelectorFromString(@"typingAttributes");
    IDPrivateRequireSignature(controller, selector, @encode(id), 2, NULL);
    return ((id (*)(id, SEL))objc_msgSend)(controller, selector);
}

void IDPrivateInputSetTypingAttributes(
    id controller,
    NSDictionary<NSAttributedStringKey, id> *attributes) {
    SEL selector = NSSelectorFromString(@"setTypingAttributes:");
    IDPrivateRequireSignature(controller, selector, @encode(void), 3,
                              @encode(id));
    ((void (*)(id, SEL, id))objc_msgSend)(controller, selector, attributes);
}

void IDPrivateInputAllowTypingAttributeNames(
    id controller,
    NSSet<NSAttributedStringKey> *attributeNames) {
    SEL getSelector = NSSelectorFromString(TGPN__allowedTypingAttributes());
    SEL setSelector = NSSelectorFromString(TGPN__setAllowedTypingAttributes_());
    IDPrivateRequireSignature(controller, getSelector, @encode(id), 2, NULL);
    IDPrivateRequireSignature(controller, setSelector, @encode(void), 3,
                              @encode(id));
    NSSet<NSAttributedStringKey> *current =
        ((id (*)(id, SEL))objc_msgSend)(controller, getSelector);
    NSMutableSet<NSAttributedStringKey> *allowed =
        current.mutableCopy ?: [NSMutableSet set];
    [allowed unionSet:attributeNames];
    ((void (*)(id, SEL, id))objc_msgSend)(controller, setSelector,
                                          allowed.copy);
}

void IDPrivateInputInvalidateTypingAttributes(id controller) {
    SEL selector = NSSelectorFromString(TGPN__invalidateTypingAttributes());
    IDPrivateRequireSignature(controller, selector, @encode(void), 2, NULL);
    ((void (*)(id, SEL))objc_msgSend)(controller, selector);
}

void IDPrivateInputPerformWhileSuppressingDelegateNotifications(
    id controller, void (NS_NOESCAPE ^body)(void)) {
    SEL selector = NSSelectorFromString(TGPN__performWhileSuppressingDelegateNotifications_());
    [IDPrivateUIKit requireObject:controller
              respondsToSelector:selector
                           stage:@"Suppressed input-delegate notification transaction"];
    IDPrivateRequireSignature(controller, selector, @encode(void), 3,
                              @encode(void (^)(void)));
    ((void (*)(id, SEL, void (^)(void)))objc_msgSend)(controller, selector, body);
}

static id IDPrivateValidatedBackwardDeleteRanges(id controller, NSString *stage) {
    id ranges = ((id (*)(id, SEL))objc_msgSend)(
        controller,
        NSSelectorFromString(TGPN__rangesForBackwardsDelete()));
    [IDPrivateUIKit requireObject:ranges
              respondsToSelector:NSSelectorFromString(TGPN_unionRange())
                           stage:stage];
    return ranges;
}

void IDPrivateInputPreflightBackwardDeleteRanges(id controller) {
    (void)IDPrivateValidatedBackwardDeleteRanges(
        controller,
        @"Backward-delete ranges construction preflight");
}

NSRange IDPrivateInputBackwardDeleteRange(id controller) {
    id ranges = IDPrivateValidatedBackwardDeleteRanges(
        controller,
        @"Backward-delete ranges action aggregate");
    return ((NSRange (*)(id, SEL))objc_msgSend)(
        ranges,
        NSSelectorFromString(TGPN_unionRange()));
}

BOOL IDPrivateTextViewShouldDelete(id textView, id input) {
    return ((BOOL (*)(id, SEL, id))objc_msgSend)(
        textView,
        NSSelectorFromString(TGPN_keyboardInputShouldDelete_()),
        input);
}

NSUInteger IDPrivateTextKit2RangeCount(id range) {
    [IDPrivateUIKit requireObject:range
              respondsToSelector:NSSelectorFromString(TGPN_textKit2Ranges())
                           stage:@"TextKit 2 range adapter"];
    NSArray *ranges = ((id (*)(id, SEL))objc_msgSend)(
        range,
        NSSelectorFromString(TGPN_textKit2Ranges()));
    return ranges.count;
}

NSArray *IDPrivateLayoutSelectionRects(id layoutController, id range, UIView *fromView) {
    BOOL (^allContainers)(id) = ^BOOL(id container) { return YES; };
    return ((id (*)(id, SEL, id, id, id))objc_msgSend)(
        layoutController,
        NSSelectorFromString(TGPN_selectionRectsForRange_fromView_forContainerPassingTest_()),
        range,
        fromView,
        allContainers);
}

void IDPrivateTextContainerSetTextView(NSTextContainer *textContainer,
                                       UIView * _Nullable textView) {
    ((void (*)(id, SEL, id))objc_msgSend)(
        textContainer,
        NSSelectorFromString(@"setTextView:"),
        textView);
}

UIView *IDPrivateTextContainerTextView(NSTextContainer *textContainer) {
    return ((id (*)(id, SEL))objc_msgSend)(
        textContainer,
        NSSelectorFromString(@"textView"));
}

void IDPrivateRequireTextContainerHost(id host, NSString *stage) {
    NSArray<IDInteractionABISpec *> *specs = @[
        IDInteractionABISpecMake(@"textContainer", @encode(id), @[]),
        IDInteractionABISpecMake(@"setTextContainer:", @encode(void),
            @[IDInteractionTypeEncoding(@encode(id))]),
        IDInteractionABISpecMake(TGPN_textContainerOrigin(), @encode(CGPoint), @[]),
    ];
    NSArray<NSString *> *mismatches = IDInteractionABIMismatches(host, specs);
    if (mismatches.count == 0) return;
    NSString *reason = [NSString stringWithFormat:
        @"%@ failed: text-container host ABI mismatch:\n%@",
        stage,
        [mismatches componentsJoinedByString:@"\n"]];
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:reason
                                 userInfo:nil];
}

BOOL IDPrivateRespondsToSelector(id target, SEL selector) {
    return [target respondsToSelector:selector];
}

id IDPrivateObject0(id target, SEL selector) {
    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

id IDPrivateObject1(id target, SEL selector, id value) {
    return ((id (*)(id, SEL, id))objc_msgSend)(target, selector, value);
}

id IDPrivateObject2(id target, SEL selector, id first, id second) {
    return ((id (*)(id, SEL, id, id))objc_msgSend)(target, selector, first, second);
}

id IDPrivateObjectObjectInteger(id target, SEL selector, id value, NSInteger integer) {
    return ((id (*)(id, SEL, id, NSInteger))objc_msgSend)(target, selector, value, integer);
}

id IDPrivateObjectObjectIntegerInteger(id target,
                                       SEL selector,
                                       id value,
                                       NSInteger firstInteger,
                                       NSInteger secondInteger) {
    return ((id (*)(id, SEL, id, NSInteger, NSInteger))objc_msgSend)(
        target,
        selector,
        value,
        firstInteger,
        secondInteger);
}

id IDPrivateObjectPoint(id target, SEL selector, CGPoint point) {
    return ((id (*)(id, SEL, CGPoint))objc_msgSend)(target, selector, point);
}

id IDPrivateObjectPointObject(id target, SEL selector, CGPoint point, id value) {
    return ((id (*)(id, SEL, CGPoint, id))objc_msgSend)(target, selector, point, value);
}

NSInteger IDPrivateInteger2(id target, SEL selector, id first, id second) {
    return ((NSInteger (*)(id, SEL, id, id))objc_msgSend)(target, selector, first, second);
}

NSInteger IDPrivateIntegerObjectInteger(id target, SEL selector, id value, NSInteger integer) {
    return ((NSInteger (*)(id, SEL, id, NSInteger))objc_msgSend)(target, selector, value, integer);
}

CGRect IDPrivateRectObject(id target, SEL selector, id value) {
    return ((CGRect (*)(id, SEL, id))objc_msgSend)(target, selector, value);
}

void IDPrivateVoid0(id target, SEL selector) {
    ((void (*)(id, SEL))objc_msgSend)(target, selector);
}

void IDPrivateVoid1(id target, SEL selector, id value) {
    ((void (*)(id, SEL, id))objc_msgSend)(target, selector, value);
}

void IDPrivateVoid2(id target, SEL selector, id first, id second) {
    ((void (*)(id, SEL, id, id))objc_msgSend)(target, selector, first, second);
}

void IDPrivateVoidObjectRange(id target, SEL selector, id value, NSRange range) {
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    BOOL valid = signature != nil &&
        signature.numberOfArguments == 4 &&
        strcmp(signature.methodReturnType, @encode(void)) == 0 &&
        IDInteractionTypeMatches(
            [signature getArgumentTypeAtIndex:2], @encode(id)) &&
        IDPrivateTypeEncodingsMatch(
            [signature getArgumentTypeAtIndex:3], @encode(NSRange));
    if (!valid) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
            reason:[NSString stringWithFormat:
                @"Private operation ABI is unavailable for %@",
                NSStringFromSelector(selector)]
          userInfo:nil];
    }
    ((void (*)(id, SEL, id, NSRange))objc_msgSend)(target, selector, value, range);
}

void IDPrivateVoidIntegerObject(id target, SEL selector, NSInteger integer, id value) {
    ((void (*)(id, SEL, NSInteger, id))objc_msgSend)(target, selector, integer, value);
}

#endif
