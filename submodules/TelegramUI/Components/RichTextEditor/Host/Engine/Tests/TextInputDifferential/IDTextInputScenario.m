#import "IDTextInputScenario.h"

#import <CoreFoundation/CoreFoundation.h>
#import <math.h>

NSString *const IDTextInputScenarioErrorDomain =
    @"com.inputdec.tests.text-input-scenario";

typedef NS_ENUM(NSInteger, IDTextInputScenarioErrorCode) {
    IDTextInputScenarioErrorInvalidJSON = 1,
    IDTextInputScenarioErrorInvalidSchema = 2,
};

@interface IDTextInputTransaction ()

@property(nonatomic, readwrite) IDTextInputTransactionKind kind;
@property(nonatomic, copy, readwrite, nullable) NSString *text;
@property(nonatomic, copy, readwrite, nullable) NSValue *rangeValue;
@property(nonatomic, copy, readwrite, nullable) NSValue *selectedRangeValue;
@property(nonatomic, copy, readwrite)
    NSDictionary<NSString *, id> *traits;
@property(nonatomic, copy, readwrite, nullable) NSString *trait;
@property(nonatomic, copy, readwrite, nullable) NSString *phase;

@end

@implementation IDTextInputTransaction
@end

@interface IDTextInputScenario ()

@property(nonatomic, readwrite) NSInteger schemaVersion;
@property(nonatomic, readwrite) IDTextInputScenarioFamily family;
@property(nonatomic, copy, readwrite) NSString *identifier;
@property(nonatomic, copy, readwrite) NSString *initialText;
@property(nonatomic, readwrite) NSRange initialSelection;
@property(nonatomic, copy, readwrite)
    NSDictionary<NSString *, id> *initialTraits;
@property(nonatomic, copy, readwrite)
    NSArray<IDTextInputTransaction *> *transactions;
@property(nonatomic, copy, readwrite)
    NSArray<NSString *> *comparisonFields;
@property(nonatomic, readwrite) CGFloat geometryTolerance;
@property(nonatomic, copy, readwrite)
    NSDictionary<NSString *, id> *provenance;

@end

@implementation IDTextInputScenario
@end

static NSError *IDTextInputScenarioError(NSString *description) {
    return [NSError errorWithDomain:IDTextInputScenarioErrorDomain
                               code:IDTextInputScenarioErrorInvalidSchema
                           userInfo:@{
        NSLocalizedDescriptionKey: description,
    }];
}

static BOOL IDTextInputExactKeys(
    id value, NSArray<NSString *> *expectedKeys) {
    if (![value isKindOfClass:NSDictionary.class]) return NO;
    NSSet *actual = [NSSet setWithArray:[value allKeys]];
    return [actual isEqualToSet:[NSSet setWithArray:expectedKeys]];
}

static BOOL IDTextInputNonemptyString(id value) {
    return [value isKindOfClass:NSString.class] && [value length] > 0;
}

static BOOL IDTextInputInteger(id value, NSUInteger *result) {
    if (![value isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) {
        return NO;
    }
    double number = [value doubleValue];
    NSUInteger integer = [value unsignedIntegerValue];
    if (!isfinite(number) || number < 0.0 ||
        number != (double)integer) {
        return NO;
    }
    if (result != NULL) *result = integer;
    return YES;
}

static BOOL IDTextInputBoolean(id value) {
    return [value isKindOfClass:NSNumber.class] &&
        CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

static NSValue *IDTextInputRangeValue(
    id value, NSUInteger upperBound, BOOL *valid) {
    *valid = NO;
    if (!IDTextInputExactKeys(value, @[@"location", @"length"])) return nil;
    NSUInteger location = 0;
    NSUInteger length = 0;
    if (!IDTextInputInteger(value[@"location"], &location) ||
        !IDTextInputInteger(value[@"length"], &length) ||
        location > upperBound || length > upperBound - location) {
        return nil;
    }
    *valid = YES;
    return [NSValue valueWithRange:NSMakeRange(location, length)];
}

static NSDictionary<NSString *, NSNumber *> *
IDTextInputParseTraits(id value, BOOL allowEmpty) {
    if (![value isKindOfClass:NSDictionary.class]) return nil;
    NSDictionary *dictionary = value;
    if (!allowEmpty && dictionary.count == 0) return nil;
    NSSet<NSString *> *integerKeys = [NSSet setWithArray:@[
        @"autocapitalizationType", @"autocorrectionType",
        @"spellCheckingType", @"smartQuotesType", @"smartDashesType",
        @"smartInsertDeleteType", @"inlinePredictionType", @"keyboardType",
        @"returnKeyType",
    ]];
    NSSet<NSString *> *allowedKeys = [integerKeys setByAddingObject:
        @"secureTextEntry"];
    for (id key in dictionary) {
        if (![key isKindOfClass:NSString.class] ||
            ![allowedKeys containsObject:key]) {
            return nil;
        }
        if ([key isEqualToString:@"secureTextEntry"]) {
            if (!IDTextInputBoolean(dictionary[key])) return nil;
        } else if (!IDTextInputInteger(dictionary[key], NULL)) {
            return nil;
        }
    }
    return [dictionary copy];
}

static NSDictionary<NSString *, NSNumber *> *
IDTextInputParseInitialTraits(id value) {
    NSArray<NSString *> *keys = @[
        @"autocapitalizationType", @"autocorrectionType",
        @"spellCheckingType", @"smartQuotesType", @"smartDashesType",
        @"smartInsertDeleteType", @"inlinePredictionType", @"keyboardType",
        @"returnKeyType", @"secureTextEntry",
    ];
    if (!IDTextInputExactKeys(value, keys)) return nil;
    return IDTextInputParseTraits(value, NO);
}

static BOOL IDTextInputFamily(
    NSString *name, IDTextInputScenarioFamily *family) {
    NSDictionary<NSString *, NSNumber *> *values = @{
        @"ime": @(IDTextInputScenarioFamilyIME),
        @"autocorrection": @(IDTextInputScenarioFamilyAutocorrection),
        @"inline-prediction": @(IDTextInputScenarioFamilyInlinePrediction),
        @"inline-formatting": @(IDTextInputScenarioFamilyInlineFormatting),
    };
    NSNumber *value = values[name];
    if (value == nil) return NO;
    *family = value.integerValue;
    return YES;
}

static BOOL IDTextInputTransactionKindForName(
    NSString *name, IDTextInputTransactionKind *kind) {
    NSDictionary<NSString *, NSNumber *> *values = @{
        @"become-first-responder":
            @(IDTextInputTransactionKindBecomeFirstResponder),
        @"resign-first-responder":
            @(IDTextInputTransactionKindResignFirstResponder),
        @"set-selection": @(IDTextInputTransactionKindSetSelection),
        @"set-marked-text": @(IDTextInputTransactionKindSetMarkedText),
        @"unmark-text": @(IDTextInputTransactionKindUnmarkText),
        @"insert-text": @(IDTextInputTransactionKindInsertText),
        @"delete-backward": @(IDTextInputTransactionKindDeleteBackward),
        @"replace-range": @(IDTextInputTransactionKindReplaceRange),
        @"begin-undo-group": @(IDTextInputTransactionKindBeginUndoGroup),
        @"end-undo-group": @(IDTextInputTransactionKindEndUndoGroup),
        @"undo": @(IDTextInputTransactionKindUndo),
        @"redo": @(IDTextInputTransactionKindRedo),
        @"set-traits": @(IDTextInputTransactionKindSetTraits),
        @"toggleInlineTrait":
            @(IDTextInputTransactionKindToggleInlineTrait),
        @"checkpoint": @(IDTextInputTransactionKindCheckpoint),
    };
    NSNumber *value = values[name];
    if (value == nil) return NO;
    *kind = value.integerValue;
    return YES;
}

static BOOL IDTextInputNull(id value) {
    return value == NSNull.null;
}

static IDTextInputTransaction *IDTextInputParseTransaction(
    id value, NSUInteger initialLength, NSError **error) {
    BOOL inlineToggle =
        [value isKindOfClass:NSDictionary.class] &&
        [value[@"kind"] isEqualToString:@"toggleInlineTrait"];
    NSArray<NSString *> *keys = inlineToggle
        ? @[@"kind", @"text", @"range", @"selectedRange", @"traits",
            @"trait", @"phase"]
        : @[@"kind", @"text", @"range", @"selectedRange", @"traits",
            @"phase"];
    if (!IDTextInputExactKeys(value, keys)) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Transaction must contain exactly the version-one keys.");
        }
        return nil;
    }
    NSDictionary *dictionary = value;
    IDTextInputTransactionKind kind = 0;
    if (!IDTextInputNonemptyString(dictionary[@"kind"]) ||
        !IDTextInputTransactionKindForName(dictionary[@"kind"], &kind)) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Transaction kind is unsupported.");
        }
        return nil;
    }

    id textJSON = dictionary[@"text"];
    id rangeJSON = dictionary[@"range"];
    id selectedRangeJSON = dictionary[@"selectedRange"];
    id traitJSON = dictionary[@"trait"];
    id phaseJSON = dictionary[@"phase"];
    NSDictionary *traits =
        IDTextInputParseTraits(dictionary[@"traits"], YES);
    if (traits == nil) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Transaction traits are malformed.");
        }
        return nil;
    }

    NSString *text = IDTextInputNull(textJSON) ? nil :
        ([textJSON isKindOfClass:NSString.class] ? textJSON : nil);
    NSString *phase = IDTextInputNull(phaseJSON) ? nil :
        (IDTextInputNonemptyString(phaseJSON) ? phaseJSON : nil);
    NSString *trait = IDTextInputNull(traitJSON) ? nil :
        (IDTextInputNonemptyString(traitJSON) ? traitJSON : nil);
    if ((!IDTextInputNull(textJSON) && text == nil) ||
        (!IDTextInputNull(phaseJSON) && phase == nil) ||
        (inlineToggle && (!IDTextInputNonemptyString(trait) ||
         ![@[@"bold", @"italic", @"underline", @"strikethrough"]
             containsObject:trait]))) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Transaction text or phase has the wrong type.");
        }
        return nil;
    }

    BOOL rangeValid = NO;
    NSValue *range = IDTextInputNull(rangeJSON) ? nil :
        IDTextInputRangeValue(rangeJSON, initialLength, &rangeValid);
    if (!IDTextInputNull(rangeJSON) && !rangeValid) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Transaction range is invalid.");
        }
        return nil;
    }

    NSUInteger selectedUpperBound = text.length;
    BOOL selectedRangeValid = NO;
    NSValue *selectedRange = IDTextInputNull(selectedRangeJSON) ? nil :
        IDTextInputRangeValue(
            selectedRangeJSON, selectedUpperBound, &selectedRangeValid);
    if (!IDTextInputNull(selectedRangeJSON) && !selectedRangeValid) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Transaction selectedRange is invalid.");
        }
        return nil;
    }

    BOOL commonEmpty = text == nil && range == nil &&
        selectedRange == nil && traits.count == 0 && trait == nil &&
        phase == nil;
    BOOL valid = NO;
    switch (kind) {
        case IDTextInputTransactionKindBecomeFirstResponder:
        case IDTextInputTransactionKindResignFirstResponder:
        case IDTextInputTransactionKindUnmarkText:
        case IDTextInputTransactionKindDeleteBackward:
        case IDTextInputTransactionKindBeginUndoGroup:
        case IDTextInputTransactionKindEndUndoGroup:
        case IDTextInputTransactionKindUndo:
        case IDTextInputTransactionKindRedo:
            valid = commonEmpty;
            break;
        case IDTextInputTransactionKindSetSelection:
            valid = text == nil && range != nil && selectedRange == nil &&
                traits.count == 0 && phase == nil;
            break;
        case IDTextInputTransactionKindSetMarkedText:
            valid = text != nil && range == nil && selectedRange != nil &&
                traits.count == 0 && phase == nil;
            break;
        case IDTextInputTransactionKindInsertText:
            valid = text != nil && range == nil && selectedRange == nil &&
                traits.count == 0 && phase == nil;
            break;
        case IDTextInputTransactionKindReplaceRange:
            valid = text != nil && range != nil && selectedRange == nil &&
                traits.count == 0 && phase == nil;
            break;
        case IDTextInputTransactionKindSetTraits:
            valid = text == nil && range == nil && selectedRange == nil &&
                traits.count > 0 && trait == nil && phase == nil;
            break;
        case IDTextInputTransactionKindToggleInlineTrait:
            valid = text == nil && range == nil && selectedRange == nil &&
                traits.count == 0 && trait != nil && phase == nil;
            break;
        case IDTextInputTransactionKindCheckpoint:
            valid = text == nil && range == nil && selectedRange == nil &&
                traits.count == 0 && phase != nil;
            break;
    }
    if (!valid) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Transaction fields do not match its kind.");
        }
        return nil;
    }

    IDTextInputTransaction *transaction = [IDTextInputTransaction new];
    transaction.kind = kind;
    transaction.text = text;
    transaction.rangeValue = range;
    transaction.selectedRangeValue = selectedRange;
    transaction.traits = traits;
    transaction.trait = trait;
    transaction.phase = phase;
    return transaction;
}

static NSArray<NSString *> *IDTextInputParseComparisonFields(id value) {
    if (![value isKindOfClass:NSArray.class] || [value count] == 0) return nil;
    NSSet<NSString *> *allowed = [NSSet setWithArray:@[
        @"canonical", @"blocks", @"selection", @"markedRange",
        @"markedText", @"affinity", @"firstResponder", @"canUndo",
        @"canRedo", @"traits", @"caretRect", @"selectionRects",
        @"inputDelegateTrace", @"storageMutationTrace",
        @"typingInlineTraits", @"inlineRuns", @"annotationRanges",
    ]];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (id field in value) {
        if (!IDTextInputNonemptyString(field) ||
            ![allowed containsObject:field] ||
            [seen containsObject:field]) {
            return nil;
        }
        [seen addObject:field];
    }
    return [value copy];
}

static IDTextInputScenario *IDTextInputParseScenario(
    id value, NSInteger schemaVersion, IDTextInputScenarioFamily family,
    NSError **error) {
    NSArray<NSString *> *keys = @[
        @"identifier", @"initial", @"transactions", @"comparisonFields",
        @"geometryTolerance", @"provenance",
    ];
    if (!IDTextInputExactKeys(value, keys)) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Scenario must contain exactly the version-one keys.");
        }
        return nil;
    }
    NSDictionary *dictionary = value;
    NSString *identifier = dictionary[@"identifier"];
    if (!IDTextInputNonemptyString(identifier)) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Scenario identifier must be nonempty.");
        }
        return nil;
    }

    NSDictionary *initial = dictionary[@"initial"];
    if (!IDTextInputExactKeys(
            initial, @[@"text", @"selection", @"traits"]) ||
        ![initial[@"text"] isKindOfClass:NSString.class]) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Scenario initial state is malformed.");
        }
        return nil;
    }
    NSString *initialText = initial[@"text"];
    BOOL initialRangeValid = NO;
    NSValue *initialSelection = IDTextInputRangeValue(
        initial[@"selection"], initialText.length, &initialRangeValid);
    NSDictionary *initialTraits =
        IDTextInputParseInitialTraits(initial[@"traits"]);
    if (!initialRangeValid || initialTraits == nil) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Scenario initial range or traits are malformed.");
        }
        return nil;
    }

    NSArray *transactionJSON = dictionary[@"transactions"];
    if (![transactionJSON isKindOfClass:NSArray.class] ||
        transactionJSON.count == 0) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Scenario transactions must be nonempty.");
        }
        return nil;
    }
    NSMutableArray<IDTextInputTransaction *> *transactions =
        [NSMutableArray array];
    NSInteger undoDepth = 0;
    NSUInteger checkpointCount = 0;
    for (id transactionJSONValue in transactionJSON) {
        IDTextInputTransaction *transaction =
            IDTextInputParseTransaction(
                transactionJSONValue, initialText.length, error);
        if (transaction == nil) return nil;
        if (transaction.kind ==
            IDTextInputTransactionKindBeginUndoGroup) {
            undoDepth += 1;
        } else if (transaction.kind ==
                   IDTextInputTransactionKindEndUndoGroup) {
            undoDepth -= 1;
            if (undoDepth < 0) {
                if (error != NULL) {
                    *error = IDTextInputScenarioError(
                        @"Undo group closes before it opens.");
                }
                return nil;
            }
        } else if (transaction.kind ==
                   IDTextInputTransactionKindCheckpoint) {
            checkpointCount += 1;
        }
        [transactions addObject:transaction];
    }
    if (undoDepth != 0 || checkpointCount == 0) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Scenario needs balanced Undo groups and a checkpoint.");
        }
        return nil;
    }

    NSArray<NSString *> *comparisonFields =
        IDTextInputParseComparisonFields(dictionary[@"comparisonFields"]);
    id toleranceJSON = dictionary[@"geometryTolerance"];
    if (comparisonFields == nil ||
        ![toleranceJSON isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)toleranceJSON) ==
            CFBooleanGetTypeID() ||
        !isfinite([toleranceJSON doubleValue]) ||
        [toleranceJSON doubleValue] < 0.0) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Scenario comparison contract is malformed.");
        }
        return nil;
    }
    NSSet<NSString *> *formattingFields =
        [NSSet setWithArray:@[@"typingInlineTraits", @"inlineRuns"]];
    if (family != IDTextInputScenarioFamilyInlineFormatting &&
        [formattingFields intersectsSet:
            [NSSet setWithArray:comparisonFields]]) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Formatting fields require the inline-formatting family.");
        }
        return nil;
    }
    for (IDTextInputTransaction *transaction in transactions) {
        if (transaction.kind ==
                IDTextInputTransactionKindToggleInlineTrait &&
            family != IDTextInputScenarioFamilyInlineFormatting) {
            if (error != NULL) {
                *error = IDTextInputScenarioError(
                    @"Formatting transactions require their family.");
            }
            return nil;
        }
    }

    NSDictionary *provenance = dictionary[@"provenance"];
    if (!IDTextInputExactKeys(
            provenance,
            @[@"sourceFixture", @"stockEvidence", @"targetRuntime"]) ||
        !IDTextInputNonemptyString(provenance[@"sourceFixture"]) ||
        !IDTextInputNonemptyString(provenance[@"stockEvidence"]) ||
        !IDTextInputNonemptyString(provenance[@"targetRuntime"])) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Scenario provenance is malformed.");
        }
        return nil;
    }

    IDTextInputScenario *scenario = [IDTextInputScenario new];
    scenario.schemaVersion = schemaVersion;
    scenario.family = family;
    scenario.identifier = identifier;
    scenario.initialText = initialText;
    scenario.initialSelection = initialSelection.rangeValue;
    scenario.initialTraits = initialTraits;
    scenario.transactions = transactions.copy;
    scenario.comparisonFields = comparisonFields;
    scenario.geometryTolerance = [toleranceJSON doubleValue];
    scenario.provenance = provenance;
    return scenario;
}

NSArray<IDTextInputScenario *> *IDLoadTextInputScenarios(
    NSURL *fixtureURL, NSError **error) {
    if (error != NULL) *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:fixtureURL
                                        options:0
                                          error:error];
    if (data == nil) return nil;
    NSError *jsonError = nil;
    id root = [NSJSONSerialization JSONObjectWithData:data
                                               options:0
                                                 error:&jsonError];
    if (root == nil) {
        if (error != NULL) {
            *error = [NSError errorWithDomain:IDTextInputScenarioErrorDomain
                                         code:IDTextInputScenarioErrorInvalidJSON
                                     userInfo:@{
                NSLocalizedDescriptionKey:
                    jsonError.localizedDescription ?: @"Invalid JSON.",
            }];
        }
        return nil;
    }
    if (!IDTextInputExactKeys(
            root, @[@"schema", @"runtime", @"family", @"scenarios"])) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Fixture must contain exactly the version-one keys.");
        }
        return nil;
    }
    NSDictionary *fixture = root;
    NSUInteger schema = 0;
    if (!IDTextInputInteger(fixture[@"schema"], &schema) || schema != 1 ||
        !IDTextInputExactKeys(
            fixture[@"runtime"], @[@"osVersion", @"osBuild"]) ||
        ![fixture[@"runtime"][@"osVersion"] isEqual:@"26.5"] ||
        ![fixture[@"runtime"][@"osBuild"] isEqual:@"23F73"]) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Fixture runtime or schema is unsupported.");
        }
        return nil;
    }
    IDTextInputScenarioFamily family = 0;
    if (!IDTextInputFamily(fixture[@"family"], &family) ||
        ![fixture[@"scenarios"] isKindOfClass:NSArray.class] ||
        [fixture[@"scenarios"] count] == 0) {
        if (error != NULL) {
            *error = IDTextInputScenarioError(
                @"Fixture family or scenarios are malformed.");
        }
        return nil;
    }

    NSMutableArray<IDTextInputScenario *> *scenarios =
        [NSMutableArray array];
    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
    for (id scenarioJSON in fixture[@"scenarios"]) {
        IDTextInputScenario *scenario =
            IDTextInputParseScenario(scenarioJSON, (NSInteger)schema,
                                     family, error);
        if (scenario == nil) return nil;
        if ([identifiers containsObject:scenario.identifier]) {
            if (error != NULL) {
                *error = IDTextInputScenarioError(
                    @"Scenario identifiers must be unique.");
            }
            return nil;
        }
        [identifiers addObject:scenario.identifier];
        [scenarios addObject:scenario];
    }
    return scenarios.copy;
}
