#import <UIKit/UIKit.h>

@class PGPhotoFilter;
@class PGPhotoTool;

@protocol TGPhotoEditorCollectionViewFiltersDataSource;
@protocol TGPhotoEditorCollectionViewToolsDataSource;

@interface TGPhotoEditorCollectionView : UICollectionView <UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, copy) void(^interactionBegan)(void);
@property (nonatomic, copy) void(^interactionEnded)(void);

@property (nonatomic, weak) id <TGPhotoEditorCollectionViewFiltersDataSource> filtersDataSource;
@property (nonatomic, weak) id <TGPhotoEditorCollectionViewToolsDataSource> toolsDataSource;
@property (nonatomic, strong) UIImage *filterThumbnailImage;

@property (nonatomic, readonly) bool hasAnyTracking;

- (instancetype)initWithLandscape:(bool)landscape nameWidth:(CGFloat)nameWidth;

- (void)setMinimumLineSpacing:(CGFloat)minimumLineSpacing;
- (void)setMinimumInteritemSpacing:(CGFloat)minimumInteritemSpacing;

@end

@protocol TGPhotoEditorCollectionViewFiltersDataSource <NSObject>

- (NSInteger)numberOfFiltersInCollectionView:(TGPhotoEditorCollectionView *)collectionView;
- (PGPhotoFilter *)collectionView:(TGPhotoEditorCollectionView *)collectionView filterAtIndex:(NSInteger)index;
- (void)collectionView:(TGPhotoEditorCollectionView *)collectionView didSelectFilterWithIndex:(NSInteger)index;
- (void)collectionView:(TGPhotoEditorCollectionView *)collectionView requestThumbnailImageForFilterAtIndex:(NSInteger)index completion:(void (^)(UIImage *thumbnailImage, bool cached, bool finished))completion;

@end

@protocol TGPhotoEditorCollectionViewToolsDataSource <NSObject>

- (NSInteger)numberOfToolsInCollectionView:(TGPhotoEditorCollectionView *)collectionView;
- (PGPhotoTool *)collectionView:(TGPhotoEditorCollectionView *)collectionView toolAtIndex:(NSInteger)index;

- (void (^)(PGPhotoTool *, id, bool))changeBlockForCollectionView:(TGPhotoEditorCollectionView *)collectionView;
- (void (^)(void))interactionEndedForCollectionView:(TGPhotoEditorCollectionView *)collectionView;

@end

