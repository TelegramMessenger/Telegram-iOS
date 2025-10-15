#import <UIKit/UIKit.h>

@interface TGPhotoEditorButton : UIControl

@property (nonatomic, strong) UIImage *iconImage;
@property (nonatomic, assign) bool active;
@property (nonatomic, assign) bool disabled;
@property (nonatomic, assign) bool dontHighlightOnSelection;

- (void)setIconImage:(UIImage *)image activeIconImage:(UIImage *)activeIconImage;
- (void)setSelected:(BOOL)selected animated:(BOOL)animated;

@end
