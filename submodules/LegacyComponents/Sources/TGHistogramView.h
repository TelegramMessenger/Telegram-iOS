#import "PGCurvesTool.h"

@class PGPhotoHistogram;

@interface TGHistogramView : UIView

@property (nonatomic, assign) bool isLandscape;

- (void)setHistogram:(PGPhotoHistogram *)histogram type:(PGCurvesType)type animated:(bool)animated;

@end
