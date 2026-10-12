#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGPrivateRuntimeNames.h"

#import "IDUIKitAutoscrollEntryCapability.h"

#import "TGRichTextInputDecHostPreflight.h"

@interface IDUIKitAutoscrollEntryCapability ()
@property(nonatomic, getter=isActive, readwrite) BOOL active;
@property(nonatomic, strong, readwrite)
    IDUIKitCapabilityReport *report;
- (BOOL)adoptProtocol:(Protocol *)protocol
              onClass:(Class)viewClass;
@end

static NSArray<NSString *> *IDUIKitAutoscrollEntryRequiredMembers(
    IDUIKitRuntimeCapabilityContract *contract) {
    NSMutableArray<NSString *> *members =
        [NSMutableArray array];
    for (IDUIKitRuntimeMemberContract *member in contract.members) {
        if (member.isRequired) {
            [members addObject:member.identifier];
        }
    }
    return [members sortedArrayUsingSelector:@selector(compare:)];
}

static IDUIKitCapabilityReport *IDUIKitAutoscrollEntryReport(
    IDUIKitRuntimeCapabilityContract *contract,
    IDUIKitContractResult *result,
    IDUIKitCapabilityState state,
    NSString *reason) {
    return [[IDUIKitCapabilityReport alloc]
        initWithIdentifier:contract.identifier
                     state:state
           requiredMembers:
               IDUIKitAutoscrollEntryRequiredMembers(contract)
              observedABIs:result.observedABIs
              dependencies:contract.dependencies
                  fallback:contract.fallback
           rejectionReason:reason];
}

@implementation IDUIKitAutoscrollEntryCapability

- (instancetype)initWithContract:
    (IDUIKitRuntimeCapabilityContract *)contract
                         resolver:
    (IDUIKitCapabilityResolver *)resolver
                        viewClass:(Class)viewClass {
    NSParameterAssert(contract != nil);
    NSParameterAssert(resolver != nil);
    NSParameterAssert(viewClass != Nil);
    self = [super init];
    if (self == nil) return nil;

    IDUIKitContractResult *result =
        [resolver evaluateContract:contract];
    NSString *resultReason = result.mismatches.count == 0
        ? nil
        : [result.mismatches componentsJoinedByString:@"\n"];
    if (!result.isAccepted) {
        _report = IDUIKitAutoscrollEntryReport(
            contract, result, result.state, resultReason);
        return self;
    }

    IDUIKitRuntimeMemberContract *protocolMember = nil;
    for (IDUIKitRuntimeMemberContract *member in contract.members) {
        if (member.kind == IDUIKitPrivateMemberKindProtocol) {
            protocolMember = member;
            break;
        }
    }
    Protocol *protocol = protocolMember == nil
        ? nil
        : [resolver protocolNamed:protocolMember.name];
    BOOL adopted = NO;
    @try {
        adopted = protocol != nil &&
            [self adoptProtocol:protocol onClass:viewClass] &&
            class_conformsToProtocol(viewClass, protocol);
    } @catch (__unused NSException *exception) {
        adopted = NO;
    }
    if (!adopted) {
        _report = IDUIKitAutoscrollEntryReport(
            contract,
            result,
            IDUIKitCapabilityStateRejectedContract,
            [NSString stringWithFormat:@"The validated %@ protocol could not be adopted.",
                TGPN_UITextAutoscrolling()]);
        return self;
    }

    _active = YES;
    _report = [IDUIKitAutoscrollEntryReport(
        contract,
        result,
        IDUIKitCapabilityStateAvailable,
        nil) reportByActivating];
    return self;
}

- (BOOL)adoptProtocol:(Protocol *)protocol
              onClass:(Class)viewClass {
    return [TGRichTextInputDecHostPreflight
        adoptResolvedTextAutoscrollingProtocol:protocol
                                       onClass:viewClass];
}

@end

#endif
