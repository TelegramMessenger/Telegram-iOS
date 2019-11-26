#import "TGLocationMapViewController.h"

#import "Freedom.h"
#import "LegacyComponentsInternal.h"
#import "TGColor.h"
#import "TGImageUtils.h"
#import "TGFont.h"
#import "TGLocationUtils.h"

#import "TGUser.h"
#import "TGLocationMapView.h"
#import "TGLocationOptionsView.h"

#import <LegacyComponents/TGMenuSheetController.h>
#import "TGSearchBar.h"

const MKCoordinateSpan TGLocationDefaultSpan = { 0.008, 0.008 };
const CGFloat TGLocationMapClipHeight = 1600.0f;
const CGFloat TGLocationMapInset = 100.0f;

@interface TGLocationTableView : UITableView

@end

@interface TGLocationMapViewController () <CLLocationManagerDelegate>
{
    id<LegacyComponentsContext> _context;
    
    UIView *_mapClipView;
    
    SVariable *_userLocation;
    SPipe *_userLocationPipe;
    
    MKPolygon *_darkPolygon;
    
    void (^_openLiveLocationMenuBlock)(void);
}
@end

@implementation TGLocationMapViewController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        _context = context;
        _userLocationPipe = [[SPipe alloc] init];
        
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        
        _userLocation = [[SVariable alloc] init];
        [_userLocation set:[[SSignal single:nil] then:_userLocationPipe.signalProducer()]];
    }
    return self;
}

- (void)dealloc
{
    _locationManager.delegate = nil;
    _mapView.delegate = nil;
    _tableView.dataSource = nil;
    _tableView.delegate = nil;
}

- (void)setPallete:(TGLocationPallete *)pallete {
    _pallete = pallete;
    if ([self isViewLoaded]) {
        self.view.backgroundColor = pallete.backgroundColor;
    }
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = self.pallete.backgroundColor;
    self.alwaysUseTallNavigationBarHeight = true;
        
    _tableView = [[TGLocationTableView alloc] initWithFrame:self.view.bounds];
    if (iosMajorVersion() >= 11)
        _tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.backgroundColor = self.view.backgroundColor;
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.delaysContentTouches = false;
    _tableView.canCancelContentTouches = true;
    [self.view addSubview:_tableView];
    
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    if (self.pallete != nil)
        _activityIndicator.color = self.pallete.secondaryTextColor;
    _activityIndicator.userInteractionEnabled = false;
    [_tableView addSubview:_activityIndicator];
    
    _messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 20)];
    _messageLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _messageLabel.backgroundColor = [UIColor clearColor];
    _messageLabel.font = TGSystemFontOfSize(16);
    _messageLabel.hidden = true;
    _messageLabel.textAlignment = NSTextAlignmentCenter;
    _messageLabel.textColor = self.pallete != nil ? self.pallete.secondaryTextColor : UIColorRGB(0x8e8e93);
    _messageLabel.userInteractionEnabled = false;
    [_tableView addSubview:_messageLabel];
    
    _tableViewTopInset = [self mapHeight];
    _mapClipView = [[UIView alloc] initWithFrame:CGRectMake(0, -TGLocationMapClipHeight, self.view.frame.size.width, TGLocationMapClipHeight + 10.0f)];
    _mapClipView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _mapClipView.clipsToBounds = true;
    [_tableView addSubview:_mapClipView];
    
    _mapViewWrapper = [[UIView alloc] initWithFrame:CGRectMake(0, TGLocationMapClipHeight - _tableViewTopInset, self.view.frame.size.width, _tableViewTopInset + 10.0f)];
    _mapViewWrapper.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_mapClipView addSubview:_mapViewWrapper];
    
    __weak TGLocationMapViewController *weakSelf = self;
    _mapView = [[TGLocationMapView alloc] initWithFrame:CGRectMake(0, -TGLocationMapInset, self.view.frame.size.width, _tableViewTopInset + 2 * TGLocationMapInset + 10.0f)];
    _mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _mapView.delegate = self;
    _mapView.showsUserLocation = true;
    [_mapViewWrapper addSubview:_mapView];
    
    _optionsView = [[TGLocationOptionsView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 45.0f, 90.0f)];
    if (self.pallete != nil)
        _optionsView.pallete = self.pallete;
    _optionsView.mapModeChanged = ^(NSInteger mapMode) {
        __strong TGLocationMapViewController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf->_mapView setMapType:(MKMapType)mapMode];
        
    };
    _optionsView.trackModePressed = ^{
        __strong TGLocationMapViewController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf userLocationButtonPressed];
    };
    [self.view addSubview:_optionsView];
    
    UIImage *edgeImage = TGComponentsImageNamed(@"LocationPanelEdge");
    UIImage *edgeHighlightImage = TGComponentsImageNamed(@"LocationPanelEdge_Highlighted");
    if (self.pallete != nil)
    {
        UIGraphicsBeginImageContextWithOptions(edgeImage.size, false, 0.0f);
        [edgeImage drawAtPoint:CGPointZero];
        [TGTintedImage(edgeHighlightImage, self.pallete.backgroundColor) drawAtPoint:CGPointZero];

        edgeImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    _edgeView = [[UIImageView alloc] initWithImage:[edgeImage resizableImageWithCapInsets:UIEdgeInsetsMake(0.0f, 10.0f, 0.0f, 10.0f)]];
    _edgeView.frame = CGRectMake(0.0f, _tableViewTopInset - 10.0f, _mapViewWrapper.frame.size.width, _edgeView.frame.size.height);
    [_mapViewWrapper addSubview:_edgeView];
    
    if (self.pallete != nil)
        edgeHighlightImage = TGTintedImage(edgeHighlightImage, self.pallete.selectionColor);
    
    _edgeHighlightView = [[UIImageView alloc] initWithImage:[edgeHighlightImage resizableImageWithCapInsets:UIEdgeInsetsMake(0.0f, 10.0f, 0.0f, 10.0f)]];
    _edgeHighlightView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _edgeHighlightView.frame = _edgeView.bounds;
    _edgeHighlightView.alpha = 0.0f;
    _edgeHighlightView.image = [edgeHighlightImage resizableImageWithCapInsets:UIEdgeInsetsMake(0.0f, 10.0f, 0.0f, 10.0f)];
    [_edgeView addSubview:_edgeHighlightView];
    
    self.scrollViewsForAutomaticInsetsAdjustment = @[ _tableView ];
    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)layoutControllerForSize:(CGSize)size duration:(NSTimeInterval)duration
{
    [super layoutControllerForSize:size duration:duration];
    
    if (!self.isViewLoaded)
        return;
    
    [self updateMapHeightAnimated:false];
    _optionsView.frame = CGRectMake(self.view.bounds.size.width - 45.0f - 6.0f - self.controllerSafeAreaInset.right, 56.0f + 6.0f, 45.0f, 90.0f);
    _tableView.contentOffset = CGPointMake(0.0f, -_tableViewTopInset - self.controllerInset.top);
}

- (void)setOptionsViewHidden:(bool)hidden
{
    if (_optionsView.userInteractionEnabled == !hidden)
        return;
    
    _optionsView.userInteractionEnabled = !hidden;
    [UIView animateWithDuration:0.15 animations:^
    {
        _optionsView.alpha = hidden ? 0.0f : 1.0f;
    }];
}

- (void)userLocationButtonPressed
{
    
}

- (bool)hasUserLocation
{
    return (_mapView.userLocation != nil && _mapView.userLocation.location != nil);
}

- (void)updateLocationAvailability
{
    bool locationAvailable = [self hasUserLocation] || _locationServicesDisabled;
    [_optionsView setLocationAvailable:locationAvailable animated:true];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == _tableView)
    {
        CGFloat offset = scrollView.contentInset.top + scrollView.contentOffset.y;
        CGFloat mapOffset = MIN(offset, [self mapHeight]);
        _mapView.frame = CGRectMake(_mapView.frame.origin.x, -TGLocationMapInset + mapOffset / 2, _mapView.frame.size.width, _mapView.frame.size.height);
        
        [self setOptionsViewHidden:(scrollView.contentOffset.y > -180.0f)];
        
        CGFloat additionalScrollInset = _edgeView.frame.size.height / 2.0f;
        if (scrollView.contentOffset.y < -scrollView.contentInset.top)
            additionalScrollInset += -scrollView.contentInset.top - scrollView.contentOffset.y;
        
        scrollView.scrollIndicatorInsets = UIEdgeInsetsMake(self.controllerScrollInset.top + _tableViewTopInset + additionalScrollInset, 0.0f, 0.0f, 0.0f);
    }
}

- (void)_autoAdjustInsetsForScrollView:(UIScrollView *)scrollView previousInset:(UIEdgeInsets)previousInset
{
    CGPoint contentOffset = scrollView.contentOffset;
    
    UIEdgeInsets controllerInset = self.controllerInset;
    controllerInset.top += _tableViewTopInset;
    controllerInset.bottom += _tableViewBottomInset;
    
    UIEdgeInsets scrollInset = self.controllerScrollInset;
    scrollInset.top += _tableViewTopInset;
    
    scrollView.contentInset = controllerInset;
    scrollView.scrollIndicatorInsets = scrollInset;
    
    if (!UIEdgeInsetsEqualToEdgeInsets(previousInset, UIEdgeInsetsZero))
    {
        CGFloat maxOffset = scrollView.contentSize.height - (scrollView.frame.size.height - controllerInset.bottom);
        
        if (![self shouldAdjustScrollViewInsetsForInversedLayout])
            contentOffset.y += previousInset.top - controllerInset.top;
        
        contentOffset.y = MAX(-controllerInset.top, MIN(contentOffset.y, maxOffset));
        [scrollView setContentOffset:contentOffset animated:false];
    }
    else if (contentOffset.y < controllerInset.top)
    {
        contentOffset.y = -controllerInset.top;
        [scrollView setContentOffset:contentOffset animated:false];
    }
    
    _optionsView.frame = CGRectMake(self.view.bounds.size.width - 45.0f - 6.0f, 56.0f + 6.0f, 45.0f, 90.0f);
}

- (NSInteger)tableView:(UITableView *)__unused tableView numberOfRowsInSection:(NSInteger)__unused section
{
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)__unused tableView cellForRowAtIndexPath:(NSIndexPath *)__unused indexPath
{
    return nil;
}

- (void)tableView:(UITableView *)tableView didHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
}

- (void)tableView:(UITableView *)tableView didUnhighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
}

- (void)updateInsets
{
    UIEdgeInsets previousInset = _tableView.contentInset;
    
    CGPoint previousOffset = _tableView.contentOffset;
    UIEdgeInsets controllerInset = self.controllerInset;
    controllerInset.top += _tableViewTopInset;
    controllerInset.bottom += _tableViewBottomInset;
    _tableView.contentInset = controllerInset;
    
    if (previousInset.bottom > FLT_EPSILON)
        _tableView.contentOffset = previousOffset;
}

- (void)updateMapHeightAnimated:(bool)animated
{
    void (^changeBlock)(void) = ^
    {
        _tableViewTopInset = [self mapHeight];
        
        _mapViewWrapper.frame = CGRectMake(0, TGLocationMapClipHeight - _tableViewTopInset, self.view.frame.size.width, _tableViewTopInset + 10.0f);
        _mapView.frame = CGRectMake(0, -TGLocationMapInset, self.view.frame.size.width, _tableViewTopInset + 2 * TGLocationMapInset + 10.0f);
        _edgeView.frame = CGRectMake(0.0f, _tableViewTopInset - 10.0f, _mapViewWrapper.frame.size.width, _edgeView.frame.size.height);
        
        [self updateInsets];
    };
    
    if (animated)
    {
        [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
        {
            changeBlock();
        } completion:nil];
    }
    else
    {
        changeBlock();
    }
}

- (CGFloat)mapHeight
{
    return self.view.frame.size.height - [self visibleContentHeight] - self.controllerInset.top;
}

- (CGFloat)visibleContentHeight
{
    return 0.0f;
}

- (CGFloat)safeAreaInsetBottom {
    return MAX(self.context.safeAreaInset.bottom, self.controllerSafeAreaInset.bottom);
}

#pragma mark -

- (void)setMapCenterCoordinate:(CLLocationCoordinate2D)coordinate offset:(CGPoint)offset animated:(bool)animated
{
    [self setMapCenterCoordinate:coordinate span:TGLocationDefaultSpan offset:offset animated:animated];
}

- (void)setMapCenterCoordinate:(CLLocationCoordinate2D)coordinate span:(MKCoordinateSpan)span offset:(CGPoint)offset animated:(bool)animated
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

#pragma mark -

- (UIView *)locationMapView
{
    return _mapView;
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    if (overlay == _darkPolygon)
    {
        MKPolygonRenderer *renderer = [[MKPolygonRenderer alloc] initWithPolygon:overlay];
        renderer.fillColor = [[UIColor blackColor] colorWithAlphaComponent:0.3f];
        return renderer;
    }
    
    return nil;
}

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[MKPolygon class]])
    {
        MKPolygonView *overlayView = [[MKPolygonView alloc] initWithPolygon:overlay];
        overlayView.fillColor = [[UIColor blackColor] colorWithAlphaComponent:0.3f];
        return overlayView;
    }
    
    return nil;
}

- (void)mapView:(MKMapView *)__unused mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    userLocation.title = @"";
    
    _locationServicesDisabled = false;
    
    if (userLocation.location != nil)
        _userLocationPipe.sink(userLocation.location);
    
    [self updateLocationAvailability];
}

- (void)mapView:(MKMapView *)__unused mapView didFailToLocateUserWithError:(NSError *)__unused error
{
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied || [CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted)
    {
        _userLocationPipe.sink(nil);
        _locationServicesDisabled = true;
        [self updateLocationAvailability];
    }
}

- (bool)locationServicesDisabled
{
    return _locationServicesDisabled;
}

- (SSignal *)userLocationSignal
{
    return [_userLocation signal];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (_openLiveLocationMenuBlock != nil)
    {
        if (status == kCLAuthorizationStatusAuthorizedAlways)
            _openLiveLocationMenuBlock();
        
        _openLiveLocationMenuBlock = nil;
    }
}

- (CGRect)_liveLocationMenuSourceRect
{
    return CGRectZero;
}

- (void)_willStartOwnLiveLocation
{
    
}

- (void)dismissLiveLocationMenu:(TGMenuSheetController *)controller doNotRemove:(bool)doNotRemove
{
    [self _willStartOwnLiveLocation];
    
    if (!doNotRemove)
    {
        [controller dismissAnimated:true];
    }
    else
    {
        [controller setDimViewHidden:true animated:true];
        [controller removeFromParentViewController];
    }
}

- (void)_presentLiveLocationMenu:(CLLocationCoordinate2D)coordinate dismissOnCompletion:(bool)dismissOnCompletion
{
    void (^block)(void) = ^
    {
        __weak TGLocationMapViewController *weakSelf = self;
        CGRect (^sourceRect)(void) = ^CGRect
        {
            __strong TGLocationMapViewController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return CGRectZero;
            
            return [strongSelf _liveLocationMenuSourceRect];
        };
        
        TGMenuSheetController *controller = [[TGMenuSheetController alloc] initWithContext:_context dark:false];
        controller.dismissesByOutsideTap = true;
        controller.hasSwipeGesture = true;
        controller.narrowInLandscape = true;
        controller.sourceRect = sourceRect;
        
        NSMutableArray *itemViews = [[NSMutableArray alloc] init];
        
        NSString *title = TGLocalized(@"Map.LiveLocationGroupDescription");
        if ([self.receivingPeer isKindOfClass:[TGUser class]])
            title = [NSString stringWithFormat:TGLocalized(@"Map.LiveLocationPrivateDescription"), [(TGUser *)self.receivingPeer displayFirstName]];
        
        TGMenuSheetTitleItemView *titleItem = [[TGMenuSheetTitleItemView alloc] initWithTitle:nil subtitle:title];
        [itemViews addObject:titleItem];
        
        __weak TGMenuSheetController *weakController = controller;
        TGMenuSheetButtonItemView *for15MinutesItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Map.LiveLocationFor15Minutes") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
        {
            __strong TGLocationMapViewController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController == nil)
                return;
            
            if (strongSelf.liveLocationStarted != nil)
                strongSelf.liveLocationStarted(coordinate, 15 * 60);
            
            [strongSelf dismissLiveLocationMenu:strongController doNotRemove:!dismissOnCompletion];
        }];
        [itemViews addObject:for15MinutesItem];
        
        TGMenuSheetButtonItemView *for1HourItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Map.LiveLocationFor1Hour") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
        {
            __strong TGLocationMapViewController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController == nil)
                return;
            
            if (strongSelf.liveLocationStarted != nil)
                strongSelf.liveLocationStarted(coordinate, 60 * 60 - 1);
            
            [strongSelf dismissLiveLocationMenu:strongController doNotRemove:!dismissOnCompletion];
        }];
        [itemViews addObject:for1HourItem];
        
        TGMenuSheetButtonItemView *for8HoursItem = [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Map.LiveLocationFor8Hours") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
        {
            __strong TGLocationMapViewController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController == nil)
                return;
            
            if (strongSelf.liveLocationStarted != nil)
                strongSelf.liveLocationStarted(coordinate, 8 * 60 * 60);
            
            [strongSelf dismissLiveLocationMenu:strongController doNotRemove:!dismissOnCompletion];
        }];
        [itemViews addObject:for8HoursItem];
        
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
    };
    
    void (^errorBlock)(void) = ^
    {
        [[[LegacyComponentsGlobals provider] accessChecker] checkLocationAuthorizationStatusForIntent:TGLocationAccessIntentLiveLocation alertDismissComlpetion:nil];
    };
    
    if ([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedAlways && [CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorizedWhenInUse)
    {
        errorBlock();
    }
    else
    {
        if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorizedAlways)
        {
            block();
        }
        else
        {
            if (![TGLocationUtils requestAlwaysUserLocationAuthorizationWithLocationManager:_locationManager])
                errorBlock();
            else
                _openLiveLocationMenuBlock = [block copy];
        }
    }
}

@end


@implementation TGLocationTableView

- (BOOL)touchesShouldCancelInContentView:(UIView *)__unused view
{
    return true;
}

static void TGLocationTableViewAdjustContentOffsetIfNecessary(__unused id self, __unused SEL _cmd)
{
}

+ (void)initialize
{
    static bool initialized = false;
    if (!initialized)
    {
        initialized = true;
        
        FreedomDecoration instanceDecorations[] =
        {
            { .name = 0x584ab24eU,
                .imp = (IMP)&TGLocationTableViewAdjustContentOffsetIfNecessary,
                .newIdentifier = FreedomIdentifierEmpty,
                .newEncoding = FreedomIdentifierEmpty
            }
        };
        
        freedomClassAutoDecorate(0x5bfec194, NULL, 0, instanceDecorations, sizeof(instanceDecorations) / sizeof(instanceDecorations[0]));
    }
}

@end

@implementation TGLocationPallete

+ (instancetype)palleteWithBackgroundColor:(UIColor *)backgroundColor selectionColor:(UIColor *)selectionColor separatorColor:(UIColor *)separatorColor textColor:(UIColor *)textColor secondaryTextColor:(UIColor *)secondaryTextColor accentColor:(UIColor *)accentColor destructiveColor:(UIColor *)destructiveColor locationColor:(UIColor *)locationColor liveLocationColor:(UIColor *)liveLocationColor iconColor:(UIColor *)iconColor sectionHeaderBackgroundColor:(UIColor *)sectionHeaderBackgroundColor sectionHeaderTextColor:(UIColor *)sectionHeaderTextColor searchBarPallete:(TGSearchBarPallete *)searchBarPallete avatarPlaceholder:(UIImage *)avatarPlaceholder
{
    TGLocationPallete *pallete = [[TGLocationPallete alloc] init];
    pallete->_backgroundColor = backgroundColor;
    pallete->_selectionColor = selectionColor;
    pallete->_separatorColor = separatorColor;
    pallete->_textColor = textColor;
    pallete->_secondaryTextColor = secondaryTextColor;
    pallete->_accentColor = accentColor;
    pallete->_destructiveColor = destructiveColor;
    pallete->_locationColor = locationColor;
    pallete->_liveLocationColor = liveLocationColor;
    pallete->_iconColor = iconColor;
    pallete->_sectionHeaderBackgroundColor = sectionHeaderBackgroundColor;
    pallete->_sectionHeaderTextColor = sectionHeaderTextColor;
    pallete->_searchBarPallete = searchBarPallete;
    pallete->_avatarPlaceholder = avatarPlaceholder;
    return pallete;
}

@end
