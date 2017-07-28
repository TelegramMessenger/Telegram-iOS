#import <LegacyComponents/TGPhotoPaintEntityView.h>
#import <LegacyComponents/TGPhotoPaintStickerEntity.h>

@interface TGPhotoStickerSelectionView : TGPhotoPaintEntitySelectionView

@end


@interface TGPhotoStickerEntityView : TGPhotoPaintEntityView

@property (nonatomic, readonly) TGPhotoPaintStickerEntity *entity;
@property (nonatomic, readonly) bool isMirrored;

- (instancetype)initWithEntity:(TGPhotoPaintStickerEntity *)entity;
- (void)mirror;
- (UIImage *)image;

- (CGRect)realBounds;

@end
