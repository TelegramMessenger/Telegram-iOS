#import "PGPhotoHistogram.h"

@interface PGPhotoHistogramBins ()
{
    NSArray *_bins;
    NSUInteger _max;
}
@end

@implementation PGPhotoHistogramBins

- (instancetype)initWithCArray:(NSUInteger *)array
{
    self = [super init];
    if (self != nil)
    {
        _max = 1;
        
        NSMutableArray *bins = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < 256; i++)
        {
            [bins addObject:@(array[i])];
            if (i != 0)
            {
                if (array[i] > _max)
                    _max = array[i];
            }
        }
        
        _bins = bins;
    }
    return self;
}

- (id)objectAtIndexedSubscript:(NSUInteger)idx
{
    if (idx == 0)
        return @0;
    
    if (idx < _bins.count)
        return @([_bins[idx] floatValue] / (CGFloat)_max);
    
    return nil;
}

- (NSUInteger)count
{
    return _bins.count;
}

@end

@interface PGPhotoHistogram ()
{
    PGPhotoHistogramBins *_luminance;
    PGPhotoHistogramBins *_red;
    PGPhotoHistogramBins *_green;
    PGPhotoHistogramBins *_blue;
}
@end

@implementation PGPhotoHistogram

- (instancetype)initWithLuminanceCArray:(NSUInteger *)luminanceArray redCArray:(NSUInteger *)redArray greenCArray:(NSUInteger *)greenArray blueCArray:(NSUInteger *)blueArray
{
    self = [super init];
    if (self != nil)
    {
        _luminance = [[PGPhotoHistogramBins alloc] initWithCArray:luminanceArray];
        _red = [[PGPhotoHistogramBins alloc] initWithCArray:redArray];
        _green = [[PGPhotoHistogramBins alloc] initWithCArray:greenArray];
        _blue = [[PGPhotoHistogramBins alloc] initWithCArray:blueArray];
    }
    return self;
}

- (PGPhotoHistogramBins *)histogramBinsForType:(PGCurvesType)type
{
    switch (type)
    {
        case PGCurvesTypeLuminance:
            return _luminance;
            
        case PGCurvesTypeRed:
            return _red;
            
        case PGCurvesTypeGreen:
            return _green;
            
        case PGCurvesTypeBlue:
            return _blue;
            
        default:
            break;
    }
}

@end
