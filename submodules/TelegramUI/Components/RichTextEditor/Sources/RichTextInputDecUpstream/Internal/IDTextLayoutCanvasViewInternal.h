#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "IDTextLayoutCanvasView.h"

NS_ASSUME_NONNULL_BEGIN

@class IDTextRenderingSurfaceView;
@class IDTextCanvasAttachmentCoordinator;

@interface IDTextLayoutCanvasView ()

@property(nonatomic) BOOL performingViewportLayout;
@property(nonatomic) BOOL handlingExternalViewportLayout;
@property(nonatomic) BOOL layoutFragmentViewsNeedDisplay;
@property(nonatomic) CGSize cachedContentSize;
@property(nonatomic) NSUInteger completedViewportLayoutCount;
@property(nonatomic, strong) NSHashTable<NSTextLayoutFragment *> *unusedFragmentKeys;
@property(nonatomic, strong) NSMapTable<NSTextLayoutFragment *, UIView *> *fragmentSurfaces;
@property(nonatomic, strong) IDTextCanvasAttachmentCoordinator *attachmentCoordinator;
@property(nonatomic, strong) NSMutableSet<UIView *> *externalSurfaces;
@property(nonatomic, strong) NSMutableSet<UIView *> *unusedExternalSurfaces;
@property(nonatomic, strong) NSMapTable<id, UIView *> *anchoredAttachmentSurfaces;
@property(nonatomic, weak, nullable) id currentExternalSurfaceElement;
@property(nonatomic, strong, nullable) id currentCustomRenderController;
@property(nonatomic, strong, nullable) id lastCustomRenderController;
@property(nonatomic, copy, nullable) dispatch_block_t viewportLayoutTestHook;
@property(nonatomic) CGRect viewportOverride;
@property(nonatomic, readonly) CGRect viewportBounds;
@property(nonatomic, readonly) NSUInteger visibleSurfaceCount;
@property(nonatomic, copy, readonly) NSArray<NSTextLayoutFragment *> *visibleFragments;
@property(nonatomic, copy, readonly) NSArray<UIView *> *visibleSurfaces;
@property(nonatomic) Class nativeSurfaceViewClass;
@property(nonatomic, strong, nullable) UIView *id_textEmphasisBackgroundView;
@property(nonatomic, strong, nullable) CALayer *id_hoverEffectContainerLayer;
@property(nonatomic, strong, nullable) id id_uniqueWritingToolsAnimatedLayoutInfo;

- (nullable UIView *)surfaceForFragment:(NSTextLayoutFragment *)fragment;
- (UIView *)id_renderingSurfaceForTextLayoutFragment:(NSTextLayoutFragment *)fragment;
- (void)id_configureRenderingSurfaceForTextLayoutFragment:(NSTextLayoutFragment *)fragment;
- (void)id_notifyCustomRendererPreLayout;
- (void)id_notifyCustomRendererPostLayout;
- (void)id_viewportWillLayout;
- (void)id_viewportDidLayout;
- (void)id_removeUnusedElementViews;
- (void)id_updateContentSizeIfNeeded;
- (void)id_flushElementViews;
- (BOOL)id_addRenderingSurface:(UIView *)surface
                         group:(NSInteger)group
                     placement:(NSInteger)placement;
- (UIView *)id_renderingSurfaceForTextParagraphAnchoredAttachment:(id)attachment
                                         associatedLayoutFragment:(NSTextLayoutFragment *)fragment;
- (CGRect)id_frameForParagraphAnchoredAttachment:(id)attachment
                                  layoutFragment:(NSTextLayoutFragment *)fragment;
- (void)id_setTextEmphasisBackgroundView:(nullable UIView *)backgroundView
                            withTextView:(UIView *)textView;
- (void)id_isEditingDidChange;
- (void)id_observeEnclosingScrollView;
- (void)id_traitsChanged;
- (void)id_invalidateTextContainerOrigin;
- (CGPoint)id_textContainerOrigin;
- (nullable id)id_textLayoutController;
- (nullable id)id_layoutManager;
- (nullable id)id_customRenderController;
- (UIColor *)id_textColor;
- (BOOL)id_isEditable;
- (BOOL)id_isEditing;
- (void)id_textKit2CanvasDidLayout;
- (void)id_updateInteractionGeometry;
- (void)id_updateRenderingSurfaceViewsForTextRange:(nullable id)textRange
                                         inTextView:(UIView *)textView
                                             bounds:(CGRect)bounds;

@end

@interface IDTextLayoutCanvasView (IDTemporaryAttributeInvalidation)
- (void)setNeedsDisplayInRect:(CGRect)rect;
- (void)tgpn_invalidateTemporaryAttributesInRange:(id)range;
@end

NS_ASSUME_NONNULL_END

#endif
