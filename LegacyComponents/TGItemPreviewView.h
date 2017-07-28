#import <UIKit/UIKit.h>

@interface TGItemPreviewView : UIView

@property (nonatomic, readonly) UIView *dimView;
@property (nonatomic, readonly) UIView *wrapperView;

@property (nonatomic, copy) CGPoint (^sourcePointForItem)(id item);
@property (nonatomic, copy) void (^onDismiss)(void);

@property (nonatomic, assign) bool eccentric;
@property (nonatomic, strong) id item;
@property (nonatomic, assign) bool isLocked;

- (void)animateAppear;
- (void)animateDismiss:(void (^)())completion;

- (void)_handlePanOffset:(CGFloat)offset;
- (void)_handlePressEnded;

- (bool)_maybeLockWithVelocity:(CGFloat)velocity;

- (CGPoint)_wrapperViewContainerCenter;

- (void)_didAppear;
- (void)_willDisappear;

@end
