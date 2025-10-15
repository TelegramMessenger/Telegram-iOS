#import <Foundation/Foundation.h>
#import "PGCurvesTool.h"

@interface PGPhotoHistogramBins : NSObject

- (id)objectAtIndexedSubscript:(NSUInteger)idx;
- (NSUInteger)count;

@end

@interface PGPhotoHistogram : NSObject

- (instancetype)initWithLuminanceCArray:(NSUInteger *)luminanceArray redCArray:(NSUInteger *)redArray greenCArray:(NSUInteger *)greenArray blueCArray:(NSUInteger *)blueArray;

- (PGPhotoHistogramBins *)histogramBinsForType:(PGCurvesType)type;

@end
