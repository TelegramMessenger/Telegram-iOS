#import <CoreLocation/CoreLocation.h>

@interface TGLocationReverseGeocodeResult : NSObject

@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;

@property (nonatomic, readonly) NSString *displayAddress;

@property (nonatomic, readonly) NSString *country;
@property (nonatomic, readonly) NSString *countryAbbr;
@property (nonatomic, readonly) NSString *state;
@property (nonatomic, readonly) NSString *stateAbbr;
@property (nonatomic, readonly) NSString *city;
@property (nonatomic, readonly) NSString *district;
@property (nonatomic, readonly) NSString *street;
    
@property (nonatomic, readonly) NSString *fullAddress;

+ (TGLocationReverseGeocodeResult *)reverseGeocodeResultWithDictionary:(NSDictionary *)dictionary;
+ (TGLocationReverseGeocodeResult *)reverseGeocodeResultWithPlacemark:(CLPlacemark *)placemark;

@end
