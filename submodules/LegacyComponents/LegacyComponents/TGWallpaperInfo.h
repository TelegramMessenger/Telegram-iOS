#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TGWallpaperInfo : NSObject

- (NSString *)thumbnailUrl;
- (NSString *)fullscreenUrl;
- (int)tintColor;
- (CGFloat)systemAlpha;
- (CGFloat)buttonsAlpha;
- (CGFloat)highlightedButtonAlpha;
- (CGFloat)progressAlpha;

- (UIImage *)image;
- (NSData *)imageData;
- (bool)hasData;

- (NSDictionary *)infoDictionary;
+ (TGWallpaperInfo *)infoWithDictionary:(NSDictionary *)dict;

@end
