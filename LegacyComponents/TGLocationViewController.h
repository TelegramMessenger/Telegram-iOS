#import <LegacyComponents/LegacyComponentsContext.h>
#import <LegacyComponents/TGLocationMapViewController.h>

#import <CoreLocation/CoreLocation.h>

@class TGLocationMediaAttachment;
@class TGVenueAttachment;
@class TGMenuSheetController;
@class TGMessage;
@class TGUser;

@interface TGLiveLocationEntry : NSObject

@property (nonatomic, strong, readonly) TGMessage *message;
@property (nonatomic, strong, readonly) id peer;
@property (nonatomic, readonly) bool isOwn;
@property (nonatomic, readonly) bool isExpired;

- (instancetype)initWithMessage:(TGMessage *)message peer:(id)peer isOwn:(bool)isOwn isExpired:(bool)isExpired;
- (instancetype)initWithMessage:(TGMessage *)message peer:(id)peer;

- (int64_t)peerId;

@end

@interface TGLocationViewController : TGLocationMapViewController;

@property (nonatomic, assign) bool modalMode;
@property (nonatomic, assign) bool previewMode;

@property (nonatomic, assign) bool allowLiveLocationSharing;
@property (nonatomic, assign) bool zoomToFitAllLocationsOnScreen;

@property (nonatomic, copy) bool (^presentShareMenu)(TGMenuSheetController *, CLLocationCoordinate2D);
@property (nonatomic, copy) bool (^presentOpenInMenu)(TGLocationViewController *, TGLocationMediaAttachment *, bool, void (^)(TGMenuSheetController *));
@property (nonatomic, copy) void (^shareAction)(NSArray *peerIds, NSString *caption);
@property (nonatomic, copy) void (^calloutPressed)(void);

@property (nonatomic, readonly) UIButton *directionsButton;

@property (nonatomic, copy) SSignal *(^remainingTimeForMessage)(TGMessage *message);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context liveLocation:(TGLiveLocationEntry *)liveLocation;
- (instancetype)initWithContext:(id<LegacyComponentsContext>)context locationAttachment:(TGLocationMediaAttachment *)locationAttachment peer:(id)peer;
- (instancetype)initWithContext:(id<LegacyComponentsContext>)context message:(TGMessage *)message peer:(id)peer;

- (void)setLiveLocationsSignal:(SSignal *)signal;
- (void)setFrequentUpdatesHandle:(id<SDisposable>)disposable;

@end
