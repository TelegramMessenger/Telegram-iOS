#import "TGMediaAssetsPickerController.h"

#import <LegacyComponents/LegacyComponentsContext.h>

@class TGMediaAssetMomentList;
@class TGViewController;

@interface TGMediaAssetsMomentsController : TGMediaAssetsPickerController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context assetsLibrary:(TGMediaAssetsLibrary *)assetsLibrary momentList:(TGMediaAssetMomentList *)momentList intent:(TGMediaAssetsControllerIntent)intent selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext saveEditedPhotos:(bool)saveEditedPhotos;

@end
