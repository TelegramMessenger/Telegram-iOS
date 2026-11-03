#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDBlockTextView.h"

#import "IDBlockDocument.h"
#import "IDBlockDocumentInternal.h"
#import "IDBlockStackCanvasView.h"
#import "IDBlockStackCanvasViewInternal.h"
#import "IDBlockTextViewInternal.h"
#import "IDCanonicalTextStorageAdapter.h"
#import "IDCanonicalTextStorageAdapterInternal.h"
#import "IDInlineTextFormattingController.h"
#import "IDInlineTextStyleResolver.h"
#import "IDPrivateUIKit.h"
#import "IDPrivateUIKit+RichTextLayout.h"
#import "IDPrivateUIKit+TextLayoutCanvas.h"
#import "IDUIKitBehaviorBackend.h"
#import "IDUIKitBehaviorKernel.h"
#import "IDUIKitBehaviorReport.h"
#import "IDUIKitInputControllerCapability.h"
#import "IDUIKitInteractionCapability.h"
#import "IDNativeSelectionPresentationBackend.h"
#import "IDRichTextLayoutController.h"
#import "IDRichTextLayoutControllerInternal.h"
#import "IDRichTextSelectionRect.h"

#include <math.h>

@interface IDBlockTextView (IDSelectionPresentationPublishing)
- (void)id_schedulePendingSelectionPresentation;
- (BOOL)id_publishPendingSelectionPresentation;
@end

@implementation IDBlockTextView {
    // `id_updateTextInputTraits:` batches trait changes into ONE keyboard reload.
    BOOL _id_deferringTraitReload;
    BOOL _id_traitReloadOwed;
    BOOL _id_hasRecordedDefaultContinuousSpellChecking;
    BOOL _id_defaultContinuousSpellChecking;
    // The text geometry the last layout pass laid the blocks out against: the wrap width and the
    // container inset (the stack's origin). A pass that changes either moves every caret and
    // selection rect, so it flushes the selection display like a document change does.
    BOOL _id_hasLaidOutTextGeometry;
    CGFloat _id_laidOutWrapWidth;
    UIEdgeInsets _id_laidOutTextContainerInset;
}

// Not guarded to this class: a subclass that overrides one of the `tgpn_` callbacks must have its
// override installed under the private name too (`IDBlockTextViewInstallPrivateCallbacks`).
+ (void)initialize {
    IDBlockTextViewInstallPrivateCallbacks(self);
}

@synthesize autocapitalizationType = _autocapitalizationType;
@synthesize autocorrectionType = _autocorrectionType;
@synthesize spellCheckingType = _spellCheckingType;
@synthesize smartQuotesType = _smartQuotesType;
@synthesize smartDashesType = _smartDashesType;
@synthesize smartInsertDeleteType = _smartInsertDeleteType;
@synthesize inlinePredictionType = _inlinePredictionType;
@synthesize mathExpressionCompletionType = _mathExpressionCompletionType;
@synthesize keyboardType = _keyboardType;
@synthesize keyboardAppearance = _keyboardAppearance;
@synthesize returnKeyType = _returnKeyType;
@synthesize enablesReturnKeyAutomatically = _enablesReturnKeyAutomatically;
@synthesize secureTextEntry = _secureTextEntry;
@synthesize textContentType = _textContentType;
@synthesize passwordRules = _passwordRules;
@synthesize writingToolsBehavior = _writingToolsBehavior;
@synthesize allowedWritingToolsResultOptions = _allowedWritingToolsResultOptions;
@synthesize conversationContext = _conversationContext;
@synthesize allowsNumberPadPopover = _allowsNumberPadPopover;

static void IDBlockTextViewValidateBlocks(NSArray<NSAttributedString *> *blocks) {
    if (![blocks isKindOfClass:NSArray.class]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"IDBlockTextView block validation failed: blocks are nil or not an array."];
    }
    [blocks enumerateObjectsUsingBlock:^(id value, NSUInteger index, BOOL *stop) {
        if (![value isKindOfClass:NSAttributedString.class]) {
            [NSException raise:NSInvalidArgumentException
                        format:@"IDBlockTextView block validation failed at index %lu: foreign value.",
                               (unsigned long)index];
        }
        if ([[value string] rangeOfString:@"\n" options:NSLiteralSearch].location != NSNotFound) {
            [NSException raise:NSInvalidArgumentException
                        format:@"IDBlockTextView block validation failed at index %lu: U+000A is structural.",
                               (unsigned long)index];
        }
    }];
}

static BOOL IDBlockTextViewPresentationRectIsFinite(CGRect rect) {
    return !CGRectIsNull(rect) && !CGRectIsInfinite(rect) &&
        isfinite(rect.origin.x) && isfinite(rect.origin.y) &&
        isfinite(rect.size.width) && isfinite(rect.size.height);
}

static IDUIKitBehaviorCapabilities
IDBlockTextViewDefaultBehaviorCapabilities(void) {
    return IDUIKitBehaviorCapabilityIncomingCallbacks |
        IDUIKitBehaviorCapabilityTypingAttributes |
        IDUIKitBehaviorCapabilityInteraction |
        IDUIKitBehaviorCapabilityFloatingCursor;
}

+ (void)id_requireReferenceCompatibleRuntime {
    [IDPrivateUIKit requireCompatibleRuntime];
}

+ (IDSelectionPresentationBackendFactory)
    id_defaultSelectionPresentationBackendFactory {
    return ^id<IDSelectionPresentationBackend>(
        IDBlockTextView *hostView) {
        return [[IDNativeSelectionPresentationBackend alloc]
            initWithHostView:hostView];
    };
}

- (instancetype)initWithFrame:(CGRect)frame
              attributedBlocks:(NSArray<NSAttributedString *> *)blocks {
    return [self initWithFrame:frame
              attributedBlocks:blocks
               behaviorBackend:IDUIKitBehaviorBackendReference
                       resolver:[IDUIKitCapabilityResolver systemResolver]
          requestedCapabilities:
              IDBlockTextViewDefaultBehaviorCapabilities()
        selectionPresentationBackendFactory:
            [self.class id_defaultSelectionPresentationBackendFactory]];
}

- (instancetype)initWithFrame:(CGRect)frame
              attributedBlocks:(NSArray<NSAttributedString *> *)blocks
    selectionPresentationBackendFactory:(IDSelectionPresentationBackendFactory)factory {
    return [self initWithFrame:frame
              attributedBlocks:blocks
               behaviorBackend:IDUIKitBehaviorBackendReference
                       resolver:[IDUIKitCapabilityResolver systemResolver]
          requestedCapabilities:
              IDBlockTextViewDefaultBehaviorCapabilities()
        selectionPresentationBackendFactory:factory];
}

- (instancetype)initWithFrame:(CGRect)frame
              attributedBlocks:(NSArray<NSAttributedString *> *)blocks
               behaviorBackend:(IDUIKitBehaviorBackend)backend
                       resolver:(IDUIKitCapabilityResolver *)resolver
          requestedCapabilities:(IDUIKitBehaviorCapabilities)capabilities
    selectionPresentationBackendFactory:
        (IDSelectionPresentationBackendFactory)factory {
    IDBlockTextViewValidateBlocks(blocks);
    if (factory == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Selection presentation backend factory is nil"];
    }
    if (resolver == nil) {
        [NSException raise:NSInvalidArgumentException
                    format:@"UIKit capability resolver is nil"];
    }
    if (backend != IDUIKitBehaviorBackendReference &&
        backend != IDUIKitBehaviorBackendMinimalKernel) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Unknown UIKit behavior backend: %lu",
                           (unsigned long)backend];
    }
    self = [super initWithFrame:frame];
    if (self == nil) {
        return nil;
    }
    _id_behaviorBackend = backend;
    _id_behaviorResolver = resolver;
    _id_requestedBehaviorCapabilities = capabilities;
    _id_previousCanonicalSelection =
        NSMakeRange(NSNotFound, 0);
    _id_latestCanonicalSelection =
        NSMakeRange(NSNotFound, 0);
    _id_activeAutoscrollEndpoint =
        IDVerticalAutoscrollSelectionEndpointEnd;

    _font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _textColor = UIColor.labelColor;
    _textContainerInset = UIEdgeInsetsMake(8, 5, 8, 5);
    _editable = YES;
    _selectable = YES;
    _autocapitalizationType = UITextAutocapitalizationTypeSentences;
    _autocorrectionType = UITextAutocorrectionTypeDefault;
    _spellCheckingType = UITextSpellCheckingTypeDefault;
    _smartQuotesType = UITextSmartQuotesTypeDefault;
    _smartDashesType = UITextSmartDashesTypeDefault;
    _smartInsertDeleteType = UITextSmartInsertDeleteTypeDefault;
    _inlinePredictionType = UITextInlinePredictionTypeDefault;
    _mathExpressionCompletionType = UITextMathExpressionCompletionTypeDefault;
    _keyboardType = UIKeyboardTypeDefault;
    _keyboardAppearance = UIKeyboardAppearanceDefault;
    _returnKeyType = UIReturnKeyDefault;
    _enablesReturnKeyAutomatically = NO;
    _secureTextEntry = NO;
    _writingToolsBehavior = UIWritingToolsBehaviorDefault;
    _allowedWritingToolsResultOptions = UIWritingToolsResultDefault;
    _allowsNumberPadPopover = YES;
    _pasteConfiguration = [[UIPasteConfiguration alloc]
        initWithTypeIdentifiersForAcceptingClass:NSString.class];
    [_pasteConfiguration addAcceptableTypeIdentifiers:@[@"public.rtf"]];
    _pasteDelegate = (id<UITextPasteDelegate>)self;

    NSDictionary<NSAttributedStringKey, id> *defaultAttributes = @{
        NSFontAttributeName: _font,
        NSForegroundColorAttributeName: _textColor,
    };
    IDInlineTextStyleResolver *styleResolver =
        [[IDInlineTextStyleResolver alloc] initWithDefaultFont:_font];
    NSMutableArray<NSAttributedString *> *normalizedBlocks =
        [NSMutableArray arrayWithCapacity:blocks.count];
    for (NSAttributedString *block in blocks) {
        [normalizedBlocks addObject:
            [styleResolver importAttributedString:block]];
    }
    defaultAttributes =
        [styleResolver attributesByApplyingTraits:0
                                      toAttributes:defaultAttributes];
    IDBlockDocument *document = [[IDBlockDocument alloc]
        initWithAttributedBlocks:normalizedBlocks
               defaultAttributes:defaultAttributes];
    IDCanonicalTextStorageAdapter *adapter =
        IDCanonicalTextStorageAdapterCreate(document);
    IDBlockStackCanvasView *blockStack = [[IDBlockStackCanvasView alloc]
        initWithDocument:document];
    CGFloat width = MAX(CGRectGetWidth(frame) -
                        _textContainerInset.left - _textContainerInset.right,
                        0);
    [blockStack updateForDocumentChange:nil width:width];
    IDRichTextLayoutController *richController = [[IDRichTextLayoutController alloc]
        initWithDocument:document
        textStorageAdapter:adapter
        blockStack:blockStack];

    id inputController = nil;
    IDUIKitInputControllerCapability *behaviorInput = nil;
    IDUIKitBehaviorKernel *behaviorKernel = nil;
    @try {
        [richController id_attachInteractionTextView:blockStack];
        if (backend == IDUIKitBehaviorBackendReference) {
            [self.class id_requireReferenceCompatibleRuntime];
            // Installed here, beside its two siblings, rather than from +load.
            //
            // All three add a private protocol to this class through the runtime's add-protocol
            // call, and all three @throw when the runtime does not match. From +load that throw is
            // UNCATCHABLE — it runs before main(), so a host whose private-API landscape has
            // shifted dies at launch with no recourse. Here it lands in the @catch below, which
            // already tears a partially built editor down, so the failure is a failed CONSTRUCTION
            // that a host can gate on.
            //
            // Initializer time is early enough: adding the protocol mutates the class, and UIKit
            // only asks whether the class conforms when a view becomes a text client — which
            // happens at becomeFirstResponder, after this returns.
            //
            // (The runtime call is named in prose rather than spelled literally. Two source scans —
            // IDProjectSmokeTests and IDPrivateSurfaceManifestTests — forbid its literal spelling
            // anywhere under TextView/, to catch a private-runtime call escaping PrivateUIKit, and
            // both read raw file text, so a comment trips them exactly like a real call would.)
            [IDPrivateUIKit installKeyboardInputSupportOnClass:self.class];
            [IDPrivateUIKit installTextPasteSupportOnClass:self.class];
            [IDPrivateUIKit installTextAutoscrollingSupportOnClass:self.class];
            IDPrivateRequireRichLayoutController(
                richController,
                @"Rich layout-controller construction preflight");
            inputController =
                IDPrivateNewInputControllerWithRichLayoutController(
                    richController,
                    self);
            [IDPrivateUIKit requireObject:inputController
                                    stage:@"Rich input-controller creation"];
            NSError *behaviorError = nil;
            behaviorInput = [[IDUIKitInputControllerCapability alloc]
                initAdoptingPrivateController:inputController
                                     contract:
                    IDPrivateRichInputControllerContract()
                                     resolver:
                    [IDUIKitCapabilityResolver systemResolver]
                                        error:&behaviorError];
            if (behaviorInput == nil) {
                @throw [NSException
                    exceptionWithName:NSInternalInconsistencyException
                               reason:behaviorError.localizedDescription ?:
                        @"The UIKit input-controller capability was rejected."
                             userInfo:nil];
            }
        } else {
            _id_document = document;
            _id_textStorageAdapter = adapter;
            _id_blockStack = blockStack;
            _id_richLayoutController = richController;
            NSError *behaviorError = nil;
            behaviorKernel = [[IDUIKitBehaviorKernel alloc]
                initWithManifest:IDUIKitBehaviorRuntimeManifest()
                         resolver:resolver
                 layoutController:richController
                         delegate:self
                             view:self
            requestedCapabilities:capabilities
                            error:&behaviorError];
            if (behaviorKernel == nil) {
                @throw [NSException
                    exceptionWithName:NSInternalInconsistencyException
                               reason:behaviorError.localizedDescription ?:
                        @"The minimal UIKit behavior kernel was rejected."
                             userInfo:nil];
            }
            behaviorInput = behaviorKernel.inputController;
            inputController = behaviorInput.privateController;
        }
        [self id_preflightInputController:behaviorInput];

        _id_document = document;
        _id_textStorageAdapter = adapter;
        _id_blockStack = blockStack;
        _id_richLayoutController = richController;
        _id_inputController = inputController;
        _id_behaviorInput = behaviorInput;
        _id_behaviorKernel = behaviorKernel;
        _id_behaviorReport = behaviorKernel.report;
        _id_inlineTextStyleResolver = styleResolver;
        BOOL typingCapabilityIsActive = backend ==
            IDUIKitBehaviorBackendReference;
        for (IDUIKitCapabilityReport *report
                 in behaviorKernel.report.capabilities) {
            if ([report.identifier isEqualToString:@"typingAttributes"]) {
                typingCapabilityIsActive =
                    report.state == IDUIKitCapabilityStateActive;
                break;
            }
        }
        if (typingCapabilityIsActive) {
            [behaviorInput setAllowedTypingAttributeNames:
                [NSSet setWithArray:@[
                    NSFontAttributeName,
                    // Travels WITH the font, and must: it is the face the trait pass derives from,
                    // so a typed character carrying `.font` without it has a font with no recorded
                    // base. Left out, every typed character drifted from what the bridge renders and
                    // the host's settle stamped it back — a presentation restyle, per keystroke,
                    // which registers an undo entry and so breaks UIKit's typing coalescing.
                    IDInlineTextBaseFontAttributeName,
                    NSForegroundColorAttributeName,
                    IDInlineTextBoldAttributeName,
                    IDInlineTextItalicAttributeName,
                    IDInlineTextUnderlineAttributeName,
                    IDInlineTextStrikethroughAttributeName,
                ]]];
            behaviorInput.typingAttributes = defaultAttributes;
        }
        _id_inlineTextFormattingController =
            [[IDInlineTextFormattingController alloc]
                initWithHost:self
                    document:document
                 textStorage:adapter
               styleResolver:styleResolver];
        [self id_syncTextInputTraits];
        id<IDSelectionPresentationBackend> presentationBackend = factory(self);
        if (presentationBackend == nil) {
            [NSException raise:NSInvalidArgumentException
                        format:@"Selection presentation backend factory returned nil"];
        }
        _id_selectionPresentationBackend = presentationBackend;
        __weak IDBlockTextView *weakSelf = self;
        adapter.documentChangeHandler = ^(IDBlockDocumentChange *change) {
            [weakSelf id_reconcileDerivedStateForDocumentChange:change];
            [weakSelf id_resetTypingAttributesIfDocumentIsEmpty];
            [weakSelf.id_inlineTextFormattingController
                documentDidChange:change];
        };

        self.alwaysBounceVertical = YES;
        // A CONTENT TOUCH IS NOT HELD BACK. UIScrollView delays one by ~150ms while it decides
        // whether the gesture is a scroll, and everything this view's content does with a touch is
        // then that late: the caret, and — measured on device — catching a placed run that is
        // moving. A coast lasts long enough to survive the delay, a rubber band (~300ms) often does
        // not, so a bouncing table could not be caught while a coasting one could (K3, 2026-09-12).
        // The pan can still CANCEL a delivered touch once it decides the gesture is a scroll, which
        // is what `canCancelContentTouches` leaves in place.
        self.delaysContentTouches = NO;
        self.backgroundColor = UIColor.clearColor;
        [blockStack id_setCanvasHost:self];
        [self addSubview:blockStack];
        [self id_reconcileDerivedState];
        [self id_installInteractionAssistant];
        [self id_updateSelectionPresentation];
    } @catch (NSException *exception) {
        [_id_interactionCapability
            clearGestureRecognizersForced:YES];
        [_id_selectionPresentationBackend tearDown];
        _id_selectionPresentationBackend = nil;
        _id_interactionAssistant = nil;
        _id_interactionCapability = nil;
        [blockStack id_setCanvasHost:nil];
        [blockStack removeFromSuperview];
        if (behaviorKernel != nil) {
            [behaviorKernel detach];
        } else if (behaviorInput != nil) {
            [behaviorInput detach];
        } else if (inputController != nil) {
            IDPrivateInputDetachFromLayoutManager(inputController);
        }
        [richController id_detachFromTextInputController];
        [richController id_detachInteractionTextView];
        @throw exception;
    }
    return self;
}

- (void)id_tearDownEditorGraph {
    [self id_cancelVerticalAutoscrollSession];
    if (_id_behaviorKernel != nil) {
        [_id_behaviorKernel detach];
        _id_behaviorReport = _id_behaviorKernel.report;
    } else {
        [_id_interactionCapability detach];
        [_id_behaviorInput detach];
    }
    IDPrivateTextAutoscrollInvalidate(_id_textAutoscroll);
    _id_textAutoscroll = nil;
    [_id_selectionPresentationBackend tearDown];
    _id_selectionPresentationBackend = nil;
    _id_interactionAssistant = nil;
    _id_interactionCapability = nil;
    [_id_blockStack id_setCanvasHost:nil];
    [_id_blockStack removeFromSuperview];
    [_id_richLayoutController id_detachFromTextInputController];
    [_id_richLayoutController id_detachInteractionTextView];
    _id_textStorageAdapter.documentChangeHandler = nil;
    _inlineTextTraitStateDidChangeHandler = nil;
    _id_inlineTextFormattingController = nil;
    _id_inlineTextStyleResolver = nil;
    _id_behaviorKernel = nil;
    _id_behaviorInput = nil;
    _id_inputController = nil;
    _id_richLayoutController = nil;
    _id_textStorageAdapter = nil;
    _id_blockStack = nil;
    _id_document = nil;
}

- (void)dealloc {
    [self id_tearDownEditorGraph];
}

- (IDBlockStackCanvasView *)id_blockStackCanvasView {
    return self.id_blockStack;
}

- (id)id_layoutController {
    return self.id_richLayoutController;
}

- (void)id_preflightInputController:
    (IDUIKitInputControllerCapability *)controller {
    [controller preflightBackwardDeleteRanges];
}

- (BOOL)canBecomeFirstResponder {
    return self.userInteractionEnabled && (self.isEditable || self.isSelectable);
}

- (void)setEditable:(BOOL)editable {
    if (!editable) {
        [self id_cancelVerticalAutoscrollSession];
    }
    if (_editable == editable) {
        return;
    }
    [self resignFirstResponder];
    _editable = editable;
    [self id_updateSelectionGestures];
    if (!editable) {
        IDPrivateRecordFloatingLifecycleEventForUITesting(self, @"editableOff");
    }
}

- (void)setSelectable:(BOOL)selectable {
    if (!selectable) {
        [self id_cancelVerticalAutoscrollSession];
    }
    if (_selectable == selectable) {
        return;
    }
    _selectable = selectable;
    if (!selectable) {
        IDUIKitInteractionCapability *interaction =
            _id_interactionCapability;
        [self resignFirstResponder];
        [interaction clearGestureRecognizersForced:YES];
        [interaction clearGestureRecognizersForced:NO];
        [interaction detach];
        if (_editable) {
            [self willChangeValueForKey:@"editable"];
            _editable = NO;
            [self didChangeValueForKey:@"editable"];
        }
        self.id_interactionAssistant = nil;
        self.id_interactionCapability = nil;
        IDPrivateRecordFloatingLifecycleEventForUITesting(self, @"selectableOff");
    } else {
        [self id_installInteractionAssistant];
        [self id_updateSelectionGestures];
    }
}

- (BOOL)becomeFirstResponder {
    BOOL wasFirstResponder = self.isFirstResponder;
    BOOL became = [super becomeFirstResponder];
    if (became && !wasFirstResponder) {
        [self.id_interactionCapability
            setSelectionActive:YES visible:YES];
        [self id_updateSelectionPresentation];
        // Here as well as on a selection CHANGE: focus can arrive with the caret already in an empty
        // block, in which case nothing changes and the first keystroke would take the document's
        // defaults rather than that block's own attributes.
        [self id_adoptEmptyBlockTypingAttributesIfNeeded];
    }
    return became;
}

- (BOOL)resignFirstResponder {
    [self id_cancelVerticalAutoscrollSession];
    BOOL wasFirstResponder = self.isFirstResponder;
    BOOL resigned = [super resignFirstResponder];
    if (resigned && wasFirstResponder) {
        [self.id_interactionCapability
            setSelectionActive:NO visible:NO];
        [self id_updateSelectionGestures];
        IDPrivateRecordFloatingLifecycleEventForUITesting(self, @"responderLoss");
    }
    return resigned;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window == nil) {
        [self id_cancelVerticalAutoscrollSession];
    }
}

- (NSString *)text {
    return self.id_textStorageAdapter.string ?: @"";
}

- (NSString *)accessibilityValue {
    return self.text;
}

- (NSArray<NSAttributedString *> *)attributedBlocks {
    NSMutableArray<NSAttributedString *> *blocks = [NSMutableArray array];
    for (IDBlock *block in self.id_document.blocks) {
        [blocks addObject:block.attributedText];
    }
    return blocks.copy;
}

- (void)setText:(NSString *)text {
    NSString *plainText = text ?: @"";
    NSAttributedString *replacement = [[NSAttributedString alloc]
        initWithString:plainText
            attributes:self.id_document.defaultAttributes];
    [self.id_textStorageAdapter
        replaceCharactersInRange:NSMakeRange(0, self.id_textStorageAdapter.length)
            withAttributedString:replacement];
    [self id_reconcileDerivedState];
}

- (void)id_applyCanonicalDefaults {
    NSMutableDictionary<NSAttributedStringKey, id> *defaults =
        self.id_document.defaultAttributes.mutableCopy;
    defaults[NSFontAttributeName] = self.font;
    defaults[NSForegroundColorAttributeName] = self.textColor;
    IDInlineTextStyleResolver *resolver =
        self.id_inlineTextStyleResolver;
    NSDictionary<NSAttributedStringKey, id> *resolvedDefaults =
        [resolver attributesByApplyingDefaultFont:self.font
                                        textColor:self.textColor
                                     toAttributes:defaults];
    IDBlockDocumentChange *defaultsChange =
        [self.id_document id_setDefaultAttributes:resolvedDefaults];
    if (defaultsChange != nil) {
        [self id_reconcileDerivedStateForDocumentChange:defaultsChange];
    }
    UIFont *font = self.font;
    UIColor *textColor = self.textColor;
    [self.id_textStorageAdapter
        id_transformTextAttributesInCanonicalRange:
            NSMakeRange(0, self.id_textStorageAdapter.length)
        usingBlock:^NSDictionary<NSAttributedStringKey, id> *(
            NSDictionary<NSAttributedStringKey, id> *attributes) {
        return [resolver attributesByApplyingDefaultFont:font
                                               textColor:textColor
                                            toAttributes:attributes];
    }];
    [self id_reconcileDerivedState];
    NSMutableDictionary<NSAttributedStringKey, id> *typingAttributes =
        self.id_behaviorInput.typingAttributes.mutableCopy ?:
            [NSMutableDictionary dictionary];
    self.id_behaviorInput.typingAttributes =
        [resolver attributesByApplyingDefaultFont:self.font
                                        textColor:self.textColor
                                     toAttributes:typingAttributes];
}

- (void)setFont:(UIFont *)font {
    if (_font == font || [_font isEqual:font]) {
        return;
    }
    _font = font;
    if (self.id_document != nil) {
        [self id_applyCanonicalDefaults];
    }
}

- (void)setTextColor:(UIColor *)textColor {
    if (_textColor == textColor || [_textColor isEqual:textColor]) {
        return;
    }
    _textColor = textColor;
    if (self.id_document != nil) {
        [self id_applyCanonicalDefaults];
    }
}

- (NSDictionary<NSUUID *, NSValue *> *)blockInsets {
    return self.id_blockStack.blockInsets;
}

- (void)setBlockInsets:(NSDictionary<NSUUID *, NSValue *> *)blockInsets {
    if (self.id_blockStack.blockInsets == blockInsets ||
        [self.id_blockStack.blockInsets isEqualToDictionary:blockInsets]) {
        return;
    }
    self.id_blockStack.blockInsets = blockInsets;
    [self id_reconcileDerivedState];
}

- (NSDictionary<NSUUID *, NSValue *> *)selectionBoxes {
    return self.id_blockStack.selectionBoxes;
}

- (void)setSelectionBoxes:(NSDictionary<NSUUID *, NSValue *> *)selectionBoxes {
    // No `id_reconcileDerivedState`, unlike every other keyed dictionary here: a column changes
    // where a SELECTION is drawn and nothing about where a block is laid out. Laying out again
    // would re-enter the host pass that assigns this, which runs from `-layoutSubviews`.
    self.id_blockStack.selectionBoxes = selectionBoxes;
}

- (NSDictionary<NSUUID *, NSValue *> *)blockFrames {
    return self.id_blockStack.blockFrames;
}

- (void)setBlockFrames:(NSDictionary<NSUUID *, NSValue *> *)blockFrames {
    if (self.id_blockStack.blockFrames == blockFrames ||
        [self.id_blockStack.blockFrames isEqualToDictionary:blockFrames]) {
        return;
    }
    self.id_blockStack.blockFrames = blockFrames;
    [self id_reconcileDerivedState];
}

- (NSDictionary<NSUUID *, NSValue *> *)placedRunClipOutsets {
    return self.id_blockStack.placedRunClipOutsets;
}

- (void)setPlacedRunClipOutsets:(NSDictionary<NSUUID *, NSValue *> *)outsets {
    if (self.id_blockStack.placedRunClipOutsets == outsets ||
        [self.id_blockStack.placedRunClipOutsets isEqualToDictionary:outsets]) {
        return;
    }
    self.id_blockStack.placedRunClipOutsets = outsets;
    [self id_reconcileDerivedState];
}

- (BOOL)id_hasPlacedRunInFlight {
    return [self.id_blockStack id_hasPlacedRunInFlight];
}

- (BOOL)id_isPlacedRunInFlightForView:(UIView *)view {
    return [self.id_blockStack id_isPlacedRunInFlightForView:view];
}

- (NSDictionary<NSUUID *, NSValue *> *)placedRunColumnOutsets {
    return self.id_blockStack.placedRunColumnOutsets;
}

- (void)setPlacedRunColumnOutsets:(NSDictionary<NSUUID *, NSValue *> *)outsets {
    if (self.id_blockStack.placedRunColumnOutsets == outsets ||
        [self.id_blockStack.placedRunColumnOutsets isEqualToDictionary:outsets]) {
        return;
    }
    self.id_blockStack.placedRunColumnOutsets = outsets;
    [self id_reconcileDerivedState];
}

- (NSSet<NSUUID *> *)placedRunStarts {
    return self.id_blockStack.placedRunStarts;
}

- (void)setPlacedRunStarts:(NSSet<NSUUID *> *)starts {
    if (self.id_blockStack.placedRunStarts == starts ||
        [self.id_blockStack.placedRunStarts isEqualToSet:starts]) {
        return;
    }
    self.id_blockStack.placedRunStarts = starts;
    [self id_reconcileDerivedState];
}

- (CGSize)id_usedSizeForBlockAtIndex:(NSUInteger)index {
    NSArray<IDBlockLayout *> *layouts = self.id_blockStack.blockLayouts;
    if (index >= layouts.count) {
        return CGSizeZero;
    }
    return layouts[index].usedSize;
}

- (UIView *)id_placedRunContentViewForBlockAtIndex:(NSUInteger)index {
    NSArray<IDBlockLayout *> *layouts = self.id_blockStack.blockLayouts;
    if (index >= layouts.count) {
        return nil;
    }
    return [self.id_blockStack placedRunContentViewForBlockIdentifier:layouts[index].blockIdentifier];
}

- (CGFloat)id_placedRunContentOffsetForBlockAtIndex:(NSUInteger)index {
    NSArray<IDBlockLayout *> *layouts = self.id_blockStack.blockLayouts;
    if (index >= layouts.count) {
        return 0;
    }
    return [self.id_blockStack placedRunContentOffsetForBlockIdentifier:layouts[index].blockIdentifier];
}

- (void)id_setPlacedRunContentOffset:(CGFloat)offset forBlockAtIndex:(NSUInteger)index {
    NSArray<IDBlockLayout *> *layouts = self.id_blockStack.blockLayouts;
    if (index >= layouts.count) {
        return;
    }
    [self.id_blockStack setPlacedRunContentOffset:offset forBlockIdentifier:layouts[index].blockIdentifier];
}

- (NSDictionary<NSUUID *, NSDictionary<NSAttributedStringKey, id> *> *)
    id_emptyLineAttributesByBlock {
    return self.id_blockStack.emptyLineAttributesByBlock;
}

- (void)setId_emptyLineAttributesByBlock:
    (NSDictionary<NSUUID *, NSDictionary<NSAttributedStringKey, id> *> *)attributes {
    if (self.id_blockStack.emptyLineAttributesByBlock == attributes) {
        return;
    }
    self.id_blockStack.emptyLineAttributesByBlock = attributes;
    // Reconciled, exactly as a `lineFragmentPadding` change is: these are consumed by the per-block
    // pass in `-updateForDocumentChange:width:`, which nothing else on this path would re-run.
    [self id_reconcileDerivedState];
}

- (NSDictionary<NSUUID *, NSNumber *> *)id_emptyLineCaretOffsetsByBlock {
    return self.id_blockStack.emptyLineCaretOffsetsByBlock;
}

- (void)setId_emptyLineCaretOffsetsByBlock:(NSDictionary<NSUUID *, NSNumber *> *)offsets {
    if (self.id_blockStack.emptyLineCaretOffsetsByBlock == offsets) {
        return;
    }
    self.id_blockStack.emptyLineCaretOffsetsByBlock = offsets;
    [self id_reconcileDerivedState];
}

- (NSDictionary<NSAttributedStringKey, id> *(^)(NSUUID *))id_emptyLineAttributesProvider {
    return self.id_blockStack.emptyLineAttributesProvider;
}

- (void)setId_emptyLineAttributesProvider:(NSDictionary<NSAttributedStringKey, id> *(^)(NSUUID *))provider {
    self.id_blockStack.emptyLineAttributesProvider = provider;
    [self id_reconcileDerivedState];
}

- (NSNumber *(^)(NSUUID *))id_emptyLineCaretOffsetProvider {
    return self.id_blockStack.emptyLineCaretOffsetProvider;
}

- (void)setId_emptyLineCaretOffsetProvider:(NSNumber *(^)(NSUUID *))provider {
    self.id_blockStack.emptyLineCaretOffsetProvider = provider;
    [self id_reconcileDerivedState];
}

- (void)id_setAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
        inCanonicalRange:(NSRange)range {
    NSUInteger length = self.id_textStorageAdapter.length;
    if (range.location > length || NSMaxRange(range) > length || range.length == 0) {
        return;
    }
    [self.id_textStorageAdapter setAttributes:attributes range:range];
}

- (CGFloat)lineFragmentPadding {
    return self.id_blockStack.lineFragmentPadding;
}

- (void)setLineFragmentPadding:(CGFloat)lineFragmentPadding {
    if (self.id_blockStack.lineFragmentPadding == lineFragmentPadding) {
        return;
    }
    self.id_blockStack.lineFragmentPadding = lineFragmentPadding;
    [self id_reconcileDerivedState];
}

- (void)setTextContainerInset:(UIEdgeInsets)textContainerInset {
    if (UIEdgeInsetsEqualToEdgeInsets(_textContainerInset, textContainerInset)) {
        return;
    }
    _textContainerInset = textContainerInset;
    [self id_reconcileDerivedState];
}

- (void)id_reloadInputViewsForChangedTrait {
    if (_id_deferringTraitReload) {
        _id_traitReloadOwed = YES;
        return;
    }
    if (self.isFirstResponder) {
        [self reloadInputViews];
    }
}

- (void)id_updateTextInputTraits:(void (NS_NOESCAPE ^)(void))updates {
    if (_id_deferringTraitReload) {
        updates();
        return;
    }
    _id_deferringTraitReload = YES;
    _id_traitReloadOwed = NO;
    updates();
    _id_deferringTraitReload = NO;
    if (_id_traitReloadOwed) {
        _id_traitReloadOwed = NO;
        [self id_reloadInputViewsForChangedTrait];
    }
}

- (void)id_syncTextInputTraits {
    if (self.id_inputController != nil) {
        IDPrivateSynchronizeTextInputTraits(self.id_inputController, self);
    }
}

#define ID_DEFINE_SCALAR_TRAIT_SETTER(TYPE, NAME, IVAR) \
    - (void)set##NAME:(TYPE)value {                         \
        if (IVAR == value) {                               \
            return;                                        \
        }                                                   \
        IVAR = value;                                       \
        [self id_syncTextInputTraits];                       \
        [self id_reloadInputViewsForChangedTrait];           \
    }

ID_DEFINE_SCALAR_TRAIT_SETTER(UITextAutocapitalizationType,
                              AutocapitalizationType,
                              _autocapitalizationType)
ID_DEFINE_SCALAR_TRAIT_SETTER(UITextAutocorrectionType, AutocorrectionType, _autocorrectionType)
- (void)setSpellCheckingType:(UITextSpellCheckingType)value {
    if (_spellCheckingType == value) {
        return;
    }
    _spellCheckingType = value;
    [self id_syncTextInputTraits];
    // `Default` restores the controller's own setting, recorded before this setter first changed
    // it. Reading `Default` as off made a No -> Default round trip (a caret leaving a code block)
    // switch checking off for good.
    if (!_id_hasRecordedDefaultContinuousSpellChecking) {
        _id_defaultContinuousSpellChecking =
            self.id_behaviorInput.id_isContinuousSpellCheckingEnabled;
        _id_hasRecordedDefaultContinuousSpellChecking = YES;
    }
    BOOL enabled = _id_defaultContinuousSpellChecking;
    if (value == UITextSpellCheckingTypeYes) {
        enabled = YES;
    } else if (value == UITextSpellCheckingTypeNo) {
        enabled = NO;
    }
    [self.id_behaviorInput id_setContinuousSpellCheckingEnabled:enabled];
    [self id_reloadInputViewsForChangedTrait];
}
ID_DEFINE_SCALAR_TRAIT_SETTER(UITextSmartQuotesType, SmartQuotesType, _smartQuotesType)
ID_DEFINE_SCALAR_TRAIT_SETTER(UITextSmartDashesType, SmartDashesType, _smartDashesType)
ID_DEFINE_SCALAR_TRAIT_SETTER(UITextSmartInsertDeleteType,
                              SmartInsertDeleteType,
                              _smartInsertDeleteType)
ID_DEFINE_SCALAR_TRAIT_SETTER(UITextInlinePredictionType,
                              InlinePredictionType,
                              _inlinePredictionType)
ID_DEFINE_SCALAR_TRAIT_SETTER(UITextMathExpressionCompletionType,
                              MathExpressionCompletionType,
                              _mathExpressionCompletionType)
ID_DEFINE_SCALAR_TRAIT_SETTER(UIKeyboardType, KeyboardType, _keyboardType)
ID_DEFINE_SCALAR_TRAIT_SETTER(UIKeyboardAppearance, KeyboardAppearance, _keyboardAppearance)
ID_DEFINE_SCALAR_TRAIT_SETTER(UIReturnKeyType, ReturnKeyType, _returnKeyType)
ID_DEFINE_SCALAR_TRAIT_SETTER(BOOL,
                              EnablesReturnKeyAutomatically,
                              _enablesReturnKeyAutomatically)
ID_DEFINE_SCALAR_TRAIT_SETTER(BOOL, SecureTextEntry, _secureTextEntry)
ID_DEFINE_SCALAR_TRAIT_SETTER(UIWritingToolsBehavior,
                              WritingToolsBehavior,
                              _writingToolsBehavior)
ID_DEFINE_SCALAR_TRAIT_SETTER(UIWritingToolsResultOptions,
                              AllowedWritingToolsResultOptions,
                              _allowedWritingToolsResultOptions)
ID_DEFINE_SCALAR_TRAIT_SETTER(BOOL, AllowsNumberPadPopover, _allowsNumberPadPopover)

#undef ID_DEFINE_SCALAR_TRAIT_SETTER

- (void)setTextContentType:(UITextContentType)textContentType {
    if (_textContentType == textContentType || [_textContentType isEqualToString:textContentType]) {
        return;
    }
    _textContentType = [textContentType copy];
    [self id_syncTextInputTraits];
    [self id_reloadInputViewsForChangedTrait];
}

- (void)setPasswordRules:(UITextInputPasswordRules *)passwordRules {
    if (_passwordRules == passwordRules || [_passwordRules isEqual:passwordRules]) {
        return;
    }
    _passwordRules = [passwordRules copy];
    [self id_syncTextInputTraits];
    [self id_reloadInputViewsForChangedTrait];
}

- (void)setConversationContext:(UIConversationContext *)conversationContext {
    if (_conversationContext == conversationContext) {
        return;
    }
    _conversationContext = conversationContext;
    [self id_syncTextInputTraits];
    [self id_reloadInputViewsForChangedTrait];
}

- (void)id_reconcileDerivedState {
    [self id_reconcileDerivedStateForDocumentChange:nil];
}

- (void)id_reconcileDerivedStateForDocumentChange:(IDBlockDocumentChange *)change {
    CGFloat horizontalInset = self.textContainerInset.left + self.textContainerInset.right;
    CGFloat width = MAX(CGRectGetWidth(self.bounds) - horizontalInset, 0);
    self.id_blockStack.contentInsets = self.textContainerInset;
    [self.id_blockStack updateForDocumentChange:change width:width];
    [self.id_richLayoutController id_updateInteractionContainerGeometry];
    if (change != nil) {
        [self.id_richLayoutController
            id_reapplyTemporaryAttributesForDocumentChange:change];
    }

    CGSize documentSize = self.id_blockStack.documentContentSize;
    CGFloat verticalInset = self.textContainerInset.top + self.textContainerInset.bottom;
    CGFloat contentHeight = ceil(MAX(CGRectGetHeight(self.bounds),
                                     documentSize.height + verticalInset));
    // ORIGIN (0, 0), with the inset carried inside the stack. This view's geometry answers are in
    // its own coordinates and the stack is `-textInputView`, so UIKit reads them relative to the
    // stack; positioning the stack at the inset made UIKit add that inset a second time and draw the
    // caret and selection below and right of the glyphs. Equal origins make the two spaces coincide.
    // The blocks land in exactly the same visible place, because the stack now carries the offset.
    self.id_blockStack.frame = CGRectMake(0,
                                          0,
                                          MAX(CGRectGetWidth(self.bounds),
                                              documentSize.width + horizontalInset),
                                          documentSize.height + verticalInset);
    self.contentSize = CGSizeMake(CGRectGetWidth(self.bounds), contentHeight);
    [self setNeedsLayout];
    if (change != nil) {
        [self id_scrollCaretToVisibleIfNeeded];
        [self id_updateInteractionGeometry];
        // The TEXT moved, so the cursor has to move with it in this pass rather than in the timer's
        // later one. Only here: a selection-only change must NOT flush — see
        // `-id_flushSelectionDisplayUpdate`.
        self.id_selectionDisplayFlushPending = YES;
    }
}

/// Adopts an EMPTY block's host attributes as the typing attributes while the caret sits in it.
///
/// The same attributes that say what an empty line is MEASURED with have to say what is TYPED into
/// it, or the line looks right until it is used: on device, emptying a quote's author line and
/// typing again produced body text with no quote inset, because typing attributes are derived from
/// the text around the caret and an empty block has none.
///
/// Not reachable through the typed-text policy, which runs after `-insertText:` — the private input
/// controller a real keyboard drives inserts through its own replace, with a string it has already
/// built from these attributes.
- (void)id_translateTypingAttributesUsingBlock:(id _Nullable (^)(NSAttributedStringKey key, id value))translate {
    NSDictionary<NSAttributedStringKey, id> *(^translated)(NSDictionary<NSAttributedStringKey, id> *) =
        ^NSDictionary<NSAttributedStringKey, id> *(NSDictionary<NSAttributedStringKey, id> *attributes) {
        NSMutableDictionary<NSAttributedStringKey, id> *result = [attributes mutableCopy];
        [attributes enumerateKeysAndObjectsUsingBlock:^(NSAttributedStringKey key, id value, BOOL *stop) {
            id replacement = translate(key, value);
            if (replacement != nil) {
                result[key] = replacement;
            }
        }];
        return result;
    };
    NSDictionary<NSAttributedStringKey, id> *typing = self.id_behaviorInput.typingAttributes;
    if (typing.count > 0) {
        self.id_behaviorInput.typingAttributes = translated(typing);
    }
    if (self.id_compositionTypingAttributes.count > 0) {
        self.id_compositionTypingAttributes = translated(self.id_compositionTypingAttributes);
    }
}

- (void)id_adoptEmptyBlockTypingAttributesIfNeeded {
    NSDictionary<NSUUID *, NSDictionary<NSAttributedStringKey, id> *> *byBlock =
        self.id_blockStack.emptyLineAttributesByBlock;
    if (byBlock.count == 0 && self.id_blockStack.emptyLineAttributesProvider == nil) {
        return;
    }
    NSRange selection = [self id_NSRangeForTextRange:self.selectedTextRange];
    if (selection.location == NSNotFound || selection.length != 0) {
        return;
    }
    NSUInteger offset = 0;
    for (IDBlock *block in self.id_document.blocks) {
        NSUInteger end = offset + block.attributedText.length;
        if (selection.location >= offset && selection.location <= end) {
            if (block.attributedText.length == 0) {
                NSDictionary<NSAttributedStringKey, id> *intended =
                    [self.id_blockStack id_emptyLineAttributesForIdentifier:block.identifier];
                if (intended.count > 0) {
                    self.id_behaviorInput.typingAttributes = intended;
                }
            }
            return;
        }
        offset = end + 1;  // the separator
    }
}

- (void)id_selectionStateDidChange {
    self.id_selectionPresentationUpdatePending = NO;
    [self id_recordLatestCanonicalSelectionForAutoscroll];
    [self id_adoptEmptyBlockTypingAttributesIfNeeded];
    [self.id_inlineTextFormattingController selectionDidChange];
    [self.id_interactionCapability id_selectionChanged];
    [self setNeedsLayout];
    [self id_scrollCaretToVisibleIfNeeded];
    [self id_updateSelectionPresentation];
}

- (void)setDisplayDecorator:(IDBlockTextDisplayDecorator)displayDecorator {
    _displayDecorator = [displayDecorator copy];
    self.id_blockStack.displayDecorator = _displayDecorator;
    [self setNeedsLayout];
}

- (CGRect)id_attachmentFrameForCanonicalOffset:(NSUInteger)offset {
    NSArray<IDBlockLayout *> *layouts = self.id_blockStack.blockLayouts;
    NSArray<IDBlock *> *blocks = self.id_document.blocks;
    NSUInteger blockStart = 0;
    for (NSUInteger index = 0; index < blocks.count; index++) {
        NSUInteger length = blocks[index].attributedText.length;
        if (offset >= blockStart && offset < blockStart + length && index < layouts.count) {
            IDBlockLayout *layout = layouts[index];
            CGRect local = [layout attachmentFrameForLocalOffset:offset - blockStart];
            if (CGRectIsNull(local)) {
                return CGRectNull;
            }
            return [self convertRect:local fromView:layout.canvasView];
        }
        blockStart += length + 1;
    }
    return CGRectNull;
}

- (NSArray<NSValue *> *)id_rectsForCanonicalRange:(NSRange)range {
    NSMutableArray<NSValue *> *result = [NSMutableArray array];
    if (range.length == 0) {
        return result;
    }
    NSArray<IDBlockLayout *> *layouts = self.id_blockStack.blockLayouts;
    NSArray<IDBlock *> *blocks = self.id_document.blocks;
    NSUInteger blockStart = 0;
    for (NSUInteger index = 0; index < blocks.count; index++) {
        NSUInteger length = blocks[index].attributedText.length;
        NSRange blockRange = NSMakeRange(blockStart, length);
        NSRange overlap = NSIntersectionRange(range, blockRange);
        if (overlap.length > 0 && index < layouts.count) {
            IDBlockLayout *layout = layouts[index];
            NSRange local = NSMakeRange(overlap.location - blockStart, overlap.length);
            for (IDRichTextSelectionRect *selectionRect in
                     [layout selectionRectsForLocalRange:local]) {
                // Converted through the view hierarchy rather than by adding origins: the block's
                // canvas sits inside a scrolling stack, so its offset is not just its frame.
                CGRect converted = [self convertRect:selectionRect.rect
                                            fromView:layout.canvasView];
                [result addObject:[NSValue valueWithCGRect:converted]];
            }
        }
        // Blocks are separated by one canonical position.
        blockStart += length + 1;
    }
    return result;
}

- (CGRect)id_frameForBlockAtIndex:(NSUInteger)index {
    NSArray<IDBlockLayout *> *layouts = self.id_blockStack.blockLayouts;
    if (index >= layouts.count) {
        return CGRectNull;
    }
    UIView *canvasView = layouts[index].canvasView;
    // Converted through the view hierarchy rather than read off `canvasView.frame`, for the reason
    // `id_rectsForCanonicalRange:` gives: the block canvases sit inside a scrolling stack, so a
    // block's offset in THIS view is not its frame in its superview. Converting the view's own
    // `bounds` also carries the non-zero bounds origin the stack assigns each canvas.
    return [self convertRect:canvasView.bounds fromView:canvasView];
}

- (CGRect)id_selectionSlotForBlockAtIndex:(NSUInteger)index {
    NSArray<IDBlockLayout *> *layouts = self.id_blockStack.blockLayouts;
    if (index >= layouts.count) {
        return CGRectNull;
    }
    return [self.id_blockStack
        selectionSlotForBlockIdentifier:layouts[index].blockIdentifier];
}

- (CGRect)id_selectionBoxForBlockAtIndex:(NSUInteger)index {
    NSArray<IDBlockLayout *> *layouts = self.id_blockStack.blockLayouts;
    if (index >= layouts.count) {
        return CGRectNull;
    }
    return [self.id_blockStack
        selectionBoxForBlockIdentifier:layouts[index].blockIdentifier];
}

- (NSAttributedString *)id_renderedTextForBlockAtIndex:(NSUInteger)index {
    NSArray<IDBlockLayout *> *layouts = self.id_blockStack.blockLayouts;
    if (index >= layouts.count) {
        return nil;
    }
    return [layouts[index].contentStorage.textStorage copy];
}

- (void)setNeedsDisplayDecorationUpdate {
    [self.id_blockStack id_setDisplayDecorationNeedsUpdate];
    [self setNeedsLayout];
}

/// Clears pending typing formatting once the document is empty.
///
/// Typing attributes outlive the text they came from: bold the whole composer, delete it all, and the
/// next character typed is still bold although nothing on screen suggests it. That is the state a user
/// reads as "the composer is empty", so it should behave like one.
///
/// Deliberately keyed on the document being EMPTY rather than on deletion. A deletion that leaves text
/// behind must keep its formatting — the caret is still inside formatted content — and only the
/// emptied case is unambiguous.
- (void)id_resetTypingAttributesIfDocumentIsEmpty {
    if (self.id_textStorageAdapter.length != 0) {
        return;
    }
    IDUIKitInputControllerCapability *input = self.id_behaviorInput;
    if (input == nil) {
        return;
    }
    input.typingAttributes = self.id_document.defaultAttributes;
}

- (void)transformInlineAttributesUsingBlock:
    (NSDictionary<NSAttributedStringKey, id> *(^)(
        NSDictionary<NSAttributedStringKey, id> *))block {
    [self.id_inlineTextFormattingController
        transformInlineAttributesUsingBlock:block];
}

- (void)setHostAttributeValue:(nullable id)value
                       forKey:(NSAttributedStringKey)key {
    [self.id_inlineTextFormattingController setHostAttributeValue:value
                                                           forKey:key];
}

- (nullable id)hostAttributeValueForKey:(NSAttributedStringKey)key {
    return [self.id_inlineTextFormattingController
        hostAttributeValueForKey:key];
}

- (void)toggleInlineTextTrait:(IDInlineTextTraits)trait {
    [self.id_inlineTextFormattingController toggleTrait:trait];
}

- (IDInlineTextTraitState)stateForInlineTextTrait:
    (IDInlineTextTraits)trait {
    return [self.id_inlineTextFormattingController stateForTrait:trait];
}

- (IDInlineTextTraits)effectiveInlineTextTraits {
    return [self.id_inlineTextFormattingController
        effectiveInlineTextTraits];
}

- (void)id_updateSelectionPresentation {
    if (self.id_selectionPresentationBackend == nil) {
        return;
    }
    BOOL wasPending = self.id_selectionPresentationUpdatePending;
    self.id_selectionPresentationUpdatePending = YES;
    if (!wasPending) {
        [self setNeedsLayout];
    }
}

- (void)id_schedulePendingSelectionPresentation {
    if (self.id_selectionPresentationUpdateScheduled) {
        return;
    }
    self.id_selectionPresentationUpdateScheduled = YES;
    __weak IDBlockTextView *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        IDBlockTextView *strongSelf = weakSelf;
        strongSelf.id_selectionPresentationUpdateScheduled = NO;
        if (strongSelf.id_selectionPresentationUpdatePending) {
            [strongSelf id_publishPendingSelectionPresentation];
        }
    });
}

- (BOOL)id_publishPendingSelectionPresentation {
    id<IDSelectionPresentationBackend> backend = self.id_selectionPresentationBackend;
    UITextRange *selection = self.selectedTextRange;
    if (backend == nil || selection == nil || self.id_textStorageAdapter.editedMask != 0) {
        return NO;
    }
    NSRange canonicalSelection = [self id_NSRangeForTextRange:selection];
    if (canonicalSelection.location == NSNotFound) {
        return NO;
    }
    CGRect caretRect = CGRectNull;
    NSArray<UITextSelectionRect *> *selectionRects = @[];
    if (canonicalSelection.length == 0) {
        caretRect = [self caretRectForPosition:selection.end];
        if (!IDBlockTextViewPresentationRectIsFinite(caretRect)) {
            return NO;
        }
    } else {
        selectionRects = [self.id_richLayoutController
            id_exactSelectionRectsForRange:selection
                                   fromView:self
                    forContainerPassingTest:nil];
        if (selectionRects == nil) {
            [self setNeedsLayout];
            return NO;
        }
        for (UITextSelectionRect *selectionRect in selectionRects) {
            if (!IDBlockTextViewPresentationRectIsFinite(selectionRect.rect)) {
                return NO;
            }
        }
    }
    UIEdgeInsets insets = self.adjustedContentInset;
    CGRect visibleBounds = CGRectMake(
        self.contentOffset.x + insets.left,
        self.contentOffset.y + insets.top,
        MAX(CGRectGetWidth(self.bounds) - insets.left - insets.right, 0),
        MAX(CGRectGetHeight(self.bounds) - insets.top - insets.bottom, 0));
    if (!IDBlockTextViewPresentationRectIsFinite(visibleBounds) ||
        !isfinite(self.contentOffset.x) || !isfinite(self.contentOffset.y)) {
        return NO;
    }
    IDSelectionPresentationSnapshot *snapshot = [[IDSelectionPresentationSnapshot alloc]
        initWithCanonicalSelection:canonicalSelection
        caretRect:caretRect
        selectionRects:selectionRects
        visibleBounds:visibleBounds
        contentOffset:self.contentOffset];
    self.id_selectionPresentationUpdatePending = NO;
    [backend updateWithSnapshot:snapshot];
    return YES;
}

- (void)id_scrollRectToVisible:(CGRect)target {
    UIEdgeInsets insets = self.adjustedContentInset;
    CGFloat visibleLeft = self.contentOffset.x + insets.left;
    CGFloat visibleRight = self.contentOffset.x + CGRectGetWidth(self.bounds) - insets.right;
    CGFloat visibleTop = self.contentOffset.y + insets.top;
    CGFloat visibleBottom = self.contentOffset.y + CGRectGetHeight(self.bounds) - insets.bottom;
    CGFloat targetX = self.contentOffset.x;
    CGFloat targetY = self.contentOffset.y;
    if (CGRectGetMinX(target) < visibleLeft) {
        targetX = CGRectGetMinX(target) - insets.left;
    } else if (CGRectGetMaxX(target) > visibleRight) {
        targetX = CGRectGetMaxX(target) - CGRectGetWidth(self.bounds) + insets.right;
    }
    if (CGRectGetMinY(target) < visibleTop) {
        targetY = CGRectGetMinY(target) - insets.top;
    } else if (CGRectGetMaxY(target) > visibleBottom) {
        targetY = CGRectGetMaxY(target) - CGRectGetHeight(self.bounds) + insets.bottom;
    }

    CGFloat minimumX = -insets.left;
    CGFloat maximumX = MAX(minimumX,
                           self.contentSize.width - CGRectGetWidth(self.bounds) + insets.right);
    CGFloat minimumY = -insets.top;
    CGFloat maximumY = MAX(minimumY,
                           self.contentSize.height - CGRectGetHeight(self.bounds) + insets.bottom);
    CGPoint offset = CGPointMake(MIN(MAX(targetX, minimumX), maximumX),
                                 MIN(MAX(targetY, minimumY), maximumY));
    if (!CGPointEqualToPoint(offset, self.contentOffset)) {
        [self setContentOffset:offset animated:NO];
    }
}

- (void)id_scrollCaretToVisibleIfNeeded {
    if (!self.isFirstResponder || !self.isEditable || !self.isScrollEnabled) {
        return;
    }
    UITextRange *selection = self.selectedTextRange;
    if (selection == nil || !selection.empty) {
        return;
    }
    [self setNeedsLayout];
    [self layoutIfNeeded];
    CGRect caret = [self caretRectForPosition:selection.end];
    if (CGRectIsNull(caret) || !isfinite(caret.origin.x) || !isfinite(caret.origin.y) ||
        !isfinite(caret.size.width) || !isfinite(caret.size.height)) {
        return;
    }
    UIEdgeInsets insets = self.adjustedContentInset;
    CGRect visible = CGRectMake(self.contentOffset.x + insets.left,
                                self.contentOffset.y + insets.top,
                                MAX(CGRectGetWidth(self.bounds) - insets.left - insets.right, 0),
                                MAX(CGRectGetHeight(self.bounds) - insets.top - insets.bottom, 0));
    if (!CGRectContainsRect(visible, caret)) {
        [self id_scrollRectToVisible:caret];
    }
}

- (void)id_canvasDidLayout {
    [self.id_selectionPresentationBackend placeSelectionContainerView];
    self.id_selectionPresentationUpdatePending = YES;
    [self id_schedulePendingSelectionPresentation];
}

- (void)id_updateInteractionGeometry {
    [self.id_interactionCapability
        id_setNeedsSelectionDisplayUpdate];
    [self id_updateSelectionPresentation];
}

/// Applies UIKit's PENDING selection-display update inside this layout pass, instead of leaving it
/// to the run-loop timer UIKit schedules for it.
///
/// **The caret is otherwise drawn one run-loop iteration behind the glyphs.** Marking the selection
/// display dirty — `-[UITextInteractionAssistant setNeedsSelectionDisplayUpdate]`, which this class
/// calls from `-id_updateInteractionGeometry` — reaches
/// `-[UITextSelectionDisplayInteraction setNeedsSelectionUpdate]`, and that method updates nothing:
/// it sets a pending flag and schedules
/// `_updateSelectionIfNeededResettingBlinkingAnimation:` through
/// `-performSelector:withObject:afterDelay:inModes:` with a delay of 0 in `kCFRunLoopCommonModes`
/// (disassembled on iOS 26.5 / 23F73, arguments read from the live call site). A zero-delay timer
/// cannot run in the iteration that scheduled it, so the cursor can never be repositioned by the
/// CoreAnimation commit that draws the text it belongs to.
///
/// `-[UITextInteractionAssistant selectionChanged]` has a synchronous arm, but only
/// `activeSelection.isCommitting`, `expectingCommit` or `requiresImmediateUpdate` reach it, and the
/// last of those is a hardcoded `return NO` on the assistant. A TAP satisfies the first (it runs
/// inside `-[UITextSelection commit]`) — which is why placing the caret never lagged — and TYPING
/// satisfies none of them. **A stock UIKit text view takes the deferred arm too**, measured with a
/// breakpoint on each arm; it does not lag because UIKit's own text-layout canvas rescues it: that
/// canvas posts a viewport-layout notification at the end of its `-layoutSubviews` which
/// `-[UITextSelectionDisplayInteraction _trackingViewportDidLayout:]` observes and answers with
/// `_updateSelectionIfNeeded`, inside the commit. A text input that draws its own canvas posts
/// nothing, so only the timer is left. (The classes and selectors on that rescue path are named in
/// the test and in the telegram-ios notes; this file is source-scanned and may not spell them.)
///
/// Measured before this call existed: a synchronous `-insertText:` advanced `caretRectForPosition:`
/// by 16pt and left the cursor view's frame exactly where it was, and one `-layoutManagedSubviews`
/// moved it onto the caret. The same probe against a stock UIKit text view found its cursor correct
/// when `-insertText:` returned.
///
/// **It costs no extra work.** `-layoutManagedSubviews` forces the pending flag on and runs the
/// same gated body, and that body CLEARS the flag (`strb wzr, [x20, #0x14]`), so a timer already
/// scheduled for this iteration fires into a cleared flag and returns at its guard.
///
/// **ONLY after a document change, never after a selection-only one**, which is why
/// `id_selectionDisplayFlushPending` exists rather than this being called from every layout pass.
/// `-layoutManagedSubviews` is the RESETTING entry (`…ResettingBlinkingAnimation:YES`), and run on a
/// pass that a bare selection move triggered it disturbs the anchor the keyboard-based selection
/// interaction carries between key events: the first Shift+Right then behaved as a plain Right, so
/// an extension that stock traces as `{3,0} {3,1} {3,2}…` came out `{3,0} {4,0} {4,1}…`. Caught by
/// `IDBlockTextViewUITests`'
/// `-testPublicShiftArrowExtendsReversesAndCollapsesAcrossMultipleStructuralNewlinesLikeStock`,
/// which is the reason that test compares a whole TRACE against stock rather than an end state.
/// Typing is the case that needed fixing and a selection-only change was never late: a tap takes
/// `selectionChanged`'s synchronous arm through `isCommitting`.
- (void)id_flushSelectionDisplayUpdate {
    // By class from `-interactions` rather than through the interaction assistant: the assistant's
    // reference to it is a private ivar, while the interaction itself is public API and UIKit has
    // already installed it on this view. Nothing is created here — a view UIKit has not made a text
    // client has no such interaction and nothing to flush.
    for (id<UIInteraction> interaction in self.interactions) {
        if ([interaction isKindOfClass:UITextSelectionDisplayInteraction.class]) {
            [(UITextSelectionDisplayInteraction *)interaction layoutManagedSubviews];
            return;
        }
    }
}

- (NSRange)id_NSRangeForTextRange:(UITextRange *)range {
    if (range == nil) {
        return NSMakeRange(NSNotFound, 0);
    }
    NSInteger location = [self offsetFromPosition:self.beginningOfDocument toPosition:range.start];
    NSInteger length = [self offsetFromPosition:range.start toPosition:range.end];
    return location < 0 || length < 0
        ? NSMakeRange(NSNotFound, 0)
        : NSMakeRange((NSUInteger)location, (NSUInteger)length);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat horizontalInset = self.textContainerInset.left + self.textContainerInset.right;
    CGFloat width = MAX(CGRectGetWidth(self.bounds) - horizontalInset, 0);
    self.id_blockStack.contentInsets = self.textContainerInset;
    [self.id_blockStack updateForDocumentChange:nil width:width];
    [self.id_richLayoutController id_updateInteractionContainerGeometry];
    CGSize documentSize = self.id_blockStack.documentContentSize;
    CGFloat verticalInset = self.textContainerInset.top + self.textContainerInset.bottom;
    CGFloat contentHeight = ceil(MAX(CGRectGetHeight(self.bounds),
                                     documentSize.height + verticalInset));
    // ORIGIN (0, 0), with the inset carried inside the stack. This view's geometry answers are in
    // its own coordinates and the stack is `-textInputView`, so UIKit reads them relative to the
    // stack; positioning the stack at the inset made UIKit add that inset a second time and draw the
    // caret and selection below and right of the glyphs. Equal origins make the two spaces coincide.
    // The blocks land in exactly the same visible place, because the stack now carries the offset.
    self.id_blockStack.frame = CGRectMake(0,
                                          0,
                                          MAX(CGRectGetWidth(self.bounds),
                                              documentSize.width + horizontalInset),
                                          documentSize.height + verticalInset);
    self.contentSize = CGSizeMake(CGRectGetWidth(self.bounds), contentHeight);
    [self id_canvasDidLayout];
    [self id_updateInteractionGeometry];
    // LAST, and after the mark: the line above is what makes the selection display dirty, and this
    // is what applies it before the commit this pass belongs to — but only for a pass that follows a
    // DOCUMENT change. See `-id_flushSelectionDisplayUpdate`.
    //
    // A pass that RE-WRAPS the text owes the same flush: a width change (rotation, Split View, a
    // resize the host drives) or a container-inset change moves every line, and with it the caret
    // and the highlight, while nothing about the document changed. Left to UIKit's zero-delay timer
    // the frame committed with the re-wrapped text drew the cursor and highlight at the OLD wrap
    // (harness `HarnessWidthChangeSelectionDisplayTests`; a stock UIKit text view is right when its
    // `-layoutIfNeeded` returns). Only when the geometry actually changed: a pass at the same width
    // and inset — every scroll tick, every selection move — must not run the resetting entry (the
    // Shift+Right anchor rule above). The first pass records without flushing: there is no earlier
    // drawing to correct.
    BOOL textGeometryMoved = _id_hasLaidOutTextGeometry &&
        (fabs(_id_laidOutWrapWidth - width) > 0.001 ||
         !UIEdgeInsetsEqualToEdgeInsets(_id_laidOutTextContainerInset, self.textContainerInset));
    _id_hasLaidOutTextGeometry = YES;
    _id_laidOutWrapWidth = width;
    _id_laidOutTextContainerInset = self.textContainerInset;
    if (self.id_selectionDisplayFlushPending || textGeometryMoved) {
        self.id_selectionDisplayFlushPending = NO;
        [self id_flushSelectionDisplayUpdate];
    }
}

@end

#endif
