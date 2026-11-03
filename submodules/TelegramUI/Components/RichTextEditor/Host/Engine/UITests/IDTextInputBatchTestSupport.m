#import "IDTextInputBatchTestSupport.h"

#import <CommonCrypto/CommonDigest.h>
#import <CoreFoundation/CoreFoundation.h>

NSString *const IDTextInputBatchErrorDomain =
    @"com.inputdec.tests.text-input-batch";

static NSString *const IDTextInputBatchObservationThreadKey =
    @"com.inputdec.tests.text-input-batch.observation";
static NSString *const IDTextInputBatchThreadKey =
    @"com.inputdec.tests.text-input-batch.batch";
static NSString *const IDTextInputBatchAttemptThreadKey =
    @"com.inputdec.tests.text-input-batch.attempt";
static NSString *const IDTextInputBatchUDID =
    @"FA6F7462-AA97-42FE-9E57-8DA0593CE756";
static NSString *const IDTextInputBatchResetPolicy =
    @"erase-reset-learning-provision";

typedef NS_ENUM(NSInteger, IDTextInputBatchErrorCode) {
    IDTextInputBatchErrorInvalidJSON = 1,
    IDTextInputBatchErrorInvalidCatalog,
    IDTextInputBatchErrorUnknownBatch,
    IDTextInputBatchErrorBoundaryProtocol,
};

static NSError *IDTextInputBatchError(IDTextInputBatchErrorCode code,
                                      NSString *description) {
    return [NSError errorWithDomain:IDTextInputBatchErrorDomain code:code
                            userInfo:@{NSLocalizedDescriptionKey: description}];
}

@interface IDTextInputBatchObservation ()
@property(nonatomic, copy, readwrite) NSString *rowIdentifier;
@property(nonatomic, copy, readwrite) NSString *batchIdentifier;
@property(nonatomic, readwrite) IDTextInputBatchHost host;
@property(nonatomic, copy, readwrite) NSString *identity;
- (instancetype)initWithRowIdentifier:(NSString *)rowIdentifier
                                  host:(IDTextInputBatchHost)host;
@end

@implementation IDTextInputBatchObservation

- (instancetype)initWithRowIdentifier:(NSString *)rowIdentifier
                                  host:(IDTextInputBatchHost)host {
    self = [super init];
    if (self == nil) return nil;
    _rowIdentifier = [rowIdentifier copy];
    _host = host;
    NSString *hostName = host == IDTextInputBatchHostStock
        ? @"stock" : @"custom";
    _identity = [[NSString alloc] initWithFormat:@"%@--%@",
                  rowIdentifier, hostName];
    return self;
}

@end

@interface IDTextInputBatch ()
@property(nonatomic, copy, readwrite) NSString *identifier;
@property(nonatomic, copy, readwrite) NSString *subsystem;
@property(nonatomic, copy, readwrite)
    NSArray<IDTextInputBatchObservation *> *observations;
@property(nonatomic, readwrite, getter=isStateSensitive) BOOL stateSensitive;
@end

@implementation IDTextInputBatch
@end

@interface IDTextInputGroup ()
@property(nonatomic, copy, readwrite) NSString *identifier;
@property(nonatomic, copy, readwrite) NSString *subsystem;
@property(nonatomic, copy, readwrite) NSArray<IDTextInputBatch *> *batches;
@property(nonatomic, readwrite, getter=isStateSensitive) BOOL stateSensitive;
@end

@implementation IDTextInputGroup
@end

@interface IDTextInputGroupBoundary ()
@property(nonatomic, readwrite) IDTextInputGroupBoundaryKind kind;
@property(nonatomic, readwrite) NSUInteger sequenceIndex;
@property(nonatomic, copy, readwrite) NSString *batchIdentifier;
@property(nonatomic, copy, readwrite) NSString *rowIdentifier;
@property(nonatomic, copy, readwrite) NSString *completedHost;
@property(nonatomic, copy, readwrite) NSString *nextHost;
@property(nonatomic, copy, readwrite) NSString *completedRowIdentifier;
@property(nonatomic, copy, readwrite) NSString *nextRowIdentifier;
@property(nonatomic, copy, readwrite) NSString *completedBatchIdentifier;
@property(nonatomic, copy, readwrite) NSString *nextBatchIdentifier;
- (instancetype)initWithKind:(IDTextInputGroupBoundaryKind)kind
                sequenceIndex:(NSUInteger)sequenceIndex
               batchIdentifier:(NSString *)batchIdentifier
                  rowIdentifier:(NSString *)rowIdentifier
                  completedHost:(NSString *)completedHost
                       nextHost:(NSString *)nextHost
         completedRowIdentifier:(NSString *)completedRowIdentifier
              nextRowIdentifier:(NSString *)nextRowIdentifier
      completedBatchIdentifier:(NSString *)completedBatchIdentifier
           nextBatchIdentifier:(NSString *)nextBatchIdentifier;
@end

@implementation IDTextInputGroupBoundary
- (instancetype)initWithKind:(IDTextInputGroupBoundaryKind)kind
                sequenceIndex:(NSUInteger)sequenceIndex
               batchIdentifier:(NSString *)batchIdentifier
                  rowIdentifier:(NSString *)rowIdentifier
                  completedHost:(NSString *)completedHost
                       nextHost:(NSString *)nextHost
         completedRowIdentifier:(NSString *)completedRowIdentifier
              nextRowIdentifier:(NSString *)nextRowIdentifier
      completedBatchIdentifier:(NSString *)completedBatchIdentifier
           nextBatchIdentifier:(NSString *)nextBatchIdentifier {
    self = [super init];
    if (self == nil) return nil;
    _kind = kind;
    _sequenceIndex = sequenceIndex;
    _batchIdentifier = [batchIdentifier copy];
    _rowIdentifier = [rowIdentifier copy];
    _completedHost = [completedHost copy];
    _nextHost = [nextHost copy];
    _completedRowIdentifier = [completedRowIdentifier copy];
    _nextRowIdentifier = [nextRowIdentifier copy];
    _completedBatchIdentifier = [completedBatchIdentifier copy];
    _nextBatchIdentifier = [nextBatchIdentifier copy];
    return self;
}
@end

static NSString *IDTextInputBatchHostName(IDTextInputBatchHost host) {
    return host == IDTextInputBatchHostStock ? @"stock" : @"custom";
}

static IDTextInputGroupBoundary *IDTextInputGroupHostBoundary(
    NSUInteger sequenceIndex, IDTextInputBatch *batch,
    IDTextInputBatchObservation *completed,
    IDTextInputBatchObservation *next) {
    return [[IDTextInputGroupBoundary alloc]
        initWithKind:IDTextInputGroupBoundaryKindHost
        sequenceIndex:sequenceIndex
        batchIdentifier:batch.identifier
        rowIdentifier:completed.rowIdentifier
        completedHost:IDTextInputBatchHostName(completed.host)
        nextHost:IDTextInputBatchHostName(next.host)
        completedRowIdentifier:nil
        nextRowIdentifier:nil
        completedBatchIdentifier:nil
        nextBatchIdentifier:nil];
}

static IDTextInputGroupBoundary *IDTextInputGroupRowBoundary(
    NSUInteger sequenceIndex, IDTextInputBatch *batch,
    NSString *completedRow, NSString *nextRow) {
    return [[IDTextInputGroupBoundary alloc]
        initWithKind:IDTextInputGroupBoundaryKindRow
        sequenceIndex:sequenceIndex
        batchIdentifier:batch.identifier
        rowIdentifier:nil
        completedHost:nil
        nextHost:nil
        completedRowIdentifier:completedRow
        nextRowIdentifier:nextRow
        completedBatchIdentifier:nil
        nextBatchIdentifier:nil];
}

static IDTextInputGroupBoundary *IDTextInputGroupPassBoundary(
    NSUInteger sequenceIndex, IDTextInputBatch *completed,
    IDTextInputBatch *next) {
    return [[IDTextInputGroupBoundary alloc]
        initWithKind:IDTextInputGroupBoundaryKindPass
        sequenceIndex:sequenceIndex
        batchIdentifier:nil
        rowIdentifier:nil
        completedHost:nil
        nextHost:nil
        completedRowIdentifier:nil
        nextRowIdentifier:nil
        completedBatchIdentifier:completed.identifier
        nextBatchIdentifier:next.identifier];
}

static BOOL IDTextInputBatchExactKeys(id value,
                                      NSArray<NSString *> *keys) {
    if (![value isKindOfClass:NSDictionary.class]) return NO;
    return [[NSSet setWithArray:[value allKeys]]
        isEqualToSet:[NSSet setWithArray:keys]];
}

static BOOL IDTextInputBatchStringArray(id value) {
    if (![value isKindOfClass:NSArray.class]) return NO;
    for (id item in value) {
        if (![item isKindOfClass:NSString.class] || [item length] == 0) {
            return NO;
        }
    }
    return YES;
}

static BOOL IDTextInputBatchBoolean(id value) {
    return [value isKindOfClass:NSNumber.class] &&
        CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID();
}

static BOOL IDTextInputBatchSetError(NSError **error,
                                     IDTextInputBatchErrorCode code,
                                     NSString *description) {
    if (error != NULL) *error = IDTextInputBatchError(code, description);
    return NO;
}

static BOOL IDValidateTextInputBatchCatalog(
    NSDictionary *catalog, NSError **error) {
    if (!IDTextInputBatchExactKeys(catalog, @[
            @"schema", @"runtime", @"udid", @"subsystem", @"rows",
            @"groups",
        ])) {
        return IDTextInputBatchSetError(
            error, IDTextInputBatchErrorInvalidCatalog,
            @"catalog top-level keys differ");
    }
    id schema = catalog[@"schema"];
    if (![schema isKindOfClass:NSNumber.class] ||
        CFGetTypeID((__bridge CFTypeRef)schema) == CFBooleanGetTypeID() ||
        [schema integerValue] != 1) {
        return IDTextInputBatchSetError(
            error, IDTextInputBatchErrorInvalidCatalog,
            @"catalog schema must equal integer 1");
    }
    if (![catalog[@"runtime"] isEqual:@{
            @"osVersion": @"26.5", @"osBuild": @"23F73",
        }] || ![catalog[@"udid"] isEqual:IDTextInputBatchUDID]) {
        return IDTextInputBatchSetError(
            error, IDTextInputBatchErrorInvalidCatalog,
            @"catalog runtime or device differs");
    }
    NSString *subsystem = catalog[@"subsystem"];
    if (![subsystem isKindOfClass:NSString.class] ||
        ![@[@"ime", @"autocorrection", @"inline-prediction"]
            containsObject:subsystem]) {
        return IDTextInputBatchSetError(
            error, IDTextInputBatchErrorInvalidCatalog,
            @"catalog subsystem is invalid");
    }
    NSArray *rows = catalog[@"rows"];
    NSArray *groups = catalog[@"groups"];
    if (!IDTextInputBatchStringArray(rows) || rows.count == 0 ||
        ![groups isKindOfClass:NSArray.class] || groups.count == 0) {
        return IDTextInputBatchSetError(
            error, IDTextInputBatchErrorInvalidCatalog,
            @"catalog rows or groups are invalid");
    }
    NSMutableArray<NSString *> *groupIdentifiers = [NSMutableArray array];
    NSMutableArray<NSString *> *groupedRows = [NSMutableArray array];
    for (NSDictionary *group in groups) {
        if (!IDTextInputBatchExactKeys(group, @[
                @"id", @"language", @"rows", @"stateSensitive",
                @"resetPolicy",
            ])) {
            return IDTextInputBatchSetError(
                error, IDTextInputBatchErrorInvalidCatalog,
                @"group keys differ");
        }
        NSString *identifier = group[@"id"];
        NSArray *currentRows = group[@"rows"];
        NSString *language = group[@"language"];
        if (![identifier isKindOfClass:NSString.class] ||
            identifier.length == 0 ||
            !IDTextInputBatchStringArray(currentRows) ||
            currentRows.count == 0 ||
            ![language isKindOfClass:NSString.class] ||
            language.length == 0 ||
            !IDTextInputBatchBoolean(group[@"stateSensitive"]) ||
            ![group[@"resetPolicy"] isEqual:IDTextInputBatchResetPolicy]) {
            return IDTextInputBatchSetError(
                error, IDTextInputBatchErrorInvalidCatalog,
                @"group field is invalid");
        }
        NSUInteger maximum = [group[@"stateSensitive"] boolValue] ? 3U : 12U;
        if (currentRows.count > maximum) {
            return IDTextInputBatchSetError(
                error, IDTextInputBatchErrorInvalidCatalog,
                @"group size exceeds its state contract");
        }
        if ([subsystem isEqual:@"ime"]) {
            if (![@[@"japanese-romaji", @"simplified-chinese-pinyin"]
                    containsObject:language]) {
                return IDTextInputBatchSetError(
                    error, IDTextInputBatchErrorInvalidCatalog,
                    @"IME group language is invalid");
            }
            NSString *prefix = [language stringByAppendingString:@"-"];
            for (NSString *row in currentRows) {
                if (![row hasPrefix:prefix]) {
                    return IDTextInputBatchSetError(
                        error, IDTextInputBatchErrorInvalidCatalog,
                        @"IME group language differs from its row");
                }
            }
        } else if (![language isEqual:@"en-US"]) {
            return IDTextInputBatchSetError(
                error, IDTextInputBatchErrorInvalidCatalog,
                @"English group language differs");
        }
        [groupIdentifiers addObject:identifier];
        [groupedRows addObjectsFromArray:currentRows];
    }
    if ([NSSet setWithArray:groupIdentifiers].count != groupIdentifiers.count ||
        ![groupedRows isEqual:rows]) {
        return IDTextInputBatchSetError(
            error, IDTextInputBatchErrorInvalidCatalog,
            @"duplicate group or grouped row coverage differs");
    }
    return YES;
}

static NSDictionary *IDTextInputBatchCatalogFromData(
    NSData *data, NSError **error) {
    NSError *JSONError = nil;
    id value = [NSJSONSerialization JSONObjectWithData:data options:0
                                                  error:&JSONError];
    if (value == nil) {
        if (error != NULL) {
            *error = IDTextInputBatchError(
                IDTextInputBatchErrorInvalidJSON,
                JSONError.localizedDescription ?: @"catalog JSON is invalid");
        }
        return nil;
    }
    if (!IDValidateTextInputBatchCatalog(value, error)) return nil;
    return value;
}

static NSDictionary *IDTextInputBatchGroupFromCatalog(
    NSDictionary *catalog, NSString *groupIdentifier) {
    if ([catalog[@"subsystem"] isEqual:@"inline-prediction"] &&
        [catalog[@"rows"] containsObject:groupIdentifier]) {
        NSPredicate *rowPredicate = [NSPredicate predicateWithBlock:
            ^BOOL(NSDictionary *group, NSDictionary *bindings) {
                (void)bindings;
                return [group[@"rows"] containsObject:groupIdentifier];
            }];
        NSArray *sourceGroups = [catalog[@"groups"]
            filteredArrayUsingPredicate:rowPredicate];
        if (sourceGroups.count != 1) return nil;
        NSDictionary *source = sourceGroups.firstObject;
        return @{
            @"id": groupIdentifier,
            @"language": source[@"language"],
            @"rows": @[groupIdentifier],
            @"stateSensitive": @YES,
            @"resetPolicy": source[@"resetPolicy"],
        };
    }
    NSPredicate *identifierPredicate = [NSPredicate predicateWithBlock:
        ^BOOL(NSDictionary *group, NSDictionary *bindings) {
            (void)bindings;
            return [group[@"id"] isEqual:groupIdentifier];
        }];
    NSArray *groups = [catalog[@"groups"]
        filteredArrayUsingPredicate:identifierPredicate];
    return groups.count == 1 ? groups.firstObject : nil;
}

static IDTextInputBatch *IDTextInputBatchFromCatalog(
    NSDictionary *catalog, NSString *batchIdentifier, NSError **error) {
    NSArray<NSString *> *components =
        [batchIdentifier componentsSeparatedByString:@"--"];
    if (components.count != 4 ||
        ![components[0] isEqual:catalog[@"subsystem"]] ||
        ![@[@"r1", @"r2"] containsObject:components[1]] ||
        ![@[@"stock-custom", @"custom-stock"]
            containsObject:components[2]]) {
        IDTextInputBatchSetError(
            error, IDTextInputBatchErrorUnknownBatch,
            @"batch identifier is invalid");
        return nil;
    }
    NSDictionary *group = IDTextInputBatchGroupFromCatalog(
        catalog, components[3]);
    if (group == nil) {
        IDTextInputBatchSetError(
            error, IDTextInputBatchErrorUnknownBatch,
            @"batch group does not exist");
        return nil;
    }
    NSArray<NSNumber *> *hosts = [components[2] isEqual:@"stock-custom"]
        ? @[@(IDTextInputBatchHostStock), @(IDTextInputBatchHostCustom)]
        : @[@(IDTextInputBatchHostCustom), @(IDTextInputBatchHostStock)];
    NSMutableArray<IDTextInputBatchObservation *> *observations =
        [NSMutableArray array];
    for (NSString *row in group[@"rows"]) {
        for (NSNumber *host in hosts) {
            [observations addObject:[[IDTextInputBatchObservation alloc]
                initWithRowIdentifier:row host:host.integerValue]];
        }
    }
    IDTextInputBatch *batch = [IDTextInputBatch new];
    batch.identifier = batchIdentifier;
    batch.subsystem = catalog[@"subsystem"];
    batch.observations = observations;
    batch.stateSensitive = [group[@"stateSensitive"] boolValue];
    for (IDTextInputBatchObservation *observation in observations) {
        observation.batchIdentifier = batchIdentifier;
    }
    return batch;
}

IDTextInputBatch *IDLoadTextInputBatchFromData(
    NSData *data, NSString *batchIdentifier, NSError **error) {
    NSDictionary *catalog = IDTextInputBatchCatalogFromData(data, error);
    if (catalog == nil) return nil;
    return IDTextInputBatchFromCatalog(catalog, batchIdentifier, error);
}

IDTextInputGroup *IDLoadTextInputGroupFromData(
    NSData *data, NSString *groupIdentifier, NSError **error) {
    NSDictionary *catalog = IDTextInputBatchCatalogFromData(data, error);
    if (catalog == nil) return nil;
    NSArray<NSString *> *components =
        [groupIdentifier componentsSeparatedByString:@"--"];
    BOOL validComponents = components.count == 3 &&
        [components[0] isEqual:catalog[@"subsystem"]] &&
        components[2].length > 0;
    BOOL inlinePrediction = validComponents &&
        [components[0] isEqual:@"inline-prediction"];
    BOOL snapshotRow = inlinePrediction &&
        [components[1] isEqual:@"snapshot-row-v1"];
    BOOL ordinaryGroup = validComponents && !inlinePrediction &&
        [components[1] isEqual:@"group"];
    if (!ordinaryGroup && !snapshotRow) {
        IDTextInputBatchSetError(
            error, IDTextInputBatchErrorUnknownBatch,
            @"logical group identifier is invalid");
        return nil;
    }
    NSArray<NSString *> *repetitions = @[@"r1", @"r2"];
    NSArray<NSString *> *orders = @[@"stock-custom", @"custom-stock"];
    NSMutableArray<IDTextInputBatch *> *batches = [NSMutableArray array];
    for (NSString *repetition in repetitions) {
        for (NSString *order in orders) {
            NSString *batchIdentifier = [NSString stringWithFormat:
                @"%@--%@--%@--%@", components[0], repetition, order,
                components[2]];
            IDTextInputBatch *batch = IDTextInputBatchFromCatalog(
                catalog, batchIdentifier, error);
            if (batch == nil) return nil;
            [batches addObject:batch];
        }
    }
    IDTextInputGroup *group = [IDTextInputGroup new];
    group.identifier = groupIdentifier;
    group.subsystem = catalog[@"subsystem"];
    group.batches = batches;
    group.stateSensitive = batches.firstObject.stateSensitive;
    return group;
}

IDTextInputBatch *IDLoadSelectedTextInputBatch(
    XCTestCase *testCase, NSString *subsystem) {
    NSString *identifier = NSProcessInfo.processInfo.environment[
        @"INPUTDEC_TEXT_INPUT_BATCH_ID"];
    if (identifier.length == 0) {
        XCTFail(@"INPUTDEC_TEXT_INPUT_BATCH_ID is required");
        return nil;
    }
    NSString *resource = [NSString stringWithFormat:
        @"text-input-%@-batches-ios26.5-v1", subsystem];
    NSURL *URL = [[NSBundle bundleForClass:testCase.class]
        URLForResource:resource withExtension:@"json"];
    NSData *data = URL == nil ? nil : [NSData dataWithContentsOfURL:URL];
    if (data == nil) {
        XCTFail(@"Missing batch catalog resource %@.json", resource);
        return nil;
    }
    NSError *error = nil;
    IDTextInputBatch *batch = IDLoadTextInputBatchFromData(
        data, identifier, &error);
    if (batch == nil || ![batch.subsystem isEqual:subsystem]) {
        XCTFail(@"Cannot load selected %@ batch: %@", subsystem,
                error.localizedDescription);
        return nil;
    }
    return batch;
}

IDTextInputGroup *IDLoadSelectedTextInputGroup(
    XCTestCase *testCase, NSString *subsystem) {
    NSString *identifier = NSProcessInfo.processInfo.environment[
        @"INPUTDEC_TEXT_INPUT_GROUP_ID"];
    if (identifier.length == 0) {
        XCTFail(@"INPUTDEC_TEXT_INPUT_GROUP_ID is required");
        return nil;
    }
    NSString *resource = [NSString stringWithFormat:
        @"text-input-%@-batches-ios26.5-v1", subsystem];
    NSURL *URL = [[NSBundle bundleForClass:testCase.class]
        URLForResource:resource withExtension:@"json"];
    NSData *data = URL == nil ? nil : [NSData dataWithContentsOfURL:URL];
    if (data == nil) {
        XCTFail(@"Missing batch catalog resource %@.json", resource);
        return nil;
    }
    NSError *error = nil;
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        data, identifier, &error);
    if (group == nil || ![group.subsystem isEqual:subsystem]) {
        XCTFail(@"Cannot load selected %@ group: %@", subsystem,
                error.localizedDescription);
        return nil;
    }
    return group;
}

static BOOL IDTextInputGroupHex64(NSString *value) {
    if (![value isKindOfClass:NSString.class] || value.length != 64) return NO;
    NSCharacterSet *invalid = [[NSCharacterSet
        characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet];
    return [value rangeOfCharacterFromSet:invalid].location == NSNotFound;
}

static BOOL IDTextInputGroupURLIsSymlink(NSURL *URL) {
    NSNumber *value = nil;
    [URL getResourceValue:&value forKey:NSURLIsSymbolicLinkKey error:nil];
    return value.boolValue;
}

NSString *IDTextInputGroupTokenSHA256(NSString *token) {
    if (!IDTextInputGroupHex64(token)) return nil;
    NSData *data = [token dataUsingEncoding:NSASCIIStringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *result = [NSMutableString
        stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        [result appendFormat:@"%02x", digest[index]];
    }
    return result;
}

static BOOL IDTextInputGroupProtocolError(
    NSError **error, NSString *description) {
    return IDTextInputBatchSetError(
        error, IDTextInputBatchErrorBoundaryProtocol, description);
}

static NSDictionary *IDTextInputGroupBoundaryFields(
    NSString *token, NSString *groupIdentifier,
    IDTextInputGroupBoundary *boundary) {
    NSMutableDictionary *fields = [@{
        @"schema": @2,
        @"kind": boundary.kind == IDTextInputGroupBoundaryKindHost
            ? @"host" : (boundary.kind == IDTextInputGroupBoundaryKindRow
                ? @"row" : @"pass"),
        @"token": token,
        @"groupId": groupIdentifier,
        @"sequenceIndex": @(boundary.sequenceIndex),
    } mutableCopy];
    if (boundary.kind == IDTextInputGroupBoundaryKindHost) {
        fields[@"batchId"] = boundary.batchIdentifier;
        fields[@"rowId"] = boundary.rowIdentifier;
        fields[@"completedHost"] = boundary.completedHost;
        fields[@"nextHost"] = boundary.nextHost;
    } else if (boundary.kind == IDTextInputGroupBoundaryKindRow) {
        fields[@"batchId"] = boundary.batchIdentifier;
        fields[@"completedRowId"] = boundary.completedRowIdentifier;
        fields[@"nextRowId"] = boundary.nextRowIdentifier;
    } else {
        fields[@"completedBatchId"] = boundary.completedBatchIdentifier;
        fields[@"nextBatchId"] = boundary.nextBatchIdentifier;
    }
    return fields;
}

static BOOL IDTextInputGroupValidateBoundaryArguments(
    NSString *token, NSString *groupIdentifier,
    IDTextInputGroupBoundary *boundary,
    NSError **error) {
    BOOL host = boundary.kind == IDTextInputGroupBoundaryKindHost;
    BOOL row = boundary.kind == IDTextInputGroupBoundaryKindRow;
    BOOL pass = boundary.kind == IDTextInputGroupBoundaryKindPass;
    BOOL validHost = host && boundary.batchIdentifier.length > 0 &&
        boundary.rowIdentifier.length > 0 &&
        boundary.completedHost.length > 0 &&
        boundary.nextHost.length > 0 &&
        ![boundary.completedHost isEqual:boundary.nextHost] &&
        boundary.completedRowIdentifier == nil &&
        boundary.nextRowIdentifier == nil &&
        boundary.completedBatchIdentifier == nil &&
        boundary.nextBatchIdentifier == nil;
    BOOL validRow = row && boundary.batchIdentifier.length > 0 &&
        boundary.rowIdentifier == nil && boundary.completedHost == nil &&
        boundary.nextHost == nil &&
        boundary.completedRowIdentifier.length > 0 &&
        boundary.nextRowIdentifier.length > 0 &&
        ![boundary.completedRowIdentifier
            isEqual:boundary.nextRowIdentifier] &&
        boundary.completedBatchIdentifier == nil &&
        boundary.nextBatchIdentifier == nil;
    BOOL validPass = pass && boundary.batchIdentifier == nil &&
        boundary.rowIdentifier == nil && boundary.completedHost == nil &&
        boundary.nextHost == nil &&
        boundary.completedRowIdentifier == nil &&
        boundary.nextRowIdentifier == nil &&
        boundary.completedBatchIdentifier.length > 0 &&
        boundary.nextBatchIdentifier.length > 0 &&
        ![boundary.completedBatchIdentifier
            isEqual:boundary.nextBatchIdentifier];
    if (!IDTextInputGroupHex64(token) || groupIdentifier.length == 0 ||
        boundary.sequenceIndex < 1 ||
        (!validHost && !validRow && !validPass)) {
        return IDTextInputGroupProtocolError(
            error, @"boundary arguments are invalid");
    }
    return YES;
}

NSURL *IDTextInputGroupHandshakeDirectory(
    NSURL *dataContainerRoot, NSString *token, NSError **error) {
    if (!IDTextInputGroupHex64(token)) {
        IDTextInputGroupProtocolError(error, @"group token is invalid");
        return nil;
    }
    NSFileManager *manager = NSFileManager.defaultManager;
    NSURL *documents = nil;
    if (dataContainerRoot == nil) {
        documents = [manager URLsForDirectory:NSDocumentDirectory
                                     inDomains:NSUserDomainMask].firstObject;
    } else {
        if (IDTextInputGroupURLIsSymlink(dataContainerRoot)) {
            IDTextInputGroupProtocolError(
                error, @"data-container root is a symbolic link");
            return nil;
        }
        NSNumber *isDirectory = nil;
        [dataContainerRoot getResourceValue:&isDirectory
            forKey:NSURLIsDirectoryKey error:nil];
        if (!isDirectory.boolValue) {
            IDTextInputGroupProtocolError(
                error, @"data-container root is not a directory");
            return nil;
        }
        documents = [dataContainerRoot URLByAppendingPathComponent:@"Documents"
                                                       isDirectory:YES];
    }
    NSURL *parent = [documents URLByAppendingPathComponent:
        @"InputDecTextInputGroup" isDirectory:YES];
    NSURL *directory = [parent URLByAppendingPathComponent:token
                                               isDirectory:YES];
    NSError *creationError = nil;
    if (![manager createDirectoryAtURL:directory
           withIntermediateDirectories:YES attributes:nil
                                  error:&creationError] ||
        IDTextInputGroupURLIsSymlink(directory)) {
        IDTextInputGroupProtocolError(
            error, creationError.localizedDescription ?:
                @"cannot create handshake directory");
        return nil;
    }
    return directory;
}

BOOL IDWriteTextInputGroupBoundaryRequest(
    NSURL *directory, NSString *token, NSString *groupIdentifier,
    IDTextInputGroupBoundary *boundary, NSError **error) {
    if (!IDTextInputGroupValidateBoundaryArguments(
            token, groupIdentifier, boundary, error) ||
        IDTextInputGroupURLIsSymlink(directory)) {
        if (error != NULL && *error == nil) {
            IDTextInputGroupProtocolError(
                error, @"handshake directory is a symbolic link");
        }
        return NO;
    }
    NSString *name = [NSString stringWithFormat:
        @"boundary-%03lu-request.json",
        (unsigned long)boundary.sequenceIndex];
    NSURL *requestURL = [directory URLByAppendingPathComponent:name];
    if ([NSFileManager.defaultManager fileExistsAtPath:requestURL.path] ||
        IDTextInputGroupURLIsSymlink(requestURL)) {
        return IDTextInputGroupProtocolError(
            error, @"boundary request already exists");
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:
        IDTextInputGroupBoundaryFields(
            token, groupIdentifier, boundary)
        options:NSJSONWritingSortedKeys error:nil];
    NSURL *temporary = [directory URLByAppendingPathComponent:
        [NSString stringWithFormat:@".%@.partial-%@", name,
                                   NSUUID.UUID.UUIDString]];
    NSError *writeError = nil;
    if (![data writeToURL:temporary options:0 error:&writeError] ||
        ![NSFileManager.defaultManager moveItemAtURL:temporary
                                                toURL:requestURL
                                                error:&writeError]) {
        [NSFileManager.defaultManager removeItemAtURL:temporary error:nil];
        return IDTextInputGroupProtocolError(
            error, writeError.localizedDescription ?:
                @"cannot publish boundary request");
    }
    return YES;
}

static BOOL IDTextInputGroupValidateResponse(
    NSDictionary *response, NSDictionary *expected, NSError **error) {
    NSArray *keys = [expected.allKeys arrayByAddingObjectsFromArray:@[
        @"resetSummarySHA256", @"result",
    ]];
    if (!IDTextInputBatchExactKeys(response, keys)) {
        return IDTextInputGroupProtocolError(
            error, @"boundary response keys differ");
    }
    for (NSString *key in expected) {
        if (![response[key] isEqual:expected[key]]) {
            return IDTextInputGroupProtocolError(
                error, @"boundary response sequence differs");
        }
    }
    if (!IDTextInputGroupHex64(response[@"resetSummarySHA256"]) ||
        ![response[@"result"] isEqual:@"ready"]) {
        return IDTextInputGroupProtocolError(
            error, @"boundary response result or hash is invalid");
    }
    return YES;
}

BOOL IDWaitForTextInputGroupBoundaryResponse(
    NSURL *directory, NSString *token, NSString *groupIdentifier,
    IDTextInputGroupBoundary *boundary, NSTimeInterval timeout,
    NSError **error) {
    if (!IDTextInputGroupValidateBoundaryArguments(
            token, groupIdentifier, boundary, error) || timeout <= 0) {
        if (timeout <= 0 && error != NULL && *error == nil) {
            IDTextInputGroupProtocolError(error, @"boundary timeout is invalid");
        }
        return NO;
    }
    NSString *requestName = [NSString stringWithFormat:
        @"boundary-%03lu-request.json",
        (unsigned long)boundary.sequenceIndex];
    NSString *responseName = [NSString stringWithFormat:
        @"boundary-%03lu-response.json",
        (unsigned long)boundary.sequenceIndex];
    NSURL *requestURL = [directory URLByAppendingPathComponent:requestName];
    NSURL *responseURL = [directory URLByAppendingPathComponent:responseName];
    NSDictionary *expected = IDTextInputGroupBoundaryFields(
        token, groupIdentifier, boundary);
    NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + timeout;
    while (NSProcessInfo.processInfo.systemUptime < deadline) {
        if ([NSFileManager.defaultManager fileExistsAtPath:responseURL.path]) {
            if (IDTextInputGroupURLIsSymlink(responseURL)) {
                return IDTextInputGroupProtocolError(
                    error, @"boundary response is a symbolic link");
            }
            NSNumber *regular = nil;
            [responseURL getResourceValue:&regular
                forKey:NSURLIsRegularFileKey error:nil];
            if (!regular.boolValue) {
                return IDTextInputGroupProtocolError(
                    error, @"boundary response is not a regular file");
            }
            NSError *JSONError = nil;
            NSData *data = [NSData dataWithContentsOfURL:responseURL];
            id response = data == nil ? nil :
                [NSJSONSerialization JSONObjectWithData:data options:0
                                                  error:&JSONError];
            if (![response isKindOfClass:NSDictionary.class]) {
                return IDTextInputGroupProtocolError(
                    error, JSONError.localizedDescription ?:
                        @"boundary response JSON is invalid");
            }
            if (!IDTextInputGroupValidateResponse(response, expected, error)) {
                return NO;
            }
            NSError *removeError = nil;
            if (![NSFileManager.defaultManager removeItemAtURL:requestURL
                                                         error:&removeError] ||
                ![NSFileManager.defaultManager removeItemAtURL:responseURL
                                                         error:&removeError]) {
                return IDTextInputGroupProtocolError(
                    error, removeError.localizedDescription ?:
                        @"cannot remove validated boundary records");
            }
            return YES;
        }
        NSTimeInterval remaining =
            deadline - NSProcessInfo.processInfo.systemUptime;
        if (remaining <= 0) break;
        NSDate *until = [NSDate dateWithTimeIntervalSinceNow:
            MIN(0.02, remaining)];
        [NSRunLoop.currentRunLoop runUntilDate:until];
    }
    return IDTextInputGroupProtocolError(
        error, @"timed out waiting for boundary response");
}

static NSString *IDTextInputObservationEventKindName(
    IDTextInputObservationEventKind kind) {
    switch (kind) {
        case IDTextInputObservationEventStarted:
            return @"observation-started";
        case IDTextInputObservationEventRetryRequired:
            return @"retry-required";
        case IDTextInputObservationEventOfferReady:
            return @"offer-ready";
        case IDTextInputObservationEventComplete:
            return @"observation-complete";
    }
    return nil;
}

static NSDictionary *IDTextInputObservationBoundaryFields(
    IDTextInputGroupBoundary *boundary) {
    if (boundary == nil) return nil;
    NSMutableDictionary *fields = [@{
        @"kind": boundary.kind == IDTextInputGroupBoundaryKindHost
            ? @"host" : (boundary.kind == IDTextInputGroupBoundaryKindPass
                ? @"pass" : @"row"),
        @"sequenceIndex": @(boundary.sequenceIndex),
    } mutableCopy];
    if (boundary.kind == IDTextInputGroupBoundaryKindHost) {
        fields[@"batchId"] = boundary.batchIdentifier;
        fields[@"rowId"] = boundary.rowIdentifier;
        fields[@"completedHost"] = boundary.completedHost;
        fields[@"nextHost"] = boundary.nextHost;
    } else if (boundary.kind == IDTextInputGroupBoundaryKindRow) {
        fields[@"batchId"] = boundary.batchIdentifier;
        fields[@"completedRowId"] = boundary.completedRowIdentifier;
        fields[@"nextRowId"] = boundary.nextRowIdentifier;
    } else {
        fields[@"completedBatchId"] = boundary.completedBatchIdentifier;
        fields[@"nextBatchId"] = boundary.nextBatchIdentifier;
    }
    return fields;
}

static NSDictionary *IDTextInputObservationEventFields(
    NSString *token, NSString *groupIdentifier, NSUInteger eventIndex,
    NSUInteger observationIndex, IDTextInputObservationEventKind kind,
    IDTextInputBatchObservation *observation, NSUInteger attempt,
    IDTextInputGroupBoundary *precedingBoundary, NSError **error) {
    NSString *kindName = IDTextInputObservationEventKindName(kind);
    BOOL validAttempt = kind == IDTextInputObservationEventStarted
        ? attempt == 1
        : (kind == IDTextInputObservationEventRetryRequired
            ? attempt > 1 && attempt <= 20 : attempt >= 1 && attempt <= 20);
    BOOL validBoundary = kind == IDTextInputObservationEventStarted
        ? YES : precedingBoundary == nil;
    if (!IDTextInputGroupHex64(token) ||
        ![groupIdentifier hasPrefix:
            @"inline-prediction--snapshot-row-v1--"] ||
        eventIndex < 1 || observationIndex < 1 || observationIndex > 8 ||
        kindName == nil || !validAttempt || !validBoundary ||
        observation.batchIdentifier.length == 0 ||
        observation.rowIdentifier.length == 0) {
        IDTextInputGroupProtocolError(
            error, @"observation event arguments are invalid");
        return nil;
    }
    return @{
        @"schema": @3,
        @"kind": kindName,
        @"token": token,
        @"groupId": groupIdentifier,
        @"eventIndex": @(eventIndex),
        @"observationIndex": @(observationIndex),
        @"attempt": @(attempt),
        @"batchId": observation.batchIdentifier,
        @"rowId": observation.rowIdentifier,
        @"host": IDTextInputBatchHostName(observation.host),
        @"precedingBoundary":
            IDTextInputObservationBoundaryFields(precedingBoundary) ?:
                NSNull.null,
    };
}

BOOL IDWriteTextInputObservationEvent(
    NSURL *directory, NSString *token, NSString *groupIdentifier,
    NSUInteger eventIndex, NSUInteger observationIndex,
    IDTextInputObservationEventKind kind,
    IDTextInputBatchObservation *observation, NSUInteger attempt,
    IDTextInputGroupBoundary *precedingBoundary, NSError **error) {
    NSDictionary *fields = IDTextInputObservationEventFields(
        token, groupIdentifier, eventIndex, observationIndex, kind,
        observation, attempt, precedingBoundary, error);
    if (fields == nil || IDTextInputGroupURLIsSymlink(directory)) return NO;
    NSString *name = [NSString stringWithFormat:
        @"observation-%06lu-event.json", (unsigned long)eventIndex];
    NSURL *destination = [directory URLByAppendingPathComponent:name];
    if ([NSFileManager.defaultManager fileExistsAtPath:destination.path]) {
        return IDTextInputGroupProtocolError(
            error, @"observation event already exists");
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:fields
        options:NSJSONWritingSortedKeys error:nil];
    NSURL *temporary = [directory URLByAppendingPathComponent:
        [NSString stringWithFormat:@".%@.partial-%@", name,
                                   NSUUID.UUID.UUIDString]];
    NSError *writeError = nil;
    if (![data writeToURL:temporary options:NSDataWritingWithoutOverwriting
                    error:&writeError] ||
        ![NSFileManager.defaultManager moveItemAtURL:temporary
                                                toURL:destination
                                                error:&writeError]) {
        [NSFileManager.defaultManager removeItemAtURL:temporary error:nil];
        return IDTextInputGroupProtocolError(
            error, writeError.localizedDescription ?:
                @"cannot publish observation event");
    }
    return YES;
}

BOOL IDWaitForTextInputObservationRestoreResponse(
    NSURL *directory, NSString *token, NSString *groupIdentifier,
    NSUInteger eventIndex, NSUInteger observationIndex,
    IDTextInputObservationEventKind preparationKind,
    IDTextInputBatchObservation *observation, NSUInteger attempt,
    IDTextInputGroupBoundary *precedingBoundary,
    NSTimeInterval timeout, NSError **error) {
    if (preparationKind != IDTextInputObservationEventStarted &&
        preparationKind != IDTextInputObservationEventRetryRequired) {
        return IDTextInputGroupProtocolError(
            error, @"restore response requires a preparation event");
    }
    NSDictionary *event = IDTextInputObservationEventFields(
        token, groupIdentifier, eventIndex, observationIndex,
        preparationKind, observation, attempt, precedingBoundary, error);
    if (event == nil || timeout <= 0) return NO;
    NSString *eventName = [NSString stringWithFormat:
        @"observation-%06lu-event.json", (unsigned long)eventIndex];
    NSString *restoreName = [NSString stringWithFormat:
        @"observation-%06lu-restore.json", (unsigned long)eventIndex];
    NSURL *eventURL = [directory URLByAppendingPathComponent:eventName];
    NSURL *restoreURL = [directory URLByAppendingPathComponent:restoreName];
    NSTimeInterval deadline = NSProcessInfo.processInfo.systemUptime + timeout;
    while (NSProcessInfo.processInfo.systemUptime < deadline) {
        if ([NSFileManager.defaultManager fileExistsAtPath:restoreURL.path]) {
            if (IDTextInputGroupURLIsSymlink(restoreURL)) {
                return IDTextInputGroupProtocolError(
                    error, @"restore response is a symbolic link");
            }
            NSData *data = [NSData dataWithContentsOfURL:restoreURL];
            NSDictionary *response = data == nil ? nil :
                [NSJSONSerialization JSONObjectWithData:data options:0
                                                  error:nil];
            NSMutableDictionary *expected = [event mutableCopy];
            expected[@"kind"] = @"restore-complete";
            expected[@"preparationKind"] =
                IDTextInputObservationEventKindName(preparationKind);
            NSArray *keys = [expected.allKeys arrayByAddingObjectsFromArray:@[
                @"resetSummarySHA256", @"result",
            ]];
            if (!IDTextInputBatchExactKeys(response, keys)) {
                return IDTextInputGroupProtocolError(
                    error, @"restore response keys differ");
            }
            for (NSString *key in expected) {
                if (![response[key] isEqual:expected[key]]) {
                    return IDTextInputGroupProtocolError(
                        error, @"restore response identity differs");
                }
            }
            if (!IDTextInputGroupHex64(response[@"resetSummarySHA256"]) ||
                ![response[@"result"] isEqual:@"ready"]) {
                return IDTextInputGroupProtocolError(
                    error, @"restore response result is invalid");
            }
            NSError *removeError = nil;
            if (![NSFileManager.defaultManager removeItemAtURL:eventURL
                                                         error:&removeError] ||
                ![NSFileManager.defaultManager removeItemAtURL:restoreURL
                                                         error:&removeError]) {
                return IDTextInputGroupProtocolError(
                    error, removeError.localizedDescription ?:
                        @"cannot remove observation handshake records");
            }
            return YES;
        }
        NSTimeInterval remaining =
            deadline - NSProcessInfo.processInfo.systemUptime;
        if (remaining <= 0) break;
        [NSRunLoop.currentRunLoop runUntilDate:
            [NSDate dateWithTimeIntervalSinceNow:MIN(0.02, remaining)]];
    }
    return IDTextInputGroupProtocolError(
        error, @"timed out waiting for restore response");
}

void IDWithTextInputBatch(
    IDTextInputBatch *batch, dispatch_block_t block) {
    NSMutableDictionary *thread = NSThread.currentThread.threadDictionary;
    if (thread[IDTextInputBatchThreadKey] != nil) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Nested text-input batch"];
    }
    thread[IDTextInputBatchThreadKey] = batch;
    @try {
        block();
    } @finally {
        [thread removeObjectForKey:IDTextInputBatchThreadKey];
    }
}

void IDWithTextInputBatchObservation(
    IDTextInputBatchObservation *observation, dispatch_block_t block) {
    NSMutableDictionary *thread = NSThread.currentThread.threadDictionary;
    IDTextInputBatch *batch = thread[IDTextInputBatchThreadKey];
    if (batch == nil || ![batch.observations containsObject:observation]) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Text-input observation has no active batch"];
    }
    if (thread[IDTextInputBatchObservationThreadKey] != nil) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Nested text-input batch observation"];
    }
    thread[IDTextInputBatchObservationThreadKey] = observation;
    @try {
        block();
    } @finally {
        [thread removeObjectForKey:IDTextInputBatchObservationThreadKey];
    }
}

NSString *IDTextInputBatchAttachmentName(NSString *name) {
    IDTextInputBatch *batch =
        NSThread.currentThread.threadDictionary[IDTextInputBatchThreadKey];
    IDTextInputBatchObservation *observation =
        NSThread.currentThread.threadDictionary[
            IDTextInputBatchObservationThreadKey];
    if (batch == nil) return name;
    if (observation == nil) {
        return [NSString stringWithFormat:@"group--%@--%@",
                batch.identifier, name];
    }
    NSString *host = observation.host == IDTextInputBatchHostStock
        ? @"stock" : @"custom";
    NSNumber *attempt = NSThread.currentThread.threadDictionary[
        IDTextInputBatchAttemptThreadKey];
    if (attempt != nil) {
        return [NSString stringWithFormat:
            @"group--%@--%@--%@--attempt-%03lu--%@",
            batch.identifier, observation.rowIdentifier, host,
            (unsigned long)attempt.unsignedIntegerValue, name];
    }
    return [NSString stringWithFormat:@"group--%@--%@--%@--%@",
            batch.identifier, observation.rowIdentifier, host, name];
}

void IDAttachTextInputBatchHierarchy(
    XCTestCase *testCase, XCUIApplication *application) {
    XCTAttachment *attachment = [XCTAttachment
        attachmentWithString:application.debugDescription ?: @""];
    attachment.name = IDTextInputBatchAttachmentName(@"hierarchy.txt");
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [testCase addAttachment:attachment];
}

static BOOL IDRunTextInputBatchWithRowTransition(
    XCTestCase *testCase, IDTextInputBatch *batch,
    void (^runObservation)(IDTextInputBatchObservation *observation),
    BOOL (^crossTransition)(IDTextInputBatchObservation *completed,
                            IDTextInputBatchObservation *next)) {
    __block BOOL completed = YES;
    IDWithTextInputBatch(batch, ^{
    NSMutableArray<NSDictionary *> *serialized = [NSMutableArray array];
    for (IDTextInputBatchObservation *observation in batch.observations) {
        [serialized addObject:@{
            @"row": observation.rowIdentifier,
            @"host": observation.host == IDTextInputBatchHostStock
                ? @"stock" : @"custom",
        }];
    }
    NSDictionary *metadata = @{
        @"schema": @1,
        @"batchId": batch.identifier,
        @"subsystem": batch.subsystem,
        @"runtime": @{@"osVersion": @"26.5", @"osBuild": @"23F73"},
        @"udid": IDTextInputBatchUDID,
        @"observations": serialized,
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:metadata
        options:NSJSONWritingSortedKeys error:nil];
    XCTAttachment *metadataAttachment =
        [XCTAttachment attachmentWithData:data
                    uniformTypeIdentifier:@"public.json"];
    metadataAttachment.name =
        IDTextInputBatchAttachmentName(@"metadata.json");
    metadataAttachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [testCase addAttachment:metadataAttachment];

    for (NSUInteger index = 0; index < batch.observations.count; index++) {
        IDTextInputBatchObservation *observation = batch.observations[index];
        [XCTContext runActivityNamed:observation.identity
            block:^(id<XCTActivity> activity) {
                (void)activity;
                IDWithTextInputBatchObservation(observation, ^{
                    runObservation(observation);
                });
            }];
        if (crossTransition != nil && index + 1 < batch.observations.count) {
            IDTextInputBatchObservation *next = batch.observations[index + 1];
            if (!crossTransition(observation, next)) {
                completed = NO;
                break;
            }
        }
    }
    });
    return completed;
}

void IDRunTextInputBatch(
    XCTestCase *testCase, IDTextInputBatch *batch,
    void (^runObservation)(IDTextInputBatchObservation *observation)) {
    IDRunTextInputBatchWithRowTransition(
        testCase, batch, runObservation, nil);
}

void IDRunTextInputGroup(
    XCTestCase *testCase, IDTextInputGroup *group,
    void (^runObservation)(IDTextInputBatchObservation *observation),
    BOOL (^crossBoundary)(IDTextInputGroupBoundary *boundary)) {
    if (group.batches.count != 1 && group.batches.count != 4) {
        XCTFail(@"Text-input group must contain exactly one or four batches");
        return;
    }
    NSString *token = NSProcessInfo.processInfo.environment[
        @"INPUTDEC_TEXT_INPUT_GROUP_TOKEN"];
    NSString *tokenHash = IDTextInputGroupTokenSHA256(token);
    if (tokenHash == nil) {
        XCTFail(@"INPUTDEC_TEXT_INPUT_GROUP_TOKEN is required");
        return;
    }
    NSDictionary *metadata = @{
        @"schema": @1,
        @"groupId": group.identifier,
        @"subsystem": group.subsystem,
        @"runtime": @{ @"osVersion": @"26.5", @"osBuild": @"23F73" },
        @"udid": IDTextInputBatchUDID,
        @"tokenSHA256": tokenHash,
        @"batches": [group.batches valueForKey:@"identifier"],
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:metadata
        options:NSJSONWritingSortedKeys error:nil];
    XCTAttachment *attachment = [XCTAttachment attachmentWithData:data
        uniformTypeIdentifier:@"public.json"];
    attachment.name = @"group-metadata.json";
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [testCase addAttachment:attachment];

    __block NSUInteger sequenceIndex = 1;
    for (NSUInteger index = 0; index < group.batches.count; index++) {
        IDTextInputBatch *batch = group.batches[index];
        BOOL completed = IDRunTextInputBatchWithRowTransition(
            testCase, batch, runObservation,
            batch.stateSensitive
                ? ^BOOL(IDTextInputBatchObservation *completed,
                        IDTextInputBatchObservation *next) {
                    BOOL sameRow = [completed.rowIdentifier
                        isEqual:next.rowIdentifier];
                    IDTextInputGroupBoundary *boundary = sameRow
                        ? IDTextInputGroupHostBoundary(
                            sequenceIndex, batch, completed, next)
                        : IDTextInputGroupRowBoundary(
                            sequenceIndex, batch, completed.rowIdentifier,
                            next.rowIdentifier);
                    sequenceIndex += 1;
                    return crossBoundary(boundary);
                }
                : nil);
        if (!completed) return;
        if (index + 1 == group.batches.count) continue;
        IDTextInputBatch *next = group.batches[index + 1];
        IDTextInputGroupBoundary *boundary = IDTextInputGroupPassBoundary(
            sequenceIndex, batch, next);
        sequenceIndex += 1;
        if (!crossBoundary(boundary)) return;
    }
}

static void IDRecordSnapshotRunnerIssue(XCTestCase *testCase,
                                        NSString *description) {
    [testCase recordIssue:[[XCTIssue alloc]
        initWithType:XCTIssueTypeAssertionFailure
        compactDescription:description]];
}

static BOOL IDSnapshotCompletedIndexesAreContiguous(
    NSIndexSet *indexes, NSUInteger observationCount) {
    if (indexes.count > observationCount) return NO;
    if (indexes.count == 0) return YES;
    if (indexes.firstIndex != 1 || indexes.lastIndex != indexes.count) {
        return NO;
    }
    return [indexes countOfIndexesInRange:NSMakeRange(1, indexes.count)] ==
        indexes.count;
}

static BOOL IDAttachSnapshotGroupMetadata(
    XCTestCase *testCase, IDTextInputGroup *group) {
    NSString *token = NSProcessInfo.processInfo.environment[
        @"INPUTDEC_TEXT_INPUT_GROUP_TOKEN"];
    NSString *tokenHash = IDTextInputGroupTokenSHA256(token);
    if (tokenHash == nil) {
        IDRecordSnapshotRunnerIssue(
            testCase, @"INPUTDEC_TEXT_INPUT_GROUP_TOKEN is required");
        return NO;
    }
    NSDictionary *metadata = @{
        @"schema": @1,
        @"groupId": group.identifier,
        @"subsystem": group.subsystem,
        @"runtime": @{ @"osVersion": @"26.5", @"osBuild": @"23F73" },
        @"udid": IDTextInputBatchUDID,
        @"tokenSHA256": tokenHash,
        @"batches": [group.batches valueForKey:@"identifier"],
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:metadata
        options:NSJSONWritingSortedKeys error:nil];
    XCTAttachment *attachment = [XCTAttachment attachmentWithData:data
        uniformTypeIdentifier:@"public.json"];
    attachment.name = @"group-metadata.json";
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [testCase addAttachment:attachment];
    return YES;
}

static void IDAttachSnapshotBatchMetadata(
    XCTestCase *testCase, IDTextInputBatch *batch) {
    NSMutableArray<NSDictionary *> *observations = [NSMutableArray array];
    for (IDTextInputBatchObservation *observation in batch.observations) {
        [observations addObject:@{
            @"row": observation.rowIdentifier,
            @"host": IDTextInputBatchHostName(observation.host),
        }];
    }
    NSDictionary *metadata = @{
        @"schema": @1,
        @"batchId": batch.identifier,
        @"subsystem": batch.subsystem,
        @"runtime": @{ @"osVersion": @"26.5", @"osBuild": @"23F73" },
        @"udid": IDTextInputBatchUDID,
        @"observations": observations,
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:metadata
        options:NSJSONWritingSortedKeys error:nil];
    XCTAttachment *attachment = [XCTAttachment attachmentWithData:data
        uniformTypeIdentifier:@"public.json"];
    attachment.name = [NSString stringWithFormat:@"group--%@--metadata.json",
                                                  batch.identifier];
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [testCase addAttachment:attachment];
}

NSIndexSet *IDLoadTextInputCompletedObservationIndexes(void) {
    NSString *value = NSProcessInfo.processInfo.environment[
        @"INPUTDEC_TEXT_INPUT_COMPLETED_OBSERVATIONS"];
    if (value.length == 0) return [NSIndexSet indexSet];
    NSArray<NSString *> *components = [value componentsSeparatedByString:@","];
    NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet]
        invertedSet];
    for (NSUInteger index = 0; index < components.count; index++) {
        NSString *component = components[index];
        NSUInteger expected = index + 1;
        if (component.length == 0 ||
            [component rangeOfCharacterFromSet:nonDigits].location !=
                NSNotFound ||
            ![component isEqual:[NSString stringWithFormat:@"%lu",
                                 (unsigned long)expected]] ||
            expected > 8) {
            return nil;
        }
        [indexes addIndex:expected];
    }
    return indexes;
}

static void IDWithTextInputObservationAttempt(NSUInteger attempt,
                                               dispatch_block_t block) {
    NSMutableDictionary *thread = NSThread.currentThread.threadDictionary;
    if (thread[IDTextInputBatchAttemptThreadKey] != nil) {
        [NSException raise:NSInternalInconsistencyException
                    format:@"Nested text-input observation attempt"];
    }
    thread[IDTextInputBatchAttemptThreadKey] = @(attempt);
    @try {
        block();
    } @finally {
        [thread removeObjectForKey:IDTextInputBatchAttemptThreadKey];
    }
}

void IDRunSnapshotTextInputGroup(
    XCTestCase *testCase, IDTextInputGroup *group,
    NSUInteger maximumReadinessAttempts,
    NSIndexSet *completedObservationIndexes,
    IDTextInputObservationAttemptOutcome (^runAttempt)(
        IDTextInputBatchObservation *observation, NSUInteger attempt),
    BOOL (^handleEvent)(IDTextInputObservationEventKind kind,
                        IDTextInputBatchObservation *observation,
                        NSUInteger attempt,
                        IDTextInputGroupBoundary *precedingBoundary)) {
    if (group.batches.count != 4 || maximumReadinessAttempts < 1 ||
        maximumReadinessAttempts > 20 || runAttempt == nil ||
        handleEvent == nil) {
        IDRecordSnapshotRunnerIssue(
            testCase, @"Snapshot runner requires four batches and 1-20 attempts");
        return;
    }
    NSMutableArray<IDTextInputBatchObservation *> *observations =
        [NSMutableArray arrayWithCapacity:8];
    NSMutableArray<IDTextInputBatch *> *observationBatches =
        [NSMutableArray arrayWithCapacity:8];
    for (IDTextInputBatch *batch in group.batches) {
        if (batch.observations.count != 2) {
            IDRecordSnapshotRunnerIssue(
                testCase, @"Snapshot runner requires two observations per batch");
            return;
        }
        for (IDTextInputBatchObservation *observation in batch.observations) {
            [observations addObject:observation];
            [observationBatches addObject:batch];
        }
    }
    if (!IDSnapshotCompletedIndexesAreContiguous(
            completedObservationIndexes, observations.count)) {
        IDRecordSnapshotRunnerIssue(
            testCase, @"Completed observations must be a contiguous 1-based prefix");
        return;
    }
    if (!IDAttachSnapshotGroupMetadata(testCase, group)) return;
    for (IDTextInputBatch *batch in group.batches) {
        IDAttachSnapshotBatchMetadata(testCase, batch);
    }

    NSMutableArray<NSDictionary *> *attemptEntries = [NSMutableArray array];

    for (NSUInteger index = completedObservationIndexes.count;
         index < observations.count; index++) {
        IDTextInputBatchObservation *observation = observations[index];
        IDTextInputBatch *batch = observationBatches[index];
        IDTextInputGroupBoundary *precedingBoundary = nil;
        if (index > 0) {
            IDTextInputBatchObservation *previous = observations[index - 1];
            IDTextInputBatch *previousBatch = observationBatches[index - 1];
            precedingBoundary = previousBatch == batch
                ? IDTextInputGroupHostBoundary(
                    index, batch, previous, observation)
                : IDTextInputGroupPassBoundary(
                    index, previousBatch, batch);
        }

        __block BOOL shouldContinue = YES;
        IDWithTextInputBatch(batch, ^{
            IDWithTextInputBatchObservation(observation, ^{
                for (NSUInteger attempt = 1;
                     attempt <= maximumReadinessAttempts; attempt++) {
                    IDTextInputObservationEventKind preparationKind =
                        attempt == 1 ? IDTextInputObservationEventStarted
                                     : IDTextInputObservationEventRetryRequired;
                    IDTextInputGroupBoundary *eventBoundary =
                        attempt == 1 ? precedingBoundary : nil;
                    if (!handleEvent(preparationKind, observation, attempt,
                                     eventBoundary)) {
                        shouldContinue = NO;
                        return;
                    }

                    __block IDTextInputObservationAttemptOutcome outcome;
                    IDWithTextInputObservationAttempt(attempt, ^{
                        outcome = runAttempt(observation, attempt);
                    });
                    if (outcome ==
                            IDTextInputObservationAttemptReadinessUnavailable) {
                        if (attempt == maximumReadinessAttempts) {
                            IDRecordSnapshotRunnerIssue(testCase,
                                [NSString stringWithFormat:
                                    @"Inline prediction remained unavailable after %lu attempts",
                                    (unsigned long)maximumReadinessAttempts]);
                            shouldContinue = NO;
                            return;
                        }
                        continue;
                    }
                    if (!handleEvent(IDTextInputObservationEventOfferReady,
                                     observation, attempt, nil)) {
                        shouldContinue = NO;
                        return;
                    }
                    if (!handleEvent(IDTextInputObservationEventComplete,
                                     observation, attempt, nil)) {
                        shouldContinue = NO;
                        return;
                    }
                    [attemptEntries addObject:@{
                        @"observationIndex": @(index + 1),
                        @"batchId": batch.identifier,
                        @"rowId": observation.rowIdentifier,
                        @"host": IDTextInputBatchHostName(observation.host),
                        @"successfulAttempt": @(attempt),
                        @"readinessAttempts": @(attempt - 1),
                    }];
                    return;
                }
            });
        });
        if (!shouldContinue) return;
    }

    NSDictionary *attemptMap = @{
        @"schema": @1,
        @"groupId": group.identifier,
        @"observations": attemptEntries,
    };
    NSData *attemptData = [NSJSONSerialization
        dataWithJSONObject:attemptMap options:NSJSONWritingSortedKeys error:nil];
    XCTAttachment *attemptAttachment = [XCTAttachment
        attachmentWithData:attemptData uniformTypeIdentifier:@"public.json"];
    attemptAttachment.name = @"observation-attempts.json";
    attemptAttachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    attemptAttachment.userInfo = @{ @"observations": attemptEntries };
    [testCase addAttachment:attemptAttachment];
}

BOOL IDCrossSelectedTextInputGroupBoundary(
    XCTestCase *testCase, IDTextInputGroup *group,
    IDTextInputGroupBoundary *boundary) {
    XCUIApplication *custom = [[XCUIApplication alloc]
        initWithBundleIdentifier:@"com.inputdec.demo"];
    XCUIApplication *stock = [[XCUIApplication alloc]
        initWithBundleIdentifier:@"com.inputdec.stockoracle"];
    if (custom.state != XCUIApplicationStateNotRunning ||
        stock.state != XCUIApplicationStateNotRunning) {
        XCTFail(@"Target applications must be stopped before boundary %lu",
                (unsigned long)boundary.sequenceIndex);
        return NO;
    }
    NSString *token = NSProcessInfo.processInfo.environment[
        @"INPUTDEC_TEXT_INPUT_GROUP_TOKEN"];
    NSError *error = nil;
    NSURL *directory = IDTextInputGroupHandshakeDirectory(nil, token, &error);
    if (directory == nil || !IDWriteTextInputGroupBoundaryRequest(
            directory, token, group.identifier, boundary, &error) ||
        !IDWaitForTextInputGroupBoundaryResponse(
            directory, token, group.identifier, boundary, 60.0, &error)) {
        XCTFail(@"Cannot cross text-input group boundary %lu: %@",
                (unsigned long)boundary.sequenceIndex,
                error.localizedDescription);
        return NO;
    }
    return YES;
}
