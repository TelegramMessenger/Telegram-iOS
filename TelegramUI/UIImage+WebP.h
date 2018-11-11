#import <UIKit/UIKit.h>

@interface UIImage (WebP)

+ (UIImage *)convertFromWebP:(NSData *)data;
+ (NSData *)convertToWebP:(UIImage *)image quality:(CGFloat)quality error:(NSError **)error;

@end
