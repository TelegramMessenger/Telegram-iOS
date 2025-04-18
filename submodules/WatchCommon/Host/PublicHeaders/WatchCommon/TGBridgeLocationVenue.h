#import <CoreLocation/CoreLocation.h>

@class TGBridgeLocationMediaAttachment;

@interface TGBridgeLocationVenue : NSObject <NSCoding>

@property (nonatomic) CLLocationCoordinate2D coordinate;
@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, strong) NSString *provider;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *address;

- (TGBridgeLocationMediaAttachment *)locationAttachment;

@end
