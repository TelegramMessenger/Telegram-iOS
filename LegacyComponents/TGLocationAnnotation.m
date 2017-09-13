#import "TGLocationAnnotation.h"

@implementation TGLocationAnnotation

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate
{
    self = [super init];
    if (self != nil)
    {
        _coordinate = coordinate;
    }
    return self;
}

- (void)setCoordinate:(CLLocationCoordinate2D)newCoordinate
{
    _coordinate = newCoordinate;
}

@end
