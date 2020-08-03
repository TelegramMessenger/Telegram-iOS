#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TGCameraInterfaceAssets : NSObject

+ (UIColor *)normalColor;
+ (UIColor *)accentColor;
+ (UIColor *)redColor;

+ (UIColor *)panelBackgroundColor;
+ (UIColor *)transparentPanelBackgroundColor;
+ (UIColor *)transparentOverlayBackgroundColor;

+ (UIFont *)regularFontOfSize:(CGFloat)size;
+ (UIFont *)boldFontOfSize:(CGFloat)size;

@end
