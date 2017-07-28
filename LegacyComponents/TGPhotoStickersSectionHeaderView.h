#import <UIKit/UIKit.h>

@interface TGPhotoStickersSectionHeaderView : UIView

@property (nonatomic) NSInteger index;

- (void)setTitle:(NSString *)title;
- (void)setTextColor:(UIColor *)color;

@end

extern const CGFloat TGPhotoStickersSectionHeaderHeight;