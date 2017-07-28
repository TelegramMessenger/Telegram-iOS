#import <LegacyComponents/TGMediaPickerGalleryItem.h>
#import <LegacyComponents/TGModernGallerySelectableItem.h>
#import <LegacyComponents/TGModernGalleryEditableItem.h>
#import <AVFoundation/AVFoundation.h>

@protocol TGMediaEditAdjustments;

@interface TGMediaPickerGalleryVideoItem : TGMediaPickerGalleryItem <TGModernGallerySelectableItem, TGModernGalleryEditableItem>

@property (nonatomic, readonly) AVURLAsset *avAsset;
@property (nonatomic, readonly) CGSize dimensions;

- (instancetype)initWithFileURL:(NSURL *)fileURL dimensions:(CGSize)dimensions duration:(NSTimeInterval)duration;

- (SSignal *)durationSignal;

@end
