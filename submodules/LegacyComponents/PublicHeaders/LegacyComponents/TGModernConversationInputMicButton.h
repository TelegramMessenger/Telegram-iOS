#import <UIKit/UIKit.h>

@class TGModernConversationInputMicButton;

@protocol TGModernConversationInputMicButtonLock <NSObject>

- (void)updateLockness:(CGFloat)lockness;

@end

@protocol TGModernConversationInputMicButtonDecoration <NSObject>

- (void)updateLevel:(CGFloat)level;
- (void)setColor:(UIColor *)color;
- (void)stopAnimating;
- (void)startAnimating;

@end

@protocol TGModernConversationInputMicButtonPresentation <NSObject>

- (UIView *)view;
- (void)setUserInteractionEnabled:(bool)enabled;
- (void)present;
- (void)dismiss;

@end

@protocol TGModernConversationInputMicButtonDelegate <NSObject>

@optional

- (void)micButtonInteractionBegan;
- (void)micButtonInteractionCancelled:(CGPoint)velocity;
- (void)micButtonInteractionCompleted:(CGPoint)velocity;
- (void)micButtonInteractionUpdate:(CGPoint)value;
- (void)micButtonInteractionLocked;
- (void)micButtonInteractionRequestedLockedAction;
- (void)micButtonInteractionStopped;
- (void)micButtonInteractionUpdateCancelTranslation:(CGFloat)translation;

- (bool)micButtonShouldLock;

- (id<TGModernConversationInputMicButtonPresentation>)micButtonPresenter;
- (UIView<TGModernConversationInputMicButtonDecoration> *)micButtonDecoration;
- (UIView<TGModernConversationInputMicButtonLock> *)micButtonLock;

@end

@interface TGModernConversationInputMicPallete : NSObject

@property (nonatomic, readonly) bool isDark;
@property (nonatomic, readonly) UIColor *buttonColor;
@property (nonatomic, readonly) UIColor *iconColor;

@property (nonatomic, readonly) UIColor *backgroundColor;
@property (nonatomic, readonly) UIColor *borderColor;
@property (nonatomic, readonly) UIColor *lockColor;

@property (nonatomic, readonly) UIColor *textColor;
@property (nonatomic, readonly) UIColor *secondaryTextColor;
@property (nonatomic, readonly) UIColor *recordingColor;

+ (instancetype)palleteWithDark:(bool)dark buttonColor:(UIColor *)buttonColor iconColor:(UIColor *)iconColor backgroundColor:(UIColor *)backgroundColor borderColor:(UIColor *)borderColor lockColor:(UIColor *)lockColor textColor:(UIColor *)textColor secondaryTextColor:(UIColor *)secondaryTextColor recordingColor:(UIColor *)recordingColor;

@end

@interface TGModernConversationInputMicButton : UIButton

@property (nonatomic, weak) id<TGModernConversationInputMicButtonDelegate> delegate;

@property (nonatomic, strong) TGModernConversationInputMicPallete *pallete;
@property (nonatomic) CGPoint centerOffset;
@property (nonatomic, strong) UIImage *icon;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, assign) bool blocking;
@property (nonatomic, readonly) bool locked;
@property (nonatomic) bool fadeDisabled;

- (void)animateIn;
- (void)animateOut:(BOOL)toSmallSize;
- (void)addMicLevel:(CGFloat)level;
- (void)dismiss;
- (void)reset;

- (void)updateOverlay;

- (void)_commitLocked;

@end
