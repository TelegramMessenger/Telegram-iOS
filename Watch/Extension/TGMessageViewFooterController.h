#import "WKInterfaceTable+TGDataDrivenTable.h"

@class TGBridgeMessage;

@interface TGMessageViewFooterController : TGTableRowController

@property (nonatomic, weak) IBOutlet WKInterfaceLabel *dateLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *timeLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *statusGroup;

@property (nonatomic, weak) IBOutlet WKInterfaceButton *forwardButton;
@property (nonatomic, weak) IBOutlet WKInterfaceButton *replyButton;
@property (nonatomic, weak) IBOutlet WKInterfaceButton *viewButton;

@property (nonatomic, weak) IBOutlet WKInterfaceLabel *forwardLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *replyLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *viewLabel;

- (IBAction)forwardButtonPressedAction;
- (IBAction)replyButtonPressedAction;
- (IBAction)viewButtonPressedAction;

@property (nonatomic, copy) void (^forwardPressed)(void);
@property (nonatomic, copy) void (^replyPressed)(void);
@property (nonatomic, copy) void (^viewPressed)(void);

- (void)updateWithMessage:(TGBridgeMessage *)message channel:(bool)channel;

@end
