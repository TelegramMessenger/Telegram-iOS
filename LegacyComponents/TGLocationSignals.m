#import "TGLocationSignals.h"

#import "LegacyComponentsInternal.h"
#import "TGStringUtils.h"

#import <UIKit/UIKit.h>

#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

#import "TGLocationVenue.h"
#import "TGLocationReverseGeocodeResult.h"

NSString *const TGLocationGoogleGeocodeLocale = @"en";

@interface TGLocationHelper : NSObject <CLLocationManagerDelegate> {
    CLLocationManager *_locationManager;
    void (^_locationDetermined)(CLLocation *);
    bool _startedUpdating;
}

@end

@implementation TGLocationHelper

- (instancetype)initWithLocationDetermined:(void (^)(CLLocation *))locationDetermined {
    self = [super init];
    if (self != nil) {
        _locationDetermined = [locationDetermined copy];
        
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.distanceFilter = kCLDistanceFilterNone;
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        
        bool startUpdating = false;
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
            switch ([CLLocationManager authorizationStatus])
            {
                case kCLAuthorizationStatusAuthorizedAlways:
                case kCLAuthorizationStatusAuthorizedWhenInUse:
                    startUpdating = true;
                default:
                    break;
            }
        }
        
        if (startUpdating) {
            [self startUpdating];
        }
    }
    return self;
}

- (void)dealloc {
    [_locationManager stopUpdatingLocation];
}

- (void)startUpdating {
    if (!_startedUpdating) {
        _startedUpdating = true;
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
            [_locationManager requestWhenInUseAuthorization];
        }
        [_locationManager startUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)__unused manager didUpdateLocations:(NSArray *)locations {
    if (locations.count != 0) {
        if (_locationDetermined) {
            _locationDetermined([locations lastObject]);
        }
    }
}

@end

@implementation TGLocationSignals

+ (SSignal *)geocodeAddress:(NSString *)address
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        CLGeocoder *geocoder = [[CLGeocoder alloc] init];
        [geocoder geocodeAddressString:address completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error)
        {
            if (error != nil)
            {
                [subscriber putError:error];
                return;
            }
            else
            {
                [subscriber putNext:placemarks.firstObject];
                [subscriber putCompletion];
            }
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [geocoder cancelGeocode];
        }];
    }];
}

+ (SSignal *)geocodeAddressDictionary:(NSDictionary *)dictionary
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        CLGeocoder *geocoder = [[CLGeocoder alloc] init];
        [geocoder geocodeAddressDictionary:dictionary completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error)
        {
            if (error != nil)
            {
                [subscriber putError:error];
                return;
            }
            else
            {
                [subscriber putNext:placemarks.firstObject];
                [subscriber putCompletion];
            }
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [geocoder cancelGeocode];
        }];
    }];
}

+ (SSignal *)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        CLGeocoder *geocoder = [[CLGeocoder alloc] init];
        [geocoder reverseGeocodeLocation:[[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude] completionHandler:^(NSArray *placemarks, NSError *error)
        {
            if (error != nil)
            {
                [subscriber putError:error];
                return;
            }
            else
            {
                [subscriber putNext:[TGLocationReverseGeocodeResult reverseGeocodeResultWithPlacemark:placemarks.firstObject]];
                [subscriber putCompletion];
            }
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [geocoder cancelGeocode];
        }];
    }];
}

+ (SSignal *)cityForCoordinate:(CLLocationCoordinate2D)coordinate
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        CLGeocoder *geocoder = [[CLGeocoder alloc] init];
        [geocoder reverseGeocodeLocation:[[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude] completionHandler:^(NSArray *placemarks, NSError *error)
         {
             if (error != nil)
             {
                 [subscriber putError:error];
                 return;
             }
             else
             {
                 [subscriber putNext:[placemarks.firstObject locality]];
                 [subscriber putCompletion];
             }
         }];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [geocoder cancelGeocode];
        }];
    }];
}

+ (SSignal *)driveEta:(CLLocationCoordinate2D)destinationCoordinate
{
    if (iosMajorVersion() < 7)
        return [SSignal single:@0];
    
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        MKPlacemark *destinationPlacemark = [[MKPlacemark alloc] initWithCoordinate:destinationCoordinate addressDictionary:nil];
        MKMapItem *destinationMapItem = [[MKMapItem alloc] initWithPlacemark:destinationPlacemark];
        
        MKDirectionsRequest *request = [[MKDirectionsRequest alloc] init];
        request.source = [MKMapItem mapItemForCurrentLocation];
        request.destination = destinationMapItem;
        request.transportType = MKDirectionsTransportTypeAutomobile;
        request.requestsAlternateRoutes = false;

        MKDirections *directions = [[MKDirections alloc] initWithRequest:request];
        [directions calculateETAWithCompletionHandler:^(MKETAResponse *response, NSError *error)
        {
             if (error != nil)
             {
                 [subscriber putError:error];
                 return;
             }
            
            [subscriber putNext:@(response.expectedTravelTime)];
            [subscriber putCompletion];
        }];
        
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [directions cancel];
        }];
    }];
}

#pragma mark -

static CLLocation *lastKnownUserLocation;

+ (void)storeLastKnownUserLocation:(CLLocation *)location
{
    lastKnownUserLocation = location;
}

+ (CLLocation *)lastKnownUserLocation
{
    NSTimeInterval locationAge = -[lastKnownUserLocation.timestamp timeIntervalSinceNow];
    if (locationAge > 600)
        lastKnownUserLocation = nil;
    
    return lastKnownUserLocation;
}

+ (SSignal *)userLocation:(SVariable *)locationRequired {
    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        TGLocationHelper *helper = [[TGLocationHelper alloc] initWithLocationDetermined:^(CLLocation *location) {
            [subscriber putNext:location];
        }];
        
        id<SDisposable> requiredDisposable = [[[[locationRequired signal] take:1] deliverOn:[SQueue mainQueue]] startWithNext:^(__unused id next) {
            [helper startUpdating];
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^{
            [helper description]; // keep reference
            [requiredDisposable dispose];
        }];
    }] startOn:[SQueue mainQueue]];
}

@end
