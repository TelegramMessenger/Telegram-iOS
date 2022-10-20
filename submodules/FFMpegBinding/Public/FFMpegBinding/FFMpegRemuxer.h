#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFMpegRemuxer : NSObject

+ (bool)remux:(NSString * _Nonnull)path to:(NSString * _Nonnull)outPath;

@end

NS_ASSUME_NONNULL_END
