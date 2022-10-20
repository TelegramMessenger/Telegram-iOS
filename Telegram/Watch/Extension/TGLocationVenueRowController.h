#import "WKInterfaceTable+TGDataDrivenTable.h"

@class TGBridgeLocationVenue;

@interface TGLocationVenueRowController : TGTableRowController

@property (nonatomic, weak) IBOutlet WKInterfaceLabel *nameLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *addressLabel;

- (void)updateWithLocationVenue:(TGBridgeLocationVenue *)locationVenue;

@end
