#import "TGLocationVenueRowController.h"

#import "TGBridgeLocationVenue.h"

NSString *const TGLocationVenueRowIdentifier = @"TGLocationVenueRow";

@implementation TGLocationVenueRowController

- (void)updateWithLocationVenue:(TGBridgeLocationVenue *)locationVenue
{
    self.nameLabel.text = locationVenue.name;
    self.addressLabel.text = locationVenue.address.length > 0 ? locationVenue.address : @" ";
}

+ (NSString *)identifier
{
    return TGLocationVenueRowIdentifier;
}

@end
