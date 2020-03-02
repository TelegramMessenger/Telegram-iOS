#import "TGLocationUtils.h"

#import "LegacyComponentsInternal.h"
#import "TGLocalization.h"

#import <MapKit/MapKit.h>

@implementation TGLocationUtils

+ (MKMapRect)MKMapRectForCoordinateRegion:(MKCoordinateRegion)region
{
    MKMapPoint a = MKMapPointForCoordinate(CLLocationCoordinate2DMake(region.center.latitude + region.span.latitudeDelta / 2,
                                                                      region.center.longitude - region.span.longitudeDelta / 2));
    MKMapPoint b = MKMapPointForCoordinate(CLLocationCoordinate2DMake(region.center.latitude - region.span.latitudeDelta / 2,
                                                                      region.center.longitude + region.span.longitudeDelta / 2));
    return MKMapRectMake(MIN(a.x,b.x), MIN(a.y,b.y), ABS(a.x-b.x), ABS(a.y-b.y));
}

+ (bool)requestWhenInUserLocationAuthorizationWithLocationManager:(CLLocationManager *)locationManager
{
    CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
    
    if (authorizationStatus == kCLAuthorizationStatusDenied || authorizationStatus == kCLAuthorizationStatusRestricted)
        return false;
    
    if ([locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)])
    {
        if (authorizationStatus == kCLAuthorizationStatusNotDetermined)
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"TG_askedForAlwaysAuthorization_v0"];
        
        [locationManager requestWhenInUseAuthorization];
        return true;
    }

    return false;
}

+ (bool)requestAlwaysUserLocationAuthorizationWithLocationManager:(CLLocationManager *)locationManager
{
    CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
    if (authorizationStatus == kCLAuthorizationStatusDenied || authorizationStatus == kCLAuthorizationStatusRestricted)
        return false;
    
    if ([locationManager respondsToSelector:@selector(requestAlwaysAuthorization)])
    {
        NSString *key = @"TG_askedForAlwaysAuthorization_v0";
        bool askedForAlwaysAuthorization = [[[NSUserDefaults standardUserDefaults] objectForKey:key] boolValue];
        if (authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse && askedForAlwaysAuthorization)
            return false;
        
        [locationManager requestAlwaysAuthorization];
        [[NSUserDefaults standardUserDefaults] setObject:@true forKey:key];
        
        return true;
    }
    
    return false;
}

+ (NSString *)stringFromDistance:(CLLocationDistance)distance
{
    if (iosMajorVersion() >= 7)
    {
        MKDistanceFormatter *formatter = [self sharedDistanceFormatter];
        NSString *systemLocale = [NSLocale currentLocale].localeIdentifier;
        NSString *finalLocale = legacyEffectiveLocalization().code;
        NSRange range = [systemLocale rangeOfString:@"_"];
        if (range.location != NSNotFound) {
            finalLocale = [finalLocale stringByAppendingString:[systemLocale substringFromIndex:range.location]];
        }
        formatter.locale = [NSLocale localeWithLocaleIdentifier:finalLocale];
        if ([[formatter.locale objectForKey:NSLocaleUsesMetricSystem] boolValue])
            formatter.unitStyle = MKDistanceFormatterUnitStyleAbbreviated;
        else
            formatter.unitStyle = MKDistanceFormatterUnitStyleDefault;
        
        return [[self sharedDistanceFormatter] stringFromDistance:distance];
    }
    else
    {
        return [self _customStringFromDistance:distance];
    }
}

+ (NSString *)stringFromAccuracy:(CLLocationAccuracy)accuracy
{
    if (iosMajorVersion() >= 7)
    {
        MKDistanceFormatter *formatter = [self sharedAccuracyFormatter];
        //formatter.locale = [NSLocale localeWithLocaleIdentifier:legacyEffectiveLocalization().code];
        return [[self sharedAccuracyFormatter] stringFromDistance:accuracy];
    }
    else
    {
        return [self _customStringFromDistance:accuracy];
    }
}

+ (NSString *)stringForCoordinate:(CLLocationCoordinate2D)coordinate
{
    NSInteger latSeconds = (NSInteger)(coordinate.latitude * 3600);
    NSInteger latDegrees = latSeconds / 3600;
    latSeconds = labs(latSeconds % 3600);
    NSInteger latMinutes = latSeconds / 60;
    latSeconds %= 60;
    
    NSInteger longSeconds = (NSInteger)(coordinate.longitude * 3600);
    NSInteger longDegrees = longSeconds / 3600;
    longSeconds = labs(longSeconds % 3600);
    NSInteger longMinutes = longSeconds / 60;
    longSeconds %= 60;
    
    NSString *result = [NSString stringWithFormat:@"%@%02ld° %02ld' %02ld\" %@%02ld° %02ld' %02ld\"", latDegrees >= 0 ? @"N" : @"S", labs(latDegrees), (long)latMinutes, (long)latSeconds, longDegrees >= 0 ? @"E" : @"W", labs(longDegrees), (long)longMinutes, (long)longSeconds];
    
    return result;
}

+ (NSString *)_customStringFromDistance:(CLLocationDistance)distance
{
    NSLocale *locale = [NSLocale localeWithLocaleIdentifier:legacyEffectiveLocalization().code];
    bool metricUnits = [[locale objectForKey:NSLocaleUsesMetricSystem] boolValue];
    
    NSString *distanceString = nil;
    
    if (metricUnits)
    {
        if (distance >= 1000 * 1000)
            distanceString = [[NSString alloc] initWithFormat:@"%.1fK km", distance / (1000.0 * 1000.0)];
        else if (distance > 1000)
            distanceString = [[NSString alloc] initWithFormat:@"%.1f km", distance / 1000.0];
        else
            distanceString = [[NSString alloc] initWithFormat:@"%d m", (int)distance];
    }
    else
    {
        double feetDistance = distance / 0.3048;
        
        if (feetDistance >= 5280)
        {
            char buf[32];
            snprintf(buf, 32, "%.1f", feetDistance / 5280.0);
            bool dot = false;
            for (int i = 0; i < 32; i++)
            {
                char c = buf[i];
                if (c == '\0')
                    break;
                else if (c < '0' || c > '9')
                {
                    dot = true;
                    break;
                }
            }
            distanceString = [[NSString alloc] initWithFormat:@"%s mile%s", buf, dot || feetDistance / 5280.0 > 1.0 ? "s" : ""];
        }
        else
        {
            distanceString = [[NSString alloc] initWithFormat:@"%d %s", (int)feetDistance, (int)feetDistance != 1 ? "feet" : "foot"];
        }
    }
    
    return distanceString;
}

+ (MKDistanceFormatter *)sharedDistanceFormatter
{
    static dispatch_once_t once;
    static MKDistanceFormatter *distanceFormatter;
    dispatch_once(&once, ^
    {
        distanceFormatter = [[MKDistanceFormatter alloc] init];
    });
    
    return distanceFormatter;
}

+ (MKDistanceFormatter *)sharedAccuracyFormatter
{
    static dispatch_once_t once;
    static MKDistanceFormatter *accuracyFormatter;
    dispatch_once(&once, ^
    {
        accuracyFormatter = [[MKDistanceFormatter alloc] init];
        accuracyFormatter.unitStyle = MKDistanceFormatterUnitStyleFull;
    });
    
    return accuracyFormatter;
}

@end

const NSInteger TGGoogleMapsOffset = 268435456;
const CGFloat TGGoogleMapsRadius = TGGoogleMapsOffset / (CGFloat)M_PI;

@implementation TGLocationUtils (GoogleMaps)

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

@implementation TGLocationUtils (ThirdPartyAppLauncher)

#pragma mark Apple Maps

+ (void)openMapsWithCoordinate:(CLLocationCoordinate2D)coordinate withDirections:(bool)withDirections locationName:(NSString *)locationName
{
    MKPlacemark *placemark = [[MKPlacemark alloc] initWithCoordinate:coordinate
                                                   addressDictionary:nil];
    MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:placemark];
    [mapItem setName:locationName];
    
    if (withDirections)
    {
        NSDictionary *options = @{ MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDriving };
        MKMapItem *currentLocationMapItem = [MKMapItem mapItemForCurrentLocation];
        [MKMapItem openMapsWithItems:@[ currentLocationMapItem, mapItem ]
                       launchOptions:options];
    }
    else
    {
        [mapItem openInMapsWithLaunchOptions:nil];
    }
}

#pragma mark Google Maps

+ (void)openGoogleMapsWithCoordinate:(CLLocationCoordinate2D)coordinate withDirections:(bool)withDirections
{
    NSURL *url = nil;
    NSString *coordinatePair = [NSString stringWithFormat:@"%f,%f", coordinate.latitude, coordinate.longitude];
    
    if (withDirections)
    {
        url = [NSURL URLWithString:[[NSString alloc] initWithFormat:@"comgooglemaps-x-callback://?daddr=%@&directionsmode=driving&x-success=telegram://?resume=true&&x-source=Telegram", coordinatePair]];
    }
    else
    {
        url = [NSURL URLWithString:[[NSString alloc] initWithFormat:@"comgooglemaps-x-callback://?center=%@&q=%@&x-success=telegram://?resume=true&&x-source=Telegram", coordinatePair, coordinatePair]];
    }

    [[LegacyComponentsGlobals provider] openURL:url];
}

+ (bool)isGoogleMapsInstalled
{
    return [[LegacyComponentsGlobals provider] canOpenURL:[NSURL URLWithString:@"comgooglemaps-x-callback://"]];
}


+ (void)openGoogleWithPlaceId:(NSString *)placeId
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://maps.google.com/maps/place?cid=%@", placeId]];
    [[LegacyComponentsGlobals provider] openURL:url];
}
#pragma mark Foursquare

+ (void)openFoursquareWithVenueId:(NSString *)venueId
{
    NSURL *url = nil;
    
    if ([self isFoursquareInstalled])
        url = [NSURL URLWithString:[NSString stringWithFormat:@"foursquare://venues/%@", venueId]];
    else
        url = [NSURL URLWithString:[NSString stringWithFormat:@"https://foursquare.com/venue/%@", venueId]];
    
    [[LegacyComponentsGlobals provider] openURL:url];
}

+ (bool)isFoursquareInstalled
{
    return [[LegacyComponentsGlobals provider] canOpenURL:[NSURL URLWithString:@"foursquare://"]];
}

#pragma mark Here Maps

+ (void)openHereMapsWithCoordinate:(CLLocationCoordinate2D)coordinate
{
    NSURL *url = [NSURL URLWithString:[[NSString alloc] initWithFormat:@"here-location://%f,%f", coordinate.latitude, coordinate.longitude]];
    
    [[LegacyComponentsGlobals provider] openURL:url];
}

+ (bool)isHereMapsInstalled
{
    return [[LegacyComponentsGlobals provider] canOpenURL:[NSURL URLWithString:@"here-location://"]];
}

#pragma mark Yandex Maps

+ (void)openYandexMapsWithCoordinate:(CLLocationCoordinate2D)coordinate withDirections:(bool)withDirections
{
    NSURL *url = nil;
    
    if (withDirections)
    {
        url = [NSURL URLWithString:[[NSString alloc] initWithFormat:@"yandexmaps://build_route_on_map?lat_to=%f&lon_to=%f", coordinate.latitude, coordinate.longitude]];
    }
    else
    {
        url = [NSURL URLWithString:[[NSString alloc] initWithFormat:@"yandexmaps://maps.yandex.ru/?pt=%f,%f&z=16", coordinate.longitude, coordinate.latitude]];
    }
    
    [[LegacyComponentsGlobals provider] openURL:url];
}

+ (bool)isYandexMapsInstalled
{
    return [[LegacyComponentsGlobals provider] canOpenURL:[NSURL URLWithString:@"yandexmaps://"]];
}

#pragma mark Yandex Navigator

+ (void)openDirectionsInYandexNavigatorWithCoordinate:(CLLocationCoordinate2D)coordinate
{
    NSURL *url = [NSURL URLWithString:[[NSString alloc] initWithFormat:@"yandexnavi://build_route_on_map?lat_to=%f&lon_to=%f", coordinate.latitude, coordinate.longitude]];
    
    [[LegacyComponentsGlobals provider] openURL:url];
}

+ (bool)isYandexNavigatorInstalled
{
    return [[LegacyComponentsGlobals provider] canOpenURL:[NSURL URLWithString:@"yandexnavi://"]];
}

#pragma mark - Waze

+ (void)openWazeWithCoordinate:(CLLocationCoordinate2D)coordinate withDirections:(bool)withDirections
{
    NSURL *url = nil;
    
    if (withDirections)
    {
        url = [NSURL URLWithString:[[NSString alloc] initWithFormat:@"waze://?ll=%f,%f&navigate=yes", coordinate.latitude, coordinate.longitude]];
    }
    else
    {
        url = [NSURL URLWithString:[[NSString alloc] initWithFormat:@"waze://?ll=%f,%f", coordinate.latitude, coordinate.longitude]];
    }
    
    [[LegacyComponentsGlobals provider] openURL:url];
}

+ (bool)isWazeInstalled
{
    return [[LegacyComponentsGlobals provider] canOpenURL:[NSURL URLWithString:@"waze://"]];
}

@end
