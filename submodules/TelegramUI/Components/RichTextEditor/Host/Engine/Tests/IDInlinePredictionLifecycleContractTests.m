@import XCTest;

#import <objc/runtime.h>

#import "IDInlinePredictionLifecycleTestSupport.h"
#import "IDTextInputBatchTestSupport.h"
#import "IDBlockDocument.h"
#import "IDBlockLayout.h"
#import "IDBlockStackCanvasView.h"
#import "IDBlockTextTestSupport.h"
#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDCanonicalTextProjection.h"
#import "IDInlineTextFormatting.h"
#import "IDRichTextAnchor.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDEngineSourceLayout.h"

@interface IDCanonicalTextStorageAdapter (IDInlinePredictionAtomicTesting)
- (void)coordinateEditing:(void (NS_NOESCAPE ^)(void))block;
@end

static NSDictionary<NSString *, id> *IDValidInlinePredictionStatus(void) {
    return @{
        @"schema": @1,
        @"scenario": @"inline-prediction-interior",
        @"canonical": @"I look forward",
        @"blocks": @[@"I look forward", @"Second block remains."],
        @"selection": @{@"location": @14, @"length": @0},
        @"affinity": @"forward",
        @"markedRange": @{@"location": @(NSNotFound), @"length": @0},
        @"structuralNewlineLocations": @[@14],
        @"checkingRanges": @[],
        @"predictionDescriptor": @{
            @"present": @YES,
            @"displayText": @" to seeing you",
            @"accessibilityIdentity": @"inline-prediction",
            @"range": @{@"location": @14, @"length": @0},
            @"renderingAttributeKeys": @[@"NSTextInlinePrediction"],
        },
        @"temporaryRenderingDescriptors": @[
            @{
                @"range": @{@"location": @14, @"length": @0},
                @"attributeKeys": @[@"NSTextInlinePrediction"],
                @"valueDescriptions": @[@"visible"],
            },
        ],
        @"mutationTrace": @[],
        @"eventTrace": @[],
        @"keyboardState": @{
            @"visible": @YES,
            @"locale": @"en_US",
            @"inlinePredictionEnabled": @YES,
        },
        @"predictionGeometry": @{
            @"x": @10, @"y": @20, @"width": @80, @"height": @22,
        },
        @"coordinateSpaceIdentity": @"document-interaction-container",
        @"documentRevision": @0,
        @"textEpoch": @0,
        @"selectionEpoch": @0,
        @"checkingEpoch": @0,
        @"firstResponder": @YES,
    };
}

static NSString *IDInlinePredictionJSONString(
    NSDictionary<NSString *, id> *dictionary) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary
                                                   options:NSJSONWritingSortedKeys
                                                     error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@interface IDInlinePredictionLifecycleContractTests : XCTestCase
@end

@implementation IDInlinePredictionLifecycleContractTests

- (void)testAttemptAPISeparatesReadinessAndRetainsPhaseImageData {
    XCTAssertNotNil(NSClassFromString(@"IDInlinePredictionLifecycleAttempt"));
    XCTAssertTrue(class_getProperty(
        NSClassFromString(@"IDInlinePredictionLifecycleAttempt"),
        "offerReady") != NULL);
    XCTAssertTrue(class_getProperty(
        NSClassFromString(@"IDInlinePredictionLifecycleAttempt"),
        "result") != NULL);
    XCTAssertTrue(class_getProperty(
        IDInlinePredictionPhaseSnapshot.class, "screenshotPNGData") != NULL);

    NSString *sourcePath = IDEngineSourceFile(@"UITests/IDInlinePredictionLifecycleTestSupport.m");
    NSString *source = [NSString stringWithContentsOfFile:sourcePath
        encoding:NSUTF8StringEncoding error:nil];
    XCTAssertNotNil(source);
    XCTAssertTrue([source containsString:
        @"IDAttemptInlinePredictionLifecycle("]);
    NSRange missingStart = [source rangeOfString:@"if (!offerReady) {"];
    NSRange semanticStart = [source rangeOfString:@"} else if ("
        options:0 range:NSMakeRange(missingStart.location,
            source.length - missingStart.location)];
    NSString *missingPath = [source substringWithRange:NSMakeRange(
        missingStart.location,
        NSMaxRange(semanticStart) - missingStart.location)];
    XCTAssertTrue([missingPath containsString:@"return attempt;"]);
    XCTAssertFalse([missingPath containsString:
        @"Expected native inline prediction was absent"]);
    for (NSString *semanticFailure in @[
            @"Invalid inline-prediction stock fixture",
            @"Native offer does not match frozen iOS 26.5 contract",
            @"UIKit did not fully accept the marked inline completion",
            @"UIKit did not remove the marked inline completion",
            @"Prediction geometry tap did not settle marked completion",
        ]) {
        XCTAssertTrue([source containsString:semanticFailure], @"%@",
                      semanticFailure);
    }
}

- (void)testSnapshotAttemptTreatsKeyboardTypingAvailabilityAsReadiness {
    NSString *root = IDEngineSourceRoot();
    NSString *inlineSource = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"UITests/IDInlinePredictionLifecycleTestSupport.m")
        encoding:NSUTF8StringEncoding error:nil];
    NSString *hidHeader = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"UITests/IDHIDEventTestSupport.h")
        encoding:NSUTF8StringEncoding error:nil];
    NSString *hidSource = [NSString stringWithContentsOfFile:
        IDEngineSourceFile(@"UITests/IDHIDEventTestSupport.m")
        encoding:NSUTF8StringEncoding error:nil];
    XCTAssertNotNil(inlineSource);
    XCTAssertNotNil(hidHeader);
    XCTAssertNotNil(hidSource);
    XCTAssertTrue([hidHeader containsString:
        @"IDHIDTryTypeSoftwareKeyboardText("]);
    XCTAssertTrue([hidSource containsString:
        @"IDHIDTryTypeSoftwareKeyboardText("]);
    NSRange typing = [inlineSource rangeOfString:
        @"if (!IDHIDTryTypeSoftwareKeyboardText("];
    NSRange offer = [inlineSource rangeOfString:
        @"BOOL offerReady = IDInlinePredictionWaitForOffer"];
    XCTAssertNotEqual(typing.location, NSNotFound);
    XCTAssertNotEqual(offer.location, NSNotFound);
    if (typing.location == NSNotFound || offer.location == NSNotFound) return;
    XCTAssertLessThan(typing.location, offer.location);
    NSString *readinessPath = [inlineSource substringWithRange:NSMakeRange(
        typing.location, offer.location - typing.location)];
    XCTAssertTrue([readinessPath containsString:@"attempt.offerReady = NO"]);
    XCTAssertTrue([readinessPath containsString:@"return attempt"]);
}

- (void)testCheckpointPackageIsAtomicCompleteAndHashManifested {
    NSData *catalogData = [NSJSONSerialization dataWithJSONObject:@{
        @"schema": @1,
        @"runtime": @{ @"osVersion": @"26.5", @"osBuild": @"23F73" },
        @"udid": @"FA6F7462-AA97-42FE-9E57-8DA0593CE756",
        @"subsystem": @"inline-prediction",
        @"rows": @[@"interior-accept"],
        @"groups": @[@{
            @"id": @"interior", @"language": @"en-US",
            @"rows": @[@"interior-accept"], @"stateSensitive": @YES,
            @"resetPolicy": @"erase-reset-learning-provision",
        }],
    } options:0 error:nil];
    IDTextInputGroup *group = IDLoadTextInputGroupFromData(
        catalogData,
        @"inline-prediction--snapshot-row-v1--interior-accept", nil);
    IDTextInputBatchObservation *observation =
        group.batches.firstObject.observations.firstObject;
    XCTAssertEqualObjects(observation.batchIdentifier,
        @"inline-prediction--r1--stock-custom--interior-accept");

    IDInlinePredictionPhaseSnapshot *phase =
        [IDInlinePredictionPhaseSnapshot new];
    [phase setValue:@"baseline" forKey:@"phase"];
    [phase setValue:IDParseInlinePredictionStatus(
        IDInlinePredictionJSONString(IDValidInlinePredictionStatus()), nil)
        forKey:@"status"];
    [phase setValue:@"inline-prediction-baseline"
             forKey:@"screenshotName"];
    [phase setValue:[@"png" dataUsingEncoding:NSUTF8StringEncoding]
             forKey:@"screenshotPNGData"];
    IDInlinePredictionRunResult *result = [IDInlinePredictionRunResult new];
    [result setValue:[IDInlinePredictionMatrix() firstObject] forKey:@"row"];
    [result setValue:@[phase] forKey:@"phases"];

    NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory()
        stringByAppendingPathComponent:NSUUID.UUID.UUIDString]
        isDirectory:YES];
    XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtURL:root
        withIntermediateDirectories:YES attributes:nil error:nil]);
    [self addTeardownBlock:^{
        [NSFileManager.defaultManager removeItemAtURL:root error:nil];
    }];
    NSError *error = nil;
    XCTAssertTrue(IDWriteInlinePredictionObservationCheckpoint(
        root, result, observation, 2, (XCUIApplication *)[NSObject new],
        &error), @"%@", error);
    NSArray<NSURL *> *packages = [NSFileManager.defaultManager
        contentsOfDirectoryAtURL:root includingPropertiesForKeys:nil
        options:0 error:nil];
    XCTAssertEqual(packages.count, 1U);
    NSURL *package = packages.firstObject;
    XCTAssertEqualObjects(package.lastPathComponent,
                          @"observation-001.checkpoint");
    NSDictionary *metadata = [NSJSONSerialization JSONObjectWithData:
        [NSData dataWithContentsOfURL:[package URLByAppendingPathComponent:
            @"metadata.json"]] options:0 error:nil];
    XCTAssertEqualObjects(metadata[@"batchId"],
        observation.batchIdentifier);
    XCTAssertEqualObjects(metadata[@"successfulAttempt"], @2);
    XCTAssertEqualObjects(metadata[@"host"], @"stock");
    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:
        [NSData dataWithContentsOfURL:[package URLByAppendingPathComponent:
            @"manifest.json"]] options:0 error:nil];
    NSArray *manifestFiles = manifest[@"files"];
    XCTAssertEqual(manifestFiles.count, 4U);
    NSSet *paths = [NSSet setWithArray:[manifestFiles valueForKey:@"path"]];
    NSSet *expectedPaths = [NSSet setWithArray:@[
        @"attachments/hierarchy.txt",
        @"attachments/inline-prediction-baseline-status.json",
        @"attachments/inline-prediction-baseline.png",
        @"metadata.json",
    ]];
    XCTAssertEqualObjects(paths, expectedPaths);
    NSArray *allRootEntries = [NSFileManager.defaultManager
        contentsOfDirectoryAtPath:root.path error:nil];
    NSArray *stagingEntries = [allRootEntries
        filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:
            @"SELF BEGINSWITH '.observation-001.checkpoint.partial-'"]];
    XCTAssertEqual(stagingEntries.count, 0U);
    error = nil;
    XCTAssertFalse(IDWriteInlinePredictionObservationCheckpoint(
        root, result, observation, 2, (XCUIApplication *)[NSObject new],
        &error));
    XCTAssertNotNil(error);
}

- (void)testPredictionAcceptKeepsTraitsAndRejectLeavesNoGhostTraits {
    IDBlockTextView *accepted = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
        attributedBlocks:@[
            [[NSAttributedString alloc] initWithString:@"A"],
        ]];
    UITextPosition *acceptedEnd = accepted.endOfDocument;
    accepted.selectedTextRange = [accepted
        textRangeFromPosition:acceptedEnd toPosition:acceptedEnd];
    [accepted toggleInlineTextTrait:IDInlineTextTraitItalic];
    [accepted setMarkedText:@" to" selectedRange:NSMakeRange(3, 0)];
    [accepted unmarkText];
    XCTAssertEqualObjects(accepted.text, @"A to");
    for (NSUInteger index = 1; index < 4; index++) {
        XCTAssertTrue([[accepted.attributedBlocks[0]
            attribute:IDInlineTextItalicAttributeName
              atIndex:index
       effectiveRange:NULL] boolValue]);
    }

    IDBlockTextView *rejected = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
        attributedBlocks:@[
            [[NSAttributedString alloc] initWithString:@"A"],
        ]];
    UITextPosition *rejectedEnd = rejected.endOfDocument;
    rejected.selectedTextRange = [rejected
        textRangeFromPosition:rejectedEnd toPosition:rejectedEnd];
    [rejected toggleInlineTextTrait:IDInlineTextTraitUnderline];
    [rejected setMarkedText:@" ghost" selectedRange:NSMakeRange(6, 0)];
    [rejected replaceRange:rejected.markedTextRange withText:@""];
    [rejected unmarkText];
    XCTAssertEqualObjects(rejected.text, @"A");
    XCTAssertNil([rejected.attributedBlocks[0]
        attribute:IDInlineTextUnderlineAttributeName
          atIndex:0
   effectiveRange:NULL]);
}

- (void)testMatrixContainsNineUniqueLocationMajorRows {
    NSArray<IDInlinePredictionRow *> *rows = IDInlinePredictionMatrix();
    XCTAssertEqual(rows.count, 9U);
    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
    for (NSUInteger index = 0; index < rows.count; index += 1) {
        XCTAssertEqual(rows[index].location,
                       (IDInlinePredictionLocation)(index / 3));
        XCTAssertEqual(rows[index].decision,
                       (IDInlinePredictionDecision)(index % 3));
        XCTAssertGreaterThan(rows[index].identifier.length, 0U);
        [identifiers addObject:rows[index].identifier];
    }
    XCTAssertEqual(identifiers.count, 9U);
}

- (void)testParserAcceptsCompleteVersionOnePayload {
    NSError *error = nil;
    IDInlinePredictionStatus *status = IDParseInlinePredictionStatus(
        IDInlinePredictionJSONString(IDValidInlinePredictionStatus()), &error);
    XCTAssertNotNil(status);
    XCTAssertNil(error);
    XCTAssertEqualObjects(status.canonical, @"I look forward");
    XCTAssertEqual(status.selection.location, 14U);
    XCTAssertEqual(status.temporaryRenderingDescriptors.count, 1U);
    XCTAssertTrue([status.predictionDescriptor[@"present"] boolValue]);
}

- (void)testParserRejectsMissingAndWrongSchema {
    for (id schema in @[NSNull.null, @2, @YES, @1.5]) {
        NSMutableDictionary *payload =
            [IDValidInlinePredictionStatus() mutableCopy];
        if (schema == NSNull.null) [payload removeObjectForKey:@"schema"];
        else payload[@"schema"] = schema;
        NSError *error = nil;
        XCTAssertNil(IDParseInlinePredictionStatus(
            IDInlinePredictionJSONString(payload), &error), @"%@", schema);
        XCTAssertEqualObjects(error.domain,
                              IDInlinePredictionStatusErrorDomain);
    }
}

- (void)testParserRejectsMalformedPredictionDescriptorSchema {
    for (NSDictionary *descriptor in @[
        @{},
        @{@"present": @YES},
        @{
            @"present": @1,
            @"displayText": @" to seeing you",
            @"accessibilityIdentity": @"inline-prediction",
            @"range": @{@"location": @14, @"length": @0},
            @"renderingAttributeKeys": @[@"NSTextInlinePrediction"],
        },
        @{
            @"present": @YES,
            @"displayText": @1,
            @"accessibilityIdentity": @"inline-prediction",
            @"range": @{@"location": @14, @"length": @0},
            @"renderingAttributeKeys": @[@"NSTextInlinePrediction"],
        },
        @{
            @"present": @YES,
            @"displayText": @" to seeing you",
            @"accessibilityIdentity": @"inline-prediction",
            @"range": @{@"location": @14, @"length": @0},
            @"renderingAttributeKeys": @[@"NSTextInlinePrediction"],
            @"unexpected": @1,
        },
    ]) {
        NSMutableDictionary *payload =
            [IDValidInlinePredictionStatus() mutableCopy];
        payload[@"predictionDescriptor"] = descriptor;
        NSError *error = nil;
        XCTAssertNil(IDParseInlinePredictionStatus(
            IDInlinePredictionJSONString(payload), &error), @"%@", descriptor);
        XCTAssertEqualObjects(error.domain,
                              IDInlinePredictionStatusErrorDomain);
    }
}

- (void)testParserRejectsMalformedKeyboardStateSchema {
    for (NSDictionary *keyboardState in @[
        @{},
        @{@"visible": @YES, @"locale": @"en_US"},
        @{
            @"visible": @1,
            @"locale": @"en_US",
            @"inlinePredictionEnabled": @YES,
        },
        @{
            @"visible": @YES,
            @"locale": @1,
            @"inlinePredictionEnabled": @YES,
        },
        @{
            @"visible": @YES,
            @"locale": @"en_US",
            @"inlinePredictionEnabled": @1,
        },
        @{
            @"visible": @YES,
            @"locale": @"en_US",
            @"inlinePredictionEnabled": @YES,
            @"unexpected": @1,
        },
    ]) {
        NSMutableDictionary *payload =
            [IDValidInlinePredictionStatus() mutableCopy];
        payload[@"keyboardState"] = keyboardState;
        NSError *error = nil;
        XCTAssertNil(IDParseInlinePredictionStatus(
            IDInlinePredictionJSONString(payload), &error),
            @"%@", keyboardState);
        XCTAssertEqualObjects(error.domain,
                              IDInlinePredictionStatusErrorDomain);
    }
}

- (void)testParserRejectsMalformedTemporaryRenderingDescriptor {
    NSMutableDictionary *payload =
        [IDValidInlinePredictionStatus() mutableCopy];
    payload[@"temporaryRenderingDescriptors"] = @[
        @{
            @"range": @{@"location": @14, @"length": @0},
            @"attributeKeys": @[@"NSTextInlinePrediction"],
        },
    ];
    NSError *error = nil;
    XCTAssertNil(IDParseInlinePredictionStatus(
        IDInlinePredictionJSONString(payload), &error));
    XCTAssertEqualObjects(error.domain, IDInlinePredictionStatusErrorDomain);
}

- (void)testParserFailsClosedForNonArrayRangeCollections {
    for (NSString *key in @[
        @"structuralNewlineLocations", @"checkingRanges",
    ]) {
        NSMutableDictionary *payload =
            [IDValidInlinePredictionStatus() mutableCopy];
        payload[key] = @1;
        NSError *error = nil;
        __block IDInlinePredictionStatus *status = nil;
        XCTAssertNoThrow(status = IDParseInlinePredictionStatus(
            IDInlinePredictionJSONString(payload), &error), @"%@", key);
        XCTAssertNil(status, @"%@", key);
        XCTAssertEqualObjects(error.domain,
                              IDInlinePredictionStatusErrorDomain);
    }
}

- (void)testAcceptedPredictionInsertionIsOneCanonicalTransaction {
    IDBlockDocument *document = IDBlockTextTestDocument(@[
        @"Earlier sentence. I look forward ",
        @"Later block stays.",
    ]);
    NSUUID *unaffectedIdentifier = document.blocks[1].identifier;
    IDCanonicalTextStorageAdapter *storage =
        [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];
    __block NSUInteger processedEditCount = 0;
    id observer = [NSNotificationCenter.defaultCenter
        addObserverForName:NSTextStorageDidProcessEditingNotification
                    object:storage
                     queue:nil
                usingBlock:^(__unused NSNotification *notification) {
                    processedEditCount += 1;
                }];

    [storage coordinateEditing:^{
        [storage replaceCharactersInRange:NSMakeRange(32, 0)
                               withString:@" to"];
    }];

    [NSNotificationCenter.defaultCenter removeObserver:observer];
    XCTAssertEqualObjects(storage.string,
        @"Earlier sentence. I look forward to \nLater block stays.");
    XCTAssertEqual(document.documentRevision, 1U);
    XCTAssertEqual(processedEditCount, 1U);
    XCTAssertEqual(document.blocks.count, 2U);
    XCTAssertEqualObjects(document.blocks[1].identifier,
                          unaffectedIdentifier);
    NSRange updatedSelection = NSMakeRange(35, 0);
    XCTAssertTrue(NSMaxRange(updatedSelection) <= storage.length);
}

- (void)testBoundaryMarkedPredictionPreservesBlockLayoutAndAnchorIdentities {
    NSArray<NSArray<NSString *> *> *documents = @[
        @[@"Earlier sentence. I look forward", @"Later block stays."],
        @[@"Earlier sentence.", @"I look forward ", @"Later block stays."],
    ];
    for (NSArray<NSString *> *blockStrings in documents) {
        NSMutableArray<NSAttributedString *> *blocks =
            [NSMutableArray arrayWithCapacity:blockStrings.count];
        for (NSString *string in blockStrings) {
            [blocks addObject:IDBlockTextTestAttributedString(string)];
        }
        IDBlockTextView *view = [[IDBlockTextView alloc]
            initWithFrame:CGRectMake(0, 0, 320, 240)
            attributedBlocks:blocks];
        NSArray<NSUUID *> *identifiers =
            [view.id_document.blocks valueForKey:@"identifier"];
        NSArray<IDBlockLayout *> *layouts =
            view.id_blockStack.blockLayouts.copy;
        IDBlock *tail = view.id_document.blocks.lastObject;
        IDRichTextAnchor *tailAnchor = [[IDRichTextAnchor alloc]
            initWithDocument:view.id_document
             blockIdentifier:tail.identifier
                  localOffset:4
                         bias:IDRichTextAnchorBiasAfter];
        NSUInteger tailOffsetBefore = [tailAnchor canonicalOffsetInProjection:
            [[IDCanonicalTextProjection alloc]
                initWithDocument:view.id_document]];
        UITextPosition *position = [view positionFromPosition:
            view.beginningOfDocument offset:32];
        view.selectedTextRange =
            [view textRangeFromPosition:position toPosition:position];
        NSUInteger revision = view.id_document.documentRevision;

        [view setMarkedText:@" to" selectedRange:NSMakeRange(0, 0)];

        XCTAssertEqual(view.id_document.documentRevision, revision + 1);
        XCTAssertEqualObjects(
            [view.id_document.blocks valueForKey:@"identifier"], identifiers);
        XCTAssertEqualObjects(view.id_blockStack.blockLayouts, layouts);
        XCTAssertEqualObjects(tailAnchor.blockIdentifier, tail.identifier);
        XCTAssertEqual(tailAnchor.localOffset, 4U);
        XCTAssertEqual([tailAnchor canonicalOffsetInProjection:
            [[IDCanonicalTextProjection alloc]
                initWithDocument:view.id_document]], tailOffsetBefore + 3);
        XCTAssertNotNil(view.markedTextRange);

        [view unmarkText];

        XCTAssertEqual(view.id_document.documentRevision, revision + 1);
        XCTAssertNil(view.markedTextRange);
        XCTAssertEqualObjects(
            [view.id_document.blocks valueForKey:@"identifier"], identifiers);
        XCTAssertEqualObjects(view.id_blockStack.blockLayouts, layouts);
    }
}

- (void)testPredictionRenderingAttributesStayOutOfCanonicalStorageAndRemove {
    NSArray<NSAttributedString *> *blocks = @[
        IDBlockTextTestAttributedString(@"I look forward "),
        IDBlockTextTestAttributedString(@"Later block stays."),
    ];
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
        attributedBlocks:blocks];
    NSString *attribute = @"IDTestInlinePredictionRendering";
    UITextPosition *start = [view positionFromPosition:view.beginningOfDocument
                                               offset:2];
    UITextPosition *end = [view positionFromPosition:start offset:4];
    UITextRange *range = [view textRangeFromPosition:start toPosition:end];

    [view.id_richLayoutController
        id_addRenderingAttributes:@{attribute: @"visible"} forRange:range];

    XCTAssertNil([view.id_textStorageAdapter attribute:attribute
                                               atIndex:2
                                        effectiveRange:NULL]);
    XCTAssertEqualObjects([view.id_richLayoutController
        id_annotationAttribute:attribute atPosition:start], @"visible");

    [view.id_richLayoutController
        id_removeRenderingAttributes:@[attribute] forRange:range];

    XCTAssertNil([view.id_textStorageAdapter attribute:attribute
                                               atIndex:2
                                        effectiveRange:NULL]);
    XCTAssertNil([view.id_richLayoutController
        id_annotationAttribute:attribute atPosition:start]);
}

@end
