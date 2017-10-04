#import "TGLocationSignals.h"

#import "LegacyComponentsInternal.h"
#import "TGStringUtils.h"

#import <UIKit/UIKit.h>

#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

#import "TGLocationVenue.h"
#import "TGLocationReverseGeocodeResult.h"

NSString *const TGLocationFoursquareSearchEndpointUrl = @"https://api.foursquare.com/v2/venues/search/";
NSString *const TGLocationFoursquareClientId = @"DGCOWIDKBO5UQSI41R4JPXMIHFEBU35C1FPQX11ZXF45HX0U";
NSString *const TGLocationFoursquareClientSecret = @"COGTBZEZE4POPSGOZIJ5USK0NHRLC1RAGTYWQREZ4KQHZKON";
NSString *const TGLocationFoursquareVersion = @"20150326";
NSString *const TGLocationFoursquareVenuesCountLimit = @"25";
NSString *const TGLocationFoursquareLocale = @"en";

NSString *const TGLocationGooglePlacesSearchEndpointUrl = @"https://maps.googleapis.com/maps/api/place/nearbysearch/json";
NSString *const TGLocationGooglePlacesApiKey = @"AIzaSyBCTH4aAdvi0MgDGlGNmQAaFS8GTNBrfj4";
NSString *const TGLocationGooglePlacesRadius = @"150";
NSString *const TGLocationGooglePlacesLocale = @"en";

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

+ (SSignal *)reverseGeocodeCoordinate:(CLLocationCoordinate2D)coordinate
{
    NSURL *url = [NSURL URLWithString:[[NSString alloc] initWithFormat:@"https://maps.googleapis.com/maps/api/geocode/json?latlng=%f,%f&sensor=true&language=%@", coordinate.latitude, coordinate.longitude, TGLocationGoogleGeocodeLocale]];
    
    return [[[LegacyComponentsGlobals provider] jsonForHttpLocation:url.absoluteString] map:^id(id json)
    {
        if (![json respondsToSelector:@selector(objectForKey:)])
            return nil;
        
        NSArray *results = json[@"results"];
        if (![results respondsToSelector:@selector(objectAtIndex:)])
            return nil;
        
        if (![results.firstObject isKindOfClass:[NSDictionary class]])
            return nil;
        
        return [TGLocationReverseGeocodeResult reverseGeocodeResultWithDictionary:results.firstObject];
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

+ (SSignal *)searchNearbyPlacesWithQuery:(NSString *)query coordinate:(CLLocationCoordinate2D)coordinate service:(TGLocationPlacesService)service
{
    switch (service)
    {
        case TGLocationPlacesServiceGooglePlaces:
            return [self _searchGooglePlacesWithQuery:query coordinate:coordinate];
            
        default:
            return [self _searchFoursquareVenuesWithQuery:query coordinate:coordinate];
    }
}

+ (SSignal *)_searchFoursquareVenuesWithQuery:(NSString *)query coordinate:(CLLocationCoordinate2D)coordinate
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    parameters[@"limit"] = TGLocationFoursquareVenuesCountLimit;
    parameters[@"ll"] = [NSString stringWithFormat:@"%lf,%lf", coordinate.latitude, coordinate.longitude];
    if (query.length > 0)
        parameters[@"query"] = query;
    
    NSString *url = [self _urlForService:TGLocationPlacesServiceFoursquare parameters:parameters];
    return [[[LegacyComponentsGlobals provider] jsonForHttpLocation:url] map:^id(id json)
    {
        if (![json respondsToSelector:@selector(objectForKey:)])
            return nil;

        NSArray *results = json[@"response"][@"venues"];
        if (![results respondsToSelector:@selector(objectAtIndex:)])
            return nil;

        NSMutableArray *venues = [[NSMutableArray alloc] init];
        for (NSDictionary *result in results)
        {
            TGLocationVenue *venue = [TGLocationVenue venueWithFoursquareDictionary:result];
            if (venue != nil)
                [venues addObject:venue];
        }
        
        return venues;
    }];
}

+ (SSignal *)_searchGooglePlacesWithQuery:(NSString *)query coordinate:(CLLocationCoordinate2D)coordinate
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    parameters[@"location"] = [NSString stringWithFormat:@"%lf,%lf", coordinate.latitude, coordinate.longitude];
    if (query.length > 0)
        parameters[@"name"] = query;
    
    NSString *url = [self _urlForService:TGLocationPlacesServiceGooglePlaces parameters:parameters];
    return [[[LegacyComponentsGlobals provider] jsonForHttpLocation:url] map:^id(id json)
    {
        if (![json respondsToSelector:@selector(objectForKey:)])
            return nil;
        
        NSArray *results = json[@"results"];
        if (![results respondsToSelector:@selector(objectAtIndex:)])
            return nil;
        
        NSMutableArray *venues = [[NSMutableArray alloc] init];
        for (NSDictionary *result in results)
        {
            TGLocationVenue *venue = [TGLocationVenue venueWithGooglePlacesDictionary:result];
            if (venue != nil)
                [venues addObject:venue];
        }
        
        return venues;
    }];
}

+ (NSString *)_urlForService:(TGLocationPlacesService)service parameters:(NSDictionary *)parameters
{
    if (service == TGLocationPlacesServiceNone)
        return nil;
    
    NSMutableDictionary *finalParameters = [[self _defaultParametersForService:service] mutableCopy];
    [finalParameters addEntriesFromDictionary:parameters];
    
    NSMutableString *queryString = [[NSMutableString alloc] init];
    [finalParameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, __unused BOOL *stop) {
        if (queryString.length != 0) {
            [queryString appendString:@"&"];
        }
        [queryString appendString:[TGStringUtils stringByEscapingForURL:[NSString stringWithFormat:@"%@", key]]];
        [queryString appendString:@"="];
        [queryString appendString:[TGStringUtils stringByEscapingForURL:[NSString stringWithFormat:@"%@", obj]]];
    }];
    
    NSString *urlString = [NSString stringWithFormat:@"%@?%@", [self _endpointUrlForService:service], queryString];
    
    return urlString;
}

+ (NSString *)_endpointUrlForService:(TGLocationPlacesService)service
{
    switch (service)
    {
        case TGLocationPlacesServiceGooglePlaces:
            return TGLocationGooglePlacesSearchEndpointUrl;
            
        case TGLocationPlacesServiceFoursquare:
            return TGLocationFoursquareSearchEndpointUrl;
            
        default:
            return nil;
    }
}

+ (NSDictionary *)_defaultParametersForService:(TGLocationPlacesService)service
{
    switch (service)
    {
        case TGLocationPlacesServiceGooglePlaces:
            return @
            {
                @"key": TGLocationGooglePlacesApiKey,
                @"language": TGLocationGooglePlacesLocale,
                @"radius": TGLocationGooglePlacesRadius,
                @"sensor": @"true"
            };
            
        case TGLocationPlacesServiceFoursquare:
            return @
            {
                @"v": TGLocationFoursquareVersion,
                @"locale": TGLocationFoursquareLocale,
                @"client_id": TGLocationFoursquareClientId,
                @"client_secret" :TGLocationFoursquareClientSecret
            };
            
        default:
            return nil;
    }
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
