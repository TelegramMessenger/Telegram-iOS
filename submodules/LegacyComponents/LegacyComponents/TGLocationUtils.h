#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

@interface TGLocationUtils : NSObject

+ (MKMapRect)MKMapRectForCoordinateRegion:(MKCoordinateRegion)region;

+ (bool)requestWhenInUserLocationAuthorizationWithLocationManager:(CLLocationManager *)locationManager;
+ (bool)requestAlwaysUserLocationAuthorizationWithLocationManager:(CLLocationManager *)locationManager;

+ (NSString *)stringFromDistance:(CLLocationDistance)distance;
+ (NSString *)stringFromAccuracy:(CLLocationAccuracy)accuracy;

+ (NSString *)stringForCoordinate:(CLLocationCoordinate2D)coordinate;

@end

@interface TGLocationUtils (GoogleMaps)

+ (CLLocationDegrees)adjustGMapLatitude:(CLLocationDegrees)latitude withPixelOffset:(NSInteger)offset zoom:(NSInteger)zoom;
+ (CLLocationDegrees)adjustGMapLongitude:(CLLocationDegrees)longitude withPixelOffset:(NSInteger)offset zoom:(NSInteger)zoom;
+ (CLLocationCoordinate2D)adjustGMapCoordinate:(CLLocationCoordinate2D)coordinate withPixelOffset:(CGPoint)offset zoom:(NSInteger)zoom;

@end

@interface TGLocationUtils (ThirdPartyAppLauncher)

+ (void)openMapsWithCoordinate:(CLLocationCoordinate2D)coordinate withDirections:(bool)withDirections locationName:(NSString *)locationName;

+ (void)openGoogleMapsWithCoordinate:(CLLocationCoordinate2D)coordinate withDirections:(bool)withDirections;
+ (bool)isGoogleMapsInstalled;

+ (void)openGoogleWithPlaceId:(NSString *)placeId;

+ (void)openFoursquareWithVenueId:(NSString *)venueId;
+ (bool)isFoursquareInstalled;

+ (void)openHereMapsWithCoordinate:(CLLocationCoordinate2D)coordinate;
+ (bool)isHereMapsInstalled;

+ (void)openYandexMapsWithCoordinate:(CLLocationCoordinate2D)coordinate withDirections:(bool)withDirections;
+ (bool)isYandexMapsInstalled;

+ (void)openDirectionsInYandexNavigatorWithCoordinate:(CLLocationCoordinate2D)coordinate;
+ (bool)isYandexNavigatorInstalled;

+ (void)openWazeWithCoordinate:(CLLocationCoordinate2D)coordinate withDirections:(bool)withDirections;
+ (bool)isWazeInstalled;

@end
