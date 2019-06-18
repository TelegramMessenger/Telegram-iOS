#import "TGLocationReverseGeocodeResult.h"

@implementation TGLocationReverseGeocodeResult

+ (TGLocationReverseGeocodeResult *)reverseGeocodeResultWithDictionary:(NSDictionary *)dictionary
{
    TGLocationReverseGeocodeResult *result = [[TGLocationReverseGeocodeResult alloc] init];
    
    for (NSDictionary *component in dictionary[@"address_components"])
    {
        NSArray *types = component[@"types"];
        __unused NSString *shortName = component[@"short_name"];
        NSString *longName = component[@"long_name"];
        
        if ([types containsObject:@"country"])
        {
            result->_country = longName;
            result->_countryAbbr = shortName;
        }
        else if ([types containsObject:@"administrative_area_level_1"])
        {
            result->_state = longName;
            result->_stateAbbr = shortName;
        }
        else if ([types containsObject:@"locality"])
        {
            result->_city = longName;
        }
        else if ([types containsObject:@"sublocality"])
        {
            result->_district = longName;
        }
        else if ([types containsObject:@"neighborhood"])
        {
            if (result->_district.length == 0)
                result->_district = longName;
        }
        else if ([types containsObject:@"route"])
        {
            result->_street = longName;
        }
    }
    
    return result;
}

+ (TGLocationReverseGeocodeResult *)reverseGeocodeResultWithPlacemark:(CLPlacemark *)placemark
{
    TGLocationReverseGeocodeResult *result = [[TGLocationReverseGeocodeResult alloc] init];
    result->_country = placemark.country;
    result->_countryAbbr = placemark.ISOcountryCode;
    result->_city = placemark.locality;
    result->_district = placemark.subLocality;
    result->_street = placemark.thoroughfare;
    if (placemark.name.length > 0 && result->_street.length == 0) {
        result->_street = placemark.name;
    }
    return result;
}

- (NSString *)displayAddress
{
    if (self.street.length > 0)
        return self.street;
    else if (self.city.length > 0)
        return self.city;
    else if (self.country.length > 0)
        return self.country;
    
    return nil;
}
    
- (NSString *)fullAddress
{
    NSMutableArray *components = [[NSMutableArray alloc] init];
    if (self.street.length > 0)
        [components addObject:self.street];
    if (self.city.length > 0)
        [components addObject:self.city];
    if (self.country.length > 0)
        [components addObject:self.country];
    return [components componentsJoinedByString:@", "];
}

@end
