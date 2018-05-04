#import <SSignalKit/SSignalKit.h>
#import <CoreLocation/CoreLocation.h>

@interface TGLocationSignals : NSObject

+ (SSignal *)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate;
+ (SSignal *)cityForCoordinate:(CLLocationCoordinate2D)coordinate;
+ (SSignal *)driveEta:(CLLocationCoordinate2D)coordinate;

+ (void)storeLastKnownUserLocation:(CLLocation *)location;
+ (CLLocation *)lastKnownUserLocation;

+ (SSignal *)userLocation:(SVariable *)locationRequired;

@end
