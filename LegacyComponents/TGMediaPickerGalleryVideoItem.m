#import "TGMediaPickerGalleryVideoItem.h"

#import "LegacyComponentsInternal.h"

#import "TGMediaPickerGalleryVideoItemView.h"

#import "TGMediaAsset+TGMediaEditableItem.h"
#import <LegacyComponents/AVURLAsset+TGMediaItem.h>

@interface TGMediaPickerGalleryVideoItem ()
{
    CGSize _dimensions;
    NSTimeInterval _duration;
}
@end

@implementation TGMediaPickerGalleryVideoItem

@synthesize selectionContext;
@synthesize editingContext;

- (instancetype)initWithFileURL:(NSURL *)fileURL dimensions:(CGSize)dimensions duration:(NSTimeInterval)duration
{
    self = [super init];
    if (self != nil)
    {
        _avAsset = [[AVURLAsset alloc] initWithURL:fileURL options:nil];
        _dimensions = dimensions;
        _duration = duration;
    }
    return self;
}

- (CGSize)dimensions
{
    if (self.asset != nil)
        return self.asset.dimensions;
    
    return _dimensions;
}

- (SSignal *)durationSignal
{
    if (self.asset != nil)
        return self.asset.actualVideoDuration;
    
    return [SSignal single:@(_duration)];
}

- (NSString *)uniqueId
{
    if (self.asset != nil)
        return self.asset.identifier;
    else if (self.avAsset != nil)
        return self.avAsset.URL.absoluteString;
    
    return nil;
}

- (id<TGMediaSelectableItem>)selectableMediaItem
{
    if (self.asset != nil)
        return self.asset;
    else if (self.avAsset != nil)
        return self.avAsset;
    
    return nil;
}

- (id<TGMediaEditableItem>)editableMediaItem
{
    if (self.asset != nil)
        return self.asset;
    else if (self.avAsset != nil)
        return self.avAsset;
    
    return nil;
}

- (TGPhotoEditorTab)toolbarTabs
{
    return TGPhotoEditorCropTab | TGPhotoEditorPaintTab | TGPhotoEditorQualityTab | TGPhotoEditorTimerTab;
}

- (Class)viewClass
{
    return [TGMediaPickerGalleryVideoItemView class];
}

- (BOOL)isEqual:(id)object
{
    return [object isKindOfClass:[TGMediaPickerGalleryVideoItem class]]
    && ((self.asset != nil && TGObjectCompare(self.asset, ((TGMediaPickerGalleryItem *)object).asset)) ||
    (self.avAsset != nil && TGObjectCompare(self.avAsset.URL, ((TGMediaPickerGalleryVideoItem *)object).avAsset.URL)));
}

@end
