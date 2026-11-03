@import XCTest;

#import <objc/runtime.h>

#import "IDBlockDocument.h"
#import "IDBlockLayout.h"
#import "IDBlockStackCanvasView.h"
#import "IDBlockTextTestSupport.h"
#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDPrivateUIKit+RichTextLayout.h"
#import "IDRichTextAnnotationStore.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDSpellingReadinessProbe.h"
#import "IDTextCanvasTestSupport.h"
#import "IDTextLayoutCanvasView.h"
#import "IDTextLayoutCanvasViewInternal.h"

@interface IDBlockTextView (IDTask10ContinuousSpellingTesting)
- (void)setContinuousSpellCheckingEnabled:(BOOL)enabled;
- (BOOL)isContinuousSpellCheckingEnabled;
@end

@interface IDRichTextAnnotationStore (IDTask10Testing)
- (NSUInteger)id_entryCount;
@end

@interface IDTask10TemporaryManagerProbe : NSObject
@property(nonatomic, strong) id addedAttribute;
@property(nonatomic, strong) id addedValue;
@property(nonatomic, strong) id addedRange;
@property(nonatomic, strong) id removedAttribute;
@property(nonatomic, strong) id removedRange;
@end

@implementation IDTask10TemporaryManagerProbe
- (void)addTemporaryAttribute:(id)attribute value:(id)value forTextRange:(id)range {
    self.addedAttribute = attribute;
    self.addedValue = value;
    self.addedRange = range;
}
- (void)removeTemporaryAttribute:(id)attribute forTextRange:(id)range {
    self.removedAttribute = attribute;
    self.removedRange = range;
}
@end

@interface NSTextLayoutManager (IDFinalReviewTemporaryReplayTesting)
- (void)addTemporaryAttribute:(id)attribute
                        value:(id)value
                 forTextRange:(NSTextRange *)range;
@end

@interface IDFinalReviewTemporaryReplayLayoutManager : NSTextLayoutManager
@property(nonatomic, readonly) NSUInteger id_finalReviewTemporaryAddCount;
@end


@implementation IDFinalReviewTemporaryReplayLayoutManager

- (void)addTemporaryAttribute:(id)attribute
                        value:(id)value
                 forTextRange:(NSTextRange *)range {
    NSNumber *count = objc_getAssociatedObject(
        self,
        @selector(id_finalReviewTemporaryAddCount));
    objc_setAssociatedObject(self,
                             @selector(id_finalReviewTemporaryAddCount),
                             @(count.unsignedIntegerValue + 1),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [super addTemporaryAttribute:attribute value:value forTextRange:range];
}

- (NSUInteger)id_finalReviewTemporaryAddCount {
    return [objc_getAssociatedObject(self, _cmd) unsignedIntegerValue];
}

@end

@interface IDTask10CanvasRangeProbe : IDTextLayoutCanvasView
- (NSArray<NSTextRange *> *)task10_invalidatedRanges;
@end

@implementation IDTask10CanvasRangeProbe
- (void)invalidateTemporaryAttributesInRange:(NSTextRange *)range {
    NSMutableArray *ranges = objc_getAssociatedObject(self, _cmd);
    if (ranges == nil) {
        ranges = [NSMutableArray array];
        objc_setAssociatedObject(self, _cmd, ranges, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [ranges addObject:range];
}
- (NSArray<NSTextRange *> *)task10_invalidatedRanges {
    return [objc_getAssociatedObject(
        self,
        @selector(invalidateTemporaryAttributesInRange:)) copy] ?: @[];
}
@end

@interface IDTask10WrongCanvasABIProbe : NSObject
- (id)invalidateTemporaryAttributesInRange:(id)range;
@end

@implementation IDTask10WrongCanvasABIProbe
- (id)invalidateTemporaryAttributesInRange:(id)range {
    return range;
}
@end

@interface IDBlockSpellingIntegrationTests : XCTestCase
@property(nonatomic, strong) UIWindow *testWindow;
@end

@implementation IDBlockSpellingIntegrationTests

- (void)tearDown {
    [self.testWindow resignKeyWindow];
    self.testWindow.hidden = YES;
    self.testWindow = nil;
    [super tearDown];
}

- (IDBlockTextView *)installedViewWithBlocks:(NSArray<NSString *> *)strings {
    UIWindowScene *windowScene = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) {
            windowScene = (UIWindowScene *)scene;
            break;
        }
    }
    XCTAssertNotNil(windowScene);
    self.testWindow = [[UIWindow alloc] initWithWindowScene:windowScene];
    self.testWindow.frame = CGRectMake(0, 0, 360, 280);
    UIViewController *controller = [UIViewController new];
    self.testWindow.rootViewController = controller;
    [self.testWindow makeKeyAndVisible];

    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    for (NSString *string in strings) {
        [blocks addObject:IDBlockTextTestAttributedString(string)];
    }
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(10, 10, 330, 180)
        attributedBlocks:blocks];
    view.spellCheckingType = UITextSpellCheckingTypeYes;
    view.autocorrectionType = UITextAutocorrectionTypeNo;
    [controller.view addSubview:view];
    [controller.view layoutIfNeeded];
    [view layoutIfNeeded];
    for (IDBlockLayout *layout in view.id_blockStack.blockLayouts) {
        [layout.canvasView performViewportLayout];
    }
    return view;
}

- (CGRect)markerBandForCanonicalRange:(NSRange)range
                               inView:(IDBlockTextView *)view
                                canvas:(IDTextLayoutCanvasView *)canvas {
    UITextPosition *start = [view positionFromPosition:view.beginningOfDocument
                                                offset:(NSInteger)range.location];
    UITextPosition *end = [view positionFromPosition:start offset:(NSInteger)range.length];
    UITextRange *textRange = [view textRangeFromPosition:start toPosition:end];
    CGRect wordRect = [view firstRectForRange:textRange];
    CGRect local = [canvas convertRect:wordRect fromView:view];
    return CGRectMake(CGRectGetMinX(local) - 1,
                      CGRectGetMaxY(local) - 5,
                      CGRectGetWidth(local) + 2,
                      5);
}

- (NSUInteger)redMarkerPixelsForCanonicalRange:(NSRange)range
                                         inView:(IDBlockTextView *)view
                                          canvas:(IDTextLayoutCanvasView *)canvas {
    [view setNeedsLayout];
    [view layoutIfNeeded];
    [canvas performViewportLayout];
    CGRect markerBand = [self markerBandForCanonicalRange:range
                                                   inView:view
                                                   canvas:canvas];
    return IDCountRedPixels(IDRenderView(canvas), markerBand);
}

- (void)testAnnotationAnchorsRebaseAndHalfOpenRemovalSplitsLiveEntry {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"xxwordyy"]);
    IDCanonicalTextStorageAdapter *adapter =
        [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];
    IDRichTextAnnotationStore *store =
        [[IDRichTextAnnotationStore alloc] initWithDocument:document];
    NSString *key = @"IDTask10Annotation";

    [store addAttribute:key value:@7 canonicalRange:NSMakeRange(2, 4)];
    [adapter replaceCharactersInRange:NSMakeRange(0, 0) withString:@"A"];

    XCTAssertEqualObjects([store annotationAttribute:key atCanonicalOffset:3], @7);
    XCTAssertEqualObjects([store annotationAttribute:key atCanonicalOffset:6], @7);
    XCTAssertNil([store annotationAttribute:key atCanonicalOffset:7]);
    NSAttributedString *substring =
        [store annotatedSubstringForCanonicalRange:NSMakeRange(2, 6)];
    XCTAssertEqualObjects(substring.string, @"xwordy");
    XCTAssertEqualObjects([substring attribute:key atIndex:1 effectiveRange:NULL], @7);
    XCTAssertNil([substring attribute:key atIndex:0 effectiveRange:NULL]);

    [store removeAttribute:key canonicalRange:NSMakeRange(4, 2)];
    XCTAssertEqualObjects([store annotationAttribute:key atCanonicalOffset:3], @7);
    XCTAssertNil([store annotationAttribute:key atCanonicalOffset:4]);
    XCTAssertNil([store annotationAttribute:key atCanonicalOffset:5]);
    XCTAssertEqualObjects([store annotationAttribute:key atCanonicalOffset:6], @7);
}

- (void)testCollapsedAnnotationIsRemovedAfterCanonicalReplacement {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"mispelled"]);
    IDCanonicalTextStorageAdapter *adapter =
        [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];
    IDRichTextAnnotationStore *store =
        [[IDRichTextAnnotationStore alloc] initWithDocument:document];
    NSString *key = @"IDTask10Annotation";
    [store addAttribute:key value:@1 canonicalRange:NSMakeRange(0, 9)];

    [adapter replaceCharactersInRange:NSMakeRange(0, 9) withString:@"misspelled"];

    for (NSUInteger offset = 0; offset < document.canonicalLength; offset += 1) {
        XCTAssertNil([store annotationAttribute:key atCanonicalOffset:offset]);
    }
    XCTAssertEqual([store annotatedSubstringForCanonicalRange:
        NSMakeRange(0, document.canonicalLength)].length,
                   document.canonicalLength);
}

- (void)testMutationCompletionSynchronouslyPurgesCollapsedEntryAndReleasesValue {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"word"]);
    IDCanonicalTextStorageAdapter *adapter =
        [[IDCanonicalTextStorageAdapter alloc] initWithDocument:document];
    IDRichTextAnnotationStore *store =
        [[IDRichTextAnnotationStore alloc] initWithDocument:document];
    __weak NSObject *weakValue = nil;
    @autoreleasepool {
        NSObject *value = [NSObject new];
        weakValue = value;
        [store addAttribute:@"IDTask10Annotation"
                      value:value
             canonicalRange:NSMakeRange(0, 4)];
        value = nil;
        XCTAssertNotNil(weakValue);

        [adapter replaceCharactersInRange:NSMakeRange(0, 4) withString:@"replacement"];

        XCTAssertNil(weakValue);
        XCTAssertEqual(store.id_entryCount, 0U);
    }
}

- (void)testWeakDocumentMutationObservationDoesNotRetainAnnotationStore {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"word"]);
    __weak IDRichTextAnnotationStore *weakStore = nil;
    @autoreleasepool {
        IDRichTextAnnotationStore *store =
            [[IDRichTextAnnotationStore alloc] initWithDocument:document];
        weakStore = store;
        XCTAssertNotNil(weakStore);
    }
    XCTAssertNil(weakStore);
    [document replaceCanonicalRange:NSMakeRange(0, 0)
               withAttributedString:[[NSAttributedString alloc] initWithString:@"x"]];
}

- (void)testAnnotatedSubstringStripsCanonicalShadowBeforeOverlayingAnnotation {
    NSShadow *shadow = [NSShadow new];
    NSAttributedString *text = [[NSAttributedString alloc]
        initWithString:@"word"
            attributes:@{NSShadowAttributeName: shadow}];
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[text]
                defaultAttributes:@{}];
    IDRichTextAnnotationStore *store =
        [[IDRichTextAnnotationStore alloc] initWithDocument:document];
    NSString *key = @"IDTask10Annotation";
    [store addAttribute:key value:@7 canonicalRange:NSMakeRange(1, 2)];

    NSAttributedString *result =
        [store annotatedSubstringForCanonicalRange:NSMakeRange(0, 4)];

    XCTAssertNil([result attribute:NSShadowAttributeName atIndex:0 effectiveRange:NULL]);
    XCTAssertEqualObjects([result attribute:key atIndex:1 effectiveRange:NULL], @7);
    XCTAssertEqualObjects([document.blocks[0].attributedText
        attribute:NSShadowAttributeName atIndex:0 effectiveRange:NULL], shadow);
}

- (void)testEmptyEndAndStructuralNewlineRangesCreateNoAnnotationEntries {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"a", @"b"]);
    IDRichTextAnnotationStore *store =
        [[IDRichTextAnnotationStore alloc] initWithDocument:document];
    NSString *key = @"IDTask10Annotation";

    [store addAttribute:key value:@1 canonicalRange:NSMakeRange(1, 1)];
    [store addAttribute:key value:@2
         canonicalRange:NSMakeRange(document.canonicalLength, 0)];

    XCTAssertEqual(store.id_entryCount, 0U);
    XCTAssertNil([store annotationAttribute:key atCanonicalOffset:0]);
    XCTAssertNil([store annotationAttribute:key
                          atCanonicalOffset:document.canonicalLength]);
}

- (void)testSameKeyOverlapsPreserveLatestLookupAndHalfOpenRemovalOrdering {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"abcdef"]);
    IDRichTextAnnotationStore *store =
        [[IDRichTextAnnotationStore alloc] initWithDocument:document];
    NSString *key = @"IDTask10Annotation";
    [store addAttribute:key value:@1 canonicalRange:NSMakeRange(0, 6)];
    [store addAttribute:key value:@2 canonicalRange:NSMakeRange(2, 2)];

    XCTAssertEqualObjects([store annotationAttribute:key atCanonicalOffset:1], @1);
    XCTAssertEqualObjects([store annotationAttribute:key atCanonicalOffset:2], @2);
    XCTAssertEqualObjects([store annotationAttribute:key atCanonicalOffset:3], @2);
    XCTAssertEqualObjects([store annotationAttribute:key atCanonicalOffset:4], @1);
    XCTAssertNil([store annotationAttribute:key atCanonicalOffset:6]);

    [store removeAttribute:key canonicalRange:NSMakeRange(3, 2)];
    XCTAssertEqualObjects([store annotationAttribute:key atCanonicalOffset:2], @2);
    XCTAssertNil([store annotationAttribute:key atCanonicalOffset:3]);
    XCTAssertNil([store annotationAttribute:key atCanonicalOffset:4]);
    XCTAssertEqualObjects([store annotationAttribute:key atCanonicalOffset:5], @1);
}

- (void)testTextAlternativesDisplayStylePrivateKeyRoundTripsWithoutCanonicalStorage {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"mispelled"]);
    IDRichTextAnnotationStore *store =
        [[IDRichTextAnnotationStore alloc] initWithDocument:document];
    NSString *key = @"_NSTextAlternativesDisplayStyleAttributeName";
    [store addAttribute:key value:@1 canonicalRange:NSMakeRange(0, 9)];

    XCTAssertEqualObjects([store annotationAttribute:key atCanonicalOffset:4], @1);
    XCTAssertEqualObjects([[store annotatedSubstringForCanonicalRange:NSMakeRange(0, 9)]
        attribute:key atIndex:4 effectiveRange:NULL], @1);
    XCTAssertNil([document.blocks[0].attributedText
        attribute:key atIndex:4 effectiveRange:NULL]);

    [store removeAttribute:key canonicalRange:NSMakeRange(0, 9)];
    XCTAssertNil([store annotationAttribute:key atCanonicalOffset:4]);
}

- (void)testTemporaryPrivateWrappersPreserveExactKeyValueRangeAndRejectWrongCanvasABI {
    IDTask10TemporaryManagerProbe *manager = [IDTask10TemporaryManagerProbe new];
    NSString *attribute = @"IDTask10Temporary";
    NSNumber *value = @3;
    NSTextRange *range = (NSTextRange *)(id)@"range-token";

    IDPrivateRichAddTemporaryAttribute((NSTextLayoutManager *)(id)manager,
                                       attribute,
                                       value,
                                       range,
                                       @"Task 10 exact add");
    XCTAssertEqualObjects(manager.addedAttribute, attribute);
    XCTAssertEqualObjects(manager.addedValue, value);
    XCTAssertEqual(manager.addedRange, range);
    IDPrivateRichRemoveTemporaryAttribute((NSTextLayoutManager *)(id)manager,
                                          attribute,
                                          range,
                                          @"Task 10 exact remove");
    XCTAssertEqualObjects(manager.removedAttribute, attribute);
    XCTAssertEqual(manager.removedRange, range);

    NSException *caught = nil;
    @try {
        IDPrivateRichInvalidateTemporaryAttributes(
            (UIView *)(id)[IDTask10WrongCanvasABIProbe new],
            range,
            @"Task 10 canvas ABI");
    } @catch (NSException *exception) {
        caught = exception;
    }
    XCTAssertEqualObjects(caught.name, NSInternalInconsistencyException);
    XCTAssertTrue([caught.reason containsString:@"Task 10 canvas ABI"], @"%@", caught.reason);
    XCTAssertTrue([caught.reason containsString:@"ABI mismatch"], @"%@", caught.reason);
}

- (void)testMisspellingUsesNativeTemporaryPixelsAndCorrectionDropsBelowHalf {
    if (!IDAssertEnglishCheckerAvailable(self)) return;
    IDBlockTextView *view = [self installedViewWithBlocks:@[@""]];
    XCTAssertTrue([view becomeFirstResponder]);
    [view setContinuousSpellCheckingEnabled:YES];
    XCTAssertTrue(view.isContinuousSpellCheckingEnabled);
    [view insertText:@"mispelled "];
    IDTextLayoutCanvasView *canvas =
        view.id_blockStack.blockLayouts.firstObject.canvasView;

    __block NSUInteger misspelledPixels = 0;
    XCTAssertTrue(IDWaitForCondition(3.0, ^BOOL{
        misspelledPixels = [self redMarkerPixelsForCanonicalRange:NSMakeRange(0, 9)
                                                           inView:view
                                                            canvas:canvas];
        return misspelledPixels > 3;
    }));
    NSDictionary *canonical = [view.id_textStorageAdapter
        attributesAtIndex:1 effectiveRange:NULL];
    XCTAssertNil(canonical[NSUnderlineStyleAttributeName]);
    XCTAssertNil(canonical[NSUnderlineColorAttributeName]);
    UIImage *misspelledImage = IDRenderView(canvas);
    CGRect misspelledROI = [self markerBandForCanonicalRange:NSMakeRange(0, 9)
                                                       inView:view
                                                       canvas:canvas];
    IDAttachSpellingObservation(self, @"block-text-view-misspelled", @{
        @"role": @"custom",
        @"text": view.text ?: @"",
        @"wordRange": @{ @"location": @0, @"length": @9 },
        @"firstRect": NSStringFromCGRect([view firstRectForRange:
            [view textRangeFromPosition:view.beginningOfDocument
                              toPosition:[view positionFromPosition:
                view.beginningOfDocument offset:9]]]),
        @"roi": NSStringFromCGRect(misspelledROI),
        @"redTotal": @(misspelledPixels),
        @"redRows": IDRedPixelCountsByRow(misspelledImage, misspelledROI),
        @"temporaryRenderingAttributesObserved": @(misspelledPixels > 0),
    }, misspelledImage);

    UITextPosition *wordEnd = [view positionFromPosition:view.beginningOfDocument offset:9];
    UITextRange *word = [view textRangeFromPosition:view.beginningOfDocument
                                         toPosition:wordEnd];
    [view replaceRange:word withText:@"misspelled"];
    __block NSUInteger correctedPixels = NSUIntegerMax;
    XCTAssertTrue(IDWaitForCondition(3.0, ^BOOL{
        correctedPixels = [self redMarkerPixelsForCanonicalRange:NSMakeRange(0, 10)
                                                           inView:view
                                                            canvas:canvas];
        return correctedPixels * 2 < misspelledPixels;
    }));
}

- (void)testStructuralNewlineInvalidationTargetsOnlyExactSecondBlockLocalRange {
    IDBlockTextView *view = [self installedViewWithBlocks:@[@"correct", @"mispelled"]];
    XCTAssertEqual(view.id_blockStack.blockLayouts.count, 2U);
    for (IDBlockLayout *layout in view.id_blockStack.blockLayouts) {
        object_setClass(layout.canvasView, IDTask10CanvasRangeProbe.class);
    }
    IDTask10CanvasRangeProbe *firstCanvas =
        (id)view.id_blockStack.blockLayouts[0].canvasView;
    IDTask10CanvasRangeProbe *secondCanvas =
        (id)view.id_blockStack.blockLayouts[1].canvasView;
    UITextPosition *start = [view positionFromPosition:view.beginningOfDocument offset:8];
    UITextPosition *end = [view positionFromPosition:start offset:9];
    UITextRange *wordRange = [view textRangeFromPosition:start toPosition:end];
    NSString *key = @"IDTask10Temporary";
    NSNumber *value = @17;
    [view.id_richLayoutController id_addRenderingAttributes:@{key: value}
                                                    forRange:wordRange];

    XCTAssertEqual(firstCanvas.task10_invalidatedRanges.count, 0U);
    XCTAssertEqual(secondCanvas.task10_invalidatedRanges.count, 1U);
    NSTextRange *localRange = secondCanvas.task10_invalidatedRanges.firstObject;
    IDBlockLayout *secondLayout = view.id_blockStack.blockLayouts[1];
    XCTAssertEqual([secondLayout localOffsetForLocation:localRange.location], 0U);
    XCTAssertEqual([secondLayout localOffsetForLocation:localRange.endLocation], 9U);
    NSAttributedString *annotated =
        [view.id_richLayoutController id_annotatedSubstringForRange:wordRange];
    XCTAssertEqualObjects([annotated attribute:key atIndex:0 effectiveRange:NULL], value);
    XCTAssertEqualObjects([annotated attribute:key atIndex:8 effectiveRange:NULL], value);
    XCTAssertNil([view.id_textStorageAdapter attribute:key
                                               atIndex:8
                                        effectiveRange:NULL]);

    UITextPosition *newlineStart =
        [view positionFromPosition:view.beginningOfDocument offset:7];
    UITextPosition *newlineEnd = [view positionFromPosition:newlineStart offset:1];
    [view.id_richLayoutController id_invalidateTemporaryAttributesInRange:
        [view textRangeFromPosition:newlineStart toPosition:newlineEnd]];
    [view.id_richLayoutController id_invalidateTemporaryAttributesInRange:
        [view textRangeFromPosition:view.endOfDocument toPosition:view.endOfDocument]];
    XCTAssertEqual(firstCanvas.task10_invalidatedRanges.count, 0U);
    XCTAssertEqual(secondCanvas.task10_invalidatedRanges.count, 1U);
}

- (void)testCanonicalEditRefreshesOnlyAffectedBlockAndReplaysItsLiveTemporaryAttributes {
    IDBlockTextView *view = [self installedViewWithBlocks:@[@"alpha", @"beta"]];
    IDBlockLayout *first = view.id_blockStack.blockLayouts[0];
    IDBlockLayout *second = view.id_blockStack.blockLayouts[1];
    object_setClass(first.layoutManager, IDFinalReviewTemporaryReplayLayoutManager.class);
    object_setClass(second.layoutManager, IDFinalReviewTemporaryReplayLayoutManager.class);
    NSString *key = @"IDFinalReviewTemporary";
    UITextPosition *firstEnd = [view positionFromPosition:view.beginningOfDocument offset:5];
    UITextRange *firstRange = [view textRangeFromPosition:view.beginningOfDocument
                                               toPosition:firstEnd];
    UITextPosition *secondStart = [view positionFromPosition:view.beginningOfDocument offset:6];
    UITextRange *secondRange = [view textRangeFromPosition:secondStart
                                                toPosition:view.endOfDocument];
    [view.id_richLayoutController id_addRenderingAttributes:@{key: @"first"}
                                                    forRange:firstRange];
    [view.id_richLayoutController id_addRenderingAttributes:@{key: @"second"}
                                                    forRange:secondRange];
    NSUInteger firstAddCount =
        ((IDFinalReviewTemporaryReplayLayoutManager *)first.layoutManager)
            .id_finalReviewTemporaryAddCount;
    NSUInteger secondAddCount =
        ((IDFinalReviewTemporaryReplayLayoutManager *)second.layoutManager)
            .id_finalReviewTemporaryAddCount;
    __block NSUInteger firstStorageEditCount = 0;
    id observer = [NSNotificationCenter.defaultCenter
        addObserverForName:NSTextStorageDidProcessEditingNotification
                    object:first.contentStorage.textStorage
                     queue:nil
                usingBlock:^(__unused NSNotification *notification) {
                    firstStorageEditCount += 1;
                }];

    [view.id_textStorageAdapter replaceCharactersInRange:NSMakeRange(7, 1)
                                               withString:@"E"];

    XCTAssertEqual(firstStorageEditCount, 0U);
    XCTAssertEqualObjects(first.contentStorage.textStorage.string, @"alpha");
    XCTAssertEqualObjects(second.contentStorage.textStorage.string, @"bEta");
    XCTAssertEqual(((IDFinalReviewTemporaryReplayLayoutManager *)first.layoutManager)
                       .id_finalReviewTemporaryAddCount,
                   firstAddCount);
    XCTAssertGreaterThan(((IDFinalReviewTemporaryReplayLayoutManager *)second.layoutManager)
                             .id_finalReviewTemporaryAddCount,
                         secondAddCount);
    XCTAssertEqualObjects([view.id_richLayoutController
        id_annotationAttribute:key
                    atPosition:[view positionFromPosition:view.beginningOfDocument offset:1]],
                          @"first");
    XCTAssertEqualObjects([view.id_richLayoutController
        id_annotationAttribute:key
                    atPosition:[view positionFromPosition:view.beginningOfDocument offset:7]],
                          @"second");

    NSUInteger replayedSecondAddCount =
        ((IDFinalReviewTemporaryReplayLayoutManager *)second.layoutManager)
            .id_finalReviewTemporaryAddCount;
    [view setNeedsLayout];
    [view layoutIfNeeded];
    [NSNotificationCenter.defaultCenter removeObserver:observer];
    XCTAssertEqual(firstStorageEditCount, 0U);
    XCTAssertEqual(((IDFinalReviewTemporaryReplayLayoutManager *)first.layoutManager)
                       .id_finalReviewTemporaryAddCount,
                   firstAddCount);
    XCTAssertEqual(((IDFinalReviewTemporaryReplayLayoutManager *)second.layoutManager)
                       .id_finalReviewTemporaryAddCount,
                   replayedSecondAddCount);
}

@end
