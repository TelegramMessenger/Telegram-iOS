#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDUIKitBehaviorReport.h"

static NSArray<NSString *> *IDUIKitSortedStrings(
    NSArray<NSString *> *strings) {
    return [strings sortedArrayUsingSelector:@selector(compare:)];
}

static NSString *IDUIKitCapabilityStateName(
    IDUIKitCapabilityState state) {
    switch (state) {
        case IDUIKitCapabilityStateUnavailable:
            return @"unavailable";
        case IDUIKitCapabilityStateRejectedContract:
            return @"rejectedContract";
        case IDUIKitCapabilityStateAvailable:
            return @"available";
        case IDUIKitCapabilityStateActive:
            return @"active";
        case IDUIKitCapabilityStateProjectOwned:
            return @"projectOwned";
    }
}

static NSUInteger IDUIKitNormalizedDictionaryHash(
    NSDictionary<NSString *, id> *dictionary) {
    NSData *data = [NSJSONSerialization
        dataWithJSONObject:dictionary
                   options:NSJSONWritingSortedKeys
                     error:nil];
    return data.hash;
}

@interface IDUIKitCapabilityReport ()
@property(nonatomic, copy, readwrite) NSString *identifier;
@property(nonatomic, readwrite) IDUIKitCapabilityState state;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *requiredMembers;
@property(nonatomic, copy, readwrite)
    NSDictionary<NSString *, NSString *> *observedABIs;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *dependencies;
@property(nonatomic, copy, readwrite) NSString *fallback;
@property(nonatomic, copy, readwrite, nullable) NSString *rejectionReason;
@end

@implementation IDUIKitCapabilityReport

- (instancetype)initWithIdentifier:(NSString *)identifier
                             state:(IDUIKitCapabilityState)state
                   requiredMembers:(NSArray<NSString *> *)requiredMembers
                      observedABIs:
    (NSDictionary<NSString *, NSString *> *)observedABIs
                      dependencies:(NSArray<NSString *> *)dependencies
                          fallback:(NSString *)fallback
                   rejectionReason:(NSString *)rejectionReason {
    NSParameterAssert(identifier.length != 0);
    NSParameterAssert(requiredMembers != nil);
    NSParameterAssert(observedABIs != nil);
    NSParameterAssert(dependencies != nil);
    NSParameterAssert(fallback != nil);
    NSParameterAssert(state <= IDUIKitCapabilityStateProjectOwned);
    self = [super init];
    if (self != nil) {
        _identifier = [identifier copy];
        _state = state;
        _requiredMembers =
            [IDUIKitSortedStrings(requiredMembers) copy];
        _observedABIs = [observedABIs copy];
        _dependencies =
            [IDUIKitSortedStrings(dependencies) copy];
        _fallback = [fallback copy];
        _rejectionReason = [rejectionReason copy];
    }
    return self;
}

- (IDUIKitCapabilityReport *)reportByActivating {
    if (self.state == IDUIKitCapabilityStateActive) {
        return self;
    }
    if (self.state != IDUIKitCapabilityStateAvailable) {
        @throw [NSException
            exceptionWithName:NSInternalInconsistencyException
                       reason:[NSString stringWithFormat:
                           @"Capability %@ cannot transition from %@ to active",
                           self.identifier,
                           IDUIKitCapabilityStateName(self.state)]
                     userInfo:nil];
    }
    return [[IDUIKitCapabilityReport alloc]
        initWithIdentifier:self.identifier
                     state:IDUIKitCapabilityStateActive
           requiredMembers:self.requiredMembers
              observedABIs:self.observedABIs
              dependencies:self.dependencies
                  fallback:self.fallback
           rejectionReason:self.rejectionReason];
}

- (NSDictionary<NSString *, id> *)normalizedDictionary {
    return @{
        @"identifier": self.identifier,
        @"state": IDUIKitCapabilityStateName(self.state),
        @"requiredMembers": self.requiredMembers,
        @"observedABIs": self.observedABIs,
        @"dependencies": self.dependencies,
        @"fallback": self.fallback,
        @"rejectionReason": self.rejectionReason ?: NSNull.null,
    };
}

- (BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:IDUIKitCapabilityReport.class]) {
        return NO;
    }
    return [self.normalizedDictionary
        isEqual:[object normalizedDictionary]];
}

- (NSUInteger)hash {
    return IDUIKitNormalizedDictionaryHash(
        self.normalizedDictionary);
}

@end

@interface IDUIKitBehaviorReport ()
@property(nonatomic, copy, readwrite) NSString *osVersion;
@property(nonatomic, copy, readwrite) NSString *osBuild;
@property(nonatomic, copy, readwrite)
    NSArray<IDUIKitCapabilityReport *> *capabilities;
@property(nonatomic, getter=isDetached, readwrite) BOOL detached;
@end

@implementation IDUIKitBehaviorReport

- (instancetype)initWithOSVersion:(NSString *)osVersion
                          osBuild:(NSString *)osBuild
                      capabilities:
    (NSArray<IDUIKitCapabilityReport *> *)capabilities
                          detached:(BOOL)detached {
    NSParameterAssert(osVersion.length != 0);
    NSParameterAssert(osBuild.length != 0);
    NSParameterAssert(capabilities != nil);
    self = [super init];
    if (self != nil) {
        _osVersion = [osVersion copy];
        _osBuild = [osBuild copy];
        _capabilities = [[capabilities
            sortedArrayUsingComparator:
                ^NSComparisonResult(
                    IDUIKitCapabilityReport *left,
                    IDUIKitCapabilityReport *right) {
                    return [left.identifier
                        compare:right.identifier];
                }] copy];
        _detached = detached;
    }
    return self;
}

- (IDUIKitBehaviorReport *)reportByMarkingDetached {
    if (self.isDetached) {
        return self;
    }
    return [[IDUIKitBehaviorReport alloc]
        initWithOSVersion:self.osVersion
                  osBuild:self.osBuild
              capabilities:self.capabilities
                  detached:YES];
}

- (NSDictionary<NSString *, id> *)normalizedDictionary {
    NSMutableArray<NSDictionary<NSString *, id> *> *capabilities =
        [NSMutableArray arrayWithCapacity:self.capabilities.count];
    for (IDUIKitCapabilityReport *report in self.capabilities) {
        [capabilities addObject:report.normalizedDictionary];
    }
    return @{
        @"osVersion": self.osVersion,
        @"osBuild": self.osBuild,
        @"capabilities": capabilities.copy,
        @"detached": @(self.isDetached),
    };
}

- (BOOL)isEqual:(id)object {
    if (object == self) {
        return YES;
    }
    if (![object isKindOfClass:IDUIKitBehaviorReport.class]) {
        return NO;
    }
    return [self.normalizedDictionary
        isEqual:[object normalizedDictionary]];
}

- (NSUInteger)hash {
    return IDUIKitNormalizedDictionaryHash(
        self.normalizedDictionary);
}

@end

#endif
