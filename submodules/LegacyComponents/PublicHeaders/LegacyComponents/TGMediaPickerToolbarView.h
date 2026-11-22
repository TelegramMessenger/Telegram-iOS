#import <UIKit/UIKit.h>

@class TGMediaAssetsPallete;

@interface TGMediaPickerToolbarView : UIView

@property (nonatomic, assign) UIEdgeInsets safeAreaInset;

@property (nonatomic, strong) UIImage *attributionImage;
@property (nonatomic, strong) NSString *leftButtonTitle;
@property (nonatomic, strong) NSString *rightButtonTitle;

@property (nonatomic, readonly) UIButton *centerButton;
@property (nonatomic, strong) UIImage *centerButtonImage;
@property (nonatomic, strong) UIImage *centerButtonSelectedImage;

@property (nonatomic, copy) void (^leftPressed)(void);
@property (nonatomic, copy) void (^rightPressed)(void);
@property (nonatomic, copy) void (^centerPressed)(void);

- (void)setPallete:(TGMediaAssetsPallete *)pallete;

- (void)setRightButtonHidden:(bool)hidden;
- (void)setRightButtonEnabled:(bool)enabled animated:(bool)animated;
- (void)setSelectedCount:(NSInteger)count animated:(bool)animated;

- (void)setCenterButtonSelected:(bool)selected;
- (void)setCenterButtonHidden:(bool)hidden animated:(bool)animated;

@end

extern const CGFloat TGMediaPickerToolbarHeight;
