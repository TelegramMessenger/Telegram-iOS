#import "TGInterfaceController.h"

@class TGBridgeContext;
@class TGBridgeUser;
@class TGBridgeChat;

@interface TGUserInfoControllerContext : NSObject <TGInterfaceContext>

@property (nonatomic, strong) TGBridgeContext *context;
@property (nonatomic, readonly) TGBridgeUser *user;
@property (nonatomic, readonly) int32_t userId;

@property (nonatomic, readonly) TGBridgeChat *channel;

@property (nonatomic, assign) bool disallowCompose;

- (instancetype)initWithUser:(TGBridgeUser *)user;
- (instancetype)initWithUserId:(int32_t)userId;

- (instancetype)initWithChannel:(TGBridgeChat *)channel;

@end

@interface TGUserInfoController : TGInterfaceController

@property (nonatomic, weak) IBOutlet WKInterfaceTable *table;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *activityIndicator;

@end
