#import "TGConversationFooterController.h"
#import "TGWatchCommon.h"

NSString *const TGConversationFooterIdentifier = @"TGConversationFooter";

@implementation TGConversationFooterController

- (void)setOptions:(TGConversationFooterOptions)options
{
    [self setOptions:options animated:false];
}

- (void)setOptions:(TGConversationFooterOptions)options animated:(bool)animated
{
    void (^changeBlock)() = ^
    {
        if (options == _options)
            return;
        
        _options = options;
        
        bool isSendMessage = options & TGConversationFooterOptionsSendMessage;
        bool isStartBot = options & TGConversationFooterOptionsStartBot;
        bool isRestartBot = options & TGConversationFooterOptionsRestartBot;
        bool isUnblock = options & TGConversationFooterOptionsUnblock;
        bool isInactive = options & TGConversationFooterOptionsInactive;
        
        bool hasCommandsButton = options & TGConversationFooterOptionsBotCommands;
        bool hasKeyboardButton = options & TGConversationFooterOptionsBotKeyboard;
        bool hasVoiceButton = options & TGConversationFooterOptionsVoice;
        
        if (isSendMessage)
        {
            self.attachmentsGroup.hidden = false;
            self.bottomButton.hidden = false;
            self.bottomButton.title = TGLocalized(@"Watch.Conversation.Reply");
            
            NSInteger buttonCount = 2;
            CGFloat buttonWidth = 0.5f;
            if (hasCommandsButton || hasKeyboardButton)
                buttonCount += 1;
            if (hasVoiceButton)
                buttonCount += 1;
            
            buttonWidth = 1.0f / buttonCount;
            
            bool commandButtonHidden = (!hasCommandsButton && !hasKeyboardButton);
            [self.commandsButton setHidden:commandButtonHidden];
            [self.voiceButton setHidden:!hasVoiceButton];
            
            if (!commandButtonHidden)
                [self.commandsIcon setImageNamed:hasCommandsButton ? @"BotCommandIcon": @"BotKeyboardIcon"];
            
            [self.commandsButton setRelativeWidth:commandButtonHidden ? 0.0 : buttonWidth withAdjustment:0];
            [self.voiceButton setRelativeWidth:!hasVoiceButton ? 0.0 : buttonWidth withAdjustment:0];
            [self.stickerButton setRelativeWidth:buttonWidth withAdjustment:0];
            [self.locationButton setRelativeWidth:buttonWidth withAdjustment:0];
        }
        else if (isStartBot)
        {
            self.attachmentsGroup.hidden = true;
            self.bottomButton.hidden = false;
            self.bottomButton.title = TGLocalized(@"Bot.Start");
        }
        else if (isRestartBot)
        {
            self.attachmentsGroup.hidden = true;
            self.bottomButton.hidden = false;
            self.bottomButton.title = TGLocalized(@"Watch.Bot.Restart");
        }
        else if (isUnblock)
        {
            self.attachmentsGroup.hidden = true;
            self.bottomButton.hidden = false;
            self.bottomButton.title = TGLocalized(@"Watch.Conversation.Unblock");
        }
        else if (isInactive)
        {
            self.attachmentsGroup.hidden = true;
            self.bottomButton.hidden = true;
        }
    };
    
    if (animated)
        self.animate(changeBlock);
    else
        changeBlock();
}

- (IBAction)commandsButtonPressedAction
{
    if (self.commandsPressed != nil)
        self.commandsPressed();
}

- (IBAction)stickerButtonPressedAction
{
    if (self.stickerPressed != nil)
        self.stickerPressed();
}

- (IBAction)locationButtonPressedAction
{
    if (self.locationPressed != nil)
        self.locationPressed();
}

- (IBAction)voiceButtonPressedAction
{
    if (self.voicePressed != nil)
        self.voicePressed();
}

- (IBAction)bottomButtonPressedAction
{
    bool isSendMessage = _options & TGConversationFooterOptionsSendMessage;
    bool isStartBot = _options & TGConversationFooterOptionsStartBot;
    bool isRestartBot = _options & TGConversationFooterOptionsRestartBot;
    bool isUnblock = _options & TGConversationFooterOptionsUnblock;
    
    if (isSendMessage)
    {
        if (self.replyPressed != nil)
            self.replyPressed();
    }
    else if (isStartBot)
    {
        if (self.startPressed != nil)
            self.startPressed();
    }
    else if (isRestartBot)
    {
        if (self.restartPressed != nil)
            self.restartPressed();
    }
    else if (isUnblock)
    {
        if (self.unblockPressed != nil)
            self.unblockPressed();
    }
}

#pragma mark -

+ (NSString *)identifier
{
    return TGConversationFooterIdentifier;
}

@end
