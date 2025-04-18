#import "TGLocationMapHeaderController.h"
#import "TGWatchCommon.h"
#import "TGLocationUtils.h"

NSString *const TGLocationMapHeaderIdentifier = @"TGLocationMapHeader";

@interface TGLocationMapHeaderController ()
{
    CLLocation *_location;
}
@end

@implementation TGLocationMapHeaderController

- (void)updateWithLocation:(CLLocation *)location
{
    self.currentLocationLabel.text = TGLocalized(@"Watch.Location.Current");
    
    if (_location == nil || [_location distanceFromLocation:location] > 50)
    {
        CLLocationDegrees latitude = [TGLocationUtils adjustGMapLatitude:location.coordinate.latitude withPixelOffset:-20 zoom:15];
        [self.map setRegion:MKCoordinateRegionMake(CLLocationCoordinate2DMake(latitude, location.coordinate.longitude), MKCoordinateSpanMake(0.003, 0.003))];
        
        if (_location != nil)
            [self.map removeAllAnnotations];
        
        [self.map addAnnotation:location.coordinate withPinColor:WKInterfaceMapPinColorRed];
        
        _location = location;
    }
}

- (void)currentLocationPressedAction
{
    if (self.currentLocationPressed != nil)
        self.currentLocationPressed();
}

+ (NSString *)identifier
{
    return TGLocationMapHeaderIdentifier;
}

@end
