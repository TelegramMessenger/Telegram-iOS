#import <UIKit/UIKit.h>

#import <LegacyComponents/TGModernGalleryItem.h>

#import <SSignalKit/SSignalKit.h>

@class TGViewController;
@class TGModernGalleryItemView;
@protocol TGModernGalleryDefaultFooterView;
@protocol TGModernGalleryDefaultFooterAccessoryView;

@protocol TGModernGalleryItemViewDelegate <NSObject>

- (void)itemViewIsReadyForScheduledDismiss:(TGModernGalleryItemView *)itemView;
- (void)itemViewDidRequestInterfaceShowHide:(TGModernGalleryItemView *)itemView;

- (void)itemViewDidRequestGalleryDismissal:(TGModernGalleryItemView *)itemView animated:(bool)animated;

- (UIView *)itemViewDidRequestInterfaceView:(TGModernGalleryItemView *)itemView;

- (TGViewController *)parentControllerForPresentation;

- (UIView *)overlayContainerView;

@end

@interface TGModernGalleryItemView : UIView
{
    id<TGModernGalleryItem> _item;
}

@property (nonatomic, weak) id<TGModernGalleryItemViewDelegate> delegate;

@property (nonatomic) NSUInteger index;
@property (nonatomic) UIEdgeInsets safeAreaInset;
@property (nonatomic, strong) id<TGModernGalleryItem> item;
@property (nonatomic, strong) UIView<TGModernGalleryDefaultFooterView> *defaultFooterView;
@property (nonatomic, strong) UIView<TGModernGalleryDefaultFooterAccessoryView> *defaultFooterAccessoryLeftView;
@property (nonatomic, strong) UIView<TGModernGalleryDefaultFooterAccessoryView> *defaultFooterAccessoryRightView;

- (void)_setItem:(id<TGModernGalleryItem>)item;
- (void)setItem:(id<TGModernGalleryItem>)item synchronously:(bool)synchronously;

- (SSignal *)readyForTransitionIn;

- (void)reset;
- (void)prepareForRecycle;
- (void)prepareForReuse;
- (void)setIsVisible:(bool)isVisible;
- (void)setIsCurrent:(bool)isCurrent;
- (void)setFocused:(bool)isFocused;

- (UIView *)headerView;
- (UIView *)footerView;

- (UIView *)transitionView;
- (UIView *)transitionContentView;
- (CGRect)transitionViewContentRect;

- (bool)dismissControllerNowOrSchedule;

- (bool)allowsScrollingAtPoint:(CGPoint)point;

- (SSignal *)contentAvailabilityStateSignal;

@end
