#import "TGLocationVenue.h"

#import <LegacyComponents/TGLocationMediaAttachment.h>

NSString *const TGLocationGooglePlacesVenueProvider = @"google";
NSString *const TGLocationFoursquareVenueProvider = @"foursquare";

@interface TGLocationVenue ()
{
    NSString *_displayAddress;
}
@end

@implementation TGLocationVenue

+ (TGLocationVenue *)venueWithFoursquareDictionary:(NSDictionary *)dictionary
{
    TGLocationVenue *venue = [[TGLocationVenue alloc] init];
    venue->_identifier = dictionary[@"id"];
    venue->_name = dictionary[@"name"];
    
    NSDictionary *location = dictionary[@"location"];
    venue->_coordinate = CLLocationCoordinate2DMake([location[@"lat"] doubleValue], [location[@"lng"] doubleValue]);
    
    NSArray *categories = dictionary[@"categories"];
    if (categories.count > 0)
    {
        NSDictionary *category = categories.firstObject;
        NSDictionary *icon = category[@"icon"];
        if (icon != nil)
            venue->_categoryIconUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@64%@", icon[@"prefix"], icon[@"suffix"]]];
        
        NSURL *url = [NSURL URLWithString:icon[@"prefix"]];
        NSArray *components = url.pathComponents;
        NSString *categoryName = [[NSString stringWithFormat:@"%@/%@", [components objectAtIndex:components.count - 2], components.lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"_"]];
        venue->_categoryName = categoryName;
    }
    
    venue->_country = location[@"country"];
    venue->_state = location[@"state"];
    venue->_city = location[@"city"];
    venue->_address = location[@"address"];
    venue->_crossStreet = location[@"crossStreet"];
    
    venue->_provider = TGLocationFoursquareVenueProvider;
    
    return venue;
}

+ (TGLocationVenue *)venueWithGooglePlacesDictionary:(NSDictionary *)dictionary
{
    TGLocationVenue *venue = [[TGLocationVenue alloc] init];
    venue->_identifier = dictionary[@"place_id"];
    venue->_name = dictionary[@"name"];
    
    NSDictionary *location = dictionary[@"geometry"][@"location"];
    venue->_coordinate = CLLocationCoordinate2DMake([location[@"lat"] doubleValue], [location[@"lng"] doubleValue]);
    
    NSArray *types = dictionary[@"types"];
    if (types.count > 0)
    {
        if ([types containsObject:@"political"])
            return nil;
        
        venue->_categoryName = types.firstObject;
    }
    
    venue->_displayAddress = dictionary[@"vicinity"];
    
    venue->_provider = TGLocationGooglePlacesVenueProvider;
    
    return venue;
}

+ (TGLocationVenue *)venueWithLocationAttachment:(TGLocationMediaAttachment *)attachment
{
    TGLocationVenue *venue = [[TGLocationVenue alloc] init];
    venue->_identifier = attachment.venue.venueId;
    venue->_name = attachment.venue.title;
    
    venue->_coordinate = CLLocationCoordinate2DMake(attachment.latitude, attachment.longitude);
    venue->_categoryName = attachment.venue.type;
  
    venue->_displayAddress = attachment.venue.address;
    
    venue->_provider = attachment.venue.provider;
    
    return venue;
}

- (NSString *)displayAddress
{
    if (_displayAddress.length > 0)
        return _displayAddress;
    if (self.street.length > 0)
        return self.street;
    else if (self.city.length > 0)
        return self.city;
    else if (self.country.length > 0)
        return self.country;
    
    return nil;
}

- (NSString *)street
{
    if (self.address.length > 0)
        return self.address;
    else
        return self.crossStreet;
}

- (TGVenueAttachment *)venueAttachment
{
    return [[TGVenueAttachment alloc] initWithTitle:self.name address:self.displayAddress provider:self.provider venueId:self.identifier type:self.categoryName];
}

@end
