#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class TGKeyCommandController;
@class SSignal;

typedef enum {
    LegacyComponentsActionSheetActionTypeGeneric,
    LegacyComponentsActionSheetActionTypeDestructive,
    LegacyComponentsActionSheetActionTypeCancel
} LegacyComponentsActionSheetActionType;

@interface LegacyComponentsActionSheetAction : NSObject

@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *action;
@property (nonatomic, readonly) LegacyComponentsActionSheetActionType type;

- (instancetype)initWithTitle:(NSString *)title action:(NSString *)action;
- (instancetype)initWithTitle:(NSString *)title action:(NSString *)action type:(LegacyComponentsActionSheetActionType)type;

@end

@protocol LegacyComponentsContext <NSObject>

- (CGRect)fullscreenBounds;
- (TGKeyCommandController *)keyCommandController;
- (CGRect)statusBarFrame;
- (bool)isStatusBarHidden;
- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation;
- (void)forceSetStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation;
- (UIStatusBarStyle)statusBarStyle;
- (void)setStatusBarStyle:(UIStatusBarStyle)statusBarStyle animated:(BOOL)animated;
- (void)forceStatusBarAppearanceUpdate;

- (bool)currentlyInSplitView;

- (UIUserInterfaceSizeClass)currentSizeClass;
- (UIUserInterfaceSizeClass)currentHorizontalSizeClass;
- (UIUserInterfaceSizeClass)currentVerticalSizeClass;
- (SSignal *)sizeClassSignal;

- (bool)canOpenURL:(NSURL *)url;
- (void)openURL:(NSURL *)url;

- (NSDictionary *)serverMediaDataForAssetUrl:(NSString *)url;

- (void)presentActionSheet:(NSArray<LegacyComponentsActionSheetAction *> *)actions view:(UIView *)view completion:(void (^)(LegacyComponentsActionSheetAction *))completion;

@end
