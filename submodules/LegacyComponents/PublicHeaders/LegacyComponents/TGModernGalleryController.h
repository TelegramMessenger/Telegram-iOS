#import <LegacyComponents/LegacyComponents.h>

#import <LegacyComponents/TGOverlayController.h>
#import <LegacyComponents/LegacyComponentsContext.h>

@class TGModernGalleryModel;
@protocol TGModernGalleryItem;
@class TGModernGalleryItemView;

typedef NS_ENUM(NSUInteger, TGModernGalleryScrollAnimationDirection) {
    TGModernGalleryScrollAnimationDirectionDefault,
    TGModernGalleryScrollAnimationDirectionLeft,
    TGModernGalleryScrollAnimationDirectionRight
};

@interface TGModernGalleryController : TGOverlayController

@property (nonatomic) UIStatusBarStyle defaultStatusBarStyle;
@property (nonatomic) bool shouldAnimateStatusBarStyleTransition;

@property (nonatomic, strong) TGModernGalleryModel *model;
@property (nonatomic, assign) bool animateTransition;
@property (nonatomic, assign) bool asyncTransitionIn;
@property (nonatomic, assign) bool showInterface;
@property (nonatomic, assign) bool adjustsStatusBarVisibility;
@property (nonatomic, assign) bool hasFadeOutTransition;
@property (nonatomic, assign) bool previewMode;

@property (nonatomic, copy) UIView *(^transitionHost)(void);
@property (nonatomic, copy) void (^itemFocused)(id<TGModernGalleryItem>);
@property (nonatomic, copy) UIView *(^beginTransitionIn)(id<TGModernGalleryItem>, TGModernGalleryItemView *);
@property (nonatomic, copy) void (^startedTransitionIn)();
@property (nonatomic, copy) void (^finishedTransitionIn)(id<TGModernGalleryItem>, TGModernGalleryItemView *);
@property (nonatomic, copy) UIView *(^beginTransitionOut)(id<TGModernGalleryItem>, TGModernGalleryItemView *);
@property (nonatomic, copy) void (^completedTransitionOut)();

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context;

- (NSArray *)visibleItemViews;
- (TGModernGalleryItemView *)itemViewForItem:(id<TGModernGalleryItem>)item;
- (id<TGModernGalleryItem>)currentItem;

- (UIView *)transitionView;

- (void)setCurrentItemIndex:(NSUInteger)index animated:(bool)animated;
- (void)setCurrentItemIndex:(NSUInteger)index direction:(TGModernGalleryScrollAnimationDirection)direction animated:(bool)animated;

- (void)dismissWhenReady;
- (void)dismissWhenReadyAnimated:(bool)animated;

- (bool)isFullyOpaque;

@end

@protocol TGModernGalleryTransitionHostScrollView <NSObject>

- (bool)disableGalleryTransitionOffsetFix;

@end
