@import XCTest;

#import "IDBlockDocument.h"
#import "IDBlockDocumentInternal.h"
#import "IDBlockLayout.h"
#import "IDBlockStackCanvasView.h"
#import "IDBlockTextTestSupport.h"
#import "IDTextLayoutCanvasView.h"
#import "IDTextLayoutCanvasViewInternal.h"
#import "IDTextRenderingSurfaceView.h"
#import "IDTextCanvasAttachmentLifecycle.h"

#import <objc/runtime.h>

@interface IDBlockLayout (IDBlockLayoutCanvasHostTesting)
- (nullable id)id_canvasHost;
- (void)id_setCanvasHost:(nullable id)host;
- (CGPoint)textContainerOrigin;
- (nullable id)customRenderController;
- (UIColor *)textColor;
- (BOOL)isEditable;
- (BOOL)isEditing;
- (void)id_attachmentView:(UIView *)view
    didLayoutInFragmentFrame:(CGRect)fragmentFrame;
- (void)id_attachmentViewsDidEnterViewport:(NSSet<UIView *> *)views;
- (void)id_attachmentViewsDidLeaveViewport:(NSSet<UIView *> *)views;
- (void)_textKit2CanvasDidLayout;
- (void)_updateInteractionGeometry;
@end

@interface IDBlockStackCanvasView (IDBlockLayoutCanvasHostTesting)
- (void)id_setCanvasHost:(nullable id)host;
@end

@interface IDBlockLayoutHostProbe : NSObject <IDTextCanvasAttachmentLifecycleSink>
@property(nonatomic, strong) UIColor *textColor;
@property(nonatomic, strong) id customRenderController;
@property(nonatomic, getter=isEditable) BOOL editable;
@property(nonatomic, getter=isEditing) BOOL editing;
@property(nonatomic) NSUInteger didLayoutCount;
@property(nonatomic) NSUInteger interactionGeometryUpdateCount;
@property(nonatomic, strong) NSMutableArray<UIView *> *attachmentViews;
@property(nonatomic, strong) NSMutableArray<NSValue *> *attachmentFrames;
@property(nonatomic, strong) NSMutableArray<NSSet<UIView *> *> *enteredAttachmentBatches;
@property(nonatomic, strong) NSMutableArray<NSSet<UIView *> *> *leftAttachmentBatches;
@end

@implementation IDBlockLayoutHostProbe

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _attachmentViews = [NSMutableArray array];
        _attachmentFrames = [NSMutableArray array];
        _enteredAttachmentBatches = [NSMutableArray array];
        _leftAttachmentBatches = [NSMutableArray array];
    }
    return self;
}

- (void)id_attachmentView:(UIView *)view
    didLayoutInFragmentFrame:(CGRect)fragmentRect {
    [self.attachmentViews addObject:view];
    [self.attachmentFrames addObject:[NSValue valueWithCGRect:fragmentRect]];
}

- (void)id_attachmentViewsDidEnterViewport:(NSSet<UIView *> *)views {
    [self.enteredAttachmentBatches addObject:views];
}

- (void)id_attachmentViewsDidLeaveViewport:(NSSet<UIView *> *)views {
    [self.leftAttachmentBatches addObject:views];
}

// The canvas forwards to its host under the neutral names it compiles its callbacks under (the
// private ones exist only at run time, for UIKit).
- (void)tgpn__textKit2CanvasDidLayout {
    self.didLayoutCount += 1;
}

- (void)tgpn__updateInteractionGeometry {
    self.interactionGeometryUpdateCount += 1;
}

- (id)tgpn_customRenderController {
    return self.customRenderController;
}

@end

@interface NSTextLayoutManager (IDFinalReviewTemporaryAttributeTesting)
- (void)addTemporaryAttribute:(id)attribute
                        value:(id)value
                 forTextRange:(NSTextRange *)range;
@end

@interface IDFinalReviewRecordingLayoutManager : NSTextLayoutManager
@property(nonatomic, readonly) NSUInteger id_temporaryAddCount;
@end

@implementation IDFinalReviewRecordingLayoutManager

- (void)addTemporaryAttribute:(id)attribute
                        value:(id)value
                 forTextRange:(NSTextRange *)range {
    NSNumber *count = objc_getAssociatedObject(
        self,
        @selector(id_temporaryAddCount));
    objc_setAssociatedObject(self,
                             @selector(id_temporaryAddCount),
                             @(count.unsignedIntegerValue + 1),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [super addTemporaryAttribute:attribute value:value forTextRange:range];
}

- (NSUInteger)id_temporaryAddCount {
    return [objc_getAssociatedObject(self, _cmd) unsignedIntegerValue];
}

@end


@interface IDFinalReviewRecordingCanvasView : IDTextLayoutCanvasView
@property(nonatomic, readonly) NSUInteger id_displayInvalidationCount;
@end


@implementation IDFinalReviewRecordingCanvasView

- (void)setNeedsDisplay {
    NSNumber *count = objc_getAssociatedObject(
        self,
        @selector(id_displayInvalidationCount));
    objc_setAssociatedObject(self,
                             @selector(id_displayInvalidationCount),
                             @(count.unsignedIntegerValue + 1),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [super setNeedsDisplay];
}

- (NSUInteger)id_displayInvalidationCount {
    return [objc_getAssociatedObject(self, _cmd) unsignedIntegerValue];
}

@end

@interface IDBlockLayoutTests : XCTestCase
@end

@implementation IDBlockLayoutTests

/// DISPLAY-ONLY DECORATION. Styling that must never enter the model — a spoiler's hide, which also
/// has to come and go as the selection moves — has nowhere to live in this engine: presentation is
/// otherwise written into the document, and every visual channel there maps onto a model field.
///
/// The decorator runs where the canvas actually reads, which is the ONLY place that works. Three
/// earlier attempts hooked `attributesByApplyingTraits:`, the text storage's `attributesAtIndex:`,
/// and a `UIEditMenuInteraction`; all compiled, all tested green, none rendered. `IDBlockLayout`
/// loads its per-block `NSTextContentStorage` from `block.attributedText`, so this is the seam.
- (void)testADisplayDecoratorReachesRenderingAndNotTheDocument {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"alpha beta"]);
    IDBlock *block = document.blocks.firstObject;
    IDBlockLayout *layout = [[IDBlockLayout alloc] initWithBlock:block width:300.0];

    layout.displayDecorator = ^NSAttributedString *(NSAttributedString *text, NSUUID *identifier) {
        NSMutableAttributedString *result = [text mutableCopy];
        [result addAttribute:NSBackgroundColorAttributeName
                       value:UIColor.redColor
                       range:NSMakeRange(0, MIN((NSUInteger)5, result.length))];
        return result;
    };
    [layout updateContentFromBlock:block];

    id rendered = [layout.contentStorage.textStorage attribute:NSBackgroundColorAttributeName
                                                       atIndex:0
                                                effectiveRange:NULL];
    XCTAssertEqualObjects(rendered, UIColor.redColor,
                          @"the decorator did not reach what the canvas renders");

    id model = [block.attributedText attribute:NSBackgroundColorAttributeName
                                       atIndex:0
                                effectiveRange:NULL];
    XCTAssertNil(model, @"display-only styling reached the DOCUMENT, where it would be sent");
}

/// THE CONTROL: without a decorator the rendered text is the block's own, unchanged.
- (void)testWithNoDecoratorRenderedTextIsTheBlockText {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"alpha beta"]);
    IDBlock *block = document.blocks.firstObject;
    IDBlockLayout *layout = [[IDBlockLayout alloc] initWithBlock:block width:300.0];
    [layout updateContentFromBlock:block];

    XCTAssertEqualObjects(layout.contentStorage.textStorage.string, block.attributedText.string);
    XCTAssertNil([layout.contentStorage.textStorage attribute:NSBackgroundColorAttributeName
                                                      atIndex:0 effectiveRange:NULL]);
}

- (IDBlockStackCanvasView *)stackForDocument:(IDBlockDocument *)document
                                       width:(CGFloat)width {
    IDBlockStackCanvasView *stack =
        [[IDBlockStackCanvasView alloc] initWithDocument:document];
    [stack updateForDocumentChange:nil width:width];
    return stack;
}

- (void)testEveryBlockOwnsAnIndependentDerivedTextKitGraphAndExistingCanvas {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"alpha", @"beta"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:90.0];
    IDBlockLayout *first = stack.blockLayouts[0];
    IDBlockLayout *second = stack.blockLayouts[1];

    XCTAssertNotEqual(first.contentStorage, second.contentStorage);
    XCTAssertNotEqual(first.contentStorage.textStorage, second.contentStorage.textStorage);
    XCTAssertNotEqual(first.layoutManager, second.layoutManager);
    XCTAssertNotEqual(first.textContainer, second.textContainer);
    XCTAssertNotEqual(first.canvasView, second.canvasView);
    XCTAssertTrue([first.canvasView isMemberOfClass:IDTextLayoutCanvasView.class]);
    XCTAssertTrue([second.canvasView isMemberOfClass:IDTextLayoutCanvasView.class]);
    XCTAssertEqual(first.canvasView.context, first);
    XCTAssertEqual(second.canvasView.context, second);
    XCTAssertEqual(first.canvasView.superview, stack);
    XCTAssertEqual(second.canvasView.superview, stack);
    XCTAssertEqualObjects(first.contentStorage.textStorage.string, @"alpha");
    XCTAssertEqualObjects(second.contentStorage.textStorage.string, @"beta");
    XCTAssertNil(first.layoutManager.delegate);
    XCTAssertNil(second.layoutManager.delegate);
    for (UIView *view in stack.subviews) {
        XCTAssertFalse([view isKindOfClass:UITextView.class]);
    }
}

- (void)testPerBlockStorageIsDerivedOnlyAndRefreshesFromTheDocument {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"canonical"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:180.0];
    IDBlockLayout *layout = stack.blockLayouts.firstObject;
    NSUInteger revision = document.documentRevision;

    [layout.contentStorage.textStorage replaceCharactersInRange:NSMakeRange(0, 3)
                                                      withString:@"DERIVED"];

    XCTAssertEqualObjects(document.blocks.firstObject.attributedText.string, @"canonical");
    XCTAssertEqual(document.documentRevision, revision);
    [stack updateForDocumentChange:nil width:180.0];
    XCTAssertEqualObjects(layout.contentStorage.textStorage.string, @"DERIVEDonical");

    IDBlockDocumentChange *change = [document
        replaceCanonicalRange:NSMakeRange(0, document.canonicalLength)
        withAttributedString:IDBlockTextTestAttributedString(@"refreshed")];
    [stack updateForDocumentChange:change width:180.0];
    XCTAssertEqualObjects(layout.contentStorage.textStorage.string, @"refreshed");
}

- (void)testDefaultAttributeMutationReportsAndRefreshesAnEmptyBlock {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@""]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:180.0];
    IDBlockLayout *layout = stack.blockLayouts.firstObject;
    NSUInteger documentRevision = document.documentRevision;
    NSUInteger contentRevision = layout.contentRevision;
    UIFont *font = [UIFont systemFontOfSize:31.0 weight:UIFontWeightSemibold];
    UIColor *color = UIColor.systemOrangeColor;

    IDBlockDocumentChange *change = [document id_setDefaultAttributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color,
    }];
    [stack updateForDocumentChange:change width:180.0];

    XCTAssertNotNil(change);
    XCTAssertEqual(document.documentRevision, documentRevision + 1);
    XCTAssertEqualObjects(change.affectedBlockIdentifiers,
                          @[document.blocks.firstObject.identifier]);
    XCTAssertEqual(layout.contentRevision, contentRevision + 1);
    NSDictionary<NSAttributedStringKey, id> *attributes =
        [layout attributesAtLocalOffset:0
                              direction:UITextStorageDirectionForward];
    XCTAssertEqualObjects(attributes[NSFontAttributeName], font);
    XCTAssertEqualObjects(attributes[NSForegroundColorAttributeName], color);
    XCTAssertEqualWithAccuracy(layout.usedSize.height, font.lineHeight, 0.5);
}

- (void)testDefaultAttributeReplacementRemovesRetiredKeysFromAnEmptyBlock {
    UIFont *oldFont = [UIFont systemFontOfSize:17.0];
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[[[NSAttributedString alloc] initWithString:@""]]
        defaultAttributes:@{
            NSFontAttributeName: oldFont,
            NSForegroundColorAttributeName: UIColor.labelColor,
            NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
        }];
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:180.0];
    UIFont *newFont = [UIFont systemFontOfSize:29.0];

    IDBlockDocumentChange *change = [document id_setDefaultAttributes:@{
        NSFontAttributeName: newFont,
        NSForegroundColorAttributeName: UIColor.systemPurpleColor,
    }];
    [stack updateForDocumentChange:change width:180.0];

    XCTAssertNil(document.blocks.firstObject
                     .separatorAttributes[NSUnderlineStyleAttributeName]);
    NSDictionary<NSAttributedStringKey, id> *attributes =
        [stack.blockLayouts.firstObject
            attributesAtLocalOffset:0
                          direction:UITextStorageDirectionForward];
    XCTAssertNil(attributes[NSUnderlineStyleAttributeName]);
    XCTAssertEqualObjects(attributes[NSFontAttributeName], newFont);
}

- (void)testEditInSecondBlockDoesNotEditOrInvalidateFirstDerivedLayout {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"alpha", @"beta"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:180.0];
    IDBlockLayout *first = stack.blockLayouts[0];
    IDBlockLayout *second = stack.blockLayouts[1];
    object_setClass(first.canvasView, IDFinalReviewRecordingCanvasView.class);
    __block NSUInteger firstStorageEditCount = 0;
    id observer = [NSNotificationCenter.defaultCenter
        addObserverForName:NSTextStorageDidProcessEditingNotification
                    object:first.contentStorage.textStorage
                     queue:nil
                usingBlock:^(__unused NSNotification *notification) {
                    firstStorageEditCount += 1;
                }];
    NSUInteger firstDisplayCount =
        ((IDFinalReviewRecordingCanvasView *)first.canvasView).id_displayInvalidationCount;

    IDBlockDocumentChange *change = [document
        replaceCanonicalRange:NSMakeRange(7, 1)
        withAttributedString:IDBlockTextTestAttributedString(@"E")];
    [stack updateForDocumentChange:change width:180.0];

    [NSNotificationCenter.defaultCenter removeObserver:observer];
    XCTAssertEqual(firstStorageEditCount, 0U);
    XCTAssertEqual(((IDFinalReviewRecordingCanvasView *)first.canvasView)
                       .id_displayInvalidationCount,
                   firstDisplayCount);
    XCTAssertEqualObjects(first.contentStorage.textStorage.string, @"alpha");
    XCTAssertEqualObjects(second.contentStorage.textStorage.string, @"bEta");
}

- (void)testLayoutOnlyPassDoesNotReplaceDerivedContentOrTouchTemporaryManager {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"alpha", @"beta"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:180.0];
    IDBlockLayout *first = stack.blockLayouts[0];
    object_setClass(first.layoutManager, IDFinalReviewRecordingLayoutManager.class);
    __block NSUInteger storageEditCount = 0;
    id observer = [NSNotificationCenter.defaultCenter
        addObserverForName:NSTextStorageDidProcessEditingNotification
                    object:first.contentStorage.textStorage
                     queue:nil
                usingBlock:^(__unused NSNotification *notification) {
                    storageEditCount += 1;
                }];
    NSUInteger addCount = ((IDFinalReviewRecordingLayoutManager *)first.layoutManager)
        .id_temporaryAddCount;

    [stack updateForDocumentChange:nil width:180.0];

    [NSNotificationCenter.defaultCenter removeObserver:observer];
    XCTAssertEqual(storageEditCount, 0U);
    XCTAssertEqual(((IDFinalReviewRecordingLayoutManager *)first.layoutManager)
                       .id_temporaryAddCount,
                   addCount);
    XCTAssertEqualObjects(first.contentStorage.textStorage.string, @"alpha");
}

- (NSMutableAttributedString *)richBlockTextWithAttachment:(NSTextAttachment *)attachment
                                                     color:(UIColor *)color {
    NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
    paragraphStyle.firstLineHeadIndent = 13.0;
    paragraphStyle.paragraphSpacing = 7.0;
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc]
        initWithString:@"A\uFFFCB"
            attributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:17.0],
                NSForegroundColorAttributeName: color,
                NSParagraphStyleAttributeName: paragraphStyle,
            }];
    [text addAttribute:NSFontAttributeName
                 value:[UIFont boldSystemFontOfSize:21.0]
                 range:NSMakeRange(0, 1)];
    [text addAttribute:NSAttachmentAttributeName
                 value:attachment
                 range:NSMakeRange(1, 1)];
    [text addAttributes:@{
        NSFontAttributeName: [UIFont italicSystemFontOfSize:15.0],
        NSBaselineOffsetAttributeName: @3.0,
    } range:NSMakeRange(2, 1)];
    return text;
}

- (void)testDerivedStoragePreservesEveryAttributedRunAtInitialization {
    NSTextAttachment *attachment = [NSTextAttachment new];
    attachment.bounds = CGRectMake(0, 0, 18, 24);
    NSAttributedString *rich = [self richBlockTextWithAttachment:attachment
                                                           color:UIColor.systemRedColor];
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[rich]
               defaultAttributes:IDBlockTextTestAttributes()];

    IDBlockLayout *layout = [[IDBlockLayout alloc]
        initWithBlock:document.blocks.firstObject
                width:180.0];

    XCTAssertTrue([layout.contentStorage.textStorage isEqualToAttributedString:rich]);
    XCTAssertEqual([layout.contentStorage.textStorage attribute:NSAttachmentAttributeName
                                                        atIndex:1
                                                 effectiveRange:NULL],
                   attachment);
}

- (void)testDerivedStoragePreservesEveryAttributedRunOnUpdate {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"old"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:180.0];
    IDBlockLayout *layout = stack.blockLayouts.firstObject;
    NSTextAttachment *attachment = [NSTextAttachment new];
    attachment.bounds = CGRectMake(-2, -4, 20, 28);
    NSAttributedString *rich = [self richBlockTextWithAttachment:attachment
                                                           color:UIColor.systemBlueColor];

    IDBlockDocumentChange *change = [document
        replaceCanonicalRange:NSMakeRange(0, document.canonicalLength)
        withAttributedString:rich];
    [stack updateForDocumentChange:change width:180.0];

    XCTAssertEqual(stack.blockLayouts.firstObject, layout);
    XCTAssertTrue([layout.contentStorage.textStorage isEqualToAttributedString:rich]);
    XCTAssertEqual([layout.contentStorage.textStorage attribute:NSAttachmentAttributeName
                                                        atIndex:1
                                                 effectiveRange:NULL],
                   attachment);
}

- (void)testSameHeightTextUpdateReconcilesFragmentsAndSurfacesOnNextViewportPass {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"AAAA"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:200.0];
    IDBlockLayout *layout = stack.blockLayouts.firstObject;
    [layout.canvasView performViewportLayout];
    NSTextLayoutFragment *oldFragment = layout.canvasView.visibleFragments.firstObject;
    IDTextRenderingSurfaceView *oldSurface =
        (IDTextRenderingSurfaceView *)layout.canvasView.visibleSurfaces.firstObject;
    CGFloat oldHeight = layout.usedSize.height;
    XCTAssertEqualObjects(((NSTextParagraph *)oldFragment.textElement).attributedString.string,
                          @"AAAA");
    XCTAssertEqual(oldSurface.layoutFragment, oldFragment);

    IDBlockDocumentChange *change = [document
        replaceCanonicalRange:NSMakeRange(0, document.canonicalLength)
        withAttributedString:IDBlockTextTestAttributedString(@"BBBB")];
    [stack updateForDocumentChange:change width:200.0];
    XCTAssertEqual(layout.usedSize.height, oldHeight);
    [layout.canvasView performViewportLayout];

    NSTextLayoutFragment *newFragment = layout.canvasView.visibleFragments.firstObject;
    IDTextRenderingSurfaceView *newSurface =
        (IDTextRenderingSurfaceView *)layout.canvasView.visibleSurfaces.firstObject;
    XCTAssertNotNil(newFragment);
    XCTAssertNotNil(newSurface);
    XCTAssertEqualObjects(((NSTextParagraph *)newFragment.textElement).attributedString.string,
                          @"BBBB");
    XCTAssertEqual(newSurface.layoutFragment, newFragment);
    XCTAssertEqual([layout.canvasView surfaceForFragment:newFragment], newSurface);
    if (oldFragment != newFragment) {
        XCTAssertNil([layout.canvasView surfaceForFragment:oldFragment]);
    }
}

- (void)testFullRangeLayoutUsesDeterministicWidthAndExactFractionalStacking {
    IDBlockDocument *document = IDBlockTextTestDocument(@[
        @"one two three four five six seven eight nine ten eleven twelve",
        @"tail",
    ]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:83.25];
    IDBlockLayout *first = stack.blockLayouts[0];
    IDBlockLayout *second = stack.blockLayouts[1];
    CGPoint firstOrigin = [stack documentOriginForBlockIdentifier:first.blockIdentifier];
    CGPoint secondOrigin = [stack documentOriginForBlockIdentifier:second.blockIdentifier];
    CGRect firstUsage = CGRectStandardize(first.layoutManager.usageBoundsForTextContainer);
    CGRect secondUsage = CGRectStandardize(second.layoutManager.usageBoundsForTextContainer);
    CGSize expectedFirstSize = CGSizeMake(
        MAX(CGRectGetMaxX(firstUsage), 0.0) - MIN(CGRectGetMinX(firstUsage), 0.0),
        MAX(CGRectGetMaxY(firstUsage), 0.0) - MIN(CGRectGetMinY(firstUsage), 0.0));
    CGSize expectedSecondSize = CGSizeMake(
        MAX(CGRectGetMaxX(secondUsage), 0.0) - MIN(CGRectGetMinX(secondUsage), 0.0),
        MAX(CGRectGetMaxY(secondUsage), 0.0) - MIN(CGRectGetMinY(secondUsage), 0.0));
    CGFloat exactDocumentHeight =
        expectedFirstSize.height + expectedSecondSize.height;

    XCTAssertEqual(first.textContainer.size.width, 83.25);
    XCTAssertEqual(second.textContainer.size.width, 83.25);
    XCTAssertGreaterThan(first.usedSize.height, ceil([UIFont systemFontOfSize:17.0].lineHeight * 2));
    XCTAssertTrue(CGSizeEqualToSize(first.usedSize, expectedFirstSize));
    XCTAssertTrue(CGSizeEqualToSize(second.usedSize, expectedSecondSize));
    XCTAssertEqual(firstOrigin.y, 0.0);
    XCTAssertEqual(secondOrigin.y, expectedFirstSize.height);
    XCTAssertNotEqual(secondOrigin.y, floor(secondOrigin.y));
    XCTAssertEqual(CGRectGetMinY(second.canvasView.frame), secondOrigin.y);
    XCTAssertEqual(CGRectGetHeight(first.canvasView.frame), expectedFirstSize.height);
    XCTAssertEqual(CGRectGetHeight(second.canvasView.frame), expectedSecondSize.height);
    XCTAssertEqual(stack.documentContentSize.height, ceil(exactDocumentHeight));
    XCTAssertNotEqual(stack.documentContentSize.height, exactDocumentHeight);
    XCTAssertEqual(stack.documentContentSize.width, ceil(83.25));
}

- (void)testGrowingLeadingBlockMovesDownstreamByExactUsedHeightDeltaAndReusesIdentity {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"short", @"stable tail"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:96.0];
    IDBlockLayout *first = stack.blockLayouts[0];
    IDBlockLayout *second = stack.blockLayouts[1];
    IDTextLayoutCanvasView *secondCanvas = second.canvasView;
    CGFloat oldFirstHeight = first.usedSize.height;
    CGFloat oldSecondOrigin =
        [stack documentOriginForBlockIdentifier:second.blockIdentifier].y;

    NSString *wrapped = @"one two three four five six seven eight nine ten eleven twelve";
    IDBlockDocumentChange *change = [document
        replaceCanonicalRange:NSMakeRange(0, document.blocks[0].attributedText.length)
        withAttributedString:IDBlockTextTestAttributedString(wrapped)];
    [stack updateForDocumentChange:change width:96.0];

    CGFloat newFirstHeight = first.usedSize.height;
    CGFloat newSecondOrigin =
        [stack documentOriginForBlockIdentifier:second.blockIdentifier].y;
    XCTAssertEqual(stack.blockLayouts[0], first);
    XCTAssertEqual(stack.blockLayouts[1], second);
    XCTAssertEqual(stack.blockLayouts[1].canvasView, secondCanvas);
    XCTAssertGreaterThan(newFirstHeight, oldFirstHeight);
    XCTAssertEqual(newSecondOrigin - oldSecondOrigin, newFirstHeight - oldFirstHeight);
    XCTAssertEqual(newSecondOrigin, newFirstHeight);
}

- (void)testStableIdentifierReconciliationCreatesAndRemovesOnlyChangedLayouts {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"alpha", @"beta"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:120.0];
    IDBlockLayout *first = stack.blockLayouts[0];
    IDBlockLayout *second = stack.blockLayouts[1];

    IDBlockDocumentChange *insert = [document
        replaceCanonicalRange:NSMakeRange(2, 0)
        withAttributedString:IDBlockTextTestAttributedString(@"\nX")];
    [stack updateForDocumentChange:insert width:120.0];
    IDBlockLayout *inserted = stack.blockLayouts[1];
    IDTextLayoutCanvasView *insertedCanvas = inserted.canvasView;

    XCTAssertEqual(stack.blockLayouts.count, 3U);
    XCTAssertEqual(stack.blockLayouts[0], first);
    XCTAssertEqual(stack.blockLayouts[2], second);
    XCTAssertNotEqual(inserted, first);
    XCTAssertNotEqual(inserted, second);
    XCTAssertEqualObjects([stack.blockLayouts valueForKey:@"blockIdentifier"],
                          [document.blocks valueForKey:@"identifier"]);
    XCTAssertEqualObjects(stack.subviews,
                          (@[first.canvasView, inserted.canvasView, second.canvasView]));

    NSUUID *insertedIdentifier = inserted.blockIdentifier;
    IDBlockDocumentChange *remove = [document
        replaceCanonicalRange:NSMakeRange(2, 2)
        withAttributedString:IDBlockTextTestAttributedString(@"")];
    [stack updateForDocumentChange:remove width:120.0];

    XCTAssertEqual(stack.blockLayouts.count, 2U);
    XCTAssertEqual(stack.blockLayouts[0], first);
    XCTAssertEqual(stack.blockLayouts[1], second);
    XCTAssertNil([stack layoutForBlockIdentifier:insertedIdentifier]);
    XCTAssertNil(insertedCanvas.superview);
    XCTAssertEqualObjects(stack.subviews, (@[first.canvasView, second.canvasView]));
}

- (void)testLocalUTF16OffsetsAndLocationsRoundTripIncludingBothEnds {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"a👨‍👩‍👧‍👦b", @"foreign"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:220.0];
    IDBlockLayout *layout = stack.blockLayouts[0];
    NSUInteger length = document.blocks[0].attributedText.length;

    for (NSUInteger offset = 0; offset <= length; offset += 1) {
        id<NSTextLocation> location = [layout locationForLocalOffset:offset];
        XCTAssertNotNil(location);
        XCTAssertEqual([layout localOffsetForLocation:location], offset);
    }
    XCTAssertNil([layout locationForLocalOffset:length + 1]);
    XCTAssertEqual([layout localOffsetForLocation:(id<NSTextLocation>)nil], NSNotFound);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"

- (void)testBlockLayoutInitializerRejectsNilBlockDeterministically {
    @try {
        (void)[[IDBlockLayout alloc] initWithBlock:(IDBlock *)nil width:120.0];
        XCTFail(@"Expected nil block rejection");
    } @catch (NSException *exception) {
        XCTAssertEqualObjects(exception.name, NSInvalidArgumentException);
        XCTAssertEqualObjects(exception.reason, @"IDBlockLayout requires a block.");
    }
}

- (void)testBlockStackInitializerRejectsNilDocumentDeterministically {
    @try {
        (void)[[IDBlockStackCanvasView alloc] initWithDocument:(IDBlockDocument *)nil];
        XCTFail(@"Expected nil document rejection");
    } @catch (NSException *exception) {
        XCTAssertEqualObjects(exception.name, NSInvalidArgumentException);
        XCTAssertEqualObjects(exception.reason,
                              @"IDBlockStackCanvasView requires a document.");
    }
}

#pragma clang diagnostic pop

- (void)testEmptyBlockHasOneExactFontLineAndBoundaryPointsChooseTheFollowingBlock {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"", @"second"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:160.0];
    IDBlockLayout *first = stack.blockLayouts[0];
    IDBlockLayout *second = stack.blockLayouts[1];
    CGFloat boundary = [stack documentOriginForBlockIdentifier:second.blockIdentifier].y;

    CGFloat exactLineHeight = [UIFont systemFontOfSize:17.0].lineHeight;
    XCTAssertEqual(first.usedSize.height, exactLineHeight);
    XCTAssertEqual(CGRectGetHeight(first.canvasView.frame), exactLineHeight);
    XCTAssertEqual(boundary, first.usedSize.height);
    XCTAssertEqual([stack nearestBlockLayoutForDocumentPoint:CGPointMake(0, -100)], first);
    XCTAssertEqual([stack nearestBlockLayoutForDocumentPoint:CGPointMake(0, boundary - 0.1)],
                   first);
    XCTAssertEqual([stack nearestBlockLayoutForDocumentPoint:CGPointMake(0, boundary)], second);
    XCTAssertEqual([stack nearestBlockLayoutForDocumentPoint:CGPointMake(0, boundary + 0.1)],
                   second);
    XCTAssertEqual([stack nearestBlockLayoutForDocumentPoint:CGPointMake(0, 10000)], second);
}

- (void)testProjectAttachmentCallbacksForwardThroughWeakHostWithoutCycle {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"callbacks"]);
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:160.0];
    IDBlockLayout *layout = stack.blockLayouts.firstObject;
    __weak IDBlockLayoutHostProbe *weakHost = nil;
    @autoreleasepool {
        IDBlockLayoutHostProbe *host = [IDBlockLayoutHostProbe new];
        host.textColor = UIColor.systemPurpleColor;
        host.customRenderController = [NSObject new];
        host.editable = YES;
        host.editing = YES;
        weakHost = host;

        [stack id_setCanvasHost:host];

        XCTAssertEqual([layout id_canvasHost], host);
        XCTAssertEqual([layout textColor], host.textColor);
        XCTAssertEqual([layout customRenderController], host.customRenderController);
        XCTAssertTrue([layout isEditable]);
        XCTAssertTrue([layout isEditing]);
        XCTAssertTrue(CGPointEqualToPoint([layout textContainerOrigin], CGPointZero));
        UIView *attachmentView = [UIView new];
        CGRect attachmentFrame = CGRectMake(1, 2, 30, 40);
        NSSet<UIView *> *batch = [NSSet setWithObject:attachmentView];
        [layout id_attachmentView:attachmentView
            didLayoutInFragmentFrame:attachmentFrame];
        [layout id_attachmentViewsDidEnterViewport:batch];
        [layout id_attachmentViewsDidLeaveViewport:batch];
        [layout _textKit2CanvasDidLayout];
        [layout _updateInteractionGeometry];
        XCTAssertEqualObjects(host.attachmentViews, (@[attachmentView]));
        XCTAssertTrue(CGRectEqualToRect(host.attachmentFrames.firstObject.CGRectValue,
                                        attachmentFrame));
        XCTAssertEqual(host.enteredAttachmentBatches.firstObject, batch);
        XCTAssertEqual(host.leftAttachmentBatches.firstObject, batch);
        XCTAssertFalse([host.enteredAttachmentBatches.firstObject
            isKindOfClass:NSMutableSet.class]);
        XCTAssertEqual(host.didLayoutCount, 1U);
        XCTAssertEqual(host.interactionGeometryUpdateCount, 1U);
    }
    XCTAssertNil(weakHost);
    XCTAssertNil([layout id_canvasHost]);
    XCTAssertEqualObjects([layout textColor], UIColor.labelColor);
    XCTAssertNil([layout customRenderController]);
    XCTAssertFalse([layout isEditable]);
    XCTAssertFalse([layout isEditing]);
}

- (void)testNegativeUsageOriginExpandsExactExtentAndCompensatesCanvasOrigin {
    NSAttributedString *raised = [[NSAttributedString alloc]
        initWithString:@"raised baseline"
            attributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:17.0],
                NSForegroundColorAttributeName: UIColor.labelColor,
                NSBaselineOffsetAttributeName: @48.0,
            }];
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:@[raised, IDBlockTextTestAttributedString(@"tail")]
               defaultAttributes:IDBlockTextTestAttributes()];
    IDBlockStackCanvasView *stack = [self stackForDocument:document width:180.0];
    IDBlockLayout *first = stack.blockLayouts[0];
    IDBlockLayout *second = stack.blockLayouts[1];

    first.textContainer.lineFragmentPadding = -20.0;
    [stack updateForDocumentChange:nil width:180.0];
    CGRect usage = CGRectStandardize(first.layoutManager.usageBoundsForTextContainer);
    CGFloat minimumX = MIN(CGRectGetMinX(usage), 0);
    CGFloat minimumY = MIN(CGRectGetMinY(usage), 0);
    CGFloat maximumX = MAX(CGRectGetMaxX(usage), 0);
    CGFloat maximumY = MAX(CGRectGetMaxY(usage), 0);
    CGSize expectedSize = CGSizeMake(maximumX - minimumX, maximumY - minimumY);
    CGPoint expectedBoundsOrigin = CGPointMake(minimumX, minimumY);

    XCTAssertLessThan(CGRectGetMinX(usage), 0.0, @"%@", NSStringFromCGRect(usage));
    XCTAssertTrue(CGSizeEqualToSize(first.usedSize, expectedSize),
                  @"usage=%@ used=%@ expected=%@",
                  NSStringFromCGRect(usage),
                  NSStringFromCGSize(first.usedSize),
                  NSStringFromCGSize(expectedSize));
    XCTAssertTrue(CGPointEqualToPoint([first textContainerOrigin], CGPointZero));
    XCTAssertEqual([stack documentOriginForBlockIdentifier:second.blockIdentifier].y,
                   expectedSize.height);
    XCTAssertEqual(CGRectGetHeight(first.canvasView.frame), expectedSize.height);
    XCTAssertTrue(CGPointEqualToPoint(first.canvasView.bounds.origin,
                                     expectedBoundsOrigin));
    CGFloat exactDocumentHeight = expectedSize.height + second.usedSize.height;
    XCTAssertEqual(stack.documentContentSize.height, ceil(exactDocumentHeight));

    CGRect documentUsage = [first.canvasView convertRect:usage toView:stack];
    XCTAssertGreaterThanOrEqual(CGRectGetMinX(documentUsage),
                                CGRectGetMinX(first.canvasView.frame));
    XCTAssertGreaterThanOrEqual(CGRectGetMinY(documentUsage),
                                CGRectGetMinY(first.canvasView.frame));
    XCTAssertLessThanOrEqual(CGRectGetMaxX(documentUsage),
                             CGRectGetMaxX(first.canvasView.frame));
    XCTAssertLessThanOrEqual(CGRectGetMaxY(documentUsage),
                             CGRectGetMaxY(first.canvasView.frame));

    [first.canvasView performViewportLayout];
    IDTextRenderingSurfaceView *surface =
        (IDTextRenderingSurfaceView *)first.canvasView.visibleSurfaces.firstObject;
    XCTAssertNotNil(surface);
    XCTAssertTrue(CGPointEqualToPoint(surface.containerOrigin, CGPointZero));
}

/// A zero-length local range extended only at the HEAD is not an error, and answering it as one
/// took the whole document's selection down with it.
///
/// The coordinator offers every structural separator to BOTH sides: the block before it is asked
/// for a TAIL extension and the block after it for a HEAD extension, under the identical condition
/// that the separator's offset is selected. On a line WITH GLYPHS the head side has nothing to draw
/// — a head extension widens the first segment to the LINE'S LEADING EDGE, which a range starting at
/// the block's offset 0 already sits on — so it comes back zero-width. Reporting that as INEXACT
/// (nil) made `IDDocumentLayoutCoordinator` discard the selection geometry for the entire document,
/// and UIKit then drew no selection at all: the measured symptom was a selection that vanishes
/// whenever one of the selected lines is empty, because every selection that touches an empty line
/// has a boundary on a separator (2026-09-15).
///
/// An EMPTY block is the case where the head side DOES have something: its whole line is the break,
/// so there is no glyph to hug and no line to fill, and it stands the break up as a narrow mark.
/// This contract used to read "no segments rather than no answer" and asserted that for both
/// blocks; the mark is what changed it, and the name said the wrong half of the rule.
- (void)testAHeadOnlyZeroLengthRangeIsABreakMarkOnAnEmptyBlockAndNothingOnAFullOne {
    IDBlockDocument *document = IDBlockTextTestDocument(@[@"", @"abc"]);
    IDBlockLayout *empty = [[IDBlockLayout alloc] initWithBlock:document.blocks[0] width:300.0];
    IDBlockLayout *text = [[IDBlockLayout alloc] initWithBlock:document.blocks[1] width:300.0];

    // An EMPTY block's whole line IS the paragraph break, so a selection reaching it has a break to
    // draw and no glyph to hug: the block stands the break up as a narrow mark. Without one the line
    // the finger was just dragged onto reads as skipped.
    NSArray<IDBlockSelectionSegment *> *emptyHead =
        [empty selectionSegmentsForLocalRange:NSMakeRange(0, 0)
                                   extendHead:YES
                                   extendTail:NO];
    XCTAssertNotNil(emptyHead,
                    @"nil reads as INEXACT and discards the whole document's selection");
    XCTAssertEqual(emptyHead.count, 1U);
    XCTAssertGreaterThan(CGRectGetWidth(emptyHead.firstObject.rect), 0.0);
    XCTAssertLessThan(CGRectGetWidth(emptyHead.firstObject.rect), 300.0,
                      @"a mark stands for a break, so it is about a space wide, not a filled line");
    // It carries the HEAD boundary role, and must: the role records WHICH separator the segment's
    // canonical range covers, and `IDRichSelectionGeometryResultIsValid` refuses a separator-ranged
    // segment without one — which discards the geometry for the whole document. That is a different
    // thing from the logical endpoint (`containsLogicalStart`/`End`), which the mark does not claim
    // and which is settled a level up, in the coordinator.
    XCTAssertTrue((emptyHead.firstObject.boundaryRole & IDBlockSelectionBoundaryRoleHead) != 0);

    // A block WITH text has a glyph line of its own, so the separator above it is the previous
    // block's tail to draw and this block contributes nothing for it.
    NSArray<IDBlockSelectionSegment *> *textHead =
        [text selectionSegmentsForLocalRange:NSMakeRange(0, 0)
                                  extendHead:YES
                                  extendTail:NO];
    XCTAssertNotNil(textHead,
                    @"nil reads as INEXACT and discards the whole document's selection");
    XCTAssertEqual(textHead.count, 0U);

    // THE CONTROL: the tail side of the same separator still answers with its own geometry, so the
    // separator is drawn once rather than not at all.
    NSArray<IDBlockSelectionSegment *> *tail =
        [empty selectionSegmentsForLocalRange:NSMakeRange(0, 0) extendHead:NO extendTail:YES];
    XCTAssertEqual(tail.count, 1U);
    XCTAssertGreaterThan(CGRectGetWidth(tail.firstObject.rect), 0.0);
    XCTAssertTrue((tail.firstObject.boundaryRole & IDBlockSelectionBoundaryRoleTail) != 0);
}
@end
