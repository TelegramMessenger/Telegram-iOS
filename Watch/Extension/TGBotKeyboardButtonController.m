#import "TGBotKeyboardButtonController.h"
#import "TGBridgeBotReplyMarkup.h"

NSString *const TGBotKeyboardButtonRowIdentifier = @"TGBotKeyboardButton";

@implementation TGBotKeyboardButtonController

- (void)updateWithButton:(TGBridgeBotReplyMarkupButton *)button
{
    self.textLabel.text = button.text;
}

+ (NSString *)identifier
{
    return TGBotKeyboardButtonRowIdentifier;
}

@end
