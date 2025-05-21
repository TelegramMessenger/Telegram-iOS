#import <UIKit/UIKit.h>

#import <SSignalKit/SSignalKit.h>

@protocol TGMediaEditableItem <NSObject>

@property (nonatomic, readonly) bool isVideo;
@property (nonatomic, readonly) NSString *uniqueIdentifier;

@optional
@property (nonatomic, readonly) CGSize originalSize;
@property (nonatomic, readonly) NSTimeInterval originalDuration;

- (SSignal *)thumbnailImageSignal;
- (SSignal *)screenImageSignal:(NSTimeInterval)position;
- (SSignal *)originalImageSignal:(NSTimeInterval)position;

@end


@class TGPaintingData;

@protocol TGMediaEditAdjustments <NSObject>

@property (nonatomic, readonly) CGSize originalSize;
@property (nonatomic, readonly) CGRect cropRect;
@property (nonatomic, readonly) UIImageOrientation cropOrientation;
@property (nonatomic, readonly) CGFloat cropRotation;
@property (nonatomic, readonly) CGFloat cropLockedAspectRatio;
@property (nonatomic, readonly) bool cropMirrored;
@property (nonatomic, readonly) bool sendAsGif;
@property (nonatomic, readonly) TGPaintingData *paintingData;
@property (nonatomic, readonly) NSDictionary *toolValues;

- (bool)toolsApplied;
- (bool)hasPainting;

- (bool)cropAppliedForAvatar:(bool)forAvatar;
- (bool)isDefaultValuesForAvatar:(bool)forAvatar;

- (bool)isCropEqualWith:(id<TGMediaEditAdjustments>)adjusments;

@end


@interface TGMediaEditingContext : NSObject

@property (nonatomic, readonly) bool inhibitEditing;

@property (nonatomic, assign) int64_t sendPaidMessageStars;

+ (instancetype)contextForCaptionsOnly;

- (SSignal *)imageSignalForItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)imageSignalForItem:(NSObject<TGMediaEditableItem> *)item withUpdates:(bool)withUpdates;

- (SSignal *)thumbnailImageSignalForIdentifier:(NSString *)identifier;
- (SSignal *)thumbnailImageSignalForIdentifier:(NSString *)identifier withUpdates:(bool)withUpdates synchronous:(bool)synchronous;

- (SSignal *)thumbnailImageSignalForItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)thumbnailImageSignalForItem:(id<TGMediaEditableItem>)item withUpdates:(bool)withUpdates synchronous:(bool)synchronous;
- (SSignal *)fastImageSignalForItem:(NSObject<TGMediaEditableItem> *)item withUpdates:(bool)withUpdates;

- (void)setImage:(UIImage *)image thumbnailImage:(UIImage *)thumbnailImage forItem:(id<TGMediaEditableItem>)item synchronous:(bool)synchronous;
- (void)setFullSizeImage:(UIImage *)image forItem:(id<TGMediaEditableItem>)item;

- (SSignal *)coverImageSignalForItem:(NSObject<TGMediaEditableItem> *)item;
- (void)setCoverImage:(UIImage *)image position:(NSNumber *)position forItem:(id<TGMediaEditableItem>)item;
- (UIImage *)coverImageForItem:(NSObject<TGMediaEditableItem> *)item;
- (NSNumber *)coverPositionForItem:(NSObject<TGMediaEditableItem> *)item;

- (void)setTemporaryRep:(id)rep forItem:(id<TGMediaEditableItem>)item;

- (SSignal *)fullSizeImageUrlForItem:(id<TGMediaEditableItem>)item;

- (NSAttributedString *)captionForItem:(NSObject<TGMediaEditableItem> *)item;

- (SSignal *)captionSignalForItem:(NSObject<TGMediaEditableItem> *)item;
- (void)setCaption:(NSAttributedString *)caption forItem:(NSObject<TGMediaEditableItem> *)item;

- (bool)isForcedCaption;
- (SSignal *)forcedCaption;
- (void)setForcedCaption:(NSAttributedString *)caption;
- (void)setForcedCaption:(NSAttributedString *)caption skipUpdate:(bool)skipUpdate;

- (NSObject<TGMediaEditAdjustments> *)adjustmentsForItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)adjustmentsSignalForItem:(NSObject<TGMediaEditableItem> *)item;
- (void)setAdjustments:(NSObject<TGMediaEditAdjustments> *)adjustments forItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)adjustmentsUpdatedSignal;

- (NSNumber *)timerForItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)timerSignalForItem:(NSObject<TGMediaEditableItem> *)item;
- (void)setTimer:(NSNumber *)timer forItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)timersUpdatedSignal;

- (bool)spoilerForItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)spoilerSignalForItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)spoilerSignalForIdentifier:(NSString *)identifier;
- (void)setSpoiler:(bool)spoiler forItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)spoilersUpdatedSignal;

- (NSNumber *)priceForItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)priceSignalForItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)priceSignalForIdentifier:(NSString *)identifier;
- (void)setPrice:(NSNumber *)price forItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)pricesUpdatedSignal;

- (UIImage *)paintingImageForItem:(NSObject<TGMediaEditableItem> *)item;
- (UIImage *)stillPaintingImageForItem:(NSObject<TGMediaEditableItem> *)item;
- (bool)setPaintingData:(NSData *)data entitiesData:(NSData *)entitiesData image:(UIImage *)image stillImage:(UIImage *)stillImage forItem:(NSObject<TGMediaEditableItem> *)item dataUrl:(NSURL **)dataOutUrl entitiesDataUrl:(NSURL **)entitiesDataOutUrl imageUrl:(NSURL **)imageOutUrl forVideo:(bool)video;
- (void)clearPaintingData;

- (bool)isCaptionAbove;
- (SSignal *)captionAbove;
- (void)setCaptionAbove:(bool)captionAbove;

- (bool)isHighQualityPhoto;
- (SSignal *)highQualityPhoto;
- (void)setHighQualityPhoto:(bool)highQualityPhoto;

- (SSignal *)facesForItem:(NSObject<TGMediaEditableItem> *)item;
- (void)setFaces:(NSArray *)faces forItem:(NSObject<TGMediaEditableItem> *)item;

- (SSignal *)cropAdjustmentsUpdatedSignal;

- (void)requestOriginalThumbnailImageForItem:(id<TGMediaEditableItem>)item completion:(void (^)(UIImage *))completion;
- (void)requestOriginalImageForItem:(id<TGMediaEditableItem>)itemId completion:(void (^)(UIImage *image))completion;
- (void)setOriginalImage:(UIImage *)image forItem:(id<TGMediaEditableItem>)item synchronous:(bool)synchronous;

@end
