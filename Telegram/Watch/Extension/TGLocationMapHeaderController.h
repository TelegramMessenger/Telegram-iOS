#import "WKInterfaceTable+TGDataDrivenTable.h"

@interface TGLocationMapHeaderController : TGTableRowController

@property (nonatomic, weak) IBOutlet WKInterfaceMap *map;
@property (nonatomic, weak) IBOutlet WKInterfaceButton *currentLocationButton;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *currentLocationLabel;
- (IBAction)currentLocationPressedAction;

@property (nonatomic, copy) void (^currentLocationPressed)(void);

- (void)updateWithLocation:(CLLocation *)location;

@end
