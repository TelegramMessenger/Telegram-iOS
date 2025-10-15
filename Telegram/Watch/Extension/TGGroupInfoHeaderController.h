#import "WKInterfaceTable+TGDataDrivenTable.h"

@class TGBridgeChat;
@class TGBridgeContext;

@interface TGGroupInfoHeaderController : TGTableRowController

@property (nonatomic, weak) IBOutlet WKInterfaceButton *avatarButton;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *avatarGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *avatarInitialsLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *nameLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *participantsLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *onlineLabel;
- (IBAction)avatarPressedAction;

@property (nonatomic, copy) void (^avatarPressed)(void);

- (void)updateWithGroupChat:(TGBridgeChat *)chat users:(NSDictionary *)users context:(TGBridgeContext *)context;

@end
