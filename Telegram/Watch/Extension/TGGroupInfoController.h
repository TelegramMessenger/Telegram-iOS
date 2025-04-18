#import "TGInterfaceController.h"

@class TGBridgeContext;
@class TGBridgeChat;

@interface TGGroupInfoControllerContext : NSObject <TGInterfaceContext>

@property (nonatomic, strong) TGBridgeContext *context;
@property (nonatomic, readonly) TGBridgeChat *groupChat;

- (instancetype)initWithGroupChat:(TGBridgeChat *)groupChat;

@end

@interface TGGroupInfoController : TGInterfaceController

@property (nonatomic, weak) IBOutlet WKInterfaceTable *table;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *activityIndicator;

@end
