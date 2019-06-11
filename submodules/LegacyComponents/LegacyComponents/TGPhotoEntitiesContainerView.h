#import "TGPhotoPaintSparseView.h"

@class TGPhotoPaintEntityView;

@interface TGPhotoEntitiesContainerView : TGPhotoPaintSparseView

@property (nonatomic, readonly) NSUInteger entitiesCount;
@property (nonatomic, copy) void (^entitySelected)(TGPhotoPaintEntityView *);
@property (nonatomic, copy) void (^entityRemoved)(TGPhotoPaintEntityView *);

- (TGPhotoPaintEntityView *)viewForUUID:(NSInteger)uuid;
- (void)removeViewWithUUID:(NSInteger)uuid;
- (void)removeAll;

- (void)handlePinch:(UIPinchGestureRecognizer *)gestureRecognizer;
- (void)handleRotate:(UIRotationGestureRecognizer *)gestureRecognizer;

- (UIImage *)imageInRect:(CGRect)rect background:(UIImage *)background;

- (bool)isTrackingAnyEntityView;

@end
