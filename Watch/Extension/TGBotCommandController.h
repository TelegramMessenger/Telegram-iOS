#import "TGInterfaceController.h"

@class SSignal;
@class TGBridgeContext;

@interface TGBotCommandControllerContext : NSObject <TGInterfaceContext>

@property (nonatomic, strong) TGBridgeContext *context;
@property (nonatomic, strong) SSignal *commandListSignal;
@property (nonatomic, copy) void (^completionBlock)(NSString *command);

@end

@interface TGBotCommandController : TGInterfaceController

@property (nonatomic, weak) IBOutlet WKInterfaceTable *table;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *activityIndicator;

@end

extern NSString *const TGBotCommandUserKey;
extern NSString *const TGBotCommandListKey;