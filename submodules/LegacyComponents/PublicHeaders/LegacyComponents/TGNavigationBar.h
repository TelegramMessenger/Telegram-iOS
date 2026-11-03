#import <UIKit/UIKit.h>

@class SSignal;

@interface TGNavigationBarPallete : NSObject

@property (nonatomic, readonly) UIColor *backgroundColor;
@property (nonatomic, readonly) UIColor *separatorColor;
@property (nonatomic, readonly) UIColor *titleColor;
@property (nonatomic, readonly) UIColor *tintColor;

+ (instancetype)palleteWithBackgroundColor:(UIColor *)backgroundColor separatorColor:(UIColor *)separatorColor titleColor:(UIColor *)titleColor tintColor:(UIColor *)tintColor;

@end

@protocol TGNavigationBarMusicPlayerView <NSObject>

@end

@protocol TGNavigationBarMusicPlayerProvider <NSObject>

- (UIView<TGNavigationBarMusicPlayerView> *)makeMusicPlayerView:(UINavigationController *)navigationController;
- (SSignal *)musicPlayerIsActive;

@end

@interface TGNavigationBar : UINavigationBar

+ (void)setMusicPlayerProvider:(id<TGNavigationBarMusicPlayerProvider>)provider;
+ (id<TGNavigationBarMusicPlayerProvider>)musicPlayerProvider;

@property (nonatomic, weak) UINavigationController *navigationController;

@property (nonatomic, strong) UIView *progressView;
@property (nonatomic, assign) CGFloat verticalOffset;
@property (nonatomic, weak) UIView *additionalView;

@property (nonatomic) bool keepAlpha;

- (id)initWithFrame:(CGRect)frame barStyle:(UIBarStyle)barStyle;

- (void)setPallete:(TGNavigationBarPallete *)pallete;
- (void)setHiddenState:(bool)hidden animated:(bool)animated;

- (SSignal *)hiddenSignal;

- (bool)shouldAddBackdropBackground;
- (unsigned int)indexAboveBackdropBackground;

@property (nonatomic, assign) CGFloat musicPlayerOffset;
@property (nonatomic, strong) UIView<TGNavigationBarMusicPlayerView> *musicPlayerView;
@property (nonatomic) bool minimizedMusicPlayer;

- (void)showMusicPlayerView:(bool)show animation:(void (^)())animation;

@end

@interface TGBlackNavigationBar : TGNavigationBar

@end

@interface TGWhiteNavigationBar : TGNavigationBar

@end

@interface TGTransparentNavigationBar : TGNavigationBar

@end
