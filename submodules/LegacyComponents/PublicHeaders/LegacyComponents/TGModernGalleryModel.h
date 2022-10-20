#import <Foundation/Foundation.h>

#import <LegacyComponents/TGModernGalleryInterfaceView.h>
#import <LegacyComponents/TGModernGalleryDefaultHeaderView.h>
#import <LegacyComponents/TGModernGalleryDefaultFooterView.h>
#import <LegacyComponents/TGModernGalleryDefaultFooterAccessoryView.h>

@class TGModernGalleryController;
@protocol TGModernGalleryItem;

@interface TGModernGalleryModel : NSObject

@property (nonatomic, strong) NSArray *items;

@property (nonatomic, strong, readonly) id<TGModernGalleryItem> focusItem;

@property (nonatomic, copy) void (^itemsUpdated)(id<TGModernGalleryItem>);
@property (nonatomic, copy) void (^focusOnItem)(id<TGModernGalleryItem>, bool);
@property (nonatomic, copy) UIView *(^actionSheetView)();
@property (nonatomic, copy) UIViewController *(^viewControllerForModalPresentation)();
@property (nonatomic, copy) void (^dismiss)(bool, bool);
@property (nonatomic, copy) void (^dismissWhenReady)(bool);
@property (nonatomic, copy) NSArray *(^visibleItems)();

- (void)_transitionCompleted;
- (void)_replaceItems:(NSArray *)items focusingOnItem:(id<TGModernGalleryItem>)item;
- (void)_focusOnItem:(id<TGModernGalleryItem>)item synchronously:(bool)synchronously;
- (void)_interItemTransitionProgressChanged:(CGFloat)progress;

- (bool)_shouldAutorotate;

- (UIView<TGModernGalleryInterfaceView> *)createInterfaceView;
- (UIView<TGModernGalleryDefaultHeaderView> *)createDefaultHeaderView;
- (UIView<TGModernGalleryDefaultFooterView> *)createDefaultFooterView;
- (UIView<TGModernGalleryDefaultFooterAccessoryView> *)createDefaultLeftAccessoryView;
- (UIView<TGModernGalleryDefaultFooterAccessoryView> *)createDefaultRightAccessoryView;

@end
