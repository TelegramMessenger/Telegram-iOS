#import <LegacyComponents/TGModernConversationAssociatedInputPanel.h>

@class TGConversationAssociatedInputPanelPallete;

@interface TGHashtagPanelCell : UITableViewCell

@property (nonatomic, strong) TGConversationAssociatedInputPanelPallete *pallete;

- (instancetype)initWithStyle:(TGModernConversationAssociatedInputPanelStyle)style;

- (void)setDisplaySeparator:(bool)displaySeparator;
- (void)setHashtag:(NSString *)hashtag;

@end

extern NSString *const TGHashtagPanelCellKind;
