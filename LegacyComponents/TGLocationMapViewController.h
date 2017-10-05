#import <LegacyComponents/TGViewController.h>
#import <LegacyComponents/LegacyComponentsContext.h>

#import <MapKit/MapKit.h>

#import <SSignalKit/SSignalKit.h>

@class TGLocationMapView;
@class TGLocationOptionsView;

@interface TGLocationMapViewController : TGViewController <UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, MKMapViewDelegate>
{
    CLLocationManager *_locationManager;
    bool _locationServicesDisabled;
    
    CGFloat _tableViewTopInset;
    CGFloat _tableViewBottomInset;
    UITableView *_tableView;
    UIActivityIndicatorView *_activityIndicator;
    UILabel *_messageLabel;
    
    UIView *_mapViewWrapper;
    TGLocationMapView *_mapView;
    TGLocationOptionsView *_optionsView;
    UIImageView *_edgeView;
    UIImageView *_edgeHighlightView;
}

@property (nonatomic, copy) void (^liveLocationStarted)(CLLocationCoordinate2D coordinate, int32_t period);
@property (nonatomic, copy) void (^liveLocationStopped)(void);

- (void)userLocationButtonPressed;

- (void)setMapCenterCoordinate:(CLLocationCoordinate2D)coordinate offset:(CGPoint)offset animated:(bool)animated;
- (void)setMapCenterCoordinate:(CLLocationCoordinate2D)coordinate span:(MKCoordinateSpan)span offset:(CGPoint)offset animated:(bool)animated;

- (void)updateInsets;
- (void)updateMapHeightAnimated:(bool)animated;

- (CGFloat)visibleContentHeight;
- (CGFloat)mapHeight;

- (bool)hasUserLocation;
- (SSignal *)userLocationSignal;
- (bool)locationServicesDisabled;
- (void)updateLocationAvailability;

@property (nonatomic, strong) id receivingPeer;
- (void)_presentLiveLocationMenu:(CLLocationCoordinate2D)coordinate dismissOnCompletion:(bool)dismissOnCompletion;
- (CGRect)_liveLocationMenuSourceRect;
- (void)_willStartOwnLiveLocation;

@end

extern const CGFloat TGLocationMapInset;
extern const CGFloat TGLocationMapClipHeight;
extern const MKCoordinateSpan TGLocationDefaultSpan;
