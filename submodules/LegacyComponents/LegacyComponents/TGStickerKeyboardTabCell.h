#import <UIKit/UIKit.h>

#import "TGStickerKeyboardTabPanel.h"

@class TGDocumentMediaAttachment;

@interface TGStickerKeyboardTabCell : UICollectionViewCell

- (void)setFavorite;
- (void)setRecent;
- (void)setNone;
- (void)setDocumentMedia:(TGDocumentMediaAttachment *)documentMedia;
- (void)setUrl:(NSString *)avatarUrl peerId:(int64_t)peerId title:(NSString *)title;

- (void)setStyle:(TGStickerKeyboardViewStyle)style;
- (void)setPallete:(TGStickerKeyboardPallete *)pallete;

- (void)setInnerAlpha:(CGFloat)innerAlpha;

@end
