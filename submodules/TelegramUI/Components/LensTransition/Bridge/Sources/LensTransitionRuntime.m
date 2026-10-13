#import "LensTransitionRuntime/LensTransitionRuntime.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "Identifiers.inc"

// Volatile encoded bytes prevent optimized builds from folding decoded names
// into string/selector sections. These are runtime identifiers, never Swift ABI.
__attribute__((noinline)) static NSString *LTName(LTKey key) {
    char bytes[64];
    for (NSUInteger i = 0; i < sizeof(bytes); i++) {
        bytes[i] = LTNames[key][i] ^ 0xa7;
        if (bytes[i] == 0) break;
    }
    return [NSString stringWithUTF8String:bytes];
}
static SEL LTSelector(LTKey key) { return NSSelectorFromString(LTName(key)); }

@interface LTTransitionState : NSObject {
@public
    UITargetedPreview *origin;
    UITargetedPreview *destination;
    UITargetedPreview *pivot;
    UIView *host;
    UIView *detached;
    UIView *menu;
    void (^animations)(void);
    void (^completion)(void);
}
@end
@implementation LTTransitionState @end
static char LTStateKey;
static LTTransitionState *LTState(id object) { return objc_getAssociatedObject(object, &LTStateKey); }
static void LTAttach(id object, LTTransitionState *state) { objc_setAssociatedObject(object, &LTStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static id LTOrigin(id o, SEL s) { return LTState(o)->origin; }
static id LTGetPivot(id o, SEL s) { return LTState(o)->pivot; }
static id LTGetDestination(id o, SEL s) { return LTState(o)->destination; }
static id LTGetHost(id o, SEL s) { return LTState(o)->host; }
static id LTGetDetached(id o, SEL s) { return LTState(o)->detached; }
static id LTGetMenu(id o, SEL s) { return LTState(o)->menu; }
static id LTNil(id o, SEL s) { return nil; }
static id LTEmpty(id o, SEL s) { return @[]; }
static BOOL LTYes(id o, SEL s) { return YES; }
static BOOL LTNo(id o, SEL s) { return NO; }
static void LTIgnore(id o, SEL s) {}
static void LTGetBackground(id o, SEL s, BOOL visible) {}
static void LTFinish(id o, SEL s) {
    LTTransitionState *state = LTState(o);
    void (^block)(void) = state->completion;
    state->completion = nil;
    state->animations = nil;
    if (block) block();
}
static void LTAnimate(id o, SEL s) { void (^block)(void) = LTState(o)->animations; if (block) block(); }

// Compare complete ABI signatures, ignoring only numeric argument offsets.
static BOOL LTMatches(Class cls, LTKey key, const char *types) {
    Method method = class_getInstanceMethod(cls, LTSelector(key));
    if (!method) return NO;
    NSMethodSignature *actual = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    NSMethodSignature *expected = [NSMethodSignature signatureWithObjCTypes:types];
    if (strcmp(actual.methodReturnType, expected.methodReturnType) || actual.numberOfArguments != expected.numberOfArguments) return NO;
    for (NSUInteger i = 0; i < actual.numberOfArguments; i++) {
        if (strcmp([actual getArgumentTypeAtIndex:i], [expected getArgumentTypeAtIndex:i])) return NO;
    }
    return YES;
}
static Class LTCoordinatorClass, LTControllerClass, LTMenuClass, LTAlongsideClass;
static BOOL LTAdd(Class cls, LTKey key, IMP imp, const char *types) { return class_addMethod(cls, LTSelector(key), imp, types); }
static BOOL LTPrepare(void) {
    static dispatch_once_t once;
    static BOOL supported;
    dispatch_once(&once, ^{
        Class base = NSClassFromString(LTName(LTCoordinator));
        struct { LTKey key; const char *types; IMP imp; } overrides[] = {
            {LTFrom, "@@:", (IMP)LTOrigin}, {LTAttachment, "@@:", (IMP)LTOrigin},
            {LTPivot, "@@:", (IMP)LTGetPivot}, {LTUsesDestination, "B@:", (IMP)LTYes},
            {LTContent, "@@:", (IMP)LTNil}, {LTAccessories, "@@:", (IMP)LTEmpty},
            {LTDragging, "B@:", (IMP)LTNo}, {LTBackground, "v@:B", (IMP)LTGetBackground}
        };
        if (!base || !LTMatches(base, LTInitialize, "@@:@@") || !LTMatches(base, LTStart, "v@:") ||
            !LTMatches(base, LTAlongside, "v@:@") ||
            !LTMatches(UIView.class, LTVisibility, "@@:d")) return;
        for (NSUInteger i = 0; i < sizeof(overrides) / sizeof(overrides[0]); i++) {
            if (!LTMatches(base, overrides[i].key, overrides[i].types)) return;
        }
        Class coordinator = objc_allocateClassPair(base, "LTNativeTransition", 0);
        Class controller = objc_allocateClassPair(NSObject.class, "LTTransitionContext", 0);
        Class menu = objc_allocateClassPair(UIView.class, "LTTransitionDestination", 0);
        Class alongside = objc_allocateClassPair(NSObject.class, "LTTransitionActions", 0);
        BOOL valid = coordinator && controller && menu && alongside;
        if (valid) {
            for (NSUInteger i = 0; i < sizeof(overrides) / sizeof(overrides[0]); i++) {
                valid &= LTAdd(coordinator, overrides[i].key, overrides[i].imp, overrides[i].types);
            }
            valid &= LTAdd(controller, LTLayout, (IMP)LTNil, "@@:");
            valid &= LTAdd(controller, LTFlock, (IMP)LTNil, "@@:");
            valid &= LTAdd(controller, LTMenu, (IMP)LTGetMenu, "@@:");
            valid &= LTAdd(controller, LTHost, (IMP)LTGetHost, "@@:");
            valid &= LTAdd(controller, LTDetached, (IMP)LTGetDetached, "@@:");
            valid &= LTAdd(controller, LTEndHiding, (IMP)LTIgnore, "v@:");
            valid &= LTAdd(menu, LTDestination, (IMP)LTGetDestination, "@@:");
            valid &= LTAdd(alongside, LTRunAnimations, (IMP)LTAnimate, "v@:");
            valid &= LTAdd(alongside, LTRunCompletions, (IMP)LTFinish, "v@:");
        }
        if (!valid) {
            if (coordinator) objc_disposeClassPair(coordinator);
            if (controller) objc_disposeClassPair(controller);
            if (menu) objc_disposeClassPair(menu);
            if (alongside) objc_disposeClassPair(alongside);
            return;
        }
        objc_registerClassPair(coordinator); objc_registerClassPair(controller);
        objc_registerClassPair(menu); objc_registerClassPair(alongside);
        LTCoordinatorClass = coordinator; LTControllerClass = controller;
        LTMenuClass = menu; LTAlongsideClass = alongside;
        supported = YES;
    });
    return supported;
}

static NSMapTable<UIView *, LTTransitionDriver *> *LTActiveTransitions;

@implementation LTTransitionDriver {
    id _native;
    id _context;
    id _actions;
    BOOL _started;
}
+ (BOOL)isSupported { return LTPrepare(); }
+ (id)visibilityAssertionForView:(UIView *)view {
    SEL selector = LTSelector(LTVisibility);
    if (!LTMatches(view.class, LTVisibility, "@@:d")) return nil;
    return ((id (*)(id, SEL, CGFloat))objc_msgSend)(view, selector, 0);
}
- (instancetype)initWithSource:(UITargetedPreview *)source destination:(UITargetedPreview *)destination pivot:(UITargetedPreview *)pivot container:(UIView *)container sourceIdentity:(UIView *)sourceIdentity alongside:(void (^)(void))alongside {
    NSAssert(NSThread.isMainThread, @"Transition must be created on the main thread");
    if (!LTPrepare()) return nil;
    self = [super init];
    if (self) {
        LTTransitionState *state = [LTTransitionState new];
        state->origin = source; state->destination = destination; state->pivot = pivot;
        state->host = container;
        // Distinct from the source target's container: selects UIKit's pivot path.
        state->detached = [UIView new];
        state->menu = [LTMenuClass new];
        // Separate state avoids a state -> menu -> state retention cycle.
        LTTransitionState *menuState = [LTTransitionState new];
        menuState->destination = destination;
        LTAttach(state->menu, menuState);
        state->animations = [alongside copy];
        _context = [LTControllerClass new]; LTAttach(_context, state);
        _actions = [LTAlongsideClass new]; LTAttach(_actions, state);
        // Explicit init-family ownership across the dynamically resolved call.
        typedef id (*Initialize)(id __attribute__((ns_consumed)), SEL, id, id) __attribute__((ns_returns_retained));
        if (!LTActiveTransitions) LTActiveTransitions = [NSMapTable weakToWeakObjectsMapTable];
        LTTransitionDriver *previous = [LTActiveTransitions objectForKey:sourceIdentity ?: source.view];
        id previousNative = previous && previous->_started && LTState(previous->_actions)->completion ? previous->_native : nil;
        _native = ((Initialize)objc_msgSend)([LTCoordinatorClass alloc], LTSelector(LTInitialize), _context, previousNative);
        if (!_native) return nil;
        // UIKit transfers the active morph, including its source-side portals.
        // Independent coordinators leave the older return visible behind a reopen.
        // A profile's return snapshot and live button share this logical identity.
        [LTActiveTransitions setObject:self forKey:sourceIdentity ?: source.view];
        if (!sourceIdentity) [LTActiveTransitions setObject:self forKey:destination.view];
        LTAttach(_native, state);
        ((void (*)(id, SEL, id))objc_msgSend)(_native, LTSelector(LTAlongside), _actions);
    }
    return self;
}
- (void)startWithCompletion:(void (^)(void))completion {
    NSAssert(NSThread.isMainThread && !_started, @"Transition must start once on the main thread");
    _started = YES;
    // Always use presentation semantics. Closing reverses previews; UIKit's
    // dismissal mode would remove the caller's host from its hierarchy.
    // Install before starting: disabled animations can finish synchronously.
    LTState(_actions)->completion = [completion copy];
    ((void (*)(id, SEL))objc_msgSend)(_native, LTSelector(LTStart));
}
@end
