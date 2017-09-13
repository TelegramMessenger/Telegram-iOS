#import "TGLocationViewController.h"

#import "LegacyComponentsInternal.h"

#import "TGNavigationBar.h"
#import "TGUser.h"
#import "TGConversation.h"
#import "TGMessage.h"
#import "TGImageUtils.h"
#import "TGFont.h"

#import <MapKit/MapKit.h>

#import "TGLocationUtils.h"

#import "TGLocationVenue.h"
#import "TGLocationAnnotation.h"

#import "TGLocationTitleView.h"
#import "TGLocationMapView.h"
#import "TGLocationTrackingButton.h"
#import "TGLocationMapModeControl.h"
#import "TGLocationPinAnnotationView.h"

#import "TGLocationOptionsView.h"

#import <LegacyComponents/TGMenuSheetController.h>

@interface TGLocationViewController () <MKMapViewDelegate>
{
    CLLocationManager *_locationManager;
    
    bool _locationServicesDisabled;
    
    CLLocation *_location;
    TGVenueAttachment *_venue;
    TGLocationMediaAttachment *_locationAttachment;
    TGLocationAnnotation *_annotation;
    
    CLLocation *_lastDirectionsStartLocation;
    MKDirections *_directions;

    TGLocationMapView *_mapView;
    UIBarButtonItem *_actionsBarItem;
    id _peer;
    
    TGLocationOptionsView *_optionsView;
    
    id<LegacyComponentsContext> _context;
}
@end

@implementation TGLocationViewController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context coordinate:(CLLocationCoordinate2D)coordinate venue:(TGVenueAttachment *)venue peer:(id)peer
{
    self = [self initWithContext:context];
    if (self != nil)
    {
        self.titleText = TGLocalized(@"Map.LocationTitle");
        
        _locationManager = [[CLLocationManager alloc] init];
        
        _context = context;
        _location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
        _venue = venue;
        _peer = peer;
        
        _annotation = [[TGLocationAnnotation alloc] initWithCoordinate:coordinate];
    }
    return self;
}

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context locationAttachment:(TGLocationMediaAttachment *)locationAttachment peer:(id)peer
{
    self = [self initWithContext:context coordinate:CLLocationCoordinate2DMake(locationAttachment.latitude, locationAttachment.longitude) venue:locationAttachment.venue peer:peer];
    if (self != nil)
    {
        _locationAttachment = locationAttachment;
    }
    return self;
}

- (void)dealloc
{
    _mapView.delegate = nil;
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    _mapView = [[TGLocationMapView alloc] initWithFrame:self.view.bounds];
    _mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _mapView.delegate = self;
    _mapView.showsUserLocation = true;
    _mapView.tapEnabled = false;
    [self.view addSubview:_mapView];
    
    __weak TGLocationViewController *weakSelf = self;
    _optionsView = [[TGLocationOptionsView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 45.0f, 90.0f)];
    _optionsView.mapModeChanged = ^(NSInteger mapMode) {
        __strong TGLocationViewController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf->_mapView setMapType:(MKMapType)mapMode];
            
    };
    _optionsView.trackModePressed = ^{
        __strong TGLocationViewController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf trackingModePressed];
    };
    [self.view addSubview:_optionsView];
    
    NSString *backButtonTitle = TGLocalized(@"Common.Back");
    if (TGIsPad() || _modalMode)
    {
        backButtonTitle = TGLocalized(@"Common.Done");
        [self setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:backButtonTitle style:UIBarButtonItemStyleDone target:self action:@selector(dismissButtonPressed)]];
    }
    
    CGFloat actionsButtonWidth = 0.0f;
    if (iosMajorVersion() >= 7)
    {
        _actionsBarItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionsButtonPressed)];
        [self setRightBarButtonItem:_actionsBarItem];
        actionsButtonWidth = 48.0f;
    }
    else
    {
        NSString *actionsButtonTitle = TGLocalized(@"Common.More");
        _actionsBarItem = [[UIBarButtonItem alloc] initWithTitle:actionsButtonTitle style:UIBarButtonItemStylePlain target:self action:@selector(actionsButtonPressed)];
        [self setRightBarButtonItem:_actionsBarItem];
        
        actionsButtonWidth = 16.0f;
        if ([actionsButtonTitle respondsToSelector:@selector(sizeWithAttributes:)])
            actionsButtonWidth += CGCeil([actionsButtonTitle sizeWithAttributes:@{ NSFontAttributeName:TGSystemFontOfSize(16.0f) }].width);
        else
            actionsButtonWidth += CGCeil([actionsButtonTitle sizeWithFont:TGSystemFontOfSize(16.0f)].width);
    }
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    _optionsView.frame = CGRectMake(self.view.bounds.size.width - 45.0f - 6.0f, self.navigationController.navigationBar.frame.size.height + 20.0f + 6.0f, 45.0f, 90.0f);
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [_mapView addAnnotation:_annotation];
    [_mapView selectAnnotation:_annotation animated:false];
    
    _mapView.region = MKCoordinateRegionMake(_location.coordinate, MKCoordinateSpanMake(0.008, 0.008));
    
    [TGLocationUtils requestWhenInUserLocationAuthorizationWithLocationManager:_locationManager];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.previewMode && !animated)
    {
        UIView *contentView = [[_mapView subviews] firstObject];
        UIView *annotationContainer = nil;
        for (NSUInteger i = 1; i < contentView.subviews.count; i++)
        {
            UIView *view = contentView.subviews[i];
            if ([NSStringFromClass(view.class) rangeOfString:@"AnnotationContainer"].location != NSNotFound)
            {
                annotationContainer = view;
                break;
            }
        }
        
        for (UIView *view in annotationContainer.subviews)
            view.frame = CGRectOffset(view.frame, 0, 48.5f);
    }
}

#pragma mark - 

- (void)setPreviewMode:(bool)previewMode
{
    _previewMode = previewMode;
    
    if (!previewMode)
        [self setRightBarButtonItem:_actionsBarItem];
}

#pragma mark - Actions

- (void)dismissButtonPressed
{
    [self.presentingViewController dismissViewControllerAnimated:true completion:nil];
}

- (void)actionsButtonPressed
{
    TGLocationMediaAttachment *locationAttachment = _locationAttachment;
    if (locationAttachment == nil)
        return;
    
    CGRect (^sourceRect)(void) = ^CGRect
    {
        return CGRectZero;
    };
    
   
    __weak TGLocationViewController *weakSelf = self;
    
    if (_presentOpenInMenu && _presentOpenInMenu(self, locationAttachment, false, ^(TGMenuSheetController *menuController)
    {
        __strong TGLocationViewController *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf->_presentShareMenu) {
            strongSelf->_presentShareMenu(menuController, strongSelf->_location.coordinate);
        }
    }))
    {
        
    }
    else
    {
        TGMenuSheetController *controller = [[TGMenuSheetController alloc] initWithContext:_context dark:false];
        controller.dismissesByOutsideTap = true;
        controller.hasSwipeGesture = true;
        controller.narrowInLandscape = true;
        controller.sourceRect = sourceRect;
        controller.barButtonItem = self.navigationItem.rightBarButtonItem;
        
        NSMutableArray *itemViews = [[NSMutableArray alloc] init];
        
        __weak TGMenuSheetController *weakController = controller;
        TGMenuSheetButtonItemView *openItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Map.OpenInMaps") type:TGMenuSheetButtonTypeDefault action:^
        {
            __strong TGLocationViewController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController == nil)
                return;
            
            [strongController dismissAnimated:true];
            [TGLocationUtils openMapsWithCoordinate:strongSelf->_location.coordinate withDirections:false locationName:strongSelf->_annotation.title];
        }];
        [itemViews addObject:openItem];
        
        TGMenuSheetButtonItemView *shareItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Conversation.ContextMenuShare") type:TGMenuSheetButtonTypeDefault action:^
        {
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController == nil)
                return;
            
            __strong TGLocationViewController *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_presentShareMenu) {
                strongSelf->_presentShareMenu(strongController, strongSelf->_location.coordinate);
            }
        }];
        [itemViews addObject:shareItem];
        
        TGMenuSheetButtonItemView *cancelItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.Cancel") type:TGMenuSheetButtonTypeCancel action:^
        {
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController == nil)
                return;
            
            [strongController dismissAnimated:true manual:true];
        }];
        [itemViews addObject:cancelItem];
        
        [controller setItemViews:itemViews];
        [controller presentInViewController:self sourceView:self.view animated:true];

    }
}

- (NSString *)_coordinateString
{
    NSInteger latSeconds = (NSInteger)(_location.coordinate.latitude * 3600);
    NSInteger latDegrees = latSeconds / 3600;
    latSeconds = labs(latSeconds % 3600);
    NSInteger latMinutes = latSeconds / 60;
    latSeconds %= 60;
    
    NSInteger longSeconds = (NSInteger)(_location.coordinate.longitude * 3600);
    NSInteger longDegrees = longSeconds / 3600;
    longSeconds = labs(longSeconds % 3600);
    NSInteger longMinutes = longSeconds / 60;
    longSeconds %= 60;
    
    NSString *result = [NSString stringWithFormat:@"%@%02ld° %02ld' %02ld\" %@%02ld° %02ld' %02ld\"", latDegrees >= 0 ? @"N" : @"S", labs(latDegrees), (long)latMinutes, (long)latSeconds, longDegrees >= 0 ? @"E" : @"W", labs(longDegrees), (long)longMinutes, (long)longSeconds];
    
    return result;
}

- (void)trackingModePressed
{
    if (![self _hasUserLocation])
    {
        if (![TGLocationUtils requestWhenInUserLocationAuthorizationWithLocationManager:_locationManager])
        {
            if (_locationServicesDisabled)
                [[[LegacyComponentsGlobals provider] accessChecker] checkLocationAuthorizationStatusForIntent:TGLocationAccessIntentTracking alertDismissComlpetion:nil];
        }
        
        [self updateLocationAvailability];
        return;
    }

    TGLocationTrackingMode newMode = TGLocationTrackingModeNone;
    switch ([TGLocationTrackingButton locationTrackingModeWithUserTrackingMode:_mapView.userTrackingMode])
    {
        case TGLocationTrackingModeFollow:
            newMode = TGLocationTrackingModeFollowWithHeading;
            break;
            
        case TGLocationTrackingModeFollowWithHeading:
            newMode = TGLocationTrackingModeNone;
            break;
            
        default:
            newMode = TGLocationTrackingModeFollow;
            break;
    }
    
    [_mapView setUserTrackingMode:[TGLocationTrackingButton userTrackingModeWithLocationTrackingMode:newMode] animated:true];
    [_optionsView setTrackingMode:newMode animated:true];
}

- (void)getDirectionsPressed
{
    TGLocationMediaAttachment *locationAttachment = _locationAttachment;
    if (locationAttachment == nil)
        return;
    
    if (_presentOpenInMenu && _presentOpenInMenu(self, locationAttachment, true, nil))
    {
    }
    else
    {
        [TGLocationUtils openMapsWithCoordinate:_location.coordinate withDirections:true locationName:_annotation.title];
    }
}

#pragma mark - Map View Delegate

- (void)mapView:(MKMapView *)__unused mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    userLocation.title = @"";
    
    _locationServicesDisabled = false;
    
    [self updateAnnotation];
    [self updateLocationAvailability];
}

- (void)mapView:(MKMapView *)__unused mapView didFailToLocateUserWithError:(NSError *)__unused error
{
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied || [CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted)
    {
        _locationServicesDisabled = true;
        [self updateLocationAvailability];
    }
}

- (bool)_hasUserLocation
{
    return (_mapView.userLocation != nil && _mapView.userLocation.location != nil);
}

- (void)updateLocationAvailability
{
    bool locationAvailable = [self _hasUserLocation] || _locationServicesDisabled;
    [_optionsView setLocationAvailable:locationAvailable animated:true];
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if (annotation == mapView.userLocation)
        return nil;
    
    TGLocationPinAnnotationView *view = (TGLocationPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:TGLocationPinAnnotationKind];
    if (view == nil)
        view = [[TGLocationPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:TGLocationPinAnnotationKind];
    else
        view.annotation = annotation;
    
    //view.selectable = false;
    view.canShowCallout = false;
    
    [view sizeToFit];
    [view setNeedsLayout];
    
    return view;
}

- (void)updateAnnotation
{
    if (_mapView.userLocation == nil || _mapView.userLocation.location == nil)
        return;
    
    CLLocationDistance distanceToLocation =  [_location distanceFromLocation:_mapView.userLocation.location];
    [self _updateAnnotationView];
    
    [self _updateDirectionsETA];
}

- (void)_updateAnnotationView
{
    TGLocationPinAnnotationView *annotationView = (TGLocationPinAnnotationView *)[_mapView viewForAnnotation:_annotation];
    annotationView.annotation = _annotation;
    [annotationView sizeToFit];
    [annotationView setNeedsLayout];
    
//    if (annotationView.appeared)
//    {
//        [UIView animateWithDuration:0.2f animations:^
//        {
//            [annotationView layoutIfNeeded];
//        }];
//    }
}

- (void)_updateDirectionsETA
{
    if (iosMajorVersion() < 7)
        return;
    
    if (_lastDirectionsStartLocation == nil || [_mapView.userLocation.location distanceFromLocation:_lastDirectionsStartLocation] > 100)
    {
        if (_directions != nil)
            [_directions cancel];
        
        MKPlacemark *destinationPlacemark = [[MKPlacemark alloc] initWithCoordinate:_location.coordinate addressDictionary:nil];
        MKMapItem *destinationMapItem = [[MKMapItem alloc] initWithPlacemark:destinationPlacemark];
        
        MKDirectionsRequest *request = [[MKDirectionsRequest alloc] init];
        request.source = [MKMapItem mapItemForCurrentLocation];
        request.destination = destinationMapItem;
        request.transportType = MKDirectionsTransportTypeAutomobile;
        request.requestsAlternateRoutes = false;
        
        _directions = [[MKDirections alloc] initWithRequest:request];
        [_directions calculateETAWithCompletionHandler:^(MKETAResponse *response, NSError *error)
        {
            if (error != nil)
                return;
            
            [self _updateAnnotationView];
        }];
        
        _lastDirectionsStartLocation = _mapView.userLocation.location;
    }
}

@end
