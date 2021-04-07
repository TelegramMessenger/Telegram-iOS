#import "TGBridgeLocationMediaAttachment.h"

const NSInteger TGBridgeLocationMediaAttachmentType = 0x0C9ED06E;

NSString *const TGBridgeLocationMediaLatitudeKey = @"lat";
NSString *const TGBridgeLocationMediaLongitudeKey = @"lon";
NSString *const TGBridgeLocationMediaVenueKey = @"venue";

NSString *const TGBridgeVenueTitleKey = @"title";
NSString *const TGBridgeVenueAddressKey = @"address";
NSString *const TGBridgeVenueProviderKey = @"provider";
NSString *const TGBridgeVenueIdKey = @"venueId";

@implementation TGBridgeVenueAttachment

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _title = [aDecoder decodeObjectForKey:TGBridgeVenueTitleKey];
        _address = [aDecoder decodeObjectForKey:TGBridgeVenueAddressKey];
        _provider = [aDecoder decodeObjectForKey:TGBridgeVenueProviderKey];
        _venueId = [aDecoder decodeObjectForKey:TGBridgeVenueIdKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.title forKey:TGBridgeVenueTitleKey];
    [aCoder encodeObject:self.address forKey:TGBridgeVenueAddressKey];
    [aCoder encodeObject:self.provider forKey:TGBridgeVenueProviderKey];
    [aCoder encodeObject:self.venueId forKey:TGBridgeVenueIdKey];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    
    TGBridgeVenueAttachment *venue = (TGBridgeVenueAttachment *)object;
    
    return [self.title isEqualToString:venue.title] && [self.address isEqualToString:venue.address] && [self.provider isEqualToString:venue.provider] && [self.venueId isEqualToString:venue.venueId];
}

@end


@implementation TGBridgeLocationMediaAttachment

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self != nil)
    {
        _latitude = [aDecoder decodeDoubleForKey:TGBridgeLocationMediaLatitudeKey];
        _longitude = [aDecoder decodeDoubleForKey:TGBridgeLocationMediaLongitudeKey];
        _venue = [aDecoder decodeObjectForKey:TGBridgeLocationMediaVenueKey];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeDouble:self.latitude forKey:TGBridgeLocationMediaLatitudeKey];
    [aCoder encodeDouble:self.longitude forKey:TGBridgeLocationMediaLongitudeKey];
    [aCoder encodeObject:self.venue forKey:TGBridgeLocationMediaVenueKey];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    
    if (!object || ![object isKindOfClass:[self class]])
        return NO;
    
    TGBridgeLocationMediaAttachment *location = (TGBridgeLocationMediaAttachment *)object;
    
    bool equalCoord = (fabs(self.latitude - location.latitude) < DBL_EPSILON && fabs(self.longitude - location.longitude) < DBL_EPSILON);
    bool equalVenue = (self.venue == nil && location.venue == nil) || ([self.venue isEqual:location.venue]);
    
    return equalCoord || equalVenue;
}

+ (NSInteger)mediaType
{
    return TGBridgeLocationMediaAttachmentType;
}

@end
