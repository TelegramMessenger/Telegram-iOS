#import "TGLocationUtils.h"

const NSInteger TGGoogleMapsOffset = 268435456;
const CGFloat TGGoogleMapsRadius = TGGoogleMapsOffset / (CGFloat)M_PI;

@implementation TGLocationUtils

+ (CLLocationCoordinate2D)adjustGMapCoordinate:(CLLocationCoordinate2D)coordinate withPixelOffset:(CGPoint)offset zoom:(NSInteger)zoom
{
    return CLLocationCoordinate2DMake([self adjustGMapLatitude:coordinate.latitude withPixelOffset:(NSInteger)offset.y zoom:zoom], [self adjustGMapLongitude:coordinate.longitude withPixelOffset:(NSInteger)offset.x zoom:zoom]);
}

+ (CLLocationDegrees)adjustGMapLatitude:(CLLocationDegrees)latitude withPixelOffset:(NSInteger)offset zoom:(NSInteger)zoom
{
    return [self _yToLatitude:([self _latitudeToY:latitude] + (offset << (21 - zoom)))];
}

+ (CLLocationDegrees)adjustGMapLongitude:(CLLocationDegrees)longitude withPixelOffset:(NSInteger)offset zoom:(NSInteger)zoom
{
    return [self _xToLongitude:([self _longitudeToX:longitude] + (offset << (21 - zoom)))];
}

+ (NSInteger)_latitudeToY:(CLLocationDegrees)latitude
{
    return (NSInteger)round(TGGoogleMapsOffset - TGGoogleMapsRadius * log((1 + sin(latitude * M_PI / 180.0)) / (1 - sin(latitude * M_PI / 180.0))) / 2);
}

+ (CLLocationDegrees)_yToLatitude:(NSInteger)y
{
    return (M_PI_2 - 2 * atan(exp((y - TGGoogleMapsOffset) / TGGoogleMapsRadius))) * 180.0 / M_PI;
}

+ (NSInteger)_longitudeToX:(CLLocationDegrees)longitude
{
    return (NSInteger)round(TGGoogleMapsOffset + TGGoogleMapsRadius * longitude * M_PI / 180);
}

+ (CLLocationDegrees)_xToLongitude:(NSInteger)x
{
    return (x - TGGoogleMapsOffset) / TGGoogleMapsRadius * 180.0 / M_PI;
}

@end
