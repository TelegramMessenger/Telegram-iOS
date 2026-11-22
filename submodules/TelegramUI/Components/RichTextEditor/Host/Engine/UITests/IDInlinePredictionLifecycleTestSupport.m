#import "IDInlinePredictionLifecycleTestSupport.h"
#import "IDHIDEventTestSupport.h"
#import "IDTextInputBatchTestSupport.h"

#import <CommonCrypto/CommonDigest.h>
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>

NSString *const IDInlinePredictionStatusErrorDomain =
    @"com.inputdec.tests.inline-prediction-status";

typedef NS_ENUM(NSInteger, IDInlinePredictionStatusErrorCode) {
    IDInlinePredictionStatusErrorInvalidJSON = 1,
    IDInlinePredictionStatusErrorInvalidSchema,
    IDInlinePredictionStatusErrorInvalidField,
};

static NSError *IDInlinePredictionError(
    IDInlinePredictionStatusErrorCode code, NSString *description) {
    return [NSError errorWithDomain:IDInlinePredictionStatusErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

@interface IDInlinePredictionRow ()
@property(nonatomic, readwrite) IDInlinePredictionLocation location;
@property(nonatomic, readwrite) IDInlinePredictionDecision decision;
@property(nonatomic, copy, readwrite) NSString *identifier;
- (instancetype)initWithLocation:(IDInlinePredictionLocation)location
                        decision:(IDInlinePredictionDecision)decision
                      identifier:(NSString *)identifier;
@end

@implementation IDInlinePredictionRow

- (instancetype)initWithLocation:(IDInlinePredictionLocation)location
                        decision:(IDInlinePredictionDecision)decision
                      identifier:(NSString *)identifier {
    self = [super init];
    if (self == nil) return nil;
    _location = location;
    _decision = decision;
    _identifier = [identifier copy];
    return self;
}

@end

@interface IDInlinePredictionStatus ()
@property(nonatomic, copy, readwrite) NSString *canonical;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *blocks;
@property(nonatomic, readwrite) NSRange selection;
@property(nonatomic, copy, readwrite) NSString *affinity;
@property(nonatomic, readwrite) NSRange markedRange;
@property(nonatomic, copy, readwrite)
    NSArray<NSNumber *> *structuralNewlineLocations;
@property(nonatomic, copy, readwrite) NSArray<NSValue *> *checkingRanges;
@property(nonatomic, copy, readwrite)
    NSDictionary<NSString *, id> *predictionDescriptor;
@property(nonatomic, copy, readwrite)
    NSArray<NSDictionary<NSString *, id> *> *temporaryRenderingDescriptors;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *mutationTrace;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *eventTrace;
@property(nonatomic, copy, readwrite)
    NSDictionary<NSString *, id> *keyboardState;
@property(nonatomic, copy, readwrite)
    NSDictionary<NSString *, id> *predictionGeometry;
@property(nonatomic, copy, readwrite) NSString *coordinateSpaceIdentity;
@property(nonatomic, readwrite) NSUInteger documentRevision;
@property(nonatomic, readwrite) NSUInteger textEpoch;
@property(nonatomic, readwrite) NSUInteger selectionEpoch;
@property(nonatomic, readwrite) NSUInteger checkingEpoch;
@property(nonatomic, readwrite, getter=isFirstResponder) BOOL firstResponder;
@end

@implementation IDInlinePredictionStatus
@end

@interface IDInlinePredictionPhaseSnapshot ()
@property(nonatomic, copy, readwrite) NSString *phase;
@property(nonatomic, strong, readwrite) IDInlinePredictionStatus *status;
@property(nonatomic, copy, readwrite) NSString *screenshotName;
@property(nonatomic, copy, readwrite) NSData *screenshotPNGData;
@end

@implementation IDInlinePredictionPhaseSnapshot
@end

@interface IDInlinePredictionRunResult ()
@property(nonatomic, strong, readwrite) IDInlinePredictionRow *row;
@property(nonatomic, copy, readwrite)
    NSArray<IDInlinePredictionPhaseSnapshot *> *phases;
@end

@implementation IDInlinePredictionRunResult
@end

@interface IDInlinePredictionLifecycleAttempt ()
@property(nonatomic, readwrite) BOOL offerReady;
@property(nonatomic, strong, readwrite) IDInlinePredictionRunResult *result;
@end

@implementation IDInlinePredictionLifecycleAttempt
@end

static BOOL IDInlinePredictionCheckpointError(
    NSError **error, NSString *description) {
    if (error != NULL) {
        *error = [NSError errorWithDomain:IDInlinePredictionStatusErrorDomain
            code:IDInlinePredictionStatusErrorInvalidField
            userInfo:@{NSLocalizedDescriptionKey: description}];
    }
    return NO;
}

static NSString *IDInlinePredictionSHA256(NSData *data) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *result = [NSMutableString
        stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        [result appendFormat:@"%02x", digest[index]];
    }
    return result;
}

static NSDictionary *IDInlinePredictionRangeDictionary(NSRange range) {
    NSNumber *location = range.location == NSNotFound
        ? @(-1) : @(range.location);
    return @{ @"location": location, @"length": @(range.length) };
}

static NSDictionary *IDInlinePredictionStatusDictionary(
    IDInlinePredictionStatus *status) {
    NSMutableArray *checkingRanges = [NSMutableArray array];
    for (NSValue *value in status.checkingRanges) {
        [checkingRanges addObject:
            IDInlinePredictionRangeDictionary(value.rangeValue)];
    }
    return @{
        @"schema": @1,
        @"canonical": status.canonical,
        @"blocks": status.blocks,
        @"selection": IDInlinePredictionRangeDictionary(status.selection),
        @"affinity": status.affinity,
        @"markedRange": IDInlinePredictionRangeDictionary(status.markedRange),
        @"structuralNewlineLocations": status.structuralNewlineLocations,
        @"checkingRanges": checkingRanges,
        @"predictionDescriptor": status.predictionDescriptor,
        @"temporaryRenderingDescriptors":
            status.temporaryRenderingDescriptors,
        @"mutationTrace": status.mutationTrace,
        @"eventTrace": status.eventTrace,
        @"keyboardState": status.keyboardState,
        @"predictionGeometry": status.predictionGeometry,
        @"coordinateSpaceIdentity": status.coordinateSpaceIdentity,
        @"documentRevision": @(status.documentRevision),
        @"textEpoch": @(status.textEpoch),
        @"selectionEpoch": @(status.selectionEpoch),
        @"checkingEpoch": @(status.checkingEpoch),
        @"firstResponder": @(status.isFirstResponder),
    };
}

static NSUInteger IDInlinePredictionObservationIndex(
    IDTextInputBatchObservation *observation) {
    NSArray<NSString *> *parts =
        [observation.batchIdentifier componentsSeparatedByString:@"--"];
    if (parts.count != 4 || ![parts[0] isEqual:@"inline-prediction"] ||
        ![parts[3] isEqual:observation.rowIdentifier]) return NSNotFound;
    NSUInteger repetition = [parts[1] isEqual:@"r1"] ? 1
        : ([parts[1] isEqual:@"r2"] ? 2 : 0);
    NSArray<NSString *> *hosts = [parts[2] componentsSeparatedByString:@"-"];
    NSString *host = observation.host == IDTextInputBatchHostStock
        ? @"stock" : @"custom";
    NSUInteger hostIndex = [hosts indexOfObject:host];
    if (repetition == 0 || hosts.count != 2 || hostIndex == NSNotFound ||
        (![hosts isEqual:@[@"stock", @"custom"]] &&
         ![hosts isEqual:@[@"custom", @"stock"]])) return NSNotFound;
    NSUInteger orderOffset = [parts[2] isEqual:@"stock-custom"] ? 0 : 2;
    return (repetition - 1) * 4 + orderOffset + hostIndex + 1;
}

static BOOL IDInlinePredictionWriteCheckpointFile(
    NSURL *root, NSString *relativePath, NSData *data,
    NSMutableArray<NSDictionary *> *files, NSError **error) {
    NSURL *URL = [root URLByAppendingPathComponent:relativePath];
    if (![data writeToURL:URL options:NSDataWritingWithoutOverwriting
                    error:error]) return NO;
    [files addObject:@{
        @"path": relativePath,
        @"size": @(data.length),
        @"sha256": IDInlinePredictionSHA256(data),
    }];
    return YES;
}

BOOL IDWriteInlinePredictionObservationCheckpoint(
    NSURL *directory, IDInlinePredictionRunResult *result,
    IDTextInputBatchObservation *observation, NSUInteger successfulAttempt,
    XCUIApplication *application, NSError **error) {
    NSUInteger observationIndex =
        IDInlinePredictionObservationIndex(observation);
    if (observationIndex == NSNotFound || successfulAttempt < 1 ||
        successfulAttempt > 20 || result.phases.count == 0 ||
        ![result.row.identifier isEqual:observation.rowIdentifier]) {
        return IDInlinePredictionCheckpointError(
            error, @"checkpoint identity is invalid");
    }
    NSString *packageName = [NSString stringWithFormat:
        @"observation-%03lu.checkpoint", (unsigned long)observationIndex];
    NSURL *destination = [directory URLByAppendingPathComponent:packageName
                                                     isDirectory:YES];
    if ([NSFileManager.defaultManager fileExistsAtPath:destination.path]) {
        return IDInlinePredictionCheckpointError(
            error, @"checkpoint destination already exists");
    }
    NSString *stagingName = [NSString stringWithFormat:
        @".%@.partial-%d", packageName, getpid()];
    NSURL *staging = [directory URLByAppendingPathComponent:stagingName
                                                isDirectory:YES];
    NSURL *attachments = [staging URLByAppendingPathComponent:@"attachments"
                                                   isDirectory:YES];
    NSFileManager *manager = NSFileManager.defaultManager;
    NSError *localError = nil;
    if (![manager createDirectoryAtURL:attachments
           withIntermediateDirectories:YES attributes:nil error:&localError]) {
        return IDInlinePredictionCheckpointError(
            error, localError.localizedDescription);
    }
    BOOL success = NO;
    @try {
        NSString *host = observation.host == IDTextInputBatchHostStock
            ? @"stock" : @"custom";
        NSDictionary *metadata = @{
            @"schema": @1,
            @"runtime": @{ @"osVersion": @"26.5", @"osBuild": @"23F73" },
            @"udid": @"FA6F7462-AA97-42FE-9E57-8DA0593CE756",
            @"observationIndex": @(observationIndex),
            @"batchId": observation.batchIdentifier,
            @"rowId": observation.rowIdentifier,
            @"host": host,
            @"successfulAttempt": @(successfulAttempt),
            @"result": @"complete",
        };
        NSMutableArray<NSDictionary *> *files = [NSMutableArray array];
        NSData *metadataData = [NSJSONSerialization
            dataWithJSONObject:metadata options:NSJSONWritingSortedKeys
            error:&localError];
        if (metadataData == nil || !IDInlinePredictionWriteCheckpointFile(
                staging, @"metadata.json", metadataData, files, &localError)) {
            @throw localError ?: [NSException exceptionWithName:@"Checkpoint"
                reason:@"cannot write metadata" userInfo:nil];
        }
        for (IDInlinePredictionPhaseSnapshot *phase in result.phases) {
            if (phase.phase.length == 0 || phase.status == nil ||
                phase.screenshotPNGData.length == 0) {
                @throw [NSException exceptionWithName:@"Checkpoint"
                    reason:@"checkpoint phase is incomplete" userInfo:nil];
            }
            NSString *statusPath = [NSString stringWithFormat:
                @"attachments/inline-prediction-%@-status.json", phase.phase];
            NSData *statusData = [NSJSONSerialization dataWithJSONObject:
                IDInlinePredictionStatusDictionary(phase.status)
                options:NSJSONWritingSortedKeys error:&localError];
            NSString *imagePath = [NSString stringWithFormat:
                @"attachments/inline-prediction-%@.png", phase.phase];
            if (statusData == nil || !IDInlinePredictionWriteCheckpointFile(
                    staging, statusPath, statusData, files, &localError) ||
                !IDInlinePredictionWriteCheckpointFile(
                    staging, imagePath, phase.screenshotPNGData, files,
                    &localError)) {
                @throw localError ?: [NSException exceptionWithName:@"Checkpoint"
                    reason:@"cannot write phase" userInfo:nil];
            }
        }
        NSData *hierarchy = [(application.debugDescription ?: @"unavailable")
            dataUsingEncoding:NSUTF8StringEncoding];
        if (!IDInlinePredictionWriteCheckpointFile(
                staging, @"attachments/hierarchy.txt", hierarchy, files,
                &localError)) {
            @throw localError;
        }
        [files sortUsingComparator:^NSComparisonResult(
            NSDictionary *left, NSDictionary *right) {
            return [left[@"path"] compare:right[@"path"]];
        }];
        NSDictionary *manifest = @{ @"schema": @1, @"files": files };
        NSData *manifestData = [NSJSONSerialization
            dataWithJSONObject:manifest options:NSJSONWritingSortedKeys
            error:&localError];
        if (manifestData == nil || ![manifestData writeToURL:
                [staging URLByAppendingPathComponent:@"manifest.json"]
                options:NSDataWritingWithoutOverwriting error:&localError] ||
            ![manager moveItemAtURL:staging toURL:destination
                              error:&localError]) {
            @throw localError ?: [NSException exceptionWithName:@"Checkpoint"
                reason:@"cannot publish checkpoint" userInfo:nil];
        }
        success = YES;
    } @catch (id exception) {
        if (localError == nil && [exception isKindOfClass:NSError.class]) {
            localError = exception;
        }
        IDInlinePredictionCheckpointError(
            error, localError.localizedDescription ?:
                ([exception respondsToSelector:@selector(reason)]
                    ? [exception reason] : @"cannot write checkpoint"));
    } @finally {
        if (!success) [manager removeItemAtURL:staging error:nil];
    }
    return success;
}

NSArray<IDInlinePredictionRow *> *IDInlinePredictionMatrix(void) {
    static NSArray<IDInlinePredictionRow *> *rows;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *locations =
            @[@"interior", @"before-boundary", @"after-boundary"];
        NSArray<NSString *> *decisions =
            @[@"accept", @"dismiss-then-type", @"accept-then-delete"];
        NSMutableArray<IDInlinePredictionRow *> *result =
            [NSMutableArray arrayWithCapacity:9];
        for (NSUInteger location = 0; location < locations.count; location += 1) {
            for (NSUInteger decision = 0; decision < decisions.count;
                 decision += 1) {
                NSString *identifier = [NSString stringWithFormat:@"%@-%@",
                    locations[location], decisions[decision]];
                [result addObject:[[IDInlinePredictionRow alloc]
                    initWithLocation:(IDInlinePredictionLocation)location
                            decision:(IDInlinePredictionDecision)decision
                          identifier:identifier]];
            }
        }
        rows = result.copy;
    });
    return rows;
}

NSArray<IDInlinePredictionRow *> *
IDInlinePredictionRowsMatchingIdentifier(NSString *identifier) {
    if (identifier == nil) return @[];
    NSPredicate *predicate = [NSPredicate predicateWithBlock:
        ^BOOL(IDInlinePredictionRow *row, NSDictionary *bindings) {
            (void)bindings;
            return [row.identifier isEqualToString:identifier];
        }];
    return [IDInlinePredictionMatrix()
        filteredArrayUsingPredicate:predicate];
}

static BOOL IDInlinePredictionIsInteger(id value, NSUInteger *result) {
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
    if (result != NULL) {
        *result = [(NSNumber *)value unsignedIntegerValue];
    }
    return YES;
}

static BOOL IDInlinePredictionIsBoolean(id value, BOOL *result) {
    if (![value isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) {
        return NO;
    }
    if (result != NULL) *result = [value boolValue];
    return YES;
}

static BOOL IDInlinePredictionExactKeys(
    id value, NSArray<NSString *> *expectedKeys) {
    if (![value isKindOfClass:NSDictionary.class]) return NO;
    NSDictionary *dictionary = value;
    return [[NSSet setWithArray:dictionary.allKeys]
        isEqualToSet:[NSSet setWithArray:expectedKeys]];
}

static BOOL IDInlinePredictionParseRange(id value, NSRange *result) {
    if (!IDInlinePredictionExactKeys(value, @[@"location", @"length"])) {
        return NO;
    }
    NSUInteger location = 0;
    NSUInteger length = 0;
    if (!IDInlinePredictionIsInteger(value[@"location"], &location) ||
        !IDInlinePredictionIsInteger(value[@"length"], &length)) {
        return NO;
    }
    if ((location == NSNotFound && length != 0) ||
        (location != NSNotFound && length > NSUIntegerMax - location)) {
        return NO;
    }
    if (result != NULL) *result = NSMakeRange(location, length);
    return YES;
}

static BOOL IDInlinePredictionStringArray(id value) {
    if (![value isKindOfClass:NSArray.class]) return NO;
    for (id item in value) {
        if (![item isKindOfClass:NSString.class]) return NO;
    }
    return YES;
}

static BOOL IDInlinePredictionDescriptorIsValid(id value) {
    if (!IDInlinePredictionExactKeys(value, @[
            @"present", @"displayText", @"accessibilityIdentity", @"range",
            @"renderingAttributeKeys",
        ])) {
        return NO;
    }
    BOOL present = NO;
    NSRange range = {0};
    return IDInlinePredictionIsBoolean(value[@"present"], &present) &&
        [value[@"displayText"] isKindOfClass:NSString.class] &&
        [value[@"accessibilityIdentity"] isKindOfClass:NSString.class] &&
        IDInlinePredictionParseRange(value[@"range"], &range) &&
        IDInlinePredictionStringArray(value[@"renderingAttributeKeys"]);
}

static BOOL IDInlinePredictionTemporaryDescriptorsAreValid(id value) {
    if (![value isKindOfClass:NSArray.class]) return NO;
    for (id descriptor in value) {
        if (!IDInlinePredictionExactKeys(descriptor,
                @[@"range", @"attributeKeys", @"valueDescriptions"])) {
            return NO;
        }
        NSRange range = {0};
        if (!IDInlinePredictionParseRange(descriptor[@"range"], &range) ||
            !IDInlinePredictionStringArray(descriptor[@"attributeKeys"]) ||
            !IDInlinePredictionStringArray(
                descriptor[@"valueDescriptions"]) ||
            [descriptor[@"attributeKeys"] count] !=
                [descriptor[@"valueDescriptions"] count]) {
            return NO;
        }
    }
    return YES;
}

static BOOL IDInlinePredictionKeyboardStateIsValid(id value) {
    if (!IDInlinePredictionExactKeys(
            value, @[@"visible", @"locale", @"inlinePredictionEnabled"])) {
        return NO;
    }
    BOOL visible = NO;
    BOOL enabled = NO;
    return IDInlinePredictionIsBoolean(value[@"visible"], &visible) &&
        [value[@"locale"] isKindOfClass:NSString.class] &&
        IDInlinePredictionIsBoolean(
            value[@"inlinePredictionEnabled"], &enabled);
}

static BOOL IDInlinePredictionGeometryIsValid(id value) {
    if (!IDInlinePredictionExactKeys(
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
    return YES;
}

IDInlinePredictionStatus *IDParseInlinePredictionStatus(
    NSString *serializedStatus, NSError **error) {
    if (error != NULL) *error = nil;
    NSData *data = [serializedStatus dataUsingEncoding:NSUTF8StringEncoding];
    id object = data == nil ? nil :
        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray<NSString *> *keys = @[
        @"schema", @"scenario", @"canonical", @"blocks", @"selection",
        @"affinity", @"markedRange", @"structuralNewlineLocations",
        @"checkingRanges", @"predictionDescriptor",
        @"temporaryRenderingDescriptors", @"mutationTrace", @"eventTrace",
        @"keyboardState", @"predictionGeometry", @"coordinateSpaceIdentity",
        @"documentRevision", @"textEpoch", @"selectionEpoch", @"checkingEpoch",
        @"firstResponder",
    ];
    if (!IDInlinePredictionExactKeys(object, keys)) {
        if (error != NULL) {
            *error = IDInlinePredictionError(
                IDInlinePredictionStatusErrorInvalidJSON,
                @"Inline-prediction status must be a complete versioned JSON object");
        }
        return nil;
    }

    NSDictionary<NSString *, id> *payload = object;
    NSUInteger schema = 0;
    if (!IDInlinePredictionIsInteger(payload[@"schema"], &schema) ||
        schema != 1) {
        if (error != NULL) {
            *error = IDInlinePredictionError(
                IDInlinePredictionStatusErrorInvalidSchema,
                @"Inline-prediction status schema must equal 1");
        }
        return nil;
    }

    NSRange selection = {0};
    NSRange markedRange = {0};
    BOOL firstResponder = NO;
    BOOL valid =
        [payload[@"scenario"] isKindOfClass:NSString.class] &&
        [payload[@"scenario"] length] > 0 &&
        [payload[@"canonical"] isKindOfClass:NSString.class] &&
        IDInlinePredictionStringArray(payload[@"blocks"]) &&
        IDInlinePredictionParseRange(payload[@"selection"], &selection) &&
        ([payload[@"affinity"] isEqual:@"forward"] ||
         [payload[@"affinity"] isEqual:@"backward"]) &&
        IDInlinePredictionParseRange(payload[@"markedRange"], &markedRange) &&
        [payload[@"structuralNewlineLocations"] isKindOfClass:NSArray.class] &&
        [payload[@"checkingRanges"] isKindOfClass:NSArray.class] &&
        IDInlinePredictionDescriptorIsValid(
            payload[@"predictionDescriptor"]) &&
        IDInlinePredictionTemporaryDescriptorsAreValid(
            payload[@"temporaryRenderingDescriptors"]) &&
        IDInlinePredictionStringArray(payload[@"mutationTrace"]) &&
        IDInlinePredictionStringArray(payload[@"eventTrace"]) &&
        IDInlinePredictionKeyboardStateIsValid(payload[@"keyboardState"]) &&
        IDInlinePredictionGeometryIsValid(payload[@"predictionGeometry"]) &&
        [payload[@"coordinateSpaceIdentity"] isKindOfClass:NSString.class] &&
        [payload[@"coordinateSpaceIdentity"] length] > 0 &&
        IDInlinePredictionIsBoolean(
            payload[@"firstResponder"], &firstResponder);

    NSArray *newlinePayload =
        [payload[@"structuralNewlineLocations"] isKindOfClass:NSArray.class]
            ? payload[@"structuralNewlineLocations"] : @[];
    NSMutableArray<NSNumber *> *newlines = [NSMutableArray array];
    for (id item in newlinePayload) {
        NSUInteger location = 0;
        if (!IDInlinePredictionIsInteger(item, &location)) {
            valid = NO;
        } else {
            [newlines addObject:@(location)];
        }
    }

    NSArray *checkingRangePayload =
        [payload[@"checkingRanges"] isKindOfClass:NSArray.class]
            ? payload[@"checkingRanges"] : @[];
    NSMutableArray<NSValue *> *checkingRanges = [NSMutableArray array];
    for (id item in checkingRangePayload) {
        NSRange range = {0};
        if (!IDInlinePredictionParseRange(item, &range)) {
            valid = NO;
        } else {
            [checkingRanges addObject:[NSValue valueWithRange:range]];
        }
    }

    NSUInteger documentRevision = 0;
    NSUInteger textEpoch = 0;
    NSUInteger selectionEpoch = 0;
    NSUInteger checkingEpoch = 0;
    valid = valid &&
        IDInlinePredictionIsInteger(
            payload[@"documentRevision"], &documentRevision) &&
        IDInlinePredictionIsInteger(payload[@"textEpoch"], &textEpoch) &&
        IDInlinePredictionIsInteger(
            payload[@"selectionEpoch"], &selectionEpoch) &&
        IDInlinePredictionIsInteger(
            payload[@"checkingEpoch"], &checkingEpoch);
    if (!valid) {
        if (error != NULL) {
            *error = IDInlinePredictionError(
                IDInlinePredictionStatusErrorInvalidField,
                @"Inline-prediction status contains an invalid field");
        }
        return nil;
    }

    IDInlinePredictionStatus *status = [IDInlinePredictionStatus new];
    status.canonical = payload[@"canonical"];
    status.blocks = payload[@"blocks"];
    status.selection = selection;
    status.affinity = payload[@"affinity"];
    status.markedRange = markedRange;
    status.structuralNewlineLocations = newlines.copy;
    status.checkingRanges = checkingRanges.copy;
    status.predictionDescriptor = payload[@"predictionDescriptor"];
    status.temporaryRenderingDescriptors =
        payload[@"temporaryRenderingDescriptors"];
    status.mutationTrace = payload[@"mutationTrace"];
    status.eventTrace = payload[@"eventTrace"];
    status.keyboardState = payload[@"keyboardState"];
    status.predictionGeometry = payload[@"predictionGeometry"];
    status.coordinateSpaceIdentity = payload[@"coordinateSpaceIdentity"];
    status.documentRevision = documentRevision;
    status.textEpoch = textEpoch;
    status.selectionEpoch = selectionEpoch;
    status.checkingEpoch = checkingEpoch;
    status.firstResponder = firstResponder;
    return status;
}

static BOOL IDInlinePredictionWaitForKeyboardReady(
    XCUIApplication *application, NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        XCUIElement *key =
            [application.keyboards.keys matchingIdentifier:@"i"].firstMatch;
        if (key.exists && key.isHittable) return YES;
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    return NO;
}

XCUIApplication *IDLaunchStockInlinePredictionScenario(
    IDInlinePredictionRow *row) {
    NSArray<NSString *> *locations =
        @[@"interior", @"before-boundary", @"after-boundary"];
    XCUIApplication *application = [[XCUIApplication alloc]
        initWithBundleIdentifier:@"com.inputdec.stockoracle"];
    [application terminate];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)", @"-AppleLocale", @"en_US",
    ];
    application.launchEnvironment = @{
        @"IDStockEditorFrame": NSStringFromCGRect(
            CGRectMake(16, 198, 370, 360)),
        @"IDStockTouchScenario":
            [@"inline-prediction-" stringByAppendingString:
                locations[(NSUInteger)row.location]],
        @"IDInlinePredictionDecision": row.identifier,
        @"IDForceEnglishUSInputMode": @"1",
    };
    [application launch];
    if (!IDInlinePredictionWaitForKeyboardReady(application, 5.0)) {
        [application terminate];
        [application launch];
        (void)IDInlinePredictionWaitForKeyboardReady(application, 5.0);
    }
    return application;
}

XCUIApplication *IDLaunchCustomInlinePredictionScenario(
    IDInlinePredictionRow *row) {
    NSArray<NSString *> *locations =
        @[@"interior", @"before-boundary", @"after-boundary"];
    XCUIApplication *application = [XCUIApplication new];
    [application terminate];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)", @"-AppleLocale", @"en_US",
        @"--id-block-ui-scenario",
        [@"inline-prediction-" stringByAppendingString:
            locations[(NSUInteger)row.location]],
    ];
    application.launchEnvironment = @{
        @"IDInlinePredictionDecision": row.identifier,
        @"IDForceEnglishUSInputMode": @"1",
    };
    [application launch];
    if (!IDInlinePredictionWaitForKeyboardReady(application, 5.0)) {
        [application terminate];
        [application launch];
        (void)IDInlinePredictionWaitForKeyboardReady(application, 5.0);
    }
    return application;
}

static NSDictionary<NSString *, id> *IDInlinePredictionFixture(void) {
    NSBundle *bundle = [NSBundle bundleForClass:IDInlinePredictionRunResult.class];
    NSURL *URL = [bundle URLForResource:@"inline-prediction-stock-contract-v1"
                          withExtension:@"json"
                           subdirectory:@"Fixtures"];
    if (URL == nil) {
        URL = [bundle URLForResource:@"inline-prediction-stock-contract-v1"
                       withExtension:@"json"];
    }
    NSData *data = URL == nil ? nil : [NSData dataWithContentsOfURL:URL];
    id object = data == nil ? nil :
        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [object isKindOfClass:NSDictionary.class] ? object : nil;
}

static BOOL IDInlinePredictionFixtureIsValid(
    NSDictionary<NSString *, id> *fixture, NSString **failure) {
    NSSet *expectedKeys = [NSSet setWithArray:@[
        @"schema", @"runtime", @"typedPrefix", @"offeredText",
        @"acceptAction", @"dismissAction", @"postDismissText",
    ]];
    if (fixture == nil ||
        ![[NSSet setWithArray:fixture.allKeys] isEqualToSet:expectedKeys] ||
        ![fixture[@"schema"] isEqual:@1]) {
        if (failure != NULL) *failure = @"fixture keys/schema are invalid";
        return NO;
    }
    NSDictionary *runtime = fixture[@"runtime"];
    if (![runtime isKindOfClass:NSDictionary.class] ||
        ![[NSSet setWithArray:runtime.allKeys] isEqualToSet:
            [NSSet setWithArray:@[@"osVersion", @"osBuild", @"locale"]]] ||
        ![runtime isEqual:@{
            @"osVersion": @"26.5", @"osBuild": @"23F73",
            @"locale": @"en_US",
        }]) {
        if (failure != NULL) *failure = @"fixture runtime is not iOS 26.5/23F73/en_US";
        return NO;
    }
    for (NSString *key in @[@"typedPrefix", @"offeredText",
                             @"postDismissText"]) {
        if (![fixture[key] isKindOfClass:NSString.class] ||
            [fixture[key] length] == 0) {
            if (failure != NULL) {
                *failure = [NSString stringWithFormat:
                    @"fixture %@ must be a nonempty string", key];
            }
            return NO;
        }
    }
    for (NSString *key in @[@"acceptAction", @"dismissAction"]) {
        NSDictionary *action = fixture[key];
        if (![action isKindOfClass:NSDictionary.class] ||
            ![[NSSet setWithArray:action.allKeys] isEqualToSet:
                [NSSet setWithArray:@[@"kind", @"value"]]] ||
            ![action[@"kind"] isKindOfClass:NSString.class] ||
            [action[@"kind"] length] == 0 ||
            ![action[@"value"] isKindOfClass:NSString.class] ||
            [action[@"value"] length] == 0) {
            if (failure != NULL) {
                *failure = [NSString stringWithFormat:
                    @"fixture %@ action is invalid", key];
            }
            return NO;
        }
    }
    return YES;
}

static IDInlinePredictionPhaseSnapshot *IDCaptureInlinePredictionPhase(
    XCTestCase *testCase, XCUIApplication *application, NSString *phase) {
    XCUIElement *statusElement =
        [application descendantsMatchingType:XCUIElementTypeAny]
            [@"inline-prediction-status"];
    if (![statusElement waitForExistenceWithTimeout:4.0]) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:@"Inline-prediction status element is absent"]];
    }
    NSString *serialized = [statusElement.value isKindOfClass:NSString.class]
        ? statusElement.value : @"{}";
    NSError *parseError = nil;
    IDInlinePredictionStatus *status =
        IDParseInlinePredictionStatus(serialized, &parseError);
    NSLog(@"ID_INLINE_PREDICTION_STATUS phase=%@ payload=%@", phase,
          serialized);
    if (status == nil) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:[NSString stringWithFormat:
                @"Invalid inline-prediction status for %@: %@ raw=%@", phase,
                parseError.localizedDescription, serialized]]];
    }
    NSString *screenshotName =
        [NSString stringWithFormat:@"inline-prediction-%@", phase];
    XCUIScreenshot *screen = XCUIScreen.mainScreen.screenshot;
    XCTAttachment *screenshot =
        [XCTAttachment attachmentWithScreenshot:screen];
    screenshot.name = IDTextInputBatchAttachmentName(screenshotName);
    screenshot.lifetime = XCTAttachmentLifetimeKeepAlways;
    [testCase addAttachment:screenshot];
    XCTAttachment *statusAttachment =
        [XCTAttachment attachmentWithString:serialized];
    statusAttachment.name = IDTextInputBatchAttachmentName(
        [NSString stringWithFormat:@"inline-prediction-%@-status", phase]);
    statusAttachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [testCase addAttachment:statusAttachment];
    IDInlinePredictionPhaseSnapshot *snapshot =
        [IDInlinePredictionPhaseSnapshot new];
    snapshot.phase = phase;
    snapshot.status = status;
    snapshot.screenshotName = screenshotName;
    snapshot.screenshotPNGData = screen.PNGRepresentation;
    return snapshot;
}

static BOOL IDInlinePredictionWaitForOffer(
    XCUIApplication *application, NSTimeInterval timeout) {
    XCUIElement *statusElement =
        [application descendantsMatchingType:XCUIElementTypeAny]
            [@"inline-prediction-status"];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        NSString *serialized =
            [statusElement.value isKindOfClass:NSString.class]
                ? statusElement.value : @"{}";
        IDInlinePredictionStatus *status =
            IDParseInlinePredictionStatus(serialized, NULL);
        if ([status.predictionDescriptor[@"present"] boolValue]) return YES;
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    return NO;
}

static IDInlinePredictionStatus *IDInlinePredictionCurrentStatus(
    XCUIApplication *application) {
    XCUIElement *statusElement =
        [application descendantsMatchingType:XCUIElementTypeAny]
            [@"inline-prediction-status"];
    NSString *serialized =
        [statusElement.value isKindOfClass:NSString.class]
            ? statusElement.value : @"{}";
    return IDParseInlinePredictionStatus(serialized, NULL);
}

static BOOL IDInlinePredictionWaitForStableOffer(
    XCUIApplication *application, NSString *expectedDisplayText,
    NSTimeInterval stableDuration, NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    NSDate *stableSince = nil;
    do {
        IDInlinePredictionStatus *status =
            IDInlinePredictionCurrentStatus(application);
        BOOL stable =
            [status.predictionDescriptor[@"present"] boolValue] &&
            [status.predictionDescriptor[@"displayText"]
                isEqual:expectedDisplayText] &&
            status.selection.location == status.markedRange.location &&
            status.markedRange.length > 0 &&
            [status.predictionGeometry[@"width"] doubleValue] > 0 &&
            [status.predictionGeometry[@"height"] doubleValue] > 0;
        if (stable) {
            if (stableSince == nil) stableSince = NSDate.date;
            if (-stableSince.timeIntervalSinceNow >= stableDuration) {
                return YES;
            }
        } else {
            stableSince = nil;
        }
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    return NO;
}

static BOOL IDInlinePredictionWaitForActionTransition(
    XCUIApplication *application, BOOL shouldRemainPresent,
    NSString *previousDisplayText, NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        IDInlinePredictionStatus *status =
            IDInlinePredictionCurrentStatus(application);
        BOOL present =
            [status.predictionDescriptor[@"present"] boolValue];
        NSString *displayText =
            status.predictionDescriptor[@"displayText"];
        if (shouldRemainPresent) {
            if (present && displayText.length > 0 &&
                ![displayText isEqual:previousDisplayText]) {
                return YES;
            }
        } else if (!present && status.markedRange.location == NSNotFound) {
            return YES;
        }
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    return NO;
}

static void IDInlinePredictionAttachHierarchy(
    XCTestCase *testCase, XCUIApplication *application, NSString *name) {
    XCTAttachment *attachment = [XCTAttachment attachmentWithString:
        application.debugDescription ?: @"unavailable"];
    attachment.name = IDTextInputBatchAttachmentName(name);
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [testCase addAttachment:attachment];
}

IDInlinePredictionLifecycleAttempt *IDAttemptInlinePredictionLifecycle(
    XCTestCase *testCase, XCUIApplication *application,
    IDInlinePredictionRow *row) {
    XCUIElementQuery *elements =
        [application descendantsMatchingType:XCUIElementTypeAny];
    XCUIElement *stockEditor = elements[@"stock-text-view"];
    XCUIElement *editor =
        stockEditor.exists ? stockEditor : elements[@"block-text-view"];
    XCUIElement *status = elements[@"inline-prediction-status"];
    if (![editor waitForExistenceWithTimeout:4.0] ||
        ![status waitForExistenceWithTimeout:4.0]) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:@"Inline-prediction fixture did not launch"]];
    }

    NSDictionary<NSString *, id> *fixture = IDInlinePredictionFixture();
    NSString *fixtureFailure = nil;
    if (!IDInlinePredictionFixtureIsValid(fixture, &fixtureFailure)) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:[NSString stringWithFormat:
                @"Invalid inline-prediction stock fixture: %@",
                fixtureFailure ?: @"unknown error"]]];
        IDInlinePredictionRunResult *failedResult =
            [IDInlinePredictionRunResult new];
        failedResult.row = row;
        failedResult.phases = @[];
        IDInlinePredictionLifecycleAttempt *attempt =
            [IDInlinePredictionLifecycleAttempt new];
        attempt.offerReady = YES;
        attempt.result = failedResult;
        return attempt;
    }
    NSString *typedPrefix = fixture[@"typedPrefix"];

    NSMutableArray<IDInlinePredictionPhaseSnapshot *> *phases =
        [NSMutableArray array];
    [phases addObject:IDCaptureInlinePredictionPhase(
        testCase, application, @"baseline")];
    if (!IDHIDTryTypeSoftwareKeyboardText(application, typedPrefix)) {
        IDInlinePredictionLifecycleAttempt *attempt =
            [IDInlinePredictionLifecycleAttempt new];
        attempt.offerReady = NO;
        attempt.result = nil;
        return attempt;
    }
    BOOL offerReady = IDInlinePredictionWaitForOffer(application, 8.0);
    IDInlinePredictionPhaseSnapshot *offered =
        IDCaptureInlinePredictionPhase(testCase, application, @"offered");
    [phases addObject:offered];
    if (!offerReady) {
        IDInlinePredictionAttachHierarchy(
            testCase, application,
            @"inline-prediction-offer-missing-hierarchy");
        IDInlinePredictionLifecycleAttempt *attempt =
            [IDInlinePredictionLifecycleAttempt new];
        attempt.offerReady = NO;
        attempt.result = nil;
        return attempt;
    } else if (![offered.status.predictionDescriptor[@"displayText"]
                    isEqual:fixture[@"offeredText"]] ||
               ![offered.status.predictionDescriptor[
                    @"accessibilityIdentity"] isEqual:@"marked-text"] ||
               offered.status.markedRange.location == NSNotFound ||
               offered.status.markedRange.length == 0 ||
               [offered.status.predictionGeometry[@"width"] doubleValue] <= 0 ||
               [offered.status.predictionGeometry[@"height"] doubleValue] <= 0) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:[NSString stringWithFormat:
                @"Native offer does not match frozen iOS 26.5 contract: %@",
                offered.status.predictionDescriptor]]];
    }

    NSDictionary<NSString *, id> *action =
        row.decision == IDInlinePredictionDecisionDismissThenType
            ? fixture[@"dismissAction"] : fixture[@"acceptAction"];
    NSString *actionKind =
        [action[@"kind"] isKindOfClass:NSString.class] ? action[@"kind"] : @"";
    NSString *actionValue =
        [action[@"value"] isKindOfClass:NSString.class] ? action[@"value"] : @"";
    if ([actionKind isEqualToString:@"uikit-accept-inline-completion"] &&
        [actionValue isEqualToString:
            @"acceptTextCompletionWithInteraction:wordTerminator:"]) {
        __block NSString *previousDisplayText =
            offered.status.predictionDescriptor[@"displayText"];
        __block BOOL settled = NO;
        __block BOOL failedToAdvance = NO;
        for (NSUInteger step = 0; step < 4 && !settled; step += 1) {
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFSTR("com.inputdec.inline-prediction.accept"),
                NULL, NULL, true);
            NSDate *deadline =
                [NSDate dateWithTimeIntervalSinceNow:4.0];
            BOOL advanced = NO;
            do {
                IDInlinePredictionStatus *status =
                    IDInlinePredictionCurrentStatus(application);
                BOOL present =
                    [status.predictionDescriptor[@"present"] boolValue];
                NSString *displayText =
                    status.predictionDescriptor[@"displayText"];
                if (!present &&
                    status.markedRange.location == NSNotFound) {
                    [NSThread sleepForTimeInterval:0.50];
                    IDInlinePredictionStatus *confirmation =
                        IDInlinePredictionCurrentStatus(application);
                    BOOL confirmedPresent = [confirmation
                        .predictionDescriptor[@"present"] boolValue];
                    if (!confirmedPresent &&
                        confirmation.markedRange.location == NSNotFound) {
                        settled = YES;
                        advanced = YES;
                        break;
                    }
                    NSString *confirmedDisplayText = confirmation
                        .predictionDescriptor[@"displayText"];
                    if (confirmedPresent &&
                        confirmedDisplayText.length > 0 &&
                        ![confirmedDisplayText
                            isEqual:previousDisplayText]) {
                        previousDisplayText = confirmedDisplayText;
                        advanced = YES;
                        break;
                    }
                }
                if (present && displayText.length > 0 &&
                    ![displayText isEqual:previousDisplayText]) {
                    previousDisplayText = displayText;
                    advanced = YES;
                    break;
                }
                [NSThread sleepForTimeInterval:0.05];
            } while (deadline.timeIntervalSinceNow > 0);
            if (!advanced) {
                failedToAdvance = YES;
                break;
            }
            if (!settled) {
                // The rendered marked suffix changes before the completion
                // controller publishes its replacement backing object.
                // Avoid invoking the next UIKit partial-accept step against
                // that stale object.
                [NSThread sleepForTimeInterval:0.50];
            }
        }
        if (!settled || failedToAdvance) {
            [testCase recordIssue:[[XCTIssue alloc]
                initWithType:XCTIssueTypeAssertionFailure
                compactDescription:
                    @"UIKit did not fully accept the marked inline completion"]];
        }
    } else if ([actionKind isEqualToString:
            @"uikit-remove-inline-text-completion"] &&
        [actionValue isEqualToString:@"removeInlineTextCompletionPrompt"]) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFSTR("com.inputdec.inline-prediction.dismiss"),
            NULL, NULL, true);
        if (!IDInlinePredictionWaitForActionTransition(
                application, NO,
                offered.status.predictionDescriptor[@"displayText"], 4.0)) {
            [testCase recordIssue:[[XCTIssue alloc]
                initWithType:XCTIssueTypeAssertionFailure
                compactDescription:
                    @"UIKit did not remove the marked inline completion"]];
        }
    } else if ([actionKind isEqualToString:@"prediction-geometry-tap"] &&
        ([actionValue isEqualToString:@"center"] ||
         [actionValue isEqualToString:@"before-start"])) {
        NSDictionary<NSString *, id> *geometry =
            offered.status.predictionGeometry;
        CGFloat predictionX = [actionValue isEqualToString:@"before-start"]
            ? [geometry[@"x"] doubleValue] - 3.0
            : [geometry[@"x"] doubleValue] +
                [geometry[@"width"] doubleValue] * 0.5;
        CGFloat predictionY = [geometry[@"y"] doubleValue] +
            [geometry[@"height"] doubleValue] * 0.5;
        XCUICoordinate *origin =
            [editor coordinateWithNormalizedOffset:CGVectorMake(0, 0)];
        [[origin coordinateWithOffset:
            CGVectorMake(predictionX, predictionY)] tap];
        if (!IDInlinePredictionWaitForActionTransition(
                application, NO,
                offered.status.predictionDescriptor[@"displayText"], 4.0)) {
            [testCase recordIssue:[[XCTIssue alloc]
                initWithType:XCTIssueTypeAssertionFailure
                compactDescription:
                    @"Prediction geometry tap did not settle marked completion"]];
        }
    } else if ([actionKind isEqualToString:
                   @"software-keyboard-key-sequence"]) {
        NSArray<NSString *> *keys =
            [actionValue componentsSeparatedByString:@","];
        if (!IDInlinePredictionWaitForStableOffer(
                application, fixture[@"offeredText"], 0.50, 4.0)) {
            [testCase recordIssue:[[XCTIssue alloc]
                initWithType:XCTIssueTypeAssertionFailure
                compactDescription:
                    @"Native inline prediction did not remain stable before acceptance"]];
        }
        __block NSString *previousDisplayText =
            offered.status.predictionDescriptor[@"displayText"];
        [keys enumerateObjectsUsingBlock:
            ^(NSString *key, NSUInteger index, BOOL *stop) {
            (void)stop;
            IDHIDTapSoftwareKeyboardKey(testCase, application, key);
            BOOL remains = index + 1 < keys.count;
            if (remains) {
                // UIKit treats the first Space as typing through the leading
                // predicted space. Do not send the accepting Space until the
                // completion controller has published the advanced caret and
                // remaining marked suffix; a fixed delay can land either
                // before that transaction or after the suffix is dismissed.
                NSDate *deadline =
                    [NSDate dateWithTimeIntervalSinceNow:4.0];
                BOOL readyForNextKey = NO;
                do {
                    IDInlinePredictionStatus *current =
                        IDInlinePredictionCurrentStatus(application);
                    BOOL present = [current.predictionDescriptor[
                        @"present"] boolValue];
                    if (present &&
                        current.selection.location >
                            offered.status.selection.location &&
                        current.markedRange.location ==
                            current.selection.location &&
                        current.markedRange.length > 0) {
                        previousDisplayText =
                            current.predictionDescriptor[@"displayText"];
                        readyForNextKey = YES;
                        break;
                    }
                    [NSThread sleepForTimeInterval:0.02];
                } while (deadline.timeIntervalSinceNow > 0);
                if (!readyForNextKey) {
                    (void)IDCaptureInlinePredictionPhase(
                        testCase, application,
                        @"typedThroughTimeout");
                    [testCase recordIssue:[[XCTIssue alloc]
                        initWithType:XCTIssueTypeAssertionFailure
                        compactDescription:
                            @"Inline prediction did not publish its typed-through suffix"]];
                    *stop = YES;
                }
            } else if (!IDInlinePredictionWaitForActionTransition(
                    application, NO, previousDisplayText, 4.0)) {
                [testCase recordIssue:[[XCTIssue alloc]
                    initWithType:XCTIssueTypeAssertionFailure
                    compactDescription:[NSString stringWithFormat:
                        @"Inline prediction did not settle after key %lu/%lu",
                        (unsigned long)(index + 1),
                        (unsigned long)keys.count]]];
            }
        }];
    } else {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:[NSString stringWithFormat:
                @"Unsupported inline-prediction action %@:%@",
                actionKind, actionValue]]];
    }
    [phases addObject:IDCaptureInlinePredictionPhase(
        testCase, application, @"decision")];
    [NSThread sleepForTimeInterval:0.05];
    [phases addObject:IDCaptureInlinePredictionPhase(
        testCase, application, @"immediate")];
    [NSThread sleepForTimeInterval:0.50];
    [phases addObject:IDCaptureInlinePredictionPhase(
        testCase, application, @"quiesced")];
    if (row.decision == IDInlinePredictionDecisionDismissThenType) {
        NSString *postDismissText =
            [fixture[@"postDismissText"] isKindOfClass:NSString.class]
                ? fixture[@"postDismissText"] : @"x";
        IDHIDTypeSoftwareKeyboardText(
            testCase, application, postDismissText);
        [phases addObject:IDCaptureInlinePredictionPhase(
            testCase, application, @"postDismissTyping")];
    } else if (row.decision ==
               IDInlinePredictionDecisionAcceptThenDelete) {
        IDHIDTapSoftwareKeyboardKey(testCase, application, @"delete");
        [phases addObject:IDCaptureInlinePredictionPhase(
            testCase, application, @"firstBackspace")];
        IDHIDTapSoftwareKeyboardKey(testCase, application, @"delete");
        [phases addObject:IDCaptureInlinePredictionPhase(
            testCase, application, @"secondBackspace")];
    }

    IDInlinePredictionRunResult *result =
        [IDInlinePredictionRunResult new];
    result.row = row;
    result.phases = phases.copy;
    IDInlinePredictionLifecycleAttempt *attempt =
        [IDInlinePredictionLifecycleAttempt new];
    attempt.offerReady = YES;
    attempt.result = result;
    return attempt;
}

IDInlinePredictionRunResult *IDRunInlinePredictionLifecycle(
    XCTestCase *testCase, XCUIApplication *application,
    IDInlinePredictionRow *row) {
    IDInlinePredictionLifecycleAttempt *attempt =
        IDAttemptInlinePredictionLifecycle(testCase, application, row);
    if (!attempt.offerReady) {
        [testCase recordIssue:[[XCTIssue alloc]
            initWithType:XCTIssueTypeAssertionFailure
            compactDescription:@"Expected native inline prediction was absent"]];
        IDInlinePredictionRunResult *result =
            [IDInlinePredictionRunResult new];
        result.row = row;
        result.phases = @[];
        return result;
    }
    return attempt.result;
}
