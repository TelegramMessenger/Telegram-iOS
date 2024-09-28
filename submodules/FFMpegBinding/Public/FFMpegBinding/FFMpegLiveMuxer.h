#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFMpegLiveMuxer : NSObject

+ (bool)remux:(NSString * _Nonnull)path to:(NSString * _Nonnull)outPath offsetSeconds:(double)offsetSeconds;

@end

NS_ASSUME_NONNULL_END
