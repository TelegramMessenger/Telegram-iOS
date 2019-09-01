#import <WatchCommonWatch/TGBridgeMediaAttachment.h>

@interface TGBridgeVenueAttachment : NSObject <NSCoding>

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *address;
@property (nonatomic, strong) NSString *provider;
@property (nonatomic, strong) NSString *venueId;

@end

@interface TGBridgeLocationMediaAttachment : TGBridgeMediaAttachment

@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;

@property (nonatomic, strong) TGBridgeVenueAttachment *venue;

@end
