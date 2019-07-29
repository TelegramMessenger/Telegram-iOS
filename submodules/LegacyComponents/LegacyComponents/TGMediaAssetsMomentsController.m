#import "TGMediaAssetsMomentsController.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/TGMediaAssetsModernLibrary.h>
#import <LegacyComponents/TGMediaAssetMomentList.h>
#import <LegacyComponents/TGMediaAssetFetchResult.h>

#import <LegacyComponents/TGMediaAssetsUtils.h>

#import <LegacyComponents/TGMediaPickerLayoutMetrics.h>
#import "TGMediaAssetsMomentsCollectionView.h"
#import "TGMediaAssetsMomentsCollectionLayout.h"
#import "TGMediaAssetsMomentsSectionHeaderView.h"
#import "TGMediaAssetsMomentsSectionHeader.h"

#import "TGMediaAssetsPhotoCell.h"
#import "TGMediaAssetsVideoCell.h"
#import "TGMediaAssetsGifCell.h"

#import <LegacyComponents/TGMediaPickerModernGalleryMixin.h>

#import <LegacyComponents/TGMediaPickerToolbarView.h>

#import <LegacyComponents/TGMediaPickerSelectionGestureRecognizer.h>

@interface TGMediaAssetsMomentsController ()
{
    TGMediaAssetMomentList *_momentList;
    
    TGMediaAssetsMomentsCollectionLayout *_collectionLayout;
    id<LegacyComponentsContext> _context;
}
@end

@implementation TGMediaAssetsMomentsController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context assetsLibrary:(TGMediaAssetsLibrary *)assetsLibrary momentList:(TGMediaAssetMomentList *)momentList intent:(TGMediaAssetsControllerIntent)intent selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext saveEditedPhotos:(bool)saveEditedPhotos
{
    self = [super initWithContext:context assetsLibrary:assetsLibrary assetGroup:nil intent:intent selectionContext:selectionContext editingContext:editingContext saveEditedPhotos:saveEditedPhotos];
    if (self != nil)
    {
        _context = context;
        _momentList = momentList;
        
        [self setTitle:TGLocalized(@"MediaPicker.Moments")];
    }
    return self;
}

- (Class)_collectionViewClass
{
    return [TGMediaAssetsMomentsCollectionView class];
}

- (UICollectionViewLayout *)_collectionLayout
{
    if (_collectionLayout == nil)
        _collectionLayout = [[TGMediaAssetsMomentsCollectionLayout alloc] init];
    
    return _collectionLayout;
}

- (void)viewDidLoad
{
    CGSize frameSize = self.view.frame.size;
    CGRect collectionViewFrame = CGRectMake(0.0f, 0.0f, frameSize.width, frameSize.height);
    _collectionViewWidth = collectionViewFrame.size.width;
    _collectionView.frame = collectionViewFrame;
    
    _layoutMetrics = [TGMediaPickerLayoutMetrics defaultLayoutMetrics];
    
    _preheatMixin.imageSize = [_layoutMetrics imageSize];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [_collectionView reloadData];
        [_collectionView layoutSubviews];
        [self _adjustContentOffsetToBottom];
    });
}

- (void)collectionView:(UICollectionView *)__unused collectionView setupSectionHeaderView:(TGMediaAssetsMomentsSectionHeaderView *)sectionHeaderView forSectionHeader:(TGMediaAssetsMomentsSectionHeader *)sectionHeader
{
    TGMediaAssetMoment *moment = _momentList[sectionHeader.index];
    
    NSString *title = @"";
    NSString *location = @"";
    NSString *date = @"";
    if (moment.title.length > 0)
    {
        title = moment.title;
        if (moment.locationNames.count > 0)
            location = moment.locationNames.firstObject;
        date = [TGMediaAssetsDateUtils formattedDateRangeWithStartDate:moment.startDate endDate:moment.endDate currentDate:[NSDate date] shortDate:true];
    }
    else
    {
        title = [TGMediaAssetsDateUtils formattedDateRangeWithStartDate:moment.startDate endDate:moment.endDate currentDate:[NSDate date] shortDate:false];
    }
    
    [sectionHeaderView setTitle:title location:location date:date];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)__unused collectionView
{
    return _momentList.count;
}

- (NSInteger)collectionView:(UICollectionView *)__unused collectionView numberOfItemsInSection:(NSInteger)__unused section
{
    return ((TGMediaAssetMoment *)_momentList[section]).assetCount;
}

- (UIEdgeInsets)collectionView:(UICollectionView *)__unused collectionView layout:(UICollectionViewLayout *)__unused collectionViewLayout insetForSectionAtIndex:(NSInteger)__unused section
{
    return UIEdgeInsetsMake(48.0f, 0.0f, 0.0f, 0.0f);
}

- (TGMediaPickerModernGalleryMixin *)_galleryMixinForItem:(id)item thumbnailImage:(UIImage *)thumbnailImage selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext suggestionContext:(TGSuggestionContext *)suggestionContext hasCaptions:(bool)hasCaption allowCaptionEntities:(bool)allowCaptionEntities asFile:(bool)asFile
{
    return [[TGMediaPickerModernGalleryMixin alloc] initWithContext:_context item:item momentList:_momentList parentController:self thumbnailImage:thumbnailImage selectionContext:selectionContext editingContext:editingContext suggestionContext:suggestionContext hasCaptions:hasCaption allowCaptionEntities:allowCaptionEntities hasTimer:false onlyCrop:false inhibitDocumentCaptions:false inhibitMute:false asFile:asFile itemsLimit:0 hasSilentPosting:false];
}

- (id)_itemAtIndexPath:(NSIndexPath *)indexPath
{
    TGMediaAssetFetchResult *fetchResult = [_momentList[indexPath.section] fetchResult];
    TGMediaAsset *asset = [fetchResult assetAtIndex:indexPath.row];
    return asset;
}

@end
