#import <UIKit/UIKit.h>

#import "TGStickerKeyboardTabPanel.h"

@class TGDocumentMediaAttachment;

@interface TGStickerKeyboardTabCell : UICollectionViewCell

- (void)setFavorite;
- (void)setRecent;
- (void)setNone;
- (void)setDocumentMedia:(TGDocumentMediaAttachment *)documentMedia;
- (void)setUrl:(NSString *)url;

- (void)setStyle:(TGStickerKeyboardViewStyle)style;

- (void)setInnerAlpha:(CGFloat)innerAlpha;

@end
