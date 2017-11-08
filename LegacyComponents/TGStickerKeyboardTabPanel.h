#import <UIKit/UIKit.h>

typedef enum
{
    TGStickerKeyboardViewDefaultStyle,
    TGStickerKeyboardViewDarkBlurredStyle,
    TGStickerKeyboardViewPaintStyle,
    TGStickerKeyboardViewPaintDarkStyle
} TGStickerKeyboardViewStyle;

@interface TGStickerKeyboardTabPanel : UIView

@property (nonatomic, copy) void (^currentStickerPackIndexChanged)(NSUInteger);
@property (nonatomic, copy) void (^navigateToGifs)();
@property (nonatomic, copy) void (^navigateToTrendingFirst)();
@property (nonatomic, copy) void (^navigateToTrendingLast)();
@property (nonatomic, copy) void (^openSettings)();

@property (nonatomic, copy) void (^toggleExpanded)(void);
@property (nonatomic, copy) void (^expandInteraction)(CGFloat offset);

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
