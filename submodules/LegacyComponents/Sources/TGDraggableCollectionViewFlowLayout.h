#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TGDraggableCollectionViewFlowLayout : UICollectionViewFlowLayout

@property (nonatomic, strong) NSIndexPath *sourceIndexPath;
@property (nonatomic, strong) NSIndexPath *destinationIndexPath;
@property (nonatomic, strong) NSIndexPath *hiddenIndexPath;

@end
