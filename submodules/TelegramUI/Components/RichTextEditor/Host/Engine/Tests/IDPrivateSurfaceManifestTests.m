#import <XCTest/XCTest.h>

#import "IDUIKitCapabilityResolver.h"
#import "IDUIKitRuntimeContract.h"
#import "IDEngineSourceLayout.h"

@interface IDPrivateSurfaceManifestTests : XCTestCase
@end

@implementation IDPrivateSurfaceManifestTests

- (NSString *)sourceRoot {
    return IDEngineSourceRoot();
}

- (NSURL *)URLForResource:(NSString *)name
                   bundle:(NSBundle *)preferredBundle {
    NSMutableArray<NSBundle *> *bundles = [NSMutableArray array];
    if (preferredBundle != nil) [bundles addObject:preferredBundle];
    if (![bundles containsObject:NSBundle.mainBundle]) {
        [bundles addObject:NSBundle.mainBundle];
    }
    for (NSBundle *bundle in NSBundle.allBundles) {
        if (![bundles containsObject:bundle]) [bundles addObject:bundle];
    }
    for (NSBundle *bundle in bundles) {
        NSURL *URL = [bundle URLForResource:name
                              withExtension:@"json"];
        if (URL != nil) return URL;
    }
    return nil;
}

- (IDUIKitRuntimeManifest *)manifestNamed:(NSString *)name
                                   bundle:(NSBundle *)bundle {
    NSURL *URL = [self URLForResource:name bundle:bundle];
    XCTAssertNotNil(URL, @"Missing checked-in manifest resource %@", name);
    if (URL == nil) return nil;
    NSData *data = [NSData dataWithContentsOfURL:URL];
    NSError *error = nil;
    IDUIKitRuntimeManifest *manifest =
        [IDUIKitRuntimeManifest manifestWithData:data error:&error];
    XCTAssertNotNil(manifest, @"Invalid %@: %@", name, error);
    XCTAssertNil(error);
    return manifest;
}

- (NSArray<IDUIKitRuntimeMemberContract *> *)membersInManifest:
    (IDUIKitRuntimeManifest *)manifest {
    NSMutableArray<IDUIKitRuntimeMemberContract *> *members =
        [NSMutableArray array];
    for (IDUIKitRuntimeCapabilityContract *capability
             in manifest.capabilities.allValues) {
        [members addObjectsFromArray:capability.members];
    }
    for (IDUIKitRuntimeCapabilityContract *capability
             in manifest.referenceOnly.allValues) {
        [members addObjectsFromArray:capability.members];
    }
    return members.copy;
}

- (BOOL)sourceBody:(NSString *)body
    containsOccurrenceSymbol:(NSString *)symbol {
    NSString *escaped =
        [NSRegularExpression escapedPatternForString:symbol];
    NSRegularExpression *literal =
        [NSRegularExpression regularExpressionWithPattern:
            [NSString stringWithFormat:
                @"(?<![A-Za-z0-9_])%@(?![A-Za-z0-9_])",
                escaped]
                                                options:0
                                                  error:nil];
    if ([literal firstMatchInString:body
                            options:0
                              range:NSMakeRange(0, body.length)] != nil) {
        return YES;
    }
    // A private UIKit name is spelled in the source only through its encoded table entry
    // (`TGPN_<name>()`, every ':' as '_'), or as the neutral `tgpn_` method a callback is compiled
    // under (`TGPrivateRuntimeNames.h`, `TGPrivateMethodAliases.h`). Either is a live occurrence.
    NSString *mangled = [symbol stringByReplacingOccurrencesOfString:@":" withString:@"_"];
    if ([body containsString:[@"TGPN_" stringByAppendingString:mangled]]) return YES;
    NSString *firstKeyword = [symbol componentsSeparatedByString:@":"].firstObject;
    if ([body containsString:[@"tgpn_" stringByAppendingString:firstKeyword]]) return YES;
    if (![symbol containsString:@":"]) return NO;

    NSMutableArray<NSString *> *keywords =
        [[symbol componentsSeparatedByString:@":"] mutableCopy];
    if (keywords.lastObject.length == 0) {
        [keywords removeLastObject];
    }
    NSMutableString *pattern = [NSMutableString string];
    for (NSUInteger index = 0; index < keywords.count; index += 1) {
        if (index != 0) {
            // A method signature cannot cross a body delimiter before its
            // next selector keyword. This keeps the match occurrence-local.
            [pattern appendString:@"[^\\{;]{0,1200}?"];
        }
        [pattern appendFormat:@"\\b%@\\s*:",
            [NSRegularExpression
                escapedPatternForString:keywords[index]]];
    }
    NSRegularExpression *selector =
        [NSRegularExpression regularExpressionWithPattern:pattern
                                                  options:0
                                                    error:nil];
    return [selector firstMatchInString:body
                                options:0
                                  range:NSMakeRange(0, body.length)] != nil;
}

- (void)testProductionAndTestOnlyManifestsAreStrictAndDisjoint {
    IDUIKitRuntimeManifest *production =
        [self manifestNamed:@"UIKitBehaviorContracts-iOS26.5"
                     bundle:NSBundle.mainBundle];
    IDUIKitRuntimeManifest *testOnly =
        [self manifestNamed:@"UIKitBehaviorTestOnlyContracts-iOS26.5"
                     bundle:[NSBundle bundleForClass:self.class]];
    XCTAssertEqualObjects(production.osVersion, @"26.5");
    XCTAssertEqualObjects(production.osBuild, @"23F73");
    XCTAssertEqualObjects(testOnly.osVersion, @"26.5");
    XCTAssertEqualObjects(testOnly.osBuild, @"23F73");

    NSMutableSet<NSString *> *productionIdentifiers =
        [NSMutableSet set];
    for (IDUIKitRuntimeMemberContract *member
             in [self membersInManifest:production]) {
        XCTAssertFalse([member.direction isEqualToString:@"testOnly"]);
        XCTAssertFalse([productionIdentifiers containsObject:member.identifier]);
        [productionIdentifiers addObject:member.identifier];
    }
    NSMutableSet<NSString *> *testIdentifiers = [NSMutableSet set];
    for (IDUIKitRuntimeMemberContract *member
             in [self membersInManifest:testOnly]) {
        XCTAssertEqualObjects(member.direction, @"testOnly");
        XCTAssertFalse([testIdentifiers containsObject:member.identifier]);
        XCTAssertFalse([productionIdentifiers containsObject:member.identifier],
                       @"Test-only identifier escaped into production: %@",
                       member.identifier);
        [testIdentifiers addObject:member.identifier];
    }
}

- (void)testInternalLayoutControllerDiagnosticIsStockOnly {
    IDUIKitRuntimeManifest *testOnly =
        [self manifestNamed:@"UIKitBehaviorTestOnlyContracts-iOS26.5"
                     bundle:[NSBundle bundleForClass:self.class]];
    NSMutableArray<IDUIKitRuntimeMemberContract *> *matches =
        [NSMutableArray array];
    for (IDUIKitRuntimeMemberContract *member
             in [self membersInManifest:testOnly]) {
        if ([member.identifier isEqualToString:
                @"testOnly.internalLayoutController"]) {
            [matches addObject:member];
        }
    }

    XCTAssertEqual(matches.count, 1U);
    IDUIKitRuntimeMemberContract *member = matches.firstObject;
    XCTAssertEqualObjects(member.className, @"UITextView");
    XCTAssertEqualObjects(member.name, @"_internalTextLayoutController");
    XCTAssertEqualObjects(member.direction, @"testOnly");
    XCTAssertEqualObjects(member.source,
                          @"PrivateUIKit/IDPrivateUIKit.m|_internalTextLayoutController");
    XCTAssertEqualObjects(member.fallback,
                          @"Skip stock-oracle internal-layout diagnostics.");
    XCTAssertEqualObjects(member.teardown,
                          @"Do not retain the observed stock controller.");
}

- (void)testProductionManifestMatchesPinnedRuntimeABI {
    IDUIKitRuntimeManifest *production =
        [self manifestNamed:@"UIKitBehaviorContracts-iOS26.5"
                     bundle:NSBundle.mainBundle];
    IDUIKitCapabilityResolver *resolver =
        [IDUIKitCapabilityResolver systemResolver];
    for (NSString *identifier
             in [production.capabilities.allKeys
                 sortedArrayUsingSelector:@selector(compare:)]) {
        IDUIKitContractResult *result = [resolver evaluateContract:
            production.capabilities[identifier]];
        XCTAssertTrue(result.accepted,
                      @"%@ rejected on 26.5/23F73: %@",
                      identifier,
                      result.mismatches);
    }
}

- (void)testFinalManifestInventoryKeepsConcreteLayoutOutOfMinimalCapabilities {
    IDUIKitRuntimeManifest *production =
        [self manifestNamed:@"UIKitBehaviorContracts-iOS26.5"
                     bundle:NSBundle.mainBundle];
    IDUIKitRuntimeManifest *testOnly =
        [self manifestNamed:@"UIKitBehaviorTestOnlyContracts-iOS26.5"
                     bundle:[NSBundle bundleForClass:self.class]];
    NSDictionary<NSString *, NSNumber *> *expectedProductionCounts = @{
        @"autoscrollEntry": @3,
        @"checking": @2,
        @"dictation": @1,
        @"floatingCursor": @3,
        @"incomingCallbacks": @47,
        @"inputController": @42,
        @"interaction": @14,
        @"paste": @5,
        @"prediction": @1,
        @"typingAttributes": @9,
    };
    NSUInteger mandatoryCount = 0;
    NSUInteger optionalCount = 0;
    for (NSString *identifier in expectedProductionCounts) {
        IDUIKitRuntimeCapabilityContract *capability =
            production.capabilities[identifier];
        XCTAssertEqual(capability.members.count,
                       expectedProductionCounts[identifier].unsignedIntegerValue,
                       @"%@", identifier);
        if (capability.isMandatory) {
            mandatoryCount += capability.members.count;
        } else {
            optionalCount += capability.members.count;
        }
        for (IDUIKitRuntimeMemberContract *member in capability.members) {
            XCTAssertFalse([production.forbiddenSymbols
                containsObject:member.className], @"%@", member.identifier);
            XCTAssertFalse([production.forbiddenSymbols
                containsObject:member.name], @"%@", member.identifier);
            XCTAssertFalse([member.source containsString:@"object_getIvar"]);
            XCTAssertFalse([member.source containsString:@"method_setImplementation"]);
            XCTAssertFalse([member.source containsString:@"UIKeyboardImpl"]);
            XCTAssertFalse([member.source
                containsString:@"_internalTextLayoutController"]);
        }
    }
    XCTAssertEqual(mandatoryCount, 98U);
    XCTAssertEqual(optionalCount, 29U);

    IDUIKitRuntimeCapabilityContract *autoscrollEntry =
        production.capabilities[@"autoscrollEntry"];
    NSUInteger autoscrollProtocolCount = 0;
    NSUInteger autoscrollIncomingCallbackCount = 0;
    NSUInteger autoscrollOutgoingCount = 0;
    for (IDUIKitRuntimeMemberContract *member in autoscrollEntry.members) {
        autoscrollProtocolCount +=
            member.kind == IDUIKitPrivateMemberKindProtocol ? 1U : 0U;
        autoscrollIncomingCallbackCount +=
            member.kind == IDUIKitPrivateMemberKindIncomingCallback ? 1U : 0U;
        autoscrollOutgoingCount +=
            [member.direction isEqualToString:@"outgoing"] ? 1U : 0U;
        XCTAssertNotEqualObjects(member.className, @"UIAutoscroll");
    }
    XCTAssertEqual(autoscrollProtocolCount, 1U);
    XCTAssertEqual(autoscrollIncomingCallbackCount, 2U);
    XCTAssertEqual(autoscrollOutgoingCount, 0U);

    NSUInteger assistantAutoscrollClosureCount = 0;
    for (IDUIKitRuntimeMemberContract *member
             in production.capabilities[@"interaction"].members) {
        assistantAutoscrollClosureCount +=
            [member.name isEqualToString:@"autoscrollWillNotStart"] ? 1U : 0U;
    }
    XCTAssertEqual(assistantAutoscrollClosureCount, 1U);

    NSUInteger referenceCount = 0;
    for (IDUIKitRuntimeCapabilityContract *capability
             in production.referenceOnly.allValues) {
        referenceCount += capability.members.count;
    }
    XCTAssertEqual(referenceCount, 53U);
    XCTAssertNotNil(production.referenceOnly[@"legacyAutoscroll"]);
    XCTAssertNotNil(production.referenceOnly[@"legacyLayout"]);
    XCTAssertNotNil(production.referenceOnly[@"legacyCanvas"]);
    IDUIKitRuntimeCapabilityContract *legacyAutoscroll =
        production.referenceOnly[@"legacyAutoscroll"];
    XCTAssertEqual(legacyAutoscroll.members.count, 3U);
    for (IDUIKitRuntimeMemberContract *member in legacyAutoscroll.members) {
        XCTAssertEqualObjects(member.className, @"UIAutoscroll");
        XCTAssertEqualObjects(member.direction, @"reference");
    }

    NSUInteger testOnlyCount = 0;
    NSMutableSet<NSString *> *testOnlySources = [NSMutableSet set];
    for (IDUIKitRuntimeCapabilityContract *capability
             in testOnly.capabilities.allValues) {
        testOnlyCount += capability.members.count;
        for (IDUIKitRuntimeMemberContract *member in capability.members) {
            [testOnlySources addObject:member.source];
        }
    }
    XCTAssertEqual(testOnlyCount, 24U);
    XCTAssertTrue([testOnlySources containsObject:
        @"PrivateUIKit/IDPrivateUIKit.m|object_getIvar"]);
    XCTAssertTrue([testOnlySources containsObject:
        @"PrivateUIKit/IDPrivateUIKit.m|UIKeyboardImpl"]);
    XCTAssertTrue([testOnlySources containsObject:
        @"PrivateUIKit/IDPrivateUIKit+RichTextLayout.m|method_setImplementation"]);
    XCTAssertTrue([testOnlySources containsObject:
        @"PrivateUIKit/IDPrivateUIKit.m|timerFired:"]);
}

- (void)testEveryManifestMemberHasLiveSourceAndEvidence {
    NSArray<IDUIKitRuntimeManifest *> *manifests = @[
        [self manifestNamed:@"UIKitBehaviorContracts-iOS26.5"
                     bundle:NSBundle.mainBundle],
        [self manifestNamed:@"UIKitBehaviorTestOnlyContracts-iOS26.5"
                     bundle:[NSBundle bundleForClass:self.class]],
    ];
    NSString *root = self.sourceRoot;
    NSMutableSet<NSString *> *sources = [NSMutableSet set];
    for (IDUIKitRuntimeManifest *manifest in manifests) {
        for (IDUIKitRuntimeMemberContract *member
                 in [self membersInManifest:manifest]) {
            XCTAssertFalse([sources containsObject:member.source],
                           @"Source occurrence has multiple owners: %@",
                           member.source);
            [sources addObject:member.source];
            NSArray<NSString *> *parts =
                [member.source componentsSeparatedByString:@"|"];
            XCTAssertEqual(parts.count, 2U);
            if (parts.count != 2) continue;
            NSString *path = IDEngineSourceFile(parts[0]);
            NSString *body =
                [NSString stringWithContentsOfFile:path
                                          encoding:NSUTF8StringEncoding
                                             error:nil];
            XCTAssertNotNil(body, @"Missing source for %@", member.identifier);
            if (body == nil) continue;
            XCTAssertTrue(
                [self sourceBody:body
                    containsOccurrenceSymbol:parts[1]],
                @"Stale source occurrence %@", member.source);

            NSArray<NSString *> *evidenceParts =
                [member.evidence componentsSeparatedByString:@"#"];
            NSString *evidencePath =
                IDEngineSourceFile(evidenceParts.firstObject);
            XCTAssertTrue([[NSFileManager defaultManager]
                fileExistsAtPath:evidencePath],
                @"Missing evidence for %@: %@",
                member.identifier,
                member.evidence);
        }
    }
}

- (void)testTextViewLayerHasNoRawPrivateRuntimeAccess {
    NSString *directory =
        IDEngineSourceFile(@"TextView");
    NSDirectoryEnumerator *enumerator =
        [[NSFileManager defaultManager] enumeratorAtPath:directory];
    NSArray<NSString *> *tokens = @[
        @"NSClassFromString",
        @"NSSelectorFromString",
        @"NSProtocolFromString",
        @"objc_msgSend",
        @"class_get",
        @"class_add",
        @"object_getClass",
        @"object_getIvar",
    ];
    for (NSString *file in enumerator) {
        if (![file.pathExtension isEqualToString:@"m"] &&
            ![file.pathExtension isEqualToString:@"h"]) {
            continue;
        }
        NSString *body = [NSString stringWithContentsOfFile:
            [directory stringByAppendingPathComponent:file]
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
        XCTAssertNotNil(body);
        for (NSString *token in tokens) {
            XCTAssertFalse([body containsString:token],
                           @"%@ escaped into TextView/%@", token, file);
        }
    }
}

- (void)testBehaviorKernelContainsNoReferenceOnlyForbiddenSymbol {
    IDUIKitRuntimeManifest *production =
        [self manifestNamed:@"UIKitBehaviorContracts-iOS26.5"
                     bundle:NSBundle.mainBundle];
    NSString *directory = IDEngineSourceFile(@"PrivateUIKit/BehaviorKernel");
    NSDirectoryEnumerator *enumerator =
        [[NSFileManager defaultManager] enumeratorAtPath:directory];
    for (NSString *file in enumerator) {
        if (![file.pathExtension isEqualToString:@"m"] &&
            ![file.pathExtension isEqualToString:@"h"]) {
            continue;
        }
        NSString *body = [NSString stringWithContentsOfFile:
            [directory stringByAppendingPathComponent:file]
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
        XCTAssertNotNil(body);
        for (NSString *symbol in production.forbiddenSymbols) {
            XCTAssertFalse([body containsString:symbol],
                           @"Reference-only symbol %@ escaped into %@",
                           symbol,
                           file);
        }
    }
}

- (void)testProductionClassLookupAllowlistIsExplicitAndNarrow {
    NSString *root = self.sourceRoot;
    NSSet<NSString *> *allowlist = [NSSet setWithArray:@[
        @"PrivateUIKit/BehaviorKernel/IDUIKitCapabilityResolver.m",
        @"PrivateUIKit/IDPrivateUIKit.m",
        @"PrivateUIKit/IDPrivateUIKit+RichTextLayout.m",
        @"PrivateUIKit/IDBlockTextView+PrivateCallbacks.m",
    ]];
    NSString *privateRoot =
        IDEngineSourceFile(@"PrivateUIKit");
    NSDirectoryEnumerator *enumerator =
        [[NSFileManager defaultManager] enumeratorAtPath:privateRoot];
    for (NSString *file in enumerator) {
        if (![file.pathExtension isEqualToString:@"m"]) continue;
        NSString *relative =
            [@"PrivateUIKit" stringByAppendingPathComponent:file];
        NSString *body = [NSString stringWithContentsOfFile:
            [privateRoot stringByAppendingPathComponent:file]
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
        if (![body containsString:@"NSClassFromString"]) continue;
        XCTAssertTrue([allowlist containsObject:relative],
                      @"Unapproved production class lookup in %@", relative);
    }
}

- (void)testEveryLiteralAdapterOccurrenceHasExactlyOneManifestOwner {
    IDUIKitRuntimeManifest *production =
        [self manifestNamed:@"UIKitBehaviorContracts-iOS26.5"
                     bundle:NSBundle.mainBundle];
    IDUIKitRuntimeManifest *testOnly =
        [self manifestNamed:@"UIKitBehaviorTestOnlyContracts-iOS26.5"
                     bundle:[NSBundle bundleForClass:self.class]];
    NSMutableDictionary<NSString *, NSNumber *> *ownerCounts =
        [NSMutableDictionary dictionary];
    for (IDUIKitRuntimeManifest *manifest in @[production, testOnly]) {
        for (IDUIKitRuntimeMemberContract *member
                 in [self membersInManifest:manifest]) {
            ownerCounts[member.source] =
                @(ownerCounts[member.source].unsignedIntegerValue + 1);
        }
    }

    NSArray<NSString *> *relativePaths = @[
        @"PrivateUIKit/IDBlockTextView+PrivateCallbacks.m",
        @"PrivateUIKit/IDPrivateUIKit+RichTextLayout.m",
        @"PrivateUIKit/IDPrivateUIKit+TextLayoutCanvas.m",
    ];
    NSArray<NSRegularExpression *> *patterns = @[
        [NSRegularExpression regularExpressionWithPattern:
            @"NSClassFromString\\(@\"([^\"]+)\"\\)"
                                                  options:0 error:nil],
        [NSRegularExpression regularExpressionWithPattern:
            @"NSSelectorFromString\\(@\"([^\"]+)\"\\)"
                                                  options:0 error:nil],
        [NSRegularExpression regularExpressionWithPattern:
            @"class_getInstanceVariable\\([^,]+,\\s*\"([^\"]+)\"\\)"
                                                  options:NSRegularExpressionDotMatchesLineSeparators
                                                    error:nil],
    ];
    for (NSString *relativePath in relativePaths) {
        NSString *body = [NSString stringWithContentsOfFile:
            IDEngineSourceFile(relativePath)
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
        XCTAssertNotNil(body);
        NSMutableSet<NSString *> *records = [NSMutableSet set];
        for (NSRegularExpression *pattern in patterns) {
            for (NSTextCheckingResult *match
                     in [pattern matchesInString:body
                                         options:0
                                           range:NSMakeRange(0, body.length)]) {
                NSString *symbol =
                    [body substringWithRange:[match rangeAtIndex:1]];
                [records addObject:[NSString stringWithFormat:
                    @"%@|%@", relativePath, symbol]];
            }
        }
        for (NSString *record in records) {
            XCTAssertEqual(ownerCounts[record].unsignedIntegerValue, 1U,
                           @"Unclassified or multiply-owned occurrence: %@",
                           record);
        }
    }
}

@end
