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

@end