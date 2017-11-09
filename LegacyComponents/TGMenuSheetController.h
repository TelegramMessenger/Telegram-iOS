#import <LegacyComponents/TGMenuSheetButtonItemView.h>
#import <LegacyComponents/TGMenuSheetTitleItemView.h>

#import <LegacyComponents/LegacyComponentsContext.h>

@class SDisposableSet;

@interface TGMenuSheetController : UIViewController

@property (nonatomic, strong, readonly) SDisposableSet *disposables;

@property (nonatomic, assign) bool requiuresDimView;
@property (nonatomic, assign) bool requiresShadow;
@property (nonatomic, assign) bool dismissesByOutsideTap;
@property (nonatomic, assign) bool hasSwipeGesture;

@property (nonatomic, assign) bool followsKeyboard;

@property (nonatomic, assign) bool narrowInLandscape;
@property (nonatomic, assign) bool inhibitPopoverPresentation;
@property (nonatomic, assign) bool stickWithSpecifiedParentController;

@property (nonatomic, readonly) NSArray *itemViews;

@property (nonatomic, copy) void (^willPresent)(CGFloat offset);
@property (nonatomic, copy) void (^willDismiss)(bool manual);
@property (nonatomic, copy) void (^didDismiss)(bool manual);
@property (nonatomic, copy) void (^customRemoveFromParentViewController)();

@property (nonatomic, assign) UIPopoverArrowDirection permittedArrowDirections;
@property (nonatomic, copy) CGRect (^sourceRect)(void);
@property (nonatomic, readonly) UIView *sourceView;
@property (nonatomic, strong) UIBarButtonItem *barButtonItem;
@property (nonatomic, readonly) UIUserInterfaceSizeClass sizeClass;

@property (nonatomic, readonly) UIPanGestureRecognizer *panGestureRecognizer;
@property (nonatomic, readonly) UIViewController *parentController;

@property (nonatomic, assign) CGFloat maxHeight;

@property (nonatomic, readonly) CGFloat statusBarHeight;
@property (nonatomic, readonly) UIEdgeInsets safeAreaInset;
@property (nonatomic, readonly) CGFloat menuHeight;

@property (nonatomic) bool packIsArchived;
@property (nonatomic) bool packIsMask;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context dark:(bool)dark;
- (instancetype)initWithContext:(id<LegacyComponentsContext>)context itemViews:(NSArray *)itemViews;
- (void)setItemViews:(NSArray *)itemViews;
- (void)setItemViews:(NSArray *)itemViews animated:(bool)animated;
- (void)removeItemViewsAtIndexes:(NSIndexSet *)indexes;

- (void)presentInViewController:(UIViewController *)viewController sourceView:(UIView *)sourceView animated:(bool)animated;
- (void)dismissAnimated:(bool)animated;
- (void)dismissAnimated:(bool)animated manual:(bool)manual;
- (void)dismissAnimated:(bool)animated manual:(bool)manual completion:(void (^)(void))completion;

- (void)setDimViewHidden:(bool)hidden animated:(bool)animated;

@end
