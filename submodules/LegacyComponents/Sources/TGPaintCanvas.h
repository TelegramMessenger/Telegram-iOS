#import <UIKit/UIKit.h>

@class TGPainting;
@class TGPaintBrush;
@class TGPaintState;

@interface TGPaintCanvas : UIView

@property (nonatomic, strong) TGPainting *painting;
@property (nonatomic, readonly) TGPaintState *state;

@property (nonatomic, assign) CGRect cropRect;
@property (nonatomic, assign) UIImageOrientation cropOrientation;
@property (nonatomic, assign) CGSize originalSize;

@property (nonatomic, copy) bool (^shouldDrawOnSingleTap)(void);

@property (nonatomic, copy) bool (^shouldDraw)(void);
@property (nonatomic, copy) void (^strokeBegan)(void);
@property (nonatomic, copy) void (^strokeCommited)(void);
@property (nonatomic, copy) UIView *(^hitTest)(CGPoint point, UIEvent *event);
@property (nonatomic, copy) bool (^pointInsideContainer)(CGPoint point);

@property (nonatomic, readonly) bool isTracking;

- (void)draw;

- (void)setBrush:(TGPaintBrush *)brush;
- (void)setBrushWeight:(CGFloat)brushWeight;
- (void)setBrushColor:(UIColor *)color;
- (void)setEraser:(bool)eraser;

@end
