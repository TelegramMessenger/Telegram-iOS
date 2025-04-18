#import "WKInterfaceTable+TGDataDrivenTable.h"

@class TGBridgeContext;
@class TGBridgeUser;
@class TGBridgeChat;

@interface TGUserInfoHeaderController : TGTableRowController

@property (nonatomic, weak) IBOutlet WKInterfaceButton *avatarButton;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *avatarGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *avatarInitialsLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *avatarVerified;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *nameLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *lastSeenLabel;
- (IBAction)avatarPressedAction;

@property (nonatomic, copy) void (^avatarPressed)(void);

- (void)updateWithUser:(TGBridgeUser *)user context:(TGBridgeContext *)context;
- (void)updateWithChannel:(TGBridgeChat *)channel;

@end
