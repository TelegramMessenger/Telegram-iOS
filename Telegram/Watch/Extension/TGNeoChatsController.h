#import "TGInterfaceController.h"
#import "TGBridgeStateSignal.h"

@class TGBridgeContext;
@class TGBridgeChat;

@interface TGNeoChatsControllerContext : NSObject <TGInterfaceContext>

@property (nonatomic, strong) NSArray *initialChats;
@property (nonatomic, strong) TGBridgeContext *context;
@property (nonatomic, copy) void (^completionBlock)(TGBridgeChat *peer);

@end


@interface TGNeoChatsController : TGInterfaceController

@property (nonatomic, weak) IBOutlet WKInterfaceTable *table;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *activityIndicator;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *authAlertGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *authAlertImage;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *authAlertImageGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *authAlertLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *authAlertDescLabel;

@property (nonatomic, readonly) NSArray *chats;

- (void)popAllControllers;
- (void)resetLocalization;

+ (NSString *)stringForSyncState:(TGBridgeSynchronizationStateValue)value;

@end

extern NSString *const TGSynchronizationStateNotification;
extern NSString *const TGSynchronizationStateKey;

extern NSString *const TGContextNotification;
extern NSString *const TGContextNotificationKey;
