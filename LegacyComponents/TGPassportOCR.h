#import <Foundation/Foundation.h>
#import <SSignalKit/SSignalKit.h>

@interface TGPassportOCR : NSObject

+ (SSignal *)recognizeMRZInImage:(UIImage *)image;

@end
