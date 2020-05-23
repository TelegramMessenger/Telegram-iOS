#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>

@class TGPaintingData;

@protocol TGPhotoPaintEntityRenderer <NSObject>

- (void)entitiesForTime:(CMTime)time size:(CGSize)size completion:(void(^)(NSArray<CIImage *> *))completion;

@end

@protocol TGPhotoPaintStickerRenderView <NSObject>

- (UIImage *)image;

@end

@protocol TGPhotoPaintStickersContext <NSObject>

- (UIView<TGPhotoPaintStickerRenderView> *)stickerViewForDocument:(id)document;

@property (nonatomic, copy) void(^presentStickersController)(void(^)(id, bool, UIView *, CGRect));

@end
