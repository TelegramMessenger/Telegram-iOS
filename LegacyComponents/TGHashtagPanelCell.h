#import <LegacyComponents/TGModernConversationAssociatedInputPanel.h>

@interface TGHashtagPanelCell : UITableViewCell

- (instancetype)initWithStyle:(TGModernConversationAssociatedInputPanelStyle)style;

- (void)setDisplaySeparator:(bool)displaySeparator;
- (void)setHashtag:(NSString *)hashtag;

@end

extern NSString *const TGHashtagPanelCellKind;
