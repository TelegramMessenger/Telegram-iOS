#import "WKInterfaceTable+TGDataDrivenTable.h"

@class TGBridgeMessage;
@class TGBridgeContext;

@interface TGMessageViewMessageRowController : TGTableRowController

@property (nonatomic, weak) IBOutlet WKInterfaceButton *forwardHeaderButton;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *forwardTitleLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *forwardFromLabel;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *replyHeaderGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *replyHeaderImageGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *replyAuthorNameLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *replyMessageTextLabel;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *mediaGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *activityIndicator;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *mapGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceMap *map;

@property (nonatomic, weak) IBOutlet WKInterfaceButton *playButton;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *durationGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *durationLabel;

@property (nonatomic, weak) IBOutlet WKInterfaceLabel *titleLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *subtitleLabel;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *fileGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *fileIconGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceButton *audioButton;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *audioIcon;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *venueIcon;

@property (nonatomic, weak) IBOutlet WKInterfaceButton *contactButton;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *avatarGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *avatarInitialsLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *nameLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *phoneLabel;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *stickerGroup;

@property (nonatomic, weak) IBOutlet WKInterfaceLabel *messageTextLabel;

@property (nonatomic, copy) void (^forwardPressed)(void);
@property (nonatomic, copy) void (^playPressed)(void);
@property (nonatomic, copy) void (^contactPressed)(void);

- (IBAction)forwardButtonPressedAction;
- (IBAction)playButtonPressedAction;
- (IBAction)contactButtonPressedAction;

- (void)setProcessingState:(bool)processing;

- (void)updateWithMessage:(TGBridgeMessage *)message context:(TGBridgeContext *)context additionalPeers:(NSDictionary *)additionalPeers;

@end
