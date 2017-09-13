#import <LegacyComponents/TGViewController.h>
#import <LegacyComponents/LegacyComponentsContext.h>

#import <CoreLocation/CoreLocation.h>

@class TGVenueAttachment;

typedef enum {
    TGLocationPickerControllerDefaultIntent,
    TGLocationPickerControllerCustomLocationIntent
} TGLocationPickerControllerIntent;

@interface TGLocationPickerController : TGViewController

@property (nonatomic, copy) void (^locationPicked)(CLLocationCoordinate2D coordinate, TGVenueAttachment *venue);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context intent:(TGLocationPickerControllerIntent)intent;

@end
