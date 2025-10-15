#import <UIKit/UIKit.h>

#import <LegacyComponents/TGModernGalleryInterfaceView.h>

@interface TGModernGalleryDefaultInterfaceView : UIView <TGModernGalleryInterfaceView>

- (void)addItemHeaderView:(UIView *)itemHeaderView;
- (void)removeItemHeaderView:(UIView *)itemHeaderView;
- (void)addItemFooterView:(UIView *)itemFooterView;
- (void)removeItemFooterView:(UIView *)itemFooterView;
- (void)addItemLeftAcessoryView:(UIView *)itemLeftAcessoryView;
- (void)removeItemLeftAcessoryView:(UIView *)itemLeftAcessoryView;
- (void)addItemRightAcessoryView:(UIView *)itemRightAcessoryView;
- (void)removeItemRightAcessoryView:(UIView *)itemRightAcessoryView;

- (void)animateTransitionInWithDuration:(NSTimeInterval)dutation;
- (void)animateTransitionOutWithDuration:(NSTimeInterval)dutation;
- (void)setTransitionOutProgress:(CGFloat)transitionOutProgress manual:(bool)manual;

@end
