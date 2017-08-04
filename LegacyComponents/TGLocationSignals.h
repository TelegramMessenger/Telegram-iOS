#import <SSignalKit/SSignalKit.h>
#import <CoreLocation/CoreLocation.h>

typedef enum {
    TGLocationPlacesServiceNone,
    TGLocationPlacesServiceFoursquare,
    TGLocationPlacesServiceGooglePlaces
} TGLocationPlacesService;

@interface TGLocationSignals : NSObject

+ (SSignal *)searchNearbyPlacesWithQuery:(NSString *)query coordinate:(CLLocationCoordinate2D)coordinate service:(TGLocationPlacesService)service;
+ (SSignal *)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate;

+ (void)storeLastKnownUserLocation:(CLLocation *)location;
+ (CLLocation *)lastKnownUserLocation;

+ (SSignal *)userLocation:(SVariable *)locationRequired;

@end
