#import <Foundation/Foundation.h>
#import <LegacyComponents/TGMediaPickerCaptionInputPanel.h>

@class TGSuggestionContext;
@class TGKeyCommandController;

@interface TGPhotoCaptionInputMixin : NSObject

@property (nonatomic, readonly) TGMediaPickerCaptionInputPanel *inputPanel;
@property (nonatomic, readonly) UIView *dismissView;

@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;
@property (nonatomic, readonly) CGFloat keyboardHeight;
@property (nonatomic, assign) CGFloat contentAreaHeight;
@property (nonatomic, assign) bool allowEntities;

@property (nonatomic, strong) TGSuggestionContext *suggestionContext;

@property (nonatomic, copy) UIView *(^panelParentView)(void);

@property (nonatomic, copy) void (^panelFocused)(void);
@property (nonatomic, copy) void (^finishedWithCaption)(NSString *caption, NSArray *entities);
@property (nonatomic, copy) void (^keyboardHeightChanged)(CGFloat keyboardHeight, NSTimeInterval duration, NSInteger animationCurve);

- (instancetype)initWithKeyCommandController:(TGKeyCommandController *)keyCommandController;

- (void)createInputPanelIfNeeded;
- (void)beginEditing;
- (void)enableDismissal;

- (void)destroy;

@property (nonatomic, strong) NSString *caption;
- (void)setCaption:(NSString *)caption entities:(NSArray *)entities animated:(bool)animated;

- (void)setCaptionPanelHidden:(bool)hidden animated:(bool)animated;

- (void)updateLayoutWithFrame:(CGRect)frame edgeInsets:(UIEdgeInsets)edgeInsets;

@end
