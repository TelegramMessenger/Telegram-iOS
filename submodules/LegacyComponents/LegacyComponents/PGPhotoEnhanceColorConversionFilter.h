#import "GPUImageFilter.h"

typedef enum
{
    PGPhotoEnhanceColorConversionRGBToHSVMode,
    PGPhotoEnhanceColorConversionHSVToRGBMode
} PGPhotoEnhanceColorConversionMode;

@interface PGPhotoEnhanceColorConversionFilter : GPUImageFilter

- (instancetype)initWithMode:(PGPhotoEnhanceColorConversionMode)mode;

@end
