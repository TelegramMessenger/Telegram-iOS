#import <LegacyComponents/TGMediaPickerGalleryItem.h>
#import <LegacyComponents/TGModernGallerySelectableItem.h>
#import <LegacyComponents/TGModernGalleryEditableItem.h>
#import <AVFoundation/AVFoundation.h>

@protocol TGMediaEditAdjustments;

@interface TGMediaPickerGalleryVideoItem : TGMediaPickerGalleryItem <TGModernGallerySelectableItem, TGModernGalleryEditableItem>

@property (nonatomic, readonly) AVAsset *avAsset;
@property (nonatomic, readonly) CGSize dimensions;
- (SSignal *)durationSignal;

@end
