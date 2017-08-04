#import <MapKit/MapKit.h>

@interface TGLocationMapView : MKMapView

@property (nonatomic, copy) void(^singleTap)(void);

@property (nonatomic, assign) bool longPressAsTapEnabled;
@property (nonatomic, assign) bool tapEnabled;
@property (nonatomic, assign) bool manipulationEnabled;

@end
