#import "TGInterfaceController.h"

@class TGBridgeContext;
@class TGBridgeChat;
@class TGBridgeMessage;

@interface TGMessageViewControllerContext : NSObject <TGInterfaceContext>

@property (nonatomic, strong) TGBridgeContext *context;
@property (nonatomic, readonly) TGBridgeMessage *message;
@property (nonatomic, readonly) int64_t peerId;
@property (nonatomic, readonly) TGBridgeChat *channel;
@property (nonatomic, strong) NSDictionary *additionalPeers;

- (instancetype)initWithMessage:(TGBridgeMessage *)message peerId:(int64_t)peerId;
- (instancetype)initWithMessage:(TGBridgeMessage *)message channel:(TGBridgeChat *)channel;

@end

@interface TGMessageViewController : TGInterfaceController

@property (nonatomic, weak) IBOutlet WKInterfaceTable *table;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *activityIndicator;

@end
