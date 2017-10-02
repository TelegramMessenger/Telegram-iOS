#import "TGMediaPickerGalleryInterfaceView.h"

#import "LegacyComponentsInternal.h"
#import "TGImageUtils.h"
#import "TGFont.h"

#import <SSignalKit/SSignalKit.h>

#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGObserverProxy.h>

#import <LegacyComponents/TGModernButton.h>

#import <LegacyComponents/TGMediaSelectionContext.h>
#import <LegacyComponents/TGMediaEditingContext.h>
#import <LegacyComponents/TGVideoEditAdjustments.h>
#import <LegacyComponents/TGMediaVideoConverter.h>
#import "TGMediaPickerGallerySelectedItemsModel.h"

#import "TGModernGallerySelectableItem.h"
#import "TGModernGalleryEditableItem.h"
#import "TGMediaPickerGalleryPhotoItemView.h"
#import "TGMediaPickerGalleryVideoItemView.h"

#import <LegacyComponents/TGMessageImageViewOverlayView.h>

#import <LegacyComponents/TGPhotoEditorTabController.h>
#import <LegacyComponents/TGPhotoToolbarView.h>
#import <LegacyComponents/TGPhotoEditorButton.h>
#import "TGCheckButtonView.h"
#import "TGMediaPickerPhotoCounterButton.h"
#import "TGMediaPickerPhotoStripView.h"

#import "TGMediaPickerScrubberHeaderView.h"

#import <LegacyComponents/TGMenuView.h>

#import <LegacyComponents/TGPhotoCaptionInputMixin.h>

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
    TGMediaPickerPhotoCounterButton *_photoCounterButton;
    
    TGMediaPickerPhotoStripView *_selectedPhotosView;
    
    SMetaDisposable *_adjustmentsDisposable;
    SMetaDisposable *_captionDisposable;
    SMetaDisposable *_itemAvailabilityDisposable;
    SMetaDisposable *_itemSelectedDisposable;
    
    NSTimer *_tooltipTimer;
    TGMenuContainerView *_tooltipContainerView;
    
    void (^_closePressed)();
    void (^_scrollViewOffsetRequested)(CGFloat offset);
    
    id<LegacyComponentsContext> _context;
}

@property (nonatomic, strong) ASHandle *actionHandle;

@end

@implementation TGMediaPickerGalleryInterfaceView

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context focusItem:(id<TGModernGalleryItem>)focusItem selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext hasSelectionPanel:(bool)hasSelectionPanel recipientName:(NSString *)recipientName
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        _context = context;
        _selectionContext = selectionContext;
        _editingContext = editingContext;
        
        _hasSwipeGesture = true;
        
        _itemHeaderViews = [[NSMutableArray alloc] init];
        _itemFooterViews = [[NSMutableArray alloc] init];
        
        _wrapperView = [[UIView alloc] initWithFrame:CGRectZero];
        [self addSubview:_wrapperView];
        
        _headerWrapperView = [[UIView alloc] init];
        [_wrapperView addSubview:_headerWrapperView];
        
        __weak TGMediaPickerGalleryInterfaceView *weakSelf = self;
        void(^toolbarCancelPressed)(void) = ^
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            strongSelf->_closePressed();
        };
        void(^toolbarDonePressed)(void) = ^
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf.window endEditing:true];
            strongSelf->_donePressed(strongSelf->_currentItem);
        };
        
        static dispatch_once_t onceToken;
        static UIImage *muteBackground;
        dispatch_once(&onceToken, ^
        {
            CGRect rect = CGRectMake(0, 0, 39.0f, 39.0f);
            UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetFillColorWithColor(context, UIColorRGBA(0x000000, 0.6f).CGColor);
            CGContextFillEllipseInRect(context, CGRectInset(rect, 3, 3));
            
            muteBackground = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _muteButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 39.0f, 39.0f)];
        _muteButton.hidden = true;
        _muteButton.adjustsImageWhenHighlighted = false;
        [_muteButton setBackgroundImage:muteBackground forState:UIControlStateNormal];
        [_muteButton setImage:[TGPhotoEditorInterfaceAssets gifIcon] forState:UIControlStateNormal];
        [_muteButton setImage:[TGPhotoEditorInterfaceAssets gifActiveIcon] forState:UIControlStateSelected];
        [_muteButton setImage:[TGPhotoEditorInterfaceAssets gifActiveIcon]  forState:UIControlStateSelected | UIControlStateHighlighted];
        [_muteButton addTarget:self action:@selector(toggleSendAsGif) forControlEvents:UIControlEventTouchUpInside];
        [_wrapperView addSubview:_muteButton];
        
        if (recipientName.length > 0)
        {
            _arrowView = [[UIImageView alloc] initWithImage:TGComponentsImageNamed(@"PhotoPickerArrow")];
            _arrowView.alpha = 0.45f;
            [_wrapperView addSubview:_arrowView];
            
            _recipientLabel = [[UILabel alloc] init];
            _recipientLabel.backgroundColor = [UIColor clearColor];
            _recipientLabel.font = TGBoldSystemFontOfSize(13.0f);
            _recipientLabel.textColor = UIColorRGBA(0xffffff, 0.45f);
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
        
            _photoCounterButton = [[TGMediaPickerPhotoCounterButton alloc] initWithFrame:CGRectMake(0, 0, 64, 38)];
            [_photoCounterButton addTarget:self action:@selector(photoCounterButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            _photoCounterButton.userInteractionEnabled = false;
            [_wrapperView addSubview:_photoCounterButton];
        }
        
        [self updateEditorButtonsForItem:focusItem animated:false];
        
        _adjustmentsDisposable = [[SMetaDisposable alloc] init];
        _captionDisposable = [[SMetaDisposable alloc] init];
        _itemSelectedDisposable = [[SMetaDisposable alloc] init];
        _itemAvailabilityDisposable = [[SMetaDisposable alloc] init];
        
        _captionMixin = [[TGPhotoCaptionInputMixin alloc] initWithKeyCommandController:[_context keyCommandController]];
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
        
        _captionMixin.finishedWithCaption = ^(NSString *caption)
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
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
            
            CGFloat offset = 0.0f;
            if (keyboardHeight > 0)
                offset = -keyboardHeight / 2.0f;
            
            [UIView animateWithDuration:duration delay:0.0f options:animationCurve animations:^
            {
                if (strongSelf->_scrollViewOffsetRequested != nil)
                    strongSelf->_scrollViewOffsetRequested(offset);
            } completion:nil];
        };
        
        [_captionMixin createInputPanelIfNeeded];
        
        _portraitToolbarView = [[TGPhotoToolbarView alloc] initWithBackButton:TGPhotoEditorBackButtonBack doneButton:TGPhotoEditorDoneButtonSend solidBackground:false];
        _portraitToolbarView.cancelPressed = toolbarCancelPressed;
        _portraitToolbarView.donePressed = toolbarDonePressed;
        [_wrapperView addSubview:_portraitToolbarView];
        
        _landscapeToolbarView = [[TGPhotoToolbarView alloc] initWithBackButton:TGPhotoEditorBackButtonBack doneButton:TGPhotoEditorDoneButtonSend solidBackground:false];
        _landscapeToolbarView.cancelPressed = toolbarCancelPressed;
        _landscapeToolbarView.donePressed = toolbarDonePressed;
        [_wrapperView addSubview:_landscapeToolbarView];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];

    [_adjustmentsDisposable dispose];
    [_captionDisposable dispose];
    [_itemSelectedDisposable dispose];
    [_itemAvailabilityDisposable dispose];
}

- (void)setHasCaptions:(bool)hasCaptions
{
    _hasCaptions = hasCaptions;
    if (!hasCaptions)
        [_captionMixin destroy];
}

- (void)setSuggestionContext:(TGSuggestionContext *)suggestionContext
{
    _captionMixin.suggestionContext = suggestionContext;
}

- (void)setClosePressed:(void (^)())closePressed
{
    _closePressed = [closePressed copy];
}

- (void)setScrollViewOffsetRequested:(void (^)(CGFloat))scrollViewOffsetRequested
{
    _scrollViewOffsetRequested = [scrollViewOffsetRequested copy];
}

- (void)setEditorTabPressed:(void (^)(TGPhotoEditorTab tab))editorTabPressed
{
    __weak TGMediaPickerGalleryInterfaceView *weakSelf = self;
    void (^tabPressed)(TGPhotoEditorTab) = ^(TGPhotoEditorTab tab)
    {
        __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (tab == TGPhotoEditorTimerTab)
            [strongSelf openTimerSetup];
        else
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
    
    CGFloat screenSide = MAX(TGScreenSize().width, TGScreenSize().height);
    UIEdgeInsets screenEdges = UIEdgeInsetsMake((screenSide - self.frame.size.height) / 2, (screenSide - self.frame.size.width) / 2, (screenSide + self.frame.size.height) / 2, (screenSide + self.frame.size.width) / 2);
  
    __weak TGMediaPickerGalleryInterfaceView *weakSelf = self;
    
    if (_selectionContext != nil)
    {
        _checkButton.frame = [self _checkButtonFrameForOrientation:[self interfaceOrientation] screenEdges:screenEdges hasHeaderView:(itemView.headerView != nil)];
        
        if ([itemView.headerView isKindOfClass:[TGMediaPickerScrubberHeaderView class]])
        {
            TGMediaPickerScrubberHeaderView *headerView = (TGMediaPickerScrubberHeaderView *)itemView.headerView;
            [headerView.scrubberView setRecipientName:_recipientLabel.text];
        }
        
        [self _layoutRecipientLabelForOrientation:[self interfaceOrientation] screenEdges:screenEdges hasHeaderView:(itemView.headerView != nil)];
        
        SSignal *signal = nil;
        id<TGMediaSelectableItem>selectableItem = nil;
        if ([_currentItem conformsToProtocol:@protocol(TGModernGallerySelectableItem)])
            selectableItem = ((id<TGModernGallerySelectableItem>)_currentItem).selectableMediaItem;
        
        [_checkButton setSelected:[_selectionContext isItemSelected:selectableItem] animated:false];
        signal = [_selectionContext itemInformativeSelectedSignal:selectableItem];
        [_itemSelectedDisposable setDisposable:[signal startWithNext:^(TGMediaSelectionChange *next)
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (next.sender != strongSelf->_checkButton)
                [strongSelf->_checkButton setSelected:next.selected animated:next.animated];
        }]];
    }
    
    [self updateEditorButtonsForItem:item animated:true];
    
    __weak TGModernGalleryItemView *weakItemView = itemView;
    [_itemAvailabilityDisposable setDisposable:[[[itemView contentAvailabilityStateSignal] deliverOn:[SQueue mainQueue]] startWithNext:^(id next)
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
            
            strongSelf->_muteButton.hidden = ![strongItemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]];
        }
    }]];
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
    
    [_checkButton setSelected:!_checkButton.selected animated:true];
    
    if (selectableItem != nil)
        [_selectionContext setItem:selectableItem selected:_checkButton.selected animated:animated sender:_checkButton];
}

- (void)photoCounterButtonPressed
{
    [_photoCounterButton setSelected:!_photoCounterButton.selected animated:true];
    [_selectedPhotosView setHidden:!_photoCounterButton.selected animated:true];
}

- (void)updateEditorButtonsForItem:(id<TGModernGalleryItem>)item animated:(bool)animated
{
    if (_editingContext == nil || _editingContext.inhibitEditing)
    {
        [_portraitToolbarView setEditButtonsHidden:true animated:false];
        [_landscapeToolbarView setEditButtonsHidden:true animated:false];
        return;
    }
    
    TGPhotoEditorTab tabs = TGPhotoEditorNoneTab;
    if ([item conformsToProtocol:@protocol(TGModernGalleryEditableItem)])
        tabs = [(id<TGModernGalleryEditableItem>)item toolbarTabs];
        
    if (iosMajorVersion() < 7)
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
    
    id<TGModernGalleryEditableItem> galleryEditableItem = (id<TGModernGalleryEditableItem>)item;
    if ([item conformsToProtocol:@protocol(TGModernGalleryEditableItem)])
    {
        id<TGMediaEditableItem> editableMediaItem = [galleryEditableItem editableMediaItem];
        
        __weak TGMediaPickerGalleryInterfaceView *weakSelf = self;
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
        }] deliverOn:[SQueue mainQueue]] startWithNext:^(NSDictionary *dict)
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            id<TGMediaEditAdjustments> adjustments = dict[@"adjustments"];
            NSNumber *timer = dict[@"timer"];
            
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
        }]];
        
        [_captionDisposable setDisposable:[[galleryEditableItem.editingContext captionSignalForItem:editableMediaItem] startWithNext:^(NSString *caption)
        {
            __strong TGMediaPickerGalleryInterfaceView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf->_captionMixin setCaption:caption animated:animated];
        }]];
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
    TGPhotoEditorTab disabledButtons = TGPhotoEditorNoneTab;
    
    if ([adjustments isKindOfClass:[TGMediaVideoEditAdjustments class]])
    {
        TGMediaVideoEditAdjustments *videoAdjustments = (TGMediaVideoEditAdjustments *)adjustments;
        _muteButton.selected = videoAdjustments.sendAsGif;
    }
    
    TGPhotoEditorButton *qualityButton = [_portraitToolbarView buttonForTab:TGPhotoEditorQualityTab];
    if (qualityButton != nil)
    {
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
    
    TGPhotoEditorButton *timerButton = [_portraitToolbarView buttonForTab:TGPhotoEditorTimerTab];
    if (timerButton != nil)
    {
        NSInteger value = [timer integerValue];
        
        UIImage *defaultIcon = [TGPhotoEditorInterfaceAssets timerIconForValue:0];
        UIImage *icon = [TGPhotoEditorInterfaceAssets timerIconForValue:value];
        [timerButton setIconImage:defaultIcon activeIconImage:icon];
        
        TGPhotoEditorButton *landscapeTimerButton = [_landscapeToolbarView buttonForTab:TGPhotoEditorTimerTab];
        
        if ([self shouldDisplayTooltip])
        {
            TGDispatchAfter(0.5, dispatch_get_main_queue(), ^
            {
                if (self.frame.size.width > self.frame.size.height)
                    [self setupTooltip:[_landscapeToolbarView convertRect:landscapeTimerButton.frame toView:self]];
                else
                    [self setupTooltip:[_portraitToolbarView convertRect:timerButton.frame toView:self]];
            });
        }
        
        timerButton = landscapeTimerButton;
        [timerButton setIconImage:defaultIcon activeIconImage:icon];
        
        if (value > 0)
            highlightedButtons |= TGPhotoEditorTimerTab;
    }
    
    [_portraitToolbarView setEditButtonsHighlighted:highlightedButtons];
    [_landscapeToolbarView setEditButtonsHighlighted:highlightedButtons];
    
    [_portraitToolbarView setEditButtonsDisabled:disabledButtons];
    [_landscapeToolbarView setEditButtonsDisabled:disabledButtons];
}

- (bool)shouldDisplayTooltip
{
    return ![[[NSUserDefaults standardUserDefaults] objectForKey:@"TG_displayedMediaTimerTooltip_v0"] boolValue];
}

- (void)setupTooltip:(CGRect)rect
{
    if (_tooltipContainerView != nil)
        return;
    
    _tooltipTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(tooltipTimerTick) interval:2.5 repeat:false];
    
    _tooltipContainerView = [[TGMenuContainerView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height)];
    [self addSubview:_tooltipContainerView];
    
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    [actions addObject:[[NSDictionary alloc] initWithObjectsAndKeys:TGLocalized(@"MediaPicker.TimerTooltip"), @"title", nil]];
    
    [_tooltipContainerView.menuView setButtonsAndActions:actions watcherHandle:_actionHandle];
    [_tooltipContainerView.menuView sizeToFit];
    _tooltipContainerView.menuView.buttonHighlightDisabled = true;
    
    [_tooltipContainerView showMenuFromRect:rect animated:false];
    
    [[NSUserDefaults standardUserDefaults] setObject:@true forKey:@"TG_displayedMediaTimerTooltip_v0"];
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

- (void)updateSelectionInterface:(NSUInteger)selectedCount counterVisible:(bool)counterVisible animated:(bool)animated
{
    if (counterVisible)
    {
        bool animateCount = animated && !(counterVisible && _photoCounterButton.internalHidden);
        [_photoCounterButton setSelectedCount:selectedCount animated:animateCount];
        [_photoCounterButton setInternalHidden:false animated:animated completion:nil];
    }
    else
    {
        __weak TGMediaPickerPhotoCounterButton *weakButton = _photoCounterButton;
        [_photoCounterButton setInternalHidden:true animated:animated completion:^
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
            _arrowView.alpha = alpha * 0.45f;
            _recipientLabel.alpha = alpha;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                _checkButton.userInteractionEnabled = !hidden;
                _muteButton.userInteractionEnabled = !hidden;
            }
        }];
    }
    else
    {
        _checkButton.alpha = alpha;
        _checkButton.userInteractionEnabled = !hidden;
        
        _muteButton.alpha = alpha;
        _muteButton.userInteractionEnabled = !hidden;
        
        _arrowView.alpha = alpha * 0.45f;
        _recipientLabel.alpha = alpha;
    }
    
    if (hidden)
    {
        [_photoCounterButton setSelected:false animated:animated];
        [_selectedPhotosView setHidden:true animated:animated];
    }
    
    [_photoCounterButton setHidden:hidden delay:delay animated:animated];
}

- (void)setAllInterfaceHidden:(bool)hidden delay:(NSTimeInterval)__unused delay animated:(bool)animated
{
    CGFloat alpha = (hidden ? 0.0f : 1.0f);
    if (animated)
    {
        [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _checkButton.alpha = alpha;
            _muteButton.alpha = alpha;
            _arrowView.alpha = alpha * 0.45f;
            _recipientLabel.alpha = alpha;
            _portraitToolbarView.alpha = alpha;
            _landscapeToolbarView.alpha = alpha;
            _captionMixin.inputPanel.alpha = alpha;
        } completion:^(BOOL finished)
        {
            if (finished)
            {
                _checkButton.userInteractionEnabled = !hidden;
                _muteButton.userInteractionEnabled = !hidden;
                _portraitToolbarView.userInteractionEnabled = !hidden;
                _landscapeToolbarView.userInteractionEnabled = !hidden;
                _captionMixin.inputPanel.userInteractionEnabled = !hidden;
            }
        }];
    }
    else
    {
        _checkButton.alpha = alpha;
        _checkButton.userInteractionEnabled = !hidden;
        
        _muteButton.alpha = alpha;
        _muteButton.userInteractionEnabled = !hidden;
        
        _arrowView.alpha = alpha * 0.45f;
        _recipientLabel.alpha = alpha;
        
        _portraitToolbarView.alpha = alpha;
        _portraitToolbarView.userInteractionEnabled = !hidden;
        
        _landscapeToolbarView.alpha = alpha;
        _landscapeToolbarView.userInteractionEnabled = !hidden;
        
        _captionMixin.inputPanel.alpha = alpha;
        _captionMixin.inputPanel.userInteractionEnabled = !hidden;
    }
    
    if (hidden)
    {
        [_photoCounterButton setSelected:false animated:animated];
        [_selectedPhotosView setHidden:true animated:animated];
    }
    
    [_photoCounterButton setHidden:hidden delay:delay animated:animated];
    
    [self setItemHeaderViewHidden:hidden animated:animated];
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
    if ([currentItemView isKindOfClass:[TGMediaPickerGalleryVideoItemView class]])
        [(TGMediaPickerGalleryVideoItemView *)currentItemView toggleSendAsGif];
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

- (void)animateTransitionOutWithDuration:(NSTimeInterval)__unused dutation
{
    
}

- (void)setTransitionOutProgress:(CGFloat)transitionOutProgress
{
    [self setAllInterfaceHidden:(transitionOutProgress > FLT_EPSILON) delay:0.0 animated:true];
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

- (void)editorTransitionIn
{
    [self setSelectionInterfaceHidden:true animated:true];
    
    [UIView animateWithDuration:0.2 animations:^
    {
        _captionMixin.inputPanel.alpha = 0.0f;
        _portraitToolbarView.doneButton.alpha = 0.0f;
        _landscapeToolbarView.doneButton.alpha = 0.0f;
    }];
}

- (void)editorTransitionOut
{
    [self setSelectionInterfaceHidden:false animated:true];
    
    [UIView animateWithDuration:0.3 animations:^
    {
        _captionMixin.inputPanel.alpha = 1.0f;
        _portraitToolbarView.doneButton.alpha = 1.0f;
        _landscapeToolbarView.doneButton.alpha = 1.0f;
    }];
}

#pragma mark -

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *view = [super hitTest:point withEvent:event];
    
    if (view == _photoCounterButton
        || view == _checkButton
        || view == _muteButton
        || [view isDescendantOfView:_headerWrapperView]
        || [view isDescendantOfView:_portraitToolbarView]
        || [view isDescendantOfView:_landscapeToolbarView]
        || [view isDescendantOfView:_selectedPhotosView]
        || [view isDescendantOfView:_captionMixin.inputPanel]
        || [view isDescendantOfView:_captionMixin.dismissView]
        || [view isKindOfClass:[TGMenuButtonView class]])
        
    {
        return view;
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
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
            frame = CGRectMake(screenEdges.right - 47, screenEdges.bottom - 54 - 59, _muteButton.frame.size.width, _muteButton.frame.size.height);
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            frame = CGRectMake(screenEdges.left + 5, screenEdges.bottom - 54 - 59, _muteButton.frame.size.width, _muteButton.frame.size.height);
            break;
            
        default:
            frame = CGRectMake(screenEdges.left + 5, screenEdges.top + 5, _muteButton.frame.size.width, _muteButton.frame.size.height);
            break;
    }
    
    if (hasHeaderView)
        frame.origin.y += 64;
    
    return frame;
}

- (CGRect)_checkButtonFrameForOrientation:(UIInterfaceOrientation)orientation screenEdges:(UIEdgeInsets)screenEdges hasHeaderView:(bool)hasHeaderView
{
    CGRect frame = CGRectZero;
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
    
    if (hasHeaderView)
        frame.origin.y += 64;
    
    return frame;
}

- (void)_layoutRecipientLabelForOrientation:(UIInterfaceOrientation)orientation screenEdges:(UIEdgeInsets)screenEdges hasHeaderView:(bool)hasHeaderView
{
    CGFloat screenWidth = MIN(self.frame.size.width, self.frame.size.height);
    CGFloat recipientWidth = MIN(_recipientLabel.frame.size.width, screenWidth - 100.0f);
    
    CGRect frame = CGRectZero;
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
    
    _arrowView.hidden = hasHeaderView;
    _recipientLabel.hidden = hasHeaderView;
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
    _portraitToolbarView.frame = CGRectMake(screenEdges.left, portraitToolbarViewBottomEdge - TGPhotoEditorToolbarSize, self.frame.size.width, TGPhotoEditorToolbarSize);
    
    UIEdgeInsets captionEdgeInsets = screenEdges;
    captionEdgeInsets.bottom = _portraitToolbarView.frame.size.height;
    [_captionMixin updateLayoutWithFrame:self.bounds edgeInsets:captionEdgeInsets];
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            [UIView performWithoutAnimation:^
            {
                _photoCounterButton.frame = CGRectMake(screenEdges.left + TGPhotoEditorToolbarSize + 1, screenEdges.top + 6 + headerInset, 64, 38);
                
                _selectedPhotosView.frame = CGRectMake(screenEdges.left + TGPhotoEditorToolbarSize + 66, screenEdges.top + 4 + headerInset, photosViewSize, self.frame.size.height - 4 * 2 - headerInset);
                
                _landscapeToolbarView.frame = CGRectMake(screenEdges.left, screenEdges.top, TGPhotoEditorToolbarSize, self.frame.size.height);
            }];
            
            _headerWrapperView.frame = CGRectMake(TGPhotoEditorToolbarSize + screenEdges.left, screenEdges.top, self.frame.size.width - TGPhotoEditorToolbarSize, 64);
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            [UIView performWithoutAnimation:^
            {
                _photoCounterButton.frame = CGRectMake(screenEdges.right - TGPhotoEditorToolbarSize - 64 - 1, screenEdges.top + 6 + headerInset, 64, 38);
                
                _selectedPhotosView.frame = CGRectMake(screenEdges.right - TGPhotoEditorToolbarSize - photosViewSize - 66, screenEdges.top + 4 + headerInset, photosViewSize, self.frame.size.height - 4 * 2 - headerInset);
                
                _landscapeToolbarView.frame = CGRectMake(screenEdges.right - TGPhotoEditorToolbarSize, screenEdges.top, TGPhotoEditorToolbarSize, self.frame.size.height);
            }];
            
            _headerWrapperView.frame = CGRectMake(screenEdges.left, screenEdges.top, self.frame.size.width - TGPhotoEditorToolbarSize, 64);
        }
            break;
            
        default:
        {
            [UIView performWithoutAnimation:^
            {
                _photoCounterButton.frame = CGRectMake(screenEdges.right - 56, screenEdges.bottom - TGPhotoEditorToolbarSize - [_captionMixin.inputPanel baseHeight] - 40, 64, 38);
                
                _selectedPhotosView.frame = CGRectMake(screenEdges.left + 4, screenEdges.bottom - TGPhotoEditorToolbarSize - [_captionMixin.inputPanel baseHeight] - photosViewSize - 54, self.frame.size.width - 4 * 2, photosViewSize);
            }];
            
            _landscapeToolbarView.frame = CGRectMake(_landscapeToolbarView.frame.origin.x, screenEdges.top, TGPhotoEditorToolbarSize, self.frame.size.height);
            
            _headerWrapperView.frame = CGRectMake(screenEdges.left, screenEdges.top, self.frame.size.width, 64);
        }
            break;
    }
    
    _muteButton.frame = [self _muteButtonFrameForOrientation:orientation screenEdges:screenEdges hasHeaderView:true];
    _checkButton.frame = [self _checkButtonFrameForOrientation:orientation screenEdges:screenEdges hasHeaderView:hasHeaderView];
    [self _layoutRecipientLabelForOrientation:orientation screenEdges:screenEdges hasHeaderView:hasHeaderView];
    
    for (UIView *itemHeaderView in _itemHeaderViews)
        itemHeaderView.frame = _headerWrapperView.bounds;
    
    CGRect itemFooterViewFrame = [self itemFooterViewFrameForSize:self.frame.size];
    for (UIView *itemFooterView in _itemFooterViews)
        itemFooterView.frame = itemFooterViewFrame;
}

@end
