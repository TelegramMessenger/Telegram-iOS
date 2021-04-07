#import <UIKit/UIKit.h>

#import <LegacyComponents/LegacyComponentsContext.h>
#import <LegacyComponents/TGModernGalleryInterfaceView.h>

@class TGModernGalleryScrollView;

@interface TGModernGalleryView : UIView

@property (nonatomic, copy) void (^transitionProgress)(CGFloat progress, bool manual);
@property (nonatomic, copy) bool (^transitionOut)(CGFloat velocity);
@property (nonatomic, copy) void (^instantDismiss)();

@property (nonatomic, strong, readonly) UIView *overlayContainerView;

@property (nonatomic, strong, readonly) UIView<TGModernGalleryInterfaceView> *interfaceView;
@property (nonatomic, strong, readonly) TGModernGalleryScrollView *scrollView;

- (instancetype)initWithFrame:(CGRect)frame context:(id<LegacyComponentsContext>)context itemPadding:(CGFloat)itemPadding interfaceView:(UIView<TGModernGalleryInterfaceView> *)interfaceView previewMode:(bool)previewMode previewSize:(CGSize)previewSize;

- (bool)shouldAutorotate;

- (void)showHideInterface;
- (void)hideInterfaceAnimated;
- (void)updateInterfaceVisibility;
- (bool)isInterfaceHidden;

- (void)addItemHeaderView:(UIView *)itemHeaderView;
- (void)removeItemHeaderView:(UIView *)itemHeaderView;
- (void)addItemFooterView:(UIView *)itemFooterView;
- (void)removeItemFooterView:(UIView *)itemFooterView;

- (void)simpleTransitionInWithCompletion:(void (^)())completion;
- (void)simpleTransitionOutWithVelocity:(CGFloat)velocity completion:(void (^)())completion;
- (void)transitionInWithDuration:(NSTimeInterval)duration;
- (void)transitionOutWithDuration:(NSTimeInterval)duration;

- (void)fadeOutWithDuration:(NSTimeInterval)duration completion:(void (^)(void))completion;

- (void)setScrollViewVerticalOffset:(CGFloat)offset;

- (void)setPreviewMode:(bool)previewMode;
- (void)enableInstantDismiss;
- (void)disableInstantDismiss;

@end
