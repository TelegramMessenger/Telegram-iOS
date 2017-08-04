#import <LegacyComponents/LegacyComponentsContext.h>
#import <LegacyComponents/TGViewController.h>

#import <CoreLocation/CoreLocation.h>

@class TGLocationMediaAttachment;
@class TGVenueAttachment;
@class TGMenuSheetController;

@interface TGLocationViewController : TGViewController

@property (nonatomic, assign) bool previewMode;

@property (nonatomic, copy) bool (^presentShareMenu)(TGMenuSheetController *, CLLocationCoordinate2D);
@property (nonatomic, copy) bool (^presentOpenInMenu)(TGLocationViewController *, TGLocationMediaAttachment *, bool, void (^)(TGMenuSheetController *));
@property (nonatomic, copy) void (^shareAction)(NSArray *peerIds, NSString *caption);
@property (nonatomic, copy) void (^calloutPressed)(void);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context coordinate:(CLLocationCoordinate2D)coordinate venue:(TGVenueAttachment *)venue peer:(id)peer;
- (instancetype)initWithContext:(id<LegacyComponentsContext>)context locationAttachment:(TGLocationMediaAttachment *)locationAttachment peer:(id)peer;

@end
