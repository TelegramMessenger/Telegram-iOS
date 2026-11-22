#import "IDTextView.h"
#import "IDTextLayoutCanvasView.h"

NS_ASSUME_NONNULL_BEGIN

@interface IDTextView ()

- (instancetype)initWithFrame:(CGRect)frame
      initialSpellCheckingType:(UITextSpellCheckingType)spellCheckingType;

@property(nonatomic, strong, readonly) NSTextContentStorage *id_textContentStorage;
@property(nonatomic, strong, readonly) NSTextLayoutManager *id_textLayoutManager;
@property(nonatomic, strong, readonly) NSTextContainer *id_textContainer;
@property(nonatomic, strong, readonly) IDTextLayoutCanvasView *id_canvasView;
@property(nonatomic, strong, nullable, readonly) id id_layoutController;
@property(nonatomic, strong, nullable, readonly) id id_inputController;
@property(nonatomic, strong, nullable, readwrite) id id_interactionAssistant;
@property(nonatomic, strong, nullable, readwrite) UIView *id_selectionContainerView;
/// The frame that keeps the selection container in the canvas's coordinate space.
- (CGRect)id_selectionContainerFrame;

- (void)id_applyUniformAttributes;
- (void)id_reloadInputViewsForChangedTrait;
- (void)id_preflightInputController:(id)controller;
- (void)id_setInitialContinuousSpellCheckingEnabled:(BOOL)enabled
                                  onInputController:(id)inputController;
- (void)id_notifySelectionChanged;
- (void)id_scrollCaretToVisibleIfNeeded;
- (void)id_didMutateText;
- (void)id_canvasDidLayout;
- (void)id_updateInteractionGeometry;
- (NSRange)id_NSRangeForTextRange:(UITextRange *)range;
- (NSRange)id_NSRangeForTextKitRanges:(NSArray<NSTextRange *> *)ranges;

@end

@interface IDTextView (Interaction)
- (void)id_installInteractionAssistant;
- (void)id_updateSelectionGestures;
@end

NS_ASSUME_NONNULL_END
