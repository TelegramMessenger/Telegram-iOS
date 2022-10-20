#import "TGDraggableCollectionView.h"

#import <LegacyComponents/LegacyComponents.h>

#import "TGDraggableCollectionViewFlowLayout.h"

NSString * const TGDraggableCollectionViewLayoutKey = @"collectionViewLayout";
const UIEdgeInsets TGDraggableDefaultScrollingTriggerEdgeInsets = { 60, 60, 60, 60 };
const CGFloat TGDraggableDefaultScrollingSpeed = 300.0f;

typedef enum
{
    TGDraggableCollectionScrollingDirectionUnknown,
    TGDraggableCollectionScrollingDirectionUp,
    TGDraggableCollectionScrollingDirectionLeft,
    TGDraggableCollectionScrollingDirectionRight,
    TGDraggableCollectionScrollingDirectionDown
} TGDraggableCollectionScrollingDirection;

@interface TGDraggableCollectionView () <UIGestureRecognizerDelegate>
{
    UIView *_draggedView;
    UIView *_insideSnapshotView;
    UIView *_outsideSnapshotView;
    
    NSIndexPath *_lastIndexPath;
    
    UIPanGestureRecognizer *_panGestureRecognizer;
    UILongPressGestureRecognizer *_pressGestureRecognizer;
    
    CADisplayLink *_scrollingDisplayLink;
    TGDraggableCollectionScrollingDirection _scrollingDirection;
}

@end

@implementation TGDraggableCollectionView

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout
{
    NSAssert([layout isKindOfClass:[TGDraggableCollectionViewFlowLayout class]], @"collectionViewLayout must be an instance of TGDraggableCollectionViewFlowLayout");
    
    self = [super initWithFrame:frame collectionViewLayout:layout];
    if (self != nil)
    {
        _scrollingTriggerEdgeInsets = TGDraggableDefaultScrollingTriggerEdgeInsets;
        _scrollingSpeed = TGDraggableDefaultScrollingSpeed;
        
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragPan:)];
        _panGestureRecognizer.delegate = self;
        [self addGestureRecognizer:_panGestureRecognizer];
        
        _pressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragPress:)];
        _pressGestureRecognizer.minimumPressDuration = 0.25f;
        _pressGestureRecognizer.delegate = self;
        for (UIGestureRecognizer *gestureRecognizer in self.gestureRecognizers)
        {
            if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]])
                [gestureRecognizer requireGestureRecognizerToFail:_pressGestureRecognizer];
        }
        [self addGestureRecognizer:_pressGestureRecognizer];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleApplicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillResignActiveNotification
                                                  object:nil];
}

- (void)handleApplicationWillResignActive:(NSNotification *)__unused notification
{
    _pressGestureRecognizer.enabled = false;
    _pressGestureRecognizer.enabled = true;
}

- (void)setDraggable:(bool)draggable
{
    _draggable = draggable;
    _pressGestureRecognizer.enabled = draggable;
    _panGestureRecognizer.enabled = draggable;
}

#pragma mark - Items

- (TGDraggableCollectionViewFlowLayout *)draggableLayout
{
    return (TGDraggableCollectionViewFlowLayout *)self.draggableLayout;
}

- (NSIndexPath *)indexPathForItemNearPoint:(CGPoint)point
{
    NSIndexPath *destinationIndexPath = self.draggableLayout.destinationIndexPath;
    self.draggableLayout.destinationIndexPath = nil;
    NSArray *layoutAttributes = [self.draggableLayout layoutAttributesForElementsInRect:self.bounds];
    self.draggableLayout.destinationIndexPath = destinationIndexPath;
 
    NSIndexPath *nearestItemIndexPath = nil;
    CGFloat minDistance = FLT_MAX;
    
    for (UICollectionViewLayoutAttributes *attributes in layoutAttributes)
    {
        CGFloat deltaX = attributes.center.x - point.x;
        CGFloat deltaY = attributes.center.y - point.y;
        CGFloat distance = (CGFloat)sqrt(deltaX * deltaX + deltaY * deltaY);
        
        if (distance < minDistance)
        {
            minDistance = distance;
            nearestItemIndexPath = attributes.indexPath;
        }
    }
    
    return nearestItemIndexPath;
}

#pragma mark - Dragged View

- (UIView *)_draggedViewSuperview
{
    return (self.draggedViewSuperview != nil) ? self.draggedViewSuperview : self;
}

- (UIView *)_prepareDraggedViewForCell:(UICollectionViewCell *)cell
{
    UIView *view = [[UIView alloc] initWithFrame:[self convertRect:cell.frame toView:[self _draggedViewSuperview]]];
    view.layer.rasterizationScale = TGScreenScaling();
    
    _outsideSnapshotView = [cell snapshotViewAfterScreenUpdates:false];
    [view addSubview:_outsideSnapshotView];
    
    _insideSnapshotView = [cell snapshotViewAfterScreenUpdates:false];
    
    _outsideSnapshotView.layer.shadowOffset = CGSizeZero;
    _outsideSnapshotView.layer.shadowColor = [UIColor blackColor].CGColor;
    _outsideSnapshotView.layer.shadowRadius = 3.0f;
    _outsideSnapshotView.layer.shadowOpacity = 0.87f;
    _outsideSnapshotView.layer.shadowPath = [UIBezierPath bezierPathWithRect:view.bounds].CGPath;
    
    return view;
}

- (void)_performDraggedViewHighlightTransitionWithDuration:(CGFloat)duration completion:(void (^)(void))completion
{
    [self addSubview:_insideSnapshotView];
    _insideSnapshotView.center = [self convertPoint:_draggedView.center fromView:[self _draggedViewSuperview]];
    
    _draggedView.layer.shouldRasterize = true;
    _draggedView.alpha = 0.0f;
    
    [UIView animateWithDuration:duration delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^
     {
         _draggedView.alpha = 1.0f;
         _draggedView.transform = CGAffineTransformMakeScale(1.12f, 1.12f);
         _insideSnapshotView.transform = _draggedView.transform;
     } completion:^(BOOL finished)
     {
         if (finished)
         {
             _insideSnapshotView.hidden = true;
             if (completion != nil)
                 completion();
         }
     }];
}

- (void)_performDraggedViewUnhighlightTransitionWithDuration:(CGFloat)duration targetCellCenter:(CGPoint)targetCellCenter completion:(void (^)(void))completion
{
    _insideSnapshotView.center = [self convertPoint:_draggedView.center fromView:[self _draggedViewSuperview]];
    _insideSnapshotView.hidden = false;
    
    [UIView animateWithDuration:duration delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^
     {
         _draggedView.alpha = 0.0f;
         _draggedView.transform = CGAffineTransformIdentity;
         _insideSnapshotView.transform = _draggedView.transform;
         _draggedView.center = [self convertPoint:targetCellCenter toView:[self _draggedViewSuperview]];
         _insideSnapshotView.center = targetCellCenter;
     } completion:^(__unused BOOL finished)
     {
         if (completion != nil)
             completion();
     }];
}

- (void)_performDraggedViewDropToIndexPath:(NSIndexPath *)destinationIndexPath completion:(void (^)(void))completion
{
    UICollectionViewLayoutAttributes *layoutAttributes = [self layoutAttributesForItemAtIndexPath:destinationIndexPath];
    
    [self _performDraggedViewUnhighlightTransitionWithDuration:0.25f targetCellCenter:layoutAttributes.center completion:^
    {
        [_draggedView removeFromSuperview];
        _draggedView = nil;
        [_outsideSnapshotView removeFromSuperview];
        _outsideSnapshotView = nil;
        [_insideSnapshotView removeFromSuperview];
        _insideSnapshotView = nil;
         
        if (completion != nil)
            completion();
    }];
}

- (void)updateDestinationIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath == nil || [_lastIndexPath isEqual:indexPath])
        return;

    _lastIndexPath = indexPath;
    
    id<TGDraggableCollectionViewDataSource> dataSource = (id<TGDraggableCollectionViewDataSource>)self.dataSource;
    if ([dataSource respondsToSelector:@selector(collectionView:canMoveItemAtIndexPath:toIndexPath:)] &&
        ![dataSource collectionView:self canMoveItemAtIndexPath:self.draggableLayout.sourceIndexPath toIndexPath:indexPath])
    {
        return;
    }
    
    [self performBatchUpdates:^
    {
        self.draggableLayout.hiddenIndexPath = indexPath;
        self.draggableLayout.destinationIndexPath = indexPath;
    } completion:nil];
}

#pragma mark - Gesture Handling

- (void)handleDragPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            CGPoint location = [gestureRecognizer locationInView:self];
            NSIndexPath *indexPath = [self indexPathForItemAtPoint:location];
            if (indexPath == nil)
                return;
            
            id<TGDraggableCollectionViewDataSource> dataSource = (id<TGDraggableCollectionViewDataSource>)self.dataSource;
            if ([dataSource respondsToSelector:@selector(collectionView:canMoveItemAtIndexPath:)] &&
                ![dataSource collectionView:self canMoveItemAtIndexPath:indexPath])
            {
                return;
            }
            
            [_draggedView removeFromSuperview];
            _draggedView = [self _prepareDraggedViewForCell:[self cellForItemAtIndexPath:indexPath]];
            [[self _draggedViewSuperview] addSubview:_draggedView];
            
            [self _performDraggedViewHighlightTransitionWithDuration:0.25f completion:nil];
            
            _lastIndexPath = indexPath;
            self.draggableLayout.sourceIndexPath = indexPath;
            self.draggableLayout.destinationIndexPath = indexPath;
            self.draggableLayout.hiddenIndexPath = indexPath;
            [self.draggableLayout invalidateLayout];
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            if (self.draggableLayout.sourceIndexPath == nil)
                return;
            
            NSIndexPath *sourceIndexPath = self.draggableLayout.sourceIndexPath;
            NSIndexPath *destinationIndexPath = self.draggableLayout.destinationIndexPath;
            
            id<TGDraggableCollectionViewDataSource> dataSource = (id<TGDraggableCollectionViewDataSource>)self.dataSource;
            [dataSource collectionView:self itemAtIndexPath:sourceIndexPath willMoveToIndexPath:destinationIndexPath];
            
            [self performBatchUpdates:^
            {
                [self moveItemAtIndexPath:sourceIndexPath toIndexPath:destinationIndexPath];
                self.draggableLayout.sourceIndexPath = nil;
                self.draggableLayout.destinationIndexPath = nil;
            } completion:nil];
            
            _pressGestureRecognizer.enabled = false;
            
            [self _performDraggedViewDropToIndexPath:destinationIndexPath completion:^
            {
                _pressGestureRecognizer.enabled = true;
                
                if ([dataSource respondsToSelector:@selector(collectionView:itemAtIndexPath:didMoveToIndexPath:)])
                    [dataSource collectionView:self itemAtIndexPath:sourceIndexPath didMoveToIndexPath:destinationIndexPath];
                
                self.draggableLayout.hiddenIndexPath = nil;
                [self.draggableLayout invalidateLayout];
            }];
            
            _lastIndexPath = nil;
            [self invalidateScrolling];
        }
            break;
            
        default:
            break;
    }
}

- (void)handleDragPan:(UIPanGestureRecognizer *)gestureRecognizer
{
    if (self.draggableLayout.sourceIndexPath == nil)
        return;
    
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        case UIGestureRecognizerStateChanged:
        {
            CGPoint translation = [gestureRecognizer translationInView:self];
            [gestureRecognizer setTranslation:CGPointZero inView:self];
            
            _draggedView.center = CGPointMake(_draggedView.center.x + translation.x,
                                              _draggedView.center.y + translation.y);
            
            CGPoint center = [self convertPoint:_draggedView.center fromView:[self _draggedViewSuperview]];
            _insideSnapshotView.center = center;
            
            UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.draggableLayout;
            switch (layout.scrollDirection)
            {
                case UICollectionViewScrollDirectionHorizontal:
                {
                    if (center.x < (CGRectGetMinX(self.bounds) + self.scrollingTriggerEdgeInsets.left))
                    {
                        [self setupScrollForDraggingInDirection:TGDraggableCollectionScrollingDirectionLeft];
                    }
                    else
                    {
                        if (center.x > (CGRectGetMaxX(self.bounds) - self.scrollingTriggerEdgeInsets.right))
                            [self setupScrollForDraggingInDirection:TGDraggableCollectionScrollingDirectionRight];
                        else
                            [self invalidateScrolling];
                    }
                }
                    break;
                    
                case UICollectionViewScrollDirectionVertical:
                {
                    if (center.y < (CGRectGetMinY(self.bounds) + self.scrollingTriggerEdgeInsets.top))
                    {
                        [self setupScrollForDraggingInDirection:TGDraggableCollectionScrollingDirectionUp];
                    }
                    else
                    {
                        if (center.y > (CGRectGetMaxY(self.bounds) - self.scrollingTriggerEdgeInsets.bottom))
                            [self setupScrollForDraggingInDirection:TGDraggableCollectionScrollingDirectionDown];
                        else
                            [self invalidateScrolling];
                    }
                }
                    break;
                    
                default:
                    break;
            }
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            [self invalidateScrolling];
        }
            break;
            
        default:
            break;
    }
    
    if (_scrollingDirection != TGDraggableCollectionScrollingDirectionUnknown)
        return;
    
    CGPoint location = [gestureRecognizer locationInView:self];
    NSIndexPath *indexPath = [self indexPathForItemNearPoint:location];
    [self updateDestinationIndexPath:indexPath];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (self.draggable && gestureRecognizer == _panGestureRecognizer)
        return (self.draggableLayout.sourceIndexPath != nil);
    
    return true;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer == _pressGestureRecognizer && otherGestureRecognizer == _panGestureRecognizer)
        return true;
    else if (gestureRecognizer == _panGestureRecognizer && otherGestureRecognizer == _pressGestureRecognizer)
        return true;
    
    return false;
}

#pragma mark - Scrolling

- (void)setupScrollForDraggingInDirection:(TGDraggableCollectionScrollingDirection)direction
{
    if (_scrollingDirection == direction)
        return;
    
    [self invalidateScrolling];
    
    _scrollingDirection = direction;
    
    _scrollingDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(handleDragScroll:)];
    [_scrollingDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)handleDragScroll:(CADisplayLink *)displayLink
{
    if (_scrollingDirection == TGDraggableCollectionScrollingDirectionUnknown)
        return;
    
    CGSize frameSize = self.bounds.size;
    CGSize contentSize = self.contentSize;
    CGPoint contentOffset = self.contentOffset;
    UIEdgeInsets contentInset = self.contentInset;
    
    CGFloat distance = (CGFloat)rint(self.scrollingSpeed * displayLink.duration);
    CGPoint translation = CGPointZero;
    
    switch (_scrollingDirection)
    {
        case TGDraggableCollectionScrollingDirectionUp:
        {
            distance = -distance;
            
            if (contentOffset.y + distance <= -contentInset.top)
                distance = -contentOffset.y - contentInset.top;
            
            translation = CGPointMake(0, distance);
        }
            break;
            
        case TGDraggableCollectionScrollingDirectionDown:
        {
            CGFloat maxY = contentSize.height - frameSize.height + contentInset.bottom;
            
            if ((contentOffset.y + distance) >= maxY)
                distance = maxY - contentOffset.y;
            
            translation = CGPointMake(0, distance);
        }
            break;
            
        case TGDraggableCollectionScrollingDirectionLeft:
        {
            distance = -distance;
            
            if (contentOffset.x + distance <= -contentInset.left)
                distance = -contentOffset.x - contentInset.left;
            
            translation = CGPointMake(distance, 0);
        }
            break;
            
        case TGDraggableCollectionScrollingDirectionRight:
        {
            CGFloat maxX = contentSize.width - frameSize.width + contentInset.right;
            
            if ((contentOffset.x + distance) >= maxX)
                distance = maxX - contentOffset.x;
            
            translation = CGPointMake(distance, 0);
        }
            break;
            
        default:
            break;
    }

    self.contentOffset = CGPointMake(contentOffset.x + translation.x,
                                     contentOffset.y + translation.y);
    
    NSIndexPath *indexPath = [self indexPathForItemNearPoint:_draggedView.center];
    [self updateDestinationIndexPath:indexPath];
}

- (void)invalidateScrolling
{
    [_scrollingDisplayLink invalidate];
    _scrollingDisplayLink = nil;
    
    _scrollingDirection = TGDraggableCollectionScrollingDirectionUnknown;
}

@end
