#import <LegacyComponents/TGLocationMapViewController.h>
#import <LegacyComponents/LegacyComponentsContext.h>

#import <CoreLocation/CoreLocation.h>

@class TGVenueAttachment;
@class TGUser;

typedef enum {
    TGLocationPickerControllerDefaultIntent,
    TGLocationPickerControllerCustomLocationIntent
} TGLocationPickerControllerIntent;

@interface TGLocationPickerController : TGLocationMapViewController

@property (nonatomic, copy) void (^locationPicked)(CLLocationCoordinate2D coordinate, TGVenueAttachment *venue);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context intent:(TGLocationPickerControllerIntent)intent;

@property (nonatomic, strong) id peer;
@property (nonatomic, assign) bool allowLiveLocationSharing;
@property (nonatomic, assign) bool sharingLiveLocation;

@end
