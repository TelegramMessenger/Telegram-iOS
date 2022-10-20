#import <UIKit/UIKit.h>

@class PGPhotoTool;

@interface TGPhotoToolCell : UICollectionViewCell

@property (nonatomic, readonly) bool isTracking;

- (void)setPhotoTool:(PGPhotoTool *)photoTool landscape:(bool)landscape nameWidth:(CGFloat)nameWidth changeBlock:(void (^)(PGPhotoTool *, id, bool))changeBlock interactionBegan:(void (^)(void))interactionBegan interactionEnded:(void (^)(void))interactionEnded;

@end

extern NSString * const TGPhotoToolCellKind;
