#import "TGMediaAssetsPickerController.h"

#import "LegacyComponentsInternal.h"

#import "TGMediaAssetsMomentsController.h"
#import "TGMediaGroupsController.h"

#import <LegacyComponents/TGMediaAssetMomentList.h>
#import <LegacyComponents/TGMenuView.h>
#import <LegacyComponents/TGTooltipView.h>

#import <LegacyComponents/TGFileUtils.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGPaintUtils.h>
#import <LegacyComponents/UIImage+TG.h>
#import <LegacyComponents/TGGifConverter.h>
#import <CommonCrypto/CommonDigest.h>

#import "TGModernBarButton.h"
#import <LegacyComponents/TGMediaPickerToolbarView.h>
#import "TGMediaAssetsTipView.h"

#import <LegacyComponents/TGMediaAsset+TGMediaEditableItem.h>
#import <LegacyComponents/TGMediaAssetImageSignals.h>

#import <LegacyComponents/TGPhotoEditorController.h>

#import <LegacyComponents/TGVideoEditAdjustments.h>
#import <LegacyComponents/TGPaintingData.h>

@interface TGMediaAssetsController () <UINavigationControllerDelegate, ASWatcher>
{
    TGMediaAssetsControllerIntent _intent;
    
    TGMediaPickerToolbarView *_toolbarView;
    TGMediaSelectionContext *_selectionContext;
    TGMediaEditingContext *_editingContext;
    
    SMetaDisposable *_groupingChangedDisposable;
    SMetaDisposable *_selectionChangedDisposable;
    SMetaDisposable *_timersChangedDisposable;
    SMetaDisposable *_adjustmentsChangedDisposable;
    
    TGViewController *_searchController;
    UIView *_searchSnapshotView;
    
    NSTimer *_tooltipTimer;
    TGMenuContainerView *_tooltipContainerView;
    TGTooltipContainerView *_groupingTooltipContainerView;
    
    id<LegacyComponentsContext> _context;
    bool _saveEditedPhotos;
    
    SMetaDisposable *_tooltipDismissDisposable;
}

@property (nonatomic, strong) ASHandle *actionHandle;
@property (nonatomic, readonly) TGMediaAssetsLibrary *assetsLibrary;

@end

@implementation TGMediaAssetsController

+ (instancetype)controllerWithContext:(id<LegacyComponentsContext>)context assetGroup:(TGMediaAssetGroup *)assetGroup intent:(TGMediaAssetsControllerIntent)intent recipientName:(NSString *)recipientName saveEditedPhotos:(bool)saveEditedPhotos allowGrouping:(bool)allowGrouping
{
    if (intent != TGMediaAssetsControllerSendMediaIntent)
        allowGrouping = false;
    
    TGMediaAssetsController *assetsController = [[TGMediaAssetsController alloc] initWithContext:context intent:intent saveEditedPhotos:saveEditedPhotos allowGrouping:allowGrouping];
    
    __weak TGMediaAssetsController *weakController = assetsController;
    void (^catchToolbarView)(bool) = ^(bool enabled)
    {
        __strong TGMediaAssetsController *strongController = weakController;
        if (strongController == nil)
            return;
        
        UIView *toolbarView = strongController->_toolbarView;
        if (enabled)
        {
            if (toolbarView.superview != strongController.view)
                return;
            
            [strongController.pickerController.view addSubview:toolbarView];
        }
        else
        {
            if (toolbarView.superview == strongController.view)
                return;
            
            [strongController.view addSubview:toolbarView];
        }
    };
    
    TGMediaGroupsController *groupsController = [[TGMediaGroupsController alloc] initWithContext:context assetsLibrary:assetsController.assetsLibrary intent:intent];
    groupsController.openAssetGroup = ^(id group)
    {
        __strong TGMediaAssetsController *strongController = weakController;
        if (strongController == nil)
            return;
        
        TGMediaAssetsPickerController *pickerController = nil;
        
        if ([group isKindOfClass:[TGMediaAssetGroup class]])
        {
            pickerController = [[TGMediaAssetsPickerController alloc] initWithContext:strongController->_context assetsLibrary:strongController.assetsLibrary assetGroup:group intent:intent selectionContext:strongController->_selectionContext editingContext:strongController->_editingContext saveEditedPhotos:strongController->_saveEditedPhotos];
        }
        else if ([group isKindOfClass:[TGMediaAssetMomentList class]])
        {
            pickerController = [[TGMediaAssetsMomentsController alloc] initWithContext:strongController->_context assetsLibrary:strongController.assetsLibrary momentList:group intent:intent selectionContext:strongController->_selectionContext editingContext:strongController->_editingContext saveEditedPhotos:strongController->_saveEditedPhotos];
        }
        pickerController.suggestionContext = strongController.suggestionContext;
        pickerController.localMediaCacheEnabled = strongController.localMediaCacheEnabled;
        pickerController.captionsEnabled = strongController.captionsEnabled;
        pickerController.inhibitDocumentCaptions = strongController.inhibitDocumentCaptions;
        pickerController.liveVideoUploadEnabled = strongController.liveVideoUploadEnabled;
        pickerController.catchToolbarView = catchToolbarView;
        pickerController.recipientName = recipientName;
        pickerController.hasTimer = strongController.hasTimer;
        [strongController pushViewController:pickerController animated:true];
    };
    [groupsController loadViewIfNeeded];
    
    TGMediaAssetsPickerController *pickerController = [[TGMediaAssetsPickerController alloc] initWithContext:context assetsLibrary:assetsController.assetsLibrary assetGroup:assetGroup intent:intent selectionContext:assetsController->_selectionContext editingContext:assetsController->_editingContext saveEditedPhotos:saveEditedPhotos];
    pickerController.catchToolbarView = catchToolbarView;
    
    [groupsController setIsFirstInStack:true];
    [pickerController setIsFirstInStack:false];
    
    [assetsController setViewControllers:@[ groupsController, pickerController ]];
    ((TGNavigationBar *)assetsController.navigationBar).navigationController = assetsController;
    
    assetsController.recipientName = recipientName;
    
    return assetsController;
}

- (void)setSuggestionContext:(TGSuggestionContext *)suggestionContext
{
    _suggestionContext = suggestionContext;
    self.pickerController.suggestionContext = suggestionContext;
}

- (void)setCaptionsEnabled:(bool)captionsEnabled
{
    _captionsEnabled = captionsEnabled;
    self.pickerController.captionsEnabled = captionsEnabled;
}

- (void)setInhibitDocumentCaptions:(bool)inhibitDocumentCaptions
{
    _inhibitDocumentCaptions = inhibitDocumentCaptions;
    self.pickerController.inhibitDocumentCaptions = inhibitDocumentCaptions;
}

- (void)setLiveVideoUploadEnabled:(bool)liveVideoUploadEnabled
{
    _liveVideoUploadEnabled = liveVideoUploadEnabled;
    self.pickerController.liveVideoUploadEnabled = liveVideoUploadEnabled;
}

- (void)setLocalMediaCacheEnabled:(bool)localMediaCacheEnabled
{
    _localMediaCacheEnabled = localMediaCacheEnabled;
    self.pickerController.localMediaCacheEnabled = localMediaCacheEnabled;
}

- (void)setShouldStoreAssets:(bool)shouldStoreAssets
{
    _shouldStoreAssets = shouldStoreAssets;
    self.pickerController.shouldStoreAssets = shouldStoreAssets;
}

- (void)setRecipientName:(NSString *)recipientName
{
    _recipientName = recipientName;
    self.pickerController.recipientName = recipientName;
}

- (void)setHasTimer:(bool)hasTimer
{
    _hasTimer = hasTimer;
    self.pickerController.hasTimer = hasTimer;
}

- (TGMediaAssetsPickerController *)pickerController
{
    TGMediaAssetsPickerController *pickerController = nil;
    for (TGViewController *viewController in self.viewControllers)
    {
        if ([viewController isKindOfClass:[TGMediaAssetsPickerController class]])
        {
            pickerController = (TGMediaAssetsPickerController *)viewController;
            break;
        }
    }
    return pickerController;
}

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context intent:(TGMediaAssetsControllerIntent)intent saveEditedPhotos:(bool)saveEditedPhotos allowGrouping:(bool)allowGrouping
{
    self = [super initWithNavigationBarClass:[TGNavigationBar class] toolbarClass:[UIToolbar class]];
    if (self != nil)
    {
        _context = context;
        _saveEditedPhotos = saveEditedPhotos;
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        self.delegate = self;
        _intent = intent;
        _assetsLibrary = [TGMediaAssetsLibrary libraryForAssetType:[TGMediaAssetsController assetTypeForIntent:intent]];
        
        __weak TGMediaAssetsController *weakSelf = self;
        _selectionContext = [[TGMediaSelectionContext alloc] initWithGroupingAllowed:allowGrouping];
        if (allowGrouping)
            _selectionContext.grouping = ![[[NSUserDefaults standardUserDefaults] objectForKey:@"TG_mediaGroupingDisabled_v0"] boolValue];
        [_selectionContext setItemSourceUpdatedSignal:[_assetsLibrary libraryChanged]];
        _selectionContext.updatedItemsSignal = ^SSignal *(NSArray *items)
        {
            __strong TGMediaAssetsController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return nil;
            
            return [strongSelf->_assetsLibrary updatedAssetsForAssets:items];
        };
        
        bool (^updateGroupingButtonVisibility)(void) = ^bool
        {
            __strong TGMediaAssetsController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return false;
            
            bool onlyGroupableMedia = true;
            for (TGMediaAsset *asset in strongSelf->_selectionContext.selectedItems)
            {
                if (asset.type == TGMediaAssetGifType)
                {
                    onlyGroupableMedia = false;
                    break;
                }
                else
                {
                    if ([[strongSelf->_editingContext timerForItem:asset] integerValue] > 0)
                    {
                        onlyGroupableMedia = false;
                        break;
                    }
                    
                    id<TGMediaEditAdjustments> adjustments = [strongSelf->_editingContext adjustmentsForItem:asset];
                    if ([adjustments isKindOfClass:[TGMediaVideoEditAdjustments class]] && ((TGMediaVideoEditAdjustments *)adjustments).sendAsGif)
                    {
                        onlyGroupableMedia = false;
                        break;
                    }
                }
            }
            
            bool groupingButtonVisible = strongSelf->_selectionContext.allowGrouping && onlyGroupableMedia && strongSelf->_selectionContext.count > 1;
            [strongSelf->_toolbarView setCenterButtonHidden:!groupingButtonVisible animated:true];
            
            return groupingButtonVisible;
        };
        
        _selectionChangedDisposable = [[SMetaDisposable alloc] init];
        [_selectionChangedDisposable setDisposable:[[_selectionContext selectionChangedSignal] startWithNext:^(__unused id next)
        {
            __strong TGMediaAssetsController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            bool groupingButtonVisible = updateGroupingButtonVisibility();
            [strongSelf->_toolbarView setSelectedCount:strongSelf->_selectionContext.count animated:true];
            [strongSelf->_toolbarView setRightButtonEnabled:strongSelf->_selectionContext.count > 0 animated:false];
            
            if (groupingButtonVisible && [strongSelf shouldDisplayTooltip] && strongSelf->_selectionContext.grouping)
                [strongSelf setupTooltip:[strongSelf->_toolbarView convertRect:strongSelf->_toolbarView.centerButton.frame toView:strongSelf.view]];
        }]];
        
        if (intent == TGMediaAssetsControllerSendMediaIntent || intent == TGMediaAssetsControllerSetProfilePhotoIntent)
            _editingContext = [[TGMediaEditingContext alloc] init];
        else if (intent == TGMediaAssetsControllerSendFileIntent)
            _editingContext = [TGMediaEditingContext contextForCaptionsOnly];
        
        if (allowGrouping)
        {
            _groupingChangedDisposable = [[SMetaDisposable alloc] init];
            [_groupingChangedDisposable setDisposable:[_selectionContext.groupingChangedSignal startWithNext:^(NSNumber *next)
            {
                __strong TGMediaAssetsController *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                [strongSelf->_toolbarView setCenterButtonSelected:next.boolValue];
            }]];
            
            if (_editingContext != nil)
            {
                _timersChangedDisposable = [[SMetaDisposable alloc] init];
                [_timersChangedDisposable setDisposable:[_editingContext.timersUpdatedSignal startWithNext:^(__unused NSNumber *next)
                {
                    updateGroupingButtonVisibility();
                }]];
                
                _adjustmentsChangedDisposable = [[SMetaDisposable alloc] init];
                [_adjustmentsChangedDisposable setDisposable:[_editingContext.adjustmentsUpdatedSignal startWithNext:^(__unused NSNumber *next)
                {
                    updateGroupingButtonVisibility();
                }]];
            }
        }
    }
    return self;
}

- (void)dealloc
{
    self.delegate = nil;
    [_selectionChangedDisposable dispose];
    [_tooltipDismissDisposable dispose];
}

- (void)loadView
{
    [super loadView];
    
    CGFloat inset = [TGViewController safeAreaInsetForOrientation:self.interfaceOrientation].bottom;
    _toolbarView = [[TGMediaPickerToolbarView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - TGMediaPickerToolbarHeight - inset, self.view.frame.size.width, TGMediaPickerToolbarHeight + inset)];
    _toolbarView.safeAreaInset = [TGViewController safeAreaInsetForOrientation:self.interfaceOrientation];
    _toolbarView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    if (_intent != TGMediaAssetsControllerSendFileIntent && _intent != TGMediaAssetsControllerSendMediaIntent)
        [_toolbarView setRightButtonHidden:true];
    if (_selectionContext.allowGrouping)
    {
        [_toolbarView setCenterButtonImage:TGTintedImage(TGComponentsImageNamed(@"MediaPickerGroupPhotosIcon"), UIColorRGB(0x858e99))];
        [_toolbarView setCenterButtonSelectedImage:TGComponentsImageNamed(@"MediaPickerGroupPhotosIcon")];
        [_toolbarView setCenterButtonHidden:true animated:false];
        [_toolbarView setCenterButtonSelected:_selectionContext.grouping];
        
        __weak TGMediaAssetsController *weakSelf = self;
        _toolbarView.centerPressed = ^
        {
            __strong TGMediaAssetsController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf groupPhotosPressed];
        };
    }
    [self.view addSubview:_toolbarView];
}

- (void)viewDidLoad
{
    __weak TGMediaAssetsController *weakSelf = self;
    _toolbarView.leftPressed = ^
    {
        __strong TGMediaAssetsController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf dismiss];
    };
    
    _toolbarView.rightPressed = ^
    {
        __strong TGMediaAssetsController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf completeWithCurrentItem:nil];
    };
}

- (void)groupPhotosPressed
{
    [_selectionContext toggleGrouping];
    
    [self showGroupingTooltip:_selectionContext.grouping duration:2.5];
}

- (void)dismiss
{
    if (self.dismissalBlock != nil)
        self.dismissalBlock();
    
    [_editingContext clearPaintingData];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
    if (self.view.frame.size.width > self.view.frame.size.height)
        orientation = UIInterfaceOrientationLandscapeLeft;
    _toolbarView.safeAreaInset = [TGViewController safeAreaInsetForOrientation:orientation];
    
    if (_searchController == nil)
        return;
    
    CGSize screenSize = TGScreenSize();
    UIView *view = _searchController.view;
    
    CGRect frame = view.frame;
    if (ABS(frame.size.width - screenSize.width) < FLT_EPSILON)
    {
        if (ABS(frame.size.height - screenSize.height + 20) < FLT_EPSILON)
        {
            frame.origin.y = frame.size.height - screenSize.height;
            frame.size.height = screenSize.height;
        }
        else if (frame.size.height > screenSize.height + FLT_EPSILON)
        {
            frame.origin.y = 0;
            frame.size.height = screenSize.height;
        }
    }
    else if (ABS(frame.size.width - screenSize.height) < FLT_EPSILON)
    {
        if (frame.size.height > screenSize.width + FLT_EPSILON)
        {
            frame.origin.y = 0;
            frame.size.height = screenSize.width;
        }
    }
    
    if (ABS(frame.size.height) < FLT_EPSILON)
    {
        frame.size.height = screenSize.height;
    }
    
    if (!CGRectEqualToRect(view.frame, frame))
        view.frame = frame;

    [_searchController.view.superview bringSubviewToFront:_searchController.view];
}

#pragma mark -

- (void)completeWithAvatarImage:(UIImage *)image
{
    if (self.avatarCompletionBlock != nil)
        self.avatarCompletionBlock(image);
}

- (void)completeWithCurrentItem:(TGMediaAsset *)currentItem
{
    NSArray *signals = [self resultSignalsWithCurrentItem:currentItem descriptionGenerator:self.descriptionGenerator];
    if (self.completionBlock != nil)
        self.completionBlock(signals);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_intent == TGMediaAssetsControllerSendFileIntent && self.shouldShowFileTipIfNeeded && iosMajorVersion() >= 7)
    {
        if (![[[NSUserDefaults standardUserDefaults] objectForKey:@"didShowDocumentPickerTip_v2"] boolValue])
        {
            [[NSUserDefaults standardUserDefaults] setObject:@true forKey:@"didShowDocumentPickerTip_v2"];
            
            TGMediaAssetsTipView *tipView = [[TGMediaAssetsTipView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.bounds.size.width, self.view.bounds.size.height)];
            tipView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self.navigationController.view addSubview:tipView];
        }
    }
}

- (NSArray *)resultSignalsWithCurrentItem:(TGMediaAsset *)currentItem descriptionGenerator:(id (^)(id, NSString *, NSString *))descriptionGenerator
{
    bool storeAssets = (_editingContext != nil) && self.shouldStoreAssets;
    
    if (_intent == TGMediaAssetsControllerSendMediaIntent)
        [[NSUserDefaults standardUserDefaults] setObject:@(!_selectionContext.grouping) forKey:@"TG_mediaGroupingDisabled_v0"];
    
    return [TGMediaAssetsController resultSignalsForSelectionContext:_selectionContext editingContext:_editingContext intent:_intent currentItem:currentItem storeAssets:storeAssets useMediaCache:self.localMediaCacheEnabled descriptionGenerator:descriptionGenerator saveEditedPhotos:_saveEditedPhotos];
}

+ (int64_t)generateGroupedId
{
    int64_t value;
    arc4random_buf(&value, sizeof(int64_t));
    return value;
}

+ (NSArray *)resultSignalsForSelectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext intent:(TGMediaAssetsControllerIntent)intent currentItem:(TGMediaAsset *)currentItem storeAssets:(bool)storeAssets useMediaCache:(bool)__unused useMediaCache descriptionGenerator:(id (^)(id, NSString *, NSString *))descriptionGenerator saveEditedPhotos:(bool)saveEditedPhotos
{
    NSMutableArray *signals = [[NSMutableArray alloc] init];
    NSMutableArray *selectedItems = [selectionContext.selectedItems mutableCopy];
    if (selectedItems.count == 0 && currentItem != nil)
        [selectedItems addObject:currentItem];
    
    if (saveEditedPhotos && storeAssets)
    {
        NSMutableArray *fullSizeSignals = [[NSMutableArray alloc] init];
        for (TGMediaAsset *asset in selectedItems)
        {
            if ([editingContext timerForItem:asset] == nil)
                [fullSizeSignals addObject:[editingContext fullSizeImageUrlForItem:asset]];
        }
        
        SSignal *combinedSignal = nil;
        SQueue *queue = [SQueue concurrentDefaultQueue];
        
        for (SSignal *signal in fullSizeSignals)
        {
            if (combinedSignal == nil)
                combinedSignal = [signal startOn:queue];
            else
                combinedSignal = [[combinedSignal then:signal] startOn:queue];
        }
        
        [[[[combinedSignal deliverOn:[SQueue mainQueue]] filter:^bool(id result)
        {
            return [result isKindOfClass:[NSURL class]];
        }] mapToSignal:^SSignal *(NSURL *url)
        {
            return [[TGMediaAssetsLibrary sharedLibrary] saveAssetWithImageAtUrl:url];
        }] startWithNext:nil];
    }
    
    static dispatch_once_t onceToken;
    static UIImage *blankImage;
    dispatch_once(&onceToken, ^
    {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, 1), true, 0.0f);
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
        CGContextFillRect(context, CGRectMake(0, 0, 1, 1));
        
        blankImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    
    CGSize fallbackThumbnailImageSize = CGSizeMake(256, 256);
    SSignal *(^inlineThumbnailSignal)(TGMediaAsset *) = ^SSignal *(TGMediaAsset *asset)
    {
        return [[[TGMediaAssetImageSignals imageForAsset:asset imageType:TGMediaAssetImageTypeAspectRatioThumbnail size:fallbackThumbnailImageSize allowNetworkAccess:false] takeLast] catch:^SSignal *(id error)
        {
            if ([error respondsToSelector:@selector(boolValue)] && [error boolValue]) {
                return [[TGMediaAssetImageSignals imageForAsset:asset imageType:TGMediaAssetImageTypeAspectRatioThumbnail size:fallbackThumbnailImageSize allowNetworkAccess:true] takeLast];
            } else {
                return [SSignal single:blankImage];
            }
        }];
    };
    
    NSNumber *groupedId;
    NSInteger i = 0;
    if (selectionContext.grouping && selectedItems.count > 1)
        groupedId = @([self generateGroupedId]);
    
    bool hasAnyTimers = false;
    if (editingContext != nil)
    {
        for (TGMediaAsset *asset in selectedItems)
        {
            if ([editingContext timerForItem:asset] != nil)
            {
                hasAnyTimers = true;
                break;
            }
        }
    }
    
    for (TGMediaAsset *asset in selectedItems)
    {
        switch (asset.type)
        {
            case TGMediaAssetPhotoType:
            {
                if (intent == TGMediaAssetsControllerSendFileIntent)
                {
                    NSString *caption = [editingContext captionForItem:asset];
                    
                    [signals addObject:[[[TGMediaAssetImageSignals imageDataForAsset:asset allowNetworkAccess:false] map:^NSDictionary *(TGMediaAssetImageData *assetData)
                    {
                        NSString *tempFileName = TGTemporaryFileName(nil);
                        [assetData.imageData writeToURL:[NSURL fileURLWithPath:tempFileName] atomically:true];
                        
                        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                        dict[@"type"] = @"file";
                        dict[@"tempFileUrl"] = [NSURL fileURLWithPath:tempFileName];
                        dict[@"fileName"] = assetData.fileName;
                        dict[@"mimeType"] = TGMimeTypeForFileUTI(assetData.fileUTI);
                        
                        id generatedItem = descriptionGenerator(dict, caption, nil);
                        return generatedItem;
                    }] catch:^SSignal *(id error)
                    {
                        if (![error isKindOfClass:[NSNumber class]])
                            return [SSignal complete];
                        
                        return [inlineThumbnailSignal(asset) map:^id(UIImage *image)
                        {
                            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                            dict[@"type"] = @"cloudPhoto";
                            dict[@"document"] = @true;
                            dict[@"asset"] = asset;
                            dict[@"previewImage"] = image;
                            dict[@"mimeType"] = TGMimeTypeForFileUTI(asset.uniformTypeIdentifier);
                            dict[@"fileName"] = asset.fileName;
                            
                            id generatedItem = descriptionGenerator(dict, nil, nil);
                            return generatedItem;
                        }];
                    }]];
                }
                else
                {
                    NSString *caption = [editingContext captionForItem:asset];
                    id<TGMediaEditAdjustments> adjustments = [editingContext adjustmentsForItem:asset];
                    NSNumber *timer = [editingContext timerForItem:asset];
                    
                    SSignal *inlineSignal = [inlineThumbnailSignal(asset) map:^id(UIImage *image)
                    {
                        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                        dict[@"type"] = @"cloudPhoto";
                        dict[@"document"] = @false;
                        dict[@"asset"] = asset;
                        dict[@"previewImage"] = image;
                        
                        if (timer != nil)
                            dict[@"timer"] = timer;
                        else if (groupedId != nil && !hasAnyTimers)
                            dict[@"groupedId"] = groupedId;
                        
                        id generatedItem = descriptionGenerator(dict, caption, nil);
                        return generatedItem;
                    }];
                    
                    SSignal *assetSignal = inlineSignal;
                    SSignal *imageSignal = assetSignal;
                    if (editingContext != nil)
                    {
                        imageSignal = [[[[[editingContext imageSignalForItem:asset withUpdates:true] filter:^bool(id result)
                        {
                            return result == nil || ([result isKindOfClass:[UIImage class]] && !((UIImage *)result).degraded);
                        }] take:1] mapToSignal:^SSignal *(id result)
                        {
                            if (result == nil)
                            {
                                return [SSignal fail:nil];
                            }
                            else if ([result isKindOfClass:[UIImage class]])
                            {
                                UIImage *image = (UIImage *)result;
                                image.edited = true;
                                return [SSignal single:image];
                            }

                            return [SSignal complete];
                        }] onCompletion:^
                        {
                            __strong TGMediaEditingContext *strongEditingContext = editingContext;
                            [strongEditingContext description];
                        }];
                    }
                    
                    [signals addObject:[[imageSignal map:^NSDictionary *(UIImage *image)
                    {
                        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                        dict[@"type"] = @"editedPhoto";
                        dict[@"image"] = image;
                        
                        if (adjustments.paintingData.stickers.count > 0)
                            dict[@"stickers"] = adjustments.paintingData.stickers;
                        
                        if (timer != nil)
                            dict[@"timer"] = timer;
                        else if (groupedId != nil && !hasAnyTimers)
                            dict[@"groupedId"] = groupedId;
                        
                        id generatedItem = descriptionGenerator(dict, caption, nil);
                        return generatedItem;
                    }] catch:^SSignal *(__unused id error)
                    {
                        return inlineSignal;
                    }]];
                    
                    i++;
                }
            }
                break;
                
            case TGMediaAssetVideoType:
            {
                if (intent == TGMediaAssetsControllerSendFileIntent)
                {
                    NSString *caption = [editingContext captionForItem:asset];
                    id<TGMediaEditAdjustments> adjustments = [editingContext adjustmentsForItem:asset];
                    
                    [signals addObject:[inlineThumbnailSignal(asset) map:^id(UIImage *image)
                    {
                        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                        dict[@"type"] = @"video";
                        dict[@"document"] = @true;
                        dict[@"asset"] = asset;
                        dict[@"previewImage"] = image;
                        dict[@"fileName"] = asset.fileName;
                        
                        if (adjustments.paintingData.stickers.count > 0)
                            dict[@"stickers"] = adjustments.paintingData.stickers;
                        
                        id generatedItem = descriptionGenerator(dict, caption, nil);
                        return generatedItem;
                    }]];
                }
                else
                {
                    TGVideoEditAdjustments *adjustments = (TGVideoEditAdjustments *)[editingContext adjustmentsForItem:asset];
                    NSString *caption = [editingContext captionForItem:asset];
                    NSNumber *timer = [editingContext timerForItem:asset];
                    
                    UIImage *(^cropVideoThumbnail)(UIImage *, CGSize, CGSize, bool) = ^UIImage *(UIImage *image, CGSize targetSize, CGSize sourceSize, bool resize)
                    {
                        if ([adjustments cropAppliedForAvatar:false] || adjustments.hasPainting)
                        {
                            CGRect scaledCropRect = CGRectMake(adjustments.cropRect.origin.x * image.size.width / adjustments.originalSize.width, adjustments.cropRect.origin.y * image.size.height / adjustments.originalSize.height, adjustments.cropRect.size.width * image.size.width / adjustments.originalSize.width, adjustments.cropRect.size.height * image.size.height / adjustments.originalSize.height);
                            return TGPhotoEditorCrop(image, adjustments.paintingData.image, adjustments.cropOrientation, 0, scaledCropRect, adjustments.cropMirrored, targetSize, sourceSize, resize);
                        }
                        
                        return image;
                    };
                    
                    SSignal *trimmedVideoThumbnailSignal = [[TGMediaAssetImageSignals avAssetForVideoAsset:asset allowNetworkAccess:false] mapToSignal:^SSignal *(AVAsset *avAsset)
                    {
                        CGSize imageSize = TGFillSize(asset.dimensions, CGSizeMake(384, 384));
                        return [[TGMediaAssetImageSignals videoThumbnailForAVAsset:avAsset size:imageSize timestamp:CMTimeMakeWithSeconds(adjustments.trimStartValue, NSEC_PER_SEC)] map:^UIImage *(UIImage *image)
                        {
                            return cropVideoThumbnail(image, TGScaleToFill(asset.dimensions, CGSizeMake(256, 256)), asset.dimensions, true);
                        }];
                    }];
                    
                    SSignal *videoThumbnailSignal = [inlineThumbnailSignal(asset) map:^UIImage *(UIImage *image)
                    {
                        return cropVideoThumbnail(image, image.size, image.size, false);
                    }];
                    
                    SSignal *thumbnailSignal = adjustments.trimStartValue > FLT_EPSILON ? trimmedVideoThumbnailSignal : videoThumbnailSignal;
                    
                    [signals addObject:[thumbnailSignal map:^id(UIImage *image)
                    {
                        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                        dict[@"type"] = @"video";
                        dict[@"document"] = @false;
                        dict[@"asset"] = asset;
                        dict[@"previewImage"] = image;
                        dict[@"adjustments"] = adjustments;
                        
                        if (adjustments.paintingData.stickers.count > 0)
                            dict[@"stickers"] = adjustments.paintingData.stickers;
                        
                        if (timer != nil)
                            dict[@"timer"] = timer;
                        else if (groupedId != nil && !hasAnyTimers)
                            dict[@"groupedId"] = groupedId;
                        
                        id generatedItem = descriptionGenerator(dict, caption, nil);
                        return generatedItem;
                    }]];
                    
                    i++;
                }
            }
                break;
                
            case TGMediaAssetGifType:
            {
                NSString *caption = editingContext ? [editingContext captionForItem:asset] : nil;

                [signals addObject:[[[TGMediaAssetImageSignals imageDataForAsset:asset allowNetworkAccess:false] mapToSignal:^SSignal *(TGMediaAssetImageData *assetData)
                {
                    NSString *tempFileName = TGTemporaryFileName(nil);
                    NSData *data = assetData.imageData;
                    
                    const char *gif87Header = "GIF87";
                    const char *gif89Header = "GIF89";
                    if (data.length >= 5 && (!memcmp(data.bytes, gif87Header, 5) || !memcmp(data.bytes, gif89Header, 5)))
                    {
                        return [[TGGifConverter convertGifToMp4:data] map:^id(NSString *filePath)
                        {
                            NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                            dict[@"type"] = @"file";
                            dict[@"tempFileUrl"] = [NSURL fileURLWithPath:filePath];
                            dict[@"fileName"] = @"animation.mp4";
                            dict[@"mimeType"] = @"video/mp4";
                            dict[@"isAnimation"] = @true;
                            
                            id generatedItem = descriptionGenerator(dict, caption, nil);
                            return generatedItem;
                        }];
                    }
                    else
                    {
                        [data writeToURL:[NSURL fileURLWithPath:tempFileName] atomically:true];
                        
                        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                        dict[@"type"] = @"file";
                        dict[@"tempFileUrl"] = [NSURL fileURLWithPath:tempFileName];
                        dict[@"fileName"] = assetData.fileName;
                        dict[@"mimeType"] = TGMimeTypeForFileUTI(assetData.fileUTI);
                        
                        id generatedItem = descriptionGenerator(dict, caption, nil);
                        return [SSignal single:generatedItem];
                    }
                }] catch:^SSignal *(id error)
                {
                    if (![error isKindOfClass:[NSNumber class]])
                        return [SSignal complete];
                    
                    return [inlineThumbnailSignal(asset) map:^id(UIImage *image)
                    {
                        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                        dict[@"type"] = @"cloudPhoto";
                        dict[@"document"] = @true;
                        dict[@"asset"] = asset;
                        dict[@"previewImage"] = image;
                        
                        id generatedItem = descriptionGenerator(dict, caption, nil);
                        return generatedItem;
                    }];
                }]];
            }
                break;
                
            default:
                break;
        }
        
        if (groupedId != nil && i == 10)
        {
            i = 0;
            groupedId = @([self generateGroupedId]);
        }
    }
    return signals;
}

#pragma mark -

- (UIBarButtonItem *)rightBarButtonItem
{
    if (_intent == TGMediaAssetsControllerSendFileIntent)
        return nil;
    
    if (iosMajorVersion() < 7)
    {
        TGModernBarButton *searchButton = [[TGModernBarButton alloc] initWithImage:TGComponentsImageNamed(@"NavigationSearchIcon.png")];
        searchButton.portraitAdjustment = CGPointMake(-7, -5);
        [searchButton addTarget:self action:@selector(searchButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        return [[UIBarButtonItem alloc] initWithCustomView:searchButton];
    }
    
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchButtonPressed)];
}

- (void)searchButtonPressed
{
    if (self.requestSearchController) {
        _searchController = self.requestSearchController();
    }
    /*TGWebSearchController *searchController = [[TGWebSearchController alloc] initWithContext:[TGLegacyComponentsContext shared] forAvatarSelection:(_intent == TGMediaAssetsControllerSetProfilePhotoIntent) embedded:true];
    searchController.captionsEnabled = self.captionsEnabled;
    searchController.suggestionContext = self.suggestionContext;

    __weak TGWebSearchController *weakController = searchController;
    searchController.avatarCompletionBlock = ^(UIImage *image)
    {
        TGMediaAssetsController *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf.avatarCompletionBlock == nil)
            return;
        
        strongSelf.avatarCompletionBlock(image);
    };
    searchController.completionBlock = ^(__unused TGWebSearchController *sender)
    {
        TGMediaAssetsController *strongSelf = weakSelf;
        if (strongSelf == nil || strongSelf.completionBlock == nil)
            return;
        
        __strong TGWebSearchController *strongController = weakController;
        if (strongController == nil)
            return;
        
        NSDictionary *(^descriptionGenerator)(id, NSString *) = ^(id result, NSString *caption)
        {
            return strongSelf.descriptionGenerator(result, caption, nil);
        };
        
        strongSelf.completionBlock([strongController selectedItemSignals:descriptionGenerator]);
    };
    searchController.dismiss = ^
    {
        __strong TGWebSearchController *strongController = weakController;
        if (strongController == nil)
            return;
        
        [strongController dismissEmbeddedAnimated:true];
    };
    searchController.parentNavigationController = self;
    [searchController presentEmbeddedInController:self animated:true];

    _searchController = searchController;*/
}

- (void)navigationController:(UINavigationController *)__unused navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)__unused animated
{
    if (_searchController == nil)
        return;
    
    UIView *backArrow = [self _findBackArrow:self.navigationBar];
    UIView *backButton = [self _findBackButton:self.navigationBar parentView:self.navigationBar];
    
    if ([viewController isKindOfClass:[TGPhotoEditorController class]])
    {
        backArrow.alpha = 0.0f;
        backButton.alpha = 0.0f;
        
        _searchSnapshotView = [_searchController.view snapshotViewAfterScreenUpdates:false];
        _searchSnapshotView.frame = CGRectOffset([_searchController.view convertRect:_searchController.view.frame toView:self.navigationBar], -_searchSnapshotView.frame.size.width, 0);
        [self.navigationBar addSubview:_searchSnapshotView];
        _searchController.view.hidden = true;
    }
    else if ([viewController isKindOfClass:[TGMediaAssetsPickerController class]])
    {
        [_searchSnapshotView.superview bringSubviewToFront:_searchSnapshotView];
        
        backArrow.alpha = 0.0f;
        backButton.alpha = 0.0f;
    }
}

- (void)navigationController:(UINavigationController *)__unused navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)__unused animated
{
    if (_searchController == nil)
        return;
    
    if ([viewController isKindOfClass:[TGMediaAssetsPickerController class]])
    {
        [_searchSnapshotView removeFromSuperview];
        _searchSnapshotView = nil;
        _searchController.view.hidden = false;
        
        UIView *backArrow = [self _findBackArrow:self.navigationBar];
        UIView *backButton = [self _findBackButton:self.navigationBar parentView:self.navigationBar];
        backArrow.alpha = 1.0f;
        backButton.alpha = 1.0f;
    }
}

- (UIView *)_findBackArrow:(UIView *)view
{
    Class backArrowClass = NSClassFromString(TGEncodeText(@"`VJObwjhbujpoCbsCbdlJoejdbupsWjfx", -1));
    
    if ([view isKindOfClass:backArrowClass])
        return view;
    
    for (UIView *subview in view.subviews)
    {
        UIView *result = [self _findBackArrow:subview];
        if (result != nil)
            return result;
    }
    
    return nil;
}

- (UIView *)_findBackButton:(UIView *)view parentView:(UIView *)parentView
{
    Class backButtonClass = NSClassFromString(TGEncodeText(@"VJObwjhbujpoJufnCvuupoWjfx", -1));
    
    if ([view isKindOfClass:backButtonClass])
    {
        if (view.center.x < parentView.frame.size.width / 2.0f)
            return view;
    }
    
    for (UIView *subview in view.subviews)
    {
        UIView *result = [self _findBackButton:subview parentView:parentView];
        if (result != nil)
            return result;
    }
    
    return nil;
}

#pragma mark -

+ (TGMediaAssetType)assetTypeForIntent:(TGMediaAssetsControllerIntent)intent
{
    TGMediaAssetType assetType = TGMediaAssetAnyType;
    
    switch (intent)
    {
        case TGMediaAssetsControllerSetProfilePhotoIntent:
        case TGMediaAssetsControllerSetCustomWallpaperIntent:
            assetType = TGMediaAssetPhotoType;
            break;
            
        case TGMediaAssetsControllerSendMediaIntent:
            assetType = TGMediaAssetAnyType;
            break;
            
        default:
            break;
    }
    
    return assetType;
}

#pragma mark - Grouping Tooltip

- (bool)shouldDisplayTooltip
{
    return ![[[NSUserDefaults standardUserDefaults] objectForKey:@"TG_displayedGroupTooltip_v0"] boolValue];
}

- (void)setupTooltip:(CGRect)rect
{
    if (_tooltipContainerView != nil)
        return;
    
    rect = CGRectOffset(rect, 0.0f, 15.0f);
    
    _tooltipTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(tooltipTimerTick) interval:3.0 repeat:false];
    
    _tooltipContainerView = [[TGMenuContainerView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height)];
    [self.view addSubview:_tooltipContainerView];
    
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    [actions addObject:[[NSDictionary alloc] initWithObjectsAndKeys:TGLocalized(@"MediaPicker.TapToUngroupDescription"), @"title", nil]];
    
    [_tooltipContainerView.menuView setButtonsAndActions:actions watcherHandle:_actionHandle];
    [_tooltipContainerView.menuView sizeToFit];
    _tooltipContainerView.menuView.buttonHighlightDisabled = true;
    
    [_tooltipContainerView showMenuFromRect:rect animated:false];
    
    [[NSUserDefaults standardUserDefaults] setObject:@true forKey:@"TG_displayedGroupTooltip_v0"];
}

- (void)tooltipTimerTick
{
    [_tooltipTimer invalidate];
    _tooltipTimer = nil;
    
    [_tooltipContainerView hideMenu];
}

- (void)actionStageActionRequested:(NSString *)action options:(id)__unused options
{
    if ([action isEqualToString:@"menuAction"])
    {
        [_tooltipTimer invalidate];
        _tooltipTimer = nil;
        
        [_tooltipContainerView hideMenu];
    }
}

- (void)showGroupingTooltip:(bool)grouped duration:(NSTimeInterval)duration
{
    NSString *tooltipText = TGLocalized(grouped ? @"MediaPicker.GroupDescription" : @"MediaPicker.UngroupDescription");
    
    if (_groupingTooltipContainerView.isShowingTooltip && _groupingTooltipContainerView.tooltipView.sourceView == _toolbarView.centerButton)
    {
        [_groupingTooltipContainerView.tooltipView setText:tooltipText animated:true];
    }
    else
    {
        [_tooltipContainerView removeFromSuperview];
        [_groupingTooltipContainerView removeFromSuperview];
        
        _groupingTooltipContainerView = [[TGTooltipContainerView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height)];
        [self.view addSubview:_groupingTooltipContainerView];
        
        [_groupingTooltipContainerView.tooltipView setText:tooltipText animated:false];
        _groupingTooltipContainerView.tooltipView.sourceView = _toolbarView.centerButton;
        
        CGRect recordButtonFrame = [_toolbarView convertRect:_toolbarView.centerButton.frame toView:_groupingTooltipContainerView];
        recordButtonFrame.origin.y += 15.0f;
        [_groupingTooltipContainerView showTooltipFromRect:recordButtonFrame animated:false];
    }
    
    if (_tooltipDismissDisposable == nil)
        _tooltipDismissDisposable = [[SMetaDisposable alloc] init];
    
    __weak TGTooltipContainerView *weakContainerView = _groupingTooltipContainerView;
    [_tooltipDismissDisposable setDisposable:[[[SSignal complete] delay:duration onQueue:[SQueue mainQueue]] startWithNext:nil completed:^{
        __strong TGTooltipContainerView *strongContainerView = weakContainerView;
        if (strongContainerView != nil)
            [strongContainerView hideTooltip];
    }]];
}

- (BOOL)prefersStatusBarHidden
{
    return !TGIsPad() && iosMajorVersion() >= 11 && UIInterfaceOrientationIsLandscape([[LegacyComponentsGlobals provider] applicationStatusBarOrientation]);
}

- (bool)allowGrouping
{
    return _selectionContext.allowGrouping;
}

@end
