#import "TGInterfaceController.h"

@interface TGComposeController : TGInterfaceController

@property (nonatomic, weak) IBOutlet WKInterfaceLabel *recipientLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *messageLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceButton *stickerButton;
@property (nonatomic, weak) IBOutlet WKInterfaceButton *locationButton;

@property (nonatomic, weak) IBOutlet WKInterfaceButton *addContactButton;
@property (nonatomic, weak) IBOutlet WKInterfaceButton *createMessageButton;
@property (nonatomic, weak) IBOutlet WKInterfaceButton *sendButton;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *bottomGroup;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *stickerGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *locationIcon;

- (IBAction)addContactPressedAction;
- (IBAction)createMessagePressedAction;
- (IBAction)stickerPressedAction;
- (IBAction)locationPressedAction;
- (IBAction)sendPressedAction;

@end
