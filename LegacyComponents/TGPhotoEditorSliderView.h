#import <UIKit/UIKit.h>

@interface TGPhotoEditorSliderView : UIControl

@property (nonatomic, copy) void(^interactionBegan)(void);
@property (nonatomic, copy) void(^interactionEnded)(void);
@property (nonatomic, copy) void(^reset)(void);

@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;

@property (nonatomic, assign) CGFloat minimumValue;
@property (nonatomic, assign) CGFloat maximumValue;

@property (nonatomic, assign) CGFloat startValue;
@property (nonatomic, assign) CGFloat value;

@property (nonatomic, readonly) bool knobStartedDragging;

@property (nonatomic, assign) CGFloat knobPadding;
@property (nonatomic, assign) CGFloat lineSize;
@property (nonatomic, strong) UIColor *backColor;
@property (nonatomic, strong) UIColor *trackColor;
@property (nonatomic, assign) CGFloat trackCornerRadius;
@property (nonatomic, assign) bool bordered;

@property (nonatomic, strong) UIImage *knobImage;

@property (nonatomic, assign) NSInteger positionsCount;
@property (nonatomic, assign) CGFloat dotSize;

- (void)setValue:(CGFloat)value animated:(BOOL)animated;

@end

extern const CGFloat TGPhotoEditorSliderViewMargin;
