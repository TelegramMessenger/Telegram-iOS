#import "TGMediaAssetsPickerController.h"

#import <Photos/Photos.h>
#import <PhotosUI/PhotosUI.h>
#import "LegacyComponentsInternal.h"

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

#import <LegacyComponents/TGMediaAsset+TGMediaEditableItem.h>
#import <LegacyComponents/TGMediaAssetImageSignals.h>

#import <LegacyComponents/TGPhotoEditorController.h>

#import <LegacyComponents/TGVideoEditAdjustments.h>
#import <LegacyComponents/TGPaintingData.h>

#import "TGModernButton.h"
#import "PGPhotoEditor.h"

@interface TGMediaPickerAccessView: UIView
{
    TGMediaAssetsPallete *_pallete;
    
    UIView *_backgroundView;
    UIView *_separatorView;
    UIView *_bottomSeparatorView;
    UIImageView *_iconView;
    UILabel *_labelView;
    UILabel *_titleView;
    UILabel *_textView;
    TGModernButton * _buttonView;
    
    CGSize _titleSize;
    CGSize _textSize;
}

@property (nonatomic, assign) UIEdgeInsets safeAreaInset;

@property (nonatomic, copy) void (^pressed)(void);

@end

@implementation TGMediaPickerAccessView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _backgroundView = [[UIView alloc] init];
        _separatorView = [[UIView alloc] init];
        _bottomSeparatorView = [[UIView alloc] init];
        _iconView = [[UIImageView alloc] init];
        _labelView = [[UILabel alloc] init];
        _titleView = [[UILabel alloc] init];
        _textView = [[UILabel alloc] init];
        
        _labelView.font = TGSystemFontOfSize(14.0);
        _labelView.text = @"!";
        _labelView.textAlignment = NSTextAlignmentCenter;
        
        _titleView.font = TGSemiboldSystemFontOfSize(17.0);
        _titleView.text = TGLocalized(@"Media.LimitedAccessTitle");
        _titleView.numberOfLines = 1;
        
        _textView.font = TGSystemFontOfSize(14.0);
        _textView.text = TGLocalized(@"Media.LimitedAccessText");
        _textView.numberOfLines = 3;
        
        _buttonView = [[TGModernButton alloc] init];
        _buttonView.adjustsImageWhenHighlighted = false;
        _buttonView.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        _buttonView.contentEdgeInsets = UIEdgeInsetsMake(0.0, 15.0, 0.0, 0.0);
        _buttonView.titleLabel.font = TGSystemFontOfSize(17.0f);
        _buttonView.highlightBackgroundColor = UIColorRGB(0xebebeb);
        [_buttonView setTitle:TGLocalized(@"Media.LimitedAccessManage") forState:UIControlStateNormal];
        [_buttonView addTarget:self action:@selector(buttonPressed) forControlEvents:UIControlEventTouchUpInside];
        
        [self addSubview:_backgroundView];
        [self addSubview:_separatorView];
        [self addSubview:_bottomSeparatorView];
        [self addSubview:_iconView];
        [self addSubview:_labelView];
        [self addSubview:_titleView];
        [self addSubview:_textView];
        [self addSubview:_buttonView];
    }
    return self;
}

- (void)buttonPressed {
    self.pressed();
}

- (void)setPallete:(TGMediaAssetsPallete *)pallete {
    _pallete = pallete;
    
    _backgroundView.backgroundColor = pallete.backgroundColor;
    _separatorView.backgroundColor = pallete.separatorColor;
    _bottomSeparatorView.backgroundColor = pallete.separatorColor;
    _titleView.textColor = pallete.textColor;
    _textView.textColor = pallete.textColor;
    _iconView.image = TGCircleImage(20.0, pallete.destructiveColor);
    _labelView.textColor = pallete.badgeTextColor;
    _buttonView.highlightBackgroundColor = pallete.selectionColor;
    
    [_buttonView setTitleColor:pallete.accentColor];
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize result = CGSizeMake(size.width, 0.0);
    
    CGSize constrainedSize = CGSizeMake(size.width - 30.0, size.height);
    CGSize titleSize = [_titleView sizeThatFits:constrainedSize];
    CGSize textSize = [_textView sizeThatFits:constrainedSize];
    
    result.height += titleSize.height;
    result.height += textSize.height;
    result.height += 45.0;
    result.height += 39.0;
    result.height = CGFloor(result.height);
    
    _titleSize = titleSize;
    _textSize = textSize;
    
    return result;
}

- (void)setSafeAreaInset:(UIEdgeInsets)safeAreaInset {
    _safeAreaInset = safeAreaInset;
    [self layoutSubviews];
}

- (void)layoutSubviews {
    _backgroundView.frame = self.bounds;
    
    _iconView.frame = CGRectMake(self.safeAreaInset.left + 15.0, 16.0, 20.0, 20.0);
    _labelView.frame = _iconView.frame;
    
    _buttonView.contentEdgeInsets = UIEdgeInsetsMake(0.0, self.safeAreaInset.left + 15.0, 0.0, 0.0);
    _titleView.frame = CGRectMake(self.safeAreaInset.left + 42.0, 15.0, _titleSize.width, _titleSize.height);
    _textView.frame = CGRectMake(self.safeAreaInset.left + 15.0, 46.0, _textSize.width, _textSize.height);
    _separatorView.frame = CGRectMake(self.safeAreaInset.left + 15.0, self.bounds.size.height - 46.0, self.bounds.size.width, TGScreenPixel);
    _buttonView.frame = CGRectMake(0.0, self.bounds.size.height - 46.0, self.bounds.size.width, 46.0);
    _bottomSeparatorView.frame = CGRectMake(0.0, self.bounds.size.height - TGScreenPixel, self.bounds.size.width, TGScreenPixel);
}

@end

@interface TGMediaAssetsController () <UINavigationControllerDelegate, ASWatcher>
{
    TGMediaAssetsControllerIntent _intent;
    
    TGMediaPickerToolbarView *_toolbarView;
    
    TGMediaPickerAccessView *_accessView;
    
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

+ (instancetype)controllerWithContext:(id<LegacyComponentsContext>)context assetGroup:(TGMediaAssetGroup *)assetGroup intent:(TGMediaAssetsControllerIntent)intent recipientName:(NSString *)recipientName saveEditedPhotos:(bool)saveEditedPhotos allowGrouping:(bool)allowGrouping selectionLimit:(int)selectionLimit
{
    return [self controllerWithContext:context assetGroup:assetGroup intent:intent recipientName:recipientName saveEditedPhotos:saveEditedPhotos allowGrouping:allowGrouping inhibitSelection:false selectionLimit:selectionLimit];
}

+ (instancetype)controllerWithContext:(id<LegacyComponentsContext>)context assetGroup:(TGMediaAssetGroup *)assetGroup intent:(TGMediaAssetsControllerIntent)intent recipientName:(NSString *)recipientName saveEditedPhotos:(bool)saveEditedPhotos allowGrouping:(bool)allowGrouping inhibitSelection:(bool)inhibitSelection selectionLimit:(int)selectionLimit
{
    if (intent != TGMediaAssetsControllerSendMediaIntent && intent != TGMediaAssetsControllerSendFileIntent)
        allowGrouping = false;
    
    TGMediaAssetsController *assetsController = [[TGMediaAssetsController alloc] initWithContext:context intent:intent saveEditedPhotos:saveEditedPhotos allowGrouping:allowGrouping selectionLimit:selectionLimit];
    
    __weak TGMediaAssetsController *weakController = assetsController;
    void (^catchToolbarView)(bool) = ^(bool enabled)
    {
        __strong TGMediaAssetsController *strongController = weakController;
        if (strongController == nil)
            return;
        
        if (strongController->_toolbarView.superview == nil)
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
    groupsController.pallete = assetsController.pallete;
    groupsController.openAssetGroup = ^(id group)
    {
        __strong TGMediaAssetsController *strongController = weakController;
        if (strongController == nil)
            return;
        
        TGMediaAssetsPickerController *pickerController = nil;
        
        if ([group isKindOfClass:[TGMediaAssetGroup class]])
        {
            pickerController = [[TGMediaAssetsPickerController alloc] initWithContext:strongController->_context assetsLibrary:strongController.assetsLibrary assetGroup:group intent:intent selectionContext:inhibitSelection ? nil : strongController->_selectionContext editingContext:strongController->_editingContext saveEditedPhotos:strongController->_saveEditedPhotos];
            pickerController.pallete = strongController.pallete;
        }
        pickerController.stickersContext = strongController.stickersContext;
        pickerController.localMediaCacheEnabled = strongController.localMediaCacheEnabled;
        pickerController.captionsEnabled = strongController.captionsEnabled;
        pickerController.allowCaptionEntities = strongController.allowCaptionEntities;
        pickerController.inhibitDocumentCaptions = strongController.inhibitDocumentCaptions;
        pickerController.inhibitMute = strongController.inhibitMute;
        pickerController.liveVideoUploadEnabled = strongController.liveVideoUploadEnabled;
        pickerController.catchToolbarView = catchToolbarView;
        pickerController.recipientName = recipientName;
        pickerController.hasTimer = strongController.hasTimer;
        pickerController.onlyCrop = strongController.onlyCrop;
        pickerController.hasSilentPosting = strongController.hasSilentPosting;
        pickerController.hasSchedule = strongController.hasSchedule;
        pickerController.reminder = strongController.reminder;
        pickerController.presentScheduleController = strongController.presentScheduleController;
        pickerController.presentTimerController = strongController.presentTimerController;
        [strongController pushViewController:pickerController animated:true];
    };
    [groupsController loadViewIfNeeded];
    
    TGMediaAssetsPickerController *pickerController = [[TGMediaAssetsPickerController alloc] initWithContext:context assetsLibrary:assetsController.assetsLibrary assetGroup:assetGroup intent:intent selectionContext:inhibitSelection ? nil : assetsController->_selectionContext editingContext:assetsController->_editingContext saveEditedPhotos:saveEditedPhotos];
    pickerController.pallete = assetsController.pallete;
    pickerController.catchToolbarView = catchToolbarView;
    
    [groupsController setIsFirstInStack:true];
    [pickerController setIsFirstInStack:false];
    
    if (intent == TGMediaAssetsControllerSendMediaIntent) {
        [assetsController setViewControllers:@[ pickerController ]];
    } else {
        [assetsController setViewControllers:@[ groupsController, pickerController ]];
    }
    ((TGNavigationBar *)assetsController.navigationBar).navigationController = assetsController;
    
    assetsController.recipientName = recipientName;
    
    return assetsController;
}

- (void)setStickersContext:(id<TGPhotoPaintStickersContext>)stickersContext
{
    _stickersContext = stickersContext;
    self.pickerController.stickersContext = stickersContext;
}

- (void)setCaptionsEnabled:(bool)captionsEnabled
{
    _captionsEnabled = captionsEnabled;
    self.pickerController.captionsEnabled = captionsEnabled;
}

- (void)setAllowCaptionEntities:(bool)allowCaptionEntities
{
    _allowCaptionEntities = allowCaptionEntities;
    self.pickerController.allowCaptionEntities = allowCaptionEntities;
}

- (void)setInhibitDocumentCaptions:(bool)inhibitDocumentCaptions
{
    _inhibitDocumentCaptions = inhibitDocumentCaptions;
    self.pickerController.inhibitDocumentCaptions = inhibitDocumentCaptions;
}

- (void)setInhibitMute:(bool)inhibitMute
{
    _inhibitMute = inhibitMute;
    self.pickerController.inhibitMute = inhibitMute;
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

- (void)setHasSilentPosting:(bool)hasSilentPosting
{
    _hasSilentPosting = hasSilentPosting;
    self.pickerController.hasSilentPosting = hasSilentPosting;
}

- (void)setHasSchedule:(bool)hasSchedule
{
    _hasSchedule = hasSchedule;
    self.pickerController.hasSchedule = hasSchedule;
}

- (void)setReminder:(bool)reminder
{
    _reminder = reminder;
    self.pickerController.reminder = reminder;
}

- (void)setPresentScheduleController:(void (^)(bool, void (^)(int32_t)))presentScheduleController {
    _presentScheduleController = [presentScheduleController copy];
    self.pickerController.presentScheduleController = presentScheduleController;
}

- (void)setPresentTimerController:(void (^)(void (^)(int32_t)))presentTimerController {
    _presentTimerController = [presentTimerController copy];
    self.pickerController.presentTimerController = presentTimerController;
}

- (void)setOnlyCrop:(bool)onlyCrop
{
    _onlyCrop = onlyCrop;
    self.pickerController.onlyCrop = onlyCrop;
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

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context intent:(TGMediaAssetsControllerIntent)intent saveEditedPhotos:(bool)saveEditedPhotos allowGrouping:(bool)allowGrouping selectionLimit:(int)selectionLimit
{
    self = [super initWithNavigationBarClass:[TGNavigationBar class] toolbarClass:[UIToolbar class]];
    if (self != nil)
    {
        _context = context;
        _saveEditedPhotos = saveEditedPhotos;
     
        if ([context respondsToSelector:@selector(navigationBarPallete)])
            [((TGNavigationBar *)self.navigationBar) setPallete:[context navigationBarPallete]];
        
        if ([context respondsToSelector:@selector(mediaAssetsPallete)])
            [self setPallete:[context mediaAssetsPallete]];
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        self.delegate = self;
        _intent = intent;
        _assetsLibrary = [TGMediaAssetsLibrary libraryForAssetType:[TGMediaAssetsController assetTypeForIntent:intent]];
        
        __weak TGMediaAssetsController *weakSelf = self;
        _selectionContext = [[TGMediaSelectionContext alloc] initWithGroupingAllowed:allowGrouping selectionLimit:selectionLimit];
        if (allowGrouping)
            _selectionContext.grouping = true;
        _selectionContext.selectionLimitExceeded = ^{
            __strong TGMediaAssetsController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            if (strongSelf->_selectionLimitExceeded) {
                strongSelf->_selectionLimitExceeded();
            }
        };
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
            for (TGMediaAsset *item in strongSelf->_selectionContext.selectedItems)
            {
                TGMediaAsset *asset = item;
                if ([asset isKindOfClass:[TGCameraCapturedVideo class]]) {
                    asset = [(TGCameraCapturedVideo *)item originalAsset];
                }
                
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
            groupingButtonVisible = false;
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
            
            NSUInteger count = strongSelf->_selectionContext.count;
            NSString *text = nil;
            __block bool hasPhoto = false;
            __block bool hasVideo = false;
            [strongSelf->_selectionContext enumerateSelectedItems:^(id<TGMediaSelectableItem> asset) {
                NSObject *value = (NSObject *)asset;
                if (![value isKindOfClass:[TGMediaAsset class]])
                    return;
                if (((TGMediaAsset *)asset).isVideo) {
                    hasVideo = true;
                } else {
                    hasPhoto = true;
                }
            }];
            
            if (hasPhoto && hasVideo) {
                if (count == 1) {
                    text = @"1 media selected";
                } else {
                    text = [NSString stringWithFormat:@"%lu medias selected", (unsigned long)count];
                }
            } else if (hasPhoto) {
                if (count == 1) {
                    text = @"1 photo selected";
                } else {
                    text = [NSString stringWithFormat:@"%lu photos selected", count];
                }
            } else if (hasVideo) {
                if (count == 1) {
                    text = @"1 message selected";
                } else {
                    text = [NSString stringWithFormat:@"%lu videos selected", count];
                }
            }

            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, text);
        }]];
        
        if (intent == TGMediaAssetsControllerSendMediaIntent || intent == TGMediaAssetsControllerSetProfilePhotoIntent || intent == TGMediaAssetsControllerSetSignupProfilePhotoIntent || intent == TGMediaAssetsControllerPassportIntent || intent == TGMediaAssetsControllerPassportMultipleIntent)
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
    
    bool hasOnScreenNavigation = false;
    if (iosMajorVersion() >= 11) {
        if (@available(iOS 11.0, *)) {
            hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || _context.safeAreaInset.bottom > FLT_EPSILON;
        }
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CGFloat inset = [TGViewController safeAreaInsetForOrientation:self.interfaceOrientation hasOnScreenNavigation:hasOnScreenNavigation].bottom;
    _toolbarView = [[TGMediaPickerToolbarView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - TGMediaPickerToolbarHeight - inset, self.view.frame.size.width, TGMediaPickerToolbarHeight + inset)];
    if (_pallete != nil)
        _toolbarView.pallete = _pallete;
    _toolbarView.safeAreaInset = [TGViewController safeAreaInsetForOrientation:self.interfaceOrientation hasOnScreenNavigation:hasOnScreenNavigation];
#pragma clang diagnostic pop
    _toolbarView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    if ((_intent != TGMediaAssetsControllerSendFileIntent && _intent != TGMediaAssetsControllerSendMediaIntent && _intent != TGMediaAssetsControllerPassportMultipleIntent) || _selectionContext == nil)
        [_toolbarView setRightButtonHidden:true];
   
    __weak TGMediaAssetsController *weakSelf = self;
    if (_selectionContext.allowGrouping)
    {
        [_toolbarView setCenterButtonImage:TGTintedImage(TGComponentsImageNamed(@"MediaPickerGroupPhotosIcon"), _pallete != nil ? _pallete.secondaryTextColor : UIColorRGB(0x858e99))];
        [_toolbarView setCenterButtonSelectedImage:_pallete != nil ? TGTintedImage(TGComponentsImageNamed(@"MediaPickerGroupPhotosIcon"), _pallete.accentColor) : TGComponentsImageNamed(@"MediaPickerGroupPhotosIcon")];
        [_toolbarView setCenterButtonHidden:true animated:false];
        [_toolbarView setCenterButtonSelected:_selectionContext.grouping];
        
        _toolbarView.centerPressed = ^
        {
            __strong TGMediaAssetsController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf groupPhotosPressed];
        };
    }
    if (_intent != TGMediaAssetsControllerSendMediaIntent)
        [self.view addSubview:_toolbarView];

    if (@available(iOS 14.0, *)) {
        if ([PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite] == PHAuthorizationStatusLimited) {
            _accessView = [[TGMediaPickerAccessView alloc] init];
            _accessView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            _accessView.safeAreaInset = [TGViewController safeAreaInsetForOrientation:self.interfaceOrientation hasOnScreenNavigation:hasOnScreenNavigation];
    #pragma clang diagnostic pop
            [_accessView setPallete:_pallete];
            _accessView.pressed = ^{
                __strong TGMediaAssetsController *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    [strongSelf manageAccess];
                }
            };
            [self.view addSubview:_accessView];
        }
    }
}

- (void)manageAccess
{
    if (iosMajorVersion() < 14) {
        return;
    }
    
    __weak TGMediaAssetsController *weakSelf = self;
    
    TGMenuSheetController *controller = [[TGMenuSheetController alloc] initWithContext:_context dark:false];
    controller.dismissesByOutsideTap = true;
    controller.narrowInLandscape = true;
    __weak TGMenuSheetController *weakController = controller;
    
    NSArray *items = @
    [
     [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Media.LimitedAccessSelectMore") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
      {
          __strong TGMenuSheetController *strongController = weakController;
          if (strongController == nil)
              return;
          
          __strong TGMediaAssetsController *strongSelf = weakSelf;
          if (strongSelf == nil)
              return;

            [strongController dismissAnimated:true manual:false completion:nil];
        if (@available(iOS 14, *)) {
            [[PHPhotoLibrary sharedPhotoLibrary] presentLimitedLibraryPickerFromViewController:strongSelf];
        }
      }],
     [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Media.LimitedAccessChangeSettings") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
      {
          __strong TGMenuSheetController *strongController = weakController;
          if (strongController == nil)
              return;
          
          __strong TGMediaAssetsController *strongSelf = weakSelf;
          if (strongSelf == nil)
              return;
          
          [strongController dismissAnimated:true manual:false completion:nil];
          [[[LegacyComponentsGlobals provider] applicationInstance] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:^(BOOL success) {
              
          }];
      }],
     [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.Cancel") type:TGMenuSheetButtonTypeCancel fontSize:20.0 action:^
      {
          __strong TGMenuSheetController *strongController = weakController;
          if (strongController != nil)
              [strongController dismissAnimated:true];
      }]
     ];
    
    [controller setItemViews:items];
    [controller presentInViewController:self sourceView:self.view animated:true];
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
            [strongSelf completeWithCurrentItem:nil silentPosting:false scheduleTime:0];
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

- (void)setPallete:(TGMediaAssetsPallete *)pallete {
    _pallete = pallete;
   
    [_accessView setPallete:pallete];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    UIInterfaceOrientation orientation = UIInterfaceOrientationPortrait;
    if (self.view.frame.size.width > self.view.frame.size.height)
        orientation = UIInterfaceOrientationLandscapeLeft;
    
    bool hasOnScreenNavigation = false;
    if (iosMajorVersion() >= 11) {
        if (@available(iOS 11.0, *)) {
            hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || _context.safeAreaInset.bottom > FLT_EPSILON;
        }
    }
    
    _toolbarView.safeAreaInset = [TGViewController safeAreaInsetForOrientation:orientation hasOnScreenNavigation:hasOnScreenNavigation];
    _accessView.safeAreaInset = [TGViewController safeAreaInsetForOrientation:orientation hasOnScreenNavigation:hasOnScreenNavigation];
    
    if (_accessView != nil) {
        CGSize accessSize = [_accessView sizeThatFits:self.view.frame.size];
        _accessView.frame = CGRectMake(0.0, self.navigationBar.frame.size.height, self.view.frame.size.width, accessSize.height);
    
        for (UIViewController *controller in self.viewControllers) {
            if ([controller isKindOfClass:[TGMediaGroupsController class]]) {
                ((TGMediaGroupsController *)controller).topInset = accessSize.height;
            } else if ([controller isKindOfClass:[TGMediaPickerController class]]) {
                ((TGMediaPickerController *)controller).topInset = accessSize.height;
            }
        }
    }
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

- (void)completeWithAvatarVideo:(AVAsset *)asset adjustments:(TGVideoEditAdjustments *)adjustments image:(UIImage *)image
{
    if (self.avatarVideoCompletionBlock != nil)
        self.avatarVideoCompletionBlock(image, asset, adjustments);
}

- (void)completeWithCurrentItem:(TGMediaAsset *)currentItem silentPosting:(bool)silentPosting scheduleTime:(int32_t)scheduleTime
{
    if (self.completionBlock != nil)
    {
        NSArray *signals = [self resultSignalsWithCurrentItem:currentItem descriptionGenerator:self.descriptionGenerator];
        self.completionBlock(signals, silentPosting, scheduleTime);
    }
    else if (self.singleCompletionBlock != nil)
    {
        self.singleCompletionBlock(currentItem, _editingContext);
    }
}

- (NSArray *)resultSignalsWithCurrentItem:(TGMediaAsset *)currentItem descriptionGenerator:(id (^)(id, NSAttributedString *, NSString *, NSString *))descriptionGenerator
{
    bool storeAssets = (_editingContext != nil) && self.shouldStoreAssets;
    
    if (_intent == TGMediaAssetsControllerSendMediaIntent && _selectionContext.allowGrouping)
        [[NSUserDefaults standardUserDefaults] setObject:@(!_selectionContext.grouping) forKey:@"TG_mediaGroupingDisabled_v0"];
    
    return [TGMediaAssetsController resultSignalsForSelectionContext:_selectionContext editingContext:_editingContext intent:_intent currentItem:currentItem storeAssets:storeAssets convertToJpeg:false descriptionGenerator:descriptionGenerator saveEditedPhotos:_saveEditedPhotos];
}

+ (int64_t)generateGroupedId
{
    int64_t value;
    arc4random_buf(&value, sizeof(int64_t));
    return value;
}

+ (NSArray *)resultSignalsForSelectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext intent:(TGMediaAssetsControllerIntent)intent currentItem:(TGMediaAsset *)currentItem storeAssets:(bool)storeAssets convertToJpeg:(bool)convertToJpeg descriptionGenerator:(id (^)(id, NSAttributedString *, NSString *, NSString *))descriptionGenerator saveEditedPhotos:(bool)saveEditedPhotos
{
    NSMutableArray *signals = [[NSMutableArray alloc] init];
    NSMutableArray *selectedItems = selectionContext.selectedItems ? [selectionContext.selectedItems mutableCopy] : [[NSMutableArray alloc] init];
    if (selectedItems.count == 0 && currentItem != nil)
        [selectedItems addObject:currentItem];
    
    if (saveEditedPhotos && storeAssets && editingContext != nil)
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
    NSInteger num = 0;
    bool grouping = selectionContext.grouping;
    
    bool hasAnyTimers = false;
    if (editingContext != nil || grouping)
    {
        for (TGMediaAsset *asset in selectedItems)
        {
            if ([editingContext timerForItem:asset] != nil) {
                hasAnyTimers = true;
            }
            id<TGMediaEditAdjustments> adjustments = [editingContext adjustmentsForItem:asset];
            if ([adjustments isKindOfClass:[TGVideoEditAdjustments class]]) {
                TGVideoEditAdjustments *videoAdjustments = (TGVideoEditAdjustments *)adjustments;
                if (videoAdjustments.sendAsGif) {
                    grouping = false;
                }
            }
            for (TGPhotoPaintEntity *entity in adjustments.paintingData.entities) {
                if (entity.animated) {
                    grouping = true;
                }
            }
        }
    }
    
    if (grouping && selectedItems.count > 1)
        groupedId = @([self generateGroupedId]);
    
    for (TGMediaAsset *item in selectedItems)
    {
        TGMediaAsset *asset = item;
        if ([asset isKindOfClass:[TGCameraCapturedVideo class]]) {
            asset = ((TGCameraCapturedVideo *)asset).originalAsset;
        }
        
        NSAttributedString *caption = [editingContext captionForItem:asset];
        
        if (editingContext.isForcedCaption) {
            if (grouping && num > 0) {
                caption = nil;
            } else if (!grouping && num < selectedItems.count - 1) {
                caption = nil;
            }
        }
        
        switch (asset.type)
        {
            case TGMediaAssetPhotoType:
            {
                if (intent == TGMediaAssetsControllerSendFileIntent)
                {
                    [signals addObject:[[[TGMediaAssetImageSignals imageDataForAsset:asset allowNetworkAccess:false convertToJpeg:convertToJpeg] map:^NSDictionary *(TGMediaAssetImageData *assetData)
                    {
                        NSString *tempFileName = TGTemporaryFileName(nil);
                        [assetData.imageData writeToURL:[NSURL fileURLWithPath:tempFileName] atomically:true];
                        
                        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                        dict[@"type"] = @"file";
                        dict[@"tempFileUrl"] = [NSURL fileURLWithPath:tempFileName];
                        dict[@"fileName"] = assetData.fileName;
                        dict[@"mimeType"] = TGMimeTypeForFileUTI(assetData.fileUTI);
                        
                        if (groupedId != nil)
                            dict[@"groupedId"] = groupedId;
                        
                        id generatedItem = descriptionGenerator(dict, caption, nil, asset.identifier);
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
                            
                            NSString *fileName = asset.fileName;
                            NSRange range = [fileName.lowercaseString rangeOfString:@".heic"];
                            if (range.location != NSNotFound)
                                fileName = [fileName stringByReplacingCharactersInRange:range withString:@".JPG"];
                            
                            dict[@"fileName"] = fileName;
                            
                            if (groupedId != nil)
                                dict[@"groupedId"] = groupedId;
                            
                            id generatedItem = descriptionGenerator(dict, caption, nil, asset.identifier);
                            return generatedItem;
                        }];
                    }]];
                    
                    i++;
                    num++;
                }
                else
                {
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
                        
                        id generatedItem = descriptionGenerator(dict, caption, nil, asset.identifier);
                        return generatedItem;
                    }];
                    
                    SSignal *assetSignal = inlineSignal;
                    SSignal *imageSignal = assetSignal;
                    if (adjustments.sendAsGif)
                    {
                        NSTimeInterval trimStartValue = 0.0;
                        if ([adjustments isKindOfClass:[TGVideoEditAdjustments class]]) {
                            TGVideoEditAdjustments *videoAdjustments = (TGVideoEditAdjustments *)adjustments;
                            trimStartValue = videoAdjustments.trimStartValue;
                        }
                        
                        UIImage *(^cropVideoThumbnail)(UIImage *, CGSize, CGSize, bool) = ^UIImage *(UIImage *image, CGSize targetSize, CGSize sourceSize, bool resize)
                        {
                            if ([adjustments cropAppliedForAvatar:false] || adjustments.hasPainting || adjustments.toolsApplied)
                            {
                                CGRect scaledCropRect = CGRectMake(adjustments.cropRect.origin.x * image.size.width / adjustments.originalSize.width, adjustments.cropRect.origin.y * image.size.height / adjustments.originalSize.height, adjustments.cropRect.size.width * image.size.width / adjustments.originalSize.width, adjustments.cropRect.size.height * image.size.height / adjustments.originalSize.height);
                                UIImage *paintingImage = adjustments.paintingData.stillImage;
                                if (paintingImage == nil) {
                                    paintingImage = adjustments.paintingData.image;
                                }
                                if (adjustments.toolsApplied) {
                                    image = [PGPhotoEditor resultImageForImage:image adjustments:adjustments];
                                }
                                return TGPhotoEditorCrop(image, paintingImage, adjustments.cropOrientation, 0, scaledCropRect, adjustments.cropMirrored, targetSize, sourceSize, resize);
                            }
                            
                            return image;
                        };
                        
                        SSignal *trimmedVideoThumbnailSignal = [[TGMediaAssetImageSignals avAssetForVideoAsset:asset allowNetworkAccess:false] mapToSignal:^SSignal *(AVAsset *avAsset)
                        {
                            CGSize imageSize = TGFillSize(asset.dimensions, CGSizeMake(512, 512));
                            return [[TGMediaAssetImageSignals videoThumbnailForAVAsset:avAsset size:imageSize timestamp:CMTimeMakeWithSeconds(trimStartValue, NSEC_PER_SEC)] map:^UIImage *(UIImage *image)
                            {
                                return cropVideoThumbnail(image, TGScaleToFill(asset.dimensions, CGSizeMake(512, 512)), asset.dimensions, true);
                            }];
                        }];
                        
                        SSignal *videoThumbnailSignal = [inlineThumbnailSignal(asset) map:^UIImage *(UIImage *image)
                        {
                            return cropVideoThumbnail(image, image.size, image.size, false);
                        }];
                        
                        SSignal *thumbnailSignal = trimStartValue > FLT_EPSILON ? trimmedVideoThumbnailSignal : videoThumbnailSignal;
                        
                        TGMediaVideoConversionPreset preset = [TGMediaVideoConverter presetFromAdjustments:adjustments];
                        CGSize dimensions = [TGMediaVideoConverter dimensionsFor:asset.originalSize adjustments:adjustments preset:preset];
                        
                        TGCameraCapturedVideo *videoAsset = [[TGCameraCapturedVideo alloc] initWithAsset:asset livePhoto:true];
                        [signals addObject:[thumbnailSignal mapToSignal:^SSignal *(UIImage *image)
                        {
                            return [videoAsset.avAsset map:^id(AVURLAsset *avAsset) {
                                NSTimeInterval duration = CMTimeGetSeconds(avAsset.duration);
                                if ([adjustments isKindOfClass:[TGVideoEditAdjustments class]]) {
                                    TGVideoEditAdjustments *videoAdjustments = (TGVideoEditAdjustments *)adjustments;
                                    duration = videoAdjustments.trimApplied ? (videoAdjustments.trimEndValue - videoAdjustments.trimStartValue) : duration;
                                }
                                
                                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                                dict[@"type"] = @"cameraVideo";
                                dict[@"url"] = avAsset.URL;
                                dict[@"previewImage"] = image;
                                dict[@"duration"] = @(duration);
                                dict[@"dimensions"] = [NSValue valueWithCGSize:dimensions];
                                dict[@"adjustments"] = adjustments;
                                
                                if (adjustments.paintingData.stickers.count > 0)
                                    dict[@"stickers"] = adjustments.paintingData.stickers;
                                if (timer != nil)
                                    dict[@"timer"] = timer;
                                else if (groupedId != nil && !hasAnyTimers)
                                    dict[@"groupedId"] = groupedId;
                                
                                id generatedItem = descriptionGenerator(dict, caption, nil, asset.identifier);
                                return generatedItem;
                            }];
                        }]];
                        
                        i++;
                        num++;
                    }
                    else
                    {
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
                            
                            bool animated = false;
                            for (TGPhotoPaintEntity *entity in adjustments.paintingData.entities) {
                                if (entity.animated) {
                                    animated = true;
                                    break;
                                }
                            }
                              
                            if (animated) {
                                dict[@"isAnimation"] = @true;
                                if ([adjustments isKindOfClass:[PGPhotoEditorValues class]]) {
                                    dict[@"adjustments"] = [TGVideoEditAdjustments editAdjustmentsWithPhotoEditorValues:(PGPhotoEditorValues *)adjustments preset:TGMediaVideoConversionPresetAnimation];
                                } else {
                                    dict[@"adjustments"] = adjustments;
                                }
                                
                                NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"gifvideo_%x.jpg", (int)arc4random()]];
                                NSData *data = UIImageJPEGRepresentation(image, 0.8);
                                [data writeToFile:filePath atomically:true];
                                dict[@"url"] = [NSURL fileURLWithPath:filePath];
                                  
                                if ([adjustments cropAppliedForAvatar:false] || adjustments.hasPainting || adjustments.toolsApplied)
                                {
                                    UIImage *paintingImage = adjustments.paintingData.stillImage;
                                    if (paintingImage == nil) {
                                        paintingImage = adjustments.paintingData.image;
                                    }
                                    UIImage *thumbnailImage = TGPhotoEditorVideoExtCrop(image, paintingImage, adjustments.cropOrientation, adjustments.cropRotation, adjustments.cropRect, adjustments.cropMirrored, TGScaleToFill(asset.dimensions, CGSizeMake(512, 512)), adjustments.originalSize, true, true, true, false);
                                    if (thumbnailImage != nil) {
                                        dict[@"previewImage"] = thumbnailImage;
                                    }
                                }
                            }
                            
                            if (timer != nil)
                                dict[@"timer"] = timer;
                            else if (groupedId != nil && !hasAnyTimers)
                                dict[@"groupedId"] = groupedId;
                            
                            id generatedItem = descriptionGenerator(dict, caption, nil, asset.identifier);
                            return generatedItem;
                        }] catch:^SSignal *(__unused id error)
                        {
                            return inlineSignal;
                        }]];
                    }
                    
                    i++;
                    num++;
                }
            }
                break;
                
            case TGMediaAssetVideoType:
            {
                if (intent == TGMediaAssetsControllerSendFileIntent)
                {
                    id<TGMediaEditAdjustments> adjustments = [editingContext adjustmentsForItem:asset];
                    
                    CGSize dimensions = asset.originalSize;
                    NSTimeInterval duration = asset.videoDuration;
                    
                    [signals addObject:[inlineThumbnailSignal(asset) map:^id(UIImage *image)
                    {
                        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                        dict[@"type"] = @"video";
                        dict[@"document"] = @true;
                        dict[@"asset"] = asset;
                        dict[@"previewImage"] = image;
                        dict[@"fileName"] = asset.fileName;
                        dict[@"dimensions"] = [NSValue valueWithCGSize:dimensions];
                        dict[@"duration"] = @(duration);
                        
                        if (adjustments.paintingData.stickers.count > 0)
                            dict[@"stickers"] = adjustments.paintingData.stickers;
                        
                        if (groupedId != nil)
                            dict[@"groupedId"] = groupedId;
                        
                        id generatedItem = descriptionGenerator(dict, caption, nil, asset.identifier);
                        return generatedItem;
                    }]];
                    
                    i++;
                    num++;
                }
                else
                {
                    TGVideoEditAdjustments *adjustments = (TGVideoEditAdjustments *)[editingContext adjustmentsForItem:asset];
                    NSNumber *timer = [editingContext timerForItem:asset];
                    
                    UIImage *(^cropVideoThumbnail)(UIImage *, CGSize, CGSize, bool) = ^UIImage *(UIImage *image, CGSize targetSize, CGSize sourceSize, bool resize)
                    {
                        if ([adjustments cropAppliedForAvatar:false] || adjustments.hasPainting || adjustments.toolsApplied)
                        {
                            CGRect scaledCropRect = CGRectMake(adjustments.cropRect.origin.x * image.size.width / adjustments.originalSize.width, adjustments.cropRect.origin.y * image.size.height / adjustments.originalSize.height, adjustments.cropRect.size.width * image.size.width / adjustments.originalSize.width, adjustments.cropRect.size.height * image.size.height / adjustments.originalSize.height);
                            UIImage *paintingImage = adjustments.paintingData.stillImage;
                            if (paintingImage == nil) {
                                paintingImage = adjustments.paintingData.image;
                            }
                            if (adjustments.toolsApplied) {
                                image = [PGPhotoEditor resultImageForImage:image adjustments:adjustments];
                            }
                            return TGPhotoEditorCrop(image, paintingImage, adjustments.cropOrientation, 0, scaledCropRect, adjustments.cropMirrored, targetSize, sourceSize, resize);
                        }
                        
                        return image;
                    };
                    
                    SSignal *trimmedVideoThumbnailSignal = [[TGMediaAssetImageSignals avAssetForVideoAsset:asset allowNetworkAccess:false] mapToSignal:^SSignal *(AVAsset *avAsset)
                    {
                        CGSize imageSize = TGFillSize(asset.dimensions, CGSizeMake(512, 512));
                        return [[TGMediaAssetImageSignals videoThumbnailForAVAsset:avAsset size:imageSize timestamp:CMTimeMakeWithSeconds(adjustments.trimStartValue, NSEC_PER_SEC)] map:^UIImage *(UIImage *image)
                        {
                            return cropVideoThumbnail(image, TGScaleToFill(asset.dimensions, CGSizeMake(512, 512)), asset.dimensions, true);
                        }];
                    }];
                    
                    SSignal *videoThumbnailSignal = [inlineThumbnailSignal(asset) map:^UIImage *(UIImage *image)
                    {
                        return cropVideoThumbnail(image, image.size, image.size, false);
                    }];
                    
                    SSignal *thumbnailSignal = adjustments.trimStartValue > FLT_EPSILON ? trimmedVideoThumbnailSignal : videoThumbnailSignal;
                    
                    TGMediaVideoConversionPreset preset = [TGMediaVideoConverter presetFromAdjustments:adjustments];
                    CGSize dimensions = [TGMediaVideoConverter dimensionsFor:asset.originalSize adjustments:adjustments preset:preset];
                    NSTimeInterval duration = adjustments.trimApplied ? (adjustments.trimEndValue - adjustments.trimStartValue) : asset.videoDuration;
                    
                    [signals addObject:[thumbnailSignal map:^id(UIImage *image)
                    {
                        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                        dict[@"type"] = @"video";
                        dict[@"document"] = @false;
                        dict[@"asset"] = asset;
                        dict[@"previewImage"] = image;
                        dict[@"adjustments"] = adjustments;
                        dict[@"dimensions"] = [NSValue valueWithCGSize:dimensions];
                        dict[@"duration"] = @(duration);
                        
                        if (adjustments.paintingData.stickers.count > 0)
                            dict[@"stickers"] = adjustments.paintingData.stickers;
                        
                        if (timer != nil)
                            dict[@"timer"] = timer;
                        else if (groupedId != nil && !hasAnyTimers)
                            dict[@"groupedId"] = groupedId;
                        
                        id generatedItem = descriptionGenerator(dict, caption, nil, asset.identifier);
                        return generatedItem;
                    }]];
                    
                    i++;
                    num++;
                }
            }
                break;
                
            case TGMediaAssetGifType:
            {
                TGCameraCapturedVideo *video = (TGCameraCapturedVideo *)item;
                if ([video isKindOfClass:[TGMediaAsset class]]) {
                    video = [[TGCameraCapturedVideo alloc] initWithAsset:(TGMediaAsset *)video livePhoto:false];
                }
                
                TGVideoEditAdjustments *adjustments = (TGVideoEditAdjustments *)[editingContext adjustmentsForItem:video];
                NSNumber *timer = [editingContext timerForItem:video];
                
                UIImage *(^cropVideoThumbnail)(UIImage *, CGSize, CGSize, bool) = ^UIImage *(UIImage *image, CGSize targetSize, CGSize sourceSize, bool resize)
                {
                    if ([adjustments cropAppliedForAvatar:false] || adjustments.hasPainting || adjustments.toolsApplied)
                    {
                        CGRect scaledCropRect = CGRectMake(adjustments.cropRect.origin.x * image.size.width / adjustments.originalSize.width, adjustments.cropRect.origin.y * image.size.height / adjustments.originalSize.height, adjustments.cropRect.size.width * image.size.width / adjustments.originalSize.width, adjustments.cropRect.size.height * image.size.height / adjustments.originalSize.height);
                        UIImage *paintingImage = adjustments.paintingData.stillImage;
                        if (paintingImage == nil) {
                            paintingImage = adjustments.paintingData.image;
                        }
                        if (adjustments.toolsApplied) {
                            image = [PGPhotoEditor resultImageForImage:image adjustments:adjustments];
                        }
                        return TGPhotoEditorCrop(image, paintingImage, adjustments.cropOrientation, 0, scaledCropRect, adjustments.cropMirrored, targetSize, sourceSize, resize);
                    }
                    
                    return image;
                };
                
                CGSize imageSize = TGFillSize(video.originalSize, CGSizeMake(512, 512));
                SSignal *trimmedVideoThumbnailSignal = [[video avAsset] mapToSignal:^SSignal *(AVURLAsset *avAsset) {
                    return [[TGMediaAssetImageSignals videoThumbnailForAVAsset:avAsset size:imageSize timestamp:CMTimeMakeWithSeconds(adjustments.trimStartValue, NSEC_PER_SEC)] map:^UIImage *(UIImage *image)
                    {
                        return cropVideoThumbnail(image, TGScaleToFill(video.originalSize, CGSizeMake(512, 512)), video.originalSize, true);
                    }];
                }];
                
                SSignal *videoThumbnailSignal = [[video thumbnailImageSignal] map:^UIImage *(UIImage *image)
                {
                    return cropVideoThumbnail(image, image.size, image.size, false);
                }];
                
                SSignal *thumbnailSignal = adjustments.trimStartValue > FLT_EPSILON ? trimmedVideoThumbnailSignal : videoThumbnailSignal;
                
                TGMediaVideoConversionPreset preset = TGMediaVideoConversionPresetAnimation;
                if (adjustments != nil) {
                    adjustments = [adjustments editAdjustmentsWithPreset:preset maxDuration:0.0];
                } else {
                    adjustments = [TGVideoEditAdjustments editAdjustmentsWithOriginalSize:video.originalSize preset:preset];
                }
                CGSize dimensions = [TGMediaVideoConverter dimensionsFor:video.originalSize adjustments:adjustments preset:preset];
                NSTimeInterval duration = adjustments.trimApplied ? (adjustments.trimEndValue - adjustments.trimStartValue) : video.videoDuration;
                
                [signals addObject:[thumbnailSignal map:^id(UIImage *image)
                {
                    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                    dict[@"type"] = @"cameraVideo";
                    dict[@"url"] = video.immediateAVAsset.URL;
                    dict[@"previewImage"] = image;
                    dict[@"adjustments"] = adjustments;
                    dict[@"dimensions"] = [NSValue valueWithCGSize:dimensions];
                    dict[@"duration"] = @(duration);
                    
                    if (adjustments.paintingData.stickers.count > 0)
                        dict[@"stickers"] = adjustments.paintingData.stickers;
                    if (timer != nil)
                        dict[@"timer"] = timer;
                    
                    id generatedItem = descriptionGenerator(dict, caption, nil, asset.identifier);
                    return generatedItem;
                }]];
                
                i++;
                num++;
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

+ (NSArray *)pasteboardResultSignalsForSelectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext intent:(TGMediaAssetsControllerIntent)intent currentItem:(id<TGMediaSelectableItem>)currentItem descriptionGenerator:(id (^)(id, NSAttributedString *, NSString *, NSString *))descriptionGenerator
{
    NSMutableArray *signals = [[NSMutableArray alloc] init];
    NSMutableArray *selectedItems = [selectionContext.selectedItems mutableCopy];
    if (selectedItems.count == 0 && currentItem != nil)
        [selectedItems addObject:currentItem];
    
    NSNumber *groupedId;
    NSInteger i = 0;
    NSInteger num = 0;
    bool grouping = selectionContext.grouping;
    
    bool hasAnyTimers = false;
    if (editingContext != nil || grouping)
    {
        for (id<TGMediaEditableItem> asset in selectedItems)
        {
            if ([editingContext timerForItem:asset] != nil) {
                hasAnyTimers = true;
            }
            id<TGMediaEditAdjustments> adjustments = [editingContext adjustmentsForItem:asset];
            if ([adjustments isKindOfClass:[TGVideoEditAdjustments class]]) {
                TGVideoEditAdjustments *videoAdjustments = (TGVideoEditAdjustments *)adjustments;
                if (videoAdjustments.sendAsGif) {
                    grouping = false;
                }
            }
            for (TGPhotoPaintEntity *entity in adjustments.paintingData.entities) {
                if (entity.animated) {
                    grouping = true;
                }
            }
        }
    }
    
    if (grouping && selectedItems.count > 1)
        groupedId = @([self generateGroupedId]);
    
    for (id<TGMediaEditableItem> asset in selectedItems)
    {
        NSAttributedString *caption = [editingContext captionForItem:asset];
        if (editingContext.isForcedCaption) {
            if (grouping && num > 0) {
                caption = nil;
            } else if (!grouping && num < selectedItems.count - 1) {
                caption = nil;
            }
        }
        
        if ([asset isKindOfClass:[UIImage class]]) {
            if (intent == TGMediaAssetsControllerSendFileIntent)
            {
                NSString *tempFileName = TGTemporaryFileName(nil);
                NSData *imageData = UIImageJPEGRepresentation((UIImage *)asset, 1.0);
                [imageData writeToURL:[NSURL fileURLWithPath:tempFileName] atomically:true];
                
                NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                dict[@"type"] = @"file";
                dict[@"tempFileUrl"] = [NSURL fileURLWithPath:tempFileName];
                dict[@"fileName"] = [NSString stringWithFormat:@"IMG%03ld.jpg", i];
                dict[@"mimeType"] = TGMimeTypeForFileUTI(@"image/jpeg");
                dict[@"previewImage"] = asset;
                
                if (groupedId != nil)
                    dict[@"groupedId"] = groupedId;
                
                id generatedItem = descriptionGenerator(dict, caption, nil, nil);
                [signals addObject:[SSignal single:generatedItem]];
                
                i++;
                num++;
            } else {
                id<TGMediaEditAdjustments> adjustments = [editingContext adjustmentsForItem:asset];
                NSNumber *timer = [editingContext timerForItem:asset];
                
                SSignal *inlineSignal = [[SSignal single:asset] map:^id(UIImage *image)
                                         {
                    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                    dict[@"type"] = @"editedPhoto";
                    dict[@"image"] = image;
                    
                    if (timer != nil)
                        dict[@"timer"] = timer;
                    
                    if (groupedId != nil && !hasAnyTimers)
                        dict[@"groupedId"] = groupedId;
                    
                    id generatedItem = descriptionGenerator(dict, caption, nil, nil);
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
                    
                    if (groupedId != nil && !hasAnyTimers)
                        dict[@"groupedId"] = groupedId;
                    
                    id generatedItem = descriptionGenerator(dict, caption, nil, nil);
                    return generatedItem;
                }] catch:^SSignal *(__unused id error)
                                    {
                    return inlineSignal;
                }]];
                
                i++;
                num++;
            }
        } else if ([asset isKindOfClass:[TGCameraCapturedVideo class]]) {
            TGCameraCapturedVideo *video = (TGCameraCapturedVideo *)asset;
            
            TGVideoEditAdjustments *adjustments = (TGVideoEditAdjustments *)[editingContext adjustmentsForItem:asset];
            NSAttributedString *caption = [editingContext captionForItem:asset];
            NSNumber *timer = [editingContext timerForItem:asset];
            
            UIImage *(^cropVideoThumbnail)(UIImage *, CGSize, CGSize, bool) = ^UIImage *(UIImage *image, CGSize targetSize, CGSize sourceSize, bool resize)
            {
                if ([adjustments cropAppliedForAvatar:false] || adjustments.hasPainting || adjustments.toolsApplied)
                {
                    CGRect scaledCropRect = CGRectMake(adjustments.cropRect.origin.x * image.size.width / adjustments.originalSize.width, adjustments.cropRect.origin.y * image.size.height / adjustments.originalSize.height, adjustments.cropRect.size.width * image.size.width / adjustments.originalSize.width, adjustments.cropRect.size.height * image.size.height / adjustments.originalSize.height);
                    UIImage *paintingImage = adjustments.paintingData.stillImage;
                    if (paintingImage == nil) {
                        paintingImage = adjustments.paintingData.image;
                    }
                    if (adjustments.toolsApplied) {
                        image = [PGPhotoEditor resultImageForImage:image adjustments:adjustments];
                    }
                    return TGPhotoEditorCrop(image, paintingImage, adjustments.cropOrientation, 0, scaledCropRect, adjustments.cropMirrored, targetSize, sourceSize, resize);
                }
                
                return image;
            };
            
            CGSize imageSize = TGFillSize(asset.originalSize, CGSizeMake(512, 512));
            SSignal *trimmedVideoThumbnailSignal = [[video avAsset] mapToSignal:^SSignal *(AVURLAsset *avAsset) {
                return [[TGMediaAssetImageSignals videoThumbnailForAVAsset:avAsset size:imageSize timestamp:CMTimeMakeWithSeconds(adjustments.trimStartValue, NSEC_PER_SEC)] map:^UIImage *(UIImage *image)
                        {
                    return cropVideoThumbnail(image, TGScaleToFill(asset.originalSize, CGSizeMake(512, 512)), asset.originalSize, true);
                }];
            }];
            
            SSignal *(^inlineThumbnailSignal)(id<TGMediaEditableItem>) = ^SSignal *(id<TGMediaEditableItem> item)
            {
                return [item thumbnailImageSignal];
            };
            
            SSignal *videoThumbnailSignal = [inlineThumbnailSignal(asset) map:^UIImage *(UIImage *image) {
                return cropVideoThumbnail(image, image.size, image.size, false);
            }];
            
            SSignal *thumbnailSignal = adjustments.trimStartValue > FLT_EPSILON ? trimmedVideoThumbnailSignal : videoThumbnailSignal;
            
            TGMediaVideoConversionPreset preset = [TGMediaVideoConverter presetFromAdjustments:adjustments];
            CGSize dimensions = [TGMediaVideoConverter dimensionsFor:asset.originalSize adjustments:adjustments preset:preset];
            NSTimeInterval duration = adjustments.trimApplied ? (adjustments.trimEndValue - adjustments.trimStartValue) : video.videoDuration;
            
            [signals addObject:[thumbnailSignal mapToSignal:^id(UIImage *image)
                                {
                return [video.avAsset map:^id(AVURLAsset *avAsset) {
                    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                    dict[@"type"] = @"cameraVideo";
                    dict[@"url"] = avAsset.URL;
                    dict[@"previewImage"] = image;
                    dict[@"adjustments"] = adjustments;
                    dict[@"dimensions"] = [NSValue valueWithCGSize:dimensions];
                    dict[@"duration"] = @(duration);
                    
                    if (adjustments.paintingData.stickers.count > 0)
                        dict[@"stickers"] = adjustments.paintingData.stickers;
                    if (timer != nil)
                        dict[@"timer"] = timer;
                    else if (groupedId != nil && !hasAnyTimers)
                        dict[@"groupedId"] = groupedId;
                    
                    id generatedItem = descriptionGenerator(dict, caption, nil, nil);
                    return generatedItem;
                }];
            }]];
            
            i++;
            i++;
            num++;
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

- (UIBarButtonItem *)leftBarButtonItem
{
    if (_intent == TGMediaAssetsControllerSendMediaIntent) {
        return [[UIBarButtonItem alloc] initWithTitle:TGLocalized(@"Common.Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancelButtonPressed)];
    }
    return nil;
}

- (UIBarButtonItem *)rightBarButtonItem
{
    return nil;
//    if (_intent == TGMediaAssetsControllerSendFileIntent)
//        return nil;
//    if (self.requestSearchController == nil) {
//        return nil;
//    }
//
//    if (iosMajorVersion() < 7)
//    {
//        TGModernBarButton *searchButton = [[TGModernBarButton alloc] initWithImage:TGComponentsImageNamed(@"NavigationSearchIcon.png")];
//        searchButton.portraitAdjustment = CGPointMake(-7, -5);
//        [searchButton addTarget:self action:@selector(searchButtonPressed) forControlEvents:UIControlEventTouchUpInside];
//        return [[UIBarButtonItem alloc] initWithCustomView:searchButton];
//    }
//
//    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(searchButtonPressed)];
}

- (void)cancelButtonPressed
{
    [self dismiss];
}

- (void)searchButtonPressed
{
    if (self.requestSearchController) {
        self.requestSearchController();
    }
}

- (void)send:(bool)silently
{
    [self completeWithCurrentItem:nil silentPosting:silently scheduleTime:0];
}

- (void)schedule:(bool)media {
    __weak TGMediaAssetsController *weakSelf = self;
    self.presentScheduleController(media, ^(int32_t scheduleTime) {
        [weakSelf completeWithCurrentItem:nil silentPosting:false scheduleTime:scheduleTime];
    });
}

- (void)navigationController:(UINavigationController *)__unused navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)__unused animated
{
    if (_searchController == nil)
        return;
    
    UIView *backArrow = nil;
    UIView *backButton = nil;
    
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
        
        UIView *backArrow = nil;
        UIView *backButton = nil;
        backArrow.alpha = 1.0f;
        backButton.alpha = 1.0f;
    }
}

#pragma mark -

+ (TGMediaAssetType)assetTypeForIntent:(TGMediaAssetsControllerIntent)intent
{
    TGMediaAssetType assetType = TGMediaAssetAnyType;
    
    switch (intent)
    {
        case TGMediaAssetsControllerSetSignupProfilePhotoIntent:
        case TGMediaAssetsControllerSetCustomWallpaperIntent:
        case TGMediaAssetsControllerPassportIntent:
        case TGMediaAssetsControllerPassportMultipleIntent:
            assetType = TGMediaAssetPhotoType;
            break;
     
        case TGMediaAssetsControllerSetProfilePhotoIntent:
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

@implementation TGMediaAssetsPallete

+ (instancetype)palleteWithDark:(bool)dark backgroundColor:(UIColor *)backgroundColor selectionColor:(UIColor *)selectionColor separatorColor:(UIColor *)separatorColor textColor:(UIColor *)textColor secondaryTextColor:(UIColor *)secondaryTextColor accentColor:(UIColor *)accentColor destructiveColor:(UIColor *)destructiveColor barBackgroundColor:(UIColor *)barBackgroundColor barSeparatorColor:(UIColor *)barSeparatorColor navigationTitleColor:(UIColor *)navigationTitleColor badge:(UIImage *)badge badgeTextColor:(UIColor *)badgeTextColor sendIconImage:(UIImage *)sendIconImage doneIconImage:(UIImage *)doneIconImage maybeAccentColor:(UIColor *)maybeAccentColor
{
    TGMediaAssetsPallete *pallete = [[TGMediaAssetsPallete alloc] init];
    pallete->_isDark = dark;
    pallete->_backgroundColor = backgroundColor;
    pallete->_selectionColor = selectionColor;
    pallete->_separatorColor = separatorColor;
    pallete->_textColor = textColor;
    pallete->_secondaryTextColor = secondaryTextColor;
    pallete->_accentColor = accentColor;
    pallete->_destructiveColor = destructiveColor;
    pallete->_barBackgroundColor = barBackgroundColor;
    pallete->_barSeparatorColor = barSeparatorColor;
    pallete->_navigationTitleColor = navigationTitleColor;
    pallete->_badge = badge;
    pallete->_badgeTextColor = badgeTextColor;
    pallete->_sendIconImage = sendIconImage;
    pallete->_doneIconImage = doneIconImage;
    pallete->_maybeAccentColor = maybeAccentColor;
    return pallete;
}

@end
