#import "TGMediaPickerGalleryVideoItem.h"

#import "LegacyComponentsInternal.h"

#import "TGMediaPickerGalleryVideoItemView.h"

#import "TGMediaAsset+TGMediaEditableItem.h"
#import "TGCameraCapturedVideo.h"
#import <LegacyComponents/AVURLAsset+TGMediaItem.h>

@implementation TGMediaPickerGalleryVideoItem

@synthesize selectionContext;
@synthesize editingContext;

- (CGSize)dimensions
{
    if ([self.asset isKindOfClass:[TGMediaAsset class]])
        return ((TGMediaAsset *)self.asset).dimensions;
    
    if ([self.asset respondsToSelector:@selector(originalSize)])
        return self.asset.originalSize;
    
    return CGSizeZero;
}

- (AVAsset *)avAsset
{
    if ([self.asset isKindOfClass:[TGCameraCapturedVideo class]])
        return ((TGCameraCapturedVideo *)self.asset).avAsset;
    
    return nil;
}

- (SSignal *)durationSignal
{
    if ([self.asset isKindOfClass:[TGMediaAsset class]])
        return ((TGMediaAsset *)self.asset).actualVideoDuration;
    
    if ([self.asset respondsToSelector:@selector(originalDuration)])
        return [SSignal single:@(self.asset.originalDuration)];
    
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
    if ([self.asset isKindOfClass:[TGMediaAsset class]] && ((TGMediaAsset *)self.asset).subtypes & TGMediaAssetSubtypePhotoLive)
        return TGPhotoEditorCropTab | TGPhotoEditorPaintTab | TGPhotoEditorToolsTab | TGPhotoEditorTimerTab;
    else
        return TGPhotoEditorCropTab | TGPhotoEditorPaintTab | TGPhotoEditorQualityTab | TGPhotoEditorTimerTab;
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
