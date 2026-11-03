#import "GPUImageContext.h"

@interface PGPhotoEnhanceLUTGenerator : NSObject <GPUImageInput>

@property (nonatomic, copy) void(^lutDataReady)(GLubyte *data);
@property (nonatomic, assign) bool skip;

@end

extern const NSUInteger PGPhotoEnhanceHistogramBins;
extern const NSUInteger PGPhotoEnhanceSegments;
