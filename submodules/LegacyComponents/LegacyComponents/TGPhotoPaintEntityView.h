#import <UIKit/UIKit.h>

@class TGPhotoPaintEntity;
@class TGPhotoPaintEntitySelectionView;
@class TGPaintUndoManager;

@interface TGPhotoPaintEntityView : UIView
{
    NSInteger _entityUUID;
    
    CGFloat _angle;
    CGFloat _scale;
}

@property (nonatomic, readonly) NSInteger entityUUID;

@property (nonatomic, readonly) TGPhotoPaintEntity *entity;
@property (nonatomic, assign) bool inhibitGestures;

@property (nonatomic, readonly) CGFloat angle;
@property (nonatomic, readonly) CGFloat scale;

@property (nonatomic, copy) bool (^shouldTouchEntity)(TGPhotoPaintEntityView *);
@property (nonatomic, copy) void (^entityBeganDragging)(TGPhotoPaintEntityView *);
@property (nonatomic, copy) void (^entityChanged)(TGPhotoPaintEntityView *);

@property (nonatomic, readonly) bool isTracking;

- (void)pan:(CGPoint)point absolute:(bool)absolute;
- (void)rotate:(CGFloat)angle absolute:(bool)absolute;
- (void)scale:(CGFloat)scale absolute:(bool)absolute;

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer;

- (bool)precisePointInside:(CGPoint)point;

@property (nonatomic, weak) TGPhotoPaintEntitySelectionView *selectionView;
- (TGPhotoPaintEntitySelectionView *)createSelectionView;
- (CGRect)selectionBounds;

@end


@interface TGPhotoPaintEntitySelectionView : UIView

@property (nonatomic, weak) TGPhotoPaintEntityView *entityView;

@property (nonatomic, copy) void (^entityRotated)(CGFloat angle);
@property (nonatomic, copy) void (^entityResized)(CGFloat scale);

@property (nonatomic, readonly) bool isTracking;

- (void)update;

- (void)fadeIn;
- (void)fadeOut;

@end