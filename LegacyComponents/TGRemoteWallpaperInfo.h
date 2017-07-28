#import <LegacyComponents/TGWallpaperInfo.h>

@interface TGRemoteWallpaperInfo : TGWallpaperInfo

- (instancetype)initWithRemoteId:(int)remoteId thumbnailUri:(NSString *)thumbnailUri fullscreenUri:(NSString *)fullscreenUri tintColor:(int)tintColor;

@end
