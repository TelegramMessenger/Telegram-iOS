#import <UIKit/UIKit.h>

@interface TGModernGalleryImageItemContainerView : UIView

@property (nonatomic, copy) UIView *(^contentView)(void);

@end
