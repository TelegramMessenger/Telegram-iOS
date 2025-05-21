#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFMpegOpusTrimmer : NSObject

+ (bool)trim:(NSString * _Nonnull)path
           to:(NSString * _Nonnull)outputPath
       start:(double)start
         end:(double)end;

@end

NS_ASSUME_NONNULL_END
