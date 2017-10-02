#import <UIKit/UIKit.h>

@class TGModernConversationInputMicButton;

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

- (bool)micButtonShouldLock;

- (id<TGModernConversationInputMicButtonPresentation>)micButtonPresenter;

@end

@interface TGModernConversationInputMicButton : UIButton

@property (nonatomic, weak) id<TGModernConversationInputMicButtonDelegate> delegate;

@property (nonatomic) CGPoint centerOffset;
@property (nonatomic, strong) UIImage *icon;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, assign) bool blocking;
@property (nonatomic, readonly) bool locked;
@property (nonatomic) bool fadeDisabled;

- (void)animateIn;
- (void)animateOut;
- (void)addMicLevel:(CGFloat)level;
- (void)dismiss;

- (void)updateOverlay;

- (void)_commitLocked;

@end
