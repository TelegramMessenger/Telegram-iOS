#import <LegacyComponents/TGViewController.h>
#import <LegacyComponents/LegacyComponentsContext.h>

#import <MapKit/MapKit.h>

#import <SSignalKit/SSignalKit.h>

@class TGLocationMapView;
@class TGLocationOptionsView;

@class TGSearchBarPallete;

@interface TGLocationPallete : NSObject

@property (nonatomic, readonly) UIColor *backgroundColor;
@property (nonatomic, readonly) UIColor *selectionColor;
@property (nonatomic, readonly) UIColor *separatorColor;
@property (nonatomic, readonly) UIColor *textColor;
@property (nonatomic, readonly) UIColor *secondaryTextColor;
@property (nonatomic, readonly) UIColor *accentColor;
@property (nonatomic, readonly) UIColor *destructiveColor;
@property (nonatomic, readonly) UIColor *locationColor;
@property (nonatomic, readonly) UIColor *liveLocationColor;
@property (nonatomic, readonly) UIColor *iconColor;
@property (nonatomic, readonly) UIColor *sectionHeaderBackgroundColor;
@property (nonatomic, readonly) UIColor *sectionHeaderTextColor;
@property (nonatomic, readonly) TGSearchBarPallete *searchBarPallete;
@property (nonatomic, readonly) UIImage *avatarPlaceholder;

+ (instancetype)palleteWithBackgroundColor:(UIColor *)backgroundColor selectionColor:(UIColor *)selectionColor separatorColor:(UIColor *)separatorColor textColor:(UIColor *)textColor secondaryTextColor:(UIColor *)secondaryTextColor accentColor:(UIColor *)accentColor destructiveColor:(UIColor *)destructiveColor locationColor:(UIColor *)locationColor liveLocationColor:(UIColor *)liveLocationColor iconColor:(UIColor *)iconColor sectionHeaderBackgroundColor:(UIColor *)sectionHeaderBackgroundColor sectionHeaderTextColor:(UIColor *)sectionHeaderTextColor searchBarPallete:(TGSearchBarPallete *)searchBarPallete avatarPlaceholder:(UIImage *)avatarPlaceholder;

@end

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

@property (nonatomic, strong) TGLocationPallete *pallete;
@property (nonatomic, readonly, strong) UIView *locationMapView;

- (void)userLocationButtonPressed;

- (void)setMapCenterCoordinate:(CLLocationCoordinate2D)coordinate offset:(CGPoint)offset animated:(bool)animated;
- (void)setMapCenterCoordinate:(CLLocationCoordinate2D)coordinate span:(MKCoordinateSpan)span offset:(CGPoint)offset animated:(bool)animated;

- (void)updateInsets;
- (void)updateMapHeightAnimated:(bool)animated;

- (CGFloat)visibleContentHeight;
- (CGFloat)mapHeight;
- (CGFloat)safeAreaInsetBottom;

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
