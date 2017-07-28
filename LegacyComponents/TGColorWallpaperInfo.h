#import <LegacyComponents/TGWallpaperInfo.h>

@interface TGColorWallpaperInfo : TGWallpaperInfo

- (instancetype)initWithColor:(uint32_t)color;
- (instancetype)initWithColor:(uint32_t)color tintColor:(int)tintColor systemAlpha:(CGFloat)systemAlpha buttonsAlpha:(CGFloat)buttonsAlpha highlightedButtonAlpha:(CGFloat)highlightedButtonAlpha progressAlpha:(CGFloat)progressAlpha;

@end
