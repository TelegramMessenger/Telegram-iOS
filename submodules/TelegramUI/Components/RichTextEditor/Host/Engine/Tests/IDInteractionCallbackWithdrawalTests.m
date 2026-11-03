@import XCTest;

#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDPrivateUIKit.h"
#import "IDPrivateUIKit+Testing.h"
#import "IDTextLayoutCanvasView.h"
#import "IDTextView.h"

#import <objc/runtime.h>
#import "IDEngineSourceLayout.h"

@interface IDInteractionCallbackWithdrawalTests : XCTestCase
@end

@interface IDBlockTextView (GestureRecognizerHostWithdrawalTesting)
- (UIView *)textInputView;
- (UIView *)_textInputViewForAddingGestureRecognizers;
@end

@interface IDMissingInteractionHostMethodProbe : IDBlockTextView
@property(nonatomic, copy) NSString *missingSelectorName;
@end

@implementation IDMissingInteractionHostMethodProbe
- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    if ([NSStringFromSelector(selector) isEqual:self.missingSelectorName]) {
        return nil;
    }
    return [super methodSignatureForSelector:selector];
}
@end

static NSString *IDInteractionCallbacksSourceRoot(void) {
    return IDEngineSourceRoot();
}

static NSString *IDInteractionSource(NSString *relativePath) {
    return [NSString stringWithContentsOfFile:
        IDEngineSourceFile(relativePath)
                                         encoding:NSUTF8StringEncoding
                                            error:nil];
}

static BOOL IDSourceMethodExistsInImplementation(
    NSString *source,
    NSString *implementation,
    NSString *selectorName) {
    NSString *opening = [@"@implementation " stringByAppendingString:implementation];
    NSRange implementationStart = [source rangeOfString:opening];
    if (implementationStart.location == NSNotFound) return NO;
    NSRange searchRange = NSMakeRange(
        NSMaxRange(implementationStart),
        source.length - NSMaxRange(implementationStart));
    NSRange implementationEnd = [source rangeOfString:@"@end"
                                               options:0
                                                 range:searchRange];
    if (implementationEnd.location == NSNotFound) return NO;
    NSRange bodyRange = NSMakeRange(
        NSMaxRange(implementationStart),
        implementationEnd.location - NSMaxRange(implementationStart));
    // A callback UIKit sends under a private name is compiled under its neutral `tgpn_` name
    // (`TGPrivateMethodAliases.h`); either spelling is the definition.
    for (NSString *name in @[selectorName, IDNeutralSelectorName(selectorName)]) {
        NSString *escaped = [NSRegularExpression escapedPatternForString:name];
        NSRegularExpression *expression = [NSRegularExpression
            regularExpressionWithPattern:[NSString stringWithFormat:
                @"(?m)^\\s*[-+]\\s*\\([^\\n)]*\\)\\s*%@\\s*\\{", escaped]
                                   options:0 error:nil];
        if ([expression firstMatchInString:source options:0 range:bodyRange] != nil) return YES;
    }
    return NO;
}

static NSArray<NSString *> *IDParsedInteractionHostABISelectors(void) {
    NSString *source = IDInteractionSource(@"PrivateUIKit/IDPrivateUIKit.m");
    NSRange start = [source rangeOfString:
        @"static NSArray<IDInteractionABISpec *> *IDInteractionHostABISpecs(void)"];
    if (start.location == NSNotFound) return @[];
    NSRange tail = NSMakeRange(NSMaxRange(start), source.length - NSMaxRange(start));
    NSRange end = [source rangeOfString:@"\n}\n" options:0 range:tail];
    if (end.location == NSNotFound) return @[];
    NSRange body = NSMakeRange(start.location, NSMaxRange(end) - start.location);
    // A selector is spelled either as a literal or, for a private UIKit name, as its encoded
    // table entry (`TGPN_<name>()`, `TGPrivateRuntimeNames.h`).
    NSRegularExpression *expression = [NSRegularExpression
        regularExpressionWithPattern:@"IDInteractionABISpecMake\\(\\s*(?:@\"([^\"]+)\"|(TGPN_\\w+)\\(\\))"
                               options:0 error:nil];
    NSDictionary<NSString *, NSString *> *decoded = IDPrivateRuntimeNamesByFunction();
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSTextCheckingResult *match
         in [expression matchesInString:source options:0 range:body]) {
        if ([match rangeAtIndex:1].location != NSNotFound) {
            [names addObject:[source substringWithRange:[match rangeAtIndex:1]]];
        } else {
            NSString *function = [source substringWithRange:[match rangeAtIndex:2]];
            [names addObject:decoded[function] ?: function];
        }
    }
    return names.copy;
}

static BOOL IDClassLocallyImplementsSelector(Class cls, SEL selector) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    BOOL found = NO;
    for (unsigned int index = 0; index < count; index += 1) {
        if (method_getName(methods[index]) == selector) {
            found = YES;
            break;
        }
    }
    free(methods);
    return found;
}

@implementation IDInteractionCallbackWithdrawalTests

- (void)testBlockGestureRecognizerHostAuthorizationFixtureIsPinnedAndComplete {
    NSString *relativePath =
        @"Tests/Fixtures/BlockGestureRecognizerHostCallbackAuthorization-iOS26.5.json";
    NSString *path = IDEngineSourceFile(relativePath);
    NSData *data = [NSData dataWithContentsOfFile:path];
    XCTAssertNotNil(data, @"Missing %@", relativePath);
    if (data == nil) return;

    NSError *error = nil;
    NSDictionary<NSString *, id> *fixture =
        [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    XCTAssertNil(error);
    XCTAssertTrue([fixture isKindOfClass:NSDictionary.class]);
    if (![fixture isKindOfClass:NSDictionary.class]) return;

    NSSet<NSString *> *expectedTopLevelKeys = [NSSet setWithArray:@[
        @"schema", @"runtime", @"selector", @"owner", @"decision",
        @"fallbackHost", @"hopper", @"artifacts", @"isolatedFailureArtifact",
    ]];
    XCTAssertEqualObjects([NSSet setWithArray:fixture.allKeys], expectedTopLevelKeys);
    XCTAssertEqualObjects(fixture[@"schema"], @1);
    XCTAssertEqualObjects(fixture[@"runtime"], (@{
        @"platform": @"iOS", @"version": @"26.5", @"build": @"23F73"
    }));
    XCTAssertEqualObjects(fixture[@"selector"],
                          @"_textInputViewForAddingGestureRecognizers");
    XCTAssertEqualObjects(fixture[@"owner"],
                          @"IDBlockTextView(PrivateInteractionCallbacks)");
    XCTAssertEqualObjects(fixture[@"decision"], @"requiredNativeInteractionHost");
    XCTAssertEqualObjects(fixture[@"fallbackHost"], @"blockStack");
    XCTAssertEqualObjects(fixture[@"hopper"], (@{
        @"receiver": @"0x1615ff4",
        @"guardCaller": @"0x1566108",
        @"guardXref": @"0x15661f8",
        @"assistantInitializer": @"0x156460c",
        @"graphInstaller": @"0x15663f4"
    }));

    NSDictionary<NSString *, NSString *> *artifacts = fixture[@"artifacts"];
    NSSet<NSString *> *expectedArtifactKeys = [NSSet setWithArray:
        @[@"units", @"lifecycle", @"batchedUI", @"touchUI"]];
    XCTAssertEqualObjects([NSSet setWithArray:artifacts.allKeys],
                          expectedArtifactKeys);
    NSDictionary<NSString *, NSString *> *isolated = fixture[@"isolatedFailureArtifact"];
    NSSet<NSString *> *expectedIsolatedKeys =
        [NSSet setWithArray:@[@"retained", @"withdrawn"]];
    XCTAssertEqualObjects([NSSet setWithArray:isolated.allKeys],
                          expectedIsolatedKeys);
    NSMutableArray<NSString *> *paths = [NSMutableArray arrayWithArray:artifacts.allValues];
    [paths addObjectsFromArray:isolated.allValues];
    for (NSString *artifact in paths) {
        // Named, not opened — see IDIsUpstreamRunArtifactPath.
        XCTAssertTrue(IDIsUpstreamRunArtifactPath(artifact), @"%@", artifact);
    }
}

- (void)testBlockInteractionPolicyCallbackAuthorizationHasExactEvidence {
    NSString *relativePath =
        @"Tests/Fixtures/BlockInteractionPolicyCallbackAuthorization-iOS26.5.json";
    NSString *path = IDEngineSourceFile(relativePath);
    NSData *data = [NSData dataWithContentsOfFile:path];
    XCTAssertNotNil(data, @"Missing %@", relativePath);
    if (data == nil) return;

    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    XCTAssertNil(error);
    XCTAssertTrue([object isKindOfClass:NSDictionary.class]);
    if (![object isKindOfClass:NSDictionary.class]) return;

    NSDictionary<NSString *, id> *fixture = object;
    XCTAssertEqualObjects(fixture[@"osVersion"], @"26.5");
    XCTAssertEqualObjects(fixture[@"build"], @"23F73");
    NSArray<NSString *> *expectedNames = @[
        @"_updateSelectionGestures",
        @"_isInteractiveTextSelectionDisabled",
        @"hasEditableSelection",
        @"_textKit2CanvasDidLayout",
    ];
    NSArray<NSDictionary<NSString *, id> *> *rows = fixture[@"selectors"];
    XCTAssertTrue([rows isKindOfClass:NSArray.class]);
    XCTAssertEqual(rows.count, expectedNames.count);
    if (![rows isKindOfClass:NSArray.class] || rows.count != expectedNames.count) {
        return;
    }

    NSSet<NSString *> *allowedDecisions =
        [NSSet setWithArray:@[@"safeFallback", @"required"]];
    NSMutableSet<NSString *> *uniqueNames = [NSMutableSet set];
    for (NSUInteger index = 0; index < rows.count; index++) {
        NSDictionary<NSString *, id> *row = rows[index];
        XCTAssertTrue([row isKindOfClass:NSDictionary.class], @"row %lu",
                      (unsigned long)index);
        NSString *name = [row[@"name"] isKindOfClass:NSString.class]
            ? row[@"name"] : nil;
        XCTAssertEqualObjects(name, expectedNames[index]);
        if (name != nil) [uniqueNames addObject:name];
        XCTAssertTrue([allowedDecisions containsObject:row[@"decision"]], @"%@", name);

        NSArray<NSString *> *evidence = row[@"evidence"];
        XCTAssertTrue([evidence isKindOfClass:NSArray.class], @"%@", name);
        XCTAssertGreaterThan(evidence.count, 0U, @"%@", name);
        BOOL foundHopperEvidence = NO;
        BOOL foundResultBundle = NO;
        for (id item in evidence) {
            XCTAssertTrue([item isKindOfClass:NSString.class], @"%@", name);
            if (![item isKindOfClass:NSString.class]) continue;
            NSString *entry = item;
            XCTAssertGreaterThan(entry.length, 0U, @"%@", name);
            if ([entry hasPrefix:@"docs/hopper/UIKitCore-iOS26.5.md#"] ) {
                foundHopperEvidence = YES;
                NSString *document = [[entry componentsSeparatedByString:@"#"] firstObject];
                XCTAssertTrue([[NSFileManager defaultManager]
                    fileExistsAtPath:IDEngineSourceFile(document)], @"%@", entry);
            }
            if (IDIsUpstreamRunArtifactPath(entry)) {
                // Named, not opened — see IDIsUpstreamRunArtifactPath. The HOPPER document cited
                // beside it is versioned here, so that reference above keeps its disk check.
                foundResultBundle = YES;
            }
        }
        XCTAssertTrue(foundHopperEvidence, @"%@", name);
        XCTAssertTrue(foundResultBundle, @"%@", name);
    }
    XCTAssertEqual(uniqueNames.count, expectedNames.count);
}

- (void)testBlockInteractionPolicyCallbacksMatchPermanentAuthorization {
    NSString *path = IDEngineSourceFile(@"Tests/Fixtures/BlockInteractionPolicyCallbackAuthorization-iOS26.5.json");
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSDictionary<NSString *, id> *fixture = data == nil ? nil :
        [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    XCTAssertNotNil(fixture);
    NSArray<NSDictionary<NSString *, id> *> *rows = fixture[@"selectors"];
    XCTAssertEqual(rows.count, 4U);

    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 240, 120)
        attributedBlocks:@[[[NSAttributedString alloc]
            initWithString:@"alpha beta"]]];
    NSArray<NSString *> *abi = IDParsedInteractionHostABISelectors();
    for (NSDictionary<NSString *, id> *row in rows) {
        BOOL expected = [row[@"decision"] isEqualToString:@"required"];
        NSString *name = row[@"name"];
        SEL selector = NSSelectorFromString(name);
        XCTAssertEqual(class_getInstanceMethod(IDBlockTextView.class, selector) != NULL,
                       expected, @"%@", name);
        XCTAssertEqual([view respondsToSelector:selector], expected, @"%@", name);
        XCTAssertEqual([abi containsObject:name], expected, @"%@", name);
    }
    XCTAssertNoThrow([IDPrivateUIKit requireInteractionHost:view
                                                      stage:@"Permanent policy ABI"]);
}

- (void)testBlockInteractionRenderFallbackSelectorsArePermanentlyAbsent {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 240, 120)
        attributedBlocks:@[[[NSAttributedString alloc]
            initWithString:@"alpha beta"]]];
    for (NSString *name in @[
             @"customRenderController",
             @"_convertPointFromRenderSpace:",
         ]) {
        SEL selector = NSSelectorFromString(name);
        XCTAssertEqual(class_getInstanceMethod(IDBlockTextView.class, selector), NULL,
                       @"%@", name);
        XCTAssertFalse([view respondsToSelector:selector], @"%@", name);
    }
    XCTAssertNoThrow([IDPrivateUIKit requireInteractionHost:view
                                                      stage:@"Permanent reduced host ABI"]);
    NSArray<NSString *> *selectors = IDParsedInteractionHostABISelectors();
    XCTAssertFalse([selectors containsObject:@"customRenderController"]);
    XCTAssertFalse([selectors containsObject:@"_convertPointFromRenderSpace:"]);
}

- (NSString *)authorizationFixturePath {
    NSString *testsDirectory = [@(__FILE__) stringByDeletingLastPathComponent];
    return [testsDirectory stringByAppendingPathComponent:
        @"Fixtures/SelectionCallbackAuthorization-iOS26.5.json"];
}

- (NSDictionary<NSString *, id> *)authorizationFixture {
    NSData *data = [NSData dataWithContentsOfFile:self.authorizationFixturePath];
    if (data == nil) return nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [object isKindOfClass:NSDictionary.class] ? object : nil;
}

- (NSArray<NSDictionary<NSString *, id> *> *)callbacksAuthorizedAs:
        (NSString *)authorization {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:
        ^BOOL(NSDictionary<NSString *, id> *row,
              NSDictionary<NSString *, id> *bindings) {
            (void)bindings;
            return [row[@"authorization"] isEqual:authorization];
        }];
    return [self.authorizationFixture[@"callbacks"]
        filteredArrayUsingPredicate:predicate];
}

- (NSArray<NSString *> *)authorizationErrors:
        (NSDictionary<NSString *, id> *)fixture {
    NSMutableArray<NSString *> *errors = [NSMutableArray array];
    if (![fixture[@"schema"] isEqual:@1]) [errors addObject:@"schema"];
    NSDictionary *runtime = fixture[@"runtime"];
    if (![runtime[@"osVersion"] isEqual:@"26.5"] ||
        ![runtime[@"osBuild"] isEqual:@"23F73"]) {
        [errors addObject:@"runtime"];
    }
    NSArray<NSDictionary<NSString *, id> *> *rows = fixture[@"callbacks"];
    if (![rows isKindOfClass:NSArray.class] || rows.count != 5U) {
        [errors addObject:@"rowCount"];
        return errors.copy;
    }
    NSSet<NSString *> *allowed = [NSSet setWithArray:@[
        @"safeFallback", @"requiredNativeChrome", @"highlightOnly"
    ]];
    NSMutableSet<NSString *> *selectors = [NSMutableSet set];
    NSMutableSet<NSString *> *definitions = [NSMutableSet set];
    for (NSDictionary<NSString *, id> *row in rows) {
        NSString *selector = [row[@"selector"] isKindOfClass:NSString.class]
            ? row[@"selector"] : nil;
        NSString *definition = [row[@"definition"] isKindOfClass:NSString.class]
            ? row[@"definition"] : nil;
        if (selector.length == 0) [errors addObject:@"selector"];
        if ([selectors containsObject:selector]) [errors addObject:@"duplicate"];
        if (selector != nil) [selectors addObject:selector];
        if (definition.length == 0 || ![definition hasSuffix:@"=1"]) {
            [errors addObject:@"definition"];
        }
        if ([definitions containsObject:definition]) [errors addObject:@"definition"];
        if (definition != nil) [definitions addObject:definition];
        id methodAbsent = row[@"methodAbsent"];
        if (methodAbsent == nil ||
            CFGetTypeID((__bridge CFTypeRef)methodAbsent) != CFBooleanGetTypeID() ||
            ![methodAbsent boolValue]) {
            [errors addObject:@"methodAbsent"];
        }
        if (![allowed containsObject:row[@"authorization"]]) {
            [errors addObject:@"authorization"];
        }
        if (![row[@"hopperProcedures"] isKindOfClass:NSArray.class] ||
            [row[@"hopperProcedures"] count] == 0) {
            [errors addObject:@"hopperProcedures"];
        }
        if (![row[@"artifacts"] isKindOfClass:NSArray.class] ||
            [row[@"artifacts"] count] == 0) {
            [errors addObject:@"artifacts"];
        }
        if (![row[@"reason"] isKindOfClass:NSString.class] ||
            [row[@"reason"] length] == 0) {
            [errors addObject:@"reason"];
        }
    }
    if (selectors.count != 5U) [errors addObject:@"completeness"];
    return errors.copy;
}

- (void)testSelectionCallbackAuthorizationFixtureHasFiveCompleteUniqueRows {
    NSDictionary<NSString *, id> *fixture = self.authorizationFixture;
    XCTAssertNotNil(fixture);
    XCTAssertEqualObjects([self authorizationErrors:fixture], @[]);
    XCTAssertEqualObjects(fixture[@"schema"], @1);
    XCTAssertEqualObjects(fixture[@"runtime"][@"osVersion"], @"26.5");
    XCTAssertEqualObjects(fixture[@"runtime"][@"osBuild"], @"23F73");
    XCTAssertEqual([fixture[@"callbacks"] count], 5U);
}

- (void)testSelectionCallbackAuthorizationFixtureRejectsMalformedRows {
    NSDictionary<NSString *, id> *fixture = self.authorizationFixture;
    XCTAssertNotNil(fixture);
    if (fixture == nil) return;
    NSArray<void (^)(NSMutableDictionary *)> *mutations = @[
        ^(NSMutableDictionary *copy) { [copy removeObjectForKey:@"schema"]; },
        ^(NSMutableDictionary *copy) {
            copy[@"runtime"] = @{@"osVersion": @"26.4", @"osBuild": @"wrong"};
        },
        ^(NSMutableDictionary *copy) { [copy[@"callbacks"] removeLastObject]; },
        ^(NSMutableDictionary *copy) {
            copy[@"callbacks"][1][@"selector"] = copy[@"callbacks"][0][@"selector"];
        },
        ^(NSMutableDictionary *copy) { copy[@"callbacks"][0][@"selector"] = @""; },
        ^(NSMutableDictionary *copy) {
            copy[@"callbacks"][0][@"authorization"] = @"unknown";
        },
        ^(NSMutableDictionary *copy) { copy[@"callbacks"][0][@"definition"] = @"wrong"; },
        ^(NSMutableDictionary *copy) { copy[@"callbacks"][0][@"methodAbsent"] = @NO; },
        ^(NSMutableDictionary *copy) { copy[@"callbacks"][0][@"artifacts"] = @[]; },
        ^(NSMutableDictionary *copy) { copy[@"callbacks"][0][@"reason"] = @""; },
        ^(NSMutableDictionary *copy) {
            copy[@"callbacks"][0][@"hopperProcedures"] = @[];
        },
    ];
    for (void (^mutation)(NSMutableDictionary *) in mutations) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:fixture
                                                       options:0 error:nil];
        NSMutableDictionary *copy = [NSJSONSerialization
            JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        mutation(copy);
        XCTAssertGreaterThan([self authorizationErrors:copy].count, 0U);
    }
}

- (void)testBlockInteractionHostOmitsAuthorizedSelectionCallbacks {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, 240.0, 120.0)
        attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"alpha beta"]]];
    NSString *source = IDInteractionSource(
        @"PrivateUIKit/IDBlockTextView+PrivateInteractionCallbacks.m");
    NSArray<NSString *> *abiNames = IDParsedInteractionHostABISelectors();
    for (NSDictionary<NSString *, id> *row
         in [self callbacksAuthorizedAs:@"safeFallback"]) {
        NSString *selector = row[@"selector"];
        XCTAssertFalse([view respondsToSelector:NSSelectorFromString(selector)]);
        XCTAssertFalse(IDSourceMethodExistsInImplementation(
            source, @"IDBlockTextView (PrivateInteractionCallbacks)", selector));
        XCTAssertFalse([abiNames containsObject:selector]);
    }
}

- (void)testBlockInteractionHostRetainsRequiredSelectionCallbacks {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0.0, 0.0, 240.0, 120.0)
        attributedBlocks:@[[[NSAttributedString alloc] initWithString:@"alpha beta"]]];
    NSString *source = IDInteractionSource(
        @"PrivateUIKit/IDBlockTextView+PrivateInteractionCallbacks.m");
    NSArray<NSString *> *abiNames = IDParsedInteractionHostABISelectors();
    for (NSDictionary<NSString *, id> *row
         in [self callbacksAuthorizedAs:@"requiredNativeChrome"]) {
        NSString *selector = row[@"selector"];
        XCTAssertTrue([view respondsToSelector:NSSelectorFromString(selector)]);
        XCTAssertTrue(IDSourceMethodExistsInImplementation(
            source, @"IDBlockTextView (PrivateInteractionCallbacks)", selector));
        XCTAssertTrue([abiNames containsObject:selector]);
    }
    XCTAssertNoThrow([IDPrivateUIKit requireInteractionHost:view
                                                      stage:@"Reduced final host ABI"]);
}

- (void)testBlockInteractionHostABIExactlyMatchesAuthorizationFixture {
    NSMutableSet<NSString *> *expected = [NSMutableSet set];
    NSMutableSet<NSString *> *candidates = [NSMutableSet set];
    for (NSDictionary<NSString *, id> *row in self.authorizationFixture[@"callbacks"]) {
        [candidates addObject:row[@"selector"]];
        if (![row[@"authorization"] isEqual:@"safeFallback"]) {
            [expected addObject:row[@"selector"]];
        }
    }
    NSMutableSet<NSString *> *actual = [NSMutableSet setWithArray:
        IDParsedInteractionHostABISelectors()];
    [actual intersectSet:candidates];
    XCTAssertEqualObjects(actual, expected);

    for (NSString *selectorName in expected) {
        IDMissingInteractionHostMethodProbe *probe =
            [[IDMissingInteractionHostMethodProbe alloc]
                initWithFrame:CGRectMake(0, 0, 240, 120)
                attributedBlocks:@[[[NSAttributedString alloc]
                    initWithString:@"missing ABI"]]];
        probe.missingSelectorName = selectorName;
        XCTAssertThrowsSpecificNamed(
            [IDPrivateUIKit requireInteractionHost:probe stage:@"Missing final ABI"],
            NSException, NSInternalInconsistencyException);
    }
}

- (void)testBlockGestureRecognizerHostCallbackRemainsRequiredOnIOS265 {
    NSString *fixturePath = IDEngineSourceFile(@"Tests/Fixtures/BlockGestureRecognizerHostCallbackAuthorization-iOS26.5.json");
    NSDictionary<NSString *, id> *fixture = [NSJSONSerialization
        JSONObjectWithData:[NSData dataWithContentsOfFile:fixturePath]
                   options:0 error:nil];
    XCTAssertEqualObjects(fixture[@"decision"], @"requiredNativeInteractionHost");

    SEL target = NSSelectorFromString(
        @"_textInputViewForAddingGestureRecognizers");
    IDBlockTextView *blockView = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 240, 120)
        attributedBlocks:@[[[NSAttributedString alloc]
            initWithString:@"gesture host"]]];

    XCTAssertNotEqual(class_getInstanceMethod(IDBlockTextView.class, target), NULL);
    XCTAssertTrue([blockView respondsToSelector:target]);
    XCTAssertEqual([blockView _textInputViewForAddingGestureRecognizers],
                   (UIView *)blockView);
    XCTAssertNotEqual(class_getInstanceMethod(IDTextView.class, target), NULL);

    NSMutableArray<NSString *> *expectedABI = [@[
        @"interactionAssistant",
        @"_textInputViewForAddingGestureRecognizers",
        @"selectionContainerView",
    ] mutableCopy];
    XCTAssertEqualObjects(IDParsedInteractionHostABISelectors(), expectedABI);
    XCTAssertNoThrow([IDPrivateUIKit requireInteractionHost:blockView
                                                      stage:@"Required gesture host"]);
    XCTAssertEqual(blockView.textInputView, (UIView *)blockView.id_blockStack);

    Class traitsClass = NSClassFromString(@"UITextInputTraits");
    XCTAssertFalse([traitsClass instancesRespondToSelector:target]);
    XCTAssertFalse(IDClassLocallyImplementsSelector(
        IDBlockTextView.class, NSSelectorFromString(@"forwardInvocation:")));
    XCTAssertFalse(IDClassLocallyImplementsSelector(
        IDBlockTextView.class, NSSelectorFromString(@"resolveInstanceMethod:")));
}

- (void)testBlockIsEditingUsesSafeInheritedFallbackOnIOS265 {
    SEL target = NSSelectorFromString(@"isEditing");
    Class blockClass = IDBlockTextView.class;
    Class directSuperclass = class_getSuperclass(blockClass);
    IDBlockTextView *blockView = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 240, 120)
        attributedBlocks:@[[[NSAttributedString alloc]
            initWithString:@"inherited editing lookup"]]];

    XCTAssertFalse(IDClassLocallyImplementsSelector(blockClass, target));
    XCTAssertTrue([blockView respondsToSelector:target]);
    XCTAssertEqual(class_getMethodImplementation(blockClass, target),
                   class_getMethodImplementation(directSuperclass, target));
    XCTAssertTrue(IDClassLocallyImplementsSelector(IDTextView.class, target));
    XCTAssertTrue(IDClassLocallyImplementsSelector(
        IDTextLayoutCanvasView.class, target));

    NSArray<NSString *> *compiledABI = IDParsedInteractionHostABISelectors();
    NSMutableArray<NSString *> *expectedABI = [@[
        @"interactionAssistant",
        @"_textInputViewForAddingGestureRecognizers",
        @"selectionContainerView",
    ] mutableCopy];
    XCTAssertEqualObjects(compiledABI, expectedABI);
    for (NSString *selectorName in compiledABI) {
        XCTAssertTrue(IDClassLocallyImplementsSelector(
            blockClass, NSSelectorFromString(selectorName)), @"%@", selectorName);
    }

    // IDBlockTextView already owns generic UITextInputTraits forwarding. Prove
    // that those pre-existing methods do not substitute for this selector.
    XCTAssertNil([blockView forwardingTargetForSelector:target]);
    XCTAssertEqualObjects([blockView methodSignatureForSelector:target],
        [directSuperclass instanceMethodSignatureForSelector:target]);
    XCTAssertFalse(IDClassLocallyImplementsSelector(
        blockClass, NSSelectorFromString(@"forwardInvocation:")));
    XCTAssertFalse(IDClassLocallyImplementsSelector(
        object_getClass(blockClass), NSSelectorFromString(@"resolveInstanceMethod:")));
}

- (void)testBlockVisualSelectionUsesSafeOuterFallbackAndKeepsRichProvider {
    SEL target = NSSelectorFromString(
        @"_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:");
    IDBlockTextView *blockView = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 240, 120)
        attributedBlocks:@[[[NSAttributedString alloc]
            initWithString:@"visual selection ownership"]]];
    Class richClass = object_getClass(blockView.id_richLayoutController);

    XCTAssertFalse(IDClassLocallyImplementsSelector(IDBlockTextView.class, target));
    XCTAssertFalse([blockView respondsToSelector:target]);
    XCTAssertFalse([IDParsedInteractionHostABISelectors()
        containsObject:NSStringFromSelector(target)]);
    XCTAssertTrue(IDClassLocallyImplementsSelector(richClass, target));
    XCTAssertFalse(IDClassLocallyImplementsSelector(
        IDBlockTextView.class, NSSelectorFromString(@"forwardInvocation:")));
    XCTAssertFalse(IDClassLocallyImplementsSelector(
        object_getClass(IDBlockTextView.class),
        NSSelectorFromString(@"resolveInstanceMethod:")));
}

@end
