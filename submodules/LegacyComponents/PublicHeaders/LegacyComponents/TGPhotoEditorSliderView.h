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
@property (nonatomic, assign) int minimumUndottedValue;

@property (nonatomic, assign) CGFloat markValue;

@property (nonatomic, assign) bool displayEdges;
@property (nonatomic, assign) bool useLinesForPositions;

@property (nonatomic, readonly) bool knobStartedDragging;

@property (nonatomic) bool limitValueChangedToLatestState;

@property (nonatomic, assign) CGFloat knobPadding;
@property (nonatomic, assign) CGFloat lineSize;
@property (nonatomic, strong) UIColor *backColor;
@property (nonatomic, strong) UIColor *trackColor;
@property (nonatomic, strong) UIColor *startColor;
@property (nonatomic, assign) CGFloat trackCornerRadius;
@property (nonatomic, assign) bool bordered;

@property (nonatomic, strong) UIImage *knobImage;
@property (nonatomic, readonly) UIImageView *knobView;

@property (nonatomic, assign) bool disableSnapToPositions;
@property (nonatomic, assign) NSInteger positionsCount;
@property (nonatomic, assign) CGFloat dotSize;

@property (nonatomic, assign) bool enablePanHandling;

- (void)setValue:(CGFloat)value animated:(BOOL)animated;

@end

extern const CGFloat TGPhotoEditorSliderViewMargin;
