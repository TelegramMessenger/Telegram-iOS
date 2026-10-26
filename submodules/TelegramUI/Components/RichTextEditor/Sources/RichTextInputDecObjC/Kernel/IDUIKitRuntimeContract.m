#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGPrivateRuntimeNames.h"
#import "IDUIKitRuntimeContract.h"

#include <string.h>

NSErrorDomain const IDUIKitRuntimeContractErrorDomain =
    @"com.inputdec.private-uikit.runtime-contract";

typedef NS_ENUM(NSInteger, IDUIKitRuntimeContractErrorCode) {
    IDUIKitRuntimeContractErrorInvalidJSON = 1,
    IDUIKitRuntimeContractErrorInvalidSchema,
};

@interface IDUIKitRuntimeMemberContract ()
@property(nonatomic, copy, readwrite) NSString *identifier;
@property(nonatomic, copy, readwrite) NSString *className;
@property(nonatomic, readwrite) IDUIKitPrivateMemberKind kind;
@property(nonatomic, copy, readwrite) NSString *name;
@property(nonatomic, copy, readwrite) NSString *returnType;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *argumentTypes;
@property(nonatomic, getter=isRequired, readwrite) BOOL required;
@property(nonatomic, copy, readwrite) NSString *direction;
@property(nonatomic, copy, readwrite) NSString *source;
@property(nonatomic, copy, readwrite) NSString *evidence;
@property(nonatomic, copy, readwrite) NSString *fallback;
@property(nonatomic, copy, readwrite) NSString *teardown;
@end

@implementation IDUIKitRuntimeMemberContract
@end

@interface IDUIKitRuntimeCapabilityContract ()
@property(nonatomic, copy, readwrite) NSString *identifier;
@property(nonatomic, readwrite) IDUIKitBehaviorCapabilities capability;
@property(nonatomic, getter=isMandatory, readwrite) BOOL mandatory;
@property(nonatomic, copy, readwrite)
    NSArray<IDUIKitRuntimeMemberContract *> *members;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *dependencies;
@property(nonatomic, copy, readwrite) NSString *fallback;
@end

@implementation IDUIKitRuntimeCapabilityContract
@end

@interface IDUIKitRuntimeManifest ()
@property(nonatomic, readwrite) NSInteger schemaVersion;
@property(nonatomic, copy, readwrite) NSString *osVersion;
@property(nonatomic, copy, readwrite) NSString *osBuild;
@property(nonatomic, copy, readwrite)
    NSDictionary<NSString *, IDUIKitRuntimeCapabilityContract *> *capabilities;
@property(nonatomic, copy, readwrite)
    NSDictionary<NSString *, IDUIKitRuntimeCapabilityContract *> *referenceOnly;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *forbiddenSymbols;
@end

static NSError *IDUIKitContractError(NSString *description) {
    return [NSError errorWithDomain:IDUIKitRuntimeContractErrorDomain
                               code:IDUIKitRuntimeContractErrorInvalidSchema
                           userInfo:@{
        NSLocalizedDescriptionKey: description,
    }];
}

static BOOL IDUIKitSetError(NSError **error, NSString *description) {
    if (error != NULL) {
        *error = IDUIKitContractError(description);
    }
    return NO;
}

static BOOL IDUIKitDictionaryHasExactKeys(
    NSDictionary *dictionary,
    NSSet<NSString *> *expected,
    NSString *context,
    NSError **error) {
    if (![dictionary isKindOfClass:NSDictionary.class]) {
        return IDUIKitSetError(
            error,
            [NSString stringWithFormat:@"%@ must be an object", context]);
    }
    NSSet<NSString *> *actual =
        [NSSet setWithArray:dictionary.allKeys];
    if ([actual isEqualToSet:expected]) {
        return YES;
    }
    NSMutableSet<NSString *> *unknown = [actual mutableCopy];
    [unknown minusSet:expected];
    NSMutableSet<NSString *> *missing = [expected mutableCopy];
    [missing minusSet:actual];
    return IDUIKitSetError(
        error,
        [NSString stringWithFormat:
            @"%@ keys are invalid; unknown=(%@), missing=(%@)",
            context,
            [[unknown allObjects] componentsJoinedByString:@", "],
            [[missing allObjects] componentsJoinedByString:@", "]]);
}

static BOOL IDUIKitIsNonemptyString(id value) {
    return [value isKindOfClass:NSString.class] &&
        [(NSString *)value length] > 0;
}

static BOOL IDUIKitIsBoolean(id value) {
    return value != nil &&
        CFGetTypeID((__bridge CFTypeRef)value) ==
            CFBooleanGetTypeID();
}

static const char *IDUIKitSkipEncodingQualifiers(const char *encoding) {
    while (encoding != NULL &&
           encoding[0] != '\0' &&
           strchr("rnNoORV", encoding[0]) != NULL) {
        encoding += 1;
    }
    return encoding;
}

static const char *IDUIKitConsumeQuotedEncoding(const char *cursor) {
    if (cursor[0] != '"') {
        return cursor;
    }
    cursor += 1;
    while (cursor[0] != '\0') {
        if (cursor[0] == '\\' && cursor[1] != '\0') {
            cursor += 2;
            continue;
        }
        if (cursor[0] == '"') {
            return cursor + 1;
        }
        cursor += 1;
    }
    return NULL;
}

static const char *IDUIKitConsumeOneType(const char *cursor) {
    cursor = IDUIKitSkipEncodingQualifiers(cursor);
    if (cursor == NULL || cursor[0] == '\0') {
        return NULL;
    }
    if (strchr("cislqCISLQfdDBv*#:?", cursor[0]) != NULL) {
        return cursor + 1;
    }
    if (cursor[0] == '@') {
        cursor += 1;
        if (cursor[0] == '?') {
            return cursor + 1;
        }
        return IDUIKitConsumeQuotedEncoding(cursor);
    }
    if (cursor[0] == '^') {
        return IDUIKitConsumeOneType(cursor + 1);
    }
    if (cursor[0] == '[') {
        cursor += 1;
        while (cursor[0] >= '0' && cursor[0] <= '9') {
            cursor += 1;
        }
        cursor = IDUIKitConsumeOneType(cursor);
        return cursor != NULL && cursor[0] == ']' ? cursor + 1 : NULL;
    }
    if (cursor[0] == '{' || cursor[0] == '(') {
        char close = cursor[0] == '{' ? '}' : ')';
        cursor += 1;
        while (cursor[0] != '\0' &&
               cursor[0] != '=' &&
               cursor[0] != close) {
            cursor += 1;
        }
        if (cursor[0] == close) {
            return cursor + 1;
        }
        if (cursor[0] != '=') {
            return NULL;
        }
        cursor += 1;
        while (cursor[0] != '\0' && cursor[0] != close) {
            if (cursor[0] == '"') {
                cursor = IDUIKitConsumeQuotedEncoding(cursor);
            } else {
                cursor = IDUIKitConsumeOneType(cursor);
            }
            if (cursor == NULL) {
                return NULL;
            }
        }
        return cursor[0] == close ? cursor + 1 : NULL;
    }
    return NULL;
}

static BOOL IDUIKitIsValidTypeEncoding(NSString *encoding) {
    if (!IDUIKitIsNonemptyString(encoding)) {
        return NO;
    }
    const char *start = encoding.UTF8String;
    const char *end = IDUIKitConsumeOneType(start);
    return end != NULL && end[0] == '\0';
}

BOOL IDUIKitRuntimeTypeEncodingMatches(const char *actual,
                                       NSString *expected) {
    if (actual == NULL ||
        !IDUIKitIsValidTypeEncoding(expected)) {
        return NO;
    }
    actual = IDUIKitSkipEncodingQualifiers(actual);
    const char *expectedBytes =
        IDUIKitSkipEncodingQualifiers(expected.UTF8String);
    const char *actualEnd = IDUIKitConsumeOneType(actual);
    if (actualEnd == NULL || actualEnd[0] != '\0') {
        return NO;
    }
    if (expectedBytes[0] == '@' && expectedBytes[1] == '\0') {
        return actual[0] == '@' && actual[1] != '?';
    }
    if (expectedBytes[0] == '@' &&
        expectedBytes[1] == '?' &&
        expectedBytes[2] == '\0') {
        return actual[0] == '@' &&
            actual[1] == '?' &&
            actual[2] == '\0';
    }
    return strcmp(actual, expectedBytes) == 0;
}

static BOOL IDUIKitParseStringArray(
    id value,
    NSString *context,
    BOOL requiresUniqueValues,
    NSArray<NSString *> **result,
    NSError **error) {
    if (![value isKindOfClass:NSArray.class]) {
        return IDUIKitSetError(
            error,
            [NSString stringWithFormat:@"%@ must be an array", context]);
    }
    NSMutableArray<NSString *> *strings = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (id item in value) {
        if (!IDUIKitIsNonemptyString(item)) {
            return IDUIKitSetError(
                error,
                [NSString stringWithFormat:
                    @"%@ contains a non-string or empty value",
                    context]);
        }
        if (requiresUniqueValues &&
            [seen containsObject:item]) {
            return IDUIKitSetError(
                error,
                [NSString stringWithFormat:
                    @"%@ contains duplicate value %@",
                    context,
                    item]);
        }
        if (requiresUniqueValues) {
            [seen addObject:item];
        }
        [strings addObject:item];
    }
    *result = strings.copy;
    return YES;
}

static NSDictionary<NSString *, NSNumber *> *
IDUIKitCapabilityNames(void) {
    static NSDictionary<NSString *, NSNumber *> *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = @{
            @"inputController":
                @(IDUIKitBehaviorCapabilityInputController),
            @"interaction":
                @(IDUIKitBehaviorCapabilityInteraction),
            @"floatingCursor":
                @(IDUIKitBehaviorCapabilityFloatingCursor),
            @"autoscrollEntry":
                @(IDUIKitBehaviorCapabilityAutoscroll),
            @"checking":
                @(IDUIKitBehaviorCapabilityChecking),
            @"typingAttributes":
                @(IDUIKitBehaviorCapabilityTypingAttributes),
            @"prediction":
                @(IDUIKitBehaviorCapabilityPrediction),
            @"paste":
                @(IDUIKitBehaviorCapabilityPaste),
            @"dictation":
                @(IDUIKitBehaviorCapabilityDictation),
            @"incomingCallbacks":
                @(IDUIKitBehaviorCapabilityIncomingCallbacks),
        };
    });
    return names;
}

static BOOL IDUIKitParseMemberKind(
    NSString *value,
    IDUIKitPrivateMemberKind *kind) {
    NSDictionary<NSString *, NSNumber *> *kinds = @{
        @"classMethod": @(IDUIKitPrivateMemberKindClassMethod),
        @"instanceMethod": @(IDUIKitPrivateMemberKindInstanceMethod),
        @"ivar": @(IDUIKitPrivateMemberKindIvar),
        @"incomingCallback":
            @(IDUIKitPrivateMemberKindIncomingCallback),
        @"protocol": @(IDUIKitPrivateMemberKindProtocol),
    };
    NSNumber *number = kinds[value];
    if (number == nil) {
        return NO;
    }
    *kind = number.unsignedIntegerValue;
    return YES;
}

static BOOL IDUIKitParseMember(
    id value,
    NSString *context,
    NSMutableSet<NSString *> *memberIdentifiers,
    IDUIKitRuntimeMemberContract **result,
    NSError **error) {
    NSDictionary *dictionary = value;
    if (!IDUIKitDictionaryHasExactKeys(
            dictionary,
            [NSSet setWithArray:@[
                @"identifier",
                @"class",
                @"kind",
                @"name",
                @"returnType",
                @"argumentTypes",
                @"required",
                @"direction",
                @"source",
                @"evidence",
                @"fallback",
                @"teardown",
            ]],
            context,
            error)) {
        return NO;
    }
    NSString *identifier = dictionary[@"identifier"];
    NSString *className = dictionary[@"class"];
    NSString *kindName = dictionary[@"kind"];
    NSString *name = dictionary[@"name"];
    NSString *returnType = dictionary[@"returnType"];
    NSString *direction = dictionary[@"direction"];
    NSString *source = dictionary[@"source"];
    NSString *evidence = dictionary[@"evidence"];
    NSString *fallback = dictionary[@"fallback"];
    NSString *teardown = dictionary[@"teardown"];
    if (!IDUIKitIsNonemptyString(identifier) ||
        !IDUIKitIsNonemptyString(className) ||
        !IDUIKitIsNonemptyString(kindName) ||
        !IDUIKitIsNonemptyString(name) ||
        !IDUIKitIsNonemptyString(direction) ||
        !IDUIKitIsNonemptyString(source) ||
        !IDUIKitIsNonemptyString(evidence) ||
        !IDUIKitIsNonemptyString(fallback) ||
        !IDUIKitIsNonemptyString(teardown)) {
        return IDUIKitSetError(
            error,
            [NSString stringWithFormat:
                @"%@ has empty member or audit metadata",
                context]);
    }
    NSSet<NSString *> *directions = [NSSet setWithArray:@[
        @"outgoing",
        @"incoming",
        @"reference",
        @"testOnly",
    ]];
    if (![directions containsObject:direction]) {
        return IDUIKitSetError(
            error,
            [NSString stringWithFormat:
                @"%@ has unknown direction %@",
                context,
                direction]);
    }
    NSArray<NSString *> *sourceParts =
        [source componentsSeparatedByString:@"|"];
    if (sourceParts.count != 2 ||
        !IDUIKitIsNonemptyString(sourceParts.firstObject) ||
        !IDUIKitIsNonemptyString(sourceParts.lastObject)) {
        return IDUIKitSetError(
            error,
            [NSString stringWithFormat:
                @"%@.source must be relativePath|symbol",
                context]);
    }
    if ([memberIdentifiers containsObject:identifier]) {
        return IDUIKitSetError(
            error,
            [NSString stringWithFormat:
                @"Duplicate member identifier %@",
                identifier]);
    }
    IDUIKitPrivateMemberKind kind;
    if (!IDUIKitParseMemberKind(kindName, &kind)) {
        return IDUIKitSetError(
            error,
            [NSString stringWithFormat:
                @"%@ has unknown member kind %@",
                context,
                kindName]);
    }
    if (!IDUIKitIsValidTypeEncoding(returnType)) {
        return IDUIKitSetError(
            error,
            [NSString stringWithFormat:
                @"%@ has invalid returnType %@",
                context,
                returnType ?: @"<missing>"]);
    }
    NSArray<NSString *> *argumentTypes = nil;
    if (!IDUIKitParseStringArray(
            dictionary[@"argumentTypes"],
            [context stringByAppendingString:@".argumentTypes"],
            NO,
            &argumentTypes,
            error)) {
        return NO;
    }
    for (NSString *encoding in argumentTypes) {
        if (!IDUIKitIsValidTypeEncoding(encoding)) {
            return IDUIKitSetError(
                error,
                [NSString stringWithFormat:
                    @"%@ has invalid argument type %@",
                    context,
                    encoding]);
        }
    }
    if (!IDUIKitIsBoolean(dictionary[@"required"])) {
        return IDUIKitSetError(
            error,
            [NSString stringWithFormat:@"%@.required must be boolean",
                                       context]);
    }
    if (kind == IDUIKitPrivateMemberKindProtocol) {
        if (argumentTypes.count != 0) {
            return IDUIKitSetError(
                error,
                [NSString stringWithFormat:
                    @"%@ protocol cannot have arguments",
                    context]);
        }
        if (![returnType isEqualToString:@"@"]) {
            return IDUIKitSetError(
                error,
                [NSString stringWithFormat:
                    @"%@ protocol return type must be @",
                    context]);
        }
        if (![className isEqualToString:name]) {
            return IDUIKitSetError(
                error,
                [NSString stringWithFormat:
                    @"%@ protocol class and name must match",
                    context]);
        }
    } else if (kind == IDUIKitPrivateMemberKindIvar) {
        if (argumentTypes.count != 0 ||
            [name containsString:@":"]) {
            return IDUIKitSetError(
                error,
                [NSString stringWithFormat:
                    @"%@ ivar %@ cannot have arguments",
                    context,
                    name]);
        }
    } else {
        NSUInteger colonCount =
            [name componentsSeparatedByString:@":"].count - 1;
        if (colonCount != argumentTypes.count) {
            return IDUIKitSetError(
                error,
                [NSString stringWithFormat:
                    @"%@ selector %@ has %lu colons but %lu arguments",
                    context,
                    name,
                    (unsigned long)colonCount,
                    (unsigned long)argumentTypes.count]);
        }
    }
    IDUIKitRuntimeMemberContract *member =
        [IDUIKitRuntimeMemberContract new];
    member.identifier = identifier;
    member.className = className;
    member.kind = kind;
    member.name = name;
    member.returnType = returnType;
    member.argumentTypes = argumentTypes;
    member.required = [dictionary[@"required"] boolValue];
    member.direction = direction;
    member.source = source;
    member.evidence = evidence;
    member.fallback = fallback;
    member.teardown = teardown;
    [memberIdentifiers addObject:identifier];
    *result = member;
    return YES;
}

static BOOL IDUIKitParseCapability(
    NSString *identifier,
    id value,
    IDUIKitBehaviorCapabilities capability,
    NSMutableSet<NSString *> *memberIdentifiers,
    IDUIKitRuntimeCapabilityContract **result,
    NSError **error) {
    NSString *context =
        [NSString stringWithFormat:@"capability.%@", identifier];
    NSDictionary *dictionary = value;
    if (!IDUIKitDictionaryHasExactKeys(
            dictionary,
            [NSSet setWithArray:@[
                @"mandatory",
                @"dependencies",
                @"fallback",
                @"members",
            ]],
            context,
            error)) {
        return NO;
    }
    if (!IDUIKitIsBoolean(dictionary[@"mandatory"])) {
        return IDUIKitSetError(
            error,
            [NSString stringWithFormat:@"%@.mandatory must be boolean",
                                       context]);
    }
    NSArray<NSString *> *dependencies = nil;
    if (!IDUIKitParseStringArray(
            dictionary[@"dependencies"],
            [context stringByAppendingString:@".dependencies"],
            YES,
            &dependencies,
            error)) {
        return NO;
    }
    if (!IDUIKitIsNonemptyString(dictionary[@"fallback"])) {
        return IDUIKitSetError(
            error,
            [NSString stringWithFormat:@"%@.fallback must be nonempty",
                                       context]);
    }
    NSArray *memberValues = dictionary[@"members"];
    if (![memberValues isKindOfClass:NSArray.class] ||
        memberValues.count == 0) {
        return IDUIKitSetError(
            error,
            [NSString stringWithFormat:
                @"%@.members must be a nonempty array",
                context]);
    }
    NSMutableArray<IDUIKitRuntimeMemberContract *> *members =
        [NSMutableArray arrayWithCapacity:memberValues.count];
    for (NSUInteger index = 0; index < memberValues.count; index += 1) {
        IDUIKitRuntimeMemberContract *member = nil;
        if (!IDUIKitParseMember(
                memberValues[index],
                [NSString stringWithFormat:
                    @"%@.members[%lu]",
                    context,
                    (unsigned long)index],
                memberIdentifiers,
                &member,
                error)) {
            return NO;
        }
        [members addObject:member];
    }
    IDUIKitRuntimeCapabilityContract *contract =
        [IDUIKitRuntimeCapabilityContract new];
    contract.identifier = identifier;
    contract.capability = capability;
    contract.mandatory = [dictionary[@"mandatory"] boolValue];
    contract.members = members.copy;
    contract.dependencies = dependencies;
    contract.fallback = dictionary[@"fallback"];
    *result = contract;
    return YES;
}

static BOOL IDUIKitParseCapabilityDictionary(
    id value,
    BOOL referenceOnly,
    NSMutableSet<NSString *> *memberIdentifiers,
    NSDictionary<NSString *, IDUIKitRuntimeCapabilityContract *> **result,
    NSError **error) {
    if (![value isKindOfClass:NSDictionary.class]) {
        return IDUIKitSetError(
            error,
            referenceOnly
                ? @"referenceOnly must be an object"
                : @"capabilities must be an object");
    }
    NSMutableDictionary *contracts = [NSMutableDictionary dictionary];
    NSArray<NSString *> *identifiers =
        [[(NSDictionary *)value allKeys]
            sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *identifier in identifiers) {
        if (!IDUIKitIsNonemptyString(identifier)) {
            return IDUIKitSetError(
                error,
                @"Capability identifiers must be nonempty strings");
        }
        NSNumber *capabilityNumber =
            IDUIKitCapabilityNames()[identifier];
        if (!referenceOnly && capabilityNumber == nil) {
            return IDUIKitSetError(
                error,
                [NSString stringWithFormat:
                    @"Unknown capability %@",
                    identifier]);
        }
        IDUIKitRuntimeCapabilityContract *contract = nil;
        if (!IDUIKitParseCapability(
                identifier,
                [(NSDictionary *)value objectForKey:identifier],
                referenceOnly
                    ? 0
                    : capabilityNumber.unsignedIntegerValue,
                memberIdentifiers,
                &contract,
                error)) {
            return NO;
        }
        contracts[identifier] = contract;
    }
    *result = contracts.copy;
    return YES;
}

@implementation IDUIKitRuntimeManifest

+ (instancetype)manifestWithData:(NSData *)data
                           error:(NSError **)error {
    if (error != NULL) {
        *error = nil;
    }
    if (![data isKindOfClass:NSData.class]) {
        IDUIKitSetError(error, @"Manifest data is missing");
        return nil;
    }
    NSError *jsonError = nil;
    id root = [NSJSONSerialization JSONObjectWithData:data
                                              options:0
                                                error:&jsonError];
    if (root == nil) {
        if (error != NULL) {
            *error = [NSError
                errorWithDomain:IDUIKitRuntimeContractErrorDomain
                           code:IDUIKitRuntimeContractErrorInvalidJSON
                       userInfo:@{
                NSLocalizedDescriptionKey:
                    jsonError.localizedDescription ?: @"Invalid JSON",
                NSUnderlyingErrorKey: jsonError ?: [NSNull null],
            }];
        }
        return nil;
    }
    NSDictionary *dictionary = root;
    if (!IDUIKitDictionaryHasExactKeys(
            dictionary,
            [NSSet setWithArray:@[
                @"schema",
                @"runtime",
                @"capabilities",
                @"referenceOnly",
                @"forbidden",
            ]],
            @"manifest",
            error)) {
        return nil;
    }
    NSNumber *schema = dictionary[@"schema"];
    if (![schema isKindOfClass:NSNumber.class] ||
        schema.integerValue != 1) {
        IDUIKitSetError(error, @"schema must be integer 1");
        return nil;
    }
    NSDictionary *runtime = dictionary[@"runtime"];
    if (!IDUIKitDictionaryHasExactKeys(
            runtime,
            [NSSet setWithArray:@[@"osVersion", @"osBuild"]],
            @"runtime",
            error)) {
        return nil;
    }
    if (!IDUIKitIsNonemptyString(runtime[@"osVersion"]) ||
        !IDUIKitIsNonemptyString(runtime[@"osBuild"])) {
        IDUIKitSetError(
            error,
            @"runtime.osVersion and runtime.osBuild must be nonempty");
        return nil;
    }
    NSMutableSet<NSString *> *memberIdentifiers =
        [NSMutableSet set];
    NSDictionary *capabilities = nil;
    if (!IDUIKitParseCapabilityDictionary(
            dictionary[@"capabilities"],
            NO,
            memberIdentifiers,
            &capabilities,
            error)) {
        return nil;
    }
    NSDictionary *referenceOnly = nil;
    if (!IDUIKitParseCapabilityDictionary(
            dictionary[@"referenceOnly"],
            YES,
            memberIdentifiers,
            &referenceOnly,
            error)) {
        return nil;
    }
    NSArray<NSString *> *forbidden = nil;
    if (!IDUIKitParseStringArray(
            dictionary[@"forbidden"],
            @"forbidden",
            YES,
            &forbidden,
            error)) {
        return nil;
    }
    NSSet<NSString *> *knownCapabilities =
        [NSSet setWithArray:capabilities.allKeys];
    for (IDUIKitRuntimeCapabilityContract *contract
         in capabilities.allValues) {
        for (NSString *dependency in contract.dependencies) {
            if (![knownCapabilities containsObject:dependency] ||
                [dependency isEqualToString:contract.identifier]) {
                IDUIKitSetError(
                    error,
                    [NSString stringWithFormat:
                        @"Capability %@ has invalid dependency %@",
                        contract.identifier,
                        dependency]);
                return nil;
            }
        }
    }
    IDUIKitRuntimeManifest *manifest = [self new];
    manifest.schemaVersion = schema.integerValue;
    manifest.osVersion = runtime[@"osVersion"];
    manifest.osBuild = runtime[@"osBuild"];
    manifest.capabilities = capabilities;
    manifest.referenceOnly = referenceOnly;
    manifest.forbiddenSymbols = forbidden;
    return manifest;
}

@end

#endif
