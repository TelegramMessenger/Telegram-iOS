#import <LegacyComponents/TGModernConversationAssociatedInputPanel.h>

@class TGUser;

@interface TGMentionPanelCell : UITableViewCell

@property (nonatomic, strong) TGUser *user;

- (instancetype)initWithStyle:(TGModernConversationAssociatedInputPanelStyle)style;

@end

extern NSString *const TGMentionPanelCellKind;
