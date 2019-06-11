#import <SSignalKit/SSignalKit.h>
#import <CoreLocation/CoreLocation.h>

@interface TGLocationSignals : NSObject

+ (SSignal *)geocodeAddress:(NSString *)address;
+ (SSignal *)geocodeAddressDictionary:(NSDictionary *)dictionary;

+ (SSignal *)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate;
+ (SSignal *)cityForCoordinate:(CLLocationCoordinate2D)coordinate;
+ (SSignal *)driveEta:(CLLocationCoordinate2D)coordinate;

+ (void)storeLastKnownUserLocation:(CLLocation *)location;
+ (CLLocation *)lastKnownUserLocation;

+ (SSignal *)userLocation:(SVariable *)locationRequired;

@end
