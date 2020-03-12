#import <LegacyComponents/TGLocationMapViewController.h>
#import <LegacyComponents/LegacyComponentsContext.h>

#import <CoreLocation/CoreLocation.h>

@class TGVenueAttachment;
@class TGUser;
@class TGMessage;

typedef enum {
    TGLocationPickerControllerDefaultIntent,
    TGLocationPickerControllerCustomLocationIntent
} TGLocationPickerControllerIntent;

@interface TGLocationPickerController : TGLocationMapViewController

@property (nonatomic, copy) void (^locationPicked)(CLLocationCoordinate2D coordinate, TGVenueAttachment *venue, NSString *address);

@property (nonatomic, copy) SSignal *(^nearbyPlacesSignal)(NSString *query, CLLocation *coordinate);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context intent:(TGLocationPickerControllerIntent)intent;

- (void)setLiveLocationsSignal:(SSignal *)signal;
@property (nonatomic, copy) SSignal *(^remainingTimeForMessage)(TGMessage *message);

@property (nonatomic, strong) id peer;
@property (nonatomic, assign) bool allowLiveLocationSharing;

@end
