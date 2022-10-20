#import <LegacyComponents/TGPhotoPaintEntityView.h>
#import <LegacyComponents/TGPhotoPaintStickerEntity.h>

@interface TGPhotoStickerSelectionView : TGPhotoPaintEntitySelectionView

@end

@protocol TGPhotoPaintStickersContext;

@interface TGPhotoStickerEntityView : TGPhotoPaintEntityView

@property (nonatomic, copy) void(^started)(double);

@property (nonatomic, readonly) TGPhotoPaintStickerEntity *entity;
@property (nonatomic, readonly) bool isMirrored;

@property (nonatomic, readonly) int64_t documentId;

- (instancetype)initWithEntity:(TGPhotoPaintStickerEntity *)entity context:(id<TGPhotoPaintStickersContext>)context;
- (void)mirror;
- (UIImage *)image;

- (void)updateVisibility:(bool)visible;
- (void)seekTo:(double)timestamp;
- (void)play;
- (void)pause;
- (void)resetToStart;
- (void)playFromFrame:(NSInteger)frameIndex;
- (void)copyStickerView:(TGPhotoStickerEntityView *)view;

- (CGRect)realBounds;

@end
