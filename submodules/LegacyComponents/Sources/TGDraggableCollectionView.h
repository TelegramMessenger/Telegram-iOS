#import <UIKit/UIKit.h>

@interface TGDraggableCollectionView : UICollectionView

@property (nonatomic, assign) bool draggable;
@property (nonatomic, assign) UIEdgeInsets scrollingTriggerEdgeInsets;
@property (nonatomic, assign) CGFloat scrollingSpeed;

@property (nonatomic, weak) UIView *draggedViewSuperview;

@end

@protocol TGDraggableCollectionViewDataSource <UICollectionViewDataSource>
@optional

- (void)collectionView:(UICollectionView *)collectionView itemAtIndexPath:(NSIndexPath *)sourceIndexPath willMoveToIndexPath:(NSIndexPath *)destinationIndexPath;
- (void)collectionView:(UICollectionView *)collectionView itemAtIndexPath:(NSIndexPath *)sourceIndexPath didMoveToIndexPath:(NSIndexPath *)destinationIndexPath;

- (bool)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)sourceIndexPath;
- (bool)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath;

@end
