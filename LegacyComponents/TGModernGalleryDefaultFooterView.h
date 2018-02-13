#import <UIKit/UIKit.h>

#import <LegacyComponents/TGModernGalleryItem.h>

@protocol TGModernGalleryDefaultFooterView <NSObject>

@optional
- (void)setTransitionOutProgress:(CGFloat)transitionOutProgress manual:(bool)manual;
- (void)setContentHidden:(bool)contentHidden;
- (void)setCustomContentView:(UIView *)contentView;

- (void)setInterItemTransitionProgress:(CGFloat)progress;

- (void)setSafeAreaInset:(UIEdgeInsets)safeAreaInset;

@required

- (void)setItem:(id<TGModernGalleryItem>)item;

@end
