#import <UIKit/UIKit.h>

#import <LegacyComponents/ASWatcher.h>

@interface TGMenuButtonView : UIButton
@end

@interface TGMenuView : UIView

@property (nonatomic, assign) bool buttonHighlightDisabled;

@property (nonatomic, strong) NSDictionary *userInfo;
@property (nonatomic, assign) bool multiline;
@property (nonatomic, assign) bool forceArrowOnTop;
@property (nonatomic, assign) bool forceCenter;
@property (nonatomic, assign) CGFloat maxWidth;

- (void)setButtonsAndActions:(NSArray *)buttonsAndActions watcherHandle:(ASHandle *)watcherHandle;

- (void)sizeToFitToWidth:(CGFloat)maxWidth;

@end

@interface TGMenuContainerView : UIView

@property (nonatomic, strong) TGMenuView *menuView;

@property (nonatomic, readonly) bool isShowingMenu;
@property (nonatomic) CGRect showingMenuFromRect;

- (void)showMenuFromRect:(CGRect)rect;
- (void)showMenuFromRect:(CGRect)rect animated:(bool)animated;
- (void)hideMenu;

@end
