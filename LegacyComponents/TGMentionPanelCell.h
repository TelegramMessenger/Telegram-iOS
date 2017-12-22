#import <LegacyComponents/TGModernConversationAssociatedInputPanel.h>

@class TGUser;
@class TGConversationAssociatedInputPanelPallete;

@interface TGMentionPanelCell : UITableViewCell

@property (nonatomic, strong) TGUser *user;
@property (nonatomic, strong) TGConversationAssociatedInputPanelPallete *pallete;

- (instancetype)initWithStyle:(TGModernConversationAssociatedInputPanelStyle)style;

@end

extern NSString *const TGMentionPanelCellKind;
