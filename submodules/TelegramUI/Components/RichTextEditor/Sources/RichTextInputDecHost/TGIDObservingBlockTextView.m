#import "TGIDEngineObservation.h"

#if TARGET_OS_IOS

#import "IDBlockDocument.h"
#import "IDBlockStackCanvasView.h"   // `documentContentSize`, for the content-height floor below
#import "IDBlockStackCanvasViewInternal.h"   // the empty-line provider's answer, by identity
#import "IDBlockTextViewInternal.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDCanonicalTextStorageAdapterInternal.h"
#import "IDInlineTextStyleResolver.h"
#import "IDUIKitInputControllerCapability.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "TGPrivateRuntimeNames.h"
#import "TGPrivateMethodAliases.h"

/// UIKit's private input-delegate callback, implemented by the engine's `+PrivateInputDelegate`
/// category; declared here so the override above can call `super`.
@interface IDBlockTextView (TGIDPrivateInputDelegateForwarding)
- (void)tgpn_textInputDidChange:(id)input;
@end


/// UIKit's tap-to-caret boundary snap, implemented by `UIResponder` and declared in no header.
/// Called from exactly ONE place in UIKitCore —
/// `-[_UIKeyboardTextSelectionController selectPositionAtPoint:granularity:completionHandler:]` —
/// which is the tap that places a caret; nothing else in the framework references it. Declared here
/// so the override below can call `super` for the granularities it does not intercept.


/// The engine's line tokenizer, with the one answer it gets wrong corrected: the LINE at a position
/// that ends a block (just before a block separator, or at the end of the document).
///
/// UIKit's `_UITextInputControllerTokenizer` answers such a position as a line of its own, empty and
/// starting there (`rangeEnclosingPosition:` → `p..p`, backward boundary → `p`), where a stock
/// `UITextView` with the same text answers the line the position ends. So ⌘← / ⇧⌘← at the end of a
/// paragraph — the usual place, right after typing it — did nothing (composer harness, 2026-09-24,
/// `HarnessLineStartKeyTests`: caret 28 stayed 28, stock 0; at the end of the text 41 stayed 41, stock
/// 29). Mid-line answers were already right.
///
/// The correction applies only where the engine's answer is that degenerate `p..p` AND the line the
/// position before it lies on ends exactly at `p` — i.e. `p` is the end of a non-empty line. A
/// genuinely empty line (an empty paragraph) keeps `p..p`, because the position before it ends a
/// DIFFERENT line (its own degenerate answer does not reach `p`). Everything else is the engine's.
@interface TGIDLineEndCorrectingTokenizer : NSObject <UITextInputTokenizer>
- (instancetype)initWithTokenizer:(id<UITextInputTokenizer>)tokenizer input:(id<UITextInput>)input;
@property(nonatomic, strong, readonly) id<UITextInputTokenizer> tgid_inner;
@end

@implementation TGIDLineEndCorrectingTokenizer {
    __weak id<UITextInput> _input;
}

- (instancetype)initWithTokenizer:(id<UITextInputTokenizer>)tokenizer input:(id<UITextInput>)input {
    self = [super init];
    if (self != nil) {
        _tgid_inner = tokenizer;
        _input = input;
    }
    return self;
}

/// The line `position` ENDS, when the engine answered it as an empty line of its own; nil otherwise.
- (nullable UITextRange *)tgid_lineEndedAt:(UITextPosition *)position {
    id<UITextInput> input = _input;
    if (input == nil || position == nil) {
        return nil;
    }
    UITextDirection backward = (UITextDirection)UITextStorageDirectionBackward;
    UITextRange *own = [_tgid_inner rangeEnclosingPosition:position withGranularity:UITextGranularityLine inDirection:backward];
    if (own != nil && !own.isEmpty) {
        return nil;
    }
    if (own != nil && [input comparePosition:own.start toPosition:position] != NSOrderedSame) {
        return nil;
    }
    UITextPosition *previous = [input positionFromPosition:position offset:-1];
    if (previous == nil) {
        return nil;
    }
    UITextRange *line = [_tgid_inner rangeEnclosingPosition:previous withGranularity:UITextGranularityLine inDirection:backward];
    if (line == nil || line.isEmpty || [input comparePosition:line.end toPosition:position] != NSOrderedSame) {
        return nil;
    }
    return line;
}

static BOOL TGIDDirectionIsBackward(UITextDirection direction) {
    return direction == (UITextDirection)UITextStorageDirectionBackward
        || direction == (UITextDirection)UITextLayoutDirectionLeft
        || direction == (UITextDirection)UITextLayoutDirectionUp;
}

- (nullable UITextRange *)rangeEnclosingPosition:(UITextPosition *)position
                                 withGranularity:(UITextGranularity)granularity
                                     inDirection:(UITextDirection)direction {
    if (granularity == UITextGranularityLine) {
        UITextRange *line = [self tgid_lineEndedAt:position];
        if (line != nil) {
            return line;
        }
    }
    return [_tgid_inner rangeEnclosingPosition:position withGranularity:granularity inDirection:direction];
}

- (BOOL)isPosition:(UITextPosition *)position
        atBoundary:(UITextGranularity)granularity
       inDirection:(UITextDirection)direction {
    if (granularity == UITextGranularityLine) {
        UITextRange *line = [self tgid_lineEndedAt:position];
        if (line != nil) {
            // The position is the line's END: a boundary going forward, not going backward.
            return !TGIDDirectionIsBackward(direction);
        }
    }
    return [_tgid_inner isPosition:position atBoundary:granularity inDirection:direction];
}

- (nullable UITextPosition *)positionFromPosition:(UITextPosition *)position
                                       toBoundary:(UITextGranularity)granularity
                                      inDirection:(UITextDirection)direction {
    if (granularity == UITextGranularityLine && TGIDDirectionIsBackward(direction)) {
        UITextRange *line = [self tgid_lineEndedAt:position];
        if (line != nil) {
            return line.start;
        }
    }
    return [_tgid_inner positionFromPosition:position toBoundary:granularity inDirection:direction];
}

- (BOOL)isPosition:(UITextPosition *)position
    withinTextUnit:(UITextGranularity)granularity
       inDirection:(UITextDirection)direction {
    if (granularity == UITextGranularityLine && TGIDDirectionIsBackward(direction) && [self tgid_lineEndedAt:position] != nil) {
        return YES;
    }
    return [_tgid_inner isPosition:position withinTextUnit:granularity inDirection:direction];
}

/// Anything UIKit asks the tokenizer beyond the protocol goes to the engine's own.
- (id)forwardingTargetForSelector:(SEL)selector {
    return [_tgid_inner respondsToSelector:selector] ? _tgid_inner : nil;
}

- (BOOL)respondsToSelector:(SEL)selector {
    return [super respondsToSelector:selector] || [_tgid_inner respondsToSelector:selector];
}

@end


/// The engine view is its own `UITextPasteDelegate` and implements the combine step
/// (`IDBlockTextView+TextInput.m`), without declaring it in a header; declared here so the host can
/// refine what the engine's own paste inserts.
@interface IDBlockTextView (TGIDPasteCombining)
- (NSAttributedString *)textPasteConfigurationSupporting:
    (id<UITextPasteConfigurationSupporting>)supporting
    combineItemAttributedStrings:(NSArray<NSAttributedString *> *)itemStrings
                       forRange:(UITextRange *)textRange;
@end

@interface TGIDObservingBlockTextView ()
@property(nonatomic, strong, nullable) TGIDLineEndCorrectingTokenizer *tgid_lineEndCorrectingTokenizer;
@property(nonatomic, readwrite) BOOL tgid_isResolvingCompositionSelection;
/// What `tgid_noteCompositionTypingAttributesOfSelection` recorded during the current resolution.
@property(nonatomic, copy, nullable) NSDictionary<NSAttributedStringKey, id> *tgid_resolvedCompositionTypingAttributes;
@property(nonatomic) BOOL tgid_didInitializePrimaryInputLanguage;
/// `tgid_indexOfBlockIdentifier:`'s cache and the `blocks` array it describes (retained, so its
/// pointer cannot be reused by a later array while the map is held).
@property(nonatomic, strong) NSArray<IDBlock *> *tgid_identifierIndexBlocks;
@property(nonatomic, strong) NSDictionary<NSUUID *, NSNumber *> *tgid_identifierIndex;
/// Each block's first canonical position, built in the same pass as `tgid_identifierIndex` and
/// valid for the same `blocks` array.
@property(nonatomic, strong) NSDictionary<NSUUID *, NSNumber *> *tgid_identifierCanonicalStart;
@end


@implementation TGIDObservingBlockTextView

// This class's own callbacks UIKit sends under private names, compiled under neutral `tgpn_` names
// and added under the private ones (`TGPrivateMethodAliases.h`), after the engine's: an override of
// one of the engine's `tgpn_` callbacks (`tgpn_textInputDidChange:`) is installed for this class too.
// Not guarded to this class, for the same reason as `+[IDBlockTextView initialize]`.
+ (void)initialize {
    IDBlockTextViewInstallPrivateCallbacks(self);
    const TGPrivateMethodAlias aliases[] = {
        { TGPN_textInputDidChange_, @selector(tgpn_textInputDidChange:) },
        { TGPN__accessibilitySelectedTextRange, @selector(tgpn__accessibilitySelectedTextRange) },
        { TGPN__accessibilitySetSelectedTextRange_, @selector(tgpn__accessibilitySetSelectedTextRange:) },
        { TGPN__findBoundaryPositionClosestToPosition_withGranularity_, @selector(tgpn__findBoundaryPositionClosestToPosition:withGranularity:) },
        { TGPN_replaceRange_withAnnotatedString_relativeReplacementRange_, @selector(tgpn_replaceRange:withAnnotatedString:relativeReplacementRange:) },
        { TGPN_addTextAlternativesDisplayStyle_toRange_, @selector(tgpn_addTextAlternativesDisplayStyle:toRange:) },
        { TGPN_rangeWithTextAlternatives_atPosition_, @selector(tgpn_rangeWithTextAlternatives:atPosition:) },
        { TGPN_annotatedSubstringForRange_, @selector(tgpn_annotatedSubstringForRange:) },
        { TGPN_removeAllTextAlternatives, @selector(tgpn_removeAllTextAlternatives) },
        { TGPN_removeAlternativesForCurrentWord, @selector(tgpn_removeAlternativesForCurrentWord) },
        { TGPN_removeEmojiAlternatives, @selector(tgpn_removeEmojiAlternatives) },
    };
    TGPrivateInstallMethodAliases(self, aliases, sizeof(aliases) / sizeof(aliases[0]));
}

/// UIKit asks the view itself for edit-menu contents (see the header). Forwards to the host, and
/// falls back to the system's own actions when no provider is installed, so the menu can never end
/// up EMPTY because a host forgot to configure one.
- (UIMenu *)editMenuForTextRange:(UITextRange *)range
                suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions {
    NSArray<UIMenuElement *> *(^provider)(NSArray<UIMenuElement *> *) =
        self.tgid_editMenuElementsProvider;
    if (provider == nil) {
        return [UIMenu menuWithChildren:suggestedActions];
    }
    return [UIMenu menuWithChildren:provider(suggestedActions)];
}


- (instancetype)initWithFrame:(CGRect)frame
             attributedBlocks:(NSArray<NSAttributedString *> *)blocks {
    self = [super initWithFrame:frame attributedBlocks:blocks];
    if (self != nil) {
        [self tgid_installDocumentChangeObserver];
    }
    return self;
}

/// CHAINS the engine's own handler rather than replacing it. The engine assigns it during init
/// (IDBlockTextView.m:328) and its work — reconciling derived state, notifying the inline
/// formatting controller — is load-bearing. Ours runs strictly AFTER.
- (void)tgid_installDocumentChangeObserver {
    IDCanonicalTextStorageAdapter *adapter = self.id_textStorageAdapter;
    // NOT an early return. A nil adapter means the engine finished `-initWithFrame:
    // attributedBlocks:` without its text-storage adapter, and every observation this class exists
    // to provide would then be silently absent — `observationSink` would simply never be called,
    // which reads from the outside exactly like "the document never changed". R1's guarantee is
    // that the host observes EVERY engine mutation; a condition that voids it must be loud.
    NSAssert(adapter != nil,
             @"TGIDObservingBlockTextView: the engine has no text-storage adapter, so no document "
             @"change observer can be installed and R1's observation guarantee is void.");
    if (adapter == nil) {
        return;
    }
    void (^engineHandler)(IDBlockDocumentChange *) = adapter.documentChangeHandler;
    __weak TGIDObservingBlockTextView *weakSelf = self;
    adapter.documentChangeHandler = ^(IDBlockDocumentChange *change) {
        if (engineHandler != nil) {
            engineHandler(change);
        }
        TGIDObservingBlockTextView *strongSelf = weakSelf;
        [strongSelf.observationSink
            engineDidChangeDocumentWithReplacedRange:change.replacedCanonicalRange
                                   replacementLength:change.replacementLength
                                   charactersChanged:change.charactersChanged];
    };
}

/// Reads `IDBlockDocument.blocks` and returns each block's own `identifier`, nothing more — see
/// the property's doc comment in TGIDEngineObservation.h for why the host cannot derive this
/// itself. A nil `id_document` (an engine torn down by `id_tearDownEditorGraph`) yields an empty
/// array, which is the honest answer: there are no blocks to identify.
- (NSArray<NSUUID *> *)tgid_blockIdentifiers {
    NSArray<IDBlock *> *blocks = self.id_document.blocks;
    NSMutableArray<NSUUID *> *identifiers = [NSMutableArray arrayWithCapacity:blocks.count];
    for (IDBlock *block in blocks) {
        [identifiers addObject:block.identifier];
    }
    return identifiers;
}

/// Rebuilds `tgid_identifierIndex` and `tgid_identifierCanonicalStart` when `blocks` is not the
/// array they were built from.
- (void)tgid_refreshIdentifierMaps {
    NSArray<IDBlock *> *blocks = self.id_document.blocks;
    if (blocks == self.tgid_identifierIndexBlocks && self.tgid_identifierIndex != nil
        && self.tgid_identifierCanonicalStart != nil) {
        return;
    }
    NSMutableDictionary<NSUUID *, NSNumber *> *index =
        [NSMutableDictionary dictionaryWithCapacity:blocks.count];
    NSMutableDictionary<NSUUID *, NSNumber *> *starts =
        [NSMutableDictionary dictionaryWithCapacity:blocks.count];
    __block NSUInteger start = 0;
    [blocks enumerateObjectsUsingBlock:^(IDBlock *block, NSUInteger position, BOOL *stop) {
        if (index[block.identifier] == nil) {   // the FIRST occurrence, as `firstIndex(of:)`
            index[block.identifier] = @(position);
            starts[block.identifier] = @(start);
        }
        start += block.attributedText.length + 1;
    }];
    self.tgid_identifierIndexBlocks = blocks;
    self.tgid_identifierIndex = index;
    self.tgid_identifierCanonicalStart = starts;
}

- (NSInteger)tgid_indexOfBlockIdentifier:(NSUUID *)identifier {
    [self tgid_refreshIdentifierMaps];
    NSNumber *position = self.tgid_identifierIndex[identifier];
    return position != nil ? position.integerValue : NSNotFound;
}

- (NSInteger)tgid_canonicalStartOfBlockIdentifier:(NSUUID *)identifier {
    [self tgid_refreshIdentifierMaps];
    NSNumber *start = self.tgid_identifierCanonicalStart[identifier];
    return start != nil ? start.integerValue : NSNotFound;
}

/// Single-shot pre-selection: the first query consumes it and thereafter reports the live keyboard,
/// which is the value the host reads back as the current input language. See the header for the
/// ordering invariant this depends on.
- (UITextInputMode *)textInputMode {
    if (!self.tgid_didInitializePrimaryInputLanguage) {
        self.tgid_didInitializePrimaryInputLanguage = YES;
        NSString *desired = self.tgid_initialPrimaryLanguage;
        if (desired.length != 0) {
            for (UITextInputMode *mode in UITextInputMode.activeInputModes) {
                if (mode.primaryLanguage != nil &&
                    [mode.primaryLanguage isEqualToString:desired]) {
                    return mode;
                }
            }
        }
    }
    return [super textInputMode];
}

- (void)tgid_resetInitialPrimaryLanguage {
    self.tgid_didInitializePrimaryInputLanguage = NO;
}

- (void)id_selectionStateDidChange {
    [super id_selectionStateDidChange];
    [self.observationSink engineDidChangeSelection];
}

/// After the engine's whole pass — the block stack placed, the content size set, the interaction
/// geometry refreshed — so the host reads the geometry the screen is about to show.
/// The responder transitions, reported on a REAL change only — `wasFirstResponder` is captured
/// before `super`, the way `IDBlockTextView`'s own overrides above do it, so a tap inside an
/// already-focused editor reports nothing. Notifying unconditionally would report focus the editor
/// already had, which is the same class of untruth as reporting focus it does not have.
- (BOOL)becomeFirstResponder {
    BOOL wasFirstResponder = self.isFirstResponder;
    BOOL became = [super becomeFirstResponder];
    if (became && !wasFirstResponder) {
        [self.observationSink engineDidBecomeFirstResponder];
    }
    return became;
}

- (BOOL)resignFirstResponder {
    BOOL wasFirstResponder = self.isFirstResponder;
    BOOL resigned = [super resignFirstResponder];
    if (resigned && wasFirstResponder) {
        [self.observationSink engineDidResignFirstResponder];
    }
    return resigned;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self.observationSink engineDidLayout];
}

/// The content of this scroll view is the DOCUMENT, floored to fill the **visible** area — the part
/// of the view the host's content insets leave unobscured — and not the view's whole frame.
///
/// The engine floors at `CGRectGetHeight(self.bounds)` (`-id_reconcileDerivedStateForDocumentChange:`
/// and `-layoutSubviews` both), which is the same number whenever the insets are zero — as they are
/// in the InputDec app and in this project's chat composer, whose host passes `.zero`. The ARTICLE
/// editor is the host that is not: it fills the screen and hands the navigation bar, the action bar,
/// the home indicator and whichever of the system keyboard / emoji panel is up to `contentInset`.
/// Floored at the frame, the scrollable range is then `contentInset.top + contentInset.bottom` for
/// EVERY document however short. Measured on K3 with a ~470pt article in an 810pt editor: 160pt of
/// phantom scroll with nothing up, 468 with the keyboard, 475 with the emoji panel — the whole
/// article could be dragged off the top of the screen, and each panel transition re-clamped the
/// offset inside a range the transition itself had just resized (closing the emoji panel snapped the
/// content back 475pt).
///
/// The legacy canvas has floored at the visible height all along — `RichTextEditorView.performLayout`,
/// "keeps the scroll content == visible area for a short doc, so the scrollable range is zero (no
/// phantom scroll/bounce over the inset bands)". This is that rule, applied at the one place both of
/// the engine's assignments pass through, so no upstream edit is needed and a re-port cannot lose it.
///
/// `adjustedContentInset` because that is what UIScrollView clamps the offset against. The host pins
/// `contentInsetAdjustmentBehavior` to `never` (see `RichTextEngineEditorView`), so it equals
/// `contentInset` and reading it here cannot feed back through the `.scrollableAxes` adjustment.
- (void)setContentSize:(CGSize)contentSize {
    IDBlockStackCanvasView *stack = self.id_blockStack;
    if (stack == nil) {
        [super setContentSize:contentSize];
        return;
    }
    UIEdgeInsets insets = self.adjustedContentInset;
    CGFloat visibleHeight = MAX(CGRectGetHeight(self.bounds) - insets.top - insets.bottom, 0.0);
    CGFloat verticalTextInset = self.textContainerInset.top + self.textContainerInset.bottom;
    CGFloat documentHeight = stack.documentContentSize.height + verticalTextInset;
    [super setContentSize:CGSizeMake(contentSize.width, ceil(MAX(visibleHeight, documentHeight)))];
}

- (void)tgpn_textInputDidChange:(id)input {
    [super tgpn_textInputDidChange:input];
    [self.observationSink engineDidFinishEdit];
}

/// The engine's OWN whole-content replacement idiom, copied from -[IDBlockTextView setText:]
/// (IDBlockTextView.m:507-516) with an attributed replacement. Blocks are joined by newlines
/// because the engine re-derives block structure by splitting the canonical string on "\n"
/// (IDBlockDocument.m:121-139), reading each separator's attributes from the newline itself.
- (void)tgid_readoptEmptyBlockTypingAttributes {
    [self id_adoptEmptyBlockTypingAttributesIfNeeded];
}

/// The engine adopts an EMPTY block's own attributes (the host's empty-line provider: the role's
/// rendering, in the current theme) only for a CARET there. A SELECTION that starts on an empty line
/// has that line's invisible separator as its first character, and the controller types over a
/// selection with the first character's attributes — so the separator's attributes decided typing
/// there, and a separator is not presentation the host re-derives: a set gives an empty block's
/// separator the document's unthemed defaults (the dark theme typed BLACK text,
/// `HarnessDarkThemeEmptyLineTypingColourTests`), and a Return split leaves it the typing attributes of
/// the moment, which an undo's re-render then does not reproduce (the same keystrokes typed struck or
/// plain depending on the undo history, `HarnessUndoSeparatorTypingAttributesTests`; composer harness
/// p21). Typing over a selection that starts on an empty line now types as a caret on that line does.
/// (A stock text view keeps whatever attributes the newline was typed with; this model has no place
/// for inline state on an empty paragraph, so its line's role decides, as it does for the caret.)
- (void)id_adoptEmptyBlockTypingAttributesIfNeeded {
    [super id_adoptEmptyBlockTypingAttributesIfNeeded];
    if (self.markedTextRange != nil) {
        return;
    }
    [self tgid_adoptEmptyLineTypingAttributesForSelectionStart];
    [self tgid_applyFormatCommandTraitsIfNeeded];
}

/// The p21 half of the override above: a SELECTION starting on an empty line takes that line's role
/// attributes, as a caret there does.
- (void)tgid_adoptEmptyLineTypingAttributesForSelectionStart {
    NSRange selection = [self tgid_canonicalSelectedRange];
    if (selection.location == NSNotFound || selection.length == 0) {
        return;
    }
    IDBlockStackCanvasView *stack = self.id_blockStack;
    if (stack == nil) {
        return;
    }
    NSUInteger offset = 0;
    for (IDBlock *block in self.id_document.blocks) {
        NSUInteger end = offset + block.attributedText.length;
        if (selection.location <= end) {
            if (block.attributedText.length == 0 && selection.location == offset) {
                NSDictionary<NSAttributedStringKey, id> *intended =
                    [stack id_emptyLineAttributesForIdentifier:block.identifier];
                if (intended.count > 0) {
                    self.id_behaviorInput.typingAttributes = intended;
                }
            }
            return;
        }
        offset = end + 1;  // the separator
    }
}

- (void)tgid_adoptTypingAttributesOfSelectedText {
    if (self.markedTextRange != nil) {
        return;
    }
    NSRange selection = [self tgid_canonicalSelectedRange];
    if (selection.location == NSNotFound || selection.length == 0) {
        return;
    }
    // UIKit's own re-derivation, the one a selection change and an undo run: the typing attributes are
    // recomputed from the text under the selection and filtered to the allowed names, exactly as after
    // re-selecting. Writing the first character's attributes directly also carried markers the
    // allowed set keeps out (a spoiler, inline code), which typing only takes through the typed-text
    // policy.
    [self.id_behaviorInput invalidateTypingAttributes];
    // A selection starting on an empty line types as a caret there (see the override above) — except
    // for the traits the command just applied, which the selected text now carries.
    self.tgid_formatCommandSelection = [NSValue valueWithRange:selection];
    [self id_adoptEmptyBlockTypingAttributesIfNeeded];
}

/// **A format command's traits win over what a line break at the selection's start derives, until the
/// selection moves** (composer harness p22, `HarnessFormatOverEmptyLineSelectionTypingTests`).
///
/// UIKit types over a selection with its FIRST character's attributes. When that character is a line
/// break — the selection starts on an empty line, or at a line's end — it is a separator, which an
/// inline command never formats (the model has no place for a format on a line break): Bold over
/// `⏎en` bolded `en`, and the `x` typed over it came out plain — the empty-line role attributes (p21)
/// or the separator's own replaced the command's re-derivation. A stock `UITextView` formats the
/// newline with the rest and types bold. So, only while the selection is still the one a format
/// command re-adopted for, the traits (bold, italic, underline, strikethrough) are those of the first
/// selected TEXT character, applied on top of whatever the start derived — its face, colour and
/// role stay the line's. Without a format command in between nothing changes: the start decides, as
/// p21 decided. The traits are read from the live text each time, so an undo of the command under the
/// same selection reads the restored text.
- (void)tgid_applyFormatCommandTraitsIfNeeded {
    NSValue *recorded = self.tgid_formatCommandSelection;
    if (recorded == nil) {
        return;
    }
    NSRange selection = [self tgid_canonicalSelectedRange];
    if (selection.location == NSNotFound || !NSEqualRanges(selection, recorded.rangeValue)) {
        self.tgid_formatCommandSelection = nil;
        return;
    }
    // The first selected character and the first selected TEXT character, on the canonical axis.
    NSDictionary<NSAttributedStringKey, id> *firstText = nil;
    BOOL startsOnALineBreak = NO;
    NSUInteger offset = 0;
    NSUInteger end = NSMaxRange(selection);
    for (IDBlock *block in self.id_document.blocks) {
        NSUInteger blockEnd = offset + block.attributedText.length;
        if (offset >= end) {
            break;
        }
        if (selection.location == blockEnd) {
            startsOnALineBreak = YES;
        }
        NSUInteger from = MAX(offset, selection.location);
        if (from < blockEnd && from < end) {
            firstText = [block.attributedText attributesAtIndex:from - offset effectiveRange:NULL];
            break;
        }
        offset = blockEnd + 1;  // the separator
    }
    if (!startsOnALineBreak || firstText == nil) {
        return;
    }
    IDInlineTextStyleResolver *resolver = self.id_inlineTextStyleResolver;
    NSDictionary<NSAttributedStringKey, id> *typing = self.id_behaviorInput.typingAttributes ?: @{};
    self.id_behaviorInput.typingAttributes =
        [resolver attributesByApplyingTraits:[resolver traitsInAttributes:firstText] toAttributes:typing];
}

- (void)tgid_translateTypingAttributesUsingBlock:(id _Nullable (^)(NSAttributedStringKey key, id value))translate {
    [self id_translateTypingAttributesUsingBlock:translate];
}

/// Answers the host's stack when one is installed. See the header for why this exists.
- (NSUndoManager *)undoManager {
    NSUndoManager *override = self.tgid_undoManagerOverride;
    return override != nil ? override : [super undoManager];
}

#pragma mark - Accessibility

/// See `tgid_accessibilityValueProvider`. The engine's raw text reads an attachment atom as `U+FFFC`.
- (NSString *)accessibilityValue {
    NSString *(^provider)(void) = self.tgid_accessibilityValueProvider;
    NSString *value = provider != nil ? provider() : nil;
    return value ?: [super accessibilityValue];
}

/// The selection VoiceOver reads against `accessibilityValue`, on that value's axis. UIKit's
/// accessibility support for a `UITextInput` responder answers this from `-selectedTextRange` on the
/// engine's axis; the host's value is on another one once an atom expands, so the host maps it. Only
/// called while the accessibility runtime is loaded; nothing else in the process asks.
- (NSRange)tgpn__accessibilitySelectedTextRange {
    NSRange canonical = [self tgid_canonicalSelectedRange];
    NSRange (^map)(NSRange) = self.tgid_accessibilityRangeFromCanonicalRange;
    if (canonical.location == NSNotFound || map == nil) {
        return canonical;
    }
    return map(canonical);
}

/// VoiceOver moving the cursor (character / word navigation, the rotor): its range is on the value's
/// axis, mapped back to the engine's, where an offset INSIDE an expanded atom snaps to a boundary.
- (void)tgpn__accessibilitySetSelectedTextRange:(NSRange)range {
    if (range.location == NSNotFound) {
        return;
    }
    NSRange (^map)(NSRange) = self.tgid_canonicalRangeFromAccessibilityRange;
    NSRange canonical = map != nil ? map(range) : range;
    UITextPosition *start = [self positionFromPosition:self.beginningOfDocument
                                                offset:(NSInteger)canonical.location];
    UITextPosition *end = start != nil ? [self positionFromPosition:start offset:(NSInteger)canonical.length] : nil;
    UITextRange *textRange = end != nil ? [self textRangeFromPosition:start toPosition:end] : nil;
    if (textRange != nil) {
        self.selectedTextRange = textRange;
    }
}

- (void)tgid_flushSelectionDisplayUpdate {
    // Clear the engine's own pending flag too: THIS is that flush. Left armed it would be spent by
    // whatever pass comes next, and the next pass is as likely as not one a bare selection move
    // triggered — the one place `-layoutManagedSubviews` must not run.
    self.id_selectionDisplayFlushPending = NO;
    [self id_flushSelectionDisplayUpdate];
}


/// **The engine's caret-follow entry point, which no longer follows anything.**
///
/// The decision moved to the host — see
/// the RichTextEditor `CLAUDE.md`, "The host decides when the caret is revealed". Every misfire it
/// replaced was this method deciding against geometry the host was about to change: the composer
/// flickering into scroll mode as the panel grew the field around a keystroke, and the article
/// editor's caret landing under a keyboard whose inset had not arrived yet.
///
/// What is left is the FACT that a reveal is owed. Reporting it is the wrapper's job, because
/// upstream reaches this method three times for one keystroke — the document-change reconcile,
/// UIKit's selection settle, then `textInputDidChange:` — and only the last has settled geometry.
///
/// Deliberately does NOT call `super`, which is upstream's minimum scroll. The ends rule that used
/// to live in this file is in `RichTextCaretRevealSolver` now, where both editors share it.
- (void)id_scrollCaretToVisibleIfNeeded {
    self.tgid_caretRevealPending = YES;
}

- (void)tgid_mergeAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
                removingKeys:(NSArray<NSAttributedStringKey> *)removedKeys
            inCanonicalRange:(NSRange)range {
    IDCanonicalTextStorageAdapter *adapter = self.id_textStorageAdapter;
    if (adapter == nil || range.length == 0 || NSMaxRange(range) > adapter.length) {
        return;
    }
    [adapter id_transformTextAttributesInCanonicalRange:range
                                             usingBlock:^NSDictionary<NSAttributedStringKey, id> *(
                                                 NSDictionary<NSAttributedStringKey, id> *existing) {
        NSMutableDictionary<NSAttributedStringKey, id> *merged = [existing mutableCopy];
        for (NSAttributedStringKey key in removedKeys) {
            [merged removeObjectForKey:key];
        }
        [merged addEntriesFromDictionary:attributes];
        return merged;
    }];
}

- (void)tgid_mergeAttributeEditsInCanonicalRanges:(NSArray<NSValue *> *)ranges
                                       attributes:(NSArray<NSDictionary<NSAttributedStringKey, id> *> *)attributes
                                     removingKeys:(NSArray<NSArray<NSAttributedStringKey> *> *)removedKeys {
    IDCanonicalTextStorageAdapter *adapter = self.id_textStorageAdapter;
    NSUInteger count = ranges.count;
    if (adapter == nil || count == 0 || attributes.count != count || removedKeys.count != count) {
        return;
    }
    NSArray<IDBlock *> *blocks = self.id_document.blocks;
    NSUInteger blockCount = blocks.count;
    NSUInteger length = adapter.length;
    // Each block's first canonical position, once.
    NSMutableData *startData = [NSMutableData dataWithLength:sizeof(NSUInteger) * MAX(blockCount, (NSUInteger)1)];
    NSUInteger *starts = startData.mutableBytes;
    NSUInteger position = 0;
    for (NSUInteger index = 0; index < blockCount; index++) {
        starts[index] = position;
        position += blocks[index].attributedText.length + 1;
    }
    NSMutableDictionary<NSNumber *, NSMutableAttributedString *> *edited = [NSMutableDictionary dictionary];
    NSRange changed = NSMakeRange(NSNotFound, 0);
    for (NSUInteger edit = 0; edit < count; edit++) {
        NSRange range = ranges[edit].rangeValue;
        if (range.length == 0 || NSMaxRange(range) > length) {
            continue;
        }
        // The last block starting at or before the range's start.
        NSUInteger low = 0, high = blockCount;
        while (high - low > 1) {
            NSUInteger middle = (low + high) / 2;
            if (starts[middle] <= range.location) low = middle; else high = middle;
        }
        for (NSUInteger index = low; index < blockCount && starts[index] < NSMaxRange(range); index++) {
            NSUInteger textLength = blocks[index].attributedText.length;
            NSRange intersection = NSIntersectionRange(range, NSMakeRange(starts[index], textLength));
            if (intersection.length == 0) {
                continue;
            }
            NSMutableAttributedString *text = edited[@(index)];
            if (text == nil) {
                text = [blocks[index].attributedText mutableCopy];
                edited[@(index)] = text;
            }
            NSRange local = NSMakeRange(intersection.location - starts[index], intersection.length);
            for (NSAttributedStringKey key in removedKeys[edit]) {
                [text removeAttribute:key range:local];
            }
            if (attributes[edit].count > 0) {
                [text addAttributes:attributes[edit] range:local];
            }
            changed = changed.location == NSNotFound ? intersection : NSUnionRange(changed, intersection);
        }
    }
    if (edited.count == 0) {
        return;
    }
    NSMutableArray<NSAttributedString *> *texts = [NSMutableArray arrayWithCapacity:blockCount];
    for (NSUInteger index = 0; index < blockCount; index++) {
        NSAttributedString *text = edited[@(index)];
        [texts addObject:text != nil ? text : blocks[index].attributedText];
    }
    [adapter id_restoreAttributedBlocks:texts changedRange:changed];
}

- (void)tgid_transformAttributesInCanonicalRange:(NSRange)range
                                      usingBlock:(NSDictionary<NSAttributedStringKey, id> *(^)(
                                                     NSDictionary<NSAttributedStringKey, id> *existing))transform {
    IDCanonicalTextStorageAdapter *adapter = self.id_textStorageAdapter;
    if (adapter == nil || transform == nil || range.length == 0 || NSMaxRange(range) > adapter.length) {
        return;
    }
    [adapter id_transformTextAttributesInCanonicalRange:range usingBlock:transform];
}

/// The selection in canonical offsets, as UIKit reads it through `UITextInput`; NSNotFound when none.
- (NSRange)tgid_canonicalSelectedRange {
    UITextRange *selected = self.selectedTextRange;
    if (selected == nil) {
        return NSMakeRange(NSNotFound, 0);
    }
    NSInteger start = [self offsetFromPosition:self.beginningOfDocument toPosition:selected.start];
    NSInteger end = [self offsetFromPosition:self.beginningOfDocument toPosition:selected.end];
    if (start < 0 || end < start) {
        return NSMakeRange(NSNotFound, 0);
    }
    return NSMakeRange((NSUInteger)start, (NSUInteger)(end - start));
}

/// Makes the selection UIKit reads describe the text a host set has JUST written, BEFORE the set's
/// `textDidChange:` goes out. `previous` is the selection read before the replacement, in the old
/// document's offsets; `span` is the old range that was replaced and `newLength` the length of what
/// replaced it.
///
/// UIKit builds the document state it sends the keyboard daemon (context before, selected text,
/// context after) from the selection at `textDidChange:`. Its input controller's ranges are
/// untracked snapshots, so without this they still held the PREVIOUS document's offsets there, and
/// the host re-seated the selection only after the bracket closed. Resolved against the new text,
/// the old offsets could land between the two halves of a surrogate pair: an undo that removed one
/// character before an emoji sent kbd a context ending in a lone surrogate, and kbd ABORTED
/// (`NSRangeException` under `-[TIRevisionHistory handleRevisedTokenString:…]`, composer harness
/// fuzz seed 15; `HarnessInputDelegateContractTests`). Every later keyboard sync then waited out a
/// timeout.
///
/// The rule is a text storage edit's, which is what a stock `UITextView` applies: an offset before
/// the span stays, one after it moves by the change in length, one inside it goes to the end of the
/// replacement. The result is then snapped to composed-character boundaries of the new text. The
/// caller still puts the selection where it belongs afterwards; this only guarantees that nothing
/// UIKit reads in between is invalid.
- (void)tgid_reseatSelection:(NSRange)previous afterReplacingRange:(NSRange)span withLength:(NSUInteger)newLength {
    if (previous.location == NSNotFound) {
        return;
    }
    NSUInteger (^map)(NSUInteger) = ^NSUInteger(NSUInteger offset) {
        if (offset <= span.location) {
            return offset;
        }
        if (offset >= NSMaxRange(span)) {
            return offset - span.length + newLength;
        }
        return span.location + newLength;
    };
    UITextRange *whole = [self textRangeFromPosition:self.beginningOfDocument toPosition:self.endOfDocument];
    NSString *text = whole != nil ? ([self textInRange:whole] ?: @"") : @"";
    NSUInteger (^snap)(NSUInteger) = ^NSUInteger(NSUInteger offset) {
        if (offset >= text.length) {
            return text.length;
        }
        return [text rangeOfComposedCharacterSequenceAtIndex:offset].location;
    };
    NSUInteger start = snap(map(previous.location));
    NSUInteger end = MAX(start, snap(map(NSMaxRange(previous))));
    NSRange current = [self tgid_canonicalSelectedRange];
    if (current.location == start && NSMaxRange(current) == end) {
        return;
    }
    UITextPosition *startPosition = [self positionFromPosition:self.beginningOfDocument offset:(NSInteger)start];
    UITextPosition *endPosition = [self positionFromPosition:self.beginningOfDocument offset:(NSInteger)end];
    if (startPosition == nil || endPosition == nil) {
        return;
    }
    UITextRange *range = [self textRangeFromPosition:startPosition toPosition:endPosition];
    if (range != nil) {
        self.selectedTextRange = range;
    }
}

- (void)tgid_replaceBlocksInRange:(NSRange)blockRange
             withAttributedBlocks:(NSArray<NSAttributedString *> *)blocks {
    NSArray<IDBlock *> *current = self.id_document.blocks;
    if (blockRange.location > current.count || NSMaxRange(blockRange) > current.count) {
        return;
    }
    // Canonical offsets of the span: the start of its first block, the end of its last.
    NSUInteger spanStart = 0;
    for (NSUInteger index = 0; index < blockRange.location; index += 1) {
        spanStart += current[index].attributedText.length + 1;
    }
    NSUInteger spanEnd = spanStart;
    for (NSUInteger index = blockRange.location; index < NSMaxRange(blockRange); index += 1) {
        spanEnd += current[index].attributedText.length + (index + 1 < NSMaxRange(blockRange) ? 1 : 0);
    }
    NSMutableAttributedString *joined = [[NSMutableAttributedString alloc] init];
    [blocks enumerateObjectsUsingBlock:^(NSAttributedString *block, NSUInteger index, BOOL *stop) {
        if (index > 0) {
            NSDictionary<NSAttributedStringKey, id> *separatorAttributes =
                blocks[index - 1].length > 0
                    ? [blocks[index - 1] attributesAtIndex:blocks[index - 1].length - 1 effectiveRange:NULL]
                    : self.id_document.defaultAttributes;
            [joined appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"
                                                                            attributes:separatorAttributes]];
        }
        [joined appendAttributedString:block];
    }];
    // Attach to the PRECEDING block wherever there is one: the engine keeps the identity of the
    // first block an edit touches, so an insertion or deletion that begins at the end of the block
    // before the span leaves every block after the span — and that block — as they were. Only at
    // the very start of the document does the edit have to touch the block that follows.
    NSUInteger prefixEnd = spanStart > 0 ? spanStart - 1 : 0;
    NSRange span = NSMakeRange(spanStart, spanEnd - spanStart);
    NSAttributedString *separator =
        [[NSAttributedString alloc] initWithString:@"\n" attributes:self.id_document.defaultAttributes];
    if (blockRange.length == 0 && blocks.count > 0) {
        if (blockRange.location > 0) {
            [joined insertAttributedString:separator atIndex:0];
            span = NSMakeRange(prefixEnd, 0);
        } else {
            [joined appendAttributedString:separator];
            span = NSMakeRange(0, 0);
        }
    } else if (blocks.count == 0 && blockRange.length > 0) {
        if (blockRange.location > 0) {
            span = NSMakeRange(prefixEnd, spanEnd - prefixEnd);
        } else if (NSMaxRange(blockRange) < current.count) {
            span.length += 1;
        }
    }
    // Bracketed like the wholesale set: UIKit re-reads its shadow copy only when told — and re-reads
    // the selection with it, so the selection is made valid for the new text first.
    NSRange previousSelection = [self tgid_canonicalSelectedRange];
    [self.inputDelegate textWillChange:self];
    [self.id_textStorageAdapter replaceCharactersInRange:span withAttributedString:joined];
    [self tgid_reseatSelection:previousSelection afterReplacingRange:span withLength:joined.length];
    [self.inputDelegate textDidChange:self];
}

- (void)tgid_setAttributedBlocks:(NSArray<NSAttributedString *> *)blocks {
    [self tgid_setAttributedBlocks:blocks emptyLineAttributes:nil];
}

- (void)tgid_setAttributedBlocks:(NSArray<NSAttributedString *> *)blocks
             emptyLineAttributes:(NSArray<NSDictionary<NSAttributedStringKey, id> *> *)
                                 emptyLineAttributes {
    [self tgid_setAttributedBlocks:blocks
              emptyLineAttributes:emptyLineAttributes
            emptyLineCaretOffsets:nil];
}

- (void)tgid_setAttributedBlocks:(NSArray<NSAttributedString *> *)blocks
             emptyLineAttributes:(NSArray<NSDictionary<NSAttributedStringKey, id> *> *)
                                 emptyLineAttributes
           emptyLineCaretOffsets:(NSArray<NSNumber *> *)emptyLineCaretOffsets {
    NSMutableAttributedString *joined = [[NSMutableAttributedString alloc] init];
    [blocks enumerateObjectsUsingBlock:^(NSAttributedString *block, NSUInteger index, BOOL *stop) {
        if (index > 0) {
            NSDictionary<NSAttributedStringKey, id> *separatorAttributes =
                blocks[index - 1].length > 0
                    ? [blocks[index - 1] attributesAtIndex:blocks[index - 1].length - 1
                                            effectiveRange:NULL]
                    : self.id_document.defaultAttributes;
            [joined appendAttributedString:
                [[NSAttributedString alloc] initWithString:@"\n"
                                                attributes:separatorAttributes]];
        }
        [joined appendAttributedString:block];
    }];
    // BRACKETED with the input-delegate notifications. UIKit keeps its own shadow copy of the
    // document for autocorrection, inline prediction and the candidate bar, and it only re-reads it
    // when a client announces a change. Upstream's `-setText:` omits this bracket, but that is a
    // load-time API called before the field is focused; this one fires on every toolbar tap and
    // every list continuation WHILE the user is typing, so an un-announced whole-document rewrite
    // leaves the keyboard reasoning about text that is no longer there.
    NSRange previousSelection = [self tgid_canonicalSelectedRange];
    NSUInteger previousLength = self.id_textStorageAdapter.length;
    [self.inputDelegate textWillChange:self];
    [self.id_textStorageAdapter
        replaceCharactersInRange:NSMakeRange(0, previousLength)
            withAttributedString:joined];
    // AFTER the document is written, never before: the map is keyed by block identity, and until the
    // replacement lands `tgid_blockIdentifiers` still describes the PREVIOUS document — every entry
    // would be filed against the wrong block, or against one that no longer exists.
    //
    // This reaches EVERY block, including the last, whose line has no following separator for the
    // attributes to travel on.
    if (emptyLineAttributes.count > 0) {
        NSMutableDictionary<NSUUID *, NSDictionary<NSAttributedStringKey, id> *> *byIdentifier =
            [NSMutableDictionary dictionary];
        NSArray<NSUUID *> *identifiers = self.tgid_blockIdentifiers;
        [emptyLineAttributes enumerateObjectsUsingBlock:^(NSDictionary *attributes,
                                                          NSUInteger index, BOOL *stop) {
            if (index < identifiers.count && attributes.count > 0) {
                byIdentifier[identifiers[index]] = attributes;
            }
        }];
        self.id_emptyLineAttributesByBlock = byIdentifier;
    } else {
        self.id_emptyLineAttributesByBlock = nil;
    }
    if (emptyLineCaretOffsets.count > 0) {
        NSMutableDictionary<NSUUID *, NSNumber *> *offsetsByIdentifier =
            [NSMutableDictionary dictionary];
        NSArray<NSUUID *> *identifiers = self.tgid_blockIdentifiers;
        [emptyLineCaretOffsets enumerateObjectsUsingBlock:^(NSNumber *offset, NSUInteger index,
                                                            BOOL *stop) {
            if (index < identifiers.count && offset.doubleValue != 0.0) {
                offsetsByIdentifier[identifiers[index]] = offset;
            }
        }];
        self.id_emptyLineCaretOffsetsByBlock = offsetsByIdentifier;
    } else {
        self.id_emptyLineCaretOffsetsByBlock = nil;
    }

    [self id_reconcileDerivedState];
    // The selection UIKit reads at `textDidChange:` must describe THIS text (see
    // `tgid_reseatSelection:afterReplacingRange:withLength:`).
    [self tgid_reseatSelection:previousSelection
           afterReplacingRange:NSMakeRange(0, previousLength)
                    withLength:joined.length];
    [self.inputDelegate textDidChange:self];
}

/// The one-line forward `tgid_customInputView`'s doc comment (TGIDEngineObservation.h) describes:
/// `IDBlockTextView` never overrides this, so UIKit's default (always nil) stands unless something
/// does. This is that something, and it decides nothing beyond "return the stored view".
- (nullable UIView *)inputView {
    return self.tgid_customInputView;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    // The scroll view's OWN pan/pinch are exempt: the veto is for the text-interaction assistant's
    // recognizers (tap/long-press/selection-drag, attached to this view per the header comment),
    // never for the scrolling this view does as a UIScrollView. Without this exemption a drag that
    // starts on a hosted media view could no longer scroll the editor at all.
    if (gestureRecognizer == self.panGestureRecognizer) {
        // The scroll pan has its own, narrower veto: it yields to a table's resize knob and to
        // nothing else (the header on `tgid_shouldBeginScrollPanHandler` says why).
        if (self.tgid_shouldBeginScrollPanHandler != nil
            && !self.tgid_shouldBeginScrollPanHandler([gestureRecognizer locationInView:self])) {
            return NO;
        }
        return [super gestureRecognizerShouldBegin:gestureRecognizer];
    }
    if (self.pinchGestureRecognizer != nil && gestureRecognizer == self.pinchGestureRecognizer) {
        return [super gestureRecognizerShouldBegin:gestureRecognizer];
    }
    if (self.tgid_shouldBeginGestureRecognizerHandler != nil
        && !self.tgid_shouldBeginGestureRecognizerHandler(gestureRecognizer)) {
        return NO;
    }
    if (self.tgid_shouldBeginTextInteractionHandler != nil
        && !self.tgid_shouldBeginTextInteractionHandler(
               [gestureRecognizer locationInView:self],
               [gestureRecognizer isKindOfClass:UITapGestureRecognizer.class])) {
        return NO;
    }
    return [super gestureRecognizerShouldBegin:gestureRecognizer];
}

/// **A tap places the caret on the character under the finger, not at the end of the word it is in.**
///
/// UIKit's own rule — `-[UIResponder _findPleasingWordBoundaryFromPosition:]` — moves a tapped
/// position to the enclosing word's START when the tap is within one character of it and to its END
/// otherwise. So every tap two or more characters into a word resolves to the same offset, and a
/// second tap anywhere in the word the caret already ends in moves nothing at all. UIKit reads a tap
/// that does not move the caret as a tap ON the caret and raises the edit menu
/// (`-[UITextSelectionInteraction didUpdateSelectionWithGesture:]` ->
/// `_showSelectionCommandsIfApplicableAfterDelay:`), which is what a user reported from the composer
/// as "tapping the field to focus opens a context menu like I tapped twice" — often, because a draft
/// with long tokens has whole lines that are one word, and because the composer keeps first
/// responder while the emoji keyboard is up, which is the state where the field LOOKS unfocused.
///
/// Intercepting the word granularity makes every tap at a different character move the caret, so the
/// menu is left to the one gesture that is meant to raise it. Everything else — notably the document
/// granularity UIKit substitutes for a secure field — is still UIKit's answer.
- (nullable UITextPosition *)tgpn__findBoundaryPositionClosestToPosition:(nullable UITextPosition *)position
                                                    withGranularity:(UITextGranularity)granularity {
    if (granularity == UITextGranularityWord) {
        return position;
    }
    // `super` by a runtime selector: the method is UIKit's, under a private name.
    struct objc_super superclassInfo = { self, class_getSuperclass(TGIDObservingBlockTextView.class) };
    return ((UITextPosition *(*)(struct objc_super *, SEL, UITextPosition *, UITextGranularity))objc_msgSendSuper)(
        &superclassInfo,
        NSSelectorFromString(TGPN__findBoundaryPositionClosestToPosition_withGranularity_()),
        position,
        granularity);
}

- (void)deleteBackward {
    // A deletion of a SELECTION is a replacement with empty text and goes through the gate like
    // one: a range across blocks is structural, and the controller's own deletion would merge the
    // blocks by identity with no rule deciding the survivor (device, 2026-09-04: select all and
    // Backspace kept a code block's language field, then a quote's band). The host's caret rules
    // still get first refusal below for a caret.
    UITextRange *selection = self.selectedTextRange;
    if (selection != nil && !selection.isEmpty && self.markedTextRange == nil && self.tgid_textInputGate != nil) {
        [self replaceRange:selection withText:@""];
        [self tgid_rederiveTypingAttributesAfterSelectionDeletion];
        // `[super deleteBackward]` is where UIKit takes the selection's edit menu down; a replacement
        // is not, so without this Cut / Copy / Paste / Format stayed up over the collapsed caret.
        [self tgid_dismissEditMenu];
        return;
    }
    // The host gets first refusal — see `tgid_deleteBackwardHandler`. Everything else is the
    // engine's; this override adds no behaviour of its own.
    if (self.tgid_deleteBackwardHandler != nil && self.tgid_deleteBackwardHandler()) {
        return;
    }
    [super deleteBackward];
}

- (void)tgid_dismissEditMenu {
    if (@available(iOS 16.0, *)) {
        for (id<UIInteraction> interaction in self.interactions) {
            if ([interaction isKindOfClass:[UIEditMenuInteraction class]]) {
                [(UIEditMenuInteraction *)interaction dismissMenu];
            }
        }
    } else {
        [[UIMenuController sharedMenuController] hideMenu];
    }
}

- (BOOL)canPerformAction:(SEL)action withSender:(nullable id)sender {
    if (action == @selector(paste:) && self.tgid_canPasteMediaHandler != nil && self.tgid_canPasteMediaHandler()) {
        return YES;
    }
    return [super canPerformAction:action withSender:sender];
}

/// A pasteboard with a text representation is the engine's; one without is offered to the host
/// first (media the chat sends rather than inserts), and falls through when the host declines.
- (void)paste:(id)sender {
    // Richest first: a pasteboard carrying the host's `Document` fragment is the host's, whatever
    // else is on it — `pasteboardItem(for:)` always writes plain text too, so the engine's own
    // `hasText` test below would otherwise claim every rich copy this editor made.
    if (self.tgid_richPasteHandler != nil && self.tgid_richPasteHandler()) {
        return;
    }
    UIPasteboard *pasteboard = UIPasteboard.generalPasteboard;
    BOOL hasText = pasteboard.hasStrings
        || [pasteboard containsPasteboardTypes:@[@"public.rtf", @"com.apple.flat-rtfd"]];
    if (!hasText && self.tgid_pasteMediaHandler != nil && self.tgid_pasteMediaHandler()) {
        return;
    }
    [super paste:sender];
}

/// What the ENGINE's own paste inserts — text another app wrote to the pasteboard — reduced to what
/// the composer's model can hold, so the composer never shows something it will not send (composer
/// harness p20):
///
/// - **No attachment and no bare `U+FFFC`.** An image in an RTFD or an HTML `<img>` imports as an
///   `NSTextAttachment`, which the model read as a bare `U+FFFC` sent literally
///   (`HarnessExternalPasteImageAttachmentTests`). There is no image-paste-to-media path for text
///   pasteboards, so the attachment is dropped; the surrounding text and lines stay.
/// - **Line endings are `"\n"`.** CRLF and a lone CR were kept as `U+000D` in the model and sent
///   (`HarnessPastedCarriageReturnTests`); a stock text view normalises them. So are `U+2029` and NEL (p24).
/// - **Presentation is the destination's.** The engine's import keeps every attribute it does not map,
///   so a foreign colour, highlight, paragraph style or face survived in storage while the model had
///   none (`HarnessPastedForeignColourTests`). Only the semantics the model carries are kept from the
///   pasted run — the four trait markers, underline / strikethrough and a link — on the caret's typing
///   attributes, and the face is rebuilt from the destination's base face plus those traits. A
///   plain-text item was already built from the typing attributes, so it comes out as it went in.
- (NSAttributedString *)textPasteConfigurationSupporting:
    (id<UITextPasteConfigurationSupporting>)supporting
    combineItemAttributedStrings:(NSArray<NSAttributedString *> *)itemStrings
                       forRange:(UITextRange *)textRange {
    NSAttributedString *imported = [super textPasteConfigurationSupporting:supporting
                                              combineItemAttributedStrings:itemStrings
                                                                  forRange:textRange];
    NSAttributedString *result = [self tgid_pastedTextInDestinationTerms:imported];
    if (self.tgid_pasteWillLandHandler != nil) {
        self.tgid_pasteWillLandHandler();
    }
    return result;
}

- (NSAttributedString *)tgid_pastedTextInDestinationTerms:(NSAttributedString *)imported {
    NSMutableAttributedString *source = imported.mutableCopy;
    // CR LF first (ONE break), then a lone CR, `U+2029` and NEL — the list of Core's
    // `normalisedLineBreaks`, THE normaliser of every other door (the set's render, host pastes, drops),
    // mirrored here because this module cannot call Swift. Keep the two lists equal: a `U+2029` this pass
    // let through reached the model and broke the tokenizer's paragraph boundaries (composer harness p24,
    // `HarnessSetCarriageReturnTests`). Literal: a non-literal search matches whole composed character
    // sequences and misses a break followed by a mark.
    // (`U+0085` cannot be written as a universal character name: C forbids one for a control character.)
    NSString *paragraphSeparator = [NSString stringWithFormat:@"%C", (unichar)0x2029];
    NSString *nextLine = [NSString stringWithFormat:@"%C", (unichar)0x0085];
    for (NSString *pattern in @[@"\r\n", @"\r", paragraphSeparator, nextLine]) {
        NSRange search = NSMakeRange(0, source.length);
        while (search.length > 0) {
            NSRange found = [source.string rangeOfString:pattern
                                                 options:NSLiteralSearch | NSBackwardsSearch
                                                   range:search];
            if (found.location == NSNotFound) {
                break;
            }
            [source replaceCharactersInRange:found withString:@"\n"];
            search = NSMakeRange(0, found.location);
        }
    }
    NSString *string = source.string;
    NSDictionary<NSAttributedStringKey, id> *typing = self.id_behaviorInput.typingAttributes ?: @{};
    NSArray<NSAttributedStringKey> *semanticKeys = @[
        IDInlineTextBoldAttributeName, IDInlineTextItalicAttributeName,
        IDInlineTextUnderlineAttributeName, IDInlineTextStrikethroughAttributeName,
        NSUnderlineStyleAttributeName, NSStrikethroughStyleAttributeName, NSLinkAttributeName,
    ];
    NSMutableDictionary<NSAttributedStringKey, id> *base = typing.mutableCopy;
    [base removeObjectsForKeys:semanticKeys];
    // The shared mapper's user-bold marker: here bold is the trait marker's alone.
    [base removeObjectForKey:@"RTBold"];
    [base removeObjectForKey:NSAttachmentAttributeName];
    // Colours are the ROLE's to derive (settle re-renders the touched blocks): the caret's typing
    // foreground is a link's accent when the caret sits after a link, and its background the
    // inline-code fill without the marker the allowed typing attributes keep out — either drawn on
    // pasted text the model holds as plain (p20 fix wave sweep, default fuzz seed 29).
    [base removeObjectForKey:NSForegroundColorAttributeName];
    [base removeObjectForKey:NSBackgroundColorAttributeName];
    IDInlineTextStyleResolver *resolver = self.id_inlineTextStyleResolver;
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
    NSUInteger length = string.length;
    NSUInteger index = 0;
    while (index < length) {
        NSRange run;
        NSDictionary<NSAttributedStringKey, id> *attributes =
            [source attributesAtIndex:index
                longestEffectiveRange:&run
                              inRange:NSMakeRange(index, length - index)];
        index = NSMaxRange(run);
        if (attributes[NSAttachmentAttributeName] != nil) {
            continue;
        }
        NSMutableString *text = [[string substringWithRange:run] mutableCopy];
        [text replaceOccurrencesOfString:@"\uFFFC"
                              withString:@""
                                 options:NSLiteralSearch
                                   range:NSMakeRange(0, text.length)];
        if (text.length == 0) {
            continue;
        }
        NSMutableDictionary<NSAttributedStringKey, id> *kept = base.mutableCopy;
        for (NSAttributedStringKey key in semanticKeys) {
            if (attributes[key] != nil) {
                kept[key] = attributes[key];
            }
        }
        NSDictionary<NSAttributedStringKey, id> *final = kept;
        if (resolver != nil) {
            final = [resolver attributesByApplyingTraits:[resolver traitsInAttributes:attributes]
                                            toAttributes:kept];
        }
        [result appendAttributedString:[[NSAttributedString alloc] initWithString:text attributes:final]];
    }
    return result.copy;
}

/// The host's clipboard first; the engine's plain-text copy when it declines.
- (void)copy:(id)sender {
    if (self.tgid_copyHandler != nil && self.tgid_copyHandler()) {
        return;
    }
    [super copy:sender];
}

/// Cut is a copy and a replacement with empty text, so the deletion reaches the gate (see
/// `deleteBackward`).
- (void)cut:(id)sender {
    UITextRange *selection = self.selectedTextRange;
    if (selection == nil || selection.isEmpty || self.markedTextRange != nil || self.tgid_textInputGate == nil
        || ![self canPerformAction:_cmd withSender:sender]) {
        [super cut:sender];
        return;
    }
    [self copy:sender];
    // Delete exactly what the copy took (composer harness p19): a copy that took a whole medium
    // while the deletion kept its atom left the photo in place AND on the clipboard.
    UITextRange *deletion = selection;
    if (self.tgid_cutRangeHandler != nil) {
        NSRange selected = [self id_NSRangeForTextRange:selection];
        NSRange wanted = self.tgid_cutRangeHandler(selected);
        if (!NSEqualRanges(wanted, selected) && wanted.location != NSNotFound) {
            UITextPosition *start = [self positionFromPosition:self.beginningOfDocument offset:(NSInteger)wanted.location];
            UITextPosition *end = start == nil ? nil : [self positionFromPosition:start offset:(NSInteger)wanted.length];
            UITextRange *widened = end == nil ? nil : [self textRangeFromPosition:start toPosition:end];
            if (widened != nil) {
                deletion = widened;
            }
        }
    }
    [self replaceRange:deletion withText:@""];
    [self tgid_rederiveTypingAttributesAfterSelectionDeletion];
}

/// A selection DELETED through the gate is a replacement with empty text, and a replacement leaves the
/// typing attributes of the text it replaced — right for text typed over a selection, wrong for a
/// deletion: the next character typed after Backspace or Cut over a bold selection came out bold where
/// a stock text view types it with the caret's own attributes (composer harness p18, fuzz seed 47,
/// `HarnessTypingOverFormattedSelectionTests`). UIKit's own re-derivation, then the empty-line
/// adoption a deletion that emptied its block needs on top of it.
- (void)tgid_rederiveTypingAttributesAfterSelectionDeletion {
    UITextRange *after = self.selectedTextRange;
    if (after == nil || !after.isEmpty || self.markedTextRange != nil) {
        return;
    }
    [self.id_behaviorInput invalidateTypingAttributes];
    [self id_adoptEmptyBlockTypingAttributesIfNeeded];
}

- (void)insertText:(NSString *)text {
    NSString *forwarded = [self tgid_textThroughGate:text replacing:[self id_NSRangeForTextRange:self.selectedTextRange]];
    if (forwarded == nil) {
        return;
    }
    [super insertText:forwarded];
}

/// A composition that STARTS over a selection first has the selection decided by the gate, as a
/// deletion — the rule typing over it obeys — and then begins at the caret that leaves.
///
/// The controller's own `setMarkedText:selectedRange:` replaces the selection with the first
/// candidate by identity merge, bypassing the gate (it is not consulted while text is marked, and
/// before this override not at the start of a composition either). Across blocks that kept the first
/// candidate as committed text (`Firstkか…`) and, over a table covered in part, emptied cells in the
/// model while dropping their lines on screen (composer harness, 2026-09-24,
/// `HarnessCompositionOverSelectionTests`).
///
/// The gate is asked about an EMPTY replacement: when it forwards (a range inside one block, or a
/// cross-block range the controller's merge already gets right) nothing changes and the controller
/// replaces the selection with the candidate as before; when it decides the range itself it has
/// issued its own edits and the composition begins at the collapsed caret; when it REFUSES (a table
/// covered only in part) the selection stays and the composition does not start, as typing over it
/// changes nothing. Later candidates find text marked and go straight through: the IME owns the text
/// until it commits.
- (void)setMarkedText:(nullable NSString *)markedText selectedRange:(NSRange)selectedRange {
    if (![self tgid_resolveSelectionBeforeComposition]) {
        return;
    }
    BOOL wasComposing = self.markedTextRange != nil;
    NSString *filtered = [self tgid_filteredMarkedText:markedText];
    if (filtered != nil) {
        markedText = filtered;
        selectedRange = [self tgid_clampedRange:selectedRange toLength:filtered.length];
    }
    [super setMarkedText:markedText selectedRange:selectedRange];
    [self tgid_noteCompositionEmptiedIfComposing:wasComposing];
}

/// A composition whose marked text was replaced with nothing is over, with nothing committed: the
/// host is told, as it is for a commit (`tgid_compositionDidEmptyHandler`).
- (void)tgid_noteCompositionEmptiedIfComposing:(BOOL)wasComposing {
    if (wasComposing && self.markedTextRange == nil && self.tgid_compositionDidEmptyHandler != nil) {
        self.tgid_compositionDidEmptyHandler();
    }
}

/// The attributed twin — what the keyboard sends when its marked text carries segment attributes —
/// is the same composition and starts over a selection by the same rule. Only the plain door was
/// overridden, so this one reached the controller's identity merge ungated: the first candidate
/// stayed behind across blocks, a code block merged into the paragraph before it, a pull quote lost
/// its author, and a table covered in part was emptied (composer harness, p12,
/// `HarnessAttributedMarkedTextOverSelectionTests`). The marked text's own attributes are display
/// only: the commit re-applies typing's, as for the plain door.
- (void)setAttributedMarkedText:(nullable NSAttributedString *)markedText selectedRange:(NSRange)selectedRange {
    if (![self tgid_resolveSelectionBeforeComposition]) {
        return;
    }
    BOOL wasComposing = self.markedTextRange != nil;
    NSString *filtered = [self tgid_filteredMarkedText:markedText.string];
    if (filtered != nil) {
        // The marked text's attributes are display only (above): the first segment's carry the whole.
        NSDictionary<NSAttributedStringKey, id> *attributes =
            markedText.length > 0 ? [markedText attributesAtIndex:0 effectiveRange:NULL] : @{};
        markedText = [[NSAttributedString alloc] initWithString:filtered attributes:attributes];
        selectedRange = [self tgid_clampedRange:selectedRange toLength:filtered.length];
    }
    [super setAttributedMarkedText:markedText selectedRange:selectedRange];
    [self tgid_noteCompositionEmptiedIfComposing:wasComposing];
}

/// The host's rewrite of a candidate holding a line break (`tgid_markedTextFilter`), or nil to keep it.
- (nullable NSString *)tgid_filteredMarkedText:(nullable NSString *)markedText {
    if (markedText.length == 0 || self.tgid_markedTextFilter == nil
        || [markedText rangeOfCharacterFromSet:NSCharacterSet.newlineCharacterSet].location == NSNotFound) {
        return nil;
    }
    NSString *filtered = self.tgid_markedTextFilter(markedText);
    return [filtered isEqualToString:markedText] ? nil : filtered;
}

- (NSRange)tgid_clampedRange:(NSRange)range toLength:(NSUInteger)length {
    NSUInteger location = MIN(range.location, length);
    return NSMakeRange(location, MIN(range.length, length - location));
}

/// The shared first half of both composition doors (see `setMarkedText:selectedRange:` above). NO
/// when the gate refused the selection and the composition must not start.
- (BOOL)tgid_resolveSelectionBeforeComposition {
    UITextRange *selection = self.selectedTextRange;
    if (self.markedTextRange == nil && selection != nil && !selection.isEmpty && self.tgid_textInputGate != nil) {
        NSRange range = [self id_NSRangeForTextRange:selection];
        NSString *forwarded = @"";
        // What typing over the selection would be attributed with, taken before the deletion
        // collapses it: the composition is still a replacement of that selection.
        NSDictionary<NSAttributedStringKey, id> *typingAttributes = [(id)self.id_behaviorInput typingAttributes];
        self.tgid_resolvedCompositionTypingAttributes = nil;
        if (range.location != NSNotFound) {
            self.tgid_isResolvingCompositionSelection = YES;
            forwarded = self.tgid_textInputGate(range, @"");
            self.tgid_isResolvingCompositionSelection = NO;
        }
        // The host's answer, when it put the composition where typing would insert rather than at the
        // selection's start (`tgid_noteCompositionTypingAttributesOfSelection`).
        if (self.tgid_resolvedCompositionTypingAttributes != nil) {
            typingAttributes = self.tgid_resolvedCompositionTypingAttributes;
            self.tgid_resolvedCompositionTypingAttributes = nil;
        }
        if (forwarded == nil) {
            UITextRange *after = self.selectedTextRange;
            if (after == nil || !after.isEmpty) {
                return NO;
            }
            if (typingAttributes.count > 0) {
                [(id)self.id_behaviorInput setTypingAttributes:typingAttributes];
            }
            self.id_compositionStartsOverResolvedSelection = YES;
        }
    } else if (self.markedTextRange == nil && selection != nil && selection.isEmpty
               && self.tgid_compositionCaretResolver != nil) {
        // A composition at a collapsed caret: the host gets to place it ONCE, before the first
        // candidate (see `tgid_compositionCaretResolver`).
        NSRange caret = [self id_NSRangeForTextRange:selection];
        if (caret.location != NSNotFound) {
            self.tgid_compositionCaretResolver(caret.location);
        }
    }
    return YES;
}

- (void)tgid_noteCompositionTypingAttributesOfSelection {
    if (!self.tgid_isResolvingCompositionSelection) {
        return;
    }
    NSDictionary<NSAttributedStringKey, id> *attributes = [(id)self.id_behaviorInput typingAttributes];
    self.tgid_resolvedCompositionTypingAttributes = attributes ?: @{};
}

- (void)unmarkText {
    BOOL wasComposing = self.markedTextRange != nil;
    [super unmarkText];
    if (wasComposing && self.markedTextRange == nil && self.tgid_compositionDidCommitHandler != nil) {
        self.tgid_compositionDidCommitHandler();
    }
}

/// See `TGIDLineEndCorrectingTokenizer`. Rebuilt only when the engine hands out a different tokenizer.
- (id<UITextInputTokenizer>)tokenizer {
    id<UITextInputTokenizer> inner = [super tokenizer];
    if (inner == nil) {
        return nil;
    }
    TGIDLineEndCorrectingTokenizer *wrapper = self.tgid_lineEndCorrectingTokenizer;
    if (wrapper == nil || wrapper.tgid_inner != inner) {
        wrapper = [[TGIDLineEndCorrectingTokenizer alloc] initWithTokenizer:inner input:self];
        self.tgid_lineEndCorrectingTokenizer = wrapper;
    }
    return wrapper;
}

- (void)replaceRange:(UITextRange *)range withText:(NSString *)text {
    NSRange replaced = [self id_NSRangeForTextRange:range];
    NSString *forwarded = [self tgid_textThroughGate:text replacing:replaced];
    if (forwarded == nil) {
        return;
    }
    // Asked AFTER the gate: a keystroke the gate turned into its own edits never gets here, and the
    // host's own edits pass the gate untouched and are declined by the handler.
    NSDictionary<NSAttributedStringKey, id> *inherited = nil;
    if (self.tgid_replacementAttributesHandler != nil && self.markedTextRange == nil
        && replaced.location != NSNotFound && replaced.length > 0 && forwarded.length > 0) {
        inherited = self.tgid_replacementAttributesHandler(replaced, forwarded);
    }
    [super replaceRange:range withText:forwarded];
    if (inherited.count > 0) {
        [self tgid_attributeReplacement:NSMakeRange(replaced.location, forwarded.length)
                                   text:forwarded
                           withInherited:inherited];
    }
}

/// Gives the text a replacement just put at `inserted` the attributes the host chose for it — the
/// same after-the-fact shape as the typed-text policy (`id_applyTypedTextPolicyForInsertionAt:`), for
/// the same reason: the controller builds the replacement string itself and never asks.
- (void)tgid_attributeReplacement:(NSRange)inserted
                             text:(NSString *)text
                     withInherited:(NSDictionary<NSAttributedStringKey, id> *)inherited {
    IDCanonicalTextStorageAdapter *adapter = self.id_textStorageAdapter;
    if (adapter == nil || NSMaxRange(inserted) > adapter.length) {
        return;
    }
    // Only when the replacement landed where it was asked to, verbatim: anything else was rewritten
    // on the way (a nested correction, a gate transform the controller reshaped) and is not ours to
    // re-attribute.
    if (![[adapter.string substringWithRange:inserted] isEqualToString:text]) {
        return;
    }
    // Only the text BEFORE the first newline continues the replaced word. A newline is a block
    // separator: what follows it is a new paragraph, and gets that block's own presentation — the
    // controller's insertion as settle re-derived it from the new block's role, which is what typing
    // Return and then the rest gives. Written over the whole replacement, the word's spoiler or inline
    // code reached into the next paragraph and a heading's face drew the new BODY line (composer
    // harness, p12, `HarnessMultiLineReplacementAttributesTests`).
    NSRange newline = [text rangeOfString:@"\n" options:NSLiteralSearch];
    if (newline.location != NSNotFound) {
        inserted.length = newline.location;
    }
    if (inserted.length == 0) {
        return;
    }
    [adapter id_transformTextAttributesInCanonicalRange:inserted
                                             usingBlock:^NSDictionary<NSAttributedStringKey, id> *(
                                                 NSDictionary<NSAttributedStringKey, id> *attributes) {
        return inherited;
    }];
    // The decision sticks, as it does for typed text: with the caret at the replacement's end, the
    // next character must not arrive with typing attributes the replacement was just corrected away
    // from.
    UITextRange *selection = self.selectedTextRange;
    if (selection != nil && selection.isEmpty
        && [self offsetFromPosition:self.beginningOfDocument toPosition:selection.start] == (NSInteger)NSMaxRange(inserted)) {
        [(id)self.id_behaviorInput setTypingAttributes:inherited];
    }
}

/// The gate's answer for `text` at `range`, or `text` itself when there is no gate or a
/// composition is in progress (an IME owns the text until it commits).
- (nullable NSString *)tgid_textThroughGate:(NSString *)text replacing:(NSRange)range {
    if (self.markedTextRange != nil) {
        // A commit through `insertText:` is the composition's last candidate: the host's marked-text rule.
        return [self tgid_filteredMarkedText:text] ?: text;
    }
    if (self.tgid_textInputGate == nil || range.location == NSNotFound) {
        return text;
    }
    return self.tgid_textInputGate(range, text);
}

@end

#endif
