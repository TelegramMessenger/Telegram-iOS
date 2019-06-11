#import <UIKit/UIKit.h>

#import "TGStickerKeyboardTabPanel.h"

typedef enum {
    TGStickerKeyboardTabSettingsCellSettings,
    TGStickerKeyboardTabSettingsCellGifs,
    TGStickerKeyboardTabSettingsCellTrending
} TGStickerKeyboardTabSettingsCellMode;

@interface TGStickerKeyboardTabSettingsCell : UICollectionViewCell

@property (nonatomic, copy) void (^pressed)();

@property (nonatomic) TGStickerKeyboardTabSettingsCellMode mode;

- (void)setBadge:(NSString *)badge;
- (void)setStyle:(TGStickerKeyboardViewStyle)style;
- (void)setPallete:(TGStickerKeyboardPallete *)pallete;

- (void)setInnerAlpha:(CGFloat)innerAlpha;

@end
