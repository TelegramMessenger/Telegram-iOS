#import <MapKit/MapKit.h>

@interface TGLocationMapView : MKMapView

@property (nonatomic, copy) void(^singleTap)(void);

@property (nonatomic, copy) bool(^customAnnotationTap)(CGPoint);

@property (nonatomic, assign) bool longPressAsTapEnabled;
@property (nonatomic, assign) bool tapEnabled;
@property (nonatomic, assign) bool manipulationEnabled;

@property (nonatomic, assign) bool allowAnnotationSelectionChanges;

@property (nonatomic, assign) UIEdgeInsets compassInsets;

@end
