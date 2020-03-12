#import "TGBridgeLocationSignals.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGBridgeClient.h"

#import <CoreLocation/CoreLocation.h>

NSString *const TGBridgeLocationAccessRequiredKey = @"access";
NSString *const TGBridgeLocationLoadingKey = @"loading";

@interface TGLocationManagerAdapter : NSObject <CLLocationManagerDelegate>
{
    CLLocationManager *_locationManager;
}

@property (nonatomic, copy) void (^authorizationStatusChanged)(TGLocationManagerAdapter *sender, CLAuthorizationStatus status);
@property (nonatomic, copy) void (^locationChanged)(CLLocation *location);

@end

@implementation TGLocationManagerAdapter

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
        _locationManager.distanceFilter = 20;
        //_locationManager.activityType = CLActivityTypeOther;
    }
    return self;
}

- (void)dealloc
{
    _locationManager.delegate = nil;
}

- (void)requestAuthorizationWithCompletion:(void (^)(TGLocationManagerAdapter *, CLAuthorizationStatus ))completion
{
    self.authorizationStatusChanged = completion;
    
    CLAuthorizationStatus status = [self authorizationStatus];
    if (status == kCLAuthorizationStatusNotDetermined || status == kCLAuthorizationStatusAuthorizedWhenInUse)
        [_locationManager requestAlwaysAuthorization];
    else
        self.authorizationStatusChanged(self, [self authorizationStatus]);
}

- (CLAuthorizationStatus)authorizationStatus
{
    return [CLLocationManager authorizationStatus];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status != kCLAuthorizationStatusNotDetermined && self.authorizationStatusChanged != nil)
        self.authorizationStatusChanged(self, status);
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation *location = locations.lastObject;
 
    if (self.locationChanged != nil)
        self.locationChanged(location);
}

- (void)startUpdating
{
    [_locationManager requestLocation];
}

- (void)stopUpdating
{
    [_locationManager stopUpdatingLocation];
}

@end

@implementation TGBridgeLocationSignals

+ (SSignal *)currentLocation
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        SDisposableSet *compositeDisposable = [[SDisposableSet alloc] init];
        
        TGLocationManagerAdapter *adapter = [[TGLocationManagerAdapter alloc] init];
        if (adapter.authorizationStatus == kCLAuthorizationStatusAuthorizedAlways)
        {
            [adapter startUpdating];
        }
        else if (adapter.authorizationStatus == kCLAuthorizationStatusNotDetermined || adapter.authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse)
        {
            [subscriber putNext:TGBridgeLocationAccessRequiredKey];
            
            SMetaDisposable *accessDisposable = [[SMetaDisposable alloc] init];
            
            [accessDisposable setDisposable:[[[SSignal complete] delay:1.0f onQueue:[SQueue mainQueue]] startWithNext:nil completed:^
            {
                [adapter requestAuthorizationWithCompletion:^(TGLocationManagerAdapter *sender, CLAuthorizationStatus status)
                {
                    if (status == kCLAuthorizationStatusAuthorizedAlways)
                    {
                        [subscriber putNext:TGBridgeLocationLoadingKey];
                        [sender startUpdating];
                    }
                    else
                    {
                        [subscriber putNext:TGBridgeLocationAccessRequiredKey];
                    }
                }];
            }]];
            
            [compositeDisposable add:accessDisposable];
        }
        else if (adapter.authorizationStatus != kCLAuthorizationStatusAuthorizedAlways)
        {
            [subscriber putNext:TGBridgeLocationAccessRequiredKey];
        }
        
        adapter.locationChanged = ^(CLLocation *location)
        {
            if (location != nil && location.horizontalAccuracy > 0)
            {
                [subscriber putNext:location];
                [subscriber putCompletion];
            }
        };
        
        SBlockDisposable *adapterDisposable = [[SBlockDisposable alloc] initWithBlock:^
        {
            [adapter stopUpdating];
        }];
        [compositeDisposable add:adapterDisposable];
        
        return compositeDisposable;
    }];
}

+ (SSignal *)nearbyVenuesWithLimit:(NSUInteger)limit
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        SMetaDisposable *disposable = [[SMetaDisposable alloc] init];
        [disposable setDisposable:[[[self currentLocation] mapToSignal:^SSignal *(id next)
        {
            if ([next isKindOfClass:[NSString class]])
            {
                return [SSignal single:next];
            }
            else if ([next isKindOfClass:[CLLocation class]])
            {
                CLLocation *location = (CLLocation *)next;
                return [[SSignal single:next] then:[self _nearbyVenuesWithCoordinate:location.coordinate limit:limit]];
            }
            
            return nil;
        }] startWithNext:^(id next)
        {
            if ([next isKindOfClass:[NSArray class]])
            {
                [subscriber putNext:next];
                [subscriber putCompletion];
                [disposable dispose];
            }
            else
            {
                [subscriber putNext:next];
            }
        }]];
        
        return nil;
    }];
}

+ (SSignal *)_nearbyVenuesWithCoordinate:(CLLocationCoordinate2D)coordinate limit:(NSUInteger)limit
{
    return [[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeNearbyVenuesSubscription alloc] initWithCoordinate:coordinate limit:limit]];
}

@end
