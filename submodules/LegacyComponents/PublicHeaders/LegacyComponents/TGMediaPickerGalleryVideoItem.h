#import <LegacyComponents/TGMediaPickerGalleryItem.h>
#import <LegacyComponents/TGModernGallerySelectableItem.h>
#import <LegacyComponents/TGModernGalleryEditableItem.h>
#import <AVFoundation/AVFoundation.h>

@class TGMediaAssetFetchResult;
@protocol TGMediaEditAdjustments;

@interface TGMediaPickerGalleryVideoItem : TGMediaPickerGalleryItem <TGModernGallerySelectableItem, TGModernGalleryEditableItem>

@property (nonatomic, readonly) SSignal *avAsset;
@property (nonatomic, readonly) CGSize dimensions;
- (SSignal *)durationSignal;

@end



@interface TGMediaPickerGalleryFetchResultItem : TGMediaPickerGalleryItem <TGModernGallerySelectableItem, TGModernGalleryEditableItem>

@property (nonatomic, readonly) TGMediaPickerGalleryItem<TGModernGallerySelectableItem, TGModernGalleryEditableItem> *backingItem;

- (instancetype)initWithFetchResult:(TGMediaAssetFetchResult *)fetchResult index:(NSUInteger)index;

@end
