#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGPrivateRuntimeNames.h"
#import "IDUIKitBehaviorKernel.h"
#import "TGRichTextInputDecContract.h"

NSErrorDomain const IDUIKitBehaviorKernelErrorDomain =
    @"IDUIKitBehaviorKernelErrorDomain";

typedef NS_ENUM(NSInteger, IDUIKitBehaviorKernelError) {
    IDUIKitBehaviorKernelErrorMissingInputContract = 1,
    IDUIKitBehaviorKernelErrorInputConstructionFailed,
    IDUIKitBehaviorKernelErrorInteractionConstructionFailed,
    IDUIKitBehaviorKernelErrorIncomingCallbackContractFailed,
};

@interface IDUIKitBehaviorKernel ()
@property(nonatomic, readwrite) IDUIKitBehaviorKernelLifecycle lifecycle;
@property(nonatomic, strong, readwrite)
    IDUIKitInputControllerCapability *inputController;
@property(nonatomic, strong, readwrite, nullable)
    IDUIKitInteractionCapability *interaction;
@property(nonatomic, strong, readwrite, nullable)
    IDUIKitAutoscrollEntryCapability *autoscrollEntry;
@property(nonatomic, strong, readwrite) IDUIKitBehaviorReport *report;
@end

static NSError *IDUIKitKernelError(
    IDUIKitBehaviorKernelError code,
    NSString *description,
    NSError *underlying) {
    NSMutableDictionary<NSString *, id> *userInfo =
        [NSMutableDictionary dictionaryWithObject:description
                                          forKey:NSLocalizedDescriptionKey];
    if (underlying != nil) {
        userInfo[NSUnderlyingErrorKey] = underlying;
    }
    return [NSError errorWithDomain:IDUIKitBehaviorKernelErrorDomain
                               code:code userInfo:userInfo.copy];
}

static NSArray<NSString *> *IDUIKitKernelRequiredMembers(
    IDUIKitRuntimeCapabilityContract *contract) {
    NSMutableArray<NSString *> *members = [NSMutableArray array];
    for (IDUIKitRuntimeMemberContract *member in contract.members) {
        if (member.isRequired) {
            [members addObject:member.identifier];
        }
    }
    return [members sortedArrayUsingSelector:@selector(compare:)];
}

static IDUIKitCapabilityReport *IDUIKitKernelDependencyReport(
    IDUIKitRuntimeCapabilityContract *contract,
    NSString *dependency) {
    return [[IDUIKitCapabilityReport alloc]
        initWithIdentifier:contract.identifier
                     state:IDUIKitCapabilityStateUnavailable
           requiredMembers:IDUIKitKernelRequiredMembers(contract)
              observedABIs:@{}
              dependencies:contract.dependencies
                  fallback:contract.fallback
           rejectionReason:[NSString stringWithFormat:
               @"Dependency %@ is not active.", dependency]];
}

IDUIKitRuntimeManifest *IDUIKitBehaviorRuntimeManifest(void) {
    return TGRichTextInputDecContractManifest();
}

static IDUIKitCapabilityReport *IDUIKitKernelContractReport(
    IDUIKitRuntimeCapabilityContract *contract,
    IDUIKitContractResult *result,
    BOOL active) {
    NSString *reason = result.mismatches.count == 0
        ? nil
        : [result.mismatches componentsJoinedByString:@"\n"];
    IDUIKitCapabilityReport *report = [[IDUIKitCapabilityReport alloc]
        initWithIdentifier:contract.identifier
                     state:result.state
           requiredMembers:IDUIKitKernelRequiredMembers(contract)
              observedABIs:result.observedABIs
              dependencies:contract.dependencies
                  fallback:contract.fallback
           rejectionReason:reason];
    return active && result.isAccepted
        ? [report reportByActivating]
        : report;
}

static BOOL IDUIKitKernelAllMembersObserved(
    IDUIKitRuntimeCapabilityContract *contract,
    IDUIKitContractResult *result) {
    for (IDUIKitRuntimeMemberContract *member in contract.members) {
        NSString *observed = result.observedABIs[member.identifier];
        if (observed == nil ||
            [observed isEqualToString:@"<missing optional>"]) {
            return NO;
        }
    }
    return YES;
}

@implementation IDUIKitBehaviorKernel

// Not the default `_inputController`: that is a private UIKit ivar name the engine looks up, and it
// must not reach the binary as text (`TGPrivateRuntimeNames.h`).
@synthesize inputController = _id_inputController;

- (instancetype)initWithManifest:(IDUIKitRuntimeManifest *)manifest
                         resolver:(IDUIKitCapabilityResolver *)resolver
                 layoutController:(id)layoutController
                         delegate:(id)delegate
                             view:(UIView *)view
            requestedCapabilities:
    (IDUIKitBehaviorCapabilities)requested
                            error:(NSError **)error {
    NSParameterAssert(manifest != nil);
    NSParameterAssert(resolver != nil);
    NSParameterAssert(layoutController != nil);
    NSParameterAssert(view != nil);
    self = [super init];
    if (self == nil) return nil;
    _lifecycle = IDUIKitBehaviorKernelLifecycleConstructing;

    IDUIKitRuntimeCapabilityContract *inputContract =
        manifest.capabilities[@"inputController"];
    if (inputContract == nil || !inputContract.isMandatory) {
        if (error != NULL) {
            *error = IDUIKitKernelError(
                IDUIKitBehaviorKernelErrorMissingInputContract,
                @"The mandatory input-controller contract is unavailable.",
                nil);
        }
        return nil;
    }

    NSError *inputError = nil;
    IDUIKitInputControllerCapability *input =
        [[IDUIKitInputControllerCapability alloc]
            initWithContract:inputContract
                    resolver:resolver
            layoutController:layoutController
                    delegate:delegate
                       error:&inputError];
    if (input == nil) {
        if (error != NULL) {
            *error = IDUIKitKernelError(
                IDUIKitBehaviorKernelErrorInputConstructionFailed,
                @"The mandatory input-controller capability was rejected.",
                inputError);
        }
        return nil;
    }
    _id_inputController = input;

    NSMutableArray<IDUIKitCapabilityReport *> *reports =
        [NSMutableArray arrayWithObject:input.report];
    IDUIKitBehaviorCapabilities validatedOptionalCapabilities = 0;
    NSArray<NSString *> *declarativeCapabilityNames =
        @[@"incomingCallbacks"];
    for (NSString *name in declarativeCapabilityNames) {
        IDUIKitRuntimeCapabilityContract *contract =
            manifest.capabilities[name];
        if (contract == nil ||
            (requested & contract.capability) == 0) {
            continue;
        }
        IDUIKitContractResult *result =
            [resolver evaluateContract:contract];
        BOOL active = result.isAccepted &&
            IDUIKitKernelAllMembersObserved(contract, result);
        [reports addObject:
            IDUIKitKernelContractReport(contract, result, active)];
        if (active) {
            validatedOptionalCapabilities |= contract.capability;
        }
        if ([name isEqualToString:@"incomingCallbacks"] &&
            !result.isAccepted) {
            [input detach];
            if (error != NULL) {
                *error = IDUIKitKernelError(
                    IDUIKitBehaviorKernelErrorIncomingCallbackContractFailed,
                    @"The required incoming-callback capability was rejected.",
                    nil);
            }
            return nil;
        }
    }

    BOOL wantsInteraction =
        (requested & IDUIKitBehaviorCapabilityInteraction) != 0;
    BOOL wantsFloating =
        (requested & IDUIKitBehaviorCapabilityFloatingCursor) != 0;
    IDUIKitRuntimeCapabilityContract *interactionContract =
        manifest.capabilities[@"interaction"];
    IDUIKitRuntimeCapabilityContract *floatingContract =
        manifest.capabilities[@"floatingCursor"];
    IDUIKitRuntimeCapabilityContract *autoscrollEntryContract =
        manifest.capabilities[@"autoscrollEntry"];
    if ((requested & IDUIKitBehaviorCapabilityAutoscroll) != 0 &&
        autoscrollEntryContract != nil) {
        IDUIKitAutoscrollEntryCapability *entry =
            [[IDUIKitAutoscrollEntryCapability alloc]
                initWithContract:autoscrollEntryContract
                        resolver:resolver
                       viewClass:view.class];
        [reports addObject:entry.report];
        if (entry.isActive) {
            _autoscrollEntry = entry;
            validatedOptionalCapabilities |=
                IDUIKitBehaviorCapabilityAutoscroll;
            [reports addObject:[[IDUIKitCapabilityReport alloc]
                initWithIdentifier:@"autoscrollEngine"
                             state:IDUIKitCapabilityStateProjectOwned
                   requiredMembers:@[]
                      observedABIs:@{}
                      dependencies:@[@"autoscrollEntry"]
                          fallback:@"vertical edge autoscroll disabled"
                   rejectionReason:nil]];
        }
    }

    if (wantsInteraction) {
        if (interactionContract == nil) {
            if (error != NULL) {
                *error = IDUIKitKernelError(
                    IDUIKitBehaviorKernelErrorInteractionConstructionFailed,
                    @"The requested interaction contract is unavailable.",
                    nil);
            }
            [input detach];
            return nil;
        }
        NSError *interactionError = nil;
        IDUIKitInteractionCapability *interaction =
            [[IDUIKitInteractionCapability alloc]
                initWithContract:interactionContract
                        resolver:resolver
                            view:view
                           error:&interactionError];
        if (interaction == nil) {
            [input detach];
            if (error != NULL) {
                *error = IDUIKitKernelError(
                    IDUIKitBehaviorKernelErrorInteractionConstructionFailed,
                    @"The interaction capability could not be constructed.",
                    interactionError);
            }
            return nil;
        }
        [reports addObject:interaction.report];
        if (wantsFloating) {
            [reports addObject:interaction.floatingCursorReport];
        }
        if (interaction.privateAssistant != nil) {
            _interaction = interaction;
        }
    } else if (wantsFloating && floatingContract != nil) {
        [reports addObject:IDUIKitKernelDependencyReport(
            floatingContract, @"interaction")];
    }

    NSArray<NSString *> *optionalDeclarativeCapabilityNames = @[
        @"checking",
        @"typingAttributes",
        @"prediction",
        @"paste",
        @"dictation",
    ];
    for (NSString *name in optionalDeclarativeCapabilityNames) {
        IDUIKitRuntimeCapabilityContract *contract =
            manifest.capabilities[name];
        if (contract == nil ||
            (requested & contract.capability) == 0) {
            continue;
        }
        NSString *inactiveDependency = nil;
        for (NSString *dependency in contract.dependencies) {
            BOOL active =
                [dependency isEqualToString:@"inputController"] ||
                ([dependency isEqualToString:@"interaction"] &&
                 _interaction != nil);
            if (!active) {
                inactiveDependency = dependency;
                break;
            }
        }
        if (inactiveDependency != nil) {
            [reports addObject:IDUIKitKernelDependencyReport(
                contract, inactiveDependency)];
            continue;
        }
        IDUIKitContractResult *result =
            [resolver evaluateContract:contract];
        BOOL active = result.isAccepted &&
            IDUIKitKernelAllMembersObserved(contract, result);
        [reports addObject:
            IDUIKitKernelContractReport(contract, result, active)];
        if (active) {
            validatedOptionalCapabilities |= contract.capability;
        }
    }

    [input setValidatedOptionalCapabilities:
        validatedOptionalCapabilities];
    _report = [[IDUIKitBehaviorReport alloc]
        initWithOSVersion:manifest.osVersion
                  osBuild:manifest.osBuild
              capabilities:reports.copy
                  detached:NO];
    _lifecycle = IDUIKitBehaviorKernelLifecycleActive;
    return self;
}

- (void)detach {
    if (self.lifecycle == IDUIKitBehaviorKernelLifecycleDetached) {
        return;
    }
    self.lifecycle = IDUIKitBehaviorKernelLifecycleDetached;
    [self.interaction detach];
    [self.inputController detach];
    if (self.report != nil) {
        self.report = [self.report reportByMarkingDetached];
    }
}

- (void)dealloc {
    [self detach];
}

@end

#endif
