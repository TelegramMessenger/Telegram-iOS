#import "TGNeoRowController.h"

@class TGBridgeContext;
@class TGBridgeMessage;
@class TGChatInfo;

@interface TGNeoConversationStaticRowController : TGNeoRowController

- (void)updateWithChatInfo:(TGChatInfo *)chatInfo;

@end
