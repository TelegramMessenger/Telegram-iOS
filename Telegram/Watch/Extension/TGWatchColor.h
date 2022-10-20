#import <UIKit/UIKit.h>

@interface UIColor (TGColor)

+ (UIColor *)hexColor:(NSInteger)hex;
+ (UIColor *)hexColor:(NSInteger)hex withAlpha:(CGFloat)alpha;

@end

@interface TGColor : NSObject

+ (UIColor *)colorForUserId:(int32_t)userId myUserId:(int32_t)myUserId;
+ (UIColor *)colorForGroupId:(int64_t)groupId;

+ (UIColor *)accentColor;
+ (UIColor *)subtitleColor;

@end
