#import "TGLocationController.h"

#import <WatchCommonWatch/WatchCommonWatch.h>

#import "TGWatchCommon.h"

#import "TGBridgeLocationSignals.h"

#import "TGBridgeLocationVenue+TGTableItem.h"

#import "WKInterfaceTable+TGDataDrivenTable.h"
#import "TGTableDeltaUpdater.h"

#import "TGLocationMapHeaderController.h"
#import "TGLocationVenueRowController.h"

NSString *const TGLocationControllerIdentifier = @"TGLocationController";
const NSUInteger TGLocationControllerBatchLimit = 14;

@implementation TGLocationControllerContext

@end

@interface TGLocationController () <TGTableDataSource>
{
    TGLocationControllerContext *_context;
    
    SMetaDisposable *_locationDisposable;
    NSArray *_venueModels;
    NSArray *_currentVenueModels;
    CLLocation *_currentLocation;
}
@end

@implementation TGLocationController

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _locationDisposable = [[SMetaDisposable alloc] init];
        
        [self.alertGroup _setInitialHidden:true];
        [self.table _setInitialHidden:true];
        self.table.tableDataSource = self;
    }
    return self;
}

- (void)dealloc
{
    [_locationDisposable dispose];
}

- (void)configureWithContext:(TGLocationControllerContext *)context
{
    _context = context;
    
    __weak TGLocationController *weakSelf = self;
    [_locationDisposable setDisposable:[[[TGBridgeLocationSignals nearbyVenuesWithLimit:TGLocationControllerBatchLimit] deliverOn:[SQueue mainQueue]] startWithNext:^(id next)
    {
        __strong TGLocationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if ([next isKindOfClass:[NSString class]])
        {
            [strongSelf performInterfaceUpdate:^(bool animated)
            {
                 __strong TGLocationController *strongSelf = weakSelf;
                 if (strongSelf == nil)
                     return;
                 
                if ([next isEqualToString:TGBridgeLocationAccessRequiredKey])
                {
                    strongSelf.alertGroup.hidden = false;
                    strongSelf.alertLabel.text = TGLocalized(@"Watch.Location.Access");
                    strongSelf.activityGroup.hidden = true;
                }
                else if ([next isEqualToString:TGBridgeLocationLoadingKey])
                {
                    strongSelf.alertGroup.hidden = true;
                    strongSelf.activityGroup.hidden = false;
                }
            }];
        }
        else if ([next isKindOfClass:[CLLocation class]])
        {
            strongSelf->_currentLocation = (CLLocation *)next;
            [strongSelf performInterfaceUpdate:^(bool animated)
            {
                __strong TGLocationController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                strongSelf.table.hidden = false;
                [strongSelf.table reloadData];
            }];
        }
        else if ([next isKindOfClass:[NSArray class]])
        {
            strongSelf->_venueModels = (NSArray *)next;
            
            [strongSelf performInterfaceUpdate:^(bool animated)
            {
                __strong TGLocationController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                NSArray *currentVenueModels = strongSelf->_currentVenueModels;
                strongSelf->_currentVenueModels = strongSelf->_venueModels;
                
                strongSelf.alertGroup.hidden = true;
                strongSelf.table.hidden = false;
                strongSelf.activityGroup.hidden = true;
                [TGTableDeltaUpdater updateTable:strongSelf.table oldData:currentVenueModels newData:strongSelf->_currentVenueModels controllerClassForIndexPath:^Class(TGIndexPath *indexPath)
                {
                    return [strongSelf table:strongSelf.table rowControllerClassAtIndexPath:indexPath];
                }];
            }];
        }
    } error:^(id error)
    {
        
    } completed:^
    {
        
    }]];
}

- (Class)headerControllerClassForTable:(WKInterfaceTable *)table
{
    return [TGLocationMapHeaderController class];
}

- (void)table:(WKInterfaceTable *)table updateHeaderController:(TGLocationMapHeaderController *)controller
{
    __weak TGLocationController *weakSelf = self;
    controller.currentLocationPressed = ^
    {
        __strong TGLocationController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        TGBridgeLocationMediaAttachment *location = [[TGBridgeLocationMediaAttachment alloc] init];
        location.latitude = strongSelf->_currentLocation.coordinate.latitude;
        location.longitude = strongSelf->_currentLocation.coordinate.longitude;
        
        [strongSelf dismissController];
        
        if (strongSelf->_context.completionBlock != nil)
            strongSelf->_context.completionBlock(location);
    };
    [controller updateWithLocation:_currentLocation];
}

- (NSUInteger)numberOfRowsInTable:(WKInterfaceTable *)table section:(NSUInteger)section
{
    return _venueModels.count;
}

- (Class)table:(WKInterfaceTable *)table rowControllerClassAtIndexPath:(NSIndexPath *)indexPath
{
    return [TGLocationVenueRowController class];
}

- (void)table:(WKInterfaceTable *)table updateRowController:(TGLocationVenueRowController *)controller forIndexPath:(TGIndexPath *)indexPath
{
    [controller updateWithLocationVenue:_venueModels[indexPath.row]];
}

- (void)table:(WKInterfaceTable *)table didSelectRowAtIndexPath:(TGIndexPath *)indexPath
{
    [self dismissController];
    
    if (_context.completionBlock != nil)
        _context.completionBlock([_venueModels[indexPath.row] locationAttachment]);
}

+ (NSString *)identifier
{
    return TGLocationControllerIdentifier;
}

@end
