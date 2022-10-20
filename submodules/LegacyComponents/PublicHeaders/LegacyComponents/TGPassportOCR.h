#import <Foundation/Foundation.h>
#import <SSignalKit/SSignalKit.h>

@interface TGPassportOCR : NSObject

+ (SSignal *)recognizeDataInImage:(UIImage *)image shouldBeDriversLicense:(bool)shouldBeDriversLicense;
+ (SSignal *)recognizeMRZInImage:(UIImage *)image;

@end
