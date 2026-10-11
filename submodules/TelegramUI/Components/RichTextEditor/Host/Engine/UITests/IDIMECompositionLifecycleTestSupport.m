#import "IDIMECompositionLifecycleTestSupport.h"
#import "IDHIDEventTestSupport.h"
#import "IDTextInputBatchTestSupport.h"

#import <CoreFoundation/CoreFoundation.h>
#import <math.h>

NSString *const IDIMECompositionStatusErrorDomain =
    @"com.inputdec.tests.ime-composition-status";

typedef NS_ENUM(NSInteger, IDIMECompositionStatusErrorCode) {
    IDIMECompositionStatusErrorInvalidJSON = 1,
    IDIMECompositionStatusErrorInvalidSchema,
    IDIMECompositionStatusErrorInvalidField,
};

static NSError *IDIMECompositionError(
    IDIMECompositionStatusErrorCode code, NSString *description) {
    return [NSError errorWithDomain:IDIMECompositionStatusErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

@interface IDIMECompositionRow ()
@property(nonatomic, readwrite) IDIMELanguage language;
@property(nonatomic, readwrite) IDIMELocation location;
@property(nonatomic, readwrite) IDIMEDecision decision;
@property(nonatomic, copy, readwrite) NSString *identifier;
- (instancetype)initWithLanguage:(IDIMELanguage)language
                        location:(IDIMELocation)location
                        decision:(IDIMEDecision)decision
                      identifier:(NSString *)identifier;
@end

@implementation IDIMECompositionRow

- (instancetype)initWithLanguage:(IDIMELanguage)language
                        location:(IDIMELocation)location
                        decision:(IDIMEDecision)decision
                      identifier:(NSString *)identifier {
    self = [super init];
    if (self == nil) return nil;
    _language = language;
    _location = location;
    _decision = decision;
    _identifier = [identifier copy];
    return self;
}

@end

@interface IDIMECompositionStatus ()
@property(nonatomic, copy, readwrite) NSString *scenario;
@property(nonatomic, copy, readwrite) NSString *language;
@property(nonatomic, copy, readwrite) NSString *location;
@property(nonatomic, copy, readwrite) NSString *decision;
@property(nonatomic, copy, readwrite) NSString *canonical;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *blocks;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *blockIdentifiers;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *anchorIdentities;
@property(nonatomic, readwrite) NSRange selection;
@property(nonatomic, copy, readwrite) NSString *affinity;
@property(nonatomic, readwrite) NSRange markedRange;
@property(nonatomic, copy, readwrite) NSString *markedText;
@property(nonatomic, readwrite) NSRange markedSelection;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *markedAttributeKeys;
@property(nonatomic, copy, readwrite)
    NSArray<NSNumber *> *structuralNewlineLocations;
@property(nonatomic, copy, readwrite) NSArray<NSValue *> *checkingRanges;
@property(nonatomic, copy, readwrite)
    NSArray<NSDictionary<NSString *, id> *> *temporaryRenderingDescriptors;
@property(nonatomic, copy, readwrite)
    NSDictionary<NSString *, id> *candidateDescriptor;
@property(nonatomic, copy, readwrite)
    NSDictionary<NSString *, id> *keyboardState;
@property(nonatomic, copy, readwrite)
    NSDictionary<NSString *, id> *compositionGeometry;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *mutationTrace;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *eventTrace;
@property(nonatomic, copy, readwrite) NSString *coordinateSpaceIdentity;
@property(nonatomic, readwrite) NSUInteger documentRevision;
@property(nonatomic, readwrite) NSUInteger textEpoch;
@property(nonatomic, readwrite) NSUInteger selectionEpoch;
@property(nonatomic, readwrite) NSUInteger checkingEpoch;
@property(nonatomic, readwrite) NSUInteger layoutEpoch;
@property(nonatomic, readwrite, getter=isFirstResponder) BOOL firstResponder;
@end

@implementation IDIMECompositionStatus
@end

@interface IDIMECompositionPhaseSnapshot ()
@property(nonatomic, copy, readwrite) NSString *phase;
@property(nonatomic, strong, readwrite) IDIMECompositionStatus *status;
@property(nonatomic, copy, readwrite) NSString *screenshotName;
@end

@implementation IDIMECompositionPhaseSnapshot
@end

@interface IDIMECompositionRunResult ()
@property(nonatomic, strong, readwrite) IDIMECompositionRow *row;
@property(nonatomic, copy, readwrite)
    NSArray<IDIMECompositionPhaseSnapshot *> *phases;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *decisionActions;
@end

@implementation IDIMECompositionRunResult
@end

NSArray<IDIMECompositionRow *> *IDIMECompositionMatrix(void) {
    static NSArray<IDIMECompositionRow *> *rows;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *languages =
            @[@"japanese-romaji", @"simplified-chinese-pinyin"];
        NSArray<NSString *> *locations =
            @[@"interior", @"before-boundary", @"after-boundary"];
        NSArray<NSString *> *decisions = @[
            @"candidate-commit", @"cancel", @"ordinary-commit",
            @"return-commit-then-undo", @"responder-loss",
        ];
        NSMutableArray<IDIMECompositionRow *> *result =
            [NSMutableArray arrayWithCapacity:24];
        for (NSUInteger language = 0; language < languages.count;
             language += 1) {
            for (NSUInteger location = 0; location < locations.count;
                 location += 1) {
                for (NSUInteger decision = 0; decision < decisions.count;
                     decision += 1) {
                    if (decision == IDIMEDecisionReturnCommitThenUndo &&
                        location == IDIMELocationInterior) {
                        continue;
                    }
                    if (decision == IDIMEDecisionResponderLoss &&
                        location != IDIMELocationBeforeBoundary) {
                        continue;
                    }
                    NSString *identifier = [NSString stringWithFormat:
                        @"%@-%@-%@", languages[language], locations[location],
                        decisions[decision]];
                    [result addObject:[[IDIMECompositionRow alloc]
                        initWithLanguage:(IDIMELanguage)language
                                location:(IDIMELocation)location
                                decision:(IDIMEDecision)decision
                              identifier:identifier]];
                }
            }
        }
        rows = result.copy;
    });
    return rows;
}

NSArray<IDIMECompositionRow *> *
IDIMECompositionRowsMatchingIdentifier(NSString *identifier) {
    if (identifier == nil) return @[];
    NSPredicate *predicate = [NSPredicate predicateWithBlock:
        ^BOOL(IDIMECompositionRow *row, NSDictionary *bindings) {
            (void)bindings;
            return [row.identifier isEqualToString:identifier];
        }];
    return [IDIMECompositionMatrix() filteredArrayUsingPredicate:predicate];
}

static NSString *IDIMEDecisionName(IDIMEDecision decision) {
    switch (decision) {
        case IDIMEDecisionCandidateCommit:
            return @"candidate-commit";
        case IDIMEDecisionCancel:
            return @"cancel";
        case IDIMEDecisionOrdinaryCommit:
            return @"ordinary-commit";
        case IDIMEDecisionReturnCommitThenUndo:
            return @"return-commit-then-undo";
        case IDIMEDecisionResponderLoss:
            return @"responder-loss";
    }
    return @"";
}

static NSDictionary<NSString *, NSNumber *> *IDIMERangeDictionary(
    NSRange range) {
    return @{ @"location": @(range.location), @"length": @(range.length) };
}

static NSArray<NSDictionary<NSString *, NSNumber *> *> *
IDIMERangeDictionaries(NSArray<NSValue *> *ranges) {
    NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *result =
        [NSMutableArray arrayWithCapacity:ranges.count];
    for (NSValue *value in ranges) {
        [result addObject:IDIMERangeDictionary(value.rangeValue)];
    }
    return result.copy;
}

static NSDictionary<NSString *, id> *IDIMECompositionStatusDictionary(
    IDIMECompositionStatus *status) {
    return @{
        @"schema": @1,
        @"scenario": status.scenario,
        @"language": status.language,
        @"location": status.location,
        @"decision": status.decision,
        @"canonical": status.canonical,
        @"blocks": status.blocks,
        @"blockIdentifiers": status.blockIdentifiers,
        @"anchorIdentities": status.anchorIdentities,
        @"selection": IDIMERangeDictionary(status.selection),
        @"affinity": status.affinity,
        @"markedRange": IDIMERangeDictionary(status.markedRange),
        @"markedText": status.markedText,
        @"markedSelection": IDIMERangeDictionary(status.markedSelection),
        @"markedAttributeKeys": status.markedAttributeKeys,
        @"structuralNewlineLocations": status.structuralNewlineLocations,
        @"checkingRanges": IDIMERangeDictionaries(status.checkingRanges),
        @"temporaryRenderingDescriptors":
            status.temporaryRenderingDescriptors,
        @"candidateDescriptor": status.candidateDescriptor,
        @"keyboardState": status.keyboardState,
        @"compositionGeometry": status.compositionGeometry,
        @"mutationTrace": status.mutationTrace,
        @"eventTrace": status.eventTrace,
        @"coordinateSpaceIdentity": status.coordinateSpaceIdentity,
        @"documentRevision": @(status.documentRevision),
        @"textEpoch": @(status.textEpoch),
        @"selectionEpoch": @(status.selectionEpoch),
        @"checkingEpoch": @(status.checkingEpoch),
        @"layoutEpoch": @(status.layoutEpoch),
        @"firstResponder": @(status.isFirstResponder),
    };
}

NSDictionary<NSString *, id> *IDIMECompositionLifecycleDictionary(
    IDIMECompositionRunResult *result, NSString *testMethod) {
    NSMutableArray<NSDictionary<NSString *, id> *> *phases =
        [NSMutableArray arrayWithCapacity:result.phases.count];
    for (IDIMECompositionPhaseSnapshot *phase in result.phases) {
        [phases addObject:@{
            @"phase": phase.phase,
            @"status": IDIMECompositionStatusDictionary(phase.status),
        }];
    }
    return @{
        @"schema": @1,
        @"testMethod": testMethod,
        @"decision": IDIMEDecisionName(result.row.decision),
        @"phases": phases.copy,
    };
}

static BOOL IDIMECompositionIsInteger(id value, NSUInteger *result) {
    if (![value isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) {
        return NO;
    }
    NSDecimal decimal = [value decimalValue];
    if (NSDecimalIsNotANumber(&decimal)) return NO;
    NSDecimal integral = {0};
    NSDecimalRound(&integral, &decimal, 0, NSRoundPlain);
    NSDecimal zero = [@0 decimalValue];
    NSDecimal maximum =
        [[NSNumber numberWithUnsignedInteger:NSUIntegerMax] decimalValue];
    if (NSDecimalCompare(&decimal, &integral) != NSOrderedSame ||
        NSDecimalCompare(&decimal, &zero) == NSOrderedAscending ||
        NSDecimalCompare(&decimal, &maximum) == NSOrderedDescending) {
        return NO;
    }
    if (result != NULL) *result = [value unsignedIntegerValue];
    return YES;
}

static BOOL IDIMECompositionIsBoolean(id value, BOOL *result) {
    if (![value isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) {
        return NO;
    }
    if (result != NULL) *result = [value boolValue];
    return YES;
}

static BOOL IDIMECompositionHasExactKeys(
    id value, NSArray<NSString *> *keys) {
    if (![value isKindOfClass:NSDictionary.class]) return NO;
    return [[NSSet setWithArray:[value allKeys]]
        isEqualToSet:[NSSet setWithArray:keys]];
}

static BOOL IDIMECompositionParseRange(id value, NSRange *result) {
    if (!IDIMECompositionHasExactKeys(value, @[@"location", @"length"])) {
        return NO;
    }
    NSUInteger location = 0;
    NSUInteger length = 0;
    if (!IDIMECompositionIsInteger(value[@"location"], &location) ||
        !IDIMECompositionIsInteger(value[@"length"], &length) ||
        (location == NSNotFound && length != 0) ||
        (location != NSNotFound && length > NSUIntegerMax - location)) {
        return NO;
    }
    if (result != NULL) *result = NSMakeRange(location, length);
    return YES;
}

static BOOL IDIMECompositionStringArray(
    id value, BOOL requireNonemptyStrings) {
    if (![value isKindOfClass:NSArray.class]) return NO;
    for (id item in value) {
        if (![item isKindOfClass:NSString.class] ||
            (requireNonemptyStrings && [item length] == 0)) {
            return NO;
        }
    }
    return YES;
}

static BOOL IDIMECompositionGeometry(id value) {
    if (!IDIMECompositionHasExactKeys(
            value, @[@"x", @"y", @"width", @"height"])) {
        return NO;
    }
    for (NSString *key in @[@"x", @"y", @"width", @"height"]) {
        id number = value[key];
        if (![number isKindOfClass:NSNumber.class] ||
            CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID() ||
            !isfinite([number doubleValue])) {
            return NO;
        }
    }
    return [value[@"width"] doubleValue] >= 0.0 &&
        [value[@"height"] doubleValue] >= 0.0;
}

static BOOL IDIMECompositionCandidateDescriptor(id value) {
    if (!IDIMECompositionHasExactKeys(value, @[
            @"visible", @"actionable", @"labels", @"selectedLabel",
            @"geometry",
        ])) {
        return NO;
    }
    BOOL visible = NO;
    BOOL actionable = NO;
    return IDIMECompositionIsBoolean(value[@"visible"], &visible) &&
        IDIMECompositionIsBoolean(value[@"actionable"], &actionable) &&
        IDIMECompositionStringArray(value[@"labels"], NO) &&
        [value[@"selectedLabel"] isKindOfClass:NSString.class] &&
        IDIMECompositionGeometry(value[@"geometry"]);
}

static BOOL IDIMECompositionKeyboardState(id value) {
    if (!IDIMECompositionHasExactKeys(value, @[
            @"visible", @"primaryLanguage",
            @"enabledInputModeIdentifiers",
        ])) {
        return NO;
    }
    BOOL visible = NO;
    return IDIMECompositionIsBoolean(value[@"visible"], &visible) &&
        [value[@"primaryLanguage"] isKindOfClass:NSString.class] &&
        [value[@"primaryLanguage"] length] > 0 &&
        IDIMECompositionStringArray(
            value[@"enabledInputModeIdentifiers"], YES);
}

static BOOL IDIMECompositionTemporaryDescriptors(
    id value, NSUInteger canonicalLength) {
    if (![value isKindOfClass:NSArray.class]) return NO;
    for (id descriptor in value) {
        if (!IDIMECompositionHasExactKeys(descriptor, @[
                @"range", @"attributeKeys", @"valueDescriptions",
            ])) {
            return NO;
        }
        NSRange range = {0};
        if (!IDIMECompositionParseRange(descriptor[@"range"], &range) ||
            range.location == NSNotFound ||
            NSMaxRange(range) > canonicalLength ||
            !IDIMECompositionStringArray(descriptor[@"attributeKeys"], YES) ||
            !IDIMECompositionStringArray(
                descriptor[@"valueDescriptions"], NO) ||
            [descriptor[@"attributeKeys"] count] !=
                [descriptor[@"valueDescriptions"] count]) {
            return NO;
        }
    }
    return YES;
}

static BOOL IDIMECompositionStringIsOneOf(
    id value, NSArray<NSString *> *allowed) {
    return [value isKindOfClass:NSString.class] &&
        [allowed containsObject:value];
}

IDIMECompositionStatus *IDParseIMECompositionStatus(
    NSString *serializedStatus, NSError **error) {
    if (error != NULL) *error = nil;
    NSData *data = [serializedStatus dataUsingEncoding:NSUTF8StringEncoding];
    id object = data == nil ? nil :
        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray<NSString *> *keys = @[
        @"schema", @"scenario", @"language", @"location", @"decision",
        @"canonical", @"blocks", @"blockIdentifiers", @"anchorIdentities",
        @"selection", @"affinity", @"markedRange", @"markedText",
        @"markedSelection", @"markedAttributeKeys",
        @"structuralNewlineLocations", @"checkingRanges",
        @"temporaryRenderingDescriptors", @"candidateDescriptor",
        @"keyboardState", @"compositionGeometry", @"mutationTrace",
        @"eventTrace", @"coordinateSpaceIdentity", @"documentRevision",
        @"textEpoch", @"selectionEpoch", @"checkingEpoch", @"layoutEpoch",
        @"firstResponder",
    ];
    if (!IDIMECompositionHasExactKeys(object, keys)) {
        if (error != NULL) {
            *error = IDIMECompositionError(
                IDIMECompositionStatusErrorInvalidJSON,
                @"IME composition status must be a complete versioned JSON object");
        }
        return nil;
    }

    NSDictionary<NSString *, id> *payload = object;
    NSUInteger schema = 0;
    if (!IDIMECompositionIsInteger(payload[@"schema"], &schema) ||
        schema != 1) {
        if (error != NULL) {
            *error = IDIMECompositionError(
                IDIMECompositionStatusErrorInvalidSchema,
                @"IME composition status schema must equal 1");
        }
        return nil;
    }

    NSString *canonical = payload[@"canonical"];
    NSArray *blocks = payload[@"blocks"];
    NSArray *safeBlocks =
        [blocks isKindOfClass:NSArray.class] ? blocks : @[];
    NSArray *blockIdentifiers =
        [payload[@"blockIdentifiers"] isKindOfClass:NSArray.class]
            ? payload[@"blockIdentifiers"] : @[];
    NSUInteger canonicalLength =
        [canonical isKindOfClass:NSString.class] ? [canonical length] : 0;
    NSRange selection = {0};
    NSRange markedRange = {0};
    NSRange markedSelection = {0};
    BOOL firstResponder = NO;
    BOOL valid =
        [payload[@"scenario"] isKindOfClass:NSString.class] &&
        [payload[@"scenario"] length] > 0 &&
        IDIMECompositionStringIsOneOf(payload[@"language"], @[
            @"japanese-romaji", @"simplified-chinese-pinyin",
        ]) &&
        IDIMECompositionStringIsOneOf(payload[@"location"], @[
            @"interior", @"before-boundary", @"after-boundary",
        ]) &&
        IDIMECompositionStringIsOneOf(payload[@"decision"], @[
            @"candidate-commit", @"cancel", @"ordinary-commit",
            @"return-commit-then-undo", @"responder-loss",
        ]) &&
        [canonical isKindOfClass:NSString.class] &&
        IDIMECompositionStringArray(blocks, NO) &&
        [blocks count] > 0 &&
        IDIMECompositionStringArray(payload[@"blockIdentifiers"], YES) &&
        blockIdentifiers.count == safeBlocks.count &&
        IDIMECompositionStringArray(payload[@"anchorIdentities"], YES) &&
        IDIMECompositionParseRange(payload[@"selection"], &selection) &&
        selection.location != NSNotFound &&
        NSMaxRange(selection) <= canonicalLength &&
        IDIMECompositionStringIsOneOf(
            payload[@"affinity"], @[@"forward", @"backward"]) &&
        IDIMECompositionParseRange(payload[@"markedRange"], &markedRange) &&
        [payload[@"markedText"] isKindOfClass:NSString.class] &&
        IDIMECompositionParseRange(
            payload[@"markedSelection"], &markedSelection) &&
        IDIMECompositionStringArray(payload[@"markedAttributeKeys"], YES) &&
        [payload[@"structuralNewlineLocations"]
            isKindOfClass:NSArray.class] &&
        [payload[@"checkingRanges"] isKindOfClass:NSArray.class] &&
        IDIMECompositionCandidateDescriptor(
            payload[@"candidateDescriptor"]) &&
        IDIMECompositionKeyboardState(payload[@"keyboardState"]) &&
        IDIMECompositionGeometry(payload[@"compositionGeometry"]) &&
        IDIMECompositionStringArray(payload[@"mutationTrace"], NO) &&
        IDIMECompositionStringArray(payload[@"eventTrace"], NO) &&
        [payload[@"coordinateSpaceIdentity"] isKindOfClass:NSString.class] &&
        [payload[@"coordinateSpaceIdentity"] length] > 0 &&
        IDIMECompositionIsBoolean(
            payload[@"firstResponder"], &firstResponder);

    NSString *joined = [blocks isKindOfClass:NSArray.class]
        ? [safeBlocks componentsJoinedByString:@"\n"] : nil;
    valid = valid && [joined isEqualToString:canonical];

    NSArray *newlinePayload =
        [payload[@"structuralNewlineLocations"] isKindOfClass:NSArray.class]
            ? payload[@"structuralNewlineLocations"] : @[];
    NSMutableArray<NSNumber *> *newlines = [NSMutableArray array];
    NSUInteger expectedNewline = 0;
    for (NSUInteger index = 0; index < safeBlocks.count; index += 1) {
        id block = safeBlocks[index];
        if (![block isKindOfClass:NSString.class]) {
            valid = NO;
            break;
        }
        expectedNewline += [block length];
        if (index + 1 < safeBlocks.count) {
            [newlines addObject:@(expectedNewline)];
            expectedNewline += 1;
        }
    }
    if (![newlinePayload isEqualToArray:newlines]) valid = NO;

    NSArray *checkingPayload =
        [payload[@"checkingRanges"] isKindOfClass:NSArray.class]
            ? payload[@"checkingRanges"] : @[];
    NSMutableArray<NSValue *> *checkingRanges = [NSMutableArray array];
    for (id item in checkingPayload) {
        NSRange range = {0};
        if (!IDIMECompositionParseRange(item, &range) ||
            range.location == NSNotFound ||
            NSMaxRange(range) > canonicalLength) {
            valid = NO;
        } else {
            [checkingRanges addObject:[NSValue valueWithRange:range]];
        }
    }

    valid = valid && IDIMECompositionTemporaryDescriptors(
        payload[@"temporaryRenderingDescriptors"], canonicalLength);

    NSString *markedText = payload[@"markedText"];
    if (markedRange.location == NSNotFound) {
        valid = valid && markedRange.length == 0 &&
            [markedText isEqualToString:@""] &&
            markedSelection.location == NSNotFound &&
            markedSelection.length == 0;
    } else {
        valid = valid && NSMaxRange(markedRange) <= canonicalLength &&
            markedSelection.location != NSNotFound &&
            NSMaxRange(markedSelection) <= markedRange.length;
        if (valid) {
            valid = [[canonical substringWithRange:markedRange]
                isEqualToString:markedText];
        }
    }

    NSUInteger documentRevision = 0;
    NSUInteger textEpoch = 0;
    NSUInteger selectionEpoch = 0;
    NSUInteger checkingEpoch = 0;
    NSUInteger layoutEpoch = 0;
    valid = valid &&
        IDIMECompositionIsInteger(
            payload[@"documentRevision"], &documentRevision) &&
        IDIMECompositionIsInteger(payload[@"textEpoch"], &textEpoch) &&
        IDIMECompositionIsInteger(
            payload[@"selectionEpoch"], &selectionEpoch) &&
        IDIMECompositionIsInteger(
            payload[@"checkingEpoch"], &checkingEpoch) &&
        IDIMECompositionIsInteger(payload[@"layoutEpoch"], &layoutEpoch);

    NSSet *blockIdentifierSet = [NSSet setWithArray:blockIdentifiers];
    valid = valid &&
        blockIdentifierSet.count == blockIdentifiers.count;
    if (!valid) {
        if (error != NULL) {
            *error = IDIMECompositionError(
                IDIMECompositionStatusErrorInvalidField,
                @"IME composition status contains an invalid field");
        }
        return nil;
    }

    IDIMECompositionStatus *status = [IDIMECompositionStatus new];
    status.scenario = payload[@"scenario"];
    status.language = payload[@"language"];
    status.location = payload[@"location"];
    status.decision = payload[@"decision"];
    status.canonical = canonical;
    status.blocks = blocks;
    status.blockIdentifiers = payload[@"blockIdentifiers"];
    status.anchorIdentities = payload[@"anchorIdentities"];
    status.selection = selection;
    status.affinity = payload[@"affinity"];
    status.markedRange = markedRange;
    status.markedText = markedText;
    status.markedSelection = markedSelection;
    status.markedAttributeKeys = payload[@"markedAttributeKeys"];
    status.structuralNewlineLocations = newlines.copy;
    status.checkingRanges = checkingRanges.copy;
    status.temporaryRenderingDescriptors =
        payload[@"temporaryRenderingDescriptors"];
    status.candidateDescriptor = payload[@"candidateDescriptor"];
    status.keyboardState = payload[@"keyboardState"];
    status.compositionGeometry = payload[@"compositionGeometry"];
    status.mutationTrace = payload[@"mutationTrace"];
    status.eventTrace = payload[@"eventTrace"];
    status.coordinateSpaceIdentity = payload[@"coordinateSpaceIdentity"];
    status.documentRevision = documentRevision;
    status.textEpoch = textEpoch;
    status.selectionEpoch = selectionEpoch;
    status.checkingEpoch = checkingEpoch;
    status.layoutEpoch = layoutEpoch;
    status.firstResponder = firstResponder;
    return status;
}

static NSArray<NSString *> *IDIMELocationNames(void) {
    return @[@"interior", @"before-boundary", @"after-boundary"];
}

static NSArray<NSString *> *IDIMEDecisionNames(void) {
    return @[
        @"candidate-commit", @"cancel", @"ordinary-commit",
        @"return-commit-then-undo", @"responder-loss",
    ];
}

static NSString *IDIMELanguageName(IDIMELanguage language) {
    return language == IDIMELanguageJapaneseRomaji
        ? @"japanese-romaji" : @"simplified-chinese-pinyin";
}

static NSArray<NSString *> *IDIMEPhysicalKeys(IDIMELanguage language) {
    return language == IDIMELanguageJapaneseRomaji
        ? @[@"k", @"a", @"n", @"a"]
        : @[@"n", @"i", @"h", @"a", @"o"];
}

static NSDictionary<NSString *, id> *IDIMEStockFixture(
    IDIMELanguage language) {
    NSString *name = language == IDIMELanguageJapaneseRomaji
        ? @"ime-japanese-romaji-stock-contract-v1"
        : @"ime-simplified-chinese-pinyin-stock-contract-v1";
    NSBundle *bundle =
        [NSBundle bundleForClass:IDIMECompositionRunResult.class];
    NSURL *url = [bundle URLForResource:name withExtension:@"json"];
    NSData *data = url == nil ? nil :
        [NSData dataWithContentsOfURL:url];
    id fixture = data == nil ? nil :
        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [fixture isKindOfClass:NSDictionary.class] ? fixture : nil;
}

static BOOL IDIMEWaitForKeyboardKey(
    XCUIApplication *application, NSString *key, NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        XCUIElement *element =
            [application.keyboards.keys matchingIdentifier:key].firstMatch;
        if (element.exists && element.isHittable) return YES;
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    return NO;
}

XCUIApplication *IDLaunchStockIMECompositionScenario(
    IDIMECompositionRow *row) {
    NSArray<NSString *> *physicalKeys = IDIMEPhysicalKeys(row.language);
    XCUIApplication *application = [[XCUIApplication alloc]
        initWithBundleIdentifier:@"com.inputdec.stockoracle"];
    [application terminate];
    application.launchArguments = @[
        @"-AppleLanguages", @"(ja)", @"-AppleLocale", @"ja_JP",
    ];
    application.launchEnvironment = @{
        @"IDStockEditorFrame":
            NSStringFromCGRect(CGRectMake(16, 198, 370, 360)),
        @"IDStockTouchScenario":
            [@"ime-" stringByAppendingString:row.identifier],
        @"IDIMELanguage": IDIMELanguageName(row.language),
        @"IDIMELocation":
            IDIMELocationNames()[(NSUInteger)row.location],
        @"IDIMEDecision":
            IDIMEDecisionNames()[(NSUInteger)row.decision],
        @"IDIMEDiscoverySequence":
            [physicalKeys componentsJoinedByString:@","],
    };
    [application launch];
    if (!IDIMEWaitForKeyboardKey(application, physicalKeys.firstObject, 6.0)) {
        [application terminate];
        [application launch];
        (void)IDIMEWaitForKeyboardKey(
            application, physicalKeys.firstObject, 6.0);
    }
    return application;
}

XCUIApplication *IDLaunchCustomIMECompositionScenario(
    IDIMECompositionRow *row) {
    NSArray<NSString *> *physicalKeys = IDIMEPhysicalKeys(row.language);
    XCUIApplication *application = [[XCUIApplication alloc]
        initWithBundleIdentifier:@"com.inputdec.demo"];
    [application terminate];
    application.launchArguments = @[
        @"-AppleLanguages", @"(ja)", @"-AppleLocale", @"ja_JP",
        @"--id-block-ui-scenario",
        [@"ime-" stringByAppendingString:row.identifier],
    ];
    application.launchEnvironment = @{
        @"IDIMELanguage": IDIMELanguageName(row.language),
        @"IDIMELocation":
            IDIMELocationNames()[(NSUInteger)row.location],
        @"IDIMEDecision":
            IDIMEDecisionNames()[(NSUInteger)row.decision],
        @"IDIMEDiscoverySequence":
            [physicalKeys componentsJoinedByString:@","],
    };
    [application launch];
    if (!IDIMEWaitForKeyboardKey(application, physicalKeys.firstObject, 6.0)) {
        [application terminate];
        [application launch];
        (void)IDIMEWaitForKeyboardKey(
            application, physicalKeys.firstObject, 6.0);
    }
    return application;
}

static XCUIElement *IDIMECandidateElement(
    XCUIApplication *application, NSString *markedText,
    NSMutableArray<NSString *> *labels) {
    if (markedText.length == 0) return nil;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:
        @"label == %@ OR value == %@ OR identifier == %@",
        markedText, markedText, markedText];
    XCUIElementQuery *matches =
        [[application descendantsMatchingType:XCUIElementTypeCell]
            matchingPredicate:predicate];
    XCUIElement *selected = nil;
    NSMutableOrderedSet<NSString *> *uniqueLabels =
        [NSMutableOrderedSet orderedSet];
    for (NSUInteger index = 0; index < matches.count; index += 1) {
        XCUIElement *element = [matches elementBoundByIndex:index];
        if (!element.exists) continue;
        NSString *label = element.label.length > 0 ? element.label :
            ([element.value isKindOfClass:NSString.class]
                ? element.value : element.identifier);
        if (label.length > 0) [uniqueLabels addObject:label];
        CGRect frame = element.frame;
        BOOL finiteFrame = !CGRectIsNull(frame) && !CGRectIsInfinite(frame) &&
            isfinite(frame.origin.x) && isfinite(frame.origin.y) &&
            isfinite(frame.size.width) && isfinite(frame.size.height);
        if (selected == nil && element.isHittable && finiteFrame &&
            frame.size.width > 0.0 && frame.size.height > 0.0) {
            selected = element;
        }
    }
    if (selected == nil) {
        CGRect keyboardFrame = application.keyboards.firstMatch.frame;
        XCUIElementQuery *cells =
            [application descendantsMatchingType:XCUIElementTypeCell];
        for (NSUInteger index = 0; index < cells.count; index += 1) {
            XCUIElement *element = [cells elementBoundByIndex:index];
            if (!element.exists) continue;
            CGRect frame = element.frame;
            BOOL finiteFrame =
                !CGRectIsNull(frame) && !CGRectIsInfinite(frame) &&
                isfinite(frame.origin.x) && isfinite(frame.origin.y) &&
                isfinite(frame.size.width) && isfinite(frame.size.height);
            if (!finiteFrame || frame.size.width <= 0.0 ||
                frame.size.height <= 0.0) {
                continue;
            }
            CGFloat keyboardTop = CGRectGetMinY(keyboardFrame);
            BOOL inCandidateStrip =
                CGRectIntersectsRect(frame, keyboardFrame) ||
                (fabs(CGRectGetMaxY(frame) - keyboardTop) <= 2.0 &&
                 CGRectGetMinY(frame) < keyboardTop);
            if (!inCandidateStrip) {
                continue;
            }
            NSString *label = element.label.length > 0 ? element.label :
                ([element.value isKindOfClass:NSString.class]
                    ? element.value : element.identifier);
            if (label.length > 0) [uniqueLabels addObject:label];
            if (element.isHittable) {
                selected = element;
                break;
            }
        }
    }
    [labels addObjectsFromArray:uniqueLabels.array];
    return selected;
}

static NSDictionary<NSString *, NSNumber *> *IDIMEGeometryForElement(
    XCUIElement *element) {
    CGRect frame = element == nil ? CGRectZero : element.frame;
    if (CGRectIsNull(frame) || CGRectIsInfinite(frame) ||
        !isfinite(frame.origin.x) || !isfinite(frame.origin.y) ||
        !isfinite(frame.size.width) || !isfinite(frame.size.height)) {
        frame = CGRectZero;
    }
    return @{
        @"x": @(frame.origin.x), @"y": @(frame.origin.y),
        @"width": @(MAX(frame.size.width, 0.0)),
        @"height": @(MAX(frame.size.height, 0.0)),
    };
}

static IDIMECompositionStatus *IDIMECurrentStatus(
    XCUIApplication *application) {
    XCUIElement *statusElement =
        [application descendantsMatchingType:XCUIElementTypeAny]
            [@"ime-composition-status"];
    NSString *serialized =
        [statusElement.value isKindOfClass:NSString.class]
            ? statusElement.value : @"{}";
    NSData *data = [serialized dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary<NSString *, id> *payload = data == nil ? nil :
        [[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]
            mutableCopy];
    NSString *markedText =
        [payload[@"markedText"] isKindOfClass:NSString.class]
            ? payload[@"markedText"] : @"";
    NSMutableArray<NSString *> *labels = [NSMutableArray array];
    XCUIElement *candidate =
        IDIMECandidateElement(application, markedText, labels);
    if (payload != nil) {
        NSString *selectedLabel = labels.firstObject ?: @"";
        payload[@"candidateDescriptor"] = @{
            @"visible": @((BOOL)(labels.count > 0)),
            @"actionable": @((BOOL)(candidate != nil)),
            @"labels": labels.copy,
            @"selectedLabel": selectedLabel ?: @"",
            @"geometry": IDIMEGeometryForElement(candidate),
        };
        NSData *augmented = [NSJSONSerialization
            dataWithJSONObject:payload
                       options:NSJSONWritingSortedKeys
                         error:nil];
        serialized = augmented == nil ? @"{}" :
            [[NSString alloc] initWithData:augmented
                                 encoding:NSUTF8StringEncoding];
    }
    return IDParseIMECompositionStatus(serialized, NULL);
}

static void IDIMEAttachHierarchy(
    XCTestCase *testCase, XCUIApplication *application, NSString *name) {
    XCTAttachment *attachment = [XCTAttachment attachmentWithString:
        application.debugDescription ?: @"unavailable"];
    attachment.name = IDTextInputBatchAttachmentName(name);
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [testCase addAttachment:attachment];
}

static IDIMECompositionPhaseSnapshot *IDIMECapturePhase(
    XCTestCase *testCase, XCUIApplication *application, NSString *phase) {
    XCUIElement *statusElement =
        [application descendantsMatchingType:XCUIElementTypeAny]
            [@"ime-composition-status"];
    if (!statusElement.exists &&
        ![statusElement waitForExistenceWithTimeout:4.0]) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:@"IME composition status element is absent"]];
    }
    NSString *serialized =
        [statusElement.value isKindOfClass:NSString.class]
            ? statusElement.value : @"{}";
    NSData *data = [serialized dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary<NSString *, id> *payload = data == nil ? nil :
        [[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]
            mutableCopy];
    NSString *markedText =
        [payload[@"markedText"] isKindOfClass:NSString.class]
            ? payload[@"markedText"] : @"";
    NSMutableArray<NSString *> *labels = [NSMutableArray array];
    XCUIElement *candidate =
        IDIMECandidateElement(application, markedText, labels);
    if (payload != nil) {
        NSString *selectedLabel = labels.firstObject ?: @"";
        payload[@"candidateDescriptor"] = @{
            @"visible": @((BOOL)(labels.count > 0)),
            @"actionable": @((BOOL)(candidate != nil)),
            @"labels": labels.copy,
            @"selectedLabel": selectedLabel ?: @"",
            @"geometry": IDIMEGeometryForElement(candidate),
        };
        NSData *augmented = [NSJSONSerialization
            dataWithJSONObject:payload
                       options:NSJSONWritingSortedKeys
                         error:nil];
        serialized = augmented == nil ? @"{}" :
            [[NSString alloc] initWithData:augmented
                                 encoding:NSUTF8StringEncoding];
    }
    NSError *parseError = nil;
    IDIMECompositionStatus *status =
        IDParseIMECompositionStatus(serialized, &parseError);
    NSLog(@"ID_IME_COMPOSITION_STATUS phase=%@ payload=%@",
          phase, serialized);
    if (status == nil) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:[NSString stringWithFormat:
                @"Invalid IME composition status for %@: %@ raw=%@",
                phase, parseError.localizedDescription, serialized]]];
    }

    NSString *screenshotName =
        [NSString stringWithFormat:@"ime-composition-%@", phase];
    XCTAttachment *screenshot =
        [XCTAttachment attachmentWithScreenshot:
            XCUIScreen.mainScreen.screenshot];
    screenshot.name = IDTextInputBatchAttachmentName(screenshotName);
    screenshot.lifetime = XCTAttachmentLifetimeKeepAlways;
    [testCase addAttachment:screenshot];
    XCTAttachment *statusAttachment =
        [XCTAttachment attachmentWithString:serialized];
    statusAttachment.name = IDTextInputBatchAttachmentName(
        [NSString stringWithFormat:@"ime-composition-%@-status", phase]);
    statusAttachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [testCase addAttachment:statusAttachment];
    IDIMEAttachHierarchy(testCase, application,
        [NSString stringWithFormat:@"ime-composition-%@-hierarchy", phase]);

    IDIMECompositionPhaseSnapshot *snapshot =
        [IDIMECompositionPhaseSnapshot new];
    snapshot.phase = phase;
    snapshot.status = status;
    snapshot.screenshotName = screenshotName;
    return snapshot;
}

static BOOL IDIMEWaitForMarkedText(
    XCUIApplication *application, NSString *differentFrom,
    NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        IDIMECompositionStatus *status = IDIMECurrentStatus(application);
        if (status.markedRange.location != NSNotFound &&
            status.markedText.length > 0 &&
            (differentFrom == nil ||
             ![status.markedText isEqualToString:differentFrom])) {
            return YES;
        }
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    return NO;
}

static BOOL IDIMEWaitForCandidate(
    XCUIApplication *application, NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        IDIMECompositionStatus *status = IDIMECurrentStatus(application);
        if ([status.candidateDescriptor[@"visible"] boolValue] &&
            [status.candidateDescriptor[@"actionable"] boolValue]) {
            return YES;
        }
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    return NO;
}

static BOOL IDIMEWaitForTerminalMarkedState(
    XCUIApplication *application, NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        IDIMECompositionStatus *status = IDIMECurrentStatus(application);
        if (status.markedRange.location == NSNotFound &&
            status.markedText.length == 0) {
            return YES;
        }
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    return NO;
}

static BOOL IDIMEWaitForFirstResponderState(
    XCUIApplication *application, BOOL expected, NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        IDIMECompositionStatus *status = IDIMECurrentStatus(application);
        if (status.isFirstResponder == expected) return YES;
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    return NO;
}

static BOOL IDIMEWaitForCanonical(
    XCUIApplication *application, NSString *expected,
    NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        IDIMECompositionStatus *status = IDIMECurrentStatus(application);
        if ([status.canonical isEqualToString:expected]) return YES;
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    return NO;
}

static BOOL IDIMEActivateLanguage(
    XCTestCase *testCase, XCUIApplication *application,
    IDIMELanguage language) {
    NSString *expectedPrimaryLanguage =
        language == IDIMELanguageJapaneseRomaji ? @"ja-JP" : @"zh-Hans";
    IDIMECompositionStatus *initial = IDIMECurrentStatus(application);
    if ([initial.keyboardState[@"primaryLanguage"]
            isEqual:expectedPrimaryLanguage]) {
        return YES;
    }

    XCUIElement *nextKeyboard = [[application
        descendantsMatchingType:XCUIElementTypeButton]
        matchingIdentifier:@"Next keyboard"].firstMatch;
    if (!nextKeyboard.exists || !nextKeyboard.isHittable) {
        IDIMEAttachHierarchy(
            testCase, application,
            @"ime-composition-next-keyboard-unavailable-hierarchy");
        return NO;
    }
    [nextKeyboard pressForDuration:1.0];

    NSString *menuLabel = language == IDIMELanguageJapaneseRomaji
        ? @"日本語ローマ字" : @"简体拼音";
    NSPredicate *predicate =
        [NSPredicate predicateWithFormat:@"label == %@", menuLabel];
    XCUIElementQuery *matches =
        [[application descendantsMatchingType:XCUIElementTypeCell]
            matchingPredicate:predicate];
    XCUIElement *mode = matches.firstMatch;
    NSPredicate *hittable = [NSPredicate predicateWithBlock:
        ^BOOL(XCUIElement *element, NSDictionary *bindings) {
            (void)bindings;
            return element.exists && element.isHittable;
        }];
    XCTNSPredicateExpectation *expectation =
        [[XCTNSPredicateExpectation alloc] initWithPredicate:hittable
                                                     object:mode];
    XCTWaiterResult waiterResult =
        [XCTWaiter waitForExpectations:@[expectation] timeout:3.0];
    (void)waiterResult;
    if (matches.count != 1 || !mode.isHittable) {
        IDIMEAttachHierarchy(
            testCase, application,
            @"ime-composition-input-mode-selection-failed-hierarchy");
        return NO;
    }
    [mode tap];

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:4.0];
    do {
        IDIMECompositionStatus *status =
            IDIMECurrentStatus(application);
        if ([status.keyboardState[@"primaryLanguage"]
                isEqual:expectedPrimaryLanguage]) {
            return YES;
        }
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    IDIMEAttachHierarchy(
        testCase, application,
        @"ime-composition-active-language-timeout-hierarchy");
    return NO;
}

IDIMECompositionRunResult *IDRunIMECompositionLifecycle(
    XCTestCase *testCase, XCUIApplication *application,
    IDIMECompositionRow *row) {
    XCUIElementQuery *elements =
        [application descendantsMatchingType:XCUIElementTypeAny];
    XCUIElement *editor = elements[@"stock-text-view"];
    if (!editor.exists) {
        editor = elements[@"block-text-view"];
    }
    XCUIElement *statusElement = elements[@"ime-composition-status"];
    if (![editor waitForExistenceWithTimeout:4.0] ||
        ![statusElement waitForExistenceWithTimeout:4.0]) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:@"IME composition host did not launch"]];
    }
    if (!IDIMEActivateLanguage(testCase, application, row.language)) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:
                @"Could not activate the requested IME from the named system menu"]];
    }

    NSMutableArray<IDIMECompositionPhaseSnapshot *> *phases =
        [NSMutableArray array];
    NSMutableArray<NSString *> *decisionActions = [NSMutableArray array];
    BOOL capturedQuiesced = NO;
    IDIMECompositionPhaseSnapshot *baseline =
        IDIMECapturePhase(testCase, application, @"baseline");
    [phases addObject:baseline];
    NSString *expectedLanguage =
        row.language == IDIMELanguageJapaneseRomaji ? @"ja-JP" : @"zh-Hans";
    if (![baseline.status.keyboardState[@"primaryLanguage"]
            isEqual:expectedLanguage]) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:[NSString stringWithFormat:
                @"Wrong active IME language: expected %@, observed %@",
                expectedLanguage,
                baseline.status.keyboardState[@"primaryLanguage"] ?: @""]]];
    }

    NSArray<NSString *> *keys = IDIMEPhysicalKeys(row.language);
    NSDictionary<NSString *, id> *fixture =
        IDIMEStockFixture(row.language);
    if (fixture == nil) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:@"Frozen IME stock fixture is absent"]];
    } else if (![fixture[@"physicalKeySequence"]
                    isEqualToArray:keys]) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:
                @"IME physical key corpus differs from frozen stock truth"]];
    }
    IDHIDTapSoftwareKeyboardKey(testCase, application, keys[0]);
    if (!IDIMEWaitForMarkedText(application, nil, 4.0)) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:@"IME did not publish first marked text"]];
    }
    IDIMECompositionPhaseSnapshot *first =
        IDIMECapturePhase(testCase, application, @"firstComposition");
    [phases addObject:first];

    IDHIDTapSoftwareKeyboardKey(testCase, application, keys[1]);
    if (!IDIMEWaitForMarkedText(
            application, first.status.markedText, 4.0)) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:@"IME did not update marked text"]];
    }
    [phases addObject:IDIMECapturePhase(
        testCase, application, @"updatedComposition")];

    for (NSUInteger index = 2; index < keys.count; index += 1) {
        IDHIDTapSoftwareKeyboardKey(testCase, application, keys[index]);
    }
    BOOL candidateReady = IDIMEWaitForCandidate(application, 6.0);
    if (row.decision == IDIMEDecisionCandidateCommit) {
        IDIMECompositionPhaseSnapshot *candidate =
            IDIMECapturePhase(testCase, application, @"candidateVisible");
        [phases addObject:candidate];
        if (!candidateReady) {
            [testCase recordIssue:[[XCTIssue alloc]
                initWithType:XCTIssueTypeAssertionFailure
                compactDescription:
                    @"IME did not expose an actionable native candidate"]];
        } else {
            NSString *candidateLabel = fixture[@"candidateLabel"];
            NSString *candidateIdentity =
                fixture[@"candidateAccessibilityIdentity"];
            NSPredicate *predicate = [NSPredicate predicateWithFormat:
                @"identifier == %@ AND label == %@",
                candidateLabel, candidateIdentity];
            XCUIElement *candidateElement =
                [[[application
                    descendantsMatchingType:XCUIElementTypeCell]
                    matchingPredicate:predicate] firstMatch];
            BOOL exactCandidate =
                candidateElement.exists && candidateElement.isHittable &&
                [candidate.status.candidateDescriptor[@"selectedLabel"]
                    isEqual:candidateIdentity] &&
                [candidate.status.candidateDescriptor[@"labels"]
                    containsObject:candidateIdentity];
            if (!exactCandidate) {
                [testCase recordIssue:[[XCTIssue alloc]
                    initWithType:XCTIssueTypeAssertionFailure
                    compactDescription:
                        @"Frozen native candidate label and accessibility "
                         "identity are not both present and actionable"]];
            }
            [decisionActions addObject:[@"candidate:"
                stringByAppendingString:candidateIdentity ?: @""]];
            if (exactCandidate) [candidateElement tap];
            if (!IDIMEWaitForTerminalMarkedState(application, 4.0)) {
                [testCase recordIssue:[[XCTIssue alloc]
                    initWithType:XCTIssueTypeAssertionFailure
                    compactDescription:
                        @"Native candidate did not commit marked text"]];
            }
        }
        [phases addObject:IDIMECapturePhase(
            testCase, application, @"decision")];
        [phases addObject:IDIMECapturePhase(
            testCase, application, @"immediate")];
    } else if (row.decision == IDIMEDecisionCancel) {
        NSString *serializedActions =
            fixture[@"cancelAction"][@"value"];
        NSArray<NSString *> *cancelActions =
            [serializedActions componentsSeparatedByString:@","];
        for (NSString *action in cancelActions) {
            IDHIDTapSoftwareKeyboardKey(
                testCase, application, action);
            [decisionActions addObject:action];
        }
        if (!IDIMEWaitForTerminalMarkedState(application, 4.0)) {
            [testCase recordIssue:[[XCTIssue alloc]
                initWithType:XCTIssueTypeAssertionFailure
                compactDescription:
                    @"IME delete sequence did not cancel marked text"]];
        }
        [phases addObject:IDIMECapturePhase(
            testCase, application, @"decision")];
        [phases addObject:IDIMECapturePhase(
            testCase, application, @"immediate")];
    } else if (row.decision == IDIMEDecisionOrdinaryCommit) {
        IDHIDTapSoftwareKeyboardKey(testCase, application, @"return");
        [decisionActions addObject:@"return"];
        if (!IDIMEWaitForTerminalMarkedState(application, 4.0)) {
            [testCase recordIssue:[[XCTIssue alloc]
                initWithType:XCTIssueTypeAssertionFailure
                compactDescription:
                    @"IME Return action did not terminate marked text"]];
        }
        [phases addObject:IDIMECapturePhase(
            testCase, application, @"decision")];
        [phases addObject:IDIMECapturePhase(
            testCase, application, @"immediate")];
    } else if (row.decision == IDIMEDecisionReturnCommitThenUndo) {
        IDHIDTapSoftwareKeyboardKey(testCase, application, @"return");
        [decisionActions addObject:@"return"];
        if (!IDIMEWaitForTerminalMarkedState(application, 4.0)) {
            [testCase recordIssue:[[XCTIssue alloc]
                initWithType:XCTIssueTypeAssertionFailure
                compactDescription:
                    @"IME Return action did not commit marked text"]];
        }
        [phases addObject:IDIMECapturePhase(
            testCase, application, @"decision")];
        [phases addObject:IDIMECapturePhase(
            testCase, application, @"immediate")];
        [NSThread sleepForTimeInterval:0.50];
        [phases addObject:IDIMECapturePhase(
            testCase, application, @"quiesced")];
        capturedQuiesced = YES;
        XCUIElement *undo = application.buttons[@"ime-undo"];
        if ([undo waitForExistenceWithTimeout:2.0] && undo.isHittable) {
            [undo tap];
        } else {
            [testCase recordIssue:[[XCTIssue alloc]
                initWithType:XCTIssueTypeAssertionFailure
                compactDescription:
                    @"Stock IME Undo control is absent or not hittable"]];
        }
        [decisionActions addObject:@"undo"];
        (void)IDIMEWaitForCanonical(
            application, baseline.status.canonical, 4.0);
        [phases addObject:IDIMECapturePhase(
            testCase, application, @"undo")];
    } else if (row.decision == IDIMEDecisionResponderLoss) {
        XCUIElement *resign = application.buttons[@"ime-resign"];
        if ([resign waitForExistenceWithTimeout:2.0] &&
            resign.isHittable) {
            [resign tap];
        } else {
            [testCase recordIssue:[[XCTIssue alloc]
                initWithType:XCTIssueTypeAssertionFailure
                compactDescription:
                    @"Stock IME Resign control is absent or not hittable"]];
        }
        [decisionActions addObject:@"resign"];
        [phases addObject:IDIMECapturePhase(
            testCase, application, @"decision")];
        if (!IDIMEWaitForFirstResponderState(application, NO, 4.0)) {
            [testCase recordIssue:[[XCTIssue alloc]
                initWithType:XCTIssueTypeAssertionFailure
                compactDescription:
                    @"IME responder-loss action kept the editor active"]];
        }
        [phases addObject:IDIMECapturePhase(
            testCase, application, @"postInterruption")];
    }
    if (!capturedQuiesced) {
        [NSThread sleepForTimeInterval:0.50];
        [phases addObject:IDIMECapturePhase(
            testCase, application, @"quiesced")];
    }

    IDIMECompositionRunResult *result =
        [IDIMECompositionRunResult new];
    result.row = row;
    result.phases = phases.copy;
    result.decisionActions = decisionActions.copy;
    return result;
}
