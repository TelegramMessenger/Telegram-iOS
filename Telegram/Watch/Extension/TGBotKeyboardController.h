#import "TGInterfaceController.h"

@class TGBridgeBotReplyMarkup;

@interface TGBotKeyboardControllerContext : NSObject <TGInterfaceContext>

@property (nonatomic, strong) TGBridgeBotReplyMarkup *replyMarkup;
@property (nonatomic, copy) void (^completionBlock)(NSString *command);

@end


@interface TGBotKeyboardController : TGInterfaceController

@property (nonatomic, weak) IBOutlet WKInterfaceTable *table;

@end
