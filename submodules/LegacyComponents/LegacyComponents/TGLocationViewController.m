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

@interface TGLiveLocation ()

- (CLLocation *)location;

@end

@interface TGLocationViewController () <MKMapViewDelegate>
{
    id<LegacyComponentsContext> _context;
    bool _dismissing;

    id _peer;
    TGMessage *_message;
    TGLocationMediaAttachment *_locationAttachment;
    UIColor *_venueColor;
    
    TGLocationAnnotation *_annotation;
    
    UIBarButtonItem *_actionsBarItem;
    bool _didSetRightBarButton;
    
    SVariable *_reloadReady;
    SMetaDisposable *_reloadDisposable;
    
    id<SDisposable> _frequentUpdatesDisposable;
    
    SSignal *_signal;
    TGLiveLocation *_currentLiveLocation;
    SMetaDisposable *_liveLocationsDisposable;
    NSArray *_initialLiveLocations;
    NSArray *_liveLocations;
    bool _hasOwnLiveLocation;
    bool _ownLocationExpired;
    
    bool _presentedLiveLocations;
    bool _selectedCurrentLiveLocation;
    
    bool _ignoreNextUpdates;
    bool _focusOnOwnLocation;
    bool _throttle;
    TGLocationPinAnnotationView *_ownLiveLocationView;
    __weak MKAnnotationView *_userLocationView;
}
@end

@implementation TGLocationViewController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context locationAttachment:(TGLocationMediaAttachment *)locationAttachment peer:(id)peer color:(UIColor *)color
{
    self = [self initWithContext:context];
    if (self != nil)
    {
        _locationAttachment = locationAttachment;
        _venueColor = color;
        
        _reloadDisposable = [[SMetaDisposable alloc] init];
        _reloadReady = [[SVariable alloc] init];
        [self setReloadReady:true];
        
        _context = context;
        _peer = peer;
        
        if (locationAttachment.period == 0)
            _annotation = [[TGLocationAnnotation alloc] initWithLocation:locationAttachment color:color];
        
        _liveLocationsDisposable = [[SMetaDisposable alloc] init];
        
        self.titleText = locationAttachment.period > 0 ? TGLocalized(@"Map.LiveLocationTitle") : TGLocalized(@"Map.LocationTitle");
    }
    return self;
}

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context liveLocation:(TGLiveLocation *)liveLocation
{
    self = [self initWithContext:context];
    if (self != nil)
    {
        _message = liveLocation.message;
        _locationAttachment = liveLocation.message.locationAttachment;
        _currentLiveLocation = liveLocation;
        if (liveLocation)
        {
            _liveLocations = @[liveLocation];
            _hasOwnLiveLocation = liveLocation.hasOwnSession;
            if (_hasOwnLiveLocation)
                _ownLocationExpired = liveLocation.isExpired;
        }
        _reloadDisposable = [[SMetaDisposable alloc] init];
        _reloadReady = [[SVariable alloc] init];
        [self setReloadReady:true];
        
        _context = context;
        _peer = liveLocation.peer;
        
        _liveLocationsDisposable = [[SMetaDisposable alloc] init];
        
        self.titleText = _locationAttachment.period > 0 ? TGLocalized(@"Map.LiveLocationTitle") : TGLocalized(@"Map.LocationTitle");
    }
    return self;
}

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context message:(TGMessage *)message peer:(id)peer color:(UIColor *)color
{
    self = [self initWithContext:context];
    if (self != nil)
    {
        _message = message;
        _locationAttachment = message.locationAttachment;
        
        _reloadDisposable = [[SMetaDisposable alloc] init];
        _reloadReady = [[SVariable alloc] init];
        [self setReloadReady:true];
        
        _context = context;
        _peer = peer;
        _venueColor = color;
        
        if (_locationAttachment.period == 0)
            _annotation = [[TGLocationAnnotation alloc] initWithLocation:_locationAttachment color:color];
        
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
    [_frequentUpdatesDisposable dispose];
}

- (void)tg_setRightBarButtonItem:(UIBarButtonItem *)barButtonItem action:(bool)action animated:(bool)animated {
    if (self.updateRightBarItem != nil) {
        self.updateRightBarItem(barButtonItem, action, animated);
    } else {
        [self setRightBarButtonItem:barButtonItem animated:animated];
    }
}

- (void)setFrequentUpdatesHandle:(id<SDisposable>)disposable
{
    _frequentUpdatesDisposable = disposable;
}

- (void)setLiveLocationsSignal:(SSignal *)signal
{
    if (_currentLiveLocation.isOwnLocation)
    {
        _signal = [[signal reduceLeftWithPassthrough:nil with:^id(id current, id value, void (^emit)(id))
        {
            if (current == nil)
            {
                emit([SSignal single:value]);
                return @true;
            }
            else
            {
                emit([[SSignal single:value] delay:0.25 onQueue:[SQueue concurrentDefaultQueue]]);
                return current;
            }
        }] switchToLatest];
    }
    else
    {
        __weak TGLocationViewController *weakSelf = self;
        _signal = [signal mapToSignal:^SSignal *(id value)
        {
            __strong TGLocationViewController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return nil;
            
            if (strongSelf->_throttle)
                return [[SSignal single:value] delay:0.25 onQueue:[SQueue concurrentDefaultQueue]];
            else
                return [SSignal single:value];
        }];
    }
    
    [self setupSignals];
}

- (void)setLiveLocations:(NSArray *)liveLocations actual:(bool)actual
{
    if (liveLocations.count == 0 && _currentLiveLocation != nil)
        liveLocations = @[ _currentLiveLocation ];
    
    TGLiveLocation *ownLiveLocation = nil;
    for (TGLiveLocation *liveLocation in liveLocations)
    {
        if (liveLocation.hasOwnSession)
        {
            ownLiveLocation = liveLocation;
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
            _ownLiveLocationView.pallete = self.pallete;
            _ownLiveLocationView.frame = CGRectOffset(_ownLiveLocationView.frame, 21.0f, 22.0f);
            [_userLocationView addSubview:_ownLiveLocationView];
            
            if (_currentLiveLocation.hasOwnSession)
                [self selectOwnAnnotationAnimated:false];
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
    
    if (!_presentedLiveLocations && actual)
    {
        _presentedLiveLocations = true;
        if (previousLocationsCount < liveLocations.count > 0)
        {
            CGFloat updatedHeight = [self possibleContentHeight] - [self visibleContentHeight];
            if (fabs(-_tableView.contentInset.top + updatedHeight - _tableView.contentOffset.y) > FLT_EPSILON)
            {
                TGDispatchAfter(0.3, dispatch_get_main_queue(), ^
                {
                    [self setReloadReady:false];
                    [_tableView setContentOffset:CGPointMake(0.0f, -_tableView.contentInset.top + updatedHeight) animated:true];
                });
            }
        }
        
        if (_currentLiveLocation.hasOwnSession && !_ownLocationExpired && !self.zoomToFitAllLocationsOnScreen)
        {
            [_mapView setUserTrackingMode:[TGLocationTrackingButton userTrackingModeWithLocationTrackingMode:TGLocationTrackingModeFollow] animated:false];
            [_optionsView setTrackingMode:TGLocationTrackingModeFollow animated:true];
        }
    }
    [self updateAnnotations];
    
    if ([self isLiveLocation])
    {
        if ([self hasMoreThanOneLocation])
        {
            if (!_didSetRightBarButton)
            {
                _didSetRightBarButton = true;
                [self tg_setRightBarButtonItem:_actionsBarItem action:false animated:true];
            }
            
            if (actual && self.zoomToFitAllLocationsOnScreen)
            {
                _zoomToFitAllLocationsOnScreen = false;
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    MKMapRect visibleMapRect = _mapView.visibleMapRect;
                    NSSet *visibleAnnotations = [_mapView annotationsInMapRect:visibleMapRect];
                    if (visibleAnnotations.count == _mapView.annotations.count)
                        return;
                    
                    [self showAllPressed];
                });
            }
        }
        else
        {
            if (_didSetRightBarButton)
            {
                _didSetRightBarButton = false;
                [self tg_setRightBarButtonItem:nil action:false animated:true];
            }
        }
    }
    
    if (_focusOnOwnLocation)
    {
        if (_ownLiveLocationView != nil && !_ownLiveLocationView.isSelected)
        {
            [self selectOwnAnnotationAnimated:false];
            _focusOnOwnLocation = false;
            _throttle = false;
            
            dispatch_async(dispatch_get_main_queue(), ^
            {
                MKMapRect visibleMapRect = _mapView.visibleMapRect;
                NSSet *visibleAnnotations = [_mapView annotationsInMapRect:visibleMapRect];
                if (visibleAnnotations.count == _mapView.annotations.count)
                    return;
                
                [self showAllPressed];
            });
        }
    }
}

- (bool)handleOwnAnnotationTap:(CGPoint)location
{
    if (_ownLiveLocationView == nil)
        return false;
    
    if (CGRectContainsPoint([_ownLiveLocationView.superview convertRect:CGRectInset(_ownLiveLocationView.frame, -16.0f, - 16.0f) toView:_mapView], location))
    {
        [self selectOwnAnnotation];
        [self setMapCenterCoordinate:_ownLiveLocationView.annotation.coordinate offset:CGPointZero animated:true];
        return true;
    }
    
    return false;
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
    NSMutableDictionary *liveLocations = [[NSMutableDictionary alloc] init];
    for (TGLiveLocation *liveLocation in _liveLocations)
    {
        if (!liveLocation.hasOwnSession || liveLocation.isExpired)
            liveLocations[@(liveLocation.message.mid)] = liveLocation;
    }
    
    TGLocationAnnotation *currentAnnotation = nil;
    NSMutableSet *annotationsToRemove = [[NSMutableSet alloc] init];
    for (TGLocationAnnotation *annotation in _mapView.annotations)
    {
        if (![annotation isKindOfClass:[TGLocationAnnotation class]] || annotation == _annotation)
            continue;
        
        if (liveLocations[@(annotation.messageId)] != nil)
        {
            annotation.coordinate = [(TGLiveLocation *)liveLocations[@(annotation.messageId)] location].coordinate;
            annotation.isExpired = [(TGLiveLocation *)liveLocations[@(annotation.messageId)] isExpired];
            [liveLocations removeObjectForKey:@(annotation.messageId)];
            
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
    for (TGLiveLocation *liveLocation in liveLocations.allValues)
    {
        TGLocationAnnotation *annotation = [[TGLocationAnnotation alloc] initWithLocation:liveLocation.message.locationAttachment];
        annotation.peer = liveLocation.peer;
        annotation.messageId = liveLocation.message.mid;
        annotation.isExpired = liveLocation.isExpired;
        
        [newAnnotations addObject:annotation];
        
        if (annotation.messageId == _currentLiveLocation.message.mid)
            currentAnnotation = annotation;
    }
    
    [_mapView addAnnotations:newAnnotations];
    
    NSInteger annotationsCount = _ownLiveLocationView != nil ? 1 : 0;
    for (TGLocationAnnotation *annotation in _mapView.annotations)
    {
        if ([annotation isKindOfClass:[TGLocationAnnotation class]] && ((TGLocationAnnotation *)annotation).isLiveLocation)
            annotationsCount += 1;
    }
    
    _mapView.allowAnnotationSelectionChanges = annotationsCount;
    
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
    
    __weak TGLocationViewController *weakSelf = self;
    _mapView.customAnnotationTap = ^bool(CGPoint location)
    {
        __strong TGLocationViewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        return [strongSelf handleOwnAnnotationTap:location];
    };
    
    if (TGIsPad() || _modalMode)
    {
        [self setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Done") style:UIBarButtonItemStyleDone target:self action:@selector(dismissButtonPressed)]];
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
            [self tg_setRightBarButtonItem:_actionsBarItem action:true animated:false];
        }
        else
        {
            NSString *actionsButtonTitle = TGLocalized(@"Common.More");
            _actionsBarItem = [[UIBarButtonItem alloc] initWithTitle:actionsButtonTitle style:UIBarButtonItemStylePlain target:self action:@selector(actionsButtonPressed)];
            [self tg_setRightBarButtonItem:_actionsBarItem action:true animated:false];
        }
    }
    
    if (_previewMode)
        _optionsView.hidden = true;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [_mapView addAnnotation:_annotation];
    [_mapView selectAnnotation:_annotation animated:false];
    
    _mapView.region = MKCoordinateRegionMake([self locationCoordinate], MKCoordinateSpanMake(0.008, 0.008));
    
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
    
    if ([_tableView numberOfRowsInSection:0] > 0)
        [_tableView layoutSubviews];
    
    CGFloat updatedHeight = [self possibleContentHeight] - [self visibleContentHeight];
    [_tableView setContentOffset:CGPointMake(0.0f, -_tableView.contentInset.top + updatedHeight) animated:false];
    
    if (_initialLiveLocations.count > 0)
    {
        [self setLiveLocations:_initialLiveLocations actual:false];
        _initialLiveLocations = nil;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.onViewDidAppear != nil)
        self.onViewDidAppear();
}

- (void)setupSignals
{
    SSignal *combinedSignal = [SSignal combineSignals:@[ [[[self userLocationSignal] deliverOn:[SQueue concurrentBackgroundQueue]] map:^id(id location) {
        if (location != nil)
            return location;
        else
            return [NSNull null];
    }], _signal ]];
    
    __weak TGLocationViewController *weakSelf = self;
    [_liveLocationsDisposable setDisposable:[combinedSignal startWithNext:^(NSArray *next)
    {
        __strong TGLocationViewController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf->_dismissing)
            return;
        
        CLLocation *currentLocation = [next.firstObject isKindOfClass:[CLLocation class]] ? next.firstObject : nil;
        NSArray *liveLocations = next.lastObject;
        bool actual = liveLocations.count > 0;
        
        NSMutableArray *filteredLiveLocations = [[NSMutableArray alloc] init];
        bool hasCurrentLocation = false;
        bool currentExpiredLocationIsOwn = false;
        for (TGLiveLocation *liveLocation in liveLocations)
        {
            if (!liveLocation.isExpired)
                [filteredLiveLocations addObject:liveLocation];
            if (liveLocation.message.mid == strongSelf->_currentLiveLocation.message.mid)
                hasCurrentLocation = true;
        }
        if (!hasCurrentLocation && strongSelf->_currentLiveLocation != nil)
        {
            bool isChannel = [strongSelf->_currentLiveLocation.peer isKindOfClass:[TGConversation class]] && !((TGConversation *)strongSelf->_currentLiveLocation.peer).isChannelGroup;
            
            TGLiveLocation *currentExpiredLiveLocation = [[TGLiveLocation alloc] initWithMessage:strongSelf->_currentLiveLocation.message peer:strongSelf->_currentLiveLocation.peer hasOwnSession:strongSelf->_currentLiveLocation.hasOwnSession isOwnLocation:strongSelf->_currentLiveLocation.isOwnLocation isExpired:isChannel ? strongSelf->_currentLiveLocation.isExpired : true];
            [filteredLiveLocations addObject:currentExpiredLiveLocation];
            
            if (currentExpiredLiveLocation.isOwnLocation && currentExpiredLiveLocation.isExpired)
                currentExpiredLocationIsOwn = true;
        }
        liveLocations = filteredLiveLocations;
        
        for (TGLiveLocation *location in filteredLiveLocations)
        {
            if (strongSelf->_ignoreNextUpdates && location.hasOwnSession && !location.isExpired && (currentExpiredLocationIsOwn || (strongSelf->_currentLiveLocation.isOwnLocation && strongSelf->_currentLiveLocation.isExpired)))
            {
                strongSelf->_dismissing = true;
                TGDispatchOnMainThread(^
                {
                    if (strongSelf.openLocation != nil)
                        strongSelf.openLocation(location.message);
                });
                return;
            }
        }
        
        if (strongSelf->_ignoreNextUpdates)
            return;
        
        NSMutableArray *sortedLiveLocations = [liveLocations mutableCopy];
        if (currentLocation != nil)
        {
            [sortedLiveLocations sortUsingComparator:^NSComparisonResult(TGLiveLocation *obj1, TGLiveLocation *obj2)
            {
                if (obj1.hasOwnSession)
                    return NSOrderedAscending;
                else if (obj2.hasOwnSession)
                    return NSOrderedDescending;
                
                if (obj1.message.mid == strongSelf->_currentLiveLocation.message.mid)
                    return NSOrderedAscending;
                else if (obj2.message.mid == strongSelf->_currentLiveLocation.message.mid)
                    return NSOrderedDescending;
                
                CGFloat distance1 = [obj1.location distanceFromLocation:currentLocation];
                CGFloat distance2 = [obj2.location distanceFromLocation:currentLocation];
                
                if (distance1 > distance2)
                    return NSOrderedDescending;
                else if (distance1 < distance2)
                    return NSOrderedAscending;
                
                return NSOrderedSame;
            }];
        }
        else
        {
            [sortedLiveLocations sortUsingComparator:^NSComparisonResult(TGLiveLocation *obj1, TGLiveLocation *obj2)
            {
                if (obj1.hasOwnSession)
                    return NSOrderedAscending;
                else if (obj2.hasOwnSession)
                    return NSOrderedDescending;
                
                if (obj1.message.mid == strongSelf->_currentLiveLocation.message.mid)
                    return NSOrderedAscending;
                else if (obj2.message.mid == strongSelf->_currentLiveLocation.message.mid)
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
                [strongSelf setLiveLocations:sortedLiveLocations actual:actual];
            else
                strongSelf->_initialLiveLocations = sortedLiveLocations;
        });
    }]];
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
    
    if (self.presentActionsMenu != nil)
    {
        self.presentActionsMenu(locationAttachment, false);
        return;
    }
    
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
        TGMenuSheetButtonItemView *openItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Map.OpenInMaps") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
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
        
        TGMenuSheetButtonItemView *shareItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Conversation.ContextMenuShare") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
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
        
        TGMenuSheetButtonItemView *cancelItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.Cancel") type:TGMenuSheetButtonTypeCancel fontSize:20.0 action:^
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
    if (![self hasUserLocation])
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
    
    if (newMode != TGLocationTrackingModeNone && _ownLiveLocationView != nil)
        [self selectOwnAnnotation];
}

- (void)selectOwnAnnotation
{
    [self selectOwnAnnotationAnimated:true];
}

- (void)selectOwnAnnotationAnimated:(bool)animated
{
    if (!_ownLiveLocationView.isSelected)
        [_ownLiveLocationView setSelected:true animated:animated];
    [_mapView deselectAnnotation:_mapView.selectedAnnotations.firstObject animated:true];
    [_ownLiveLocationView.superview.superview bringSubviewToFront:_ownLiveLocationView.superview];
}

- (void)getDirectionsPressed:(TGLocationMediaAttachment *)locationAttachment prompt:(bool)prompt
{
    if (self.presentActionsMenu != nil)
    {
        self.presentActionsMenu(locationAttachment, true);
        return;
    }
    
    if (_presentOpenInMenu && _presentOpenInMenu(self, locationAttachment, true, nil))
    {
    }
    else
    {
        void (^block)(void) = ^
        {
            NSString *title = @"";
            if (locationAttachment.venue != nil)
                title = locationAttachment.venue.title;
            else if ([_peer isKindOfClass:[TGUser class]])
                title = ((TGUser *)_peer).displayName;
            else if ([_peer isKindOfClass:[TGConversation class]])
                title = ((TGConversation *)_peer).chatTitle;
            
            [TGLocationUtils openMapsWithCoordinate:[self locationCoordinate] withDirections:true locationName:title];
        };
        
        if (prompt)
        {
            TGMenuSheetController *controller = [[TGMenuSheetController alloc] initWithContext:_context dark:false];
            controller.dismissesByOutsideTap = true;
            controller.narrowInLandscape = true;
            
            __weak TGMenuSheetController *weakController = controller;
            NSArray *items = @
            [
             [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Map.GetDirections") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
              {
                  __strong TGMenuSheetController *strongController = weakController;
                  if (strongController == nil)
                      return;
                  
                  [strongController dismissAnimated:true];
                  block();
              }],
             [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.Cancel") type:TGMenuSheetButtonTypeCancel fontSize:20.0 action:^
              {
                  __strong TGMenuSheetController *strongController = weakController;
                  if (strongController != nil)
                      [strongController dismissAnimated:true];
              }]
             ];
            
            [controller setItemViews:items];
            controller.sourceRect = ^
            {
                return CGRectZero;
            };
            controller.permittedArrowDirections = UIPopoverArrowDirectionUp;
            [controller presentInViewController:self sourceView:self.view animated:true];
        }
        else
        {
            block();
        }
    }
}

- (UIButton *)directionsButton
{
    TGLocationInfoCell *infoCell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    if ([infoCell isKindOfClass:[TGLocationInfoCell class]])
        return infoCell.directionsButton;
    
    return nil;
}

- (CGRect)_liveLocationMenuSourceRect
{
    TGLocationLiveCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    if ([cell isKindOfClass:[TGLocationLiveCell class]])
        return [cell convertRect:cell.bounds toView:self.view];
    
    return CGRectZero;
}

#pragma mark - Map View Delegate

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
                
                if (_currentLiveLocation.hasOwnSession && _mapView.selectedAnnotations.count == 0)
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

- (void)mapView:(MKMapView *)mapView didChangeUserTrackingMode:(MKUserTrackingMode)mode animated:(BOOL)animated
{
    if (mode == MKUserTrackingModeNone)
        [_optionsView setTrackingMode:TGLocationTrackingModeNone animated:true];
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
    __weak TGLocationViewController *weakSelf = self;
    if (indexPath.row == 0 && ![self isLiveLocation])
    {
        TGLocationInfoCell *cell = [tableView dequeueReusableCellWithIdentifier:TGLocationInfoCellKind];
        if (cell == nil)
            cell = [[TGLocationInfoCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGLocationInfoCellKind];
        cell.pallete = self.pallete;
        [cell setLocation:_locationAttachment color: _venueColor messageId:_message.mid userLocationSignal:[self userLocationSignal]];
        cell.locatePressed = ^
        {
            __strong TGLocationViewController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                [strongSelf->_mapView deselectAnnotation:strongSelf->_mapView.selectedAnnotations.firstObject animated:true];
                [strongSelf setMapCenterCoordinate:[strongSelf locationCoordinate] offset:CGPointZero animated:true];
            }
        };
        cell.directionsPressed = ^
        {
            __strong TGLocationViewController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf getDirectionsPressed:strongSelf->_locationAttachment prompt:false];
        };
        cell.safeInset = self.controllerSafeAreaInset;
        return cell;
    }
    else
    {
        TGLocationLiveCell *cell = [tableView dequeueReusableCellWithIdentifier:TGLocationLiveCellKind];
        if (cell == nil)
            cell = [[TGLocationLiveCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TGLocationLiveCellKind];
        cell.pallete = self.pallete;
        cell.edgeView = indexPath.row == 0 ? _edgeHighlightView : nil;
        cell.safeInset = self.controllerSafeAreaInset;
        
        if (self.allowLiveLocationSharing && (indexPath.row == 0 || (![self isLiveLocation] && indexPath.row == 1)))
        {
            if (_hasOwnLiveLocation)
            {
                TGLiveLocation *liveLocation = _liveLocations.firstObject;
                if (liveLocation.isExpired)
                    [cell configureForStart];
                else
                    [cell configureForStopWithMessage:liveLocation.message remaining:self.remainingTimeForMessage(liveLocation.message)];
            }
            else
            {
                [cell configureForStart];
            }
            
            cell.longPressed = nil;
        }
        else
        {
            NSInteger index = indexPath.row;
            if (![self isLiveLocation])
                index -= 1;
            if (self.allowLiveLocationSharing && !_hasOwnLiveLocation)
                index -= 1;
            
            TGLiveLocation *liveLocation = index >= 0 && index < _liveLocations.count ? _liveLocations[index] : nil;
            [cell configureWithPeer:liveLocation.peer message:liveLocation.message remaining:self.remainingTimeForMessage(liveLocation.message) userLocationSignal:[self userLocationSignal]];
            
            cell.longPressed = ^
            {
                __strong TGLocationViewController *strongSelf = weakSelf;
                if (strongSelf != nil)
                    [strongSelf getDirectionsPressed:liveLocation.message.locationAttachment prompt:true];
            };
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
            
            TGLiveLocation *liveLocation = _liveLocations[index];
            for (TGLocationAnnotation *annotation in _mapView.annotations)
            {
                if (![annotation isKindOfClass:[TGLocationAnnotation class]])
                    continue;
                
                if (annotation.messageId == liveLocation.message.mid)
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
        return TGLocationInfoCellHeight + self.safeAreaInsetBottom;
    else
        return TGLocationLiveCellHeight + self.safeAreaInsetBottom;
}

- (CGFloat)possibleContentHeight
{
    if (![self isLiveLocation])
    {
        CGFloat height = TGLocationInfoCellHeight;
        if (_liveLocations.count > 0)
        {
            CGFloat count = _liveLocations.count;
            if (self.allowLiveLocationSharing && !_hasOwnLiveLocation)
                count += 1;
            count = MIN(1.5f, count);
            height += count * TGLocationLiveCellHeight;
        }
        return height + self.safeAreaInsetBottom;
    }
    else
    {
        CGFloat count = _liveLocations.count;
        if (self.allowLiveLocationSharing && !_hasOwnLiveLocation)
            count += 1;
        count = MIN(2.5f, count);
        CGFloat height = count * TGLocationLiveCellHeight;
        return height + self.safeAreaInsetBottom;
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
    
    _mapView.compassInsets = UIEdgeInsetsMake(TGLocationMapInset + 120.0f + (scrollView.contentOffset.y + scrollView.contentInset.top) / 2.0f, 0.0f, 0.0f, 10.0f + TGScreenPixel);
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

- (void)_willStartOwnLiveLocation
{
    _focusOnOwnLocation = true;
    
    if (_currentLiveLocation.isOwnLocation)
        _ignoreNextUpdates = true;
    else
        _throttle = true;
}

- (void)layoutControllerForSize:(CGSize)size duration:(NSTimeInterval)duration
{
    [super layoutControllerForSize:size duration:duration];
    
    if (!self.isViewLoaded)
        return;
    
    for (UITableViewCell *cell in _tableView.visibleCells)
    {
        if ([cell isKindOfClass:[TGLocationInfoCell class]])
        {
            ((TGLocationInfoCell *)cell).safeInset = self.controllerSafeAreaInset;
        } else if ([cell isKindOfClass:[TGLocationLiveCell class]])
        {
            ((TGLocationLiveCell *)cell).safeInset = self.controllerSafeAreaInset;
        }
    }
}

@end


@implementation TGLiveLocation

- (instancetype)initWithMessage:(TGMessage *)message peer:(id)peer hasOwnSession:(bool)hasOwnSession isOwnLocation:(bool)isOwnLocation isExpired:(bool)isExpired
{
    self = [super init];
    if (self != nil)
    {
        _message = message;
        _peer = peer;
        _hasOwnSession = hasOwnSession;
        _isOwnLocation = isOwnLocation;
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
        _hasOwnSession = true;
        _isOwnLocation = true;
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
