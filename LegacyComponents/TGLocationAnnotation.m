#import "TGLocationAnnotation.h"

@implementation TGLocationAnnotation

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate title:(NSString *)title
{
    self = [super init];
    if (self != nil)
    {
        _coordinate = coordinate;
        self.title = title;
        self.subtitle = nil;
    }
    return self;
}

- (void)setCoordinate:(CLLocationCoordinate2D)newCoordinate
{
    _coordinate = newCoordinate;
}

@end
