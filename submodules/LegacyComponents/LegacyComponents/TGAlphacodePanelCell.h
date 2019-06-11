#import <LegacyComponents/TGModernConversationAssociatedInputPanel.h>

extern NSString *const TGAlphacodePanelCellKind;

@class TGConversationAssociatedInputPanelPallete;

@interface TGAlphacodePanelCell : UITableViewCell

@property (nonatomic, strong) TGConversationAssociatedInputPanelPallete *pallete;

- (instancetype)initWithStyle:(TGModernConversationAssociatedInputPanelStyle)style;
- (void)setEmoji:(NSString *)emoji label:(NSString *)label;

@end
