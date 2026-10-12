#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGPrivateMethodAliases.h"

#import "TGPrivateRuntimeNames.h"
#import "IDUIKitInteractionCapability.h"

#import <objc/message.h>

#import "TGRichTextInputDecHostPreflight.h"
#import "TGRichTextInputDecContract.h"

NSErrorDomain const IDUIKitInteractionCapabilityErrorDomain =
    @"IDUIKitInteractionCapabilityErrorDomain";

typedef NS_ENUM(NSInteger, IDUIKitInteractionCapabilityError) {
    IDUIKitInteractionCapabilityErrorInvalidHost = 1,
    IDUIKitInteractionCapabilityErrorMissingAssistantClass,
    IDUIKitInteractionCapabilityErrorInitializationFailed,
};

typedef id (*IDUIKitInteractionInitializerSend)(
    id __attribute__((ns_consumed)),
    SEL,
    id) __attribute__((ns_returns_retained));

@interface IDUIKitInteractionCapability ()
@property(nonatomic, strong, readwrite, nullable) id privateAssistant;
@property(nonatomic, strong, readwrite)
    IDUIKitCapabilityReport *report;
@property(nonatomic, strong, readwrite)
    IDUIKitCapabilityReport *floatingCursorReport;
@property(nonatomic, getter=isDetached) BOOL detached;
@property(nonatomic) BOOL floatingCursorAvailable;
@end

static NSError *IDUIKitInteractionError(
    IDUIKitInteractionCapabilityError code,
    NSString *description,
    NSException *exception) {
    NSMutableDictionary<NSString *, id> *userInfo =
        [NSMutableDictionary dictionaryWithObject:description
                                          forKey:NSLocalizedDescriptionKey];
    if (exception != nil) {
        userInfo[@"IDUIKitInteractionUnderlyingException"] = exception;
    }
    return [NSError
        errorWithDomain:IDUIKitInteractionCapabilityErrorDomain
                   code:code
               userInfo:userInfo.copy];
}

static NSArray<NSString *> *IDUIKitInteractionRequiredMembers(
    IDUIKitRuntimeCapabilityContract *contract) {
    NSMutableArray<NSString *> *identifiers =
        [NSMutableArray array];
    for (IDUIKitRuntimeMemberContract *member in contract.members) {
        if (member.isRequired) {
            [identifiers addObject:member.identifier];
        }
    }
    return [identifiers
        sortedArrayUsingSelector:@selector(compare:)];
}

static IDUIKitCapabilityReport *IDUIKitInteractionReport(
    IDUIKitRuntimeCapabilityContract *contract,
    IDUIKitContractResult *result) {
    return [[IDUIKitCapabilityReport alloc]
        initWithIdentifier:contract.identifier
                     state:result.state
           requiredMembers:
               IDUIKitInteractionRequiredMembers(contract)
              observedABIs:result.observedABIs
              dependencies:contract.dependencies
                  fallback:contract.fallback
           rejectionReason:result.mismatches.count == 0
               ? nil
               : [result.mismatches componentsJoinedByString:@"\n"]];
}

static IDUIKitCapabilityReport *IDUIKitInteractionDependencyReport(
    IDUIKitRuntimeCapabilityContract *contract,
    NSString *dependency) {
    return [[IDUIKitCapabilityReport alloc]
        initWithIdentifier:contract.identifier
                     state:IDUIKitCapabilityStateUnavailable
           requiredMembers:
               IDUIKitInteractionRequiredMembers(contract)
              observedABIs:@{}
              dependencies:contract.dependencies
                  fallback:contract.fallback
           rejectionReason:[NSString stringWithFormat:
               @"Dependency %@ is not active.", dependency]];
}

static IDUIKitCapabilityReport *IDUIKitInteractionUnavailableReport(
    IDUIKitRuntimeCapabilityContract *contract,
    IDUIKitContractResult *result,
    NSString *reason) {
    return [[IDUIKitCapabilityReport alloc]
        initWithIdentifier:contract.identifier
                     state:IDUIKitCapabilityStateUnavailable
           requiredMembers:
               IDUIKitInteractionRequiredMembers(contract)
              observedABIs:result.observedABIs
              dependencies:contract.dependencies
                  fallback:contract.fallback
           rejectionReason:reason];
}

static IDUIKitRuntimeManifest *IDUIKitInteractionManifest(void) {
    return TGRichTextInputDecContractManifest();
}

IDUIKitRuntimeCapabilityContract *
IDUIKitInteractionRuntimeContract(void) {
    IDUIKitRuntimeCapabilityContract *contract =
        IDUIKitInteractionManifest().capabilities[@"interaction"];
    if (contract == nil) {
        @throw [NSException
            exceptionWithName:NSInternalInconsistencyException
                       reason:@"The interaction runtime contract is unavailable."
                     userInfo:nil];
    }
    return contract;
}

static IDUIKitRuntimeCapabilityContract *
IDUIKitFloatingCursorRuntimeContract(void) {
    IDUIKitRuntimeCapabilityContract *contract =
        IDUIKitInteractionManifest().capabilities[@"floatingCursor"];
    if (contract == nil) {
        @throw [NSException
            exceptionWithName:NSInternalInconsistencyException
                       reason:@"The floating-cursor runtime contract is unavailable."
                     userInfo:nil];
    }
    return contract;
}

@implementation IDUIKitInteractionCapability

// Renamed members keep their previous selectors at run time (`TGPrivateMethodAliases.h`): the names are
// UIKit's private ones, which must not be compiled into the binary, and this object may be reached by
// them, as the layout controller's connection is.
+ (void)initialize {
    if (self != IDUIKitInteractionCapability.class) {
        return;
    }
    const TGPrivateMethodAlias aliases[] = {
        { TGPN_selectionChanged, @selector(id_selectionChanged) },
        { TGPN_setNeedsSelectionDisplayUpdate, @selector(id_setNeedsSelectionDisplayUpdate) },
        { TGPN_resignedFirstResponder, @selector(id_resignedFirstResponder) },
        { TGPN_selectWord, @selector(id_selectWord) },
        { TGPN_autoscrollWillNotStart, @selector(id_autoscrollWillNotStart) },
    };
    TGPrivateInstallMethodAliases(self, aliases, sizeof(aliases) / sizeof(aliases[0]));
}


- (instancetype)initWithContract:
    (IDUIKitRuntimeCapabilityContract *)contract
                         resolver:(IDUIKitCapabilityResolver *)resolver
                             view:(UIView *)view
                            error:(NSError **)error {
    NSParameterAssert(contract != nil);
    NSParameterAssert(resolver != nil);
    NSParameterAssert(view != nil);

    IDUIKitContractResult *interactionResult =
        [resolver evaluateContract:contract];
    IDUIKitCapabilityReport *interactionReport =
        IDUIKitInteractionReport(contract, interactionResult);
    IDUIKitRuntimeCapabilityContract *floatingContract =
        IDUIKitFloatingCursorRuntimeContract();
    if (!interactionResult.isAccepted) {
        self = [super init];
        if (self != nil) {
            _report = interactionReport;
            _floatingCursorReport =
                IDUIKitInteractionDependencyReport(
                    floatingContract, contract.identifier);
        }
        return self;
    }

    IDUIKitContractResult *floatingResult =
        [resolver evaluateContract:floatingContract];
    IDUIKitCapabilityReport *floatingReport =
        IDUIKitInteractionReport(
            floatingContract, floatingResult);

    @try {
        [TGRichTextInputDecHostPreflight
            requireInteractionHost:view
                             stage:@"Interaction capability host preflight"];
    } @catch (NSException *exception) {
        if (error != NULL) {
            *error = IDUIKitInteractionError(
                IDUIKitInteractionCapabilityErrorInvalidHost,
                exception.reason ?: @"The interaction host ABI was rejected.",
                exception);
        }
        self = [super init];
        if (self != nil) {
            _report = IDUIKitInteractionUnavailableReport(
                contract, interactionResult,
                exception.reason ?: @"The interaction host ABI was rejected.");
            _floatingCursorReport =
                IDUIKitInteractionDependencyReport(
                    floatingContract, contract.identifier);
        }
        return self;
    }

    IDUIKitRuntimeMemberContract *classMember = nil;
    for (IDUIKitRuntimeMemberContract *member in contract.members) {
        if ([member.name isEqualToString:@"class"]) {
            classMember = member;
            break;
        }
    }
    Class assistantClass = classMember == nil
        ? Nil
        : [resolver classNamed:classMember.className];
    if (assistantClass == Nil) {
        if (error != NULL) {
            *error = IDUIKitInteractionError(
                IDUIKitInteractionCapabilityErrorMissingAssistantClass,
                @"The validated interaction-assistant class is unavailable.",
                nil);
        }
        self = [super init];
        if (self != nil) {
            _report = IDUIKitInteractionUnavailableReport(
                contract, interactionResult,
                @"The validated interaction-assistant class is unavailable.");
            _floatingCursorReport =
                IDUIKitInteractionDependencyReport(
                    floatingContract, contract.identifier);
        }
        return self;
    }

    id allocatedAssistant = [assistantClass alloc];
    __strong id cleanupTarget = allocatedAssistant;
    id assistant = nil;
    BOOL initializerCompleted = NO;
    @try {
        assistant = ((IDUIKitInteractionInitializerSend)objc_msgSend)(
            allocatedAssistant,
            NSSelectorFromString(@"initWithView:"),
            view);
        initializerCompleted = YES;
        if (assistant == nil) {
            @throw [NSException
                exceptionWithName:NSInternalInconsistencyException
                           reason:@"The interaction assistant returned nil from initialization."
                         userInfo:nil];
        }
    } @catch (NSException *exception) {
        NSException *cleanupException = nil;
        @try {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(
                cleanupTarget,
                NSSelectorFromString(TGPN_clearGestureRecognizers_()),
                YES);
        } @catch (NSException *caught) {
            cleanupException = caught;
        }
        if (!initializerCompleted && cleanupTarget != nil) {
            CFRelease((__bridge CFTypeRef)cleanupTarget);
        }
        assistant = nil;
        allocatedAssistant = nil;
        cleanupTarget = nil;
        if (error != NULL) {
            NSString *description = cleanupException == nil
                ? exception.reason
                : [NSString stringWithFormat:
                    @"%@; recognizer cleanup failed: %@",
                    exception.reason ?: @"Interaction construction failed.",
                    cleanupException.reason ?: @"<no reason>"];
            *error = IDUIKitInteractionError(
                IDUIKitInteractionCapabilityErrorInitializationFailed,
                description ?: @"Interaction construction failed.",
                exception);
        }
        self = [super init];
        if (self != nil) {
            _report = IDUIKitInteractionUnavailableReport(
                contract, interactionResult,
                exception.reason ?: @"Interaction construction failed.");
            _floatingCursorReport =
                IDUIKitInteractionDependencyReport(
                    floatingContract, contract.identifier);
        }
        return self;
    }
    cleanupTarget = nil;

    self = [super init];
    if (self != nil) {
        _privateAssistant = assistant;
        _report = [interactionReport reportByActivating];
        _floatingCursorAvailable = floatingResult.isAccepted;
        _floatingCursorReport = floatingResult.isAccepted
            ? [floatingReport reportByActivating]
            : floatingReport;
    }
    return self;
}

- (id)activeAssistant {
    return self.isDetached ? nil : self.privateAssistant;
}

- (void)setSelectionActive:(BOOL)active visible:(BOOL)visible {
    id assistant = [self activeAssistant];
    if (assistant == nil) return;
    ((void (*)(id, SEL, BOOL))objc_msgSend)(
        assistant,
        NSSelectorFromString(TGPN_setSelectionDisplayVisible_()),
        visible);
    ((void (*)(id, SEL))objc_msgSend)(
        assistant,
        NSSelectorFromString(
            active ? TGPN_activateSelection() : TGPN_deactivateSelection()));
}

- (void)id_selectionChanged {
    id assistant = [self activeAssistant];
    if (assistant == nil) return;
    ((void (*)(id, SEL))objc_msgSend)(
        assistant, NSSelectorFromString(TGPN_selectionChanged()));
}

- (void)id_setNeedsSelectionDisplayUpdate {
    id assistant = [self activeAssistant];
    if (assistant == nil) return;
    ((void (*)(id, SEL))objc_msgSend)(
        assistant,
        NSSelectorFromString(TGPN_setNeedsSelectionDisplayUpdate()));
}

- (void)setGestureRecognizersEnabled:(BOOL)enabled {
    if (enabled) {
        id assistant = [self activeAssistant];
        if (assistant == nil) return;
        ((void (*)(id, SEL))objc_msgSend)(
            assistant,
            NSSelectorFromString(TGPN_setGestureRecognizers()));
    } else {
        [self clearGestureRecognizersForced:YES];
    }
}

- (void)clearGestureRecognizersForced:(BOOL)forced {
    id assistant = [self activeAssistant];
    if (assistant == nil) return;
    ((void (*)(id, SEL, BOOL))objc_msgSend)(
        assistant,
        NSSelectorFromString(TGPN_clearGestureRecognizers_()),
        forced);
}

- (void)beginFloatingCursorAtPoint:(CGPoint)point {
    id assistant = [self activeAssistant];
    if (assistant == nil || !self.floatingCursorAvailable) return;
    ((void (*)(id, SEL, CGPoint))objc_msgSend)(
        assistant,
        NSSelectorFromString(@"beginFloatingCursorAtPoint:"),
        point);
}

- (void)updateFloatingCursorAtPoint:(CGPoint)point
                           animated:(BOOL)animated {
    id assistant = [self activeAssistant];
    if (assistant == nil || !self.floatingCursorAvailable) return;
    ((void (*)(id, SEL, CGPoint, BOOL))objc_msgSend)(
        assistant,
        NSSelectorFromString(@"updateFloatingCursorAtPoint:animated:"),
        point,
        animated);
}

- (void)endFloatingCursor {
    id assistant = [self activeAssistant];
    if (assistant == nil || !self.floatingCursorAvailable) return;
    ((void (*)(id, SEL))objc_msgSend)(
        assistant, NSSelectorFromString(@"endFloatingCursor"));
}

- (void)id_resignedFirstResponder {
    id assistant = [self activeAssistant];
    if (assistant == nil) return;
    ((void (*)(id, SEL))objc_msgSend)(
        assistant,
        NSSelectorFromString(TGPN_resignedFirstResponder()));
}

- (void)id_selectWord {
    id assistant = [self activeAssistant];
    if (assistant == nil) return;
    ((void (*)(id, SEL))objc_msgSend)(
        assistant, NSSelectorFromString(TGPN_selectWord()));
}

- (void)selectAll:(id)sender {
    id assistant = [self activeAssistant];
    if (assistant == nil) return;
    ((void (*)(id, SEL, id))objc_msgSend)(
        assistant, NSSelectorFromString(@"selectAll:"), sender);
}

- (void)id_autoscrollWillNotStart {
    id assistant = [self activeAssistant];
    if (assistant == nil) return;
    ((void (*)(id, SEL))objc_msgSend)(
        assistant,
        NSSelectorFromString(TGPN_autoscrollWillNotStart()));
}

- (void)autoscrollDidTick {
    id assistant = [self activeAssistant];
    if (assistant == nil) return;
    SEL selector = NSSelectorFromString(TGPN_setAutoscrolled_());
    if (![assistant respondsToSelector:selector]) return;
    NSMethodSignature *signature = [assistant methodSignatureForSelector:selector];
    if (signature.numberOfArguments != 3 || strcmp(signature.methodReturnType, @encode(void)) != 0
        || strcmp([signature getArgumentTypeAtIndex:2], @encode(BOOL)) != 0) {
        return;
    }
    ((void (*)(id, SEL, BOOL))objc_msgSend)(assistant, selector, YES);
}

- (void)detach {
    id assistant = [self activeAssistant];
    if (assistant == nil) {
        self.detached = YES;
        return;
    }
    self.detached = YES;
    ((void (*)(id, SEL, BOOL))objc_msgSend)(
        assistant, NSSelectorFromString(@"detach:"), YES);
}

- (void)dealloc {
    [self detach];
}

@end

#endif
