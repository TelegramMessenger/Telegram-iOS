#import "PGPhotoEditorRawDataOutput.h"

@class PGPhotoHistogram;

@interface PGPhotoHistogramGenerator : PGPhotoEditorRawDataOutput

@property (nonatomic, copy) void (^histogramReady)(PGPhotoHistogram *histogram);

@end
