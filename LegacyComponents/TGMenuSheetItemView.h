#import <UIKit/UIKit.h>

@class TGMenuSheetView;
@class TGMenuSheetController;

typedef enum
{
    TGMenuSheetItemTypeDefault,
    TGMenuSheetItemTypeHeader,
    TGMenuSheetItemTypeFooter
} TGMenuSheetItemType;

@interface TGMenuSheetItemView : UIView <UIViewControllerPreviewingDelegate>
{
    CGFloat _screenHeight;
    UIUserInterfaceSizeClass _sizeClass;
}

@property (nonatomic, weak) TGMenuSheetController *menuController;
@property (nonatomic, readonly) TGMenuSheetItemType type;

- (instancetype)initWithType:(TGMenuSheetItemType)type;

- (void)setDark;
- (void)setHidden:(bool)hidden animated:(bool)animated;

@property (nonatomic, readonly) CGFloat contentHeightCorrection;
- (CGFloat)preferredHeightForWidth:(CGFloat)width screenHeight:(CGFloat)screenHeight;

@property (nonatomic, assign) bool requiresDivider;
@property (nonatomic, assign) bool requiresClearBackground;

@property (nonatomic, assign) bool handlesPan;
- (bool)passPanOffset:(CGFloat)offset;
@property (nonatomic, readonly) bool inhibitPan;

@property (nonatomic, readonly) UIView *previewSourceView;

@property (nonatomic, assign) bool condensable;
@property (nonatomic, assign) bool distractable;
@property (nonatomic, assign) bool overflow;

@property (nonatomic, assign) CGFloat screenHeight;
@property (nonatomic, assign) UIUserInterfaceSizeClass sizeClass;

@property (nonatomic, copy) void (^layoutUpdateBlock)(void);
- (void)requestMenuLayoutUpdate;

@property (nonatomic, copy) void (^highlightUpdateBlock)(bool highlighted);

@property (nonatomic, copy) void (^handleInternalPan)(UIPanGestureRecognizer *);

- (void)_updateHeightAnimated:(bool)animated;
- (void)_didLayoutSubviews;

- (void)_willRotateToInterfaceOrientation:(UIInterfaceOrientation)orientation duration:(NSTimeInterval)duration;
- (void)_didRotateToInterfaceOrientation:(UIInterfaceOrientation)orientation;

- (void)didChangeAbsoluteFrame;

- (void)menuView:(TGMenuSheetView *)menuView willAppearAnimated:(bool)animated;
- (void)menuView:(TGMenuSheetView *)menuView didAppearAnimated:(bool)animated;
- (void)menuView:(TGMenuSheetView *)menuView willDisappearAnimated:(bool)animated;
- (void)menuView:(TGMenuSheetView *)menuView didDisappearAnimated:(bool)animated;

@end
