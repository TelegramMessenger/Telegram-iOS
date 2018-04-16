#import <CoreLocation/CoreLocation.h>

@class TGVenueAttachment;
@class TGLocationMediaAttachment;

@interface TGLocationVenue : NSObject

@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *displayAddress;
@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (nonatomic, readonly) NSString *categoryName;
@property (nonatomic, readonly) NSURL *categoryIconUrl;

@property (nonatomic, readonly) NSString *provider;

@property (readonly, nonatomic) NSString *country;
@property (readonly, nonatomic) NSString *state;
@property (readonly, nonatomic) NSString *city;
@property (readonly, nonatomic) NSString *address;
@property (readonly, nonatomic) NSString *crossStreet;
@property (readonly, nonatomic) NSString *street;

- (TGVenueAttachment *)venueAttachment;

+ (TGLocationVenue *)venueWithFoursquareDictionary:(NSDictionary *)dictionary;
+ (TGLocationVenue *)venueWithGooglePlacesDictionary:(NSDictionary *)dictionary;

+ (TGLocationVenue *)venueWithLocationAttachment:(TGLocationMediaAttachment *)attachment;

@end

extern NSString *const TGLocationGooglePlacesVenueProvider;
extern NSString *const TGLocationFoursquareVenueProvider;
