#import <UIKit/UIKit.h>

@interface TGPhotoCropView : UIControl

@property (nonatomic, assign) UIInterfaceOrientation interfaceOrientation;

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, assign) UIImageOrientation cropOrientation;
@property (nonatomic, assign) CGRect cropRect;
@property (nonatomic, assign) CGFloat rotation;
@property (nonatomic, assign) bool mirrored;
@property (nonatomic, readonly) bool hasArbitraryRotation;
@property (nonatomic, readonly) bool isAspectRatioLocked;
@property (nonatomic, readonly) CGFloat lockedAspectRatio;

@property (nonatomic, readonly) bool isTracking;
@property (nonatomic, readonly) bool isAnimating;
@property (nonatomic, readonly) bool isAnimatingRotation;

@property (nonatomic, copy) void(^croppingChanged)(void);
@property (nonatomic, copy) void(^interactionBegan)(void);
@property (nonatomic, copy) void(^interactionEnded)(void);

- (instancetype)initWithOriginalSize:(CGSize)originalSize hasArbitraryRotation:(bool)hasArbitraryRotation;

- (void)setSnapshotImage:(UIImage *)snapshotImage;
- (void)setSnapshotView:(UIView *)snapshotView;
- (void)setPaintingImage:(UIImage *)paintingImage;
- (void)setEntitiesView:(UIView *)entitiesView;

- (void)animateTransitionIn;
- (void)animateTransitionOut;
- (void)transitionInFinishedAnimated:(bool)animated completion:(void (^)(void))completion;

- (void)performConfirmAnimated:(bool)animated;
- (void)performConfirmAnimated:(bool)animated updateInterface:(bool)updateInterface;

- (void)setRotation:(CGFloat)rotation animated:(bool)animated;
- (void)rotate90DegreesCCWAnimated:(bool)animated;

- (void)mirror;

- (void)setLockedAspectRatio:(CGFloat)aspectRatio performResize:(bool)performResize animated:(bool)animated;
- (void)unlockAspectRatio;
- (void)resetAnimated:(bool)animated;

- (UIView *)cropSnapshotView;
- (CGRect)cropRectFrameForView:(UIView *)view;
- (UIImage *)croppedImageWithMaxSize:(CGSize)maxSize;

- (void)_layoutRotationView;

@end
