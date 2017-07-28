#import <UIKit/UIKit.h>

@interface TGMediaPickerToolbarView : UIView

@property (nonatomic, strong) UIImage *attributionImage;
@property (nonatomic, strong) NSString *leftButtonTitle;
@property (nonatomic, strong) NSString *rightButtonTitle;

@property (nonatomic, copy) void (^leftPressed)(void);
@property (nonatomic, copy) void (^rightPressed)(void);

- (void)setRightButtonHidden:(bool)hidden;
- (void)setRightButtonEnabled:(bool)enabled animated:(bool)animated;
- (void)setSelectedCount:(NSInteger)count animated:(bool)animated;

@end

extern const CGFloat TGMediaPickerToolbarHeight;