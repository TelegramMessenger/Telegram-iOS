@import XCTest;

#import <objc/message.h>

#import "IDBlockDocument.h"
#import "IDBlockTextView.h"
#import "IDBlockTextViewInternal.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDInlineTextFormatting.h"
#import "IDInlineTextStyleResolver.h"
#import "IDPrivateUIKit.h"
#import "IDRichTextLayoutControllerInternal.h"

static NSAttributedStringKey const IDFormattingUnrelatedAttribute =
    @"IDFormattingUnrelatedAttribute";

@interface IDInlineTextFormattingControllerTests : XCTestCase
@end

@implementation IDInlineTextFormattingControllerTests

/// A host-supplied BASE FONT is what the trait pass derives from — the mechanism that makes an
/// inline-code run monospaced in a way that survives bolding it.
///
/// This replaces a test written against a host "style contributor" seam that has been removed. That
/// seam decorated attributes on the way to being drawn, which sounded right and was not: the canvas
/// renders each block from `block.attributedText`, so nothing it produced was ever drawn, while the
/// insertion-attributes path DID read it and baked display styling into newly typed runs. The engine
/// already had the right mechanism, and this is it.
- (void)testAHostSuppliedBaseFontIsWhatTraitsDeriveFrom {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha beta"]];
    UIFont *mono = [UIFont monospacedSystemFontOfSize:17.0
                                               weight:UIFontWeightRegular];

    [self setSelection:NSMakeRange(0, 5) inView:view];
    [view transformInlineAttributesUsingBlock:
        ^NSDictionary<NSAttributedStringKey, id> *(
            NSDictionary<NSAttributedStringKey, id> *attributes) {
        NSMutableDictionary *result = [attributes mutableCopy];
        result[IDInlineTextBaseFontAttributeName] = mono;
        result[NSFontAttributeName] = mono;
        return result;
    }];

    [self setSelection:NSMakeRange(0, 5) inView:view];
    [view toggleInlineTextTrait:IDInlineTextTraitBold];

    UIFont *font = [view.attributedBlocks[0] attributesAtIndex:0
                                                effectiveRange:NULL][NSFontAttributeName];
    XCTAssertTrue((font.fontDescriptor.symbolicTraits &
                   UIFontDescriptorTraitBold) != 0,
                  @"bolding a monospaced run must keep it bold");
    NSDictionary *iAttrs = @{NSFontAttributeName: font};
    NSDictionary *wAttrs = @{NSFontAttributeName: font};
    CGFloat iWidth = [@"i" sizeWithAttributes:iAttrs].width;
    CGFloat wWidth = [@"W" sizeWithAttributes:wAttrs].width;
    XCTAssertEqualWithAccuracy(iWidth, wWidth, 0.01,
                               @"bolding a monospaced run must keep it MONOSPACED — the trait pass "
                               @"must derive from the host's base face, not from the body font");
}

#pragma mark - Host attributes (storage counterpart to IDInlineTextStyleContributor)

/// A host attribute is a key the engine does not own — a link URL, an inline-code flag, a spoiler
/// flag. `IDInlineTextStyleContributor` gives a host the PRESENTATION of such a key; this is the
/// other half, the STORAGE. Both are needed: a contributor decorates attributes on their way to
/// being rendered and persists nothing, while writing the document directly would skip the undo
/// registration and the state notification that `toggleTrait:` performs.
- (void)testHostAttributeSetOverASelectionReadsBack {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha beta"]];
    [self setSelection:NSMakeRange(0, 5) inView:view];

    [view setHostAttributeValue:@"https://telegram.org"
                         forKey:IDFormattingUnrelatedAttribute];

    XCTAssertEqualObjects(
        [view hostAttributeValueForKey:IDFormattingUnrelatedAttribute],
        @"https://telegram.org",
        @"a host attribute set over the selection must read back from that selection");
}

- (void)testHostAttributeSetToNilRemovesIt {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha beta"]];
    [self setSelection:NSMakeRange(0, 5) inView:view];
    [view setHostAttributeValue:@"https://telegram.org"
                         forKey:IDFormattingUnrelatedAttribute];

    [self setSelection:NSMakeRange(0, 5) inView:view];
    [view setHostAttributeValue:nil forKey:IDFormattingUnrelatedAttribute];

    XCTAssertNil([view hostAttributeValueForKey:IDFormattingUnrelatedAttribute],
                 @"nil must REMOVE the key, not store a null placeholder");
}

/// A selection spanning two different values has no single answer. Reporting either endpoint's
/// value would be a plausible-looking wrong answer of exactly the shape this project bans.
- (void)testHostAttributeOverAMixedSelectionReadsNil {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha beta"]];
    [self setSelection:NSMakeRange(0, 5) inView:view];
    [view setHostAttributeValue:@"https://telegram.org"
                         forKey:IDFormattingUnrelatedAttribute];

    [self setSelection:NSMakeRange(0, 10) inView:view];

    XCTAssertNil([view hostAttributeValueForKey:IDFormattingUnrelatedAttribute],
                 @"a selection spanning a link and plain text carries no ONE value");
}

/// §2.2's preservation property, now load-bearing: the resolver rewrites the font, underline and
/// foreground channels on every trait toggle but starts from `attributes.mutableCopy` and removes
/// only the four trait keys. A host attribute must therefore survive a toggle — otherwise every
/// link would be dropped the moment the user bolded it.
- (void)testHostAttributeSurvivesATraitToggle {
    IDBlockTextView *view = [self viewWithStrings:@[@"alpha beta"]];
    [self setSelection:NSMakeRange(0, 5) inView:view];
    [view setHostAttributeValue:@"https://telegram.org"
                         forKey:IDFormattingUnrelatedAttribute];

    [self setSelection:NSMakeRange(0, 5) inView:view];
    [view toggleInlineTextTrait:IDInlineTextTraitBold];

    [self setSelection:NSMakeRange(0, 5) inView:view];
    XCTAssertEqualObjects(
        [view hostAttributeValueForKey:IDFormattingUnrelatedAttribute],
        @"https://telegram.org",
        @"bolding a link must not drop the link");
}

- (NSDictionary<NSAttributedStringKey, id> *)baseAttributes {
    return @{
        NSFontAttributeName: [UIFont systemFontOfSize:17.0],
        NSForegroundColorAttributeName: UIColor.labelColor,
    };
}

- (IDBlockTextView *)viewWithBlocks:
    (NSArray<NSAttributedString *> *)blocks {
    IDBlockTextView *view = [[IDBlockTextView alloc]
        initWithFrame:CGRectMake(0, 0, 320, 240)
        attributedBlocks:blocks];
    [view layoutIfNeeded];
    return view;
}

- (IDBlockTextView *)viewWithStrings:(NSArray<NSString *> *)strings {
    NSMutableArray<NSAttributedString *> *blocks =
        [NSMutableArray arrayWithCapacity:strings.count];
    for (NSString *string in strings) {
        [blocks addObject:[[NSAttributedString alloc]
            initWithString:string
                attributes:self.baseAttributes]];
    }
    return [self viewWithBlocks:blocks];
}

- (UIFont *)fontWithTraits:(UIFontDescriptorSymbolicTraits)traits {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    UIFontDescriptor *descriptor =
        [font.fontDescriptor fontDescriptorWithSymbolicTraits:traits];
    XCTAssertNotNil(descriptor);
    return [UIFont fontWithDescriptor:descriptor size:font.pointSize];
}

- (void)setSelection:(NSRange)range inView:(IDBlockTextView *)view {
    UITextPosition *start =
        [view positionFromPosition:view.beginningOfDocument
                           offset:(NSInteger)range.location];
    UITextPosition *end =
        [view positionFromPosition:start
                           offset:(NSInteger)range.length];
    XCTAssertNotNil(start);
    XCTAssertNotNil(end);
    view.selectedTextRange =
        [view textRangeFromPosition:start toPosition:end];
}

- (NSRange)selectionInView:(IDBlockTextView *)view {
    UITextRange *selection = view.selectedTextRange;
    NSInteger location =
        [view offsetFromPosition:view.beginningOfDocument
                      toPosition:selection.start];
    NSInteger length =
        [view offsetFromPosition:selection.start
                      toPosition:selection.end];
    return NSMakeRange((NSUInteger)location, (NSUInteger)length);
}

- (IDInlineTextTraits)semanticTraitsAtIndex:(NSUInteger)index
                                     block:
    (NSUInteger)blockIndex
                                      view:(IDBlockTextView *)view {
    NSDictionary<NSAttributedStringKey, id> *attributes =
        [view.attributedBlocks[blockIndex]
            attributesAtIndex:index effectiveRange:NULL];
    IDInlineTextTraits result = 0;
    if ([attributes[IDInlineTextBoldAttributeName] boolValue])
        result |= IDInlineTextTraitBold;
    if ([attributes[IDInlineTextItalicAttributeName] boolValue])
        result |= IDInlineTextTraitItalic;
    if ([attributes[IDInlineTextUnderlineAttributeName] boolValue])
        result |= IDInlineTextTraitUnderline;
    if ([attributes[IDInlineTextStrikethroughAttributeName] boolValue])
        result |= IDInlineTextTraitStrikethrough;
    return result;
}

- (UITextRange *)performPaste:(NSAttributedString *)attributedString
                       inView:(IDBlockTextView *)view
                        range:(UITextRange *)range {
    id<UITextPasteDelegate> delegate = view.pasteDelegate;
    XCTAssertNotNil(delegate);
    if (delegate == nil) return nil;
    XCTAssertTrue([delegate respondsToSelector:
        @selector(textPasteConfigurationSupporting:
                  combineItemAttributedStrings:forRange:)]);
    if (![delegate respondsToSelector:
        @selector(textPasteConfigurationSupporting:
                  combineItemAttributedStrings:forRange:)]) {
        return nil;
    }
    NSAttributedString *combined = [delegate
        textPasteConfigurationSupporting:view
            combineItemAttributedStrings:@[attributedString]
                                 forRange:range];
    SEL selector =
        NSSelectorFromString(@"_pasteAttributedString:pasteAsRichText:");
    XCTAssertTrue([view.id_inputController respondsToSelector:selector]);
    if (![view.id_inputController respondsToSelector:selector]) return nil;
    ((void (*)(id, SEL, id, BOOL))objc_msgSend)(
        view.id_inputController, selector, combined, YES);
    return view.selectedTextRange;
}

- (void)testAttributedReplacementImportsBoldItalicUnderlineAndStrike {
    IDBlockTextView *view = [self viewWithStrings:@[@"A"]];
    view.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
    [self setSelection:NSMakeRange(1, 0) inView:view];
    UIFont *font = [self fontWithTraits:
        UIFontDescriptorTraitBold | UIFontDescriptorTraitItalic];
    NSAttributedString *replacement = [[NSAttributedString alloc]
        initWithString:@"X"
            attributes:@{
                NSFontAttributeName: font,
                NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
                NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle),
            }];

    UITextRange *result = [self performPaste:replacement
                                      inView:view
                                       range:view.selectedTextRange];

    XCTAssertNotNil(result);
    if (result == nil) return;
    XCTAssertEqualObjects(view.text, @"AX");
    XCTAssertEqual([self semanticTraitsAtIndex:1 block:0 view:view],
                   IDInlineTextTraitBold |
                       IDInlineTextTraitItalic |
                       IDInlineTextTraitUnderline |
                       IDInlineTextTraitStrikethrough);
    XCTAssertTrue(view.undoManager.canUndo);
    [view.undoManager undo];
    XCTAssertEqualObjects(view.text, @"A");
}

- (void)testPlainPasteAtCaretUsesActiveTypingTraits {
    IDBlockTextView *view = [self viewWithStrings:@[@"A"]];
    view.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
    [self setSelection:NSMakeRange(1, 0) inView:view];
    [view toggleInlineTextTrait:IDInlineTextTraitBold];
    NSDictionary<NSAttributedStringKey, id> *typingAttributes =
        IDPrivateInputTypingAttributes(view.id_inputController);

    UITextRange *result = [self performPaste:[[NSAttributedString alloc]
        initWithString:@"X" attributes:typingAttributes]
                                      inView:view
                                       range:view.selectedTextRange];

    XCTAssertNotNil(result);
    if (result == nil) return;
    XCTAssertEqualObjects(view.text, @"AX");
    XCTAssertEqual([self semanticTraitsAtIndex:1 block:0 view:view],
                   IDInlineTextTraitBold);
}

- (void)testTemporarySpellingAndMarkedAttributesNeverBecomeSemanticMarkers {
    IDBlockTextView *view = [self viewWithStrings:@[@"A"]];
    [self setSelection:NSMakeRange(1, 0) inView:view];
    NSAttributedStringKey markedKey = @"NSMarkedClauseSegment";
    NSAttributedStringKey spellingKey = @"NSSpellingState";
    [view setAttributedMarkedText:[[NSAttributedString alloc]
        initWithString:@"X"
            attributes:@{
                NSFontAttributeName:
                    [self fontWithTraits:UIFontDescriptorTraitBold],
                markedKey: @0,
            }]
                  selectedRange:NSMakeRange(1, 0)];
    [view.id_richLayoutController
        id_addRenderingAttributes:@{spellingKey: @1}
                         forRange:view.markedTextRange];

    [view unmarkText];

    NSDictionary<NSAttributedStringKey, id> *attributes =
        [view.attributedBlocks[0] attributesAtIndex:1
                                     effectiveRange:NULL];
    XCTAssertEqual([self semanticTraitsAtIndex:1 block:0 view:view], 0U);
    XCTAssertNil(attributes[markedKey]);
    XCTAssertNil(attributes[spellingKey]);
}

- (void)testCopyExportsStandardPresentationAttributesForInteroperability {
    IDBlockTextView *view = [self viewWithStrings:@[@"A"]];
    [self setSelection:NSMakeRange(0, 1) inView:view];
    [view toggleInlineTextTrait:IDInlineTextTraitBold];
    [view toggleInlineTextTrait:IDInlineTextTraitUnderline];

    NSAttributedString *exported = [view.id_richLayoutController
        id_attributedTextInRange:view.selectedTextRange];
    NSDictionary<NSAttributedStringKey, id> *attributes =
        [exported attributesAtIndex:0 effectiveRange:NULL];
    UIFont *font = attributes[NSFontAttributeName];
    XCTAssertTrue((font.fontDescriptor.symbolicTraits &
                   UIFontDescriptorTraitBold) != 0);
    XCTAssertEqual([attributes[NSUnderlineStyleAttributeName] integerValue],
                   NSUnderlineStyleSingle);
}

- (void)testSingleBlockToggleAddsAndRemovesBold {
    IDBlockTextView *view = [self viewWithStrings:@[@"abc"]];
    [self setSelection:NSMakeRange(0, 3) inView:view];

    [view toggleInlineTextTrait:IDInlineTextTraitBold];

    XCTAssertEqual([view stateForInlineTextTrait:IDInlineTextTraitBold],
                   IDInlineTextTraitStateOn);
    for (NSUInteger index = 0; index < 3; index += 1) {
        XCTAssertTrue(([self semanticTraitsAtIndex:index
                                            block:0
                                             view:view] &
                       IDInlineTextTraitBold) != 0);
    }

    [view toggleInlineTextTrait:IDInlineTextTraitBold];

    XCTAssertEqual([view stateForInlineTextTrait:IDInlineTextTraitBold],
                   IDInlineTextTraitStateOff);
    for (NSUInteger index = 0; index < 3; index += 1) {
        XCTAssertEqual([self semanticTraitsAtIndex:index
                                            block:0
                                             view:view] &
                           IDInlineTextTraitBold,
                       0U);
    }
}

- (void)testMixedSelectionUsesOneGlobalAddDirection {
    UIFont *font = [UIFont systemFontOfSize:17.0];
    UIFontDescriptor *boldDescriptor =
        [font.fontDescriptor
            fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    NSMutableAttributedString *text =
        [[NSMutableAttributedString alloc]
            initWithString:@"AB"
                attributes:self.baseAttributes];
    [text addAttribute:NSFontAttributeName
                 value:[UIFont fontWithDescriptor:boldDescriptor size:17.0]
                 range:NSMakeRange(0, 1)];
    IDBlockTextView *view = [self viewWithBlocks:@[text]];
    [self setSelection:NSMakeRange(0, 2) inView:view];
    XCTAssertEqual([view stateForInlineTextTrait:IDInlineTextTraitBold],
                   IDInlineTextTraitStateMixed);

    [view toggleInlineTextTrait:IDInlineTextTraitBold];

    XCTAssertEqual([view stateForInlineTextTrait:IDInlineTextTraitBold],
                   IDInlineTextTraitStateOn);
    XCTAssertTrue(([self semanticTraitsAtIndex:0 block:0 view:view] &
                   IDInlineTextTraitBold) != 0);
    XCTAssertTrue(([self semanticTraitsAtIndex:1 block:0 view:view] &
                   IDInlineTextTraitBold) != 0);
}

- (void)testCrossBlockSelectionFormatsTextOnBothSidesButNotSeparator {
    IDBlockTextView *view = [self viewWithStrings:@[@"ab", @"cd"]];
    [self setSelection:NSMakeRange(1, 3) inView:view];

    [view toggleInlineTextTrait:IDInlineTextTraitUnderline];

    XCTAssertTrue(([self semanticTraitsAtIndex:1 block:0 view:view] &
                   IDInlineTextTraitUnderline) != 0);
    XCTAssertTrue(([self semanticTraitsAtIndex:0 block:1 view:view] &
                   IDInlineTextTraitUnderline) != 0);
    XCTAssertNil([view.id_textStorageAdapter
        attribute:IDInlineTextUnderlineAttributeName
          atIndex:2
   effectiveRange:NULL]);
}

- (void)testFourTraitsComposeIndependently {
    IDBlockTextView *view = [self viewWithStrings:@[@"A"]];
    [self setSelection:NSMakeRange(0, 1) inView:view];
    IDInlineTextTraits allTraits =
        IDInlineTextTraitBold |
        IDInlineTextTraitItalic |
        IDInlineTextTraitUnderline |
        IDInlineTextTraitStrikethrough;

    [view toggleInlineTextTrait:IDInlineTextTraitBold];
    [view toggleInlineTextTrait:IDInlineTextTraitItalic];
    [view toggleInlineTextTrait:IDInlineTextTraitUnderline];
    [view toggleInlineTextTrait:IDInlineTextTraitStrikethrough];

    XCTAssertEqual([self semanticTraitsAtIndex:0 block:0 view:view],
                   allTraits);
    [view toggleInlineTextTrait:IDInlineTextTraitUnderline];
    XCTAssertEqual([self semanticTraitsAtIndex:0 block:0 view:view],
                   allTraits & ~IDInlineTextTraitUnderline);
}

- (void)testFormattingPreservesSelectionIdentifiersAndUnrelatedAttributes {
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName: [UIFont systemFontOfSize:17.0],
        NSForegroundColorAttributeName: UIColor.systemOrangeColor,
        IDFormattingUnrelatedAttribute: @"preserved",
    };
    IDBlockTextView *view = [self viewWithBlocks:@[
        [[NSAttributedString alloc] initWithString:@"ab"
                                        attributes:attributes],
        [[NSAttributedString alloc] initWithString:@"cd"
                                        attributes:attributes],
    ]];
    [self setSelection:NSMakeRange(1, 3) inView:view];
    NSArray<NSUUID *> *identifiers =
        [view.id_document.blocks valueForKey:@"identifier"];

    [view toggleInlineTextTrait:IDInlineTextTraitItalic];

    XCTAssertTrue(NSEqualRanges([self selectionInView:view],
                               NSMakeRange(1, 3)));
    XCTAssertEqualObjects(
        [view.id_document.blocks valueForKey:@"identifier"],
        identifiers);
    for (NSAttributedString *block in view.attributedBlocks) {
        XCTAssertEqualObjects(
            [block attribute:IDFormattingUnrelatedAttribute
                     atIndex:0
              effectiveRange:NULL],
            @"preserved");
        XCTAssertEqualObjects(
            [block attribute:NSForegroundColorAttributeName
                     atIndex:0
              effectiveRange:NULL],
            UIColor.systemOrangeColor);
    }
}

- (void)testChangingViewFontRematerializesBoldAndItalicFromSemanticTraits {
    IDBlockTextView *view = [self viewWithStrings:@[@"A"]];
    [self setSelection:NSMakeRange(0, 1) inView:view];
    [view toggleInlineTextTrait:IDInlineTextTraitBold];
    [view toggleInlineTextTrait:IDInlineTextTraitItalic];

    view.font = [UIFont systemFontOfSize:24.0];

    NSDictionary<NSAttributedStringKey, id> *attributes =
        [view.attributedBlocks[0] attributesAtIndex:0
                                     effectiveRange:NULL];
    UIFont *font = attributes[NSFontAttributeName];
    XCTAssertEqualWithAccuracy(font.pointSize, 24.0, 0.01);
    XCTAssertEqual(font.fontDescriptor.symbolicTraits &
                       (UIFontDescriptorTraitBold |
                        UIFontDescriptorTraitItalic),
                   UIFontDescriptorTraitBold |
                       UIFontDescriptorTraitItalic);
    XCTAssertEqual([self semanticTraitsAtIndex:0 block:0 view:view],
                   IDInlineTextTraitBold | IDInlineTextTraitItalic);
}

- (void)testRangeFormattingRegistersExactlyOneUndoAndRedoStep {
    IDBlockTextView *view = [self viewWithStrings:@[@"ab", @"cd"]];
    [self setSelection:NSMakeRange(1, 3) inView:view];
    NSArray<NSAttributedString *> *beforeBlocks = view.attributedBlocks;
    NSArray<NSUUID *> *identifiers =
        [view.id_document.blocks valueForKey:@"identifier"];
    NSRange beforeSelection = [self selectionInView:view];

    [view toggleInlineTextTrait:IDInlineTextTraitBold];
    NSArray<NSAttributedString *> *afterBlocks = view.attributedBlocks;
    XCTAssertTrue(view.undoManager.canUndo);

    [view.undoManager undo];

    XCTAssertEqualObjects(view.attributedBlocks, beforeBlocks);
    XCTAssertEqualObjects(
        [view.id_document.blocks valueForKey:@"identifier"],
        identifiers);
    XCTAssertTrue(NSEqualRanges([self selectionInView:view],
                               beforeSelection));
    XCTAssertFalse(view.undoManager.canUndo);
    XCTAssertTrue(view.undoManager.canRedo);

    [view.undoManager redo];

    XCTAssertEqualObjects(view.attributedBlocks, afterBlocks);
    XCTAssertTrue(NSEqualRanges([self selectionInView:view],
                               beforeSelection));
    XCTAssertTrue(view.undoManager.canUndo);
    XCTAssertFalse(view.undoManager.canRedo);
}

- (void)testFormattingStateCallbackFiresOncePerCommittedCommand {
    IDBlockTextView *view = [self viewWithStrings:@[@"abc"]];
    [self setSelection:NSMakeRange(0, 3) inView:view];
    __block NSUInteger callbackCount = 0;
    view.inlineTextTraitStateDidChangeHandler = ^{
        callbackCount += 1;
    };

    [view toggleInlineTextTrait:IDInlineTextTraitBold];
    XCTAssertEqual(callbackCount, 1U);
    [view toggleInlineTextTrait:IDInlineTextTraitBold];
    XCTAssertEqual(callbackCount, 2U);
}

- (void)testInvalidCombinedTraitArgumentRaisesInvalidArgument {
    IDBlockTextView *view = [self viewWithStrings:@[@"abc"]];
    [self setSelection:NSMakeRange(0, 3) inView:view];
    IDInlineTextTraits combined =
        IDInlineTextTraitBold | IDInlineTextTraitItalic;

    XCTAssertThrowsSpecificNamed(
        [view toggleInlineTextTrait:combined],
        NSException,
        NSInvalidArgumentException);
    XCTAssertThrowsSpecificNamed(
        [view stateForInlineTextTrait:combined],
        NSException,
        NSInvalidArgumentException);
}

- (void)testCaretToggleChangesStateWithoutMutatingDocumentOrUndoStack {
    IDBlockTextView *view = [self viewWithStrings:@[@"A"]];
    [self setSelection:NSMakeRange(1, 0) inView:view];
    NSArray<NSAttributedString *> *beforeBlocks = view.attributedBlocks;
    NSUInteger beforeRevision = view.id_document.documentRevision;
    BOOL couldUndo = view.undoManager.canUndo;

    [view toggleInlineTextTrait:IDInlineTextTraitBold];

    XCTAssertEqual(view.effectiveInlineTextTraits,
                   IDInlineTextTraitBold);
    XCTAssertEqualObjects(view.attributedBlocks, beforeBlocks);
    XCTAssertEqual(view.id_document.documentRevision, beforeRevision);
    XCTAssertEqual(view.undoManager.canUndo, couldUndo);
}

- (void)testInputControllerOwnsSemanticTypingAttributesAndAllowsTheirKeys {
    IDBlockTextView *view = [self viewWithStrings:@[@"A"]];
    NSSet<NSAttributedStringKey> *allowed =
        IDPrivateObject0(view.id_inputController,
                         NSSelectorFromString(@"_allowedTypingAttributes"));

    XCTAssertTrue([allowed containsObject:IDInlineTextBoldAttributeName]);
    XCTAssertTrue([allowed containsObject:IDInlineTextItalicAttributeName]);
    XCTAssertTrue([allowed containsObject:IDInlineTextUnderlineAttributeName]);
    XCTAssertTrue(
        [allowed containsObject:IDInlineTextStrikethroughAttributeName]);

    [self setSelection:NSMakeRange(1, 0) inView:view];
    [view toggleInlineTextTrait:IDInlineTextTraitBold];

    NSDictionary<NSAttributedStringKey, id> *typingAttributes =
        IDPrivateObject0(view.id_inputController,
                         NSSelectorFromString(@"typingAttributes"));
    XCTAssertTrue([typingAttributes[IDInlineTextBoldAttributeName] boolValue]);
}

- (void)testFirstCaretToggleCapturesAllContextualTraits {
    NSDictionary<NSAttributedStringKey, id> *attributes = @{
        NSFontAttributeName:
            [self fontWithTraits:UIFontDescriptorTraitItalic],
        NSForegroundColorAttributeName: UIColor.labelColor,
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle),
    };
    IDBlockTextView *view = [self viewWithBlocks:@[
        [[NSAttributedString alloc] initWithString:@"A"
                                        attributes:attributes],
    ]];
    [self setSelection:NSMakeRange(1, 0) inView:view];

    [view toggleInlineTextTrait:IDInlineTextTraitBold];

    XCTAssertEqual(view.effectiveInlineTextTraits,
                   IDInlineTextTraitBold |
                       IDInlineTextTraitItalic |
                       IDInlineTextTraitUnderline);
}

- (void)testCaretToggleThenInsertAppliesSemanticAndPresentationAttributes {
    IDBlockTextView *view = [self viewWithStrings:@[@"A"]];
    [self setSelection:NSMakeRange(1, 0) inView:view];
    [view toggleInlineTextTrait:IDInlineTextTraitBold];

    [view insertText:@"X"];

    XCTAssertEqualObjects(view.text, @"AX");
    XCTAssertTrue(([self semanticTraitsAtIndex:1 block:0 view:view] &
                   IDInlineTextTraitBold) != 0);
    UIFont *font = [view.attributedBlocks[0]
        attribute:NSFontAttributeName
          atIndex:1
   effectiveRange:NULL];
    XCTAssertTrue((font.fontDescriptor.symbolicTraits &
                   UIFontDescriptorTraitBold) != 0);
}

- (void)testMultipleCaretTraitsApplyToOneInsertion {
    IDBlockTextView *view = [self viewWithStrings:@[@"A"]];
    [self setSelection:NSMakeRange(1, 0) inView:view];
    [view toggleInlineTextTrait:IDInlineTextTraitBold];
    [view toggleInlineTextTrait:IDInlineTextTraitUnderline];

    [view insertText:@"X"];

    XCTAssertEqual([self semanticTraitsAtIndex:1 block:0 view:view],
                   IDInlineTextTraitBold |
                       IDInlineTextTraitUnderline);
}

- (void)testReturnKeepsTypingTraitsButSeparatorHasNoTraits {
    IDBlockTextView *view = [self viewWithStrings:@[@"A"]];
    [self setSelection:NSMakeRange(1, 0) inView:view];
    [view toggleInlineTextTrait:IDInlineTextTraitBold];

    [view insertText:@"\nX"];

    XCTAssertEqualObjects(view.text, @"A\nX");
    XCTAssertEqual(view.attributedBlocks.count, 2U);
    XCTAssertNil([view.id_textStorageAdapter
        attribute:IDInlineTextBoldAttributeName
          atIndex:1
   effectiveRange:NULL]);
    XCTAssertTrue(([self semanticTraitsAtIndex:0 block:1 view:view] &
                   IDInlineTextTraitBold) != 0);
    XCTAssertEqual(view.effectiveInlineTextTraits,
                   IDInlineTextTraitBold);
}

- (void)testSeparateReturnPreservesExplicitTypingTraitsAtDocumentEnd {
    IDBlockTextView *view = [self viewWithStrings:@[@"A"]];
    [self setSelection:NSMakeRange(1, 0) inView:view];
    [view toggleInlineTextTrait:IDInlineTextTraitBold];

    [view insertText:@"\n"];

    XCTAssertEqual(view.effectiveInlineTextTraits,
                   IDInlineTextTraitBold);
    [view insertText:@"X"];
    XCTAssertEqualObjects(view.text, @"A\nX");
    XCTAssertTrue(([self semanticTraitsAtIndex:0 block:1 view:view] &
                   IDInlineTextTraitBold) != 0);
}

- (void)testExplicitSelectionMovementClearsOverrideAndDerivesNewContext {
    NSMutableAttributedString *text =
        [[NSMutableAttributedString alloc]
            initWithString:@"AB"
                attributes:self.baseAttributes];
    [text addAttribute:NSFontAttributeName
                 value:[self fontWithTraits:UIFontDescriptorTraitBold]
                 range:NSMakeRange(0, 1)];
    [text addAttribute:NSFontAttributeName
                 value:[self fontWithTraits:UIFontDescriptorTraitItalic]
                 range:NSMakeRange(1, 1)];
    IDBlockTextView *view = [self viewWithBlocks:@[text]];
    [self setSelection:NSMakeRange(1, 0) inView:view];
    [view toggleInlineTextTrait:IDInlineTextTraitUnderline];
    XCTAssertEqual(view.effectiveInlineTextTraits,
                   IDInlineTextTraitBold |
                       IDInlineTextTraitUnderline);

    [self setSelection:NSMakeRange(2, 0) inView:view];

    XCTAssertEqual(view.effectiveInlineTextTraits,
                   IDInlineTextTraitItalic);
}

- (void)testTypingAdvancePreservesExplicitOverride {
    IDBlockTextView *view = [self viewWithStrings:@[@"A"]];
    [self setSelection:NSMakeRange(1, 0) inView:view];
    [view toggleInlineTextTrait:IDInlineTextTraitStrikethrough];

    [view insertText:@"X"];

    XCTAssertTrue(NSEqualRanges([self selectionInView:view],
                               NSMakeRange(2, 0)));
    XCTAssertEqual(view.effectiveInlineTextTraits,
                   IDInlineTextTraitStrikethrough);
}

- (void)testDeletionAndUndoReconcileToStockTruthTable {
    NSMutableAttributedString *text =
        [[NSMutableAttributedString alloc]
            initWithString:@"AB"
                attributes:self.baseAttributes];
    [text addAttribute:NSFontAttributeName
                 value:[self fontWithTraits:UIFontDescriptorTraitBold]
                 range:NSMakeRange(0, 1)];
    [text addAttribute:NSFontAttributeName
                 value:[self fontWithTraits:UIFontDescriptorTraitItalic]
                 range:NSMakeRange(1, 1)];
    IDBlockTextView *view = [self viewWithBlocks:@[text]];
    [self setSelection:NSMakeRange(1, 0) inView:view];
    XCTAssertEqual(view.effectiveInlineTextTraits,
                   IDInlineTextTraitBold);

    [view deleteBackward];

    XCTAssertEqualObjects(view.text, @"B");
    XCTAssertEqual(view.effectiveInlineTextTraits,
                   IDInlineTextTraitItalic);
    [view.undoManager undo];
    XCTAssertEqualObjects(view.text, @"AB");
    NSRange restoredSelection = [self selectionInView:view];
    XCTAssertTrue(NSEqualRanges(restoredSelection, NSMakeRange(0, 1)),
                  @"actual %@",
                  NSStringFromRange(restoredSelection));
    XCTAssertEqual(view.effectiveInlineTextTraits,
                   IDInlineTextTraitBold);
}

@end
