#import <UIKit/UIKit.h>

@class TGPaintSwatch;

@interface TGPhotoPaintColorPicker : UIControl

@property (nonatomic, copy) void (^beganPicking)(void);
@property (nonatomic, copy) void (^valueChanged)(void);
@property (nonatomic, copy) void (^finishedPicking)(void);

@property (nonatomic, strong) TGPaintSwatch *swatch;
@property (nonatomic, assign) UIInterfaceOrientation orientation;

@end
