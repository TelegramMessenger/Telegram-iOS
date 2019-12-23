#import <LegacyComponents/TGMediaPickerController.h>
#import <LegacyComponents/TGMediaAssetsController.h>
#import <LegacyComponents/LegacyComponentsContext.h>
#import <LegacyComponents/TGVideoEditAdjustments.h>

@class TGMediaAssetsPreheatMixin;
@class TGMediaPickerModernGalleryMixin;
@class TGViewController;

@interface TGMediaAssetsPickerController : TGMediaPickerController
{
    TGMediaAssetsPreheatMixin *_preheatMixin;
}

@property (nonatomic, assign) bool liveVideoUploadEnabled;
@property (nonatomic, readonly) TGMediaAssetGroup *assetGroup;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context assetsLibrary:(TGMediaAssetsLibrary *)assetsLibrary assetGroup:(TGMediaAssetGroup *)assetGroup intent:(TGMediaAssetsControllerIntent)intent selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext saveEditedPhotos:(bool)saveEditedPhotos defaultVideoPreset:(TGMediaVideoConversionPreset)defaultVideoPreset;

@end
