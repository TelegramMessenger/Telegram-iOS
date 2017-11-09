#import "TGRemoteImageView.h"

@interface TGLetteredAvatarView : TGRemoteImageView

- (void)setSingleFontSize:(CGFloat)singleFontSize doubleFontSize:(CGFloat)doubleFontSize useBoldFont:(bool)useBoldFont;

- (void)setFirstName:(NSString *)firstName lastName:(NSString *)lastName;
- (void)setTitle:(NSString *)title;

- (void)setTitleNeedsDisplay;

- (void)loadUserPlaceholderWithSize:(CGSize)size uid:(int)uid firstName:(NSString *)firstName lastName:(NSString *)lastName placeholder:(UIImage *)placeholder;
- (void)loadGroupPlaceholderWithSize:(CGSize)size conversationId:(int64_t)conversationId title:(NSString *)title placeholder:(UIImage *)placeholder;
- (void)loadSavedMessagesWithSize:(CGSize)size placeholder:(UIImage *)placeholder;

@end
