#import <CoreLocation/CoreLocation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface TGLocationUtils : NSObject

+ (CLLocationDegrees)adjustGMapLatitude:(CLLocationDegrees)latitude withPixelOffset:(NSInteger)offset zoom:(NSInteger)zoom;
+ (CLLocationDegrees)adjustGMapLongitude:(CLLocationDegrees)longitude withPixelOffset:(NSInteger)offset zoom:(NSInteger)zoom;
+ (CLLocationCoordinate2D)adjustGMapCoordinate:(CLLocationCoordinate2D)coordinate withPixelOffset:(CGPoint)offset zoom:(NSInteger)zoom;

@end
