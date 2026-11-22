// CARVED from the InputDec behavior kernel by Scripts/carve-host-preflight.sh.
// DO NOT HAND-EDIT — see Vendor/VENDOR.md for the upstream file, commit and date.
#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "TGPrivateRuntimeNames.h"
#import <objc/runtime.h>
#import "TGRichTextInputDecHostPreflight.h"

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

static NSString *IDInteractionTypeEncoding(const char *encoding) {
    return encoding == NULL ? @"<missing>" : [NSString stringWithUTF8String:encoding];
}

static IDInteractionABISpec *IDInteractionABISpecMake(
    NSString *selectorName,
    const char *returnType,
    NSArray<NSString *> *argumentTypes) {
    return [[IDInteractionABISpec alloc] initWithSelectorName:selectorName
                                                  returnType:returnType
                                               argumentTypes:argumentTypes];
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

@implementation TGRichTextInputDecHostPreflight

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

#endif
