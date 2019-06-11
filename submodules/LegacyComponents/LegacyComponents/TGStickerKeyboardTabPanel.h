#import <UIKit/UIKit.h>

typedef enum
{
    TGStickerKeyboardViewDefaultStyle,
    TGStickerKeyboardViewDarkBlurredStyle,
    TGStickerKeyboardViewPaintStyle,
    TGStickerKeyboardViewPaintDarkStyle
} TGStickerKeyboardViewStyle;

@interface TGStickerKeyboardPallete : NSObject

@property (nonatomic, readonly) UIColor *backgroundColor;
@property (nonatomic, readonly) UIColor *separatorColor;
@property (nonatomic, readonly) UIColor *selectionColor;

@property (nonatomic, readonly) UIImage *gifIcon;
@property (nonatomic, readonly) UIImage *trendingIcon;
@property (nonatomic, readonly) UIImage *favoritesIcon;
@property (nonatomic, readonly) UIImage *recentIcon;
@property (nonatomic, readonly) UIImage *settingsIcon;
@property (nonatomic, readonly) UIImage *badge;
@property (nonatomic, readonly) UIColor *badgeTextColor;

+ (instancetype)palleteWithBackgroundColor:(UIColor *)backgroundColor separatorColor:(UIColor *)separatorColor selectionColor:(UIColor *)selectionColor gifIcon:(UIImage *)gifIcon trendingIcon:(UIImage *)trendingIcon favoritesIcon:(UIImage *)favoritesIcon recentIcon:(UIImage *)recentIcon settingsIcon:(UIImage *)settingsIcon badge:(UIImage *)badge badgeTextColor:(UIColor *)badgeTextColor;

@end

@interface TGStickerKeyboardTabPanel : UIView

@property (nonatomic, copy) void (^currentStickerPackIndexChanged)(NSUInteger);
@property (nonatomic, copy) void (^navigateToGifs)();
@property (nonatomic, copy) void (^navigateToTrendingFirst)();
@property (nonatomic, copy) void (^navigateToTrendingLast)();
@property (nonatomic, copy) void (^openSettings)();

@property (nonatomic, copy) void (^toggleExpanded)(void);
@property (nonatomic, copy) void (^expandInteraction)(CGFloat offset);

@property (nonatomic, strong) TGStickerKeyboardPallete *pallete;
@property (nonatomic, assign) UIEdgeInsets safeAreaInset;

- (instancetype)initWithFrame:(CGRect)frame style:(TGStickerKeyboardViewStyle)style;

- (void)setStickerPacks:(NSArray *)stickerPacks showRecent:(bool)showRecent showFavorite:(bool)showFavorite showGroup:(bool)showGroup showGroupLast:(bool)showGroupLast showGifs:(bool)showGifs showTrendingFirst:(bool)showTrendingFirst showTrendingLast:(bool)showTrendingLast;
- (void)setCurrentStickerPackIndex:(NSUInteger)currentStickerPackIndex animated:(bool)animated;
- (void)setCurrentGifsModeSelected;
- (void)setCurrentTrendingModeSelected;
- (void)setTrendingStickersBadge:(NSString *)badge;

- (void)setAvatarUrl:(NSString *)avatarUrl peerId:(int64_t)peerId title:(NSString *)title;

- (void)setInnerAlpha:(CGFloat)alpha;

- (void)setExpanded:(bool)expanded;
- (void)updateExpanded:(bool)expanded;

- (void)setHidden:(bool)hidden animated:(bool)animated;

@end
