
#import <MapKit/MKMapView.h>

typedef enum {
    TGLocationTrackingModeNone,
    TGLocationTrackingModeFollow,
    TGLocationTrackingModeFollowWithHeading
} TGLocationTrackingMode;

@interface TGLocationTrackingButton : UIButton

@property (nonatomic, assign) TGLocationTrackingMode trackingMode;
- (void)setTrackingMode:(TGLocationTrackingMode)trackingMode animated:(bool)animated;

@property (nonatomic, assign, getter=isLocationAvailable) bool locationAvailable;
- (void)setLocationAvailable:(bool)available animated:(bool)animated;

+ (TGLocationTrackingMode)locationTrackingModeWithUserTrackingMode:(MKUserTrackingMode)mode;
+ (MKUserTrackingMode)userTrackingModeWithLocationTrackingMode:(TGLocationTrackingMode)mode;

@end
