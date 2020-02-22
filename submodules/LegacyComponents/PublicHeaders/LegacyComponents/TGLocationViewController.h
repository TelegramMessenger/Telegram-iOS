#import <LegacyComponents/LegacyComponentsContext.h>
#import <LegacyComponents/TGLocationMapViewController.h>

#import <CoreLocation/CoreLocation.h>

@class TGLocationMediaAttachment;
@class TGVenueAttachment;
@class TGMenuSheetController;
@class TGMessage;
@class TGUser;

@interface TGLiveLocation : NSObject

@property (nonatomic, strong, readonly) TGMessage *message;
@property (nonatomic, strong, readonly) id peer;
@property (nonatomic, readonly) bool hasOwnSession;
@property (nonatomic, readonly) bool isOwnLocation;
@property (nonatomic, readonly) bool isExpired;

- (instancetype)initWithMessage:(TGMessage *)message peer:(id)peer hasOwnSession:(bool)hasOwnSession isOwnLocation:(bool)isOwnLocation isExpired:(bool)isExpired;
- (instancetype)initWithMessage:(TGMessage *)message peer:(id)peer;

- (int64_t)peerId;

@end

@interface TGLocationViewController : TGLocationMapViewController;

@property (nonatomic, assign) bool modalMode;
@property (nonatomic, assign) bool previewMode;

@property (nonatomic, assign) bool allowLiveLocationSharing;
@property (nonatomic, assign) bool zoomToFitAllLocationsOnScreen;


@property (nonatomic, copy) void (^presentActionsMenu)(TGLocationMediaAttachment *, bool);
@property (nonatomic, copy) bool (^presentShareMenu)(TGMenuSheetController *, CLLocationCoordinate2D);
@property (nonatomic, copy) bool (^presentOpenInMenu)(TGLocationViewController *, TGLocationMediaAttachment *, bool, void (^)(TGMenuSheetController *));
@property (nonatomic, copy) void (^shareAction)(NSArray *peerIds, NSString *caption);

@property (nonatomic, copy) void (^openLocation)(TGMessage *message);
@property (nonatomic, copy) void (^onViewDidAppear)(void);

@property (nonatomic, copy) void (^updateRightBarItem)(UIBarButtonItem *, bool, bool);

@property (nonatomic, readonly) UIButton *directionsButton;

@property (nonatomic, copy) SSignal *(^remainingTimeForMessage)(TGMessage *message);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context liveLocation:(TGLiveLocation *)liveLocation;
- (instancetype)initWithContext:(id<LegacyComponentsContext>)context locationAttachment:(TGLocationMediaAttachment *)locationAttachment peer:(id)peer color:(UIColor *)color;
- (instancetype)initWithContext:(id<LegacyComponentsContext>)context message:(TGMessage *)message peer:(id)peer color:(UIColor *)color;

- (void)actionsButtonPressed;

- (void)setLiveLocationsSignal:(SSignal *)signal;
- (void)setFrequentUpdatesHandle:(id<SDisposable>)disposable;

@end
