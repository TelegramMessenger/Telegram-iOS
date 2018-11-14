#import "WKInterfaceTable+TGDataDrivenTable.h"

typedef NS_OPTIONS(NSUInteger, TGConversationFooterOptions) {
    TGConversationFooterOptionsSendMessage = 1 << 0,
    TGConversationFooterOptionsUnblock = 1 << 1,
    TGConversationFooterOptionsStartBot = 1 << 2,
    TGConversationFooterOptionsRestartBot = 1 << 3,
    TGConversationFooterOptionsInactive = 1 << 4,
    TGConversationFooterOptionsBotCommands = 1 << 5,
    TGConversationFooterOptionsBotKeyboard = 1 << 6,
    TGConversationFooterOptionsVoice = 1 << 7
};

@interface TGConversationFooterController : TGTableRowController

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *attachmentsGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *commandsIcon;
@property (nonatomic, weak) IBOutlet WKInterfaceButton *commandsButton;
@property (nonatomic, weak) IBOutlet WKInterfaceButton *stickerButton;
@property (nonatomic, weak) IBOutlet WKInterfaceButton *locationButton;
@property (nonatomic, weak) IBOutlet WKInterfaceButton *voiceButton;
@property (nonatomic, weak) IBOutlet WKInterfaceButton *bottomButton;

- (IBAction)commandsButtonPressedAction;
- (IBAction)stickerButtonPressedAction;
- (IBAction)locationButtonPressedAction;
- (IBAction)voiceButtonPressedAction;
- (IBAction)bottomButtonPressedAction;

@property (nonatomic, assign) TGConversationFooterOptions options;
- (void)setOptions:(TGConversationFooterOptions)options animated:(bool)animated;

@property (nonatomic, copy) void (^commandsPressed)(void);
@property (nonatomic, copy) void (^stickerPressed)(void);
@property (nonatomic, copy) void (^locationPressed)(void);
@property (nonatomic, copy) void (^voicePressed)(void);
@property (nonatomic, copy) void (^replyPressed)(void);
@property (nonatomic, copy) void (^unblockPressed)(void);
@property (nonatomic, copy) void (^startPressed)(void);
@property (nonatomic, copy) void (^restartPressed)(void);

@property (nonatomic, copy) void (^animate)(void (^)(void));

@end
