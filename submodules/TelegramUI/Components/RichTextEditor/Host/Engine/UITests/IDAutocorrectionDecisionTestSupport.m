#import "IDAutocorrectionDecisionTestSupport.h"
#import "IDHIDEventTestSupport.h"
#import "IDTextInputBatchTestSupport.h"

NSString *const IDAutocorrectionStatusErrorDomain =
    @"com.inputdec.tests.autocorrection-status";

typedef NS_ENUM(NSInteger, IDAutocorrectionStatusErrorCode) {
    IDAutocorrectionStatusErrorInvalidJSON = 1,
    IDAutocorrectionStatusErrorInvalidSchema,
    IDAutocorrectionStatusErrorInvalidField,
    IDAutocorrectionStatusErrorCandidateUnavailable,
};

static NSError *IDAutocorrectionError(IDAutocorrectionStatusErrorCode code,
                                      NSString *description) {
    return [NSError errorWithDomain:IDAutocorrectionStatusErrorDomain code:code
                            userInfo:@{NSLocalizedDescriptionKey: description}];
}

@interface IDAutocorrectionDecisionRow ()
@property(nonatomic, readwrite) IDAutocorrectionLocation location;
@property(nonatomic, readwrite) IDAutocorrectionDecision decision;
@property(nonatomic, copy, readwrite) NSString *identifier;
- (instancetype)initWithLocation:(IDAutocorrectionLocation)location
                         decision:(IDAutocorrectionDecision)decision
                       identifier:(NSString *)identifier;
@end

@implementation IDAutocorrectionDecisionRow

- (instancetype)initWithLocation:(IDAutocorrectionLocation)location
                         decision:(IDAutocorrectionDecision)decision
                       identifier:(NSString *)identifier {
    self = [super init];
    if (self == nil) return nil;
    _location = location;
    _decision = decision;
    _identifier = [identifier copy];
    return self;
}

@end

@interface IDAutocorrectionStatus ()
@property(nonatomic, copy, readwrite) NSString *canonical;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *blocks;
@property(nonatomic, readwrite) NSRange selection;
@property(nonatomic, copy, readwrite) NSString *affinity;
@property(nonatomic, readwrite) NSRange markedRange;
@property(nonatomic, copy, readwrite) NSArray<NSNumber *> *structuralNewlineLocations;
@property(nonatomic, copy, readwrite) NSArray<NSValue *> *checkingRanges;
@property(nonatomic, copy, readwrite) NSDictionary<NSString *, id> *candidateDescriptor;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *mutationTrace;
@property(nonatomic, copy, readwrite) NSArray<NSString *> *eventTrace;
@property(nonatomic, copy, readwrite) NSDictionary<NSString *, id> *keyboardState;
@property(nonatomic, copy, readwrite) NSDictionary<NSString *, id> *correctionGeometry;
@property(nonatomic, copy, readwrite) NSString *coordinateSpaceIdentity;
@property(nonatomic, readwrite) NSUInteger documentRevision;
@property(nonatomic, readwrite) NSUInteger textEpoch;
@property(nonatomic, readwrite) NSUInteger selectionEpoch;
@property(nonatomic, readwrite) NSUInteger checkingEpoch;
@property(nonatomic, readwrite, getter=isFirstResponder) BOOL firstResponder;
@end

@implementation IDAutocorrectionStatus
@end

@interface IDAutocorrectionPhaseSnapshot ()
@property(nonatomic, copy, readwrite) NSString *phase;
@property(nonatomic, strong, readwrite) IDAutocorrectionStatus *status;
@property(nonatomic, copy, readwrite) NSString *screenshotName;
@end

@implementation IDAutocorrectionPhaseSnapshot
@end

@interface IDAutocorrectionRunResult ()
@property(nonatomic, strong, readwrite) IDAutocorrectionDecisionRow *row;
@property(nonatomic, copy, readwrite) NSArray<IDAutocorrectionPhaseSnapshot *> *phases;
@end

@implementation IDAutocorrectionRunResult
@end

NSArray<IDAutocorrectionDecisionRow *> *IDAutocorrectionDecisionMatrix(void) {
    static NSArray<IDAutocorrectionDecisionRow *> *rows;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray<NSString *> *locations = @[@"interior", @"before-boundary",
                                           @"after-boundary"];
        NSArray<NSString *> *decisions = @[@"accept-space", @"accept-punctuation",
            @"accept-candidate", @"reject-precommit", @"undo-space",
            @"undo-punctuation", @"undo-candidate"];
        NSMutableArray<IDAutocorrectionDecisionRow *> *result = [NSMutableArray array];
        for (NSUInteger location = 0; location < locations.count; location += 1) {
            for (NSUInteger decision = 0; decision < decisions.count; decision += 1) {
                [result addObject:[[IDAutocorrectionDecisionRow alloc]
                    initWithLocation:(IDAutocorrectionLocation)location
                            decision:(IDAutocorrectionDecision)decision
                          identifier:[NSString stringWithFormat:@"%@-%@",
                                      locations[location], decisions[decision]]]];
            }
        }
        rows = result.copy;
    });
    return rows;
}

NSArray<IDAutocorrectionDecisionRow *> *
IDAutocorrectionDecisionRowsMatchingIdentifier(NSString *identifier) {
    NSArray<IDAutocorrectionDecisionRow *> *rows =
        IDAutocorrectionDecisionMatrix();
    if (identifier.length == 0) return rows;
    NSPredicate *predicate = [NSPredicate predicateWithBlock:
        ^BOOL(IDAutocorrectionDecisionRow *row, NSDictionary *bindings) {
            (void)bindings;
            return [row.identifier isEqualToString:identifier];
        }];
    return [rows filteredArrayUsingPredicate:predicate];
}

static BOOL IDAutocorrectionIsInteger(id value, NSUInteger *result) {
    if (![value isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) return NO;
    NSDecimal decimal = [value decimalValue];
    if (NSDecimalIsNotANumber(&decimal)) return NO;
    NSDecimal integral = {0};
    NSDecimalRound(&integral, &decimal, 0, NSRoundPlain);
    NSDecimal zero = [@0 decimalValue];
    NSDecimal maximum = [[NSNumber numberWithUnsignedInteger:NSUIntegerMax]
        decimalValue];
    if (NSDecimalCompare(&decimal, &integral) != NSOrderedSame ||
        NSDecimalCompare(&decimal, &zero) == NSOrderedAscending ||
        NSDecimalCompare(&decimal, &maximum) == NSOrderedDescending) return NO;
    if (result != NULL) *result = [(NSNumber *)value unsignedIntegerValue];
    return YES;
}

static BOOL IDAutocorrectionIsBoolean(id value, BOOL *result) {
    if (![value isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID()) return NO;
    if (result != NULL) *result = [value boolValue];
    return YES;
}

static BOOL IDAutocorrectionExactKeys(NSDictionary *dictionary,
                                      NSArray<NSString *> *keys) {
    return [dictionary isKindOfClass:NSDictionary.class] &&
        [[NSSet setWithArray:dictionary.allKeys]
            isEqualToSet:[NSSet setWithArray:keys]];
}

static BOOL IDAutocorrectionParseRange(id value, NSRange *result) {
    if (!IDAutocorrectionExactKeys(value, @[@"location", @"length"])) return NO;
    NSUInteger location = 0;
    NSUInteger length = 0;
    if (!IDAutocorrectionIsInteger(value[@"location"], &location) ||
        !IDAutocorrectionIsInteger(value[@"length"], &length)) return NO;
    if (location != NSNotFound && length > NSUIntegerMax - location) return NO;
    if (result != NULL) *result = NSMakeRange(location, length);
    return YES;
}

static BOOL IDAutocorrectionStringArray(id value) {
    if (![value isKindOfClass:NSArray.class]) return NO;
    for (id item in value) if (![item isKindOfClass:NSString.class]) return NO;
    return YES;
}

static BOOL IDAutocorrectionCandidateDescriptorIsValid(id value) {
    if (!IDAutocorrectionExactKeys(
            value, @[@"candidate", @"original", @"actionable"])) return NO;
    BOOL actionable = NO;
    return [value[@"candidate"] isKindOfClass:NSString.class] &&
        [value[@"original"] isKindOfClass:NSString.class] &&
        IDAutocorrectionIsBoolean(value[@"actionable"], &actionable);
}

static BOOL IDAutocorrectionKeyboardStateIsValid(id value) {
    if (!IDAutocorrectionExactKeys(
            value, @[@"visible", @"locale", @"learnedOriginal"])) return NO;
    BOOL visible = NO;
    BOOL learnedOriginal = NO;
    return IDAutocorrectionIsBoolean(value[@"visible"], &visible) &&
        [value[@"locale"] isKindOfClass:NSString.class] &&
        IDAutocorrectionIsBoolean(value[@"learnedOriginal"], &learnedOriginal);
}

static BOOL IDAutocorrectionGeometryIsValid(id value) {
    if (!IDAutocorrectionExactKeys(value,
            @[@"x", @"y", @"width", @"height"])) return NO;
    for (NSString *key in @[@"x", @"y", @"width", @"height"]) {
        id number = value[key];
        if (![number isKindOfClass:NSNumber.class] ||
            CFGetTypeID((__bridge CFTypeRef)number) == CFBooleanGetTypeID() ||
            !isfinite([number doubleValue])) return NO;
    }
    return YES;
}

IDAutocorrectionStatus *IDParseAutocorrectionStatus(NSString *serializedStatus,
                                                     NSError **error) {
    if (error != NULL) *error = nil;
    NSData *data = [serializedStatus dataUsingEncoding:NSUTF8StringEncoding];
    id object = data == nil ? nil :
        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray<NSString *> *keys = @[@"schema", @"scenario", @"canonical", @"blocks",
        @"selection", @"affinity", @"markedRange", @"structuralNewlineLocations",
        @"checkingRanges", @"candidateDescriptor", @"mutationTrace", @"eventTrace",
        @"keyboardState", @"correctionGeometry", @"coordinateSpaceIdentity",
        @"documentRevision", @"textEpoch", @"selectionEpoch", @"checkingEpoch",
        @"firstResponder"];
    if (!IDAutocorrectionExactKeys(object, keys)) {
        if (error != NULL) *error = IDAutocorrectionError(
            IDAutocorrectionStatusErrorInvalidJSON,
            @"Autocorrection status must be a complete versioned JSON object");
        return nil;
    }
    NSDictionary<NSString *, id> *payload = object;
    NSUInteger schema = 0;
    if (!IDAutocorrectionIsInteger(payload[@"schema"], &schema) || schema != 1) {
        if (error != NULL) *error = IDAutocorrectionError(
            IDAutocorrectionStatusErrorInvalidSchema,
            @"Autocorrection status schema must equal 1");
        return nil;
    }
    NSRange selection = {0};
    NSRange markedRange = {0};
    BOOL firstResponder = NO;
    BOOL valid = [payload[@"scenario"] isKindOfClass:NSString.class] &&
        [payload[@"scenario"] length] > 0 &&
        [payload[@"canonical"] isKindOfClass:NSString.class] &&
        IDAutocorrectionStringArray(payload[@"blocks"]) &&
        IDAutocorrectionParseRange(payload[@"selection"], &selection) &&
        IDAutocorrectionParseRange(payload[@"markedRange"], &markedRange) &&
        ([payload[@"affinity"] isEqual:@"forward"] ||
         [payload[@"affinity"] isEqual:@"backward"]) &&
        [payload[@"structuralNewlineLocations"] isKindOfClass:NSArray.class] &&
        [payload[@"checkingRanges"] isKindOfClass:NSArray.class] &&
        IDAutocorrectionCandidateDescriptorIsValid(
            payload[@"candidateDescriptor"]) &&
        IDAutocorrectionStringArray(payload[@"mutationTrace"]) &&
        IDAutocorrectionStringArray(payload[@"eventTrace"]) &&
        IDAutocorrectionKeyboardStateIsValid(payload[@"keyboardState"]) &&
        IDAutocorrectionGeometryIsValid(payload[@"correctionGeometry"]) &&
        [payload[@"coordinateSpaceIdentity"] isKindOfClass:NSString.class] &&
        [payload[@"coordinateSpaceIdentity"] length] > 0 &&
        IDAutocorrectionIsBoolean(payload[@"firstResponder"], &firstResponder);
    NSMutableArray<NSNumber *> *newlines = [NSMutableArray array];
    for (id value in payload[@"structuralNewlineLocations"]) {
        NSUInteger offset = 0;
        if (!IDAutocorrectionIsInteger(value, &offset)) valid = NO;
        else [newlines addObject:@(offset)];
    }
    NSMutableArray<NSValue *> *checkingRanges = [NSMutableArray array];
    for (id value in payload[@"checkingRanges"]) {
        NSRange range = {0};
        if (!IDAutocorrectionParseRange(value, &range)) valid = NO;
        else [checkingRanges addObject:[NSValue valueWithRange:range]];
    }
    NSUInteger documentRevision = 0, textEpoch = 0, selectionEpoch = 0,
        checkingEpoch = 0;
    valid = valid &&
        IDAutocorrectionIsInteger(payload[@"documentRevision"], &documentRevision) &&
        IDAutocorrectionIsInteger(payload[@"textEpoch"], &textEpoch) &&
        IDAutocorrectionIsInteger(payload[@"selectionEpoch"], &selectionEpoch) &&
        IDAutocorrectionIsInteger(payload[@"checkingEpoch"], &checkingEpoch);
    if (!valid) {
        if (error != NULL) *error = IDAutocorrectionError(
            IDAutocorrectionStatusErrorInvalidField,
            @"Autocorrection status contains an invalid field");
        return nil;
    }
    IDAutocorrectionStatus *status = [IDAutocorrectionStatus new];
    status.canonical = payload[@"canonical"];
    status.blocks = payload[@"blocks"];
    status.selection = selection;
    status.affinity = payload[@"affinity"];
    status.markedRange = markedRange;
    status.structuralNewlineLocations = newlines.copy;
    status.checkingRanges = checkingRanges.copy;
    status.candidateDescriptor = payload[@"candidateDescriptor"];
    status.mutationTrace = payload[@"mutationTrace"];
    status.eventTrace = payload[@"eventTrace"];
    status.keyboardState = payload[@"keyboardState"];
    status.correctionGeometry = payload[@"correctionGeometry"];
    status.coordinateSpaceIdentity = payload[@"coordinateSpaceIdentity"];
    status.documentRevision = documentRevision;
    status.textEpoch = textEpoch;
    status.selectionEpoch = selectionEpoch;
    status.checkingEpoch = checkingEpoch;
    status.firstResponder = firstResponder;
    return status;
}

BOOL IDAutocorrectionCandidateDescriptorIsActionable(
    NSDictionary<NSString *, id> *descriptor,
    NSString *expectedCandidate,
    NSError **error) {
    if (error != NULL) *error = nil;
    NSString *candidate = [descriptor[@"candidate"] isKindOfClass:NSString.class]
        ? descriptor[@"candidate"] : nil;
    NSString *original = [descriptor[@"original"] isKindOfClass:NSString.class]
        ? descriptor[@"original"] : nil;
    BOOL actionable = NO;
    BOOL hasActionable = IDAutocorrectionIsBoolean(
        descriptor[@"actionable"], &actionable);
    if (candidate.length == 0 || original.length == 0 || !hasActionable || !actionable) {
        if (error != NULL) *error = IDAutocorrectionError(
            IDAutocorrectionStatusErrorCandidateUnavailable,
            @"Expected autocorrection candidate is absent or not actionable");
        return NO;
    }
    if (![candidate isEqualToString:expectedCandidate]) {
        if (error != NULL) *error = IDAutocorrectionError(
            IDAutocorrectionStatusErrorCandidateUnavailable,
            [NSString stringWithFormat:@"Expected candidate '%@', observed '%@'",
             expectedCandidate, candidate]);
        return NO;
    }
    return YES;
}

static BOOL IDAutocorrectionWaitForKeyboardReady(
    XCUIApplication *application, NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        XCUIElementQuery *keys =
            [application.keyboards.keys matchingIdentifier:@"t"];
        if (keys.count == 1 && keys.firstMatch.isHittable) return YES;
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    return NO;
}

XCUIApplication *IDLaunchStockAutocorrectionScenario(
    IDAutocorrectionDecisionRow *row) {
    NSArray<NSString *> *locations = @[@"interior", @"before-boundary",
                                       @"after-boundary"];
    XCUIApplication *application = [[XCUIApplication alloc]
        initWithBundleIdentifier:@"com.inputdec.stockoracle"];
    [application terminate];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)", @"-AppleLocale", @"en_US",
    ];
    application.launchEnvironment = @{
        @"IDStockEditorFrame": NSStringFromCGRect(CGRectMake(16, 198, 370, 360)),
        @"IDStockTouchScenario": [@"autocorrection-" stringByAppendingString:
            locations[(NSUInteger)row.location]],
        @"IDAutocorrectionDecision": row.identifier,
        @"IDForceEnglishUSInputMode": @"1",
    };
    [application launch];
    // A freshly erased iOS 26.5 simulator can expose the software-keyboard
    // hierarchy before its keys become interactive. Relaunching before any
    // input creates a ready session without making a correction decision.
    if (!IDAutocorrectionWaitForKeyboardReady(application, 5.0)) {
        [application terminate];
        [application launch];
        (void)IDAutocorrectionWaitForKeyboardReady(application, 5.0);
    }
    return application;
}

XCUIApplication *IDLaunchCustomAutocorrectionScenario(
    IDAutocorrectionDecisionRow *row) {
    NSArray<NSString *> *locations = @[@"interior", @"before-boundary",
                                       @"after-boundary"];
    XCUIApplication *application = [XCUIApplication new];
    [application terminate];
    application.launchArguments = @[
        @"-AppleLanguages", @"(en)", @"-AppleLocale", @"en_US",
        @"--id-block-ui-scenario",
        [@"autocorrection-" stringByAppendingString:
            locations[(NSUInteger)row.location]],
    ];
    application.launchEnvironment = @{
        @"IDAutocorrectionDecision": row.identifier,
        @"IDAutocorrectionOriginal": @"adress",
        @"IDForceEnglishUSInputMode": @"1",
    };
    [application launch];
    if (!IDAutocorrectionWaitForKeyboardReady(application, 5.0)) {
        [application terminate];
        [application launch];
        (void)IDAutocorrectionWaitForKeyboardReady(application, 5.0);
    }
    return application;
}

IDAutocorrectionPhaseSnapshot *IDCaptureAutocorrectionPhase(
    XCTestCase *testCase, XCUIApplication *application, NSString *phase) {
    XCUIElement *statusElement =
        [application descendantsMatchingType:XCUIElementTypeAny]
            [@"autocorrection-status"];
    if (![statusElement waitForExistenceWithTimeout:4.0]) {
        [testCase recordIssue:[[XCTIssue alloc] initWithType:XCTIssueTypeAssertionFailure
            compactDescription:@"Autocorrection status element is absent"]];
    }
    NSString *serialized = [statusElement.value isKindOfClass:NSString.class]
        ? statusElement.value : @"{}";
    NSData *data = [serialized dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableDictionary<NSString *, id> *payload = data == nil ? nil :
        [[NSJSONSerialization JSONObjectWithData:data options:0 error:nil] mutableCopy];
    if (payload != nil) {
        NSPredicate *candidatePredicate = [NSPredicate predicateWithFormat:
            @"label == %@ OR value == %@ OR identifier == %@", @"address", @"address", @"address"];
        XCUIElement *candidate = [[application descendantsMatchingType:XCUIElementTypeAny]
            matchingPredicate:candidatePredicate].firstMatch;
        BOOL candidateExists = candidate.exists;
        NSPredicate *correctionVariantPredicate = [NSPredicate predicateWithFormat:
            @"label == %@ OR value == %@ OR identifier == %@",
            @"addressing", @"addressing", @"addressing"];
        XCUIElement *correctionVariant =
            [[application descendantsMatchingType:XCUIElementTypeAny]
                matchingPredicate:correctionVariantPredicate].firstMatch;
        // A lone "address" can be an ordinary next-word prediction left by a
        // preceding host. The misspelling correction surface also exposes the
        // related "addressing" choice on the pinned English keyboard.
        BOOL candidateIsActionable =
            IDAutocorrectionCandidateSignalsAreActionable(
                candidateExists, correctionVariant.exists);
        payload[@"candidateDescriptor"] = @{
            @"candidate": candidateIsActionable ? (candidate.label.length > 0
                ? candidate.label : @"address") : @"",
            @"original": @"adress",
            // The driver independently waits for this semantic element to be
            // hittable before capture. iOS 26.5 can transiently report an empty
            // frame while taking the following accessibility snapshot.
            @"actionable": @(candidateIsActionable),
        };
    }
    NSData *augmented = payload == nil ? nil :
        [NSJSONSerialization dataWithJSONObject:payload
                                        options:NSJSONWritingSortedKeys error:nil];
    NSString *augmentedString = augmented == nil ? @"{}" :
        [[NSString alloc] initWithData:augmented encoding:NSUTF8StringEncoding];
    NSError *parseError = nil;
    IDAutocorrectionStatus *status =
        IDParseAutocorrectionStatus(augmentedString, &parseError);
    NSLog(@"ID_AUTOCORRECTION_STATUS phase=%@ payload=%@", phase,
          augmentedString);
    if (status == nil) {
        [testCase recordIssue:[[XCTIssue alloc] initWithType:XCTIssueTypeAssertionFailure
            compactDescription:[NSString stringWithFormat:
                @"Invalid autocorrection status for %@: %@ raw=%@", phase,
                parseError.localizedDescription, serialized]]];
    }
    NSString *screenshotName = [NSString stringWithFormat:@"autocorrection-%@", phase];
    XCTAttachment *attachment =
        [XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];
    attachment.name = IDTextInputBatchAttachmentName(screenshotName);
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [testCase addAttachment:attachment];
    XCTAttachment *statusAttachment =
        [XCTAttachment attachmentWithString:augmentedString];
    statusAttachment.name = IDTextInputBatchAttachmentName(
        [NSString stringWithFormat:@"autocorrection-%@-status", phase]);
    statusAttachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [testCase addAttachment:statusAttachment];
    IDAutocorrectionPhaseSnapshot *snapshot = [IDAutocorrectionPhaseSnapshot new];
    snapshot.phase = phase;
    snapshot.status = status;
    snapshot.screenshotName = screenshotName;
    return snapshot;
}

BOOL IDAutocorrectionCandidateSignalsAreActionable(
    BOOL candidateExists, BOOL correctionVariantExists) {
    return candidateExists && correctionVariantExists;
}

static XCUIElement *IDAutocorrectionCandidateElement(XCUIApplication *application,
                                                      NSString *text) {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:
        @"label == %@ OR value == %@ OR identifier == %@", text, text, text];
    return [[application descendantsMatchingType:XCUIElementTypeAny]
        matchingPredicate:predicate].firstMatch;
}

static XCUIElement *IDAutocorrectionOriginalElement(XCUIApplication *application,
                                                     NSString *text) {
    NSString *quoted = [NSString stringWithFormat:@"“%@”", text];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:
        @"label == %@ OR value == %@ OR identifier == %@ OR label == %@",
        text, text, text, quoted];
    return [[application descendantsMatchingType:XCUIElementTypeAny]
        matchingPredicate:predicate].firstMatch;
}

static BOOL IDAutocorrectionWaitForCandidate(XCUIApplication *application,
                                             NSString *text,
                                             NSTimeInterval timeout) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    do {
        XCUIElement *candidate = IDAutocorrectionCandidateElement(application, text);
        if (candidate.exists && candidate.isHittable) return YES;
        [NSThread sleepForTimeInterval:0.05];
    } while (deadline.timeIntervalSinceNow > 0);
    return NO;
}

static void IDAutocorrectionAttachHierarchy(XCTestCase *testCase,
                                             XCUIApplication *application,
                                             NSString *name) {
    XCTAttachment *attachment = [XCTAttachment attachmentWithString:
        application.debugDescription ?: @"unavailable"];
    attachment.name = IDTextInputBatchAttachmentName(name);
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [testCase addAttachment:attachment];
}

IDAutocorrectionRunResult *IDRunAutocorrectionDecision(
    XCTestCase *testCase, XCUIApplication *application,
    IDAutocorrectionDecisionRow *row) {
    XCUIElementQuery *elements =
        [application descendantsMatchingType:XCUIElementTypeAny];
    XCUIElement *stockEditor = elements[@"stock-text-view"];
    XCUIElement *editor = stockEditor.exists
        ? stockEditor
        : elements[@"block-text-view"];
    XCUIElement *status =
        [application descendantsMatchingType:XCUIElementTypeAny][@"autocorrection-status"];
    if (![editor waitForExistenceWithTimeout:4.0] ||
        ![status waitForExistenceWithTimeout:4.0]) {
        [testCase recordIssue:[[XCTIssue alloc] initWithType:XCTIssueTypeAssertionFailure
            compactDescription:@"Autocorrection fixture did not launch"]];
    }
    NSMutableArray<IDAutocorrectionPhaseSnapshot *> *phases = [NSMutableArray array];
    [phases addObject:IDCaptureAutocorrectionPhase(
        testCase, application, @"baseline")];
    IDHIDTypeSoftwareKeyboardText(testCase, application, @"adress");
    BOOL candidateReady = IDAutocorrectionWaitForCandidate(application, @"address", 5.0);
    [phases addObject:IDCaptureAutocorrectionPhase(
        testCase, application, @"offered")];
    if (!candidateReady) {
        IDAutocorrectionAttachHierarchy(testCase, application,
                                         @"autocorrection-candidate-missing-hierarchy");
        [testCase recordIssue:[[XCTIssue alloc] initWithType:XCTIssueTypeAssertionFailure
            compactDescription:@"Expected native candidate 'address' was not actionable"]];
    }
    switch (row.decision) {
        case IDAutocorrectionDecisionAcceptSpace:
        case IDAutocorrectionDecisionUndoSpace:
            IDHIDTapSoftwareKeyboardKey(testCase, application, @"space");
            break;
        case IDAutocorrectionDecisionAcceptPunctuation:
        case IDAutocorrectionDecisionUndoPunctuation:
            IDHIDTapSoftwareKeyboardKey(testCase, application, @".");
            break;
        case IDAutocorrectionDecisionAcceptCandidate:
        case IDAutocorrectionDecisionUndoCandidate:
            [IDAutocorrectionCandidateElement(application, @"address") tap];
            break;
        case IDAutocorrectionDecisionRejectPrecommit:
            [IDAutocorrectionOriginalElement(application, @"adress") tap];
            break;
    }
    [phases addObject:IDCaptureAutocorrectionPhase(
        testCase, application, @"decision")];
    [NSThread sleepForTimeInterval:0.05];
    [phases addObject:IDCaptureAutocorrectionPhase(
        testCase, application, @"immediate")];
    [NSThread sleepForTimeInterval:0.50];
    [phases addObject:IDCaptureAutocorrectionPhase(
        testCase, application, @"quiesced")];
    if (row.decision == IDAutocorrectionDecisionRejectPrecommit) {
        IDHIDTapSoftwareKeyboardKey(testCase, application, @"space");
        [phases addObject:IDCaptureAutocorrectionPhase(
            testCase, application, @"postRejectionSpace")];
    } else if (row.decision >= IDAutocorrectionDecisionUndoSpace) {
        IDHIDTapSoftwareKeyboardKey(testCase, application, @"delete");
        [phases addObject:IDCaptureAutocorrectionPhase(
            testCase, application, @"firstBackspace")];
        IDHIDTapSoftwareKeyboardKey(testCase, application, @"delete");
        [phases addObject:IDCaptureAutocorrectionPhase(
            testCase, application, @"secondBackspace")];
    }
    IDAutocorrectionRunResult *result = [IDAutocorrectionRunResult new];
    result.row = row;
    result.phases = phases.copy;
    return result;
}

void IDAssertAutocorrectionParity(XCTestCase *testCase,
                                  IDAutocorrectionRunResult *stock,
                                  IDAutocorrectionRunResult *custom) {
    XCTAssertEqualObjects(stock.row.identifier, custom.row.identifier);
    XCTAssertEqual(stock.phases.count, custom.phases.count);
    NSUInteger count = MIN(stock.phases.count, custom.phases.count);
    for (NSUInteger index = 0; index < count; index += 1) {
        IDAutocorrectionPhaseSnapshot *stockPhase = stock.phases[index];
        IDAutocorrectionPhaseSnapshot *customPhase = custom.phases[index];
        XCTAssertEqualObjects(stockPhase.phase, customPhase.phase,
                              @"%@ phase %lu", stock.row.identifier,
                              (unsigned long)index);
        IDAutocorrectionStatus *stockStatus = stockPhase.status;
        IDAutocorrectionStatus *customStatus = customPhase.status;
        XCTAssertEqualObjects(stockStatus.canonical, customStatus.canonical,
                              @"%@ %@", stock.row.identifier, stockPhase.phase);
        XCTAssertEqualObjects(stockStatus.blocks, customStatus.blocks,
                              @"%@ %@", stock.row.identifier, stockPhase.phase);
        XCTAssertTrue(NSEqualRanges(stockStatus.selection, customStatus.selection),
                      @"%@ %@ stock=%@ custom=%@", stock.row.identifier,
                      stockPhase.phase, NSStringFromRange(stockStatus.selection),
                      NSStringFromRange(customStatus.selection));
        XCTAssertEqualObjects(stockStatus.affinity, customStatus.affinity,
                              @"%@ %@", stock.row.identifier, stockPhase.phase);
        XCTAssertTrue(NSEqualRanges(stockStatus.markedRange, customStatus.markedRange),
                      @"%@ %@", stock.row.identifier, stockPhase.phase);
        XCTAssertEqualObjects(stockStatus.structuralNewlineLocations,
                              customStatus.structuralNewlineLocations,
                              @"%@ %@", stock.row.identifier, stockPhase.phase);
        XCTAssertEqualObjects(stockStatus.checkingRanges, customStatus.checkingRanges,
                              @"%@ %@", stock.row.identifier, stockPhase.phase);
        XCTAssertEqualObjects(stockStatus.candidateDescriptor,
                              customStatus.candidateDescriptor,
                              @"%@ %@", stock.row.identifier, stockPhase.phase);
        XCTAssertEqual(stockStatus.isFirstResponder, customStatus.isFirstResponder,
                       @"%@ %@", stock.row.identifier, stockPhase.phase);
        XCTAssertEqualObjects(stockStatus.keyboardState[@"visible"],
                              customStatus.keyboardState[@"visible"],
                              @"%@ %@", stock.row.identifier, stockPhase.phase);
        XCTAssertEqualObjects(stockStatus.keyboardState[@"locale"],
                              customStatus.keyboardState[@"locale"],
                              @"%@ %@", stock.row.identifier, stockPhase.phase);
        XCTAssertEqualObjects(stockStatus.keyboardState[@"learnedOriginal"],
                              customStatus.keyboardState[@"learnedOriginal"],
                              @"%@ %@", stock.row.identifier, stockPhase.phase);
    }
    (void)testCase;
}
