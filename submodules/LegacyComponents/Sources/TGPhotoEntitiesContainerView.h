#import "TGPhotoEditorSparseView.h"
#import "TGPhotoPaintStickersContext.h"

@class TGPaintingData;
@class TGPhotoPaintEntity;
@class TGPhotoPaintEntityView;

@interface TGPhotoEntitiesContainerView : TGPhotoEditorSparseView

@property (nonatomic, strong) id<TGPhotoPaintStickersContext> stickersContext;

@property (nonatomic, readonly) NSUInteger entitiesCount;
@property (nonatomic, copy) void (^entitySelected)(TGPhotoPaintEntityView *);
@property (nonatomic, copy) void (^entityRemoved)(TGPhotoPaintEntityView *);

- (void)updateVisibility:(bool)visible;
- (void)seekTo:(double)timestamp;
- (void)play;
- (void)pause;
- (void)resetToStart;

- (UIColor *)colorAtPoint:(CGPoint)point;

- (void)setupWithPaintingData:(TGPaintingData *)paintingData;
- (TGPhotoPaintEntityView *)createEntityViewWithEntity:(TGPhotoPaintEntity *)entity;

- (TGPhotoPaintEntityView *)viewForUUID:(NSInteger)uuid;
- (void)removeViewWithUUID:(NSInteger)uuid;
- (void)removeAll;

- (void)handlePinch:(UIPinchGestureRecognizer *)gestureRecognizer;
- (void)handleRotate:(UIRotationGestureRecognizer *)gestureRecognizer;

- (UIImage *)imageInRect:(CGRect)rect background:(UIImage *)background still:(bool)still;

- (bool)isTrackingAnyEntityView;

@end
