#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDBlockTextView.h"
#import "IDSelectionPresentation.h"
#import "IDVerticalAutoscrollGeometry.h"
#import "IDUIKitBehaviorBackend.h"
#import "IDUIKitBehaviorCapabilities.h"

@class IDBlockDocument;
@class IDBlockDocumentChange;
@class IDBlockStackCanvasView;
@class IDCanonicalTextStorageAdapter;
@class IDInlineTextFormattingController;
@class IDInlineTextStyleResolver;
@class IDRichTextLayoutController;
@class IDUIKitBehaviorKernel;
@class IDUIKitBehaviorReport;
@class IDUIKitCapabilityResolver;
@class IDUIKitInputControllerCapability;
@class IDUIKitInteractionCapability;
@protocol IDSelectionPresentationBackend;

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(18.4))
@interface IDBlockTextView ()

@property(nonatomic, strong, nullable, readwrite) IDBlockDocument *id_document;
@property(nonatomic, strong, nullable, readwrite) IDCanonicalTextStorageAdapter *id_textStorageAdapter;
@property(nonatomic, strong, nullable, readwrite) IDBlockStackCanvasView *id_blockStack;
@property(nonatomic, strong, nullable, readonly) IDBlockStackCanvasView *id_blockStackCanvasView;
@property(nonatomic, strong, nullable, readwrite) IDRichTextLayoutController *id_richLayoutController;
@property(nonatomic, strong, nullable, readonly) id id_layoutController;
@property(nonatomic, readonly) IDUIKitBehaviorBackend id_behaviorBackend;
@property(nonatomic, strong, nullable, readonly)
    IDUIKitBehaviorKernel *id_behaviorKernel;
@property(nonatomic, strong, nullable, readonly)
    IDUIKitBehaviorReport *id_behaviorReport;
@property(nonatomic, strong, nullable, readonly)
    IDUIKitCapabilityResolver *id_behaviorResolver;
@property(nonatomic, readonly)
    IDUIKitBehaviorCapabilities id_requestedBehaviorCapabilities;
@property(nonatomic, strong, nullable, readwrite) id id_inputController;
@property(nonatomic, strong, nullable, readwrite)
    IDUIKitInputControllerCapability *id_behaviorInput;
@property(nonatomic, strong, nullable, readwrite) id id_interactionAssistant;
@property(nonatomic, strong, nullable, readwrite)
    IDUIKitInteractionCapability *id_interactionCapability;
@property(nonatomic, strong, nullable, readwrite)
    id<IDSelectionPresentationBackend> id_selectionPresentationBackend;
@property(nonatomic) BOOL id_selectionPresentationUpdatePending;
/// Set when an edit changed the DOCUMENT, cleared by the next layout pass, which flushes UIKit's
/// pending selection display while it is set. Scoped to text changes deliberately — see
/// `-id_flushSelectionDisplayUpdate`.
@property(nonatomic) BOOL id_selectionDisplayFlushPending;
@property(nonatomic) BOOL id_selectionPresentationUpdateScheduled;
/// The typing attributes in force when the current composition STARTED — what `insertText:` would
/// have typed its text with, over the same selection. The controller attributes marked text by its
/// own rule (over a selection it can take the replaced text's end, or nothing), so the commit
/// re-applies these before the typed-text policy. nil while no composition is open.
@property(nonatomic, copy, nullable) NSDictionary<NSAttributedStringKey, id> *id_compositionTypingAttributes;
/// Whether the current composition REPLACED A SELECTION. Typing over a selection gets the typing
/// attributes alone — the typed-text policy runs only for an insertion at a caret — so a composition
/// over a selection commits the same way.
@property(nonatomic) BOOL id_compositionReplacesSelection;
/// Set by a host that resolved the selection a composition starts over ITSELF (and so collapsed it
/// before the composition reaches this class): the composition still replaces a selection, and its
/// typing attributes are the ones the host restored from before it resolved it. Consumed by the
/// composition's start.
@property(nonatomic) BOOL id_compositionStartsOverResolvedSelection;
@property(nonatomic, strong, nullable) id id_textAutoscroll;
@property(nonatomic, strong, nullable)
    IDVerticalAutoscroll *id_verticalAutoscroll;
@property(nonatomic)
    IDVerticalAutoscrollSelectionEndpoint id_activeAutoscrollEndpoint;
@property(nonatomic) NSRange id_previousCanonicalSelection;
@property(nonatomic) NSRange id_latestCanonicalSelection;
@property(nonatomic) IDVerticalAutoscrollRampState id_autoscrollRampState;
@property(nonatomic) BOOL id_isPublishingAutoscrollSelection;
@property(nonatomic) CGFloat id_autoscrollPointReferenceOffsetY;
@property(nonatomic, strong, nullable, readwrite)
    IDInlineTextStyleResolver *id_inlineTextStyleResolver;
@property(nonatomic, strong, nullable, readwrite)
    IDInlineTextFormattingController *id_inlineTextFormattingController;

- (instancetype)initWithFrame:(CGRect)frame
              attributedBlocks:(NSArray<NSAttributedString *> *)blocks
    selectionPresentationBackendFactory:(IDSelectionPresentationBackendFactory)factory;

+ (void)id_requireReferenceCompatibleRuntime;
+ (IDSelectionPresentationBackendFactory)
    id_defaultSelectionPresentationBackendFactory;
- (instancetype)initWithFrame:(CGRect)frame
              attributedBlocks:(NSArray<NSAttributedString *> *)blocks
               behaviorBackend:(IDUIKitBehaviorBackend)backend
                       resolver:(IDUIKitCapabilityResolver *)resolver
          requestedCapabilities:(IDUIKitBehaviorCapabilities)capabilities
    selectionPresentationBackendFactory:
        (IDSelectionPresentationBackendFactory)factory;

- (void)id_preflightInputController:
    (IDUIKitInputControllerCapability *)controller;
- (void)id_syncTextInputTraits;
- (void)id_reloadInputViewsForChangedTrait;
- (void)id_reconcileDerivedState;
- (void)id_reconcileDerivedStateForDocumentChange:(nullable IDBlockDocumentChange *)change;
- (void)id_selectionStateDidChange;
/// Adopts an EMPTY caret block's host attributes (provider first, then the pushed map) as the
/// typing attributes; a no-op when the caret's block has text or the host has no answer.
- (void)id_adoptEmptyBlockTypingAttributesIfNeeded;
/// Rewrites each typing-attribute value — the input controller's, and those an open composition's
/// commit re-applies (`id_compositionTypingAttributes`) — to what `translate` answers for it (nil
/// keeps it). For a host that re-renders presentation in place; see the Telegram host's
/// `tgid_translateTypingAttributesUsingBlock:`.
- (void)id_translateTypingAttributesUsingBlock:(id _Nullable (^)(NSAttributedStringKey key, id value))translate;
- (void)id_updateSelectionPresentation;
- (void)id_scrollCaretToVisibleIfNeeded;
- (void)id_canvasDidLayout;
- (void)id_updateInteractionGeometry;
- (void)id_flushSelectionDisplayUpdate;
- (void)id_tearDownEditorGraph;
- (NSRange)id_NSRangeForTextRange:(nullable UITextRange *)range;

@end

API_AVAILABLE(ios(18.4))
@interface IDBlockTextView (Interaction)
- (void)id_installInteractionAssistant;
- (void)id_updateSelectionGestures;
@end

API_AVAILABLE(ios(18.4))
@interface IDBlockTextView (VerticalAutoscroll)
- (void)id_cancelVerticalAutoscrollSession;
- (void)id_recordLatestCanonicalSelectionForAutoscroll;
- (void)id_setVerticalAutoscrollContentOffset:(CGPoint)contentOffset
                                      duration:(NSTimeInterval)duration;
@end

/// Adds the text view's callbacks UIKit sends under private names (`IDBlockTextView+PrivateCallbacks.m`).
/// Called from `+initialize` for the class and for every subclass.
FOUNDATION_EXTERN void IDBlockTextViewInstallPrivateCallbacks(Class cls);
/// The input-delegate and interaction callbacks' halves of it, each in its own category file.
FOUNDATION_EXTERN void IDBlockTextViewInstallPrivateInputDelegateCallbacks(Class cls);
FOUNDATION_EXTERN void IDBlockTextViewInstallPrivateInteractionCallbacks(Class cls);
/// The same for the block stack canvas's `textContainerOrigin`.
FOUNDATION_EXTERN void IDBlockStackCanvasViewInstallPrivateCallbacks(Class cls);

NS_ASSUME_NONNULL_END

#endif
