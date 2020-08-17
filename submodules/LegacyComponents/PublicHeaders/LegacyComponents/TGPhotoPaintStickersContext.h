#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>

@class TGPaintingData;
@class TGStickerMaskDescription;

@protocol TGPhotoPaintEntityRenderer <NSObject>

- (void)entitiesForTime:(CMTime)time fps:(NSInteger)fps size:(CGSize)size completion:(void(^)(NSArray<CIImage *> *))completion;

@end

@protocol TGPhotoPaintStickerRenderView <NSObject>

@property (nonatomic, copy) void(^started)(double);

- (void)setIsVisible:(bool)isVisible;
- (void)seekTo:(double)timestamp;
- (void)play;
- (void)pause;
- (void)resetToStart;
- (int64_t)documentId;
- (UIImage *)image;

@end

@protocol TGPhotoPaintStickersScreen <NSObject>

@property (nonatomic, copy) void(^screenDidAppear)(void);
@property (nonatomic, copy) void(^screenWillDisappear)(void);

- (void)restore;
- (void)invalidate;

@end

@protocol TGPhotoPaintStickersContext <NSObject>

- (int64_t)documentIdForDocument:(id)document;
- (TGStickerMaskDescription *)maskDescriptionForDocument:(id)document;

- (UIView<TGPhotoPaintStickerRenderView> *)stickerViewForDocument:(id)document;

@property (nonatomic, copy) id<TGPhotoPaintStickersScreen>(^presentStickersController)(void(^)(id, bool, UIView *, CGRect));

@end
