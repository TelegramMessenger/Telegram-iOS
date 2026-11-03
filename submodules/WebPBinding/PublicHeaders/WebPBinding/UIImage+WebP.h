#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface WebP : NSObject
    
+ (UIImage * _Nullable)convertFromWebP:(NSData * _Nonnull)data;
+ (NSData * _Nullable)convertToWebP:(UIImage * _Nonnull)image quality:(CGFloat)quality error:(NSError ** _Nullable)error;

@end

NS_ASSUME_NONNULL_END
