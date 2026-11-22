#import "TGInterfaceController.h"

@class TGBridgeContext;
@class TGBridgeChat;

@interface TGNeoConversationControllerContext : NSObject <TGInterfaceContext>

@property (nonatomic, strong) TGBridgeContext *context;
@property (nonatomic, readonly) TGBridgeChat *chat;
@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, copy) void(^finished)(void);

- (instancetype)initWithChat:(TGBridgeChat *)chat;
- (instancetype)initWithPeerId:(int64_t)peerId;

@end

@interface TGNeoConversationController : TGInterfaceController

@property (nonatomic, weak) IBOutlet WKInterfaceTable *table;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *activityIndicator;

@end
