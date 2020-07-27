#import "TGMediaPickerGalleryVideoItem.h"

#import "LegacyComponentsInternal.h"

#import "TGMediaPickerGalleryVideoItemView.h"

#import "TGMediaAsset+TGMediaEditableItem.h"
#import "TGCameraCapturedVideo.h"
#import <LegacyComponents/AVURLAsset+TGMediaItem.h>

@implementation TGMediaPickerGalleryVideoItem

@synthesize selectionContext;
@synthesize editingContext;
@synthesize stickersContext;

- (CGSize)dimensions
{
    if ([self.asset isKindOfClass:[TGMediaAsset class]])
        return ((TGMediaAsset *)self.asset).dimensions;
    
    if ([self.asset respondsToSelector:@selector(originalSize)])
        return self.asset.originalSize;
    
    return CGSizeZero;
}

- (SSignal *)avAsset
{
    if ([self.asset isKindOfClass:[TGCameraCapturedVideo class]])
        return ((TGCameraCapturedVideo *)self.asset).avAsset;
    
    return nil;
}

- (SSignal *)durationSignal
{
    if ([self.asset isKindOfClass:[TGMediaAsset class]])
        return ((TGMediaAsset *)self.asset).actualVideoDuration;
    
    if ([self.asset respondsToSelector:@selector(originalDuration)]) {
        if ([self.asset isKindOfClass:[TGCameraCapturedVideo class]]) {
            return [[(TGCameraCapturedVideo *)self.asset avAsset] mapToSignal:^SSignal *(id next) {
                if ([next isKindOfClass:[AVAsset class]]) {
                    return [SSignal single:@(CMTimeGetSeconds(((AVAsset *)next).duration))];
                } else {
                    return [SSignal complete];
                }
            }];
        }
        return [SSignal single:@(self.asset.originalDuration)];
    }
    
    return [SSignal single:@0];
}

- (NSString *)uniqueId
{
    if (self.asset != nil)
        return self.asset.uniqueIdentifier;
    
    return nil;
}

- (id<TGMediaSelectableItem>)selectableMediaItem
{
    if (self.asset != nil)
        return self.asset;
    
    return nil;
}

- (id<TGMediaEditableItem>)editableMediaItem
{
    if (self.asset != nil)
        return self.asset;
    
    return nil;
}

- (TGPhotoEditorTab)toolbarTabs
{
    if ([self.asset isKindOfClass:[TGMediaAsset class]] && ((TGMediaAsset *)self.asset).subtypes & TGMediaAssetSubtypePhotoLive) {
        return TGPhotoEditorCropTab | TGPhotoEditorPaintTab | TGPhotoEditorToolsTab;
    } else if ([self.asset isKindOfClass:[TGCameraCapturedVideo class]] && ((TGCameraCapturedVideo *)self.asset).isAnimation) {
        return TGPhotoEditorCropTab | TGPhotoEditorPaintTab | TGPhotoEditorToolsTab;
    } else {
        return TGPhotoEditorCropTab | TGPhotoEditorToolsTab | TGPhotoEditorPaintTab | TGPhotoEditorQualityTab;
    }
}

- (Class)viewClass
{
    return [TGMediaPickerGalleryVideoItemView class];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGMediaPickerGalleryVideoItem class]] && (self.asset != nil && TGObjectCompare(self.asset, ((TGMediaPickerGalleryItem *)object).asset));
}

@end
