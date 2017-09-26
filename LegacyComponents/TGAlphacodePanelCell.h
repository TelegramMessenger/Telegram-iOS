#import <LegacyComponents/TGModernConversationAssociatedInputPanel.h>

extern NSString *const TGAlphacodePanelCellKind;

@interface TGAlphacodePanelCell : UITableViewCell

- (instancetype)initWithStyle:(TGModernConversationAssociatedInputPanelStyle)style;
- (void)setEmoji:(NSString *)emoji label:(NSString *)label;

@end
