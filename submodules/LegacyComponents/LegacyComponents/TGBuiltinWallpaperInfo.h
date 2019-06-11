#import <LegacyComponents/TGWallpaperInfo.h>

@interface TGBuiltinWallpaperInfo : TGWallpaperInfo

- (instancetype)initWithBuiltinId:(int)builtinId;
- (instancetype)initWithBuiltinId:(int)builtinId tintColor:(int)tintColor systemAlpha:(CGFloat)systemAlpha buttonsAlpha:(CGFloat)buttonsAlpha highlightedButtonAlpha:(CGFloat)highlightedButtonAlpha progressAlpha:(CGFloat)progressAlpha version:(int32_t)version;

- (BOOL)isDefault;
- (int32_t)version;

@end

extern const int32_t TGBuilitinWallpaperCurrentVersion;
