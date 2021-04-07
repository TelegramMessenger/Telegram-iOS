#import <LegacyComponents/TGPhotoPaintEntityView.h>
#import <LegacyComponents/TGPhotoPaintStickerEntity.h>

@interface TGPhotoStickerSelectionView : TGPhotoPaintEntitySelectionView

@end

@protocol TGPhotoPaintStickersContext;

@interface TGPhotoStickerEntityView : TGPhotoPaintEntityView

@property (nonatomic, copy) void(^started)(double);

@property (nonatomic, readonly) TGPhotoPaintStickerEntity *entity;
@property (nonatomic, readonly) bool isMirrored;

- (instancetype)initWithEntity:(TGPhotoPaintStickerEntity *)entity context:(id<TGPhotoPaintStickersContext>)context;
- (void)mirror;
- (UIImage *)image;

- (void)updateVisibility:(bool)visible;
- (void)seekTo:(double)timestamp;
- (void)play;
- (void)pause;
- (void)resetToStart;

- (CGRect)realBounds;

@end
