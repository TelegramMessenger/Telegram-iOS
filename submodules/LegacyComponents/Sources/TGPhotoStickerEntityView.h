#import <LegacyComponents/TGPhotoPaintEntityView.h>
#import <LegacyComponents/TGPhotoPaintStickerEntity.h>

@interface TGPhotoStickerSelectionView : TGPhotoPaintEntitySelectionView

@end

@protocol TGPhotoPaintStickersContext;

@interface TGPhotoStickerEntityView : TGPhotoPaintEntityView

@property (nonatomic, readonly) TGPhotoPaintStickerEntity *entity;
@property (nonatomic, readonly) bool isMirrored;

- (instancetype)initWithEntity:(TGPhotoPaintStickerEntity *)entity context:(id<TGPhotoPaintStickersContext>)context;
- (void)mirror;
- (UIImage *)image;

- (void)updateVisibility:(bool)visible;

- (CGRect)realBounds;

@end
