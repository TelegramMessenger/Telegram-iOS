#import <Foundation/Foundation.h>
#import "SVGKDefine.h"

/** lightweight wrapper for UIColor so that we can draw with fill patterns */
@interface SVGKPattern : NSObject

+ (SVGKPattern*) patternWithColor:(UIColor*)color;
+ (SVGKPattern*) patternWithImage:(UIImage*)image;

@property (readwrite,nonatomic,strong) UIColor* color;

- (CGColorRef) CGColor;

@end
