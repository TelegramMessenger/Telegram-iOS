#import "WKInterfaceTable+TGDataDrivenTable.h"

@class TGBridgeBotReplyMarkupButton;

@interface TGBotKeyboardButtonController : TGTableRowController

@property (nonatomic, weak) IBOutlet WKInterfaceLabel *textLabel;

- (void)updateWithButton:(TGBridgeBotReplyMarkupButton *)button;

@end
