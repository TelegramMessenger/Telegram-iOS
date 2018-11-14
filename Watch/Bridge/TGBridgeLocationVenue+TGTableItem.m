#import "TGBridgeLocationVenue+TGTableItem.h"

@implementation TGBridgeLocationVenue (TGTableItem)

- (NSString *)uniqueIdentifier
{
    return self.identifier;
}

@end
