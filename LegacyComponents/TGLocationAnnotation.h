#import <MapKit/MapKit.h>

@interface TGLocationAnnotation : NSObject <MKAnnotation>

@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, strong) NSDictionary *userInfo;

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate title:(NSString *)title;

@end
