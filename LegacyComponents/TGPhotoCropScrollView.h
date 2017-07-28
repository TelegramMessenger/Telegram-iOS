#import <UIKit/UIKit.h>

@interface TGPhotoCropScrollView : UIView

@property (nonatomic, assign) CGSize contentSize;
@property (nonatomic, assign) CGFloat contentRotation;
@property (nonatomic, strong) UIView *contentView;

@property (nonatomic, assign) CGFloat maximumZoomScale;
@property (nonatomic, readonly) CGFloat minimumZoomScale;

@property (nonatomic, readonly) CGAffineTransform cropTransform;

@property (nonatomic, readonly) CGRect zoomedRect;
@property (nonatomic, readonly) CGRect availableRect;

@property (nonatomic, weak) UIImageView *imageView;

@property (nonatomic, readonly) bool isTracking;
@property (nonatomic, readonly) bool animating;

@property (nonatomic, copy) bool(^shouldBeginChanging)(void);
@property (nonatomic, copy) void(^didBeginChanging)(void);
@property (nonatomic, copy) void(^didEndChanging)(void);

- (void)setContentRotation:(CGFloat)contentRotation maximize:(bool)maximize resetting:(bool)resetting;
- (void)setContentMirrored:(bool)mirrored;
- (void)translateContentViewWithOffset:(CGPoint)offset;

- (UIView *)setSnapshotViewEnabled:(bool)enabled;
- (void)setPaintingImage:(UIImage *)image;

- (void)zoomToRect:(CGRect)rect withFrame:(CGRect)frame animated:(bool)animated completion:(void (^)(void))completion;
- (void)fitContentInsideBoundsAllowScale:(bool)allowScale animated:(bool)animated completion:(void (^)(void))completion;
- (void)fitContentInsideBoundsAllowScale:(bool)allowScale maximize:(bool)maximize animated:(bool)animated completion:(void (^)(void))completion;

- (void)storeRotationStartValues;
- (void)resetRotationStartValues;

- (void)reset;
- (void)resetAnimatedWithFrame:(CGRect)frame completion:(void (^)(void))completion;

@end
