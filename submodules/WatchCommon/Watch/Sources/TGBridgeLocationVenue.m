#import "TGBridgeLocationVenue.h"

#import "TGBridgeLocationMediaAttachment.h"

NSString *const TGBridgeLocationVenueLatitudeKey = @"lat";
NSString *const TGBridgeLocationVenueLongitudeKey = @"lon";
NSString *const TGBridgeLocationVenueIdentifierKey = @"identifier";
NSString *const TGBridgeLocationVenueProviderKey = @"provider";
NSString *const TGBridgeLocationVenueNameKey = @"name";
NSString *const TGBridgeLocationVenueAddressKey = @"address";

@implementation TGBridgeLocationVenue

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _coordinate = CLLocationCoordinate2DMake([aDecoder decodeDoubleForKey:TGBridgeLocationVenueLatitudeKey], [aDecoder decodeDoubleForKey:TGBridgeLocationVenueLongitudeKey]);
        _identifier = [aDecoder decodeObjectForKey:TGBridgeLocationVenueIdentifierKey];
        _provider = [aDecoder decodeObjectForKey:TGBridgeLocationVenueProviderKey];
        _name = [aDecoder decodeObjectForKey:TGBridgeLocationVenueNameKey];
        _address = [aDecoder decodeObjectForKey:TGBridgeLocationVenueAddressKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeDouble:self.coordinate.latitude forKey:TGBridgeLocationVenueLatitudeKey];
    [aCoder encodeDouble:self.coordinate.longitude forKey:TGBridgeLocationVenueLongitudeKey];
    [aCoder encodeObject:self.identifier forKey:TGBridgeLocationVenueIdentifierKey];
    [aCoder encodeObject:self.provider forKey:TGBridgeLocationVenueProviderKey];
    [aCoder encodeObject:self.name forKey:TGBridgeLocationVenueNameKey];
    [aCoder encodeObject:self.address forKey:TGBridgeLocationVenueAddressKey];
}

- (TGBridgeLocationMediaAttachment *)locationAttachment
{
    TGBridgeLocationMediaAttachment *attachment = [[TGBridgeLocationMediaAttachment alloc] init];
    attachment.latitude = self.coordinate.latitude;
    attachment.longitude = self.coordinate.longitude;
    
    TGBridgeVenueAttachment *venueAttachment = [[TGBridgeVenueAttachment alloc] init];
    venueAttachment.title = self.name;
    venueAttachment.address = self.address;
    venueAttachment.provider = self.provider;
    venueAttachment.venueId = self.identifier;
    
    attachment.venue = venueAttachment;
    
    return attachment;
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    
    return [self.identifier isEqualToString:((TGBridgeLocationVenue *)object).identifier];
}

@end
