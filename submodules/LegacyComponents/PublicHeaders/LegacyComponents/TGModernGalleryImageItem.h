#import <UIKit/UIKit.h>

#import <LegacyComponents/TGModernGalleryItem.h>

#import <SSignalKit/SSignalKit.h>

@class TGImageInfo;
@class TGImageView;
@class TGMediaOriginInfo;

@interface TGModernGalleryImageItem : NSObject <TGModernGalleryItem>

@property (nonatomic, readonly) NSString *uri;
@property (nonatomic, copy, readonly) dispatch_block_t (^loader)(TGImageView *, bool);

@property (nonatomic, readonly) CGSize imageSize;
@property (nonatomic, strong) NSArray *embeddedStickerDocuments;
@property (nonatomic) bool hasStickers;
@property (nonatomic) int64_t imageId;
@property (nonatomic) int64_t accessHash;
@property (nonatomic, strong) TGMediaOriginInfo *originInfo;

- (instancetype)initWithUri:(NSString *)uri imageSize:(CGSize)imageSize;
- (instancetype)initWithLoader:(dispatch_block_t (^)(TGImageView *, bool))loader imageSize:(CGSize)imageSize;
- (instancetype)initWithSignal:(SSignal *)signal imageSize:(CGSize)imageSize;

@end
