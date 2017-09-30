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
#import "TGLocationSignals.h"

#import "TGLocationVenue.h"
#import "TGLocationAnnotation.h"

#import "TGLocationTitleView.h"
#import "TGLocationMapView.h"
#import "TGLocationTrackingButton.h"
#import "TGLocationMapModeControl.h"
#import "TGLocationPinAnnotationView.h"

#import "TGLocationOptionsView.h"
#import "TGLocationInfoCell.h"
#import "TGLocationLiveCell.h"

#import <LegacyComponents/TGMenuSheetController.h>

@interface TGLiveLocationEntry ()

- (CLLocation *)location;

@end

@interface TGLocationViewController () <MKMapViewDelegate>
{
    id<LegacyComponentsContext> _context;
    
    CLLocationManager *_locationManager;
    
    bool _locationServicesDisabled;

    id _peer;
    TGMessage *_message;
    TGLocationMediaAttachment *_locationAttachment;
    
    TGLocationAnnotation *_annotation;
    
    UIBarButtonItem *_actionsBarItem;
    
    SVariable *_reloadReady;
    SMetaDisposable *_reloadDisposable;
    
    TGLiveLocationEntry *_currentLiveLocation;
    SMetaDisposable *_liveLocationsDisposable;
    NSArray *_initialLiveLocations;
    NSArray *_liveLocations;
    bool _hasOwnLiveLocation;
    bool _ownLocationExpired;
    
    bool _selectedCurrentLiveLocation;
    
    TGLocationPinAnnotationView *_ownLiveLocationView;
    __weak MKAnnotationView *_userLocationView;
}
@end

@implementation TGLocationViewController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context locationAttachment:(TGLocationMediaAttachment *)locationAttachment peer:(id)peer
{
    self = [self initWithContext:context];
    if (self != nil)
    {
        _locationAttachment = locationAttachment;
        
        _reloadDisposable = [[SMetaDisposable alloc] init];
        _reloadReady = [[SVariable alloc] init];
        [self setReloadReady:true];
        
        _locationManager = [[CLLocationManager alloc] init];
        _context = context;
        _peer = peer;
        
        if (locationAttachment.period == 0)
            _annotation = [[TGLocationAnnotation alloc] initWithLocation:locationAttachment];
        
        _liveLocationsDisposable = [[SMetaDisposable alloc] init];
        
        self.titleText = locationAttachment.period > 0 ? TGLocalized(@"Map.LiveLocationTitle") : TGLocalized(@"Map.LocationTitle");
    }
    return self;
}

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context liveLocation:(TGLiveLocationEntry *)liveLocation
{
    self = [self initWithContext:context];
    if (self != nil)
    {
        _message = liveLocation.message;
        _locationAttachment = liveLocation.message.locationAttachment;
        _currentLiveLocation = liveLocation;
        _initialLiveLocations = @[liveLocation];
        
        _reloadDisposable = [[SMetaDisposable alloc] init];
        _reloadReady = [[SVariable alloc] init];
        [self setReloadReady:true];
        
        _locationManager = [[CLLocationManager alloc] init];
        _context = context;
        _peer = liveLocation.peer;
        
        _liveLocationsDisposable = [[SMetaDisposable alloc] init];
        
        self.titleText = _locationAttachment.period > 0 ? TGLocalized(@"Map.LiveLocationTitle") : TGLocalized(@"Map.LocationTitle");
    }
    return self;
}

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context message:(TGMessage *)message peer:(id)peer
{
    self = [self initWithContext:context];
    if (self != nil)
    {
        _message = message;
        _locationAttachment = message.locationAttachment;
        
        _reloadDisposable = [[SMetaDisposable alloc] init];
        _reloadReady = [[SVariable alloc] init];
        [self setReloadReady:true];
        
        _locationManager = [[CLLocationManager alloc] init];
        _context = context;
        _peer = peer;
        
        if (_locationAttachment.period == 0)
            _annotation = [[TGLocationAnnotation alloc] initWithLocation:_locationAttachment];
        
        _liveLocationsDisposable = [[SMetaDisposable alloc] init];
        
        self.titleText = _locationAttachment.period > 0 ? TGLocalized(@"Map.LiveLocationTitle") : TGLocalized(@"Map.LocationTitle");
    }
    return self;
}

- (void)dealloc
{
    _mapView.delegate = nil;
    [_liveLocationsDisposable dispose];
    [_reloadDisposable dispose];
}

- (void)setLiveLocationsSignal:(SSignal *)signal
{
    SSignal *combinedSignal = [SSignal combineSignals:@[ [[self userLocationSignal] map:^id(id location) {
        if (location != nil)
            return location;
        else
            return [NSNull null];
    }], signal ]];
    
    __weak TGLocationViewController *weakSelf = self;
    [_liveLocationsDisposable setDisposable:[combinedSignal startWithNext:^(NSArray *next)
    {
        __strong TGLocationViewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        CLLocation *currentLocation = [next.firstObject isKindOfClass:[CLLocation class]] ? next.firstObject : nil;
        NSArray *liveLocations = next.lastObject;
        
        NSMutableArray *filteredLiveLocations = [[NSMutableArray alloc] init];
        for (TGLiveLocationEntry *entry in liveLocations)
        {
            if (!entry.isExpired || entry.message.mid == strongSelf->_currentLiveLocation.message.mid)
                [filteredLiveLocations addObject:entry];
        }
        
        liveLocations = filteredLiveLocations;

        NSMutableArray *sortedLiveLocations = [liveLocations mutableCopy];
        if (currentLocation != nil)
        {
            [sortedLiveLocations sortUsingComparator:^NSComparisonResult(TGLiveLocationEntry *obj1, TGLiveLocationEntry *obj2)
            {
                if (obj1.isOwn)
                    return NSOrderedAscending;
                else if (obj2.isOwn)
                    return NSOrderedDescending;
                
                CGFloat distance1 = [obj1.location distanceFromLocation:currentLocation];
                CGFloat distance2 = [obj2.location distanceFromLocation:currentLocation];
                
                if (distance1 > distance2)
                    return NSOrderedAscending;
                else if (distance1 < distance2)
                    return NSOrderedDescending;
                
                return NSOrderedSame;
            }];
        }
        else
        {
            [sortedLiveLocations sortUsingComparator:^NSComparisonResult(TGLiveLocationEntry *obj1, TGLiveLocationEntry *obj2)
            {
                if (obj1.isOwn)
                    return NSOrderedAscending;
                else if (obj2.isOwn)
                    return NSOrderedDescending;
                
                int32_t date1 = [obj1.message actualDate];
                int32_t date2 = [obj2.message actualDate];

                if (date1 > date2)
                    return NSOrderedAscending;
                else if (date1 < date2)
                    return NSOrderedDescending;

                return NSOrderedSame;
            }];
        }
        
        TGDispatchOnMainThread(^
        {
            if ([strongSelf isViewLoaded])
                [strongSelf setLiveLocations:sortedLiveLocations actual:true];
            else
                strongSelf->_initialLiveLocations = sortedLiveLocations;
        });
    }]];
}

- (void)setLiveLocations:(NSArray *)liveLocations actual:(bool)actual
{
    if (liveLocations.count == 0 && _currentLiveLocation != nil)
        liveLocations = @[ _currentLiveLocation ];
    
    TGLiveLocationEntry *ownLiveLocation = nil;
    for (TGLiveLocationEntry *entry in liveLocations)
    {
        if (entry.isOwn)
        {
            ownLiveLocation = entry;
            break;
        }
    }
    
    _hasOwnLiveLocation = ownLiveLocation != nil;
    _ownLocationExpired = ownLiveLocation.isExpired;
    
    if (_hasOwnLiveLocation && !_ownLocationExpired)
    {
        TGLocationAnnotation *annotation = [[TGLocationAnnotation alloc] initWithLocation:ownLiveLocation.message.locationAttachment];
        annotation.peer = ownLiveLocation.peer;
        annotation.isOwn = true;
        
        if (_ownLiveLocationView == nil)
        {
            _ownLiveLocationView = [[TGLocationPinAnnotationView alloc] initWithAnnotation:annotation];
            _ownLiveLocationView.frame = CGRectOffset(_ownLiveLocationView.frame, 21.0f, 22.0f);
            [_userLocationView addSubview:_ownLiveLocationView];
            
            if (_currentLiveLocation.isOwn)
                [_ownLiveLocationView setSelected:true animated:false];
        }
        else
        {
            _ownLiveLocationView.annotation = annotation;
        }
    }
    else
    {
        [_ownLiveLocationView removeFromSuperview];
        _ownLiveLocationView = nil;
    }
    
    CGFloat previousLocationsCount = _liveLocations.count;
    _liveLocations = liveLocations;
    [self reloadData];
    
    if (previousLocationsCount == 0 && liveLocations.count > 0)
    {
        bool animated = _initialLiveLocations.count == 0;
        CGFloat updatedHeight = [self possibleContentHeight] - [self visibleContentHeight];
        if (updatedHeight > FLT_EPSILON)
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                if (animated)
                    [self setReloadReady:false];
                
                [_tableView setContentOffset:CGPointMake(0.0f, -_tableView.contentInset.top + updatedHeight) animated:animated];
            });
        }
    }
    
    [self updateAnnotations];
    
    if ([self isLiveLocation] && [self hasMoreThanOneLocation])
    {
        [self setRightBarButtonItem:_actionsBarItem];
        
        if (actual && self.zoomToFitAllLocationsOnScreen)
        {
            _zoomToFitAllLocationsOnScreen = false;
            dispatch_async(dispatch_get_main_queue(), ^
            {
                [self showAllPressed];
            });
        }
    }
    else
    {
        [self setRightBarButtonItem:nil];
    }
}

- (void)reloadData
{
    [_reloadDisposable setDisposable:[[self reloadReadySignal] startWithNext:nil completed:^
    {
        [_tableView reloadData];
        _edgeView.highlighted = false;
    }]];
}

- (void)updateAnnotations
{
    NSMutableDictionary *entries = [[NSMutableDictionary alloc] init];
    for (TGLiveLocationEntry *entry in _liveLocations)
    {
        if (!entry.isOwn || entry.isExpired)
            entries[@(entry.message.mid)] = entry;
    }
    
    TGLocationAnnotation *currentAnnotation = nil;
    NSMutableSet *annotationsToRemove = [[NSMutableSet alloc] init];
    for (TGLocationAnnotation *annotation in _mapView.annotations)
    {
        if (![annotation isKindOfClass:[TGLocationAnnotation class]] || annotation == _annotation)
            continue;
        
        if (entries[@(annotation.messageId)] != nil)
        {
            annotation.coordinate = [(TGLiveLocationEntry *)entries[@(annotation.messageId)] location].coordinate;
            annotation.isExpired = [(TGLiveLocationEntry *)entries[@(annotation.messageId)] isExpired];
            [entries removeObjectForKey:@(annotation.messageId)];
            
            if (annotation.messageId == _currentLiveLocation.message.mid)
                currentAnnotation = annotation;
        }
        else
        {
            [annotationsToRemove addObject:annotation];
        }
    }
    
    [_mapView removeAnnotations:annotationsToRemove.allObjects];
    
    NSMutableArray *newAnnotations = [[NSMutableArray alloc] init];
    for (TGLiveLocationEntry *entry in entries.allValues)
    {
        TGLocationAnnotation *annotation = [[TGLocationAnnotation alloc] initWithLocation:entry.message.locationAttachment];
        annotation.peer = entry.peer;
        annotation.messageId = entry.message.mid;
        annotation.isExpired = entry.isExpired;
        
        [newAnnotations addObject:annotation];
        
        if (annotation.messageId == _currentLiveLocation.message.mid)
            currentAnnotation = annotation;
    }
    
    [_mapView addAnnotations:newAnnotations];
    
    if (!_selectedCurrentLiveLocation && currentAnnotation != nil)
    {
        _selectedCurrentLiveLocation = true;
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [_mapView setSelectedAnnotations:@[currentAnnotation]];
        });
    }
}

- (void)loadView
{
    [super loadView];
    
    _tableView.scrollsToTop = false;
    _mapView.tapEnabled = false;
    
    NSString *backButtonTitle = TGLocalized(@"Common.Back");
    if (TGIsPad() || _modalMode)
    {
        backButtonTitle = TGLocalized(@"Common.Done");
        [self setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:backButtonTitle style:UIBarButtonItemStyleDone target:self action:@selector(dismissButtonPressed)]];
    }
    
    if ([self isLiveLocation])
    {
        NSString *actionsButtonTitle = TGLocalized(@"Map.LiveLocationShowAll");
        _actionsBarItem = [[UIBarButtonItem alloc] initWithTitle:actionsButtonTitle style:UIBarButtonItemStylePlain target:self action:@selector(showAllPressed)];
    }
    else
    {
        if (iosMajorVersion() >= 7)
        {
            _actionsBarItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(actionsButtonPressed)];
            [self setRightBarButtonItem:_actionsBarItem];
        }
        else
        {
            NSString *actionsButtonTitle = TGLocalized(@"Common.More");
            _actionsBarItem = [[UIBarButtonItem alloc] initWithTitle:actionsButtonTitle style:UIBarButtonItemStylePlain target:self action:@selector(actionsButtonPressed)];
            [self setRightBarButtonItem:_actionsBarItem];
        }
    }
    
    if (_previewMode)
        _optionsView.hidden = true;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (_initialLiveLocations)
    {
        [self setLiveLocations:_initialLiveLocations actual:false];
        _initialLiveLocations = nil;
    }
    
    [_mapView addAnnotation:_annotation];
    [_mapView selectAnnotation:_annotation animated:false];
    
    _mapView.region = MKCoordinateRegionMake([self locationCoordinate], MKCoordinateSpanMake(0.008, 0.008));
    
    [TGLocationUtils requestWhenInUserLocationAuthorizationWithLocationManager:_locationManager];
    
    //[self updateAnnotations:false];
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
    {
        [self setRightBarButtonItem:_actionsBarItem];
        _optionsView.hidden = false;
    }
}

#pragma mark - Actions

- (void)fitAllLocations:(NSArray *)locations
{
    MKMapRect zoomRect = MKMapRectNull;
    for (CLLocation *location in locations)
    {
        MKMapPoint annotationPoint = MKMapPointForCoordinate(location.coordinate);
        MKMapRect pointRect = MKMapRectMake(annotationPoint.x, annotationPoint.y, 0.1, 0.1);
        zoomRect = MKMapRectUnion(zoomRect, pointRect);
    }
    UIEdgeInsets insets = UIEdgeInsetsMake(TGLocationMapInset + 110.0f, 80.0f, TGLocationMapInset + 110.0f, 80.0f);
    zoomRect = [_mapView mapRectThatFits:zoomRect edgePadding:insets];
    [_mapView setVisibleMapRect:zoomRect animated:true];
}

- (void)showAllPressed
{
    NSMutableArray *locations = [[NSMutableArray alloc] init];
    for (id <MKAnnotation> annotation in _mapView.annotations)
    {
        CLLocation *location = [[CLLocation alloc] initWithLatitude:annotation.coordinate.latitude longitude:annotation.coordinate.longitude];
        [locations addObject:location];
    }
    
    [self fitAllLocations:locations];
}

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
            strongSelf->_presentShareMenu(menuController, [strongSelf locationCoordinate]);
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
            [TGLocationUtils openMapsWithCoordinate:[strongSelf locationCoordinate] withDirections:false locationName:strongSelf->_annotation.title];
        }];
        [itemViews addObject:openItem];
        
        TGMenuSheetButtonItemView *shareItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Conversation.ContextMenuShare") type:TGMenuSheetButtonTypeDefault action:^
        {
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController == nil)
                return;
            
            __strong TGLocationViewController *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf->_presentShareMenu) {
                strongSelf->_presentShareMenu(strongController, [strongSelf locationCoordinate]);
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

- (void)userLocationButtonPressed
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
    
    if (newMode != TGLocationTrackingModeNone && _ownLiveLocationView != nil && !_ownLiveLocationView.isSelected)
        [_ownLiveLocationView setSelected:true animated:true];
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
        NSString *title = @"";
        if (locationAttachment.venue != nil)
            title = locationAttachment.venue.title;
        else if ([_peer isKindOfClass:[TGUser class]])
            title = ((TGUser *)_peer).displayName;
        else if ([_peer isKindOfClass:[TGConversation class]])
            title = ((TGConversation *)_peer).chatTitle;
        
        [TGLocationUtils openMapsWithCoordinate:[self locationCoordinate] withDirections:true locationName:title];
    }
}

- (UIButton *)directionsButton
{
    TGLocationInfoCell *infoCell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    if ([infoCell isKindOfClass:[TGLocationInfoCell class]])
        return infoCell.directionsButton;
    
    return nil;
}

#pragma mark - Map View Delegate

//- (void)mapView:(MKMapView *)__unused mapView didUpdateUserLocation:(MKUserLocation *)userLocation
//{
//    userLocation.title = @"";
//
//    _locationServicesDisabled = false;
//
//    [self updateAnnotation];
//    [self updateLocationAvailability];//
//}

//- (void)mapView:(MKMapView *)__unused mapView didFailToLocateUserWithError:(NSError *)__unused error
//{
//    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied || [CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted)
 //   {
   //     _locationServicesDisabled = true;
     //   [self updateLocationAvailability];
   // }/
//}

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
        view = [[TGLocationPinAnnotationView alloc] initWithAnnotation:annotation];
    else
        view.annotation = annotation;
    
    view.layer.zPosition = -1;
    
    return view;
}

- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray<MKAnnotationView *> *)views
{
    for (MKAnnotationView *view in views)
    {
        if ([view.annotation isKindOfClass:[MKUserLocation class]])
        {
            _userLocationView = view;
            
            if (_ownLiveLocationView != nil)
            {
                [_userLocationView addSubview:_ownLiveLocationView];
                
                if (_currentLiveLocation.isOwn && _mapView.selectedAnnotations.count == 0)
                    [_ownLiveLocationView setSelected:true animated:false];
            }
        }
    }
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
    if (_ownLiveLocationView.isSelected)
        [_ownLiveLocationView setSelected:false animated:true];
    
    [self setMapCenterCoordinate:view.annotation.coordinate offset:CGPointZero animated:true];
    
    [_optionsView setTrackingMode:TGLocationTrackingModeNone animated:true];
}

- (void)mapView:(MKMapView *)mapView didDeselectAnnotationView:(MKAnnotationView *)view
{
    if (_ownLiveLocationView != nil && !_ownLiveLocationView.isSelected && mapView.selectedAnnotations.count == 0)
    {
        [_ownLiveLocationView setSelected:true animated:true];
        [self setMapCenterCoordinate:_mapView.userLocation.coordinate offset:CGPointZero animated:true];
    }
}

- (CLLocationCoordinate2D)locationCoordinate
{
    return CLLocationCoordinate2DMake(_locationAttachment.latitude, _locationAttachment.longitude);
}

#pragma mark -

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger count = 0;
    if (![self isLiveLocation])
        count += 1;
    
    if (_liveLocations.count > 0)
    {
        count += _liveLocations.count;
        if (self.allowLiveLocationSharing && !_hasOwnLiveLocation)
            count += 1;
    }
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0 && ![self isLiveLocation])
    {
        TGLocationInfoCell *cell = [tableView dequeueReusableCellWithIdentifier:TGLocationInfoCellKind];
        if (cell == nil)
            cell = [[TGLocationInfoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGLocationInfoCellKind];
        
        __weak TGLocationViewController *weakSelf = self;
        [cell setLocation:_locationAttachment messageId:_message.mid userLocationSignal:[self userLocationSignal]];
        cell.locatePressed = ^
        {
            __strong TGLocationViewController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf setMapCenterCoordinate:[strongSelf locationCoordinate] offset:CGPointZero animated:true];
        };
        cell.directionsPressed = ^
        {
            __strong TGLocationViewController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf getDirectionsPressed];
        };
        return cell;
    }
    else
    {
        TGLocationLiveCell *cell = [tableView dequeueReusableCellWithIdentifier:TGLocationLiveCellKind];
        if (cell == nil)
            cell = [[TGLocationLiveCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGLocationLiveCellKind];
        
        cell.edgeView = indexPath.row == 0 ? _edgeHighlightView : nil;
        
        if (self.allowLiveLocationSharing && (indexPath.row == 0 || (![self isLiveLocation] && indexPath.row == 1)))
        {
            if (_hasOwnLiveLocation)
            {
                TGLiveLocationEntry *entry = _liveLocations.firstObject;
                if (entry.isExpired)
                    [cell configureForStart];
                else
                    [cell configureForStopWithMessage:entry.message remaining:self.remainingTimeForMessage(entry.message)];
            }
            else
            {
                [cell configureForStart];
            }
        }
        else
        {
            NSInteger index = indexPath.row;
            if (![self isLiveLocation])
                index -= 1;
            if (self.allowLiveLocationSharing && !_hasOwnLiveLocation)
                index -= 1;
            
            TGLiveLocationEntry *entry = _liveLocations[index];
            [cell configureWithPeer:entry.peer message:entry.message remaining:self.remainingTimeForMessage(entry.message) userLocationSignal:[self userLocationSignal]];
        }
        return cell;
    }
    
    return nil;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0 && ![self isLiveLocation])
        return false;
    
    return true;
}

- (void)tableView:(UITableView *)tableView didHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    [super tableView:tableView didHighlightRowAtIndexPath:indexPath];
    [self setReloadReady:false];
}

- (void)tableView:(UITableView *)tableView didUnhighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    [super tableView:tableView didUnhighlightRowAtIndexPath:indexPath];
    if (!_tableView.isTracking)
        [self setReloadReady:true];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    bool animated = true;
    if (indexPath.row == 0 && ![self isLiveLocation])
    {

    }
    else
    {
        TGLocationLiveCell *cell = [tableView dequeueReusableCellWithIdentifier:TGLocationLiveCellKind];
        if (cell == nil)
            cell = [[TGLocationLiveCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGLocationInfoCellKind];
        
        if (self.allowLiveLocationSharing && (indexPath.row == 0 || (![self isLiveLocation] && indexPath.row == 1)))
        {
            if (_hasOwnLiveLocation && !_ownLocationExpired)
            {
                if (self.liveLocationStopped != nil)
                    self.liveLocationStopped();
            }
            else
            {
                [[[self userLocationSignal] take:1] startWithNext:^(CLLocation *location)
                {
                    [self _presentLiveLocationMenu:location.coordinate dismissOnCompletion:true];
                }];
            }
        }
        else
        {
            NSInteger index = indexPath.row;
            if (![self isLiveLocation])
                index -= 1;
            if (self.allowLiveLocationSharing && !_hasOwnLiveLocation)
                index -= 1;
            
            TGLiveLocationEntry *entry = _liveLocations[index];
            for (TGLocationAnnotation *annotation in _mapView.annotations)
            {
                if (![annotation isKindOfClass:[TGLocationAnnotation class]])
                    continue;
                
                if (annotation.messageId == entry.message.mid)
                {
                    if ([_mapView.selectedAnnotations containsObject:annotation])
                        [self setMapCenterCoordinate:annotation.coordinate offset:CGPointZero animated:true];
                    else
                        [_mapView selectAnnotation:annotation animated:true];
                    break;
                }
            }
        }
    }
    [tableView deselectRowAtIndexPath:indexPath animated:animated];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0 && ![self isLiveLocation])
        return TGLocationInfoCellHeight;
    else
        return TGLocationLiveCellHeight;
    
    return 0;
}

- (CGFloat)visibleContentHeight
{
    if (![self isLiveLocation])
        return TGLocationInfoCellHeight;
    else
        return TGLocationLiveCellHeight;
}

- (CGFloat)possibleContentHeight
{
    if (![self isLiveLocation])
    {
        CGFloat height = TGLocationInfoCellHeight;
        if (_liveLocations.count > 0)
        {
            CGFloat count = 1.0f;
            if ((_liveLocations.count == 1 && !_hasOwnLiveLocation && self.allowLiveLocationSharing) || (_liveLocations.count == 2 && _hasOwnLiveLocation))
                count = 2.0f;
            else
                count = MIN(2.5f, _liveLocations.count);
            height += count * TGLocationLiveCellHeight;
        }
        return height;
    }
    else
    {
        CGFloat count = 1.0f;
        if ((_liveLocations.count == 1 && !_hasOwnLiveLocation && self.allowLiveLocationSharing) || (_liveLocations.count == 2 && _hasOwnLiveLocation))
            count = 2.0f;
        else
            count = MIN(2.5f, _liveLocations.count);
        CGFloat height = count * TGLocationLiveCellHeight;
        return height;
    }
}

- (bool)isLiveLocation
{
    return _locationAttachment.period > 0;
}

- (bool)hasMoreThanOneLocation
{
    return ((_hasOwnLiveLocation && _liveLocations.count > 1) || (!_hasOwnLiveLocation && _liveLocations.count > 0));
}

- (void)setReloadReady:(bool)ready
{
    [_reloadReady set:[SSignal single:@(ready)]];
}

- (SSignal *)reloadReadySignal
{
    return [[_reloadReady.signal filter:^bool(NSNumber *value) {
        return value.boolValue;
    }] take:1];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [super scrollViewDidScroll:scrollView];
    
    _mapView.compassInsets = UIEdgeInsetsMake(TGLocationMapInset + 108.0f + (scrollView.contentOffset.y + scrollView.contentInset.top) / 2.0f, 0.0f, 0.0f, 10.0f + TGScreenPixel);
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self setReloadReady:false];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (!scrollView.isTracking)
        [self setReloadReady:true];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)__unused scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate)
        [self setReloadReady:true];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)__unused scrollView
{
    if (!scrollView.isTracking)
        [self setReloadReady:true];
}

@end


@implementation TGLiveLocationEntry

- (instancetype)initWithMessage:(TGMessage *)message peer:(id)peer isOwn:(bool)isOwn isExpired:(bool)isExpired
{
    self = [super init];
    if (self != nil)
    {
        _message = message;
        _peer = peer;
        _isOwn = isOwn;
        _isExpired = isExpired;
    }
    return self;
}


- (instancetype)initWithMessage:(TGMessage *)message peer:(id)peer
{
    self = [super init];
    if (self != nil)
    {
        _message = message;
        _peer = peer;
        _isOwn = true;
        _isExpired = false;
    }
    return self;
}

- (int64_t)peerId
{
    return [_peer isKindOfClass:[TGUser class]] ? ((TGUser *)_peer).uid : ((TGConversation *)_peer).conversationId;
}

- (CLLocation *)location
{
    TGLocationMediaAttachment *location = _message.locationAttachment;
    if (location == nil)
        return nil;
    
    return [[CLLocation alloc] initWithLatitude:location.latitude longitude:location.longitude];
}

@end
