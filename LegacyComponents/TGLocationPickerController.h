#import <LegacyComponents/LegacyComponents.h>

#import <CoreLocation/CoreLocation.h>

@class TGVenueAttachment;

typedef enum {
    TGLocationPickerControllerDefaultIntent,
    TGLocationPickerControllerCustomLocationIntent
} TGLocationPickerControllerIntent;

@interface TGLocationPickerController : TGViewController

@property (nonatomic, copy) void (^locationPicked)(CLLocationCoordinate2D coordinate, TGVenueAttachment *venue);

- (instancetype)initWithIntent:(TGLocationPickerControllerIntent)intent;

@end
