#import <MapKit/MapKit.h>

@interface TGLocationPickerAnnotation: NSObject <MKAnnotation>

@property (nonatomic, assign) CLLocationCoordinate2D coordinate;

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate;

@end


@interface TGLocationAnnotation : NSObject <MKAnnotation>

@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@property (nonatomic, strong) NSDictionary *userInfo;

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate;

@end
