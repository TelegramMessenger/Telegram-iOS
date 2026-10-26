#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDUIKitCapabilityResolver.h"

#include <stdlib.h>

@interface IDUIKitSystemRuntimeLookup :
    NSObject <IDUIKitRuntimeLookingUp>
@end

@implementation IDUIKitSystemRuntimeLookup

- (Class)classNamed:(NSString *)name {
    return NSClassFromString(name);
}

- (Protocol *)protocolNamed:(NSString *)name {
    return NSProtocolFromString(name);
}

// `class_getInstanceMethod` deliberately does not run `+initialize`, and our classes add the
// callbacks UIKit calls under private names from `+initialize` (`TGPrivateMethodAliases.h`). So the
// class is initialized first, or a contract checked before any instance exists finds no callbacks.
- (Method)instanceMethodForClass:(Class)cls selector:(SEL)selector {
    (void)[cls class];
    return class_getInstanceMethod(cls, selector);
}

- (Method)classMethodForClass:(Class)cls selector:(SEL)selector {
    (void)[cls class];
    return class_getClassMethod(cls, selector);
}

- (Ivar)instanceVariableForClass:(Class)cls name:(NSString *)name {
    return class_getInstanceVariable(cls, name.UTF8String);
}

@end

@interface IDUIKitContractResult ()
@property(nonatomic, getter=isAccepted, readwrite) BOOL accepted;
@property(nonatomic, readwrite) IDUIKitCapabilityState state;
@property(nonatomic, copy, readwrite) NSString *contractIdentifier;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *mismatches;
@property(nonatomic, copy, readwrite)
    NSDictionary<NSString *, NSString *> *observedABIs;
@end

@implementation IDUIKitContractResult
@end

@interface IDUIKitCapabilityResolver ()
@property(nonatomic, strong) id<IDUIKitRuntimeLookingUp> lookup;
@end

static NSString *IDUIKitResolverTypeString(const char *encoding) {
    return encoding == NULL
        ? @"<missing>"
        : [NSString stringWithUTF8String:encoding];
}

static NSString *IDUIKitResolverObservedMethodABI(
    NSString *returnType,
    NSArray<NSString *> *argumentTypes) {
    return [NSString stringWithFormat:
        @"return=%@; arguments=(%@)",
        returnType,
        [argumentTypes componentsJoinedByString:@", "]];
}

static NSString *IDUIKitResolverMethodMismatch(
    IDUIKitRuntimeMemberContract *member,
    NSString *observedReturn,
    NSArray<NSString *> *observedArguments) {
    if (!IDUIKitRuntimeTypeEncodingMatches(
            observedReturn.UTF8String,
            member.returnType)) {
        return [NSString stringWithFormat:
            @"%@: expected return %@ arguments (%@), observed return %@ arguments (%@)",
            member.identifier,
            member.returnType,
            [member.argumentTypes componentsJoinedByString:@", "],
            observedReturn,
            [observedArguments componentsJoinedByString:@", "]];
    }
    if (observedArguments.count != member.argumentTypes.count) {
        return [NSString stringWithFormat:
            @"%@: expected %lu arguments (%@), observed %lu arguments (%@)",
            member.identifier,
            (unsigned long)member.argumentTypes.count,
            [member.argumentTypes componentsJoinedByString:@", "],
            (unsigned long)observedArguments.count,
            [observedArguments componentsJoinedByString:@", "]];
    }
    for (NSUInteger index = 0;
         index < observedArguments.count;
         index += 1) {
        if (IDUIKitRuntimeTypeEncodingMatches(
                observedArguments[index].UTF8String,
                member.argumentTypes[index])) {
            continue;
        }
        return [NSString stringWithFormat:
            @"%@: argument %lu expected %@, observed %@; return %@",
            member.identifier,
            (unsigned long)index,
            member.argumentTypes[index],
            observedArguments[index],
            observedReturn];
    }
    return nil;
}

@implementation IDUIKitCapabilityResolver

+ (instancetype)systemResolver {
    return [[self alloc]
        initWithLookup:[IDUIKitSystemRuntimeLookup new]];
}

- (instancetype)initWithLookup:(id<IDUIKitRuntimeLookingUp>)lookup {
    NSParameterAssert(lookup != nil);
    self = [super init];
    if (self != nil) {
        _lookup = lookup;
    }
    return self;
}

- (Class)classNamed:(NSString *)name {
    return [self.lookup classNamed:name];
}

- (Protocol *)protocolNamed:(NSString *)name {
    return [self.lookup protocolNamed:name];
}

- (IDUIKitContractResult *)evaluateContract:
    (IDUIKitRuntimeCapabilityContract *)contract {
    NSParameterAssert(contract != nil);
    NSMutableDictionary<NSString *, id> *classes =
        [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *missingClasses =
        [NSMutableSet set];
    NSMutableArray<NSString *> *missing =
        [NSMutableArray array];
    NSMutableArray<NSString *> *abiMismatches =
        [NSMutableArray array];
    NSMutableDictionary<NSString *, NSString *> *observed =
        [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *requiredClassNames =
        [NSMutableSet set];
    for (IDUIKitRuntimeMemberContract *member in contract.members) {
        if (member.isRequired &&
            member.kind != IDUIKitPrivateMemberKindProtocol) {
            [requiredClassNames addObject:member.className];
        }
    }

    for (IDUIKitRuntimeMemberContract *member in contract.members) {
        if (member.kind == IDUIKitPrivateMemberKindProtocol) {
            Protocol *protocol =
                [self.lookup protocolNamed:member.name];
            if (protocol == nil) {
                if (member.isRequired) {
                    [missing addObject:[NSString stringWithFormat:
                        @"Protocol %@ is unavailable",
                        member.name]];
                } else {
                    observed[member.identifier] =
                        @"<missing optional>";
                }
            } else {
                observed[member.identifier] =
                    [@"protocol=" stringByAppendingString:
                        NSStringFromProtocol(protocol)];
            }
            continue;
        }

        Class cls = classes[member.className];
        if (cls == Nil &&
            ![missingClasses containsObject:member.className]) {
            cls = [self.lookup classNamed:member.className];
            if (cls == Nil) {
                [missingClasses addObject:member.className];
                if ([requiredClassNames
                        containsObject:member.className]) {
                    [missing addObject:[NSString stringWithFormat:
                        @"Class %@ is unavailable",
                        member.className]];
                }
            } else {
                classes[member.className] = cls;
            }
        }
        if (cls == Nil) {
            if (!member.isRequired) {
                observed[member.identifier] =
                    @"<missing optional>";
            }
            continue;
        }

        if (member.kind == IDUIKitPrivateMemberKindIvar) {
            Ivar ivar = [self.lookup
                instanceVariableForClass:cls
                                    name:member.name];
            if (ivar == NULL) {
                if (member.isRequired) {
                    [missing addObject:[NSString stringWithFormat:
                        @"%@: missing ivar %@.%@",
                        member.identifier,
                        member.className,
                        member.name]];
                } else {
                    observed[member.identifier] =
                        @"<missing optional>";
                }
                continue;
            }
            NSString *actual =
                IDUIKitResolverTypeString(
                    ivar_getTypeEncoding(ivar));
            observed[member.identifier] =
                [@"ivar=" stringByAppendingString:actual];
            if (!IDUIKitRuntimeTypeEncodingMatches(
                    actual.UTF8String,
                    member.returnType)) {
                [abiMismatches addObject:[NSString stringWithFormat:
                    @"%@: expected ivar %@, observed %@",
                    member.identifier,
                    member.returnType,
                    actual]];
            }
            continue;
        }

        SEL selector = NSSelectorFromString(member.name);
        Method method =
            member.kind == IDUIKitPrivateMemberKindClassMethod
                ? [self.lookup classMethodForClass:cls
                                         selector:selector]
                : [self.lookup instanceMethodForClass:cls
                                            selector:selector];
        if (method == NULL) {
            if (member.isRequired) {
                [missing addObject:[NSString stringWithFormat:
                    @"%@: missing %@ %@%@",
                    member.identifier,
                    member.className,
                    member.kind ==
                        IDUIKitPrivateMemberKindClassMethod
                            ? @"+"
                            : @"-",
                    member.name]];
            } else {
                observed[member.identifier] =
                    @"<missing optional>";
            }
            continue;
        }

        char *returnBytes = method_copyReturnType(method);
        NSString *returnType =
            IDUIKitResolverTypeString(returnBytes);
        free(returnBytes);
        unsigned int argumentCount =
            method_getNumberOfArguments(method);
        NSMutableArray<NSString *> *arguments =
            [NSMutableArray array];
        for (unsigned int index = 2;
             index < argumentCount;
             index += 1) {
            char *argumentBytes =
                method_copyArgumentType(method, index);
            [arguments addObject:
                IDUIKitResolverTypeString(argumentBytes)];
            free(argumentBytes);
        }
        observed[member.identifier] =
            IDUIKitResolverObservedMethodABI(
                returnType,
                arguments);
        NSString *mismatch =
            IDUIKitResolverMethodMismatch(
                member,
                returnType,
                arguments);
        if (mismatch != nil) {
            [abiMismatches addObject:mismatch];
        }
    }

    IDUIKitContractResult *result =
        [IDUIKitContractResult new];
    result.contractIdentifier = contract.identifier;
    result.observedABIs = observed.copy;
    if (missing.count != 0) {
        result.accepted = NO;
        result.state = IDUIKitCapabilityStateUnavailable;
        result.mismatches = missing.copy;
    } else if (abiMismatches.count != 0) {
        result.accepted = NO;
        result.state =
            IDUIKitCapabilityStateRejectedContract;
        result.mismatches = abiMismatches.copy;
    } else {
        result.accepted = YES;
        result.state = IDUIKitCapabilityStateAvailable;
        result.mismatches = @[];
    }
    return result;
}

@end

#endif
