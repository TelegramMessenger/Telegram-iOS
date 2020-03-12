#import <MapKit/MapKit.h>
#import <SSignalKit/SSignalKit.h>

@class TGLocationMediaAttachment;
@class TGUser;

@interface TGLocationPickerAnnotation: NSObject <MKAnnotation>

@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@property (nonatomic, strong) id peer;

- (instancetype)initWithCoordinate:(CLLocationCoordinate2D)coordinate;

@end


@interface TGLocationAnnotation : NSObject <MKAnnotation>

@property (nonatomic, readonly) TGLocationMediaAttachment *location;
@property (nonatomic, readonly) bool isLiveLocation;
@property (nonatomic, strong) id peer;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;
@property (nonatomic, assign) int32_t messageId;
@property (nonatomic, assign) bool isOwn;
@property (nonatomic, assign) bool hasSession;
@property (nonatomic, assign) bool isExpired;

- (instancetype)initWithLocation:(TGLocationMediaAttachment *)location;
- (instancetype)initWithLocation:(TGLocationMediaAttachment *)location color:(UIColor *)color;

@end
