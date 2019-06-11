#import <MapKit/MKMapView.h>
#import "TGModernButton.h"

typedef enum {
    TGLocationTrackingModeNone,
    TGLocationTrackingModeFollow,
    TGLocationTrackingModeFollowWithHeading
} TGLocationTrackingMode;

@interface TGLocationTrackingButton : TGModernButton

@property (nonatomic, assign) TGLocationTrackingMode trackingMode;
- (void)setTrackingMode:(TGLocationTrackingMode)trackingMode animated:(bool)animated;

@property (nonatomic, assign, getter=isLocationAvailable) bool locationAvailable;
- (void)setLocationAvailable:(bool)available animated:(bool)animated;

- (void)setAccentColor:(UIColor *)accentColor spinnerColor:(UIColor *)spinnerColor;

+ (TGLocationTrackingMode)locationTrackingModeWithUserTrackingMode:(MKUserTrackingMode)mode;
+ (MKUserTrackingMode)userTrackingModeWithLocationTrackingMode:(TGLocationTrackingMode)mode;

@end
