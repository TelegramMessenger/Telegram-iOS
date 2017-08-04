#import "TGLocationPickerController.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"

#import <MapKit/MapKit.h>

#import "TGLocationUtils.h"

#import "TGLocationSignals.h"

#import "TGListsTableView.h"
#import "TGSearchBar.h"
#import "TGSearchDisplayMixin.h"
#import <LegacyComponents/TGModernButton.h>
#import <LegacyComponents/TGModernBarButton.h>
#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>

#import "TGLocationAnnotation.h"
#import "TGLocationReverseGeocodeResult.h"

#import "TGLocationMapView.h"
#import "TGLocationPinView.h"
#import "TGPickPinAnnotationView.h"

#import "TGLocationVenue.h"

#import "TGLocationVenueCell.h"
#import "TGLocationCurrentLocationCell.h"
#import "TGLocationSectionHeaderCell.h"
#import "TGLocationTrackingButton.h"
#import "TGLocationMapModeControl.h"

const CGFloat TGLocationPickerMapClipHeight = 1600.0f;
const CGFloat TGLocationPickerMapWidescreenHeight = 342.0f;
const CGFloat TGLocationPickerMapHeight = 265.0f;
const CGFloat TGLocationPickerMapInset = 280.0f;
const MKCoordinateSpan TGLocationDefaultSpan = { 0.008, 0.008 };
const CGPoint TGLocationPickerPinOffset = { 0.0f, 33.0f };

const TGLocationPlacesService TGLocationPickerPlacesProvider = TGLocationPlacesServiceFoursquare;

@interface TGLocationPair : NSObject

@property (nonatomic, readonly) CLLocation *location;
@property (nonatomic, readonly, getter=isCurrent) bool current;
@property (nonatomic, assign) bool onlyLocationUpdate;

@end

@implementation TGLocationPair

+ (TGLocationPair *)pairWithLocation:(CLLocation *)location isCurrent:(bool)isCurrent onlyLocationUpdate:(bool)onlyLocationUpdate
{
    TGLocationPair *pair = [[TGLocationPair alloc] init];
    pair->_location = location;
    pair->_current = isCurrent;
    pair->_onlyLocationUpdate = onlyLocationUpdate;
    return pair;
}

@end

@interface TGLocationPickerController () <UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate, TGSearchBarDelegate, TGSearchDisplayMixinDelegate>
{
    TGLocationPickerControllerIntent _intent;
    
    CLLocationManager *_locationManager;
    bool _locationServicesDisabled;
    
    bool _nearbyVenuesLoadFailed;
    NSArray *_nearbyVenues;
    NSArray *_searchResults;
    NSString *_searchResultsQuery;
    
    TGLocationAnnotation *_annotation;
    TGLocationAnnotation *_customAnnotation;
    
    CLLocation *_currentUserLocation;
    CLLocation *_startLocation;
    CLLocation *_venuesFetchLocation;
    SMetaDisposable *_locationUpdateDisposable;
    void (^_userLocationObserver)(CLLocation *location);
    
    SMetaDisposable *_nearbyVenuesDisposable;
    SMetaDisposable *_searchDisposable;
    SMetaDisposable *_reverseGeocodeDisposable;
    
    UIView *_pickerPinWrapper;
    TGLocationPinView *_pickerPinView;
    TGPickPinAnnotationView *_pickerAnnotationView;
    
    NSValue *_fullScreenMapSpan;
    
    UIView *_mapClipView;
    UIView *_mapViewWrapper;
    TGLocationMapView *_mapView;
    bool _mapInFullScreenMode;
    bool _pinMovedFromUserLocation;
    bool _updatePinAnnotation;
    
    CGFloat _tableViewTopInset;
    UITableView *_nearbyVenuesTableView;
    
    UIView *_searchBarOverlay;
    UIBarButtonItem *_searchButtonItem;
    UIView *_searchReferenceView;
    UIView *_searchBarWrapper;
    TGSearchBar *_searchBar;
    TGSearchDisplayMixin *_searchMixin;
    
    UIActivityIndicatorView *_activityIndicator;
    UILabel *_messageLabel;
    
    UIView *_toolbarWrapperView;
    UIView *_toolbarView;
    TGModernButton *_userLocationButton;
    TGModernButton *_showPlacesButton;
    UIImageView *_mapModeControlMask;
    TGLocationMapModeControl *_mapModeControl;
    TGModernButton *_mapModeButton;
    
    UIImageView *_attributionView;
}
@end

@implementation TGLocationPickerController

- (instancetype)init
{
    return [self initWithIntent:TGLocationPickerControllerDefaultIntent];
}

- (instancetype)initWithIntent:(TGLocationPickerControllerIntent)intent
{
    self = [super init];
    if (self != nil)
    {
        _intent = intent;
        _locationManager = [[CLLocationManager alloc] init];

        _locationUpdateDisposable = [[SMetaDisposable alloc] init];
        _nearbyVenuesDisposable = [[SMetaDisposable alloc] init];
        
        self.title = TGLocalized(@"Map.ChooseLocationTitle");
        [self setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelButtonPressed)]];
        
        _searchButtonItem = [self controllerRightBarButtonItem];
        _searchButtonItem.enabled = false;
        [self setRightBarButtonItem:_searchButtonItem];
        
        [TGLocationUtils requestWhenInUserLocationAuthorizationWithLocationManager:_locationManager];
    }
    return self;
}

- (void)dealloc
{
    [_locationUpdateDisposable dispose];
    [_nearbyVenuesDisposable dispose];
    [_searchDisposable dispose];
    
    _mapView.delegate = nil;
    _searchBar.delegate = nil;
    _searchMixin.delegate = nil;
    
    _nearbyVenuesTableView.dataSource = nil;
    _nearbyVenuesTableView.delegate = nil;
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    _nearbyVenuesTableView = [[UITableView alloc] initWithFrame:self.view.bounds];
    _nearbyVenuesTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _nearbyVenuesTableView.dataSource = self;
    _nearbyVenuesTableView.delegate = self;
    _nearbyVenuesTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [self.view addSubview:_nearbyVenuesTableView];
    
    //if ([_nearbyVenuesTableView respondsToSelector:@selector(setCellLayoutMarginsFollowReadableWidth:)])
    //    _nearbyVenuesTableView.cellLayoutMarginsFollowReadableWidth = false;
    
    if (TGLocationPickerPlacesProvider == TGLocationPlacesServiceFoursquare)
    {
        _attributionView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, _nearbyVenuesTableView.frame.size.width, 55)];
        _attributionView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _attributionView.contentMode = UIViewContentModeCenter;
        _attributionView.hidden = true;
        _attributionView.image = TGComponentsImageNamed(@"FoursquareAttribution.png");
        _nearbyVenuesTableView.tableFooterView = _attributionView;
    }
    
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _activityIndicator.userInteractionEnabled = false;
    [_nearbyVenuesTableView addSubview:_activityIndicator];
    [_activityIndicator startAnimating];
    
    _messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 20)];
    _messageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _messageLabel.backgroundColor = [UIColor clearColor];
    _messageLabel.font = TGSystemFontOfSize(16);
    _messageLabel.hidden = true;
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.textColor = UIColorRGB(0x8e8e93);
    _messageLabel.userInteractionEnabled = false;
    [_nearbyVenuesTableView addSubview:_messageLabel];
    
    CGFloat mapHeight = [TGLocationPickerController mapHeight];
    
    CGFloat stripeThickness = TGScreenPixel;
    _tableViewTopInset = mapHeight + stripeThickness;
    
    _mapClipView = [[UIView alloc] initWithFrame:CGRectMake(0, -TGLocationPickerMapClipHeight, self.view.frame.size.width, TGLocationPickerMapClipHeight)];
    _mapClipView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _mapClipView.clipsToBounds = true;
    [_nearbyVenuesTableView addSubview:_mapClipView];
    
    _mapViewWrapper = [[UIView alloc] initWithFrame:CGRectMake(0, TGLocationPickerMapClipHeight - mapHeight - stripeThickness, self.view.frame.size.width, mapHeight + stripeThickness)];
    _mapViewWrapper.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_mapClipView addSubview:_mapViewWrapper];
    
    __weak TGLocationPickerController *weakSelf = self;
    
    _mapView = [[TGLocationMapView alloc] initWithFrame:CGRectMake(0, -TGLocationPickerMapInset, self.view.frame.size.width, mapHeight + 2 * TGLocationPickerMapInset)];
    _mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _mapView.delegate = self;
    _mapView.showsUserLocation = true;
    _mapView.tapEnabled = true;
    _mapView.longPressAsTapEnabled = true;
    _mapView.singleTap = ^
    {
        __strong TGLocationPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf switchToFullscreenMapAnimated:true];
    };
    [_mapViewWrapper addSubview:_mapView];
    
    CGFloat pinWrapperWidth = self.view.frame.size.width;
    _pickerPinWrapper = [[TGLocationPinWrapperView alloc] initWithFrame:CGRectMake((_mapViewWrapper.frame.size.width - pinWrapperWidth) / 2, (_mapViewWrapper.frame.size.height - pinWrapperWidth) / 2, pinWrapperWidth, pinWrapperWidth)];
    _pickerPinWrapper.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    _pickerPinWrapper.hidden = true;
    [_mapViewWrapper addSubview:_pickerPinWrapper];
    
    _pickerPinView = [[TGLocationPinView alloc] init];
    _pickerPinView.frame = CGRectMake((_pickerPinWrapper.frame.size.width - _pickerPinView.frame.size.width) / 2, (_pickerPinWrapper.frame.size.height - _pickerPinView.frame.size.height) / 2 - 15, _pickerPinView.frame.size.width, _pickerPinView.frame.size.height);
    [_pickerPinWrapper addSubview:_pickerPinView];
    
    _pickerAnnotationView = [[TGPickPinAnnotationView alloc] initWithAnnotation:nil reuseIdentifier:nil];
    _pickerAnnotationView.calloutPressed = ^
    {
        __strong TGLocationPickerController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf _sendLocation];
    };
    _pickerAnnotationView.hidden = true;
    
    UIView *stripeView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, _mapViewWrapper.frame.size.height - stripeThickness, _mapViewWrapper.frame.size.width, stripeThickness)];
    stripeView.backgroundColor = TGSeparatorColor();
    stripeView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [_mapViewWrapper addSubview:stripeView];
    
    _searchBarOverlay = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.navigationController.view.frame.size.width, 64)];
    _searchBarOverlay.alpha = 0.0f;
    _searchBarOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _searchBarOverlay.backgroundColor = UIColorRGB(0xf7f7f7);
    _searchBarOverlay.userInteractionEnabled = false;
    [self.navigationController.view addSubview:_searchBarOverlay];
    
    _searchBarWrapper = [[UIView alloc] initWithFrame:CGRectMake(0, -64, self.navigationController.view.frame.size.width, 64)];
    _searchBarWrapper.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _searchBarWrapper.backgroundColor = [UIColor whiteColor];
    _searchBarWrapper.hidden = true;
    [self.navigationController.view addSubview:_searchBarWrapper];
    
    _searchBar = [[TGSearchBar alloc] initWithFrame:CGRectMake(0.0f, 20, _searchBarWrapper.frame.size.width, [TGSearchBar searchBarBaseHeight]) style:TGSearchBarStyleHeader];
    _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _searchBar.customBackgroundView.image = nil;
    _searchBar.customActiveBackgroundView.image = nil;
    _searchBar.delegate = self;
    [_searchBar setShowsCancelButton:true animated:false];
    [_searchBar setAlwaysExtended:true];
    _searchBar.placeholder = TGLocalized(@"Map.Search");
    [_searchBar sizeToFit];
    _searchBar.delayActivity = false;
    [_searchBarWrapper addSubview:_searchBar];

    _searchMixin = [[TGSearchDisplayMixin alloc] init];
    _searchMixin.searchBar = _searchBar;
    _searchMixin.alwaysShowsCancelButton = true;
    _searchMixin.delegate = self;
    
    _toolbarWrapperView = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 44.0f, self.view.frame.size.width, 44.0f)];
    _toolbarWrapperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    _toolbarWrapperView.userInteractionEnabled = false;
    [self.view addSubview:_toolbarWrapperView];
    
    _toolbarView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, _toolbarWrapperView.frame.size.height, _toolbarWrapperView.frame.size.width, 44.0f)];
    _toolbarView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _toolbarView.backgroundColor = UIColorRGB(0xf7f7f7);
    [_toolbarWrapperView addSubview:_toolbarView];
    stripeView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, _toolbarView.frame.size.width, stripeThickness)];
    stripeView.backgroundColor = UIColorRGB(0xb2b2b2);
    stripeView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_toolbarView addSubview:stripeView];
    
    _userLocationButton = [[TGModernButton alloc] initWithFrame:CGRectMake(4, 2, 44, 44)];
    _userLocationButton.adjustsImageWhenHighlighted = false;
    _userLocationButton.contentMode = UIViewContentModeCenter;
    _userLocationButton.exclusiveTouch = true;
    _userLocationButton.enabled = false;
    [_userLocationButton setImage:TGComponentsImageNamed(@"TrackingLocation.png") forState:UIControlStateNormal];
    [_userLocationButton addTarget:self action:@selector(userLocationButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_toolbarView addSubview:_userLocationButton];
    
    _showPlacesButton = [[TGModernButton alloc] initWithFrame:CGRectZero];
    _showPlacesButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    _showPlacesButton.exclusiveTouch = true;
    _showPlacesButton.titleLabel.font = TGSystemFontOfSize(18);
    [_showPlacesButton setTitle:TGLocalized(@"Map.ShowPlaces") forState:UIControlStateNormal];
    [_showPlacesButton setTitleColor:TGAccentColor()];
    [_showPlacesButton addTarget:self action:@selector(showPlacesButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_showPlacesButton sizeToFit];
    CGFloat showPlacesWidth = MAX(110, _showPlacesButton.frame.size.width);
    _showPlacesButton.frame = CGRectMake((self.view.frame.size.width - showPlacesWidth) / 2, 0, showPlacesWidth, 44);
    [_toolbarView addSubview:_showPlacesButton];
    
    static UIImage *maskImage = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(55.0f, 43.0f), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        CGColorRef colors[3] = {
            CGColorRetain(UIColorRGBA(0xf7f7f7, 0.0f).CGColor),
            CGColorRetain(UIColorRGBA(0xf7f7f7, 1.0f).CGColor),
            CGColorRetain(UIColorRGBA(0xf7f7f7, 1.0f).CGColor)
        };
        
        CFArrayRef colorsArray = CFArrayCreate(kCFAllocatorDefault, (const void **)&colors, 3, NULL);
        CGFloat locations[3] = {0.0f, 0.45f, 1.0f};
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colorsArray, (CGFloat const *)&locations);
        
        CFRelease(colorsArray);
        CFRelease(colors[0]);
        CFRelease(colors[1]);
        CFRelease(colors[2]);
        
        CGColorSpaceRelease(colorSpace);
        
        CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(55.0f, 0.0f), 0);
        
        CFRelease(gradient);
        
        maskImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    
    _mapModeControl = [[TGLocationMapModeControl alloc] init];
    _mapModeControl.alpha = 0.0f;
    _mapModeControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _mapModeControl.userInteractionEnabled = false;
    _mapModeControl.frame = CGRectMake(_toolbarView.frame.size.width, (_toolbarView.frame.size.height - 29) / 2 + 0.5f, _toolbarView.frame.size.width - 55 - 7.5f, 29);
    _mapModeControl.selectedSegmentIndex = MAX(0, MIN(2, (NSInteger)_mapView.mapType));
    [_mapModeControl addTarget:self action:@selector(mapModeControlValueChanged:) forControlEvents:UIControlEventValueChanged];
    [_toolbarView addSubview:_mapModeControl];
    
    _mapModeControlMask = [[UIImageView alloc] initWithFrame:CGRectMake(_toolbarView.frame.size.width - 55, 1, 55, 43)];
    _mapModeControlMask.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    _mapModeControlMask.image = maskImage;
    [_toolbarView addSubview:_mapModeControlMask];
    
    _mapModeButton = [[TGModernButton alloc] initWithFrame:CGRectMake(_toolbarView.frame.size.width - 50, TGRetinaPixel, 44, 44)];
    _mapModeButton.adjustsImageWhenHighlighted = false;
    _mapModeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    _mapModeButton.contentMode = UIViewContentModeCenter;
    _mapModeButton.exclusiveTouch = true;
    [_mapModeButton setImage:TGComponentsImageNamed(@"LocationInfo.png") forState:UIControlStateNormal];
    [_mapModeButton setImage:TGComponentsImageNamed(@"LocationInfo_Active.png") forState:UIControlStateSelected];
    [_mapModeButton setImage:TGComponentsImageNamed(@"LocationInfo_Active.png") forState:UIControlStateSelected | UIControlStateHighlighted];
    [_mapModeButton addTarget:self action:@selector(mapModeButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_toolbarView addSubview:_mapModeButton];
    
    _searchReferenceView = [[UIView alloc] initWithFrame:self.view.bounds];
    _searchReferenceView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _searchReferenceView.userInteractionEnabled = false;
    [self.view addSubview:_searchReferenceView];
    
    self.scrollViewsForAutomaticInsetsAdjustment = @[ _nearbyVenuesTableView ];
    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_intent == TGLocationPickerControllerCustomLocationIntent)
    {
        [self switchToFullscreenMapAnimated:true];
        _showPlacesButton.hidden = true;
    }
    
    __weak TGLocationPickerController *weakSelf = self;
    [_locationUpdateDisposable setDisposable:[[self userLocationSignal] startWithNext:^(TGLocationPair *locationPair)
    {
        __strong TGLocationPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf setCurrentUserLocation:locationPair.location storeLocation:locationPair.isCurrent updateMapView:!locationPair.onlyLocationUpdate];
        
        if (strongSelf->_intent != TGLocationPickerControllerCustomLocationIntent && locationPair.isCurrent && !locationPair.onlyLocationUpdate)
            [strongSelf fetchNearbyVenuesWithLocation:locationPair.location];
    }]];
    
    [self _layoutTableProgressViews];
}

- (void)reloadNearbyVenuesIfNeeded
{
    if (!_nearbyVenuesLoadFailed)
        return;
    
    _nearbyVenuesLoadFailed = false;
    [self fetchNearbyVenuesWithLocation:_currentUserLocation];
}

- (void)fetchNearbyVenuesWithLocation:(CLLocation *)location
{
    _venuesFetchLocation = location;
    
    _messageLabel.hidden = true;
    
    __weak TGLocationPickerController *weakSelf = self;
    [_nearbyVenuesDisposable setDisposable:[[[TGLocationSignals searchNearbyPlacesWithQuery:nil coordinate:location.coordinate service:TGLocationPickerPlacesProvider] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *venues)
    {
        __strong TGLocationPickerController *strongSelf = weakSelf;
        if (strongSelf != nil && venues != nil)
            [strongSelf setNearbyVenues:venues];
    } error:^(__unused id error)
    {
        __strong TGLocationPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_nearbyVenuesLoadFailed = true;
        
        [strongSelf setIsLoading:false];
        
        [strongSelf _layoutTableProgressViews];
        strongSelf->_messageLabel.hidden = false;
        strongSelf->_messageLabel.text = TGLocalized(@"Map.LoadError");
    } completed:nil]];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _searchBarWrapper.hidden = false;
    
    if (_intent != TGLocationPickerControllerCustomLocationIntent)
    {
        [[[LegacyComponentsGlobals provider] accessChecker] checkLocationAuthorizationStatusForIntent:TGLocationAccessIntentSend alertDismissComlpetion:^
        {
            if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedWhenInUse)
            {
                [self switchToFullscreenMapAnimated:true];
                _showPlacesButton.hidden = true;
            }
        }];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    _searchBarWrapper.hidden = true;
}

#pragma mark - Actions

- (void)cancelButtonPressed
{
    [self.presentingViewController dismissViewControllerAnimated:true completion:nil];
}

- (void)_sendLocation
{
    CLLocationCoordinate2D coordinate = _currentUserLocation.coordinate;
    if (_mapInFullScreenMode)
        coordinate = [self mapCenterCoordinateForPickerPin];
    
    if (self.locationPicked != nil)
        self.locationPicked(coordinate, nil);
}

- (void)searchButtonPressed
{
    [self setSearchHidden:false animated:true];
    [_searchBar becomeFirstResponder];
}

- (void)showPlacesButtonPressed
{
    [self switchToVenuesTableView];
}

- (void)userLocationButtonPressed
{
    if (!_pinMovedFromUserLocation || _currentUserLocation == nil)
        return;
    
    _pinMovedFromUserLocation = false;
    
    [self hidePickerAnnotationAnimated:true];
    [_pickerPinView setPinRaised:true animated:true completion:nil];
    
    MKCoordinateSpan span = _fullScreenMapSpan != nil ? _fullScreenMapSpan.MKCoordinateSpanValue : TGLocationDefaultSpan;
    [self _setMapCenterCoordinate:_mapView.userLocation.location.coordinate span:span offset:TGLocationPickerPinOffset animated:true];
}

- (void)mapModeButtonPressed
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismissMapModeControl) object:nil];
    [self setMapModeControlHidden:_mapModeButton.selected withUserAction:true animated:true];
}

- (void)mapModeControlValueChanged:(TGLocationMapModeControl *)sender
{
    NSInteger mapMode = MAX(0, MIN(2, sender.selectedSegmentIndex));
    [_mapView setMapType:(MKMapType)mapMode];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismissMapModeControl) object:nil];
    if (_mapModeButton.isSelected)
        [self performSelector:@selector(dismissMapModeControl) withObject:nil afterDelay:1.0f];
}

- (void)dismissMapModeControl
{
    [self setMapModeControlHidden:true withUserAction:false animated:true];
}

#pragma mark - Map View Delegate

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)__unused animated
{
    UIView *view = mapView.subviews.firstObject;
    
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers)
    {
        if(recognizer.state == UIGestureRecognizerStateBegan || recognizer.state == UIGestureRecognizerStateEnded)
        {
            if (_mapInFullScreenMode)
            {
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pinPinView) object:nil];
                [self hidePickerAnnotationAnimated:true];
            }
            else
            {
                [self switchToFullscreenMapAnimated:true];
            }
            
            [_pickerPinView setPinRaised:true animated:true completion:nil];
            
            _pinMovedFromUserLocation = true;
            _updatePinAnnotation = false;
            
            break;
        }
    }
}

- (void)mapView:(MKMapView *)__unused mapView regionDidChangeAnimated:(BOOL)__unused animated
{
    if (_pickerPinView.isPinRaised)
    {
        NSTimeInterval delay = _pinMovedFromUserLocation ? 0.38 : 0.05;
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(pinPinView) object:nil];
        [self performSelector:@selector(pinPinView) withObject:nil afterDelay:delay];
    }
    else if (_updatePinAnnotation)
    {
        [self pinPinView];
    }
}

- (void)pinPinView
{
    __weak TGLocationPickerController *weakSelf = self;
    [_pickerPinView setPinRaised:false animated:true completion:^
    {
        __strong TGLocationPickerController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf showPickerAnnotationAnimated:true];
    }];
}

- (void)mapView:(MKMapView *)__unused mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    userLocation.title = @"";
    
    _locationServicesDisabled = false;
    
    if (_userLocationObserver != nil)
        _userLocationObserver(userLocation.location);
    else if (userLocation.location != nil)
        _startLocation = userLocation.location;
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if (annotation == mapView.userLocation)
        return nil;
    
    MKPinAnnotationView *view = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:TGPickPinAnnotationKind];
    if (view == nil)
        view = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:TGPickPinAnnotationKind];
    else
        view.annotation = annotation;
    
    if (_mapInFullScreenMode)
        view.hidden = true;
    
    view.canShowCallout = false;
    view.animatesDrop = false;
    view.draggable = false;
    
    return view;
}

- (void)updateAnnotationWithLocation:(CLLocation *)location
{
    if (_mapView.userLocation == nil || _mapView.userLocation.location == nil)
        return;
    
    if (_annotation == nil)
    {
        _annotation = [[TGLocationAnnotation alloc] initWithCoordinate:_currentUserLocation.coordinate title:nil];
        [_mapView addAnnotation:_annotation];
        [_mapView selectAnnotation:_annotation animated:false];
    }
    
    _annotation.coordinate = location.coordinate;
}

- (void)updatePickerAnnotation
{
    __weak TGLocationPickerController *weakSelf = self;
    
    CLLocationCoordinate2D coordinate = [self mapCenterCoordinateForPickerPin];
    _customAnnotation = [[TGLocationAnnotation alloc] initWithCoordinate:coordinate title:TGLocalized(@"Map.SendThisLocation")];
    [self _updatePickerAnnotationViewAnimated:false];
    
    [_reverseGeocodeDisposable setDisposable:[[[TGLocationSignals reverseGeocodeCoordinate:coordinate] deliverOn:[SQueue mainQueue]] startWithNext:^(TGLocationReverseGeocodeResult *result)
    {
        __strong TGLocationPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        NSString *address = @"";
        if (result != nil)
            address = result.displayAddress;
        
        strongSelf->_customAnnotation.subtitle = address;
        [strongSelf updateCurrentLocationCell];
    } error:^(__unused id error)
    {
        __strong TGLocationPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_customAnnotation.subtitle = TGLocalized(@"Map.LocatingError");
        [strongSelf updateCurrentLocationCell];
    } completed:^
    {
        
    }]];
}

- (void)showPickerAnnotationAnimated:(bool)__unused animated
{
    [self updatePickerAnnotation];
    _customAnnotation.subtitle = nil;
    
    [self updateCurrentLocationCell];
}

- (void)hidePickerAnnotationAnimated:(bool)__unused animated
{
    _customAnnotation.subtitle = nil;
    [self updateCurrentLocationCell];
}

- (void)_updatePickerAnnotationViewAnimated:(bool)animated
{
    TGPickPinAnnotationView *annotationView = _pickerAnnotationView;
    annotationView.annotation = _customAnnotation;
    [annotationView sizeToFit];
    [annotationView setNeedsLayout];
    
    if (animated && annotationView.appeared)
    {
        [UIView animateWithDuration:0.2f animations:^
        {
            [annotationView layoutIfNeeded];
        }];
    }
}

- (CLLocationCoordinate2D)mapCenterCoordinateForPickerPin
{
    return [_mapView convertPoint:CGPointMake((_mapView.frame.size.width + TGLocationPickerPinOffset.x) / 2, (_mapView.frame.size.height + TGLocationPickerPinOffset.y) / 2) toCoordinateFromView:_mapView];
}

- (void)_setMapCenterCoordinate:(CLLocationCoordinate2D)coordinate offset:(CGPoint)offset animated:(bool)animated
{
    [self _setMapCenterCoordinate:coordinate span:TGLocationDefaultSpan offset:offset animated:animated];
}

- (void)_setMapCenterCoordinate:(CLLocationCoordinate2D)coordinate span:(MKCoordinateSpan)span offset:(CGPoint)offset animated:(bool)animated
{
    @try
    {
        MKCoordinateRegion region = MKCoordinateRegionMake(coordinate, span);
        if (!CGPointEqualToPoint(offset, CGPointZero))
        {
            MKMapRect mapRect = [TGLocationUtils MKMapRectForCoordinateRegion:region];
            [_mapView setVisibleMapRect:mapRect edgePadding:UIEdgeInsetsMake(offset.y, offset.x, 0, 0) animated:animated];
        }
        else
        {
            [_mapView setRegion:region animated:animated];
        }
    }
    @catch (NSException *exception)
    {
        TGLegacyLog(@"ERROR: failed to set location picker map region with exception: %@", exception);
    }
}

#pragma mark - Signals

- (SSignal *)userLocationSignal
{
    __weak TGLocationPickerController *weakSelf = self;
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        SMetaDisposable *disposable = [[SMetaDisposable alloc] init];
        
        [disposable setDisposable:[[[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            __strong TGLocationPickerController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return nil;
            
            if (strongSelf->_startLocation != nil)
            {
                [subscriber putNext:[TGLocationPair pairWithLocation:strongSelf->_startLocation isCurrent:true onlyLocationUpdate:false]];
                strongSelf->_startLocation = nil;
            }
            else
            {
                CLLocation *knownUserLocation = [TGLocationSignals lastKnownUserLocation];
                [subscriber putNext:[TGLocationPair pairWithLocation:knownUserLocation isCurrent:false onlyLocationUpdate:false]];
            }
            
            strongSelf->_userLocationObserver = ^(CLLocation *location)
            {
                [subscriber putNext:[TGLocationPair pairWithLocation:location isCurrent:true onlyLocationUpdate:false]];
            };
            
            return nil;
        }] map:^TGLocationPair *(TGLocationPair *locationPair)
        {
            if (!locationPair.isCurrent)
                return locationPair;
            
            __strong TGLocationPickerController *strongSelf = weakSelf;
            CLLocation *location = locationPair.location;
            
            if (strongSelf != nil && strongSelf->_venuesFetchLocation != nil)
            {
                CLLocation *currentLocation = strongSelf->_venuesFetchLocation;
                if ([location distanceFromLocation:currentLocation] < 250)
                {
                    if ((location.horizontalAccuracy < currentLocation.horizontalAccuracy || fabs(location.horizontalAccuracy - currentLocation.horizontalAccuracy) < 50))
                    {
                        locationPair.onlyLocationUpdate = true;
                    }
                }
            }
            
            return locationPair;
        }] startWithNext:^(TGLocationPair *locationPair)
        {
            [subscriber putNext:locationPair];
        }]];
        
        return disposable;
    }];
}

- (void)setCurrentUserLocation:(CLLocation *)userLocation storeLocation:(bool)storeLocation updateMapView:(bool)updateMapView
{
    if (userLocation == nil)
        return;
    
    bool hadNoLocation = (_currentUserLocation == nil);
    
    if (_mapInFullScreenMode && hadNoLocation)
        _pinMovedFromUserLocation = true;
    
    if (storeLocation)
    {
        [TGLocationSignals storeLastKnownUserLocation:userLocation];
        _currentUserLocation = userLocation;
        _searchButtonItem.enabled = true;
        _userLocationButton.enabled = true;
        
        if (updateMapView)
            [self updateAnnotationWithLocation:_currentUserLocation];
    }
    
    [self updateCurrentLocationCell];
    
    if (updateMapView)
    {
        if (!_mapInFullScreenMode)
        {
            [self _setMapCenterCoordinate:userLocation.coordinate offset:TGLocationPickerPinOffset animated:true];
        }
        else if (_intent == TGLocationPickerControllerCustomLocationIntent && hadNoLocation)
        {
            _pinMovedFromUserLocation = false;
            _updatePinAnnotation = true;
            [self _setMapCenterCoordinate:userLocation.coordinate offset:TGLocationPickerPinOffset animated:true];
        }
    }
}

#pragma mark - Appearance

- (void)switchToFullscreenMapAnimated:(bool)__unused animated
{
    _mapInFullScreenMode = true;
    
    _searchButtonItem.enabled = true;
    
    MKAnnotationView *annotationView = [_mapView viewForAnnotation:_annotation];
    annotationView.hidden = true;
    _pickerPinWrapper.hidden = false;
    
    [self showPickerAnnotationAnimated:true];
    
    _mapView.tapEnabled = false;
    _mapView.longPressAsTapEnabled = false;
    
    [self setToolbarHidden:false animated:true];
    
    _nearbyVenuesTableView.clipsToBounds = false;
    _nearbyVenuesTableView.scrollEnabled = false;
    [_mapViewWrapper.superview bringSubviewToFront:_mapViewWrapper];

    void (^changeBlock)(void) = ^
    {
        CGFloat toolbarHeight = _toolbarView.frame.size.height;
        
        _nearbyVenuesTableView.contentOffset = CGPointMake(0, -_nearbyVenuesTableView.contentInset.top);
        _nearbyVenuesTableView.frame = CGRectMake(_nearbyVenuesTableView.frame.origin.x, self.view.frame.size.height - [TGLocationPickerController mapHeight] - TGLocationCurrentLocationCellHeight - self.controllerInset.top - toolbarHeight, _nearbyVenuesTableView.frame.size.width, _nearbyVenuesTableView.frame.size.height);
        
        _mapViewWrapper.frame = CGRectMake(0, TGLocationPickerMapClipHeight - self.view.frame.size.height + self.controllerInset.top + toolbarHeight + 20, _mapViewWrapper.frame.size.width, self.view.frame.size.height - TGLocationCurrentLocationCellHeight - self.controllerInset.top - 7);
        _mapView.center = CGPointMake(_mapView.center.x, _mapViewWrapper.frame.size.height / 2);
    };
    
    void (^completionBlock)(BOOL) = ^(BOOL finished)
    {
        if (finished)
        {
            _nearbyVenuesTableView.clipsToBounds = true;
            _mapView.manipulationEnabled = true;
            
            _mapViewWrapper.frame = [self.view convertRect:_mapViewWrapper.frame fromView:_mapViewWrapper.superview];
            [self.view insertSubview:_mapViewWrapper belowSubview:_toolbarWrapperView];
            _mapViewWrapper.clipsToBounds = true;
            
            if (_annotation != nil)
                _fullScreenMapSpan = [NSValue valueWithMKCoordinateSpan:_mapView.region.span];
        }
    };
    
    if (animated)
    {
        if (iosMajorVersion() >= 7)
        {
            [UIView animateWithDuration:0.5f delay:0.0f usingSpringWithDamping:0.75f initialSpringVelocity:0.5f options:UIViewAnimationOptionCurveLinear animations:changeBlock completion:completionBlock];
        }
        else
        {
            [UIView animateWithDuration:0.4f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:changeBlock completion:completionBlock];
        }
    }
    else
    {
        changeBlock();
        completionBlock(true);
    }
}

- (void)switchToVenuesTableView
{
    _mapInFullScreenMode = false;
    
    _searchButtonItem.enabled = (_currentUserLocation != nil);
    
    MKAnnotationView *annotationView = [_mapView viewForAnnotation:_annotation];
    annotationView.hidden = false;
    _pickerPinWrapper.hidden = true;
    
    [self updateCurrentLocationCell];
    
    _mapView.mapType = MKMapTypeStandard;
    
    [self controllerInsetUpdated:self.controllerInset];
    
    [self setToolbarHidden:true animated:true];
    if (_annotation != nil)
        [self _setMapCenterCoordinate:_annotation.coordinate offset:TGLocationPickerPinOffset animated:true];
    
    _nearbyVenuesTableView.clipsToBounds = false;
    
    _mapViewWrapper.frame = CGRectMake(0, TGLocationPickerMapClipHeight - self.view.frame.size.height + self.controllerInset.top + _toolbarView.frame.size.height + 20, _mapViewWrapper.frame.size.width, self.view.frame.size.height - TGLocationCurrentLocationCellHeight - self.controllerInset.top - 7);
    [_mapClipView addSubview:_mapViewWrapper];
    _mapViewWrapper.clipsToBounds = false;
    
    void (^animationBlock)(void) = ^
    {
        _nearbyVenuesTableView.contentOffset = CGPointMake(0, -_nearbyVenuesTableView.contentInset.top);
        _nearbyVenuesTableView.frame = CGRectMake(_nearbyVenuesTableView.frame.origin.x, 0, _nearbyVenuesTableView.frame.size.width, _nearbyVenuesTableView.frame.size.height);
        
        CGFloat stripeThickness = TGScreenPixel;
        _mapViewWrapper.frame = CGRectMake(0, TGLocationPickerMapClipHeight - [TGLocationPickerController mapHeight] - stripeThickness, self.view.frame.size.width, [TGLocationPickerController mapHeight] + stripeThickness);
        _mapView.frame = CGRectMake(_mapView.frame.origin.x, (_mapViewWrapper.frame.size.height - _mapView.frame.size.height) / 2, _mapView.frame.size.width, _mapView.frame.size.height);
    };
    
    void (^completionBlock)(BOOL) = ^(BOOL finished)
    {
        _mapModeControl.selectedSegmentIndex = 0;
        if (finished)
        {
            _mapView.tapEnabled = true;
            _mapView.longPressAsTapEnabled = true;
            _nearbyVenuesTableView.clipsToBounds = true;
            _nearbyVenuesTableView.scrollEnabled = true;
        }
    };
    
    if (iosMajorVersion() >= 7)
    {
        [UIView animateWithDuration:0.5f delay:0.0f usingSpringWithDamping:0.85f initialSpringVelocity:0.5f options:UIViewAnimationOptionCurveLinear animations:animationBlock completion:completionBlock];
    }
    else
    {
        [UIView animateWithDuration:0.4f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:animationBlock completion:completionBlock];
    }
    
    [self reloadNearbyVenuesIfNeeded];
}

- (void)setToolbarHidden:(bool)hidden animated:(bool)animated
{
    _toolbarWrapperView.userInteractionEnabled = !hidden;

    void (^changeBlock)(void) = ^
    {
        _toolbarView.frame = CGRectMake(_toolbarView.frame.origin.x, hidden ? _toolbarWrapperView.frame.size.height : 0, _toolbarView.frame.size.width, _toolbarView.frame.size.height);
    };
    
    if (animated)
        [UIView animateWithDuration:0.3f delay:0.0f options:[TGViewController preferredAnimationCurve] << 16 animations:changeBlock completion:nil];
    else
        changeBlock();
}

- (void)setMapModeControlHidden:(bool)hidden withUserAction:(bool)withUserAction animated:(bool)animated
{
    _userLocationButton.userInteractionEnabled = hidden;
    _showPlacesButton.userInteractionEnabled = hidden;
    _mapModeControl.userInteractionEnabled = !hidden;
    _mapModeButton.userInteractionEnabled = true;
    
    if (!withUserAction && animated)
    {
        [UIView transitionWithView:_mapModeButton duration:0.25f options:UIViewAnimationOptionTransitionCrossDissolve animations:^
        {
            _mapModeButton.selected = !hidden;
        } completion:nil];
    }
    else
    {
        _mapModeButton.selected = !hidden;
    }
    
    if (animated)
    {
        [UIView animateWithDuration:0.3f delay:0.0f options:[TGViewController preferredAnimationCurve] << 16 animations:^
        {
            _mapModeControl.frame = CGRectMake(hidden ? _toolbarView.frame.size.width : 8, _mapModeControl.frame.origin.y, _mapModeControl.frame.size.width, _mapModeControl.frame.size.height);
        } completion:nil];
        
        [UIView animateWithDuration:0.25f animations:^
        {
            if (hidden)
            {
                _mapModeControl.alpha = 0.0f;
            }
            else
            {
                _userLocationButton.alpha = 0.0f;
                _showPlacesButton.alpha = 0.0f;
            }
        }];
        
        [UIView animateWithDuration:0.25f delay:0.05f options:kNilOptions animations:^
        {
            if (hidden)
            {
                _userLocationButton.alpha = 1.0f;
                _showPlacesButton.alpha = 1.0f;
            }
            else
            {
                _mapModeControl.alpha = 1.0f;
            }
        } completion:nil];
    }
    else
    {
        _userLocationButton.alpha = hidden ? 1.0f : 0.0f;
        _showPlacesButton.alpha = hidden ? 1.0f : 0.0f;
        _mapModeControl.alpha = hidden ? 0.0f : 1.0f;
    }
}

- (UIBarButtonItem *)controllerRightBarButtonItem
{
    if (iosMajorVersion() < 7)
    {
        TGModernBarButton *searchButton = [[TGModernBarButton alloc] initWithImage:TGComponentsImageNamed(@"NavigationSearchIcon.png")];
            searchButton.portraitAdjustment = CGPointMake(-7, -5);
        [searchButton addTarget:self action:@selector(searchButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        return [[UIBarButtonItem alloc] initWithCustomView:searchButton];
    }

    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchButtonPressed)];
}

#pragma mark - Search

- (void)setSearchHidden:(bool)hidden animated:(bool)animated
{
    void (^changeBlock)(void) = ^
    {
        CGRect frame = _searchBarWrapper.frame;
        if (hidden)
        {
            frame.origin.y = -64;
            _searchBarOverlay.alpha = 0.0f;
        }
        else
        {
            frame.origin.y = 0;
            if (self.navigationController.modalPresentationStyle == UIModalPresentationFormSheet)
                frame.origin.y -= 20;
            
            _searchBarOverlay.alpha = 1.0f;
        }
        _searchBarWrapper.frame = frame;
    };
    
    if (animated)
        [UIView animateWithDuration:0.2f animations:changeBlock];
    else
        changeBlock();
}

- (void)searchBar:(TGSearchBar *)__unused searchBar willChangeHeight:(CGFloat)__unused newHeight
{
    
}

- (void)searchMixin:(TGSearchDisplayMixin *)__unused searchMixin hasChangedSearchQuery:(NSString *)searchQuery withScope:(int)__unused scope
{
    if (searchQuery.length == 0)
    {
        [_searchDisposable setDisposable:nil];
        [_searchMixin reloadSearchResults];
        [_searchMixin setSearchResultsTableViewHidden:true];
        _searchBar.showActivity = false;
    }
    else
    {
        __weak TGLocationPickerController *weakSelf = self;
        void (^changeActivityIndicatorState)(bool) = ^(bool active)
        {
            __strong TGLocationPickerController *strongSelf = weakSelf;
            if (strongSelf != nil)
                strongSelf->_searchBar.showActivity = active;
        };
    
        SSignal *searchSignal = [[SSignal complete] delay:0.65f onQueue:[SQueue mainQueue]];
        searchSignal = [searchSignal onCompletion:^
        {
            changeActivityIndicatorState(true);
        }];
        
        CLLocationCoordinate2D coordinate = _mapInFullScreenMode ? _customAnnotation.coordinate : _currentUserLocation.coordinate;
        searchSignal = [[searchSignal then:[TGLocationSignals searchNearbyPlacesWithQuery:searchQuery coordinate:coordinate service:TGLocationPickerPlacesProvider]] deliverOn:[SQueue mainQueue]];
        
        if (_searchDisposable == nil)
            _searchDisposable = [[SMetaDisposable alloc] init];
        
        [_searchDisposable setDisposable:[[searchSignal onDispose:^
        {
            changeActivityIndicatorState(false);
        }] startWithNext:^(NSArray *results)
        {
            __strong TGLocationPickerController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf setSearchResults:results withSearchQuery:searchQuery];
        } error:^(__unused id error)
        {
            changeActivityIndicatorState(false);
        } completed:^
        {
            changeActivityIndicatorState(false);
        }]];
    }
}

- (void)searchMixinWillActivate:(bool)__unused animated
{
    if (_mapInFullScreenMode)
        return;
    
    _nearbyVenuesTableView.scrollEnabled = false;
    
    [UIView animateWithDuration:0.2f animations:^
    {
        _nearbyVenuesTableView.contentOffset = CGPointMake(0, -_nearbyVenuesTableView.contentInset.top);
        [self _layoutTableProgressViews];
    }];
}

- (void)searchMixinWillDeactivate:(bool)animated
{
    [_searchDisposable setDisposable:nil];
    
    [self setSearchHidden:true animated:animated];
    
    if (_mapInFullScreenMode)
        return;
    
    _nearbyVenuesTableView.scrollEnabled = true;

    [UIView animateWithDuration:0.2f animations:^
    {
        _nearbyVenuesTableView.contentOffset = CGPointMake(0, -_nearbyVenuesTableView.contentInset.top);
        [self _layoutTableProgressViews];
    }];
}

- (UITableView *)createTableViewForSearchMixin:(TGSearchDisplayMixin *)__unused searchMixin
{
    UITableView *tableView = [[UITableView alloc] init];
    tableView.delegate = self;
    tableView.dataSource = self;
    tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    tableView.tableFooterView = [[UIView alloc] init];
    
    return tableView;
}

- (UIView *)referenceViewForSearchResults
{
    return _searchReferenceView;
}

#pragma mark - Scroll View Delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (_searchMixin.isActive && scrollView == _searchMixin.searchResultsTableView)
    {
        [_searchBar resignFirstResponder];
    }
    else if (scrollView == _nearbyVenuesTableView)
    {
        [self _layoutTableProgressViews];
    
        CGFloat offset = scrollView.contentInset.top + scrollView.contentOffset.y;
        CGFloat mapOffset = MIN(offset, [TGLocationPickerController mapHeight]);
        _mapView.frame = CGRectMake(_mapView.frame.origin.x, -TGLocationPickerMapInset + mapOffset / 2, _mapView.frame.size.width, _mapView.frame.size.height);
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (_searchMixin.isActive && scrollView == _searchMixin.searchResultsTableView)
        [_searchBar resignFirstResponder];
}

#pragma mark - Data

- (void)updateCurrentLocationCell
{
    UITableViewCell *cell = [_nearbyVenuesTableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    if ([cell isKindOfClass:[TGLocationCurrentLocationCell class]])
    {
        TGLocationCurrentLocationCell *locationCell = (TGLocationCurrentLocationCell *)cell;
        
        if (_mapInFullScreenMode)
            [locationCell configureForCustomLocationWithAddress:_customAnnotation.subtitle];
        else
            [locationCell configureForCurrentLocationWithAccuracy:_currentUserLocation.horizontalAccuracy];
    }
    
    [cell.superview bringSubviewToFront:cell];
}

- (void)setNearbyVenues:(NSArray *)nearbyVenues
{
    bool shouldFadeIn = (_nearbyVenues.count == 0);
    
    _nearbyVenues = nearbyVenues;
    [_nearbyVenuesTableView reloadData];
 
    [self setIsLoading:false];
    
    _attributionView.hidden = (_nearbyVenues.count == 0);
    
    if (shouldFadeIn)
    {
        NSMutableArray *animatedCells = [[NSMutableArray alloc] init];
        
        for (UIView *cell in _nearbyVenuesTableView.visibleCells)
        {
            if ([cell isKindOfClass:[TGLocationVenueCell class]])
            {
                cell.alpha = 0.0f;
                [animatedCells addObject:cell];
            }
        }
        
        [UIView animateWithDuration:0.14f animations:^
        {
            for (UIView *cell in animatedCells)
                cell.alpha = 1.0f;
        }];
    }
}

- (void)setSearchResults:(NSArray *)results withSearchQuery:(NSString *)query
{
    _searchResults = results;
    _searchResultsQuery = query;
    
    [_searchMixin reloadSearchResults];
    [_searchMixin setSearchResultsTableViewHidden:query.length == 0];
}

#pragma mark - Table View Data Source & Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _nearbyVenuesTableView && indexPath.row == 0)
    {
        [self _sendLocation];
    }
    else
    {
        TGLocationVenue *venue = nil;
        if (tableView == _nearbyVenuesTableView)
        {
            venue = _nearbyVenues[indexPath.row - 2];
        }
        else if (tableView == _searchMixin.searchResultsTableView)
        {
            venue = _searchResults[indexPath.row];
            [_searchBar resignFirstResponder];
        }
        
        if (self.locationPicked != nil)
            self.locationPicked(venue.coordinate, [venue venueAttachment]);
    }
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _nearbyVenuesTableView)
    {
        if (indexPath.row == 0)
            return (_mapInFullScreenMode || _currentUserLocation != nil);
        if (indexPath.row == 1)
            return false;
    }
    
    return true;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _nearbyVenuesTableView && indexPath.row == 1)
        return nil;
    
    return indexPath;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    if (tableView == _nearbyVenuesTableView && indexPath.row == 0)
    {
        TGLocationCurrentLocationCell *locationCell = [tableView dequeueReusableCellWithIdentifier:TGLocationCurrentLocationCellKind];
        if (locationCell == nil)
            locationCell = [[TGLocationCurrentLocationCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGLocationCurrentLocationCellKind];
        
        if (_mapInFullScreenMode)
            [locationCell configureForCustomLocationWithAddress:_customAnnotation.subtitle];
        else
            [locationCell configureForCurrentLocationWithAccuracy:_currentUserLocation.horizontalAccuracy];
        
        cell = locationCell;
    }
    else if (tableView == _nearbyVenuesTableView && indexPath.row == 1)
    {
        TGLocationSectionHeaderCell *sectionCell = [tableView dequeueReusableCellWithIdentifier:TGLocationSectionHeaderKind];
        if (sectionCell == nil)
            sectionCell = [[TGLocationSectionHeaderCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGLocationSectionHeaderKind];
        
        [sectionCell configureWithTitle:TGLocalized(@"Map.ChooseAPlace")];
        
        cell = sectionCell;
    }
    else
    {
        TGLocationVenueCell *venueCell = [tableView dequeueReusableCellWithIdentifier:TGLocationVenueCellKind];
        if (venueCell == nil)
            venueCell = [[TGLocationVenueCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGLocationVenueCellKind];
        
        TGLocationVenue *venue = nil;
        if (tableView == _nearbyVenuesTableView)
            venue = _nearbyVenues[indexPath.row - 2];
        else if (tableView == _searchMixin.searchResultsTableView)
            venue = _searchResults[indexPath.row];
        
        [venueCell configureWithVenue:venue];
        
        cell = venueCell;
    }
    
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)__unused section
{
    if (tableView == _nearbyVenuesTableView)
        return _nearbyVenues.count + 2;
    else if (tableView == _searchMixin.searchResultsTableView)
        return _searchResults.count;
    
    return 0;
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _nearbyVenuesTableView)
    {
        if (indexPath.row == 0)
            return TGLocationCurrentLocationCellHeight;
        else if (indexPath.row == 1)
            return TGLocationSectionHeaderHeight;
    }
    
    return TGLocationVenueCellHeight;
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForFooterInSection:(NSInteger)__unused section
{
    return 0.001f;
}

- (UIView *)tableView:(UITableView *)__unused tableView viewForFooterInSection:(NSInteger)__unused section
{
    return [[UIView alloc] init];
}

#pragma mark - 

- (void)setIsLoading:(bool)isLoading
{
    if (isLoading)
    {
        if (_nearbyVenues.count == 0)
            [_activityIndicator startAnimating];
    }
    else
    {
        [_activityIndicator stopAnimating];
    }
}

#pragma mark - Layout

- (BOOL)shouldAutorotate
{
    return false;
}

- (void)_autoAdjustInsetsForScrollView:(UIScrollView *)scrollView previousInset:(UIEdgeInsets)previousInset
{
    if (_mapInFullScreenMode)
        return;
    
    CGPoint contentOffset = scrollView.contentOffset;
    
    UIEdgeInsets finalInset = self.controllerInset;
    finalInset.top += _tableViewTopInset;
    
    scrollView.contentInset = finalInset;
    scrollView.scrollIndicatorInsets = self.controllerScrollInset;
    
    if (!UIEdgeInsetsEqualToEdgeInsets(previousInset, UIEdgeInsetsZero))
    {
        CGFloat maxOffset = scrollView.contentSize.height - (scrollView.frame.size.height - finalInset.bottom);
        
        if (![self shouldAdjustScrollViewInsetsForInversedLayout])
            contentOffset.y += previousInset.top - finalInset.top;
        
        contentOffset.y = MAX(-finalInset.top, MIN(contentOffset.y, maxOffset));
        [scrollView setContentOffset:contentOffset animated:false];
    }
    else if (contentOffset.y < finalInset.top)
    {
        contentOffset.y = -finalInset.top;
        [scrollView setContentOffset:contentOffset animated:false];
    }
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    if (_searchMixin != nil)
    {
        UIEdgeInsets inset = self.controllerInset;
        inset.top -= 44;
        [_searchMixin controllerInsetUpdated:inset];
    }
    
    [super controllerInsetUpdated:previousInset];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    if (_searchMixin != nil)
        [_searchMixin controllerLayoutUpdated:[TGViewController screenSizeForInterfaceOrientation:toInterfaceOrientation]];
}

- (void)_layoutTableProgressViews
{
    _activityIndicator.center = CGPointMake(_nearbyVenuesTableView.frame.size.width / 2, (_nearbyVenuesTableView.frame.size.height - [TGLocationPickerController mapHeight] + 20) / 2 + (_nearbyVenuesTableView.contentInset.top + _nearbyVenuesTableView.contentOffset.y) / 2);

    _messageLabel.frame = CGRectMake(0, _activityIndicator.center.y - _messageLabel.frame.size.height, _messageLabel.frame.size.width, _messageLabel.frame.size.height);
}

+ (CGFloat)mapHeight
{
    static dispatch_once_t onceToken;
    static CGFloat mapHeight = 0;
    dispatch_once(&onceToken, ^
    {
        mapHeight = [TGViewController isWidescreen] ? TGLocationPickerMapWidescreenHeight : TGLocationPickerMapHeight;
    });
    return mapHeight;
}

@end
