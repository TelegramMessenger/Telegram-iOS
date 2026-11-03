#import <UIKit/UIKit.h>

@class PGPhotoTool;

@protocol TGPhotoEditorCollectionViewToolsDataSource;

@interface TGPhotoEditorCollectionView : UICollectionView <UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, copy) void(^interactionBegan)(void);
@property (nonatomic, copy) void(^interactionEnded)(void);

@property (nonatomic, weak) id <TGPhotoEditorCollectionViewToolsDataSource> toolsDataSource;

@property (nonatomic, readonly) bool hasAnyTracking;

- (instancetype)initWithLandscape:(bool)landscape nameWidth:(CGFloat)nameWidth;

- (void)setMinimumLineSpacing:(CGFloat)minimumLineSpacing;
- (void)setMinimumInteritemSpacing:(CGFloat)minimumInteritemSpacing;

@end

@protocol TGPhotoEditorCollectionViewToolsDataSource <NSObject>

- (NSInteger)numberOfToolsInCollectionView:(TGPhotoEditorCollectionView *)collectionView;
- (PGPhotoTool *)collectionView:(TGPhotoEditorCollectionView *)collectionView toolAtIndex:(NSInteger)index;

- (void (^)(PGPhotoTool *, id, bool))changeBlockForCollectionView:(TGPhotoEditorCollectionView *)collectionView;
- (void (^)(void))interactionEndedForCollectionView:(TGPhotoEditorCollectionView *)collectionView;

@end

