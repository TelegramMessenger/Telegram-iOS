#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TGImageLuminanceMap : NSObject

- (instancetype)initWithPixels:(uint8_t *)pixels width:(unsigned int)width height:(unsigned int)height stride:(unsigned int)stride;

- (float)averageLuminanceForArea:(CGRect)area maxWeightedDeviation:(float *)maxWeightedDeviation;

@end
