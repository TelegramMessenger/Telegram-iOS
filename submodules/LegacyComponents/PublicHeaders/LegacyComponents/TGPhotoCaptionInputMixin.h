#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol TGPhotoPaintStickersContext;
@protocol TGCaptionPanelView;

@interface TGPhotoCaptionInputMixin : NSObject

@property (nonatomic, strong) id<TGPhotoPaintStickersContext> stickersContext;
@property (nonatomic, readonly) UIView *backgroundView;
@property (nonatomic, readonly) id<TGCaptionPanelView> inputPanel;
@property (nonatomic, readonly) UIView *inputPanelView;
@property (nonatomic, readonly) UIView *dismissView;

@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;
@property (nonatomic, readonly) CGFloat keyboardHeight;
@property (nonatomic, assign) CGFloat contentAreaHeight;
@property (nonatomic, assign) bool allowEntities;

@property (nonatomic, copy) UIView *(^panelParentView)(void);

@property (nonatomic, copy) void (^panelFocused)(void);
@property (nonatomic, copy) void (^finishedWithCaption)(NSAttributedString *caption);
@property (nonatomic, copy) void (^keyboardHeightChanged)(CGFloat keyboardHeight, NSTimeInterval duration, NSInteger animationCurve);

- (void)createInputPanelIfNeeded;
- (void)beginEditing;
- (void)enableDismissal;

- (void)destroy;

@property (nonatomic, strong) NSAttributedString *caption;
- (void)setCaption:(NSAttributedString *)caption animated:(bool)animated;

- (void)setCaptionPanelHidden:(bool)hidden animated:(bool)animated;

- (void)updateLayoutWithFrame:(CGRect)frame edgeInsets:(UIEdgeInsets)edgeInsets animated:(bool)animated;

@end
