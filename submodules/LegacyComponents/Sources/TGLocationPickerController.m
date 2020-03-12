#import "TGLocationPickerController.h"

#import "LegacyComponentsInternal.h"
#import "TGColor.h"
#import "TGImageUtils.h"
#import "TGFont.h"

#import <MapKit/MapKit.h>

#import "TGLocationUtils.h"

#import "TGLocationSignals.h"

#import "TGListsTableView.h"
#import "TGSearchBar.h"
#import "TGSearchDisplayMixin.h"
#import <LegacyComponents/TGModernButton.h>
#import <LegacyComponents/TGModernBarButton.h>
#import <LegacyComponents/UIControl+HitTestEdgeInsets.h>
#import "TGLocationViewController.h"

#import "TGLocationAnnotation.h"
#import "TGLocationReverseGeocodeResult.h"

#import "TGLocationMapView.h"

#import "TGLocationVenue.h"
#import "TGLocationAnnotation.h"

#import "TGLocationVenueCell.h"
#import "TGLocationCurrentLocationCell.h"
#import "TGLocationSectionHeaderCell.h"
#import "TGLocationOptionsView.h"
#import "TGLocationPinAnnotationView.h"

const CGPoint TGLocationPickerPinOffset = { 0.0f, 33.0f };

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
    
    bool _nearbyVenuesLoadFailed;
    NSArray *_nearbyVenues;
    NSArray *_searchResults;
    NSString *_searchResultsQuery;
    
    TGLocationPinAnnotationView *_ownLocationView;
    __weak MKAnnotationView *_userLocationView;
    
    CLLocation *_currentUserLocation;
    CLLocation *_startLocation;
    CLLocation *_venuesFetchLocation;
    SMetaDisposable *_locationUpdateDisposable;
    void (^_userLocationObserver)(CLLocation *location);
    
    SMetaDisposable *_nearbyVenuesDisposable;
    SMetaDisposable *_searchDisposable;
    SMetaDisposable *_reverseGeocodeDisposable;
    
    UIView *_pickerPinWrapper;
    TGLocationPinAnnotationView *_pickerPinView;
    
    NSValue *_fullScreenMapSpan;
    
    bool _mapInFullScreenMode;
    bool _pinMovedFromUserLocation;
    bool _updatePinAnnotation;
    NSString *_customAddress;
    
    UIView *_searchBarOverlay;
    UIBarButtonItem *_searchButtonItem;
    UIView *_searchReferenceView;
    UIView *_searchBarWrapper;
    TGSearchBar *_searchBar;
    TGSearchDisplayMixin *_searchMixin;
    
    UIView *_safeAreaCurtainView;
    CGRect _initialCurtainFrame;
    
    UIImageView *_attributionView;
    
    bool _placesListVisible;
    
    id<SDisposable> _liveLocationsDisposable;
    TGLiveLocation *_liveLocation;
}
@end

@implementation TGLocationPickerController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context intent:(TGLocationPickerControllerIntent)intent
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        _intent = intent;
    
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
    [_reverseGeocodeDisposable dispose];
    [_liveLocationsDisposable dispose];
    
    _searchBar.delegate = nil;
    _searchMixin.delegate = nil;
}

- (void)loadView
{
    _tableViewBottomInset = 400.0f;
    
    [super loadView];
    
    _attributionView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, _tableView.frame.size.width, 55)];
    _attributionView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _attributionView.contentMode = UIViewContentModeCenter;
    _attributionView.hidden = true;
    _attributionView.image = self.pallete != nil ? TGTintedImage(TGComponentsImageNamed(@"FoursquareAttribution.png"), self.pallete.secondaryTextColor) : TGComponentsImageNamed(@"FoursquareAttribution.png");
    _tableView.tableFooterView = _attributionView;
    
    _mapView.tapEnabled = true;
    _mapView.longPressAsTapEnabled = true;
    if (iosMajorVersion() >= 7)
        _mapView.rotateEnabled = false;
    
    __weak TGLocationPickerController *weakSelf = self;
    _mapView.singleTap = ^
    {
        __strong TGLocationPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf switchToFullscreen];
    };
    
    _searchBarOverlay = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.navigationController.view.frame.size.width, 44.0f)];
    _searchBarOverlay.alpha = 0.0f;
    _searchBarOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _searchBarOverlay.backgroundColor = self.pallete != nil ? self.pallete.sectionHeaderBackgroundColor : UIColorRGB(0xf7f7f7);
    _searchBarOverlay.userInteractionEnabled = false;
    [self.navigationController.view addSubview:_searchBarOverlay];
    
    CGFloat safeAreaInset = self.controllerSafeAreaInset.top > FLT_EPSILON ? self.controllerSafeAreaInset.top : 0.0f;
    _searchBarWrapper = [[UIView alloc] initWithFrame:CGRectMake(0, -44.0f, self.navigationController.view.frame.size.width, 44.0f)];
    _searchBarWrapper.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _searchBarWrapper.backgroundColor = self.pallete != nil ? self.pallete.backgroundColor : [UIColor whiteColor];
    _searchBarWrapper.hidden = true;
    [self.navigationController.view addSubview:_searchBarWrapper];
    
    _searchBar = [[TGSearchBar alloc] initWithFrame:CGRectMake(0.0f, 0.0f, _searchBarWrapper.frame.size.width, [TGSearchBar searchBarBaseHeight]) style:TGSearchBarStyleHeader];
    if (self.pallete != nil)
        [_searchBar setPallete:self.pallete.searchBarPallete];
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

    _searchReferenceView = [[UIView alloc] initWithFrame:self.view.bounds];
    _searchReferenceView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _searchReferenceView.userInteractionEnabled = false;
    [self.view addSubview:_searchReferenceView];
    
    _activityIndicator.alpha = 0.0f;
    [self setIsLoading:true];
    
    if (self.safeAreaInsetBottom > FLT_EPSILON)
    {
        _safeAreaCurtainView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, _tableView.frame.size.width, self.safeAreaInsetBottom)];
        _safeAreaCurtainView.backgroundColor = self.pallete != nil ? self.pallete.sectionHeaderBackgroundColor :  UIColorRGB(0xf7f7f7);
    }
    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
    
    TGLocationPickerAnnotation *annotation = [[TGLocationPickerAnnotation alloc] initWithCoordinate:kCLLocationCoordinate2DInvalid];
    annotation.peer = self.peer;
    
    _ownLocationView = [[TGLocationPinAnnotationView alloc] initWithAnnotation:annotation];
    _ownLocationView.pallete = self.pallete;
    _ownLocationView.frame = CGRectOffset(_ownLocationView.frame, 21.0f, 22.0f);
    
    CGFloat pinWrapperWidth = self.view.frame.size.width;
    _pickerPinWrapper = [[TGLocationPinWrapperView alloc] initWithFrame:CGRectMake((_mapViewWrapper.frame.size.width - pinWrapperWidth) / 2, (_mapViewWrapper.frame.size.height - pinWrapperWidth) / 2, pinWrapperWidth, pinWrapperWidth)];
    _pickerPinWrapper.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    _pickerPinWrapper.hidden = true;
    [_mapViewWrapper addSubview:_pickerPinWrapper];
    
    _pickerPinView = [[TGLocationPinAnnotationView alloc] initWithAnnotation:annotation];
    _pickerPinView.pallete = self.pallete;
    _pickerPinView.center = CGPointMake(_pickerPinWrapper.frame.size.width / 2.0f, _pickerPinWrapper.frame.size.width / 2.0f + 16.0f);
    [_pickerPinWrapper addSubview:_pickerPinView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_intent == TGLocationPickerControllerCustomLocationIntent)
        [self switchToFullscreen];
    
    __weak TGLocationPickerController *weakSelf = self;
    [_locationUpdateDisposable setDisposable:[[self pickerUserLocationSignal] startWithNext:^(TGLocationPair *locationPair)
    {
        __strong TGLocationPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf setCurrentUserLocation:locationPair.location storeLocation:locationPair.isCurrent updateMapView:!locationPair.onlyLocationUpdate];
        
        if (strongSelf->_placesListVisible && strongSelf->_intent != TGLocationPickerControllerCustomLocationIntent && locationPair.isCurrent && !locationPair.onlyLocationUpdate)
        {
            [strongSelf fetchNearbyVenuesWithLocation:locationPair.location];
        }
    }]];
    
    [self _layoutTableProgressViews];
}

- (void)setLiveLocationsSignal:(SSignal *)signal
{
    __weak TGLocationPickerController *weakSelf = self;
    _liveLocationsDisposable = [[signal deliverOn:[SQueue mainQueue]] startWithNext:^(TGLiveLocation *liveLocation)
    {
        __strong TGLocationPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
    
        strongSelf->_liveLocation = liveLocation;
        [strongSelf updateCurrentLocationCell];
    }];
}

- (void)fetchNearbyVenuesWithLocation:(CLLocation *)location
{
    _venuesFetchLocation = location;
    _messageLabel.hidden = true;
    
    [self setIsLoading:true];
    
    __weak TGLocationPickerController *weakSelf = self;
    [_nearbyVenuesDisposable setDisposable:[[self.nearbyPlacesSignal(@"", location) deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *venues)
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
                [self switchToFullscreen];
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
    _tableView.userInteractionEnabled = false;
    
    CLLocationCoordinate2D coordinate = _currentUserLocation.coordinate;
    if (_mapInFullScreenMode)
        coordinate = [self mapCenterCoordinateForPickerPin];
    
    if (self.locationPicked != nil)
        self.locationPicked(coordinate, nil, _customAddress);
}

- (void)searchButtonPressed
{
    [self setSearchHidden:false animated:true];
    [_searchBar becomeFirstResponder];
}

- (void)_presentVenuesList
{
    if (fabs(_tableView.contentOffset.y + _tableView.contentInset.top) < 1.0f)
    {
        [_tableView setContentOffset:CGPointMake(0.0f, -_tableView.contentInset.top + (self.view.frame.size.height - [self visibleContentHeight] - self.controllerInset.top * 2.0f) / 2.0f - 16.0f) animated:true];
    }
}

- (void)userLocationButtonPressed
{
    if (!_pinMovedFromUserLocation || _currentUserLocation == nil)
        return;
    
    [self switchToUserLocation];
    
    _mapInFullScreenMode = false;
    _pinMovedFromUserLocation = false;
    
    [self hidePickerAnnotationAnimated:true];
    [_pickerPinView setPinRaised:true avatar:_intent == TGLocationPickerControllerCustomLocationIntent animated:true completion:nil];
    
    MKCoordinateSpan span = _fullScreenMapSpan != nil ? _fullScreenMapSpan.MKCoordinateSpanValue : TGLocationDefaultSpan;
    [self setMapCenterCoordinate:_mapView.userLocation.location.coordinate span:span offset:TGLocationPickerPinOffset animated:true];
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
                [self switchToFullscreen];
            }
            
            [_pickerPinView setPinRaised:true avatar:_intent == TGLocationPickerControllerCustomLocationIntent animated:true completion:nil];
            
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
    
    for (id<MKAnnotation> annotation in [mapView annotations])
    {
        if (![annotation isKindOfClass:[MKUserLocation class]])
        {
            MKAnnotationView *view = [mapView viewForAnnotation:annotation];
            [view.superview bringSubviewToFront:view];
        }
    }
}

- (void)pinPinView
{
    __weak TGLocationPickerController *weakSelf = self;
    [_pickerPinView setPinRaised:false avatar:_intent == TGLocationPickerControllerCustomLocationIntent animated:true completion:^
    {
        __strong TGLocationPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf->_mapInFullScreenMode)
        {
            [strongSelf showPickerAnnotationAnimated:true];
        }
        else
        {
            strongSelf->_ownLocationView.hidden = false;
            strongSelf->_pickerPinWrapper.hidden = true;
        }
    }];
    
    if (!_mapInFullScreenMode)
        [_pickerPinView setCustomPin:false animated:true];
}

- (void)updateLocationAvailability
{
    [super updateLocationAvailability];
    
    if (_locationServicesDisabled)
        [self switchToFullscreen];
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
    
    TGLocationPinAnnotationView *view = (TGLocationPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:TGLocationPinAnnotationKind];
    if (view == nil)
    {
        view = [[TGLocationPinAnnotationView alloc] initWithAnnotation:annotation];
        view.pallete = self.pallete;
    }
    else
    {
        view.annotation = annotation;
    }
    return view;
}

- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray<MKAnnotationView *> *)views
{
    for (MKAnnotationView *view in views)
    {
        if ([view.annotation isKindOfClass:[MKUserLocation class]])
        {
            _userLocationView = view;
            if (_ownLocationView != nil)
                [_userLocationView addSubview:_ownLocationView];
        }
    }
}

- (void)updatePickerAnnotation
{
    __weak TGLocationPickerController *weakSelf = self;
    
    CLLocationCoordinate2D coordinate = [self mapCenterCoordinateForPickerPin];
    [_reverseGeocodeDisposable setDisposable:[[[TGLocationSignals reverseGeocodeCoordinate:coordinate] deliverOn:[SQueue mainQueue]] startWithNext:^(TGLocationReverseGeocodeResult *result)
    {
        __strong TGLocationPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        NSString *address = @"";
        if (result != nil)
            address = result.fullAddress;
        
        strongSelf->_customAddress = address;
        [strongSelf updateCurrentLocationCell];
    } error:^(__unused id error)
    {
        __strong TGLocationPickerController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_customAddress = @"";
        [strongSelf updateCurrentLocationCell];
    } completed:nil]];
}

- (void)showPickerAnnotationAnimated:(bool)__unused animated
{
    [self updatePickerAnnotation];
    [self updateCurrentLocationCell];
}

- (void)hidePickerAnnotationAnimated:(bool)__unused animated
{
    [self updateCurrentLocationCell];
}

- (CLLocationCoordinate2D)mapCenterCoordinateForPickerPin
{
    return [_mapView convertPoint:CGPointMake((_mapView.frame.size.width + TGLocationPickerPinOffset.x) / 2, (_mapView.frame.size.height + TGLocationPickerPinOffset.y) / 2) toCoordinateFromView:_mapView];
}

#pragma mark - Signals

- (SSignal *)pickerUserLocationSignal
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
        [_optionsView setLocationAvailable:true animated:true];
    }
    
    [self updateCurrentLocationCell];
    
    if (updateMapView)
    {
        if (!_mapInFullScreenMode)
        {
            [self setMapCenterCoordinate:userLocation.coordinate offset:TGLocationPickerPinOffset animated:true];
        }
        else if (_intent == TGLocationPickerControllerCustomLocationIntent && hadNoLocation)
        {
            _pinMovedFromUserLocation = false;
            _updatePinAnnotation = true;
            [self setMapCenterCoordinate:userLocation.coordinate offset:TGLocationPickerPinOffset animated:true];
        }
    }
}

#pragma mark - Appearance

- (void)switchToFullscreen
{
    if (_mapInFullScreenMode)
        return;
    
    _mapInFullScreenMode = true;
    _pinMovedFromUserLocation = true;
    
    _searchButtonItem.enabled = true;
    
    _ownLocationView.hidden = true;
    _pickerPinWrapper.hidden = false;
    //if (_intent != TGLocationPickerControllerCustomLocationIntent) {
        [_pickerPinView setCustomPin:true animated:true];
    //}
    
    _mapView.tapEnabled = false;
    _mapView.longPressAsTapEnabled = false;
    
    _tableView.clipsToBounds = false;
    _tableView.scrollEnabled = false;
    [_mapViewWrapper.superview bringSubviewToFront:_mapViewWrapper];
    
    [_safeAreaCurtainView.superview bringSubviewToFront:_safeAreaCurtainView];
    [UIView animateWithDuration:0.25 animations:^
    {
        _safeAreaCurtainView.alpha = 1.0f;
    }];

    void (^changeBlock)(void) = ^
    {
        _tableView.contentOffset = CGPointMake(0, -_tableView.contentInset.top);
        _tableView.frame = CGRectMake(_tableView.frame.origin.x, self.view.frame.size.height - [self mapHeight] - TGLocationCurrentLocationCellHeight - self.controllerInset.top - self.safeAreaInsetBottom, _tableView.frame.size.width, _tableView.frame.size.height);
        
        _mapViewWrapper.frame = CGRectMake(0, TGLocationMapClipHeight - self.view.frame.size.height + self.controllerInset.top + 20, _mapViewWrapper.frame.size.width, self.view.frame.size.height - self.controllerInset.top - 10.0f);
        _mapView.center = CGPointMake(_mapView.center.x, _mapViewWrapper.frame.size.height / 2);
        _edgeView.frame = CGRectMake(0.0f, _mapViewWrapper.frame.size.height - _edgeView.frame.size.height, _edgeView.frame.size.width, _edgeView.frame.size.height);
        
        if (_safeAreaCurtainView != nil)
        {
            UITableViewCell *firstCell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
            _safeAreaCurtainView.frame = CGRectMake(0.0f, CGRectGetMaxY(firstCell.frame), _safeAreaCurtainView.frame.size.width,_safeAreaCurtainView.frame.size.height);
        }
    };
    
    void (^completionBlock)(BOOL) = ^(BOOL finished)
    {
        if (finished)
        {
            _mapView.manipulationEnabled = true;
            
            _mapViewWrapper.clipsToBounds = true;
            _fullScreenMapSpan = [NSValue valueWithMKCoordinateSpan:_mapView.region.span];
        }
    };
    
    if (iosMajorVersion() >= 7)
    {
        [UIView animateWithDuration:0.5f delay:0.0f usingSpringWithDamping:0.75f initialSpringVelocity:0.5f options:UIViewAnimationOptionCurveLinear animations:changeBlock completion:completionBlock];
    }
    else
    {
        [UIView animateWithDuration:0.4f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:changeBlock completion:completionBlock];
    }
    
    [self updateCurrentLocationCell];
}

- (void)switchToUserLocation
{
    if (!_mapInFullScreenMode)
        return;
    
    _mapInFullScreenMode = false;
    _mapViewWrapper.clipsToBounds = false;
    _searchButtonItem.enabled = !_locationServicesDisabled;
    
    void (^changeBlock)(void) = ^
    {
        _tableView.contentOffset = CGPointMake(0, -_tableView.contentInset.top);
        _tableView.frame = self.view.bounds;
        
        _mapViewWrapper.frame = CGRectMake(0, TGLocationMapClipHeight - _tableViewTopInset, self.view.frame.size.width, _tableViewTopInset + 10.0f);
        _mapView.frame = CGRectMake(0, -TGLocationMapInset, self.view.frame.size.width, _tableViewTopInset + 2 * TGLocationMapInset + 10.0f);
        _edgeView.frame = CGRectMake(0.0f, _tableViewTopInset - 10.0f, _mapViewWrapper.frame.size.width, _edgeView.frame.size.height);
        
        _safeAreaCurtainView.frame = CGRectMake(0.0f, _initialCurtainFrame.origin.y, _safeAreaCurtainView.frame.size.width,_safeAreaCurtainView.frame.size.height);
    };
    
    [_safeAreaCurtainView.superview bringSubviewToFront:_safeAreaCurtainView];
    [UIView animateWithDuration:0.25 animations:^
    {
        _safeAreaCurtainView.alpha = 1.0f;
    }];
    
    void (^completionBlock)(BOOL) = ^(BOOL finished)
    {
        if (finished)
        {
            _tableView.clipsToBounds = true;
            _tableView.scrollEnabled = true;
            
            _mapView.tapEnabled = true;
            _mapView.longPressAsTapEnabled = true;
        }
    };
    
    if (iosMajorVersion() >= 7)
    {
        [UIView animateWithDuration:0.5f delay:0.0f usingSpringWithDamping:0.75f initialSpringVelocity:0.5f options:UIViewAnimationOptionCurveLinear animations:changeBlock completion:completionBlock];
    }
    else
    {
        [UIView animateWithDuration:0.4f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:changeBlock completion:completionBlock];
    }
}

- (UIBarButtonItem *)controllerRightBarButtonItem
{
    if (_intent == TGLocationPickerControllerCustomLocationIntent) {
        return nil;
    }
    if (iosMajorVersion() < 7)
    {
        TGModernBarButton *searchButton = [[TGModernBarButton alloc] initWithImage:TGComponentsImageNamed(@"NavigationSearchIcon.png")];
            searchButton.portraitAdjustment = CGPointMake(-7, -5);
        [searchButton addTarget:self action:@selector(searchButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        return [[UIBarButtonItem alloc] initWithCustomView:searchButton];
    }

    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchButtonPressed)];
}

- (CGRect)_liveLocationMenuSourceRect
{
    TGLocationCurrentLocationCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
    if ([cell isKindOfClass:[TGLocationCurrentLocationCell class]])
        return [cell convertRect:cell.bounds toView:self.view];
    
    return CGRectZero;
}

#pragma mark - Search

- (void)setSearchHidden:(bool)hidden animated:(bool)animated
{
    void (^changeBlock)(void) = ^
    {
        CGRect frame = _searchBarWrapper.frame;
        if (hidden)
        {
            frame.origin.y = -frame.size.height;
            _searchBarOverlay.alpha = 0.0f;
        }
        else
        {
            frame.origin.y = 0;            
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
        
        CLLocationCoordinate2D coordinate = _currentUserLocation.coordinate;
        searchSignal = [searchSignal then:[self.nearbyPlacesSignal(searchQuery, _currentUserLocation) deliverOn:[SQueue mainQueue]]];
        
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
    
    _tableView.scrollEnabled = false;
    
    [UIView animateWithDuration:0.2f animations:^
    {
        _tableView.contentOffset = CGPointMake(0, -_tableView.contentInset.top);
        [self _layoutTableProgressViews];
    }];
}

- (void)searchMixinWillDeactivate:(bool)animated
{
    [_searchDisposable setDisposable:nil];
    
    [self setSearchHidden:true animated:animated];
    
    if (_mapInFullScreenMode)
        return;
    
    _tableView.scrollEnabled = true;

    [UIView animateWithDuration:0.2f animations:^
    {
        _tableView.contentOffset = CGPointMake(0, -_tableView.contentInset.top);
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
    tableView.backgroundColor = self.pallete != nil ? self.pallete.backgroundColor : [UIColor whiteColor];
    
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
    else
    {
        [super scrollViewDidScroll:scrollView];
        [self _layoutTableProgressViews];
        
        TGLocationSectionHeaderCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:_allowLiveLocationSharing ? 2 : 1  inSection:0]];
        if (cell == nil || ![cell isKindOfClass:[TGLocationSectionHeaderCell class]])
            return;
        
        if (scrollView.contentOffset.y > -scrollView.contentInset.top)
        {
            if (!_placesListVisible)
            {
                _placesListVisible = true;
                if (_currentUserLocation != nil)
                    [self fetchNearbyVenuesWithLocation:_currentUserLocation];
            }
            if (_intent != TGLocationPickerControllerCustomLocationIntent) {
                [cell configureWithTitle:TGLocalized(@"Map.ChooseAPlace")];
            }
            
            if (scrollView.contentOffset.y > -scrollView.contentInset.top + TGLocationSectionHeaderHeight)
            {
                if (_activityIndicator.alpha < FLT_EPSILON)
                {
                    [UIView animateWithDuration:0.25 animations:^
                    {
                        _activityIndicator.alpha = 1.0f;
                    }];
                }
            }
            else
            {
                [UIView animateWithDuration:0.0 animations:^
                {
                    _activityIndicator.alpha = 0.0f;
                }];
            }
            
            if (_safeAreaCurtainView != nil)
            {
                [UIView animateWithDuration:0.25 animations:^
                 {
                     _safeAreaCurtainView.alpha = 0.0f;
                 }];
            }
        }
        else
        {
            _activityIndicator.alpha = 0.0f;
            if (_intent != TGLocationPickerControllerCustomLocationIntent) {
                [cell configureWithTitle:TGLocalized(@"Map.PullUpForPlaces")];
            }
            
            if (_safeAreaCurtainView != nil)
            {
                [_safeAreaCurtainView.superview bringSubviewToFront:_safeAreaCurtainView];
                [UIView animateWithDuration:0.25 animations:^
                {
                    _safeAreaCurtainView.alpha = 1.0f;
                }];
            }
        }
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
    UITableViewCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    if ([cell isKindOfClass:[TGLocationCurrentLocationCell class]])
    {
        TGLocationCurrentLocationCell *locationCell = (TGLocationCurrentLocationCell *)cell;
        
        if (_intent == TGLocationPickerControllerCustomLocationIntent) {
            [locationCell configureForGroupLocationWithAddress:_customAddress];
        } else {
            if (_mapInFullScreenMode)
                [locationCell configureForCustomLocationWithAddress:_customAddress];
            else
                [locationCell configureForCurrentLocationWithAccuracy:_currentUserLocation.horizontalAccuracy];
        }
    }
    
    cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
    if ([cell isKindOfClass:[TGLocationCurrentLocationCell class]])
    {
        TGLocationCurrentLocationCell *locationCell = (TGLocationCurrentLocationCell *)cell;
        if (_liveLocation != nil)
            [locationCell configureForStopWithMessage:_liveLocation.message remaining:self.remainingTimeForMessage(_liveLocation.message)];
        else
            [locationCell configureForLiveLocationWithAccuracy:_currentUserLocation.horizontalAccuracy];
    }
}

- (void)setNearbyVenues:(NSArray *)nearbyVenues
{
    bool shouldFadeIn = (_nearbyVenues.count == 0);
    
    if (shouldFadeIn)
    {
        _tableViewBottomInset = 0.0f;
        [self updateInsets];
    }
    
    _nearbyVenues = nearbyVenues;
    [_tableView reloadData];
 
    [self setIsLoading:false];
    
    _attributionView.hidden = (_nearbyVenues.count == 0);
    
    if (shouldFadeIn)
    {
        NSMutableArray *animatedCells = [[NSMutableArray alloc] init];
        
        for (UIView *cell in _tableView.visibleCells)
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
    if (tableView == _tableView && indexPath.row < [self venueEntriesOffset])
    {
        if (indexPath.row == 0)
        {
            [self _sendLocation];
        }
        else if (_allowLiveLocationSharing && indexPath.row == 1)
        {
            if (_liveLocation != nil)
            {
                if (self.liveLocationStopped != nil)
                    self.liveLocationStopped();
                
                return;
            }
            else
            {
                [self _presentLiveLocationMenu:_currentUserLocation.coordinate dismissOnCompletion:false];
            }
            
            [tableView deselectRowAtIndexPath:tableView.indexPathForSelectedRow animated:true];
        }
        else if ((_allowLiveLocationSharing && indexPath.row == 2) || (!_allowLiveLocationSharing && indexPath.row == 1))
        {
            if (_intent != TGLocationPickerControllerCustomLocationIntent) {
                [self _presentVenuesList];
            }
        }
    }
    else
    {
        TGLocationVenue *venue = nil;
        if (tableView == _tableView)
        {
            venue = _nearbyVenues[indexPath.row - [self venueEntriesOffset]];
        }
        else if (tableView == _searchMixin.searchResultsTableView)
        {
            venue = _searchResults[indexPath.row];
            [_searchBar resignFirstResponder];
        }
        
        if (self.locationPicked != nil)
            self.locationPicked(venue.coordinate, [venue venueAttachment], _customAddress);
    }
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
    {
        if (indexPath.row == 0 || (_allowLiveLocationSharing && indexPath.row == 1))
            return (_mapInFullScreenMode || _currentUserLocation != nil);
    }
    
    return true;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([cell isKindOfClass:[TGLocationSectionHeaderCell class]])
    {
        if (_safeAreaCurtainView.superview == nil)
            [_tableView addSubview:_safeAreaCurtainView];
        _safeAreaCurtainView.frame = CGRectMake(0.0f, CGRectGetMaxY(cell.frame), _safeAreaCurtainView.frame.size.width, _safeAreaCurtainView.frame.size.height);
        _initialCurtainFrame = _safeAreaCurtainView.frame;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    
    if (tableView == _tableView && indexPath.row == 0)
    {
        TGLocationCurrentLocationCell *locationCell = [tableView dequeueReusableCellWithIdentifier:TGLocationCurrentLocationCellKind];
        if (locationCell == nil)
            locationCell = [[TGLocationCurrentLocationCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGLocationCurrentLocationCellKind];
        locationCell.pallete = self.pallete;
        locationCell.edgeView = _edgeHighlightView;
        
        if (_intent == TGLocationPickerControllerCustomLocationIntent) {
            [locationCell configureForGroupLocationWithAddress:_customAddress];
        } else {
            if (_mapInFullScreenMode)
                [locationCell configureForCustomLocationWithAddress:_customAddress];
            else
                [locationCell configureForCurrentLocationWithAccuracy:_currentUserLocation.horizontalAccuracy];
        }
        
        cell = locationCell;
    }
    else if (tableView == _tableView && _allowLiveLocationSharing && indexPath.row == 1)
    {
        TGLocationCurrentLocationCell *locationCell = [tableView dequeueReusableCellWithIdentifier:TGLocationCurrentLocationCellKind];
        if (locationCell == nil)
            locationCell = [[TGLocationCurrentLocationCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGLocationCurrentLocationCellKind];
        locationCell.pallete = self.pallete;
        locationCell.edgeView = nil;
        
        if (_liveLocation != nil)
            [locationCell configureForStopWithMessage:_liveLocation.message remaining:self.remainingTimeForMessage(_liveLocation.message)];
        else
            [locationCell configureForLiveLocationWithAccuracy:_currentUserLocation.horizontalAccuracy];
        
        cell = locationCell;
    }
    else if (tableView == _tableView && ((_allowLiveLocationSharing && indexPath.row == 2) || (!_allowLiveLocationSharing && indexPath.row == 1)))
    {
        TGLocationSectionHeaderCell *sectionCell = [tableView dequeueReusableCellWithIdentifier:TGLocationSectionHeaderKind];
        if (sectionCell == nil)
            sectionCell = [[TGLocationSectionHeaderCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGLocationSectionHeaderKind];
        sectionCell.pallete = self.pallete;
        
        if (_intent != TGLocationPickerControllerCustomLocationIntent) {
            if (tableView.contentOffset.y > -tableView.contentInset.top)
                [sectionCell configureWithTitle:TGLocalized(@"Map.ChooseAPlace")];
            else
                [sectionCell configureWithTitle:TGLocalized(@"Map.PullUpForPlaces")];
        }
        
        cell = sectionCell;
    }
    else
    {
        TGLocationVenueCell *venueCell = [tableView dequeueReusableCellWithIdentifier:TGLocationVenueCellKind];
        if (venueCell == nil)
            venueCell = [[TGLocationVenueCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGLocationVenueCellKind];
        venueCell.pallete = self.pallete;
        TGLocationVenue *venue = nil;
        if (tableView == _tableView)
            venue = _nearbyVenues[indexPath.row - [self venueEntriesOffset]];
        else if (tableView == _searchMixin.searchResultsTableView)
            venue = _searchResults[indexPath.row];
        
        [venueCell configureWithVenue:venue];
        
        cell = venueCell;
    }
    
    return cell;
}
             
- (NSInteger)venueEntriesOffset
{
    return _allowLiveLocationSharing ? 3 : 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)__unused section
{
    if (tableView == _tableView)
        return _nearbyVenues.count + 2 + (_allowLiveLocationSharing ? 1 : 0);
    else if (tableView == _searchMixin.searchResultsTableView)
        return _searchResults.count;
    
    return 0;
}

- (CGFloat)tableView:(UITableView *)__unused tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == _tableView)
    {
        if (indexPath.row == 0 || (_allowLiveLocationSharing && indexPath.row == 1))
            return TGLocationCurrentLocationCellHeight;
        else if ((_allowLiveLocationSharing && indexPath.row == 2) || (!_allowLiveLocationSharing && indexPath.row == 1))
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
    _activityIndicator.center = CGPointMake(_tableView.frame.size.width / 2, TGLocationCurrentLocationCellHeight * (_allowLiveLocationSharing ? 2 : 1) + TGLocationSectionHeaderHeight + (_tableView.contentInset.top + _tableView.contentOffset.y) / 2);

    _messageLabel.frame = CGRectMake(0, _activityIndicator.center.y - _messageLabel.frame.size.height / 2.0f, _messageLabel.frame.size.width, _messageLabel.frame.size.height);
}

#pragma mark -

- (CGFloat)visibleContentHeight
{
    return (_allowLiveLocationSharing ? 165.0f : 97.0f) + self.safeAreaInsetBottom;
}

@end
