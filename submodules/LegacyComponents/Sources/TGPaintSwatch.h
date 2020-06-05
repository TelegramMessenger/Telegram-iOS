#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TGPaintSwatch : NSObject

@property (nonatomic, readonly) UIColor *color;
@property (nonatomic, readonly) CGFloat colorLocation;
@property (nonatomic, readonly) CGFloat brushWeight;

+ (instancetype)swatchWithColor:(UIColor *)color colorLocation:(CGFloat)colorLocation brushWeight:(CGFloat)brushWeight;

@end
