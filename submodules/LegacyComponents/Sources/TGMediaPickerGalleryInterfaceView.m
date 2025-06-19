#import <LegacyComponents/LegacyComponents.h>
#import <LegacyComponents/TGMediaPickerGalleryInterfaceView.h>

#import "LegacyComponentsInternal.h"
#import <LegacyComponents/TGImageUtils.h>
#import <LegacyComponents/TGFont.h>

#import <SSignalKit/SSignalKit.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGObserverProxy.h>

#import <LegacyComponents/TGModernButton.h>
#import <LegacyComponents/TGMenuSheetController.h>

#import <LegacyComponents/TGMediaSelectionContext.h>
#import <LegacyComponents/TGMediaEditingContext.h>
#import <LegacyComponents/TGVideoEditAdjustments.h>
#import <LegacyComponents/TGMediaVideoConverter.h>
#import <LegacyComponents/TGMediaPickerGallerySelectedItemsModel.h>

#import <LegacyComponents/TGModernGallerySelectableItem.h>
#import <LegacyComponents/TGModernGalleryEditableItem.h>
#import <LegacyComponents/TGMediaPickerGalleryPhotoItem.h>
#import <LegacyComponents/TGMediaPickerGalleryVideoItem.h>
#import "TGMediaPickerGalleryPhotoItemView.h"
#import <LegacyComponents/TGMediaPickerGalleryVideoItemView.h>

#import <LegacyComponents/TGMessageImageViewOverlayView.h>

#import <LegacyComponents/TGPhotoEditorTabController.h>
#import <LegacyComponents/TGPhotoToolbarView.h>
#import <LegacyComponents/TGPhotoEditorButton.h>
#import <LegacyComponents/TGCheckButtonView.h>
#import "TGMediaPickerPhotoCounterButton.h"
#import "TGMediaPickerPhotoStripView.h"

#import "TGMediaPickerScrubberHeaderView.h"
#import <LegacyComponents/TGPhotoEditorInterfaceAssets.h>

#import <LegacyComponents/TGMenuView.h>
#import <LegacyComponents/TGTooltipView.h>

#import <LegacyComponents/TGPhotoCaptionInputMixin.h>

@interface TGMediaPickerGalleryWrapperView: UIView
{
    
}
@end

@implementation TGMediaPickerGalleryWrapperView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    __block UIView *result = nil;
    [self.subviews enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(__kindof UIView * _Nonnull view, NSUInteger idx, BOOL * _Nonnull stop) {
        UIView *hitTestView = [view hitTest:[self convertPoint:point toView:view] withEvent:event];
        if (hitTestView != nil) {
            *stop = true;
            result = hitTestView;
        }
    }];
    return result;
}

@end

@interface TGMediaPickerGalleryInterfaceView () <ASWatcher>
{
    id<TGModernGalleryItem> _currentItem;
    __weak TGModernGalleryItemView *_currentItemView;
    
    TGMediaSelectionContext *_selectionContext;
    TGMediaEditingContext *_editingContext;
    
    NSMutableArray *_itemHeaderViews;
    NSMutableArray *_itemFooterViews;
    
    UIView *_wrapperView;
    UIView *_headerWrapperView;
    TGPhotoToolbarView *_portraitToolbarView;
    TGPhotoToolbarView *_landscapeToolbarView;
    
    UIImageView *_arrowView;
    UILabel *_recipientLabel;
    
    TGPhotoCaptionInputMixin *_captionMixin;
    
    TGModernButton *_muteButton;
    TGCheckButtonView *_checkButton;
    bool _ignoreSetSelected;
    TGMediaPickerPhotoCounterButton *_photoCounterButton;
    TGMediaPickerGroupButton *_groupButton;
    TGMediaPickerCameraButton *_cameraButton;
    
    TGMediaPickerCoverButton *_coverButton;
    TGModernButton *_cancelCoverButton;
    TGModernButton *_saveCoverButton;
    TGMediaPickerCoverButton *_coverGalleryButton;
    UILabel *_coverTitleLabel;
    
    TGMediaPickerPhotoStripView *_selectedPhotosView;
    
    SMetaDisposable *_adjustmentsDisposable;
    SMetaDisposable *_captionDisposable;
    SMetaDisposable *_coverDisposable;
    SMetaDisposable *_itemAvailabilityDisposable;
    SMetaDisposable *_itemSelectedDisposable;
    id<SDisposable> _selectionChangedDisposable;
    id<SDisposable> _groupingChangedDisposable;
    id<SDisposable> _timersChangedDisposable;
    id<SDisposable> _adjustmentsChangedDisposable;
    
    NSTimer *_tooltipTimer;
    TGMenuContainerView *_tooltipContainerView;
    
    SMetaDisposable *_tooltipDismissDisposable;
    
    void (^_closePressed)();
    void (^_scrollViewOffsetRequested)(CGFloat offset);
    void (^_setGesturesEnabled)(bool offset);
    
    id<LegacyComponentsContext> _context;
    
    bool _ignoreSelectionUpdates;
}

@property (nonatomic, strong) ASHandle *actionHandle;
@property (nonatomic, copy) UIViewController *(^controller)();

@end

@implementation TGMediaPickerGalleryInterfaceView

@synthesize safeAreaInset = _safeAreaInset;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context focusItem:(id<TGModernGalleryItem>)focusItem selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext hasSelectionPanel:(bool)hasSelectionPanel hasCameraButton:(bool)hasCameraButton recipientName:(NSString *)recipientName isScheduledMessages:(bool)isScheduledMessages hasCoverButton:(bool)hasCoverButton
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        [[LegacyComponentsGlobals provider] makeViewDisableInteractiveKeyboardGestureRecognizer:self];
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _adjustmentsDisposable = [[SMetaDisposable alloc] init];
        _captionDisposable = [[SMetaDisposable alloc] init];
        _coverDisposable = [[SMetaDisposable alloc] init];
        _itemSelectedDisposable = [[SMetaDisposable alloc] init];
        _itemAvailabilityDisposable = [[SMetaDisposable alloc] init];
        _tooltipDismissDisposable = [[SMetaDisposable alloc] init];
        
        _context = context;
        _selectionContext = selectionContext;
        _editingContext = editingContext;
        
        _hasSwipeGesture = true;
        
        _itemHeaderViews = [[NSMutableArray alloc] init];
        _itemFooterViews = [[NSMutableArray alloc] init];
        
        _wrapperView = [[TGMediaPickerGalleryWrapperView alloc] initWithFrame:CGRectZero];
        [self addSubview:_wrapperView];
                
        __weak TGMediaPickerGalleryInterfaceView *weakSelf = self;
        void(^toolbarCancelPressed)(void) = ^
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf cancelButtonPressed];
        };
        void(^toolbarDonePressed)(void) = ^
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf->_ignoreSelectionUpdates = true;
            [strongSelf->_selectionChangedDisposable dispose];
            [strongSelf->_itemSelectedDisposable dispose];
            
            [strongSelf.window endEditing:true];
            strongSelf->_portraitToolbarView.doneButton.userInteractionEnabled = false;
            strongSelf->_landscapeToolbarView.doneButton.userInteractionEnabled = false;
            
            if (strongSelf->_captionMixin.editing) {
                [strongSelf->_captionMixin finishEditing];
                TGDispatchAfter(0.1, dispatch_get_main_queue(), ^{
                    strongSelf->_donePressed(strongSelf->_currentItem);
                });
            } else {
                strongSelf->_donePressed(strongSelf->_currentItem);
            }
            
            [strongSelf->_captionMixin onAnimateOut];
        };
        void(^toolbarDoneLongPressed)(id) = ^(id sender)
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf.window endEditing:true];
            if (strongSelf->_doneLongPressed != nil)
                strongSelf->_doneLongPressed(strongSelf->_currentItem);
            
            [[NSUserDefaults standardUserDefaults] setObject:@(3) forKey:@"TG_displayedMediaTimerTooltip_v3"];
        };
        
        _muteButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 40.0f, 40.0f)];
        _muteButton.hidden = true;
        _muteButton.adjustsImageWhenHighlighted = false;
        [_muteButton setBackgroundImage:[TGPhotoEditorInterfaceAssets gifBackgroundImage] forState:UIControlStateNormal];
        [_muteButton setImage:[TGPhotoEditorInterfaceAssets muteIcon] forState:UIControlStateNormal];
        [_muteButton setImage:[TGPhotoEditorInterfaceAssets muteActiveIcon] forState:UIControlStateSelected];
        [_muteButton setImage:[TGPhotoEditorInterfaceAssets muteActiveIcon]  forState:UIControlStateSelected | UIControlStateHighlighted];
        [_muteButton addTarget:self action:@selector(toggleSendAsGif) forControlEvents:UIControlEventTouchUpInside];
        [_wrapperView addSubview:_muteButton];
        
        if (recipientName.length > 0)
        {
            _arrowView = [[UIImageView alloc] initWithImage: TGComponentsImageNamed(@"PhotoPickerArrow")];
            _arrowView.alpha = 0.6f;
            [_wrapperView addSubview:_arrowView];
            
            _recipientLabel = [[UILabel alloc] init];
            _recipientLabel.alpha = 0.6;
            _recipientLabel.backgroundColor = [UIColor clearColor];
            _recipientLabel.font = TGBoldSystemFontOfSize(13.0f);
            _recipientLabel.textColor = UIColorRGB(0xffffff);
            _recipientLabel.text = recipientName;
            _recipientLabel.userInteractionEnabled = false;
            [_recipientLabel sizeToFit];
            [_wrapperView addSubview:_recipientLabel];
        }
        
                    
        if (_selectionContext != nil)
        {
            _checkButton = [[TGCheckButtonView alloc] initWithStyle:TGCheckButtonStyleGallery];
            _checkButton.frame = CGRectMake(self.frame.size.width - 53, 11, _checkButton.frame.size.width, _checkButton.frame.size.height);
            [_checkButton addTarget:self action:@selector(checkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [_wrapperView addSubview:_checkButton];
            
            if (hasSelectionPanel)
            {
                _selectedPhotosView = [[TGMediaPickerPhotoStripView alloc] initWithFrame:CGRectZero];
                _selectedPhotosView.selectionContext = _selectionContext;
                _selectedPhotosView.editingContext = _editingContext;
                _selectedPhotosView.itemSelected = ^(NSInteger index)
                {
                    __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    if (strongSelf.photoStripItemSelected != nil)
                        strongSelf.photoStripItemSelected(index);
                };
                _selectedPhotosView.hidden = true;
                [_wrapperView addSubview:_selectedPhotosView];
            }
                        
            _selectionChangedDisposable = [[_selectionContext selectionChangedSignal] startStrictWithNext:^(id next)
                                           {
                __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return;
                
                id<TGMediaSelectableItem> selectableItem = nil;
                if ([strongSelf->_currentItem conformsToProtocol:@protocol(TGModernGallerySelectableItem)])
                    selectableItem = ((id<TGModernGallerySelectableItem>)strongSelf->_currentItem).selectableMediaItem;
                
                if (selectableItem != nil)
                    [strongSelf->_checkButton setNumber:[strongSelf->_selectionContext indexOfItem:selectableItem]];
                
                [strongSelf updateGroupingButtonVisibility];
            } file:__FILE_NAME__ line:__LINE__];
            
            if (_selectionContext.allowGrouping)
            {
                if (_editingContext != nil)
                {
                    _timersChangedDisposable = [_editingContext.timersUpdatedSignal startStrictWithNext:^(__unused NSNumber *next)
                                                {
                        __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
                        if (strongSelf == nil)
                            return;
                        
                        [strongSelf updateGroupingButtonVisibility];
                    } file:__FILE_NAME__ line:__LINE__];
                    
                    _adjustmentsChangedDisposable = [_editingContext.adjustmentsUpdatedSignal startStrictWithNext:^(__unused NSNumber *next)
                                                     {
                        __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
                        if (strongSelf == nil)
                            return;
                        
                        [strongSelf updateGroupingButtonVisibility];
                    } file:__FILE_NAME__ line:__LINE__];
                }
                
                [self updateGroupingButtonVisibility];
            }
        }
        
        [self updateEditorButtonsForItem:focusItem animated:false];
        
        _captionMixin = [[TGPhotoCaptionInputMixin alloc] init];
        _captionMixin.panelParentView = ^UIView *
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            return strongSelf->_wrapperView;
        };
        
        _captionMixin.panelFocused = ^
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            TGModernGalleryItemView *currentItemView = strongSelf->_currentItemView;
            if ([currentItemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
            {
                TGMediaPickerGalleryVideoItemView *videoItemView = (TGMediaPickerGalleryVideoItemView *)strongSelf->_currentItemView;
                [videoItemView stop];
            }
            
            [strongSelf setSelectionInterfaceHidden:true animated:true];
            [strongSelf setItemHeaderViewHidden:true animated:true];
        };
        
        _captionMixin.finishedWithCaption = ^(NSAttributedString *caption)
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            TGModernGalleryItemView *currentItemView = strongSelf->_currentItemView;
            if ([currentItemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
            {
                TGMediaPickerGalleryVideoItemView *videoItemView = (TGMediaPickerGalleryVideoItemView *)strongSelf->_currentItemView;
                [videoItemView returnFromEditing];
            }
            
            [strongSelf setSelectionInterfaceHidden:false delay:0.25 animated:true];
            [strongSelf setItemHeaderViewHidden:false animated:true];
            
            if (strongSelf.captionSet != nil)
                strongSelf.captionSet(strongSelf->_currentItem, caption);
            
            [strongSelf updateEditorButtonsForItem:strongSelf->_currentItem animated:false];
        };
        
        _captionMixin.keyboardHeightChanged = ^(CGFloat keyboardHeight, NSTimeInterval duration, NSInteger animationCurve)
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (keyboardHeight > 0) {
                [strongSelf->_portraitToolbarView setAllButtonsHidden:true animated:true];
            } else {
                [strongSelf->_portraitToolbarView setAllButtonsHidden:false animated:true];
            }
            
            CGFloat offset = 0.0f;
            if (keyboardHeight > 0)
                offset = -keyboardHeight / 2.0f;
            
            [UIView animateWithDuration:duration delay:0.0f options:animationCurve animations:^
             {
                if (strongSelf->_scrollViewOffsetRequested != nil)
                    strongSelf->_scrollViewOffsetRequested(offset);
            } completion:nil];
        };
        
        _captionMixin.timerUpdated = ^(NSNumber *timeout) {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (![strongSelf->_currentItem conformsToProtocol:@protocol(TGModernGalleryEditableItem)])
                return;
            
            id<TGModernGalleryEditableItem> galleryEditableItem = (id<TGModernGalleryEditableItem>)strongSelf->_currentItem;
            [strongSelf->_editingContext setTimer:timeout forItem:galleryEditableItem.editableMediaItem];
            
            [strongSelf->_selectionContext setItem:(id<TGMediaSelectableItem>)galleryEditableItem.editableMediaItem selected:true animated:true sender:nil];
        };
        
        _captionMixin.captionIsAboveUpdated = ^(bool captionIsAbove) {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf->_editingContext setCaptionAbove:captionIsAbove];
        };
        
        _captionMixin.stickersContext = stickersContext;
        [_captionMixin createInputPanelIfNeeded];
        
        _headerWrapperView = [[TGMediaPickerGalleryWrapperView alloc] init];
        [_wrapperView addSubview:_headerWrapperView];
        
        _photoCounterButton = [[TGMediaPickerPhotoCounterButton alloc] initWithFrame:CGRectMake(0, 0, 64, 38)];
        [_photoCounterButton addTarget:self action:@selector(photoCounterButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        _photoCounterButton.userInteractionEnabled = false;
        [_wrapperView addSubview:_photoCounterButton];
        
        if (hasCoverButton) {
            _coverButton = [[TGMediaPickerCoverButton alloc] initWithFrame:CGRectMake(0, 0, 180, 26) gallery:false];
            _coverButton.hidden = true;
            [_coverButton addTarget:self action:@selector(coverButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [_wrapperView addSubview:_coverButton];
            
            _coverGalleryButton = [[TGMediaPickerCoverButton alloc] initWithFrame:CGRectMake(0, 0, 180, 26) gallery:true];
            _coverGalleryButton.hidden = true;
            [_coverGalleryButton addTarget:self action:@selector(coverGalleryButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [_wrapperView addSubview:_coverGalleryButton];
        }
        
        if (hasCameraButton)
        {
            _cameraButton = [[TGMediaPickerCameraButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 44.0f, 44.0f)];
            _cameraButton.adjustsImageWhenHighlighted = false;
            [_cameraButton addTarget:self action:@selector(cameraButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            
            [_wrapperView addSubview:_cameraButton];
        }
        
        TGPhotoEditorDoneButton doneButton = isScheduledMessages ? TGPhotoEditorDoneButtonSchedule : TGPhotoEditorDoneButtonSend;
        
        _portraitToolbarView = [[TGPhotoToolbarView alloc] initWithContext:_context backButton:TGPhotoEditorBackButtonBack doneButton:doneButton solidBackground:false stickersContext:editingContext.sendPaidMessageStars > 0 ? stickersContext : nil];
        _portraitToolbarView.cancelPressed = toolbarCancelPressed;
        _portraitToolbarView.donePressed = toolbarDonePressed;
        _portraitToolbarView.doneLongPressed = toolbarDoneLongPressed;
        [_wrapperView addSubview:_portraitToolbarView];
        
        _landscapeToolbarView = [[TGPhotoToolbarView alloc] initWithContext:_context backButton:TGPhotoEditorBackButtonBack doneButton:doneButton solidBackground:false stickersContext:nil];
        _landscapeToolbarView.cancelPressed = toolbarCancelPressed;
        _landscapeToolbarView.donePressed = toolbarDonePressed;
        _landscapeToolbarView.doneLongPressed = toolbarDoneLongPressed;
        
        if ([UIDevice currentDevice].userInterfaceIdiom != UIUserInterfaceIdiomPad)
            [_wrapperView addSubview:_landscapeToolbarView];
        
        if (hasCoverButton) {
            _cancelCoverButton = [[TGModernButton alloc] init];
            _cancelCoverButton.hidden = true;
            _cancelCoverButton.titleLabel.font = TGSystemFontOfSize(17.0);
            [_cancelCoverButton setTitle:TGLocalized(@"Common.Cancel") forState:UIControlStateNormal];
            [_cancelCoverButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [_cancelCoverButton addTarget:self action:@selector(cancelCoverButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [_cancelCoverButton sizeToFit];
            [_wrapperView addSubview:_cancelCoverButton];
            
            _coverTitleLabel = [[UILabel alloc] init];
            _coverTitleLabel.hidden = true;
            _coverTitleLabel.textColor = [UIColor whiteColor];
            _coverTitleLabel.font = TGBoldSystemFontOfSize(17.0);
            _coverTitleLabel.text = TGLocalized(@"Media.SelectFrame");
            [_coverTitleLabel sizeToFit];
            [_wrapperView addSubview:_coverTitleLabel];
            
            _saveCoverButton = [[TGModernButton alloc] init];
            _saveCoverButton.clipsToBounds = true;
            _saveCoverButton.layer.cornerRadius = 10.0;
            _saveCoverButton.hidden = true;
            [_saveCoverButton setBackgroundColor:UIColorRGB(0x007aff)];
            _saveCoverButton.titleLabel.font = TGBoldSystemFontOfSize(17.0);
            [_saveCoverButton setTitle:TGLocalized(@"Media.SaveCover") forState:UIControlStateNormal];
            [_saveCoverButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [_saveCoverButton addTarget:self action:@selector(saveCoverButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [_wrapperView addSubview:_saveCoverButton];
        }
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    
    [_adjustmentsDisposable dispose];
    [_captionDisposable dispose];
    [_coverDisposable dispose];
    [_itemSelectedDisposable dispose];
    [_itemAvailabilityDisposable dispose];
    [_selectionChangedDisposable dispose];
    [_timersChangedDisposable dispose];
    [_adjustmentsChangedDisposable dispose];
}

- (bool)updateGroupingButtonVisibility
{
    bool onlyGroupableMedia = true;
    for (id item in _selectionContext.selectedItems)
    {
        if ([item isKindOfClass:[TGMediaAsset class]])
        {
            if (((TGMediaAsset *)item).type == TGMediaAssetGifType)
            {
                onlyGroupableMedia = false;
                break;
            }
            else
            {
                if ([[_editingContext timerForItem:item] integerValue] > 0)
                {
                    onlyGroupableMedia = false;
                    break;
                }
                
                id<TGMediaEditAdjustments> adjustments = [_editingContext adjustmentsForItem:item];
                if ([adjustments isKindOfClass:[TGMediaVideoEditAdjustments class]] && ((TGMediaVideoEditAdjustments *)adjustments).sendAsGif)
                {
                    onlyGroupableMedia = false;
                    break;
                }
            }
        }
    }
    
    bool groupingButtonVisible = _groupButton != nil && onlyGroupableMedia && _selectionContext.count > 1;
    dispatch_async(dispatch_get_main_queue(), ^
                   {
        [_groupButton setInternalHidden:!groupingButtonVisible animated:true];
    });
    
    return groupingButtonVisible;
}

- (void)updateCameraButtonVisibility
{
    
}

- (void)setHasCaptions:(bool)hasCaptions
{
    _hasCaptions = hasCaptions;
    if (!hasCaptions)
        [_captionMixin destroy];
}

- (void)setAllowCaptionEntities:(bool)allowCaptionEntities
{
    _allowCaptionEntities = allowCaptionEntities;
    _captionMixin.allowEntities = allowCaptionEntities;
}

- (void)setClosePressed:(void (^)())closePressed
{
    _closePressed = [closePressed copy];
}

- (void)setScrollViewOffsetRequested:(void (^)(CGFloat))scrollViewOffsetRequested
{
    _scrollViewOffsetRequested = [scrollViewOffsetRequested copy];
}

- (void)setGesturesEnabled:(void (^)(bool))setGesturesEnabled
{
    _setGesturesEnabled = [setGesturesEnabled copy];
}

- (void)setEditorTabPressed:(void (^)(TGPhotoEditorTab tab))editorTabPressed
{
    __weak TGMediaPickerGalleryInterfaceView *weakSelf = self;
    void (^tabPressed)(TGPhotoEditorTab) = ^(TGPhotoEditorTab tab)
    {
        __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf tooltipTimerTick];
        editorTabPressed(tab);
    };
    _portraitToolbarView.tabPressed = tabPressed;
    _landscapeToolbarView.tabPressed = tabPressed;
}

- (void)openTimerSetup
{
    if ([_currentItem conformsToProtocol:@protocol(TGModernGalleryEditableItem)])
    {
        if (self.timerRequested != nil)
            self.timerRequested();
        
        if (!TGIsPad())
            [self setAllInterfaceHidden:true delay:0.0f animated:true];
    }
}

- (UIView *)timerButton
{
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
        return [_portraitToolbarView buttonForTab:TGPhotoEditorTimerTab];
    else
        return [_landscapeToolbarView buttonForTab:TGPhotoEditorTimerTab];
}

- (UIView *)qualityButton
{
    if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
        return [_portraitToolbarView buttonForTab:TGPhotoEditorQualityTab];
    else
        return [_landscapeToolbarView buttonForTab:TGPhotoEditorQualityTab];
}

- (void)setSelectedItemsModel:(TGMediaPickerGallerySelectedItemsModel *)selectedItemsModel
{
    _selectedPhotosView.selectedItemsModel = selectedItemsModel;
    [_selectedPhotosView reloadData];
    
    if (selectedItemsModel != nil && _selectedPhotosView != nil)
        _photoCounterButton.userInteractionEnabled = true;
}

- (void)setUsesSimpleLayout:(bool)usesSimpleLayout
{
    _usesSimpleLayout = usesSimpleLayout;
    _landscapeToolbarView.hidden = usesSimpleLayout;
}

- (void)itemFocused:(id<TGModernGalleryItem>)item itemView:(TGModernGalleryItemView *)itemView
{
    _currentItem = item;
    _currentItemView = itemView;
    
    [_currentItemView setSafeAreaInset:[self localSafeAreaInset]];
    
    UIEdgeInsets screenEdges = [self screenEdges];
    
    __weak TGMediaPickerGalleryInterfaceView *weakSelf = self;
    
    [self _layoutRecipientLabelForOrientation:[self interfaceOrientation] screenEdges:screenEdges hasHeaderView:(itemView.headerView != nil)];
    
    if (_selectionContext != nil)
    {
        _checkButton.frame = [self _checkButtonFrameForOrientation:[self interfaceOrientation] screenEdges:screenEdges hasHeaderView:(itemView.headerView != nil)];
        _groupButton.frame = [self _groupButtonFrameForOrientation:[self interfaceOrientation] screenEdges:screenEdges hasHeaderView:(itemView.headerView != nil)];
        
        SSignal *signal = nil;
        id<TGMediaSelectableItem>selectableItem = nil;
        if ([_currentItem conformsToProtocol:@protocol(TGModernGallerySelectableItem)])
            selectableItem = ((id<TGModernGallerySelectableItem>)_currentItem).selectableMediaItem;
        
        if (!_ignoreSetSelected) {
            [_checkButton setSelected:[_selectionContext isItemSelected:selectableItem] animated:false];
        }
        [_checkButton setNumber:[_selectionContext indexOfItem:selectableItem]];
        signal = [_selectionContext itemInformativeSelectedSignal:selectableItem];
        [_itemSelectedDisposable setDisposable:[signal startStrictWithNext:^(TGMediaSelectionChange *next)
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (next.sender != strongSelf->_checkButton)
                [strongSelf->_checkButton setSelected:next.selected animated:next.animated];
        } file:__FILE_NAME__ line:__LINE__]];
    }
    
    [self updateEditorButtonsForItem:item animated:true];
    
    __weak TGModernGalleryItemView *weakItemView = itemView;
    [_itemAvailabilityDisposable setDisposable:[[[itemView contentAvailabilityStateSignal] deliverOn:[SQueue mainQueue]] startStrictWithNext:^(id next)
    {
        __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
        __strong TGModernGalleryItemView *strongItemView = weakItemView;
        if (strongSelf == nil || strongItemView == nil)
            return;
        
        bool available = [next boolValue];
        
        NSString *itemId = nil;
        if ([strongItemView.item respondsToSelector:@selector(uniqueId)])
            itemId = [itemView.item performSelector:@selector(uniqueId)];
        
        NSString *currentId = nil;
        if ([strongSelf->_currentItem respondsToSelector:@selector(uniqueId)])
            currentId = [strongSelf->_currentItem performSelector:@selector(uniqueId)];
        
        if (strongItemView.item == strongSelf->_currentItem || [itemId isEqualToString:currentId])
        {
            [strongSelf->_portraitToolbarView setEditButtonsEnabled:available animated:true];
            [strongSelf->_landscapeToolbarView setEditButtonsEnabled:available animated:true];
            
            bool sendableAsGif = !strongSelf->_inhibitMute && [strongItemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]];
            if ([strongSelf->_currentItem isKindOfClass:[TGMediaPickerGalleryVideoItem class]]) {
                TGMediaPickerGalleryVideoItem *item = (TGMediaPickerGalleryVideoItem *)strongSelf->_currentItem;
                if ([item.asset isKindOfClass:[TGCameraCapturedVideo class]] && ((TGCameraCapturedVideo *)item.asset).isAnimation) {
                    sendableAsGif = false;
                }
            }
            strongSelf->_muteButton.hidden = !sendableAsGif;
            
            bool canHaveCover = false;
            if ([strongItemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]]) {
                TGMediaPickerGalleryVideoItemView *itemView = (TGMediaPickerGalleryVideoItemView *)strongItemView;
                if (itemView.editableMediaItem.originalDuration >= 60.0) {
                    canHaveCover = true;
                }
            }
            strongSelf->_coverButton.hidden = !canHaveCover;
        }
    } file:__FILE_NAME__ line:__LINE__]];
    
    UIImage *muteIcon = [TGPhotoEditorInterfaceAssets muteIcon];
    UIImage *muteActiveIcon = [TGPhotoEditorInterfaceAssets muteActiveIcon];
    if ([item isKindOfClass:[TGMediaPickerGalleryVideoItem class]]) {
        TGMediaPickerGalleryVideoItem *videoGalleryItem = (TGMediaPickerGalleryVideoItem *)item;
        if ([videoGalleryItem.editableMediaItem isKindOfClass:[TGMediaAsset class]]) {
            TGMediaAsset *asset = (TGMediaAsset *)videoGalleryItem.editableMediaItem;
            if (asset.type == TGMediaAssetPhotoType) {
                muteIcon = [TGPhotoEditorInterfaceAssets gifIcon];
                muteActiveIcon = [TGPhotoEditorInterfaceAssets gifActiveIcon];
            }
        }
    }
    [_muteButton setImage:muteIcon forState:UIControlStateNormal];
    [_muteButton setImage:muteActiveIcon forState:UIControlStateSelected];
    [_muteButton setImage:muteActiveIcon forState:UIControlStateSelected | UIControlStateHighlighted];
    
    [self setNeedsLayout];
}

- (TGPhotoEditorTab)currentTabs
{
    return _portraitToolbarView.currentTabs;
}

- (void)setTabBarUserInteractionEnabled:(bool)enabled
{
    _portraitToolbarView.userInteractionEnabled = enabled;
    _landscapeToolbarView.userInteractionEnabled = enabled;
}

- (void)setThumbnailSignalForItem:(SSignal *(^)(id))thumbnailSignalForItem
{
    [_selectedPhotosView setThumbnailSignalForItem:thumbnailSignalForItem];
}

- (void)cancelButtonPressed
{
    _ignoreSelectionUpdates = true;
    if (_cameraButton != nil && _selectionContext != nil)
    {
        __weak TGMediaPickerGalleryInterfaceView *weakSelf = self;
        
        TGMenuSheetController *controller = [[TGMenuSheetController alloc] initWithContext:_context dark:false];
        controller.dismissesByOutsideTap = true;
        controller.narrowInLandscape = true;
        __weak TGMenuSheetController *weakController = controller;
        
        NSArray *items = @
        [
            [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Camera.Discard") type:TGMenuSheetButtonTypeDefault fontSize:20.0 action:^
             {
                 __strong TGMenuSheetController *strongController = weakController;
                 if (strongController == nil)
                     return;
                 
                 __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
                 if (strongSelf == nil)
                     return;
                 
                 strongSelf->_capturing = false;
                 strongSelf->_closePressed();
                 
                 [strongController dismissAnimated:true manual:false completion:nil];
             }],
            [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Common.Cancel") type:TGMenuSheetButtonTypeCancel fontSize:20.0 action:^
             {
                 __strong TGMenuSheetController *strongController = weakController;
                 if (strongController != nil)
                     [strongController dismissAnimated:true];
             }]
        ];
        
        [controller setItemViews:items];
        controller.sourceRect = ^
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return CGRectZero;
            
            if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
                return [strongSelf convertRect:strongSelf->_portraitToolbarView.cancelButtonFrame fromView:strongSelf->_portraitToolbarView];
            else
                return [strongSelf convertRect:strongSelf->_landscapeToolbarView.cancelButtonFrame fromView:strongSelf->_landscapeToolbarView];
        };
        [controller presentInViewController:self.controller() sourceView:self animated:true];
    }
    else
    {
        _capturing = false;
        _closePressed();
    }
}

- (void)cameraButtonPressed
{
    _capturing = true;
    _closePressed();
}

- (void)checkButtonPressed
{
    if (_currentItem == nil)
        return;
    
    bool animated = false;
    if (!_selectedPhotosView.isAnimating)
        animated = true;
    
    id<TGMediaSelectableItem>selectableItem = nil;
    if ([_currentItem conformsToProtocol:@protocol(TGModernGallerySelectableItem)])
        selectableItem = ((id<TGModernGallerySelectableItem>)_currentItem).selectableMediaItem;
    
    _ignoreSetSelected = true;
    
    if (selectableItem != nil) {
        [_selectionContext setItem:selectableItem selected:!_checkButton.selected animated:animated sender:_checkButton];
        bool value = [_selectionContext isItemSelected:selectableItem];
        [_checkButton setSelected:value animated:true];
    } else {
        [_checkButton setSelected:!_checkButton.selected animated:true];
    }
    
    _ignoreSetSelected = false;
}

- (void)photoCounterButtonPressed
{
    bool selected = !_photoCounterButton.selected;
    [_photoCounterButton setSelected:!_photoCounterButton.selected animated:true];
    [_selectedPhotosView setHidden:!_photoCounterButton.selected animated:true];
    [_groupButton setHidden:!_photoCounterButton.selected animated:true];
    
    void (^changeBlock)(void) = ^
    {
        _cameraButton.frame = [self _cameraButtonFrameForOrientation:[self interfaceOrientation] screenEdges:[self screenEdges] hasHeaderView:(_currentItemView.headerView != nil) panelVisible:selected];
    };
    if (selected)
        [UIView animateWithDuration:0.45 delay:0.0 usingSpringWithDamping:0.8f initialSpringVelocity:0.1 options:kNilOptions animations:changeBlock completion:nil];
    else
        [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:changeBlock completion:nil];
    
    [self updateGroupingButtonVisibility];
}

- (void)coverButtonPressed
{
    [self coverEditorTransitionIn];
}

- (void)coverEditorTransitionIn {
    [self setAllInterfaceHidden:true keepHeader:true delay:0.0 animated:true];
    
    _coverTitleLabel.hidden = false;
    _cancelCoverButton.hidden = false;
    _saveCoverButton.hidden = false;
    _coverGalleryButton.hidden = false;
    
    _coverTitleLabel.alpha = 0.0;
    _cancelCoverButton.alpha = 0.0;
    _saveCoverButton.alpha = 0.0;
    _coverGalleryButton.alpha = 0.0;
    
    [UIView animateWithDuration:0.2 animations:^{
        _coverTitleLabel.alpha = 1.0;
        _cancelCoverButton.alpha = 1.0;
        _saveCoverButton.alpha = 1.0;
        _coverGalleryButton.alpha = 1.0;
        
        for (UIView *headerView in _itemHeaderViews) {
            if ([headerView isKindOfClass:[TGMediaPickerScrubberHeaderView class]]) {
                ((TGMediaPickerScrubberHeaderView *)headerView).scrubberView.alpha = 0.0f;
                ((TGMediaPickerScrubberHeaderView *)headerView).coverScrubberView.alpha = 1.0f;
            }
        }
    }];
    
    TGModernGalleryItemView *currentItemView = _currentItemView;
    if ([currentItemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]]) {
        [(TGMediaPickerGalleryVideoItemView *)currentItemView prepareForCoverEditing];
    }
    
    _setGesturesEnabled(false);
    _currentItemView.gesturesEnabled = false;
}

- (void)coverEditorTransitionOut {
    [self setAllInterfaceHidden:false keepHeader:true delay:0.0 animated:true];
    
    [_cancelCoverButton.layer removeAllAnimations];
    [_saveCoverButton.layer removeAllAnimations];
    
    [UIView animateWithDuration:0.3 animations:^{
        _coverTitleLabel.alpha = 0.0;
        _cancelCoverButton.alpha = 0.0;
        _saveCoverButton.alpha = 0.0;
        _coverGalleryButton.alpha = 0.0;
        
        for (UIView *headerView in _itemHeaderViews) {
            if ([headerView isKindOfClass:[TGMediaPickerScrubberHeaderView class]]) {
                ((TGMediaPickerScrubberHeaderView *)headerView).scrubberView.alpha = 1.0f;
                ((TGMediaPickerScrubberHeaderView *)headerView).coverScrubberView.alpha = 0.0f;
            }
        }
    } completion:^(BOOL finished) {
        _coverTitleLabel.hidden = true;
        _cancelCoverButton.hidden = true;
        _saveCoverButton.hidden = true;
        _coverGalleryButton.hidden = true;
    }];
    
    TGModernGalleryItemView *currentItemView = _currentItemView;
    if ([currentItemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]]) {
        [(TGMediaPickerGalleryVideoItemView *)currentItemView returnFromCoverEditing];
    }
    
    _setGesturesEnabled(true);
    _currentItemView.gesturesEnabled = true;
}

- (void)cancelCoverButtonPressed
{
    TGDispatchAfter(0.01, dispatch_get_main_queue(), ^{
        [self coverEditorTransitionOut];
    });
}

- (void)saveCoverButtonPressed
{
    id<TGModernGalleryEditableItem> galleryEditableItem = (id<TGModernGalleryEditableItem>)_currentItem;
    TGModernGalleryItemView *currentItemView = _currentItemView;
    if ([currentItemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]]) {
        id<TGMediaEditableItem> editableMediaItem = [galleryEditableItem editableMediaItem];
        [_editingContext setCoverImage:[(TGMediaPickerGalleryVideoItemView *)currentItemView screenImage] position:@([(TGMediaPickerGalleryVideoItemView *)currentItemView currentPosition]) forItem:editableMediaItem];
    }
    
    TGDispatchAfter(0.01, dispatch_get_main_queue(), ^{
        [self coverEditorTransitionOut];
    });
}

- (void)coverGalleryButtonPressed {
    if (_currentItem == nil)
        return;
    
    id<TGModernGalleryEditableItem> galleryEditableItem = (id<TGModernGalleryEditableItem>)_currentItem;
    if ([_currentItem conformsToProtocol:@protocol(TGModernGalleryEditableItem)])
    {
        id<TGMediaEditableItem> editableMediaItem = [galleryEditableItem editableMediaItem];
        CGSize originalSize = CGSizeZero;
        if ([editableMediaItem respondsToSelector:@selector(originalSize)])
            originalSize = editableMediaItem.originalSize;
        
        __weak TGMediaPickerGalleryInterfaceView *weakSelf = self;
        _captionMixin.stickersContext.editCover(originalSize, ^(UIImage *cover){
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            [strongSelf->_editingContext setCoverImage:cover position:nil forItem:editableMediaItem];
            [strongSelf coverEditorTransitionOut];
        });
    }
}

- (void)updateEditorButtonsForItem:(id<TGModernGalleryItem>)item animated:(bool)animated
{
    __weak TGMediaPickerGalleryInterfaceView *weakSelf = self;
    id<TGModernGalleryEditableItem> galleryEditableItem = (id<TGModernGalleryEditableItem>)item;
    if ([item conformsToProtocol:@protocol(TGModernGalleryEditableItem)])
    {
        id<TGMediaEditableItem> editableMediaItem = [galleryEditableItem editableMediaItem];
        [_captionDisposable setDisposable:[[galleryEditableItem.editingContext captionSignalForItem:editableMediaItem] startStrictWithNext:^(NSAttributedString *caption)
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            [strongSelf->_captionMixin setCaption:caption animated:animated];
        } file:__FILE_NAME__ line:__LINE__]];
        
        [_coverDisposable setDisposable:[[galleryEditableItem.editingContext coverImageSignalForItem:editableMediaItem] startStrictWithNext:^(UIImage *cover)
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            [strongSelf->_coverButton setImage:cover];
        } file:__FILE_NAME__ line:__LINE__]];
    }
    
    if (_editingContext == nil || _editingContext.inhibitEditing)
    {
        [_portraitToolbarView setEditButtonsHidden:true animated:false];
        [_landscapeToolbarView setEditButtonsHidden:true animated:false];
        return;
    }
    
    TGPhotoEditorTab tabs = TGPhotoEditorNoneTab;
    if ([item conformsToProtocol:@protocol(TGModernGalleryEditableItem)])
        tabs = [(id<TGModernGalleryEditableItem>)item toolbarTabs];
        
    if (iosMajorVersion() < 7 || self.onlyCrop)
    {
        tabs &= ~ TGPhotoEditorPaintTab;
        tabs &= ~ TGPhotoEditorToolsTab;
    }
    
    if (iosMajorVersion() < 8)
        tabs &= ~ TGPhotoEditorQualityTab;
    
    if (!self.hasTimer)
        tabs &= ~ TGPhotoEditorTimerTab;
    
    [_portraitToolbarView setToolbarTabs:tabs animated:animated];
    [_landscapeToolbarView setToolbarTabs:tabs animated:animated];
    
    bool editButtonsHidden = ![item conformsToProtocol:@protocol(TGModernGalleryEditableItem)];
    [_portraitToolbarView setEditButtonsHidden:editButtonsHidden animated:animated];
    [_landscapeToolbarView setEditButtonsHidden:editButtonsHidden animated:animated];
    
    if (editButtonsHidden)
    {
        [_adjustmentsDisposable setDisposable:nil];
        [_captionDisposable setDisposable:nil];
        return;
    }
    
    if ([item conformsToProtocol:@protocol(TGModernGalleryEditableItem)])
    {
        id<TGMediaEditableItem> editableMediaItem = [galleryEditableItem editableMediaItem];
        
        bool isCaptionAbove = galleryEditableItem.editingContext.isCaptionAbove;
        
        __weak id<TGModernGalleryEditableItem> weakGalleryEditableItem = galleryEditableItem;
        [_adjustmentsDisposable setDisposable:[[[[galleryEditableItem.editingContext adjustmentsSignalForItem:editableMediaItem] mapToSignal:^SSignal *(id<TGMediaEditAdjustments> adjustments) {
            __strong id<TGModernGalleryEditableItem> strongGalleryEditableItem = weakGalleryEditableItem;
            if (strongGalleryEditableItem != nil) {
                return [[strongGalleryEditableItem.editingContext timerSignalForItem:editableMediaItem] map:^id(id timer) {
                    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
                    if (adjustments != nil)
                        dict[@"adjustments"] = adjustments;
                    if (timer != nil)
                        dict[@"timer"] = timer;
                    return dict;
                }];
            } else {
                return [SSignal never];
            }
        }] deliverOn:[SQueue mainQueue]] startStrictWithNext:^(NSDictionary *dict)
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            id<TGMediaEditAdjustments> adjustments = dict[@"adjustments"];
            NSNumber *timer = dict[@"timer"];
            
            [strongSelf->_captionMixin setTimeout:[timer intValue] isVideo:editableMediaItem.isVideo isCaptionAbove:isCaptionAbove];
            
            if ([adjustments isKindOfClass:[TGVideoEditAdjustments class]])
            {
                TGVideoEditAdjustments *videoAdjustments = (TGVideoEditAdjustments *)adjustments;
                [strongSelf->_captionMixin setCaptionPanelHidden:(videoAdjustments.sendAsGif && strongSelf->_inhibitDocumentCaptions) animated:true];
            }
            else
            {
                [strongSelf->_captionMixin setCaptionPanelHidden:false animated:true];
            }
            
            CGSize originalSize = CGSizeZero;
            if ([editableMediaItem respondsToSelector:@selector(originalSize)])
                originalSize = editableMediaItem.originalSize;

            [strongSelf updateEditorButtonsForAdjustments:adjustments dimensions:originalSize timer:timer];
        } file:__FILE_NAME__ line:__LINE__]];
    }
    else
    {
        [_adjustmentsDisposable setDisposable:nil];
        [_captionDisposable setDisposable:nil];
        [self updateEditorButtonsForAdjustments:nil dimensions:CGSizeZero timer:nil];
        [_captionMixin setCaption:nil animated:animated];
    }
}

- (void)updateEditorButtonsForAdjustments:(id<TGMediaEditAdjustments>)adjustments dimensions:(CGSize)dimensions timer:(NSNumber *)timer
{
    TGPhotoEditorTab highlightedButtons = [TGPhotoEditorTabController highlightedButtonsForEditorValues:adjustments forAvatar:false];
    if (self.onlyCrop)
    {
        PGPhotoEditorValues *values = (PGPhotoEditorValues *)adjustments;
        CGFloat height = values.originalSize.width * 0.704f;
        CGFloat origin = floor((values.originalSize.height - height) / 2.0f);
        if (fabs(values.cropRect.size.width - values.originalSize.width) < FLT_EPSILON && fabs(values.cropRect.size.height - height) < FLT_EPSILON && fabs(values.cropRect.origin.y - origin) < FLT_EPSILON)
        {
            highlightedButtons &= ~ TGPhotoEditorCropTab;
        }
    }
    
    TGPhotoEditorTab disabledButtons = TGPhotoEditorNoneTab;
    
    _muteButton.selected = adjustments.sendAsGif;
    
    TGPhotoEditorButton *qualityButton = [_portraitToolbarView buttonForTab:TGPhotoEditorQualityTab];
    if (qualityButton != nil)
    {
        bool isPhoto = [_currentItemView isKindOfClass:[TGMediaPickerGalleryPhotoItemView class]] || [_currentItem isKindOfClass:[TGCameraCapturedPhoto class]];
        if (isPhoto) {
            bool isHd = _editingContext.isHighQualityPhoto;
            UIImage *icon = [TGPhotoEditorInterfaceAssets qualityIconForHighQuality:isHd filled: false];
            qualityButton.iconImage = icon;
            
            qualityButton = [_landscapeToolbarView buttonForTab:TGPhotoEditorQualityTab];
            qualityButton.iconImage = icon;
        } else {
            TGMediaVideoConversionPreset preset = 0;
            TGMediaVideoConversionPreset adjustmentsPreset = TGMediaVideoConversionPresetCompressedDefault;
            if ([adjustments isKindOfClass:[TGMediaVideoEditAdjustments class]])
                adjustmentsPreset = ((TGMediaVideoEditAdjustments *)adjustments).preset;
            
            if (adjustmentsPreset != TGMediaVideoConversionPresetCompressedDefault)
            {
                preset = adjustmentsPreset;
            }
            else
            {
                NSNumber *presetValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"TG_preferredVideoPreset_v0"];
                if (presetValue != nil)
                    preset = (TGMediaVideoConversionPreset)[presetValue integerValue];
                else
                    preset = TGMediaVideoConversionPresetCompressedMedium;
            }
            
            TGMediaVideoConversionPreset bestPreset = [TGMediaVideoConverter bestAvailablePresetForDimensions:dimensions];
            if (preset > bestPreset)
                preset = bestPreset;
            
            UIImage *icon = [TGPhotoEditorInterfaceAssets qualityIconForPreset:preset];
            qualityButton.iconImage = icon;
            
            qualityButton = [_landscapeToolbarView buttonForTab:TGPhotoEditorQualityTab];
            qualityButton.iconImage = icon;
        }
    }
    
    TGPhotoEditorButton *timerButton = [_portraitToolbarView buttonForTab:TGPhotoEditorTimerTab];
    if (timerButton != nil)
    {
        NSInteger value = [timer integerValue];
        
        UIImage *defaultIcon = [TGPhotoEditorInterfaceAssets timerIconForValue:0];
        UIImage *icon = [TGPhotoEditorInterfaceAssets timerIconForValue:value];
        [timerButton setIconImage:defaultIcon activeIconImage:icon];
        
        TGPhotoEditorButton *landscapeTimerButton = [_landscapeToolbarView buttonForTab:TGPhotoEditorTimerTab];
                
        timerButton = landscapeTimerButton;
        [timerButton setIconImage:defaultIcon activeIconImage:icon];
        
        if (value > 0)
            highlightedButtons |= TGPhotoEditorTimerTab;
    }
    
    if ([self shouldDisplayTooltip])
    {
        TGDispatchAfter(0.5, dispatch_get_main_queue(), ^
        {
            if (!TGIsPad() && self.frame.size.width > self.frame.size.height)
                [self setupTooltip:[_landscapeToolbarView convertRect:[_landscapeToolbarView doneButtonFrame] toView:self]];
            else
                [self setupTooltip:[_portraitToolbarView convertRect:[_portraitToolbarView doneButtonFrame] toView:self]];
        });
    }
    
    if (adjustments.sendAsGif)
        disabledButtons |= TGPhotoEditorQualityTab;
    
    [_portraitToolbarView setEditButtonsHighlighted:highlightedButtons];
    [_landscapeToolbarView setEditButtonsHighlighted:highlightedButtons];
    
    [_portraitToolbarView setEditButtonsDisabled:disabledButtons];
    [_landscapeToolbarView setEditButtonsDisabled:disabledButtons];
}

#pragma mark - Timer Tooltip

- (bool)shouldDisplayTooltip
{
    return [[[NSUserDefaults standardUserDefaults] objectForKey:@"TG_displayedMediaTimerTooltip_v3"] intValue] < 3;
}

- (void)setupTooltip:(CGRect)rect
{
    if (_tooltipContainerView != nil || !_hasTimer)
        return;
    
    _tooltipTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(tooltipTimerTick) interval:3.5 repeat:false];
    
    _tooltipContainerView = [[TGMenuContainerView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height)];
    [self addSubview:_tooltipContainerView];
    
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    [actions addObject:[[NSDictionary alloc] initWithObjectsAndKeys:TGLocalized(@"Media.SendingOptionsTooltip"), @"title", nil]];
    
    _tooltipContainerView.menuView.multiline = true;
    [_tooltipContainerView.menuView setButtonsAndActions:actions watcherHandle:_actionHandle];
    [_tooltipContainerView.menuView sizeToFit];
    _tooltipContainerView.menuView.buttonHighlightDisabled = true;
    
    [_tooltipContainerView showMenuFromRect:rect animated:false];
    
    int counter = [[[NSUserDefaults standardUserDefaults] objectForKey:@"TG_displayedMediaTimerTooltip_v3"] intValue];
    [[NSUserDefaults standardUserDefaults] setObject:@(counter + 1) forKey:@"TG_displayedMediaTimerTooltip_v3"];
}

- (void)tooltipTimerTick
{
    [_tooltipTimer invalidate];
    _tooltipTimer = nil;
    
    [_tooltipContainerView hideMenu];
}

- (void)showPhotoQualityTooltip:(bool)hd {
    [self updateEditorButtonsForItem:_currentItem animated:false];
    
    UIView *button = [self qualityButton];
    CGRect rect = [button convertRect:button.bounds toView:nil];
    [self showPhotoQualityTooltip:rect hd:hd];
}

- (void)showPhotoQualityTooltip:(CGRect)rect hd:(bool)hd
{
    if (_tooltipContainerView != nil) {
        [self tooltipTimerTick];
    }
    
    NSString *text = hd ? TGLocalized(@"Media.PhotoHdOn") : TGLocalized(@"Media.PhotoHdOff");
    [_context presentTooltip:text icon:[TGPhotoEditorInterfaceAssets qualityIconForHighQuality:hd filled: true] sourceRect:rect];
}

#pragma mark - Grouping Tooltip

- (void)actionStageActionRequested:(NSString *)action options:(id)__unused options
{
    if ([action isEqualToString:@"menuAction"])
    {
        [_tooltipTimer invalidate];
        _tooltipTimer = nil;
        
        [_tooltipContainerView hideMenu];
    }
}

#pragma mark -

- (void)updateSelectionInterface:(NSUInteger)selectedCount counterVisible:(bool)counterVisible animated:(bool)animated
{
    if (_ignoreSelectionUpdates)
        return;
    
    NSUInteger finalCount = MAX(1, selectedCount);
    _portraitToolbarView.sendPaidMessageStars = (_editingContext.sendPaidMessageStars * finalCount);
    [_portraitToolbarView setNeedsLayout];
    
    if (counterVisible)
    {
        bool animateCount = animated && !(counterVisible && _photoCounterButton.internalHidden);
        if (!animateCount && !_photoCounterButton.selected && !_photoCounterButton.internalHidden)
            animateCount = true;
        [_photoCounterButton setSelectedCount:selectedCount animated:animateCount];
        [_photoCounterButton setInternalHidden:false animated:animated completion:nil];
    }
    else
    {
        bool animate = animated || (selectedCount == 0 && !counterVisible);
        __weak TGMediaPickerPhotoCounterButton *weakButton = _photoCounterButton;
        [_photoCounterButton setInternalHidden:true animated:animate completion:^
        {
            __strong TGMediaPickerPhotoCounterButton *strongButton = weakButton;
            if (strongButton != nil)
            {
                strongButton.selected = false;
                [strongButton setSelectedCount:selectedCount animated:false];
            }
        }];
        [_selectedPhotosView setHidden:true animated:animated];
    }
}

- (void)updateSelectedPhotosView:(bool)reload incremental:(bool)incremental add:(bool)add index:(NSInteger)index
{
    if (_selectedPhotosView == nil)
        return;
    
    if (!reload)
        return;
    
    if (incremental)
    {
        if (add)
            [_selectedPhotosView insertItemAtIndex:index];
        else
            [_selectedPhotosView deleteItemAtIndex:index];
    }
    else
    {
        [_selectedPhotosView reloadData];
    }
}

- (void)setSelectionInterfaceHidden:(bool)hidden animated:(bool)animated
{
    [self setSelectionInterfaceHidden:hidden delay:0.0 animated:animated];
}

- (void)setSelectionInterfaceHidden:(bool)hidden delay:(NSTimeInterval)__unused delay animated:(bool)animated
{
    CGFloat alpha = (hidden ? 0.0f : 1.0f);
    if (animated)
    {
        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _checkButton.alpha = alpha;
            _muteButton.alpha = alpha;
            _coverButton.alpha = alpha;
            _arrowView.alpha = alpha * 0.6f;
            _recipientLabel.alpha = alpha * 0.6;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                _checkButton.userInteractionEnabled = !hidden;
                _muteButton.userInteractionEnabled = !hidden;
                _coverButton.userInteractionEnabled = !hidden;
            }
        }];
        
        [UIView animateWithDuration:0.2 delay:delay options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _cameraButton.alpha = alpha;
        } completion:^(BOOL finished)
        {
            if (finished)
                _cameraButton.userInteractionEnabled = !hidden;
        }];
    }
    else
    {
        _cameraButton.alpha = alpha;
        _cameraButton.userInteractionEnabled = !hidden;
        
        _checkButton.alpha = alpha;
        _checkButton.userInteractionEnabled = !hidden;
        
        _muteButton.alpha = alpha;
        _muteButton.userInteractionEnabled = !hidden;
        
        _coverButton.alpha = alpha;
        _coverButton.userInteractionEnabled = !hidden;
        
        _arrowView.alpha = alpha * 0.6f;
        _recipientLabel.alpha = alpha * 0.6;
    }
    
    if (hidden)
    {
        [_photoCounterButton setSelected:false animated:animated];
        [_selectedPhotosView setHidden:true animated:animated];
    }
    
    [_photoCounterButton setHidden:hidden delay:delay animated:animated];
    
    if (!_groupButton.hidden)
        [_groupButton setHidden:true animated:animated];
}

- (void)setAllInterfaceHidden:(bool)hidden delay:(NSTimeInterval)delay animated:(bool)animated {
    [self setAllInterfaceHidden:hidden keepHeader:false delay:delay animated:animated];
}

- (void)setAllInterfaceHidden:(bool)hidden keepHeader:(bool)keepHeader delay:(NSTimeInterval)__unused delay animated:(bool)animated
{
    CGFloat alpha = (hidden ? 0.0f : 1.0f);
    if (animated)
    {
        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _checkButton.alpha = alpha;
            _muteButton.alpha = alpha;
            _coverButton.alpha = alpha;
            _arrowView.alpha = alpha * 0.6;
            _recipientLabel.alpha = alpha * 0.6;
            _portraitToolbarView.alpha = alpha;
            _landscapeToolbarView.alpha = alpha;
            _captionMixin.inputPanelView.alpha = alpha;
            _captionMixin.backgroundView.alpha = alpha;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                _checkButton.userInteractionEnabled = !hidden;
                _muteButton.userInteractionEnabled = !hidden;
                _coverButton.userInteractionEnabled = !hidden;
                _portraitToolbarView.userInteractionEnabled = !hidden;
                _landscapeToolbarView.userInteractionEnabled = !hidden;
                _captionMixin.inputPanelView.userInteractionEnabled = !hidden;
                _captionMixin.backgroundView.userInteractionEnabled = !hidden;
            }
        }];
        
        [UIView animateWithDuration:0.2 delay:delay options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _cameraButton.alpha = alpha;
        } completion:^(BOOL finished)
        {
            if (finished)
                _cameraButton.userInteractionEnabled = !hidden;
        }];
    }
    else
    {
        _cameraButton.alpha = alpha;
        _cameraButton.userInteractionEnabled = !hidden;
        
        _checkButton.alpha = alpha;
        _checkButton.userInteractionEnabled = !hidden;
        
        _muteButton.alpha = alpha;
        _muteButton.userInteractionEnabled = !hidden;
        
        _coverButton.alpha = alpha;
        _coverButton.userInteractionEnabled = !hidden;
        
        _arrowView.alpha = alpha * 0.6;
        _recipientLabel.alpha = alpha;
        
        _portraitToolbarView.alpha = alpha;
        _portraitToolbarView.userInteractionEnabled = !hidden;
        
        _landscapeToolbarView.alpha = alpha;
        _landscapeToolbarView.userInteractionEnabled = !hidden;
        
        _captionMixin.inputPanelView.alpha = alpha;
        _captionMixin.inputPanelView.userInteractionEnabled = !hidden;
        
        _captionMixin.backgroundView.alpha = alpha;
        _captionMixin.backgroundView.userInteractionEnabled = !hidden;
    }
    
    if (hidden)
    {
        [_photoCounterButton setSelected:false animated:animated];
        [_selectedPhotosView setHidden:true animated:animated];
    }
    
    [_photoCounterButton setHidden:hidden delay:delay animated:animated];
    if (!_groupButton.hidden)
        [_groupButton setHidden:true animated:animated];
    
    [self setItemHeaderViewHidden:!keepHeader && hidden animated:animated];
}

#pragma mark - 

- (void)setItemHeaderViewHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.2f animations:^
        {
            for (UIView *view in _itemHeaderViews)
            {
                if (!view.hidden)
                    view.alpha = hidden ? 0.0f : 1.0f;
            }
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                for (UIView *view in _itemHeaderViews)
                {
                    if (!view.hidden)
                        view.userInteractionEnabled = !hidden;
                }
            }
        }];
    }
    else
    {
        for (UIView *view in _itemHeaderViews)
        {
            if (!view.hidden)
            {
                view.alpha = hidden ? 0.0f : 1.0f;
                view.userInteractionEnabled = !hidden;
            }
        }
    }
}

- (void)toggleSendAsGif
{
    if (![_currentItem conformsToProtocol:@protocol(TGModernGalleryEditableItem)])
        return;
    
    TGModernGalleryItemView *currentItemView = _currentItemView;
    bool sendableAsGif = [currentItemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]];
    if (sendableAsGif)
        [(TGMediaPickerGalleryVideoItemView *)currentItemView toggleSendAsGif];
}

- (void)toggleGrouping
{
    [_selectionContext toggleGrouping];
}

- (CGRect)itemFooterViewFrameForSize:(CGSize)size
{
    CGFloat padding = TGPhotoEditorToolbarSize;
    return CGRectMake(padding, 0.0f, size.width - padding * 2.0f, TGPhotoEditorToolbarSize);
}

- (void)addItemHeaderView:(UIView *)itemHeaderView
{
    if (itemHeaderView == nil)
        return;
    
    [_itemHeaderViews addObject:itemHeaderView];
    [_headerWrapperView addSubview:itemHeaderView];
    itemHeaderView.frame = _headerWrapperView.bounds;
}

- (void)removeItemHeaderView:(UIView *)itemHeaderView
{
    if (itemHeaderView == nil)
        return;
    
    [itemHeaderView removeFromSuperview];
    [_itemHeaderViews removeObject:itemHeaderView];
}

- (void)addItemFooterView:(UIView *)itemFooterView
{
    if (itemFooterView == nil)
        return;
    
    [_itemFooterViews addObject:itemFooterView];
    [_portraitToolbarView addSubview:itemFooterView];
    itemFooterView.frame = [self itemFooterViewFrameForSize:self.frame.size];
}

- (void)removeItemFooterView:(UIView *)itemFooterView
{
    if (itemFooterView == nil)
        return;
    
    [itemFooterView removeFromSuperview];
    [_itemFooterViews removeObject:itemFooterView];
}

- (void)addItemLeftAcessoryView:(UIView *)__unused itemLeftAcessoryView
{
    
}

- (void)removeItemLeftAcessoryView:(UIView *)__unused itemLeftAcessoryView
{
    
}

- (void)addItemRightAcessoryView:(UIView *)__unused itemRightAcessoryView
{
    
}

- (void)removeItemRightAcessoryView:(UIView *)__unused itemRightAcessoryView
{
    
}

- (void)animateTransitionInWithDuration:(NSTimeInterval)__unused dutation
{
    
}

- (void)animateTransitionOutWithDuration:(NSTimeInterval)__unused duration
{
    [_captionMixin onAnimateOut];
}

- (void)onDismiss {
    [_captionMixin onAnimateOut];
}

- (void)setTransitionOutProgress:(CGFloat)transitionOutProgress manual:(bool)manual
{
    [_captionMixin onAnimateOut];
    if (transitionOutProgress > FLT_EPSILON)
        [self setAllInterfaceHidden:true delay:0.0 animated:true];
    else if (!manual)
        [self setAllInterfaceHidden:false delay:0.0 animated:true];
}

- (void)setToolbarsHidden:(bool)hidden animated:(bool)animated
{
    if (hidden)
    {
        [_portraitToolbarView transitionOutAnimated:animated transparent:true hideOnCompletion:false];
        [_landscapeToolbarView transitionOutAnimated:animated transparent:true hideOnCompletion:false];
    }
    else
    {
        [_portraitToolbarView transitionInAnimated:animated transparent:true];
        [_landscapeToolbarView transitionInAnimated:animated transparent:true];
    }
}

- (void)immediateEditorTransitionIn {
    [self setSelectionInterfaceHidden:true animated:false];
    _captionMixin.inputPanelView.alpha = 0.0f;
    _captionMixin.backgroundView.alpha = 0.0f;
    _portraitToolbarView.doneButton.alpha = 0.0f;
    _landscapeToolbarView.doneButton.alpha = 0.0f;
    
    _portraitToolbarView.hidden = true;
    _landscapeToolbarView.hidden = true;
    
    TGDispatchAfter(0.5, dispatch_get_main_queue(), ^
    {
        _portraitToolbarView.hidden = false;
        _landscapeToolbarView.hidden = false;
    });
}

- (void)editorTransitionIn
{
    [self setSelectionInterfaceHidden:true animated:true];
    
    [UIView animateWithDuration:0.2 animations:^
    {
        _captionMixin.inputPanelView.alpha = 0.0f;
        _captionMixin.backgroundView.alpha = 0.0f;
        _portraitToolbarView.doneButton.alpha = 0.0f;
        _landscapeToolbarView.doneButton.alpha = 0.0f;
    }];
}

- (void)editorTransitionOut
{
    [self setSelectionInterfaceHidden:false animated:true];
    
    [UIView animateWithDuration:0.3 animations:^
    {
        _captionMixin.inputPanelView.alpha = 1.0f;
        _captionMixin.backgroundView.alpha = 1.0f;
        _portraitToolbarView.doneButton.alpha = 1.0f;
        _landscapeToolbarView.doneButton.alpha = 1.0f;
    }];
}

#pragma mark -

- (UIView *)hitTestWithSpecialHandling:(UIView *)view point:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *subview in [view.subviews reverseObjectEnumerator]) {
        if ([subview isKindOfClass:[TGMediaPickerGalleryWrapperView class]]) {
            UIView *result = [self hitTestWithSpecialHandling:subview point:[view convertPoint:point toView:subview] withEvent:event];
            if (result) {
                return result;
            }
        } else {
            UIView *result = [subview hitTest:[view convertPoint:point toView:subview] withEvent:event];
            if (result) {
                return result;
            }
        }
    }
    
    return nil;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [self hitTestWithSpecialHandling:self point:point withEvent:event];
    
    bool editingCover = false;
    if (_coverTitleLabel != nil && !_coverTitleLabel.isHidden) {
        editingCover = true;
    }
    if (!editingCover) {
        if (view == _photoCounterButton
            || view == _checkButton
            || view == _muteButton
            || view == _groupButton
            || view == _cameraButton
            || view == _coverButton
            || [view isDescendantOfView:_headerWrapperView]
            || [view isDescendantOfView:_portraitToolbarView]
            || [view isDescendantOfView:_landscapeToolbarView]
            || [view isDescendantOfView:_selectedPhotosView]
            || [view isDescendantOfView:_captionMixin.inputPanelView]
            || ([view isDescendantOfView:_captionMixin.dismissView] && _captionMixin.dismissView.alpha > 0.0)
            || [view isKindOfClass:[TGMenuButtonView class]])
            
        {
            return view;
        }
    } else {
        if (view == _cancelCoverButton
            || view == _saveCoverButton
            || view == _coverGalleryButton
            || [view isDescendantOfView:_headerWrapperView])
        {
            return view;
        }
    }
    
    return nil;
}

- (bool)prefersStatusBarHidden
{
    return true;
}

- (bool)allowsHide
{
    return true;
}

- (bool)showHiddenInterfaceOnScroll
{
    return true;
}

- (bool)allowsDismissalWithSwipeGesture
{
    return self.hasSwipeGesture;
}

- (bool)shouldAutorotate
{
    return true;
}

- (CGRect)_muteButtonFrameForOrientation:(UIInterfaceOrientation)orientation screenEdges:(UIEdgeInsets)screenEdges hasHeaderView:(bool)hasHeaderView
{
    CGRect frame = CGRectZero;
    if (_safeAreaInset.top > 20.0f)
        screenEdges.top += _safeAreaInset.top;
    screenEdges.left += _safeAreaInset.left;
    screenEdges.right -= _safeAreaInset.right;
    
    CGFloat panelInset = 0.0f;
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
            frame = CGRectMake(screenEdges.right - 47, screenEdges.bottom - 54 - 59, _muteButton.frame.size.width, _muteButton.frame.size.height);
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            frame = CGRectMake(screenEdges.left + 5, screenEdges.bottom - 54 - 59, _muteButton.frame.size.width, _muteButton.frame.size.height);
            break;
            
        default:
            frame = CGRectMake(screenEdges.left + 5, screenEdges.bottom - TGPhotoEditorToolbarSize - [_captionMixin.inputPanel baseHeight] - 26 - _safeAreaInset.bottom - panelInset - (hasHeaderView ? 64.0 : 0.0), _muteButton.frame.size.width, _muteButton.frame.size.height);
            break;
    }
    
    return frame;
}

- (CGRect)_groupButtonFrameForOrientation:(UIInterfaceOrientation)orientation screenEdges:(UIEdgeInsets)screenEdges hasHeaderView:(bool)hasHeaderView
{
    CGRect frame = CGRectZero;
    if (_safeAreaInset.top > 20.0f)
        screenEdges.top += _safeAreaInset.top;
    screenEdges.left += _safeAreaInset.left;
    screenEdges.right -= _safeAreaInset.right;
    screenEdges.bottom -= _safeAreaInset.bottom;
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
            frame = CGRectMake(screenEdges.left + TGPhotoEditorToolbarSize + 14, screenEdges.bottom - _groupButton.frame.size.height - 1.0f + _safeAreaInset.bottom, _groupButton.frame.size.width, _groupButton.frame.size.height);
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            frame = CGRectMake(screenEdges.right - TGPhotoEditorToolbarSize - 38 - 14, screenEdges.bottom - _groupButton.frame.size.height - 1.0f + _safeAreaInset.bottom, _groupButton.frame.size.width, _groupButton.frame.size.height);
            break;
            
        default:
            frame = CGRectMake(screenEdges.left + 6.0f, screenEdges.bottom - TGPhotoEditorToolbarSize - [_captionMixin.inputPanel baseHeight] - 40.0f, _groupButton.frame.size.width, _groupButton.frame.size.height);
            break;
    }
    
    return frame;
}

- (CGRect)_coverButtonFrameForOrientation:(UIInterfaceOrientation)orientation screenEdges:(UIEdgeInsets)screenEdges hasHeaderView:(bool)hasHeaderView
{
    CGRect frame = CGRectZero;
    if (_safeAreaInset.top > 20.0f)
        screenEdges.top += _safeAreaInset.top;
    screenEdges.left += _safeAreaInset.left;
    screenEdges.right -= _safeAreaInset.right;
    screenEdges.bottom -= _safeAreaInset.bottom;

    CGFloat panelInset = 0.0f;
    frame = CGRectMake(screenEdges.left + ((screenEdges.right - screenEdges.left) - _coverButton.frame.size.width) / 2.0, screenEdges.bottom - TGPhotoEditorToolbarSize - [_captionMixin.inputPanel baseHeight] - 49 - _safeAreaInset.bottom - panelInset, _coverButton.frame.size.width, _coverButton.frame.size.height);
    return frame;
}

- (CGRect)_coverGalleryButtonFrameForOrientation:(UIInterfaceOrientation)orientation screenEdges:(UIEdgeInsets)screenEdges hasHeaderView:(bool)hasHeaderView
{
    CGRect frame = CGRectZero;
    if (_safeAreaInset.top > 20.0f)
        screenEdges.top += _safeAreaInset.top;
    screenEdges.left += _safeAreaInset.left;
    screenEdges.right -= _safeAreaInset.right;
    screenEdges.bottom -= _safeAreaInset.bottom;

    CGFloat panelInset = 0.0f;
    frame = CGRectMake(screenEdges.left + ((screenEdges.right - screenEdges.left) - _coverButton.frame.size.width) / 2.0, screenEdges.bottom - TGPhotoEditorToolbarSize - [_captionMixin.inputPanel baseHeight] - 33 - _safeAreaInset.bottom - panelInset, _coverButton.frame.size.width, _coverButton.frame.size.height);
    return frame;
}

- (CGRect)_checkButtonFrameForOrientation:(UIInterfaceOrientation)orientation screenEdges:(UIEdgeInsets)screenEdges hasHeaderView:(bool)hasHeaderView
{
    CGRect frame = CGRectZero;
    if (_safeAreaInset.top > 20.0f)
        screenEdges.top += _safeAreaInset.top;
    screenEdges.left += _safeAreaInset.left;
    screenEdges.right -= _safeAreaInset.right;
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
            frame = CGRectMake(screenEdges.right - 44, screenEdges.top + 5, _checkButton.frame.size.width, _checkButton.frame.size.height);
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            frame = CGRectMake(screenEdges.left + 4, screenEdges.top + 5, _checkButton.frame.size.width, _checkButton.frame.size.height);
            break;
            
        default:
            frame = CGRectMake(screenEdges.right - 44, screenEdges.top + 5, _checkButton.frame.size.width, _checkButton.frame.size.height);
            break;
    }
    
    return frame;
}

- (CGRect)_cameraButtonFrameForOrientation:(UIInterfaceOrientation)orientation screenEdges:(UIEdgeInsets)screenEdges hasHeaderView:(bool)hasHeaderView panelVisible:(bool)panelVisible
{
    CGRect frame = CGRectZero;
    if (_safeAreaInset.top > 20.0f)
        screenEdges.top += _safeAreaInset.top;
    screenEdges.left += _safeAreaInset.left;
    screenEdges.right -= _safeAreaInset.right;
    
    CGFloat headerInset = hasHeaderView ? 64.0f : 0.0f;
    CGFloat buttonInset = _selectionContext != nil ? 50.0f : 0.0f;
    CGFloat panelInset = 0.0f;
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
            frame = CGRectMake(screenEdges.left + TGPhotoEditorToolbarSize + 1 + _safeAreaInset.left - 34.0f, screenEdges.top + 1 + headerInset + buttonInset, 44, 44);
            break;
    
        case UIInterfaceOrientationLandscapeRight:
             frame = CGRectMake(screenEdges.right - TGPhotoEditorToolbarSize - 1 - _safeAreaInset.right - 11.0f, screenEdges.top + 1 + headerInset + buttonInset, 44, 44);
            break;
    
        default:
             frame = CGRectMake(screenEdges.right - 46 - _safeAreaInset.right - buttonInset, screenEdges.bottom - TGPhotoEditorToolbarSize - [_captionMixin.inputPanel baseHeight] - 45 - _safeAreaInset.bottom - panelInset - (hasHeaderView ? 64.0 : 0.0), 44, 44);
            break;
    }
    
    return frame;
}

- (void)_layoutRecipientLabelForOrientation:(UIInterfaceOrientation)orientation screenEdges:(UIEdgeInsets)screenEdges hasHeaderView:(bool)hasHeaderView
{
    CGFloat screenWidth = MIN(self.frame.size.width, self.frame.size.height);
    CGFloat recipientWidth = MIN(_recipientLabel.frame.size.width, screenWidth - 150.0f);
    
    CGRect frame = CGRectZero;
    if (_safeAreaInset.top > 20.0f + FLT_EPSILON)
        screenEdges.top += _safeAreaInset.top;
    screenEdges.left += _safeAreaInset.left;
    screenEdges.right -= _safeAreaInset.right;
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
            frame = CGRectMake(screenEdges.right - recipientWidth - 28.0f, screenEdges.bottom - 24, _arrowView.frame.size.width, _arrowView.frame.size.height);
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            frame = CGRectMake(screenEdges.left + 14, screenEdges.bottom - 24, _arrowView.frame.size.width, _arrowView.frame.size.height);
            break;
            
        default:
            frame = CGRectMake(screenEdges.left + 14, screenEdges.top + 16, _arrowView.frame.size.width, _arrowView.frame.size.height);
            break;
    }
    
    _arrowView.frame = frame;
    _recipientLabel.frame = CGRectMake(CGRectGetMaxX(_arrowView.frame) + 6.0f, _arrowView.frame.origin.y - 2.0f, recipientWidth, _recipientLabel.frame.size.height);
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)__unused duration
{
    _landscapeToolbarView.interfaceOrientation = toInterfaceOrientation;
    [self setNeedsLayout];
}

- (UIInterfaceOrientation)interfaceOrientation
{
    UIInterfaceOrientation orientation = [[LegacyComponentsGlobals provider] applicationStatusBarOrientation];
    if (self.usesSimpleLayout || TGIsPad())
        orientation = UIInterfaceOrientationPortrait;
    
    return orientation;
}

- (CGSize)referenceViewSize
{
    return [_context fullscreenBounds].size;
}

- (void)setSafeAreaInset:(UIEdgeInsets)safeAreaInset
{
    _safeAreaInset = safeAreaInset;
    _captionMixin.safeAreaInset = safeAreaInset;
    [_currentItemView setSafeAreaInset:[self localSafeAreaInset]];
    [self setNeedsLayout];
}

- (UIEdgeInsets)localSafeAreaInset
{
    UIEdgeInsets safeAreaInset = _safeAreaInset;
    if (self.usesSimpleLayout || TGIsPad())
        return safeAreaInset;
    
    UIInterfaceOrientation orientation = [self interfaceOrientation];
    if (orientation == UIInterfaceOrientationLandscapeLeft)
        safeAreaInset.left = 0.0f;
    else if (orientation == UIInterfaceOrientationLandscapeRight)
        safeAreaInset.right = 0.0f;
    
    return safeAreaInset;
}

- (UIEdgeInsets)screenEdges
{
    CGSize screenSize = TGScreenSize();
    if (TGIsPad())
        screenSize = [self referenceViewSize];
    CGFloat screenSide = MAX(screenSize.width, screenSize.height);
    UIEdgeInsets screenEdges = UIEdgeInsetsZero;
    
    if (TGIsPad())
    {
        screenEdges = UIEdgeInsetsMake(0, 0, self.frame.size.height, self.frame.size.width);
    }
    else
    {
        screenEdges = UIEdgeInsetsMake((screenSide - self.frame.size.height) / 2, (screenSide - self.frame.size.width) / 2, (screenSide + self.frame.size.height) / 2, (screenSide + self.frame.size.width) / 2);
    }
    return screenEdges;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [_captionMixin setContentAreaHeight:self.frame.size.height];
    
    UIInterfaceOrientation orientation = [self interfaceOrientation];
    CGSize screenSize = TGScreenSize();
    if (TGIsPad())
        screenSize = [self referenceViewSize];
    
    CGFloat screenSide = MAX(screenSize.width, screenSize.height);
    UIEdgeInsets screenEdges = UIEdgeInsetsZero;
    
    if (TGIsPad())
    {
        _landscapeToolbarView.hidden = true;
        screenEdges = UIEdgeInsetsMake(0, 0, self.frame.size.height, self.frame.size.width);
        _wrapperView.frame = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    }
    else
    {
        screenEdges = UIEdgeInsetsMake((screenSide - self.frame.size.height) / 2, (screenSide - self.frame.size.width) / 2, (screenSide + self.frame.size.height) / 2, (screenSide + self.frame.size.width) / 2);
        _wrapperView.frame = CGRectMake((self.frame.size.width - screenSide) / 2, (self.frame.size.height - screenSide) / 2, screenSide, screenSide);
    }
    
    _selectedPhotosView.interfaceOrientation = orientation;
    
    CGFloat photosViewSize = TGPhotoThumbnailSizeForCurrentScreen().height + 4 * 2;
    
    bool hasHeaderView = (_currentItemView.headerView != nil);
    CGFloat headerInset = hasHeaderView ? 64.0f : 0.0f;
    
    CGFloat portraitToolbarViewBottomEdge = screenSide;
    if (self.usesSimpleLayout || TGIsPad())
        portraitToolbarViewBottomEdge = screenEdges.bottom;
    _portraitToolbarView.frame = CGRectMake(screenEdges.left, portraitToolbarViewBottomEdge - TGPhotoEditorToolbarSize - _safeAreaInset.bottom, self.frame.size.width, TGPhotoEditorToolbarSize + _safeAreaInset.bottom);
    
    CGFloat coverTitleTopY = screenEdges.top;
    if (_safeAreaInset.top > 20.0f + FLT_EPSILON)
        coverTitleTopY += _safeAreaInset.top;
    
    _saveCoverButton.frame = CGRectMake(screenEdges.left + 16.0, portraitToolbarViewBottomEdge - 50.0 - 16.0 - _safeAreaInset.bottom, self.frame.size.width - 16.0 * 2.0, 50.0);
    _cancelCoverButton.frame = CGRectMake(screenEdges.left + 16.0, coverTitleTopY + 20, _cancelCoverButton.frame.size.width, _cancelCoverButton.frame.size.height);
    _coverTitleLabel.frame = CGRectMake(screenEdges.left + floor((self.frame.size.width - _coverTitleLabel.frame.size.width) / 2.0), coverTitleTopY + 26, _coverTitleLabel.frame.size.width, _coverTitleLabel.frame.size.height);
    
    UIEdgeInsets captionEdgeInsets = screenEdges;
    captionEdgeInsets.bottom = _portraitToolbarView.frame.size.height;
    [_captionMixin updateLayoutWithFrame:self.bounds edgeInsets:captionEdgeInsets animated:false];
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            [UIView performWithoutAnimation:^
            {
                _photoCounterButton.frame = CGRectMake(screenEdges.left + TGPhotoEditorToolbarSize + 1 + _safeAreaInset.left, screenEdges.top + 6 + headerInset, 64, 38);
                
                _selectedPhotosView.frame = CGRectMake(screenEdges.left + TGPhotoEditorToolbarSize + 66 + _safeAreaInset.left, screenEdges.top + 4 + headerInset, photosViewSize, self.frame.size.height - 4 * 2 - headerInset);
                
                _landscapeToolbarView.frame = CGRectMake(screenEdges.left + _safeAreaInset.left, screenEdges.top, TGPhotoEditorToolbarSize + _safeAreaInset.left, self.frame.size.height);
            }];
            
            _headerWrapperView.frame = CGRectMake(screenEdges.left + TGPhotoEditorToolbarSize + _safeAreaInset.left, screenEdges.top, self.frame.size.width - TGPhotoEditorToolbarSize - _safeAreaInset.left, 64);
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            [UIView performWithoutAnimation:^
            {
                _photoCounterButton.frame = CGRectMake(screenEdges.right - TGPhotoEditorToolbarSize - 64 - 1 - _safeAreaInset.right, screenEdges.top + 6 + headerInset, 64, 38);
                
                _selectedPhotosView.frame = CGRectMake(screenEdges.right - TGPhotoEditorToolbarSize - photosViewSize - 66 - _safeAreaInset.right, screenEdges.top + 4 + headerInset, photosViewSize, self.frame.size.height - 4 * 2 - headerInset);
                
                _landscapeToolbarView.frame = CGRectMake(screenEdges.right - TGPhotoEditorToolbarSize - _safeAreaInset.right, screenEdges.top, TGPhotoEditorToolbarSize + _safeAreaInset.right, self.frame.size.height);
            }];
            
            _headerWrapperView.frame = CGRectMake(screenEdges.left, screenEdges.top, self.frame.size.width - TGPhotoEditorToolbarSize - _safeAreaInset.right, 64);
        }
            break;
            
        default:
        {
            [UIView performWithoutAnimation:^
            {
                _photoCounterButton.frame = CGRectMake(screenEdges.right - 56 - _safeAreaInset.right, screenEdges.bottom - TGPhotoEditorToolbarSize - [_captionMixin.inputPanel baseHeight] - 40 - _safeAreaInset.bottom - (hasHeaderView ? 46.0 : 0.0), 64, 38);
                
                _selectedPhotosView.frame = CGRectMake(screenEdges.left + 4, screenEdges.bottom - TGPhotoEditorToolbarSize - [_captionMixin.inputPanel baseHeight] - photosViewSize - 54 - _safeAreaInset.bottom - (hasHeaderView ? 46.0 : 0.0), self.frame.size.width - 4 * 2 - _safeAreaInset.right, photosViewSize);
            }];
            
            _landscapeToolbarView.frame = CGRectMake(_landscapeToolbarView.frame.origin.x, screenEdges.top, TGPhotoEditorToolbarSize, self.frame.size.height);
            
            _headerWrapperView.frame = CGRectMake(screenEdges.left, _portraitToolbarView.frame.origin.y - 64.0 - [_captionMixin.inputPanel baseHeight], self.frame.size.width, 72.0);
        }
            break;
    }
    
    _muteButton.frame = [self _muteButtonFrameForOrientation:orientation screenEdges:screenEdges hasHeaderView:true];
    _checkButton.frame = [self _checkButtonFrameForOrientation:orientation screenEdges:screenEdges hasHeaderView:hasHeaderView];
    _groupButton.frame = [self _groupButtonFrameForOrientation:orientation screenEdges:screenEdges hasHeaderView:hasHeaderView];
    _coverButton.frame = [self _coverButtonFrameForOrientation:orientation screenEdges:screenEdges hasHeaderView:hasHeaderView];
    _coverGalleryButton.frame = [self _coverGalleryButtonFrameForOrientation:orientation screenEdges:screenEdges hasHeaderView:hasHeaderView];
    
    [UIView performWithoutAnimation:^
    {
        _cameraButton.frame = [self _cameraButtonFrameForOrientation:orientation screenEdges:screenEdges hasHeaderView:hasHeaderView panelVisible:_selectedPhotosView != nil && !_selectedPhotosView.isInternalHidden];
    }];
    [self _layoutRecipientLabelForOrientation:orientation screenEdges:screenEdges hasHeaderView:hasHeaderView];
    
    for (UIView *itemHeaderView in _itemHeaderViews)
        itemHeaderView.frame = _headerWrapperView.bounds;
    
    CGRect itemFooterViewFrame = [self itemFooterViewFrameForSize:self.frame.size];
    for (UIView *itemFooterView in _itemFooterViews)
        itemFooterView.frame = itemFooterViewFrame;
}

- (CGRect)doneButtonFrame {
    if (UIDeviceOrientationIsPortrait((UIDeviceOrientation)[self interfaceOrientation])) {
        return [_portraitToolbarView.doneButton convertRect:_portraitToolbarView.doneButton.bounds toView:nil];
    } else {
        return [_landscapeToolbarView.doneButton convertRect:_landscapeToolbarView.doneButton.bounds toView:nil];
    }
}

@end
