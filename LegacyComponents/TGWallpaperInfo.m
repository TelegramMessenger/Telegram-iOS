/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGWallpaperInfo.h"

@implementation TGWallpaperInfo

- (NSString *)thumbnailUrl
{
    return nil;
}

- (NSString *)fullscreenUrl
{
    return nil;
}

- (int)tintColor
{
    return 0;
}

- (CGFloat)systemAlpha
{
    return 0.25f;
}

- (CGFloat)buttonsAlpha
{
    return 0.35f;
}

- (CGFloat)highlightedButtonAlpha
{
    return 0.50f;
}

- (CGFloat)progressAlpha
{
    return 0.35f;
}

- (UIImage *)image
{
    return nil;
}

- (NSData *)imageData
{
    return nil;
}

- (bool)hasData
{
    return false;
}

- (NSDictionary *)infoDictionary
{
    return @{};
}

+ (TGWallpaperInfo *)infoWithDictionary:(NSDictionary *)dict
{
    Class className = NSClassFromString(dict[@"_className"]);
    return [className infoWithDictionary:dict];
}

@end
