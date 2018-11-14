#import "WKInterfaceTable+TGDataDrivenTable.h"

@class TGBridgeUser;
@class TGBridgeChat;
@class TGBridgeBotCommandInfo;
@class TGBridgeContext;

@interface TGUserRowController : TGTableRowController

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *avatarGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *avatarInitialsLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *nameLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *lastSeenLabel;

- (void)updateWithUser:(TGBridgeUser *)user context:(TGBridgeContext *)context;
- (void)updateWithChannel:(TGBridgeChat *)channel context:(TGBridgeContext *)context;
- (void)updateWithBotCommandInfo:(TGBridgeBotCommandInfo *)commandInfo botUser:(TGBridgeUser *)botUser context:(TGBridgeContext *)context;

@end
