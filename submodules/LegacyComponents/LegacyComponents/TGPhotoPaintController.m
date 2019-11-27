#import "TGPhotoPaintController.h"

#import "LegacyComponentsInternal.h"

#import <LegacyComponents/UIImage+TG.h>

#import <LegacyComponents/TGPaintUtils.h>
#import <LegacyComponents/TGPhotoEditorUtils.h>
#import <LegacyComponents/TGPhotoEditorAnimation.h>
#import "TGPhotoEditorInterfaceAssets.h"
#import <LegacyComponents/TGObserverProxy.h>

#import <LegacyComponents/TGMenuView.h>
#import <LegacyComponents/TGModernButton.h>
#import <LegacyComponents/TGModernGalleryVideoView.h>

#import "TGMenuSheetController.h"

#import <LegacyComponents/TGMediaAsset.h>
#import <LegacyComponents/TGMediaAssetImageSignals.h>

#import "TGPainting.h"
#import <LegacyComponents/TGPaintingData.h>
#import "TGPaintRadialBrush.h"
#import "TGPaintEllipticalBrush.h"
#import "TGPaintNeonBrush.h"
#import "TGPaintCanvas.h"
#import "TGPaintingWrapperView.h"
#import "TGPaintState.h"
#import "TGPaintBrushPreview.h"
#import <LegacyComponents/TGPaintUndoManager.h>

#import "PGPhotoEditor.h"
#import "TGPhotoEditorPreviewView.h"

#import "TGPhotoPaintActionsView.h"
#import "TGPhotoPaintSettingsView.h"

#import "TGPhotoStickersView.h"

#import "TGPhotoPaintSettingsWrapperView.h"
#import "TGPhotoBrushSettingsView.h"
#import "TGPhotoTextSettingsView.h"

#import "TGPhotoPaintSelectionContainerView.h"
#import "TGPhotoEntitiesContainerView.h"
#import "TGPhotoStickerEntityView.h"
#import "TGPhotoTextEntityView.h"

#import "TGPaintFaceDetector.h"
#import "TGPhotoMaskPosition.h"

const CGFloat TGPhotoPaintTopPanelSize = 44.0f;
const CGFloat TGPhotoPaintBottomPanelSize = 79.0f;
const CGSize TGPhotoPaintingLightMaxSize = { 1280.0f, 1280.0f };
const CGSize TGPhotoPaintingMaxSize = { 1600.0f, 1600.0f };

const CGFloat TGPhotoPaintStickerKeyboardSize = 260.0f;

@interface TGPhotoPaintController () <UIScrollViewDelegate, UIGestureRecognizerDelegate, ASWatcher>
{
    TGPaintUndoManager *_undoManager;
    TGObserverProxy *_keyboardWillChangeFrameProxy;
    CGFloat _keyboardHeight;
    
    UIButton *_containerView;
    TGPhotoPaintSparseView *_wrapperView;
    UIView *_portraitToolsWrapperView;
    UIView *_landscapeToolsWrapperView;
    
    UIPinchGestureRecognizer *_pinchGestureRecognizer;
    UIRotationGestureRecognizer *_rotationGestureRecognizer;
    
    NSArray *_brushes;
    TGPainting *_painting;
    TGPaintCanvas *_canvasView;
    TGPaintBrushPreview *_brushPreview;
    
    UIView *_scrollView;
    UIView *_contentWrapperView;
    
    UIView *_dimView;
    
    TGPhotoPaintActionsView *_landscapeActionsView;
    TGPhotoPaintActionsView *_portraitActionsView;
    
    TGPhotoPaintSettingsView *_portraitSettingsView;
    TGPhotoPaintSettingsView *_landscapeSettingsView;
    
    TGPhotoPaintSettingsWrapperView *_settingsViewWrapper;
    UIView<TGPhotoPaintPanelView> *_settingsView;
    TGPhotoStickersView *_stickersView;
    
    bool _appeared;
    
    TGPhotoPaintFont *_selectedTextFont;
    bool _selectedStroke;
    
    TGPhotoEntitiesContainerView *_entitiesContainerView;
    TGPhotoPaintEntityView *_currentEntityView;
    
    TGPhotoPaintSelectionContainerView *_selectionContainerView;
    TGPhotoPaintEntitySelectionView *_entitySelectionView;
    
    TGPhotoTextEntityView *_editedTextView;
    CGPoint _editedTextCenter;
    CGAffineTransform _editedTextTransform;
    UIButton *_textEditingDismissButton;
    
    TGMenuContainerView *_menuContainerView;
    
    TGPaintingData *_resultData;
    
    AVPlayer *_player;
    SMetaDisposable *_playerItemDisposable;
    id _playerStartedObserver;
    id _playerReachedEndObserver;
    
    TGPaintingWrapperView *_paintingWrapperView;
    TGModernGalleryVideoView *_videoView;
    
    SMetaDisposable *_faceDetectorDisposable;
    NSArray *_faces;
    
    bool _enableStickers;
    
    id<LegacyComponentsContext> _context;
}

@property (nonatomic, strong) ASHandle *actionHandle;

@property (nonatomic, weak) PGPhotoEditor *photoEditor;
@property (nonatomic, weak) TGPhotoEditorPreviewView *previewView;

@end

@implementation TGPhotoPaintController

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView
{
    self = [super initWithContext:context];
    if (self != nil)
    {
        _context = context;
        _enableStickers = photoEditor.enableStickers;
        
        _actionHandle = [[ASHandle alloc] initWithDelegate:self releaseOnMainThread:true];
        
        self.photoEditor = photoEditor;
        self.previewView = previewView;
        
        _brushes = @
        [
            [[TGPaintRadialBrush alloc] init],
            [[TGPaintEllipticalBrush alloc] init],
            [[TGPaintNeonBrush alloc] init]
        ];
        _selectedTextFont = [[TGPhotoPaintFont availableFonts] firstObject];
        _selectedStroke = true;
        
        if (_photoEditor.paintingData.undoManager != nil)
            _undoManager = [_photoEditor.paintingData.undoManager copy];
        else
            _undoManager = [[TGPaintUndoManager alloc] init];
        
        CGSize size = TGScaleToSize(photoEditor.originalSize, [self maximumPaintingSize]);
        _painting = [[TGPainting alloc] initWithSize:size undoManager:_undoManager imageData:[_photoEditor.paintingData data]];
        _undoManager.painting = _painting;
        
        _keyboardWillChangeFrameProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification];
    }
    return self;
}

- (void)dealloc
{
    [_actionHandle reset];
    [_faceDetectorDisposable dispose];
    [_playerItemDisposable dispose];
}

- (void)loadView
{
    [super loadView];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    _containerView = [[UIButton alloc] initWithFrame:self.view.bounds];
    _containerView.clipsToBounds = true;
    [_containerView addTarget:self action:@selector(containerPressed) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_containerView];
    
    _pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinch:)];
    _pinchGestureRecognizer.delegate = self;
    [_containerView addGestureRecognizer:_pinchGestureRecognizer];
    
    _rotationGestureRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotate:)];
    _rotationGestureRecognizer.delegate = self;
    [_containerView addGestureRecognizer:_rotationGestureRecognizer];
    
    TGPhotoEditorPreviewView *previewView = _previewView;
    previewView.userInteractionEnabled = false;
    previewView.hidden = true;
    [_containerView addSubview:_previewView];
    
    __weak TGPhotoPaintController *weakSelf = self;
    _paintingWrapperView = [[TGPaintingWrapperView alloc] init];
    _paintingWrapperView.clipsToBounds = true;
    _paintingWrapperView.shouldReceiveTouch = ^bool
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        return (strongSelf->_editedTextView == nil);
    };
    [_containerView addSubview:_paintingWrapperView];
    
    _scrollView = [[UIView alloc] init];
    _scrollView.clipsToBounds = true;
    _scrollView.userInteractionEnabled = false;
    [_containerView addSubview:_scrollView];
    
    _contentWrapperView = [[UIView alloc] init];
    _contentWrapperView.userInteractionEnabled = false;
    [_scrollView addSubview:_contentWrapperView];
    
    _entitiesContainerView = [[TGPhotoEntitiesContainerView alloc] init];
    _entitiesContainerView.clipsToBounds = true;
    _entitiesContainerView.entitySelected = ^(TGPhotoPaintEntityView *sender)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf selectEntityView:sender];
    };
    _entitiesContainerView.entityRemoved = ^(TGPhotoPaintEntityView *entity)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (entity == strongSelf->_currentEntityView)
            [strongSelf _clearCurrentSelection];
        
        [strongSelf updateSettingsButton];
    };
    [_contentWrapperView addSubview:_entitiesContainerView];
    _undoManager.entitiesContainer = _entitiesContainerView;
    
    _dimView = [[UIView alloc] init];
    _dimView.alpha = 0.0f;
    _dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _dimView.backgroundColor = UIColorRGBA(0x000000, 0.4f);
    _dimView.userInteractionEnabled = false;
    [_entitiesContainerView addSubview:_dimView];
    
    _selectionContainerView = [[TGPhotoPaintSelectionContainerView alloc] init];
    _selectionContainerView.clipsToBounds = false;
    [_containerView addSubview:_selectionContainerView];
    
    _wrapperView = [[TGPhotoPaintSparseView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_wrapperView];
    
    _portraitToolsWrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    _portraitToolsWrapperView.alpha = 0.0f;
    [_wrapperView addSubview:_portraitToolsWrapperView];
    
    _landscapeToolsWrapperView = [[UIView alloc] initWithFrame:CGRectZero];
    _landscapeToolsWrapperView.alpha = 0.0f;
    [_wrapperView addSubview:_landscapeToolsWrapperView];
    
    void (^undoPressed)(void) = ^
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf->_undoManager undo];
    };
    
    void (^clearPressed)(UIView *) = ^(UIView *sender)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf presentClearAllAlert:sender];
    };
    
    _portraitActionsView = [[TGPhotoPaintActionsView alloc] init];
    _portraitActionsView.alpha = 0.0f;
    _portraitActionsView.undoPressed = undoPressed;
    _portraitActionsView.clearPressed = clearPressed;
    [_wrapperView addSubview:_portraitActionsView];
    
    _landscapeActionsView = [[TGPhotoPaintActionsView alloc] init];
    _landscapeActionsView.alpha = 0.0f;
    _landscapeActionsView.undoPressed = undoPressed;
    _landscapeActionsView.clearPressed = clearPressed;
    [_wrapperView addSubview:_landscapeActionsView];
    
    void (^settingsPressed)(void) = ^
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if ([strongSelf->_currentEntityView isKindOfClass:[TGPhotoTextEntityView class]])
            [strongSelf presentTextSettingsView];
        else if ([strongSelf->_currentEntityView isKindOfClass:[TGPhotoStickerEntityView class]])
            [strongSelf mirrorSelectedStickerEntity];
        else
            [strongSelf presentBrushSettingsView];
    };
    
    void (^beganColorPicking)(void) = ^
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
    
        if (![strongSelf->_currentEntityView isKindOfClass:[TGPhotoTextEntityView class]])
            [strongSelf setDimHidden:false animated:true];
    };
    
    void (^changedColor)(TGPhotoPaintSettingsView *, TGPaintSwatch *) = ^(TGPhotoPaintSettingsView *sender, TGPaintSwatch *swatch)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf setCurrentSwatch:swatch sender:sender];
    };
    
    void (^finishedColorPicking)(TGPhotoPaintSettingsView *, TGPaintSwatch *) = ^(TGPhotoPaintSettingsView *sender, TGPaintSwatch *swatch)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf setCurrentSwatch:swatch sender:sender];
        
        if (![strongSelf->_currentEntityView isKindOfClass:[TGPhotoTextEntityView class]])
            [strongSelf setDimHidden:true animated:true];
    };

    _portraitSettingsView = [[TGPhotoPaintSettingsView alloc] initWithContext:_context];
    _portraitSettingsView.beganColorPicking = beganColorPicking;
    _portraitSettingsView.changedColor = changedColor;
    _portraitSettingsView.finishedColorPicking = finishedColorPicking;
    _portraitSettingsView.settingsPressed = settingsPressed;
    _portraitSettingsView.layer.rasterizationScale = TGScreenScaling();
    _portraitSettingsView.interfaceOrientation = UIInterfaceOrientationPortrait;
    [_portraitToolsWrapperView addSubview:_portraitSettingsView];
    
    _landscapeSettingsView = [[TGPhotoPaintSettingsView alloc] initWithContext:_context];
    _landscapeSettingsView.beganColorPicking = beganColorPicking;
    _landscapeSettingsView.changedColor = changedColor;
    _landscapeSettingsView.finishedColorPicking = finishedColorPicking;
    _landscapeSettingsView.settingsPressed = settingsPressed;
    _landscapeSettingsView.layer.rasterizationScale = TGScreenScaling();
    _landscapeSettingsView.interfaceOrientation = UIInterfaceOrientationLandscapeLeft;
    [_landscapeToolsWrapperView addSubview:_landscapeSettingsView];
    
    [self setCurrentSwatch:_portraitSettingsView.swatch sender:nil];
    
    if (![self _updateControllerInset:false])
        [self controllerInsetUpdated:UIEdgeInsetsZero];
}

- (void)setupCanvas
{
    __weak TGPhotoPaintController *weakSelf = self;
    _canvasView = [[TGPaintCanvas alloc] initWithFrame:CGRectZero];
    _canvasView.pointInsideContainer = ^bool(CGPoint point)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        return [strongSelf->_containerView pointInside:[strongSelf->_canvasView convertPoint:point toView:strongSelf->_containerView] withEvent:nil];
    };
    _canvasView.shouldDraw = ^bool
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        return ![strongSelf->_entitiesContainerView isTrackingAnyEntityView];
    };
    _canvasView.shouldDrawOnSingleTap = ^bool
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        bool rotating = (strongSelf->_rotationGestureRecognizer.state == UIGestureRecognizerStateBegan || strongSelf->_rotationGestureRecognizer.state == UIGestureRecognizerStateChanged);
        bool pinching = (strongSelf->_pinchGestureRecognizer.state == UIGestureRecognizerStateBegan || strongSelf->_pinchGestureRecognizer.state == UIGestureRecognizerStateChanged);
        
        if (strongSelf->_currentEntityView != nil && !rotating && !pinching)
        {
            [strongSelf selectEntityView:nil];
            return false;
        }
        
        return true;
    };
    _canvasView.strokeBegan = ^
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf selectEntityView:nil];
    };
    _canvasView.strokeCommited = ^
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf updateActionsView];
    };
    _canvasView.hitTest = ^UIView *(CGPoint point, UIEvent *event)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return nil;
        
        return [strongSelf->_entitiesContainerView hitTest:[strongSelf->_canvasView convertPoint:point toView:strongSelf->_entitiesContainerView] withEvent:event];
    };
    _canvasView.cropRect = _photoEditor.cropRect;
    _canvasView.cropOrientation = _photoEditor.cropOrientation;
    _canvasView.originalSize = _photoEditor.originalSize;
    [_canvasView setPainting:_painting];
    [_canvasView setBrush:_brushes.firstObject];
    [self setCurrentSwatch:_portraitSettingsView.swatch sender:nil];
    [_paintingWrapperView addSubview:_canvasView];
    
    _canvasView.hidden = false;
    [self.view setNeedsLayout];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    PGPhotoEditor *photoEditor = _photoEditor;
    [self setupWithPaintingData:photoEditor.paintingData];
    
    __weak TGPhotoPaintController *weakSelf = self;
    _undoManager.historyChanged = ^
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf updateActionsView];
    };
    
    [self updateActionsView];
    
    [self performFaceDetection];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self transitionIn];
}

#pragma mark - Tab Bar

- (TGPhotoEditorTab)availableTabs
{
    TGPhotoEditorTab result = TGPhotoEditorPaintTab | TGPhotoEditorEraserTab | TGPhotoEditorTextTab;
    if (_enableStickers) {
        result |= TGPhotoEditorStickerTab;
    }
    return result;
}

- (void)handleTabAction:(TGPhotoEditorTab)tab
{
    switch (tab)
    {
        case TGPhotoEditorStickerTab:
        {
            [self presentStickersView];
        }
            break;
            
        case TGPhotoEditorTextTab:
        {
            [self createNewTextLabel];
        }
            break;
            
        case TGPhotoEditorPaintTab:
        {
            [self selectEntityView:nil];
            
            if (_canvasView.state.eraser)
                [self toggleEraserMode];
        }
            break;
            
        case TGPhotoEditorEraserTab:
        {
            [self selectEntityView:nil];
            [self toggleEraserMode];
        }
            break;
            
        default:
            break;
    }
}

- (TGPhotoEditorTab)activeTab
{
    TGPhotoEditorTab tabs = TGPhotoEditorNoneTab;
    
    if (_currentEntityView != nil)
        return tabs;
    
    if (_canvasView.state.eraser)
        tabs |= TGPhotoEditorEraserTab;
    else
        tabs |= TGPhotoEditorPaintTab;
    
    return tabs;
}

#pragma mark - Undo & Redo

- (void)updateActionsView
{
    if (_portraitActionsView == nil || _landscapeActionsView == nil)
        return;
    
    NSArray *views = @[ _portraitActionsView, _landscapeActionsView ];
    for (TGPhotoPaintActionsView *view in views)
    {
        [view setUndoEnabled:_undoManager.canUndo];
        [view setClearEnabled:_undoManager.canUndo];
    }
}

- (void)presentClearAllAlert:(UIView *)sender
{
    TGMenuSheetController *controller = [[TGMenuSheetController alloc] initWithContext:_context dark:false];
    controller.dismissesByOutsideTap = true;
    controller.narrowInLandscape = true;
    controller.permittedArrowDirections = UIPopoverArrowDirectionUp;
    __weak TGMenuSheetController *weakController = controller;
    
    __weak TGPhotoPaintController *weakSelf = self;
    NSArray *items = @
    [
     [[TGMenuSheetButtonItemView alloc] initWithTitle:TGLocalized(@"Paint.ClearConfirm") type:TGMenuSheetButtonTypeDestructive fontSize:20.0 action:^
        {
            __strong TGMenuSheetController *strongController = weakController;
            if (strongController == nil)
                return;
            
            __strong TGPhotoPaintController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            [strongSelf->_painting clear];
            [strongSelf->_undoManager reset];
            
            [strongSelf->_entitiesContainerView removeAll];
            [strongSelf _clearCurrentSelection];
            
            [strongSelf updateSettingsButton];
            
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
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return CGRectZero;
        return [sender convertRect:sender.bounds toView:strongSelf.view];
    };
    [controller presentInViewController:self.parentViewController sourceView:self.view animated:true];
}

- (void)_clearCurrentSelection
{
    _currentEntityView = nil;
    if (_entitySelectionView != nil)
    {
        [_entitySelectionView removeFromSuperview];
        _entitySelectionView = nil;
    }
}

#pragma mark - Data Handling

- (void)setupWithPaintingData:(TGPaintingData *)paintingData
{
    if (paintingData == nil)
        return;
    
    for (TGPhotoPaintEntity *entity in paintingData.entities)
    {
        [self _createEntityViewWithEntity:entity];
    }
}

- (TGPaintingData *)_prepareResultData
{
    if (_resultData != nil)
        return _resultData;
    
    NSData *data = nil;
    CGSize fittedSize = TGFitSize(_painting.size, TGPhotoEditorResultImageMaxSize);
    UIImage *image = _painting.isEmpty ? nil : [_painting imageWithSize:fittedSize andData:&data];
    NSMutableArray *entities = [[NSMutableArray alloc] init];
    
    if (image == nil && _entitiesContainerView.entitiesCount < 1)
    {
        _resultData = nil;
        return _resultData;
    }
    else if (_entitiesContainerView.entitiesCount > 0)
    {
        image = [_entitiesContainerView imageInRect:_entitiesContainerView.bounds background:image];
        
        for (TGPhotoPaintEntityView *view in _entitiesContainerView.subviews)
        {
            if (![view isKindOfClass:[TGPhotoPaintEntityView class]])
                continue;
            
            TGPhotoPaintEntity *entity = [view entity];
            if (entity != nil)
                [entities addObject:entity];
        }
    }
    
    _resultData = [TGPaintingData dataWithPaintingData:data image:image entities:entities undoManager:_undoManager];
    return _resultData;
}

- (UIImage *)image
{
    TGPaintingData *paintingData = [self _prepareResultData];
    return paintingData.image;
}

- (TGPaintingData *)paintingData
{
    return [self _prepareResultData];
}

#pragma mark - Entities

- (void)selectEntityView:(TGPhotoPaintEntityView *)view
{
    if (_editedTextView != nil)
        return;
    
    if (_currentEntityView != nil)
    {
        if (_currentEntityView == view)
        {
            [self showMenuForEntityView];
            return;
        }
        
        [self _clearCurrentSelection];
    }
    
    _currentEntityView = view;
    [self updateSettingsButton];
    
    if (view != nil)
    {
        [_currentEntityView.superview bringSubviewToFront:_currentEntityView];
    }
    else
    {
        [self hideMenu];
        return;
    }
    
    if ([view isKindOfClass:[TGPhotoTextEntityView class]])
    {
        TGPaintSwatch *textSwatch = ((TGPhotoPaintTextEntity *)view.entity).swatch;
        [self setCurrentSwatch:[TGPaintSwatch swatchWithColor:textSwatch.color colorLocation:textSwatch.colorLocaton brushWeight:_portraitSettingsView.swatch.brushWeight] sender:nil];
    }
    
    _entitySelectionView = [view createSelectionView];
    view.selectionView = _entitySelectionView;
    [_selectionContainerView addSubview:_entitySelectionView];
    
    __weak TGPhotoPaintController *weakSelf = self;
    _entitySelectionView.entityResized = ^(CGFloat scale)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_entitySelectionView.entityView scale:scale absolute:true];
    };
    _entitySelectionView.entityRotated = ^(CGFloat angle)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf->_entitySelectionView.entityView rotate:angle absolute:true];
    };
    
    [_entitySelectionView update];
}

- (void)deleteEntityView:(TGPhotoPaintEntityView *)view
{
    [_undoManager unregisterUndoWithUUID:view.entityUUID];
    
    [view removeFromSuperview];
    
    [self _clearCurrentSelection];
    
    [self updateActionsView];
    [self updateSettingsButton];
}

- (void)duplicateEntityView:(TGPhotoPaintEntityView *)view
{
    TGPhotoPaintEntity *entity = [view.entity duplicate];
    entity.position = [self startPositionRelativeToEntity:entity];
    
    TGPhotoPaintEntityView *entityView = nil;
    if ([entity isKindOfClass:[TGPhotoPaintStickerEntity class]])
    {
        TGPhotoStickerEntityView *stickerView = [self _createStickerViewWithEntity:(TGPhotoPaintStickerEntity *)entity];
        entityView = stickerView;
    }
    else
    {
        TGPhotoTextEntityView *textView = [self _createTextViewWithEntity:(TGPhotoPaintTextEntity *)entity];
        entityView = textView;
    }
    
    [self selectEntityView:entityView];
    [self _registerEntityRemovalUndo:entity];
    [self updateActionsView];
}

- (void)editEntityView:(TGPhotoPaintEntityView *)view
{
    if ([view isKindOfClass:[TGPhotoTextEntityView class]])
        [(TGPhotoTextEntityView *)view beginEditing];
}

#pragma mark Menu

- (void)showMenuForEntityView
{
    if (_menuContainerView != nil)
    {
        TGMenuContainerView *container = _menuContainerView;
        bool isShowingMenu = container.isShowingMenu;
        _menuContainerView = nil;
        
        [container removeFromSuperview];
        
        if (!isShowingMenu && container.menuView.userInfo[@"entity"] == _currentEntityView)
        {
            if ([_currentEntityView isKindOfClass:[TGPhotoTextEntityView class]])
                [self editEntityView:_currentEntityView];
    
            return;
        }
    }
    
    UIView *parentView = self.view;
    _menuContainerView = [[TGMenuContainerView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, parentView.frame.size.width, parentView.frame.size.height)];
    [parentView addSubview:_menuContainerView];
    
    NSArray *actions = nil;
    
    if ([_currentEntityView isKindOfClass:[TGPhotoStickerEntityView class]])
    {
        actions = @
        [
            @{ @"title": TGLocalized(@"Paint.Delete"), @"action": @"delete" },
            @{ @"title": TGLocalized(@"Paint.Duplicate"), @"action": @"duplicate" },
        ];
    }
    else
    {
        actions = @
        [
            @{ @"title": TGLocalized(@"Paint.Delete"), @"action": @"delete" },
            @{ @"title": TGLocalized(@"Paint.Edit"), @"action": @"edit" },
            @{ @"title": TGLocalized(@"Paint.Duplicate"), @"action": @"duplicate" },
        ];
    }
    
    [_menuContainerView.menuView setUserInfo:@{ @"entity": _currentEntityView }];
    [_menuContainerView.menuView setButtonsAndActions:actions watcherHandle:_actionHandle];
    [_menuContainerView.menuView sizeToFit];
    
    CGRect sourceRect = CGRectOffset([_currentEntityView convertRect:_currentEntityView.bounds toView:_menuContainerView], 0, -15.0f);
    [_menuContainerView showMenuFromRect:sourceRect animated:false];
}

- (void)hideMenu
{
    [_menuContainerView hideMenu];
}

- (void)actionStageActionRequested:(NSString *)action options:(id)options
{
    if ([action isEqualToString:@"menuAction"])
    {
        NSString *menuAction = options[@"action"];
        TGPhotoPaintEntityView *entity = options[@"userInfo"][@"entity"];
        
        if ([menuAction isEqualToString:@"delete"])
        {
            [self deleteEntityView:entity];
        }
        else if ([menuAction isEqualToString:@"duplicate"])
        {
            [self duplicateEntityView:entity];
        }
        else if ([menuAction isEqualToString:@"edit"])
        {
            [self editEntityView:entity];
        }
    }
    else if ([action isEqualToString:@"menuWillHide"])
    {
    }
}

#pragma mark View

- (CGPoint)centerPointFittedCropRect
{
    return [_previewView convertPoint:TGPaintCenterOfRect(_previewView.bounds) toView:_entitiesContainerView];
}

- (CGFloat)startRotation
{
    return TGCounterRotationForOrientation(_photoEditor.cropOrientation) - _photoEditor.cropRotation;
}

- (CGPoint)startPositionRelativeToEntity:(TGPhotoPaintEntity *)entity
{
    const CGPoint offset = CGPointMake(200.0f, 200.0f);
    
    if (entity != nil)
    {
        return TGPaintAddPoints(entity.position, offset);
    }
    else
    {
        const CGFloat minimalDistance = 100.0f;
        CGPoint position = [self centerPointFittedCropRect];
        
        while (true)
        {
            bool occupied = false;
            for (TGPhotoPaintEntityView *view in _entitiesContainerView.subviews)
            {
                if (![view isKindOfClass:[TGPhotoPaintEntityView class]])
                    continue;
                
                CGPoint location = view.center;
                CGFloat distance = sqrt(pow(location.x - position.x, 2) + pow(location.y - position.y, 2));
                if (distance < minimalDistance)
                    occupied = true;
            }
            
            if (!occupied)
                break;
            else
                position = TGPaintAddPoints(position, offset);
        }
        
        return position;
    }
}

- (void)_commonEntityViewSetup:(TGPhotoPaintEntityView *)entityView entity:(TGPhotoPaintEntity *)entity
{
    [self hideMenu];
    
    entityView.transform = CGAffineTransformRotate(CGAffineTransformMakeScale(entity.scale, entity.scale), entity.angle);
    entityView.center = entity.position;
    
    __weak TGPhotoPaintController *weakSelf = self;
    entityView.shouldTouchEntity = ^bool (__unused TGPhotoPaintEntityView *sender)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return false;
        
        return ![strongSelf->_canvasView isTracking] && ![strongSelf->_entitiesContainerView isTrackingAnyEntityView];
    };
    entityView.entityBeganDragging = ^(TGPhotoPaintEntityView *sender)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf != nil && sender != strongSelf->_entitySelectionView.entityView)
            [strongSelf selectEntityView:sender];
    };
    entityView.entityChanged = ^(TGPhotoPaintEntityView *sender)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (sender == strongSelf->_entitySelectionView.entityView)
            [strongSelf->_entitySelectionView update];
        
        [strongSelf updateActionsView];
    };
}

- (void)_registerEntityRemovalUndo:(TGPhotoPaintEntity *)entity
{
    [_undoManager registerUndoWithUUID:entity.uuid block:^(__unused TGPainting *painting, TGPhotoEntitiesContainerView *entitiesContainer, NSInteger uuid)
    {
        [entitiesContainer removeViewWithUUID:uuid];
    }];
}

- (TGPhotoPaintEntityView *)_createEntityViewWithEntity:(TGPhotoPaintEntity *)entity
{
    if ([entity isKindOfClass:[TGPhotoPaintStickerEntity class]])
        return [self _createStickerViewWithEntity:(TGPhotoPaintStickerEntity *)entity];
    else if ([entity isKindOfClass:[TGPhotoPaintTextEntity class]])
        return [self _createTextViewWithEntity:(TGPhotoPaintTextEntity *)entity];
    
    return nil;
}

- (TGPhotoStickerEntityView *)_createStickerViewWithEntity:(TGPhotoPaintStickerEntity *)entity
{
    TGPhotoStickerEntityView *stickerView = [[TGPhotoStickerEntityView alloc] initWithEntity:entity];
    [self _commonEntityViewSetup:stickerView entity:entity];
    [_entitiesContainerView addSubview:stickerView];

    return stickerView;
}

- (TGPhotoTextEntityView *)_createTextViewWithEntity:(TGPhotoPaintTextEntity *)entity
{
    TGPhotoTextEntityView *textView = [[TGPhotoTextEntityView alloc] initWithEntity:entity];
    [textView sizeToFit];
    
    __weak TGPhotoPaintController *weakSelf = self;
    textView.beganEditing = ^(TGPhotoTextEntityView *sender)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf bringTextEntityViewFront:sender];
    };
    
    textView.finishedEditing = ^(__unused TGPhotoTextEntityView *sender)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf sendTextEntityViewBack];
    };
    
    [self _commonEntityViewSetup:textView entity:entity];
    [_entitiesContainerView addSubview:textView];
    
    return textView;
}

#pragma mark Stickers

- (void)presentStickersView
{
    if (_stickersView == nil)
    {
        TGPhotoStickersView *view = [[TGPhotoStickersView alloc] initWithContext:_context frame:self.view.bounds];
        view.parentViewController = self;
        
        __weak TGPhotoPaintController *weakSelf = self;
        __weak TGPhotoStickersView *weakStickersView = view;
        view.stickerSelected = ^(TGDocumentMediaAttachment *document, CGPoint transitionPoint, TGPhotoStickersView *stickersView, UIView *snapshotView)
        {
            __strong TGPhotoPaintController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf createNewStickerWithDocument:document transitionPoint:transitionPoint stickersView:stickersView snapshotView:snapshotView];
        };
        view.dismissed = ^
        {
            __strong TGPhotoStickersView *strongStickersView = weakStickersView;
            if (strongStickersView != nil)
                [strongStickersView removeFromSuperview];
        };
        
        _stickersView = view;
    }
    
    if ([_context currentSizeClass] == UIUserInterfaceSizeClassCompact)
    {
        _stickersView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _stickersView.frame = self.view.bounds;
        _stickersView.safeAreaInset = self.controllerSafeAreaInset;
        [self.parentViewController.view addSubview:_stickersView];
    }
    else
    {
        _settingsView = _stickersView;
        [_stickersView sizeToFit];
        
        UIView *wrapper = [self settingsViewWrapper];
        wrapper.userInteractionEnabled = true;
        [wrapper addSubview:_stickersView];
        
        [self viewWillLayoutSubviews];
    }
    
    _stickersView.outerView = self.parentViewController.view;
    _stickersView.targetView = _contentWrapperView;
    
    [_stickersView present];
}

- (void)createNewStickerWithDocument:(TGDocumentMediaAttachment *)document transitionPoint:(CGPoint)transitionPoint stickersView:(TGPhotoStickersView *)stickersView snapshotView:(UIView *)snapshotView
{
    TGPhotoPaintStickerEntity *entity = [[TGPhotoPaintStickerEntity alloc] initWithDocument:document baseSize:[self _stickerBaseSizeForCurrentPainting]];
    [self _setStickerEntityPosition:entity];
    
    TGPhotoStickerEntityView *stickerView = [self _createStickerViewWithEntity:entity];
    stickerView.hidden = true;
    
    CGFloat rotation = entity.angle - [self startRotation];
    
    CGRect bounds = stickerView.realBounds;
    CGPoint center = [stickerView.superview convertPoint:stickerView.center toView:self.parentViewController.view];
    CGFloat scale = [[stickerView.superview.superview.layer valueForKeyPath:@"transform.scale.x"] floatValue];
    CGRect targetFrame = CGRectMake(center.x - bounds.size.width * scale / 2.0f, center.y - bounds.size.height * scale / 2.0f, bounds.size.width * scale, bounds.size.height * scale);

    [stickersView dismissWithSnapshotView:snapshotView startPoint:transitionPoint targetFrame:targetFrame targetRotation:rotation completion:^
    {
        stickerView.hidden = false;
        [_entitySelectionView fadeIn];
    }];
    
    [self selectEntityView:stickerView];
    _entitySelectionView.alpha = 0.0f;
    
    [self _registerEntityRemovalUndo:entity];
    [self updateActionsView];
}

- (void)mirrorSelectedStickerEntity
{
    if ([_currentEntityView isKindOfClass:[TGPhotoStickerEntityView class]])
        [((TGPhotoStickerEntityView *)_currentEntityView) mirror];
}

#pragma mark Text

- (void)createNewTextLabel
{
    TGPaintSwatch *currentSwatch = _portraitSettingsView.swatch;
    TGPaintSwatch *whiteSwatch = [TGPaintSwatch swatchWithColor:[UIColor whiteColor] colorLocation:1.0f brushWeight:currentSwatch.brushWeight];
    TGPaintSwatch *blackSwatch = [TGPaintSwatch swatchWithColor:[UIColor blackColor] colorLocation:0.85f brushWeight:currentSwatch.brushWeight];
    [self setCurrentSwatch:_selectedStroke ? blackSwatch : whiteSwatch sender:nil];
    
    CGFloat maxWidth = [self fittedContentSize].width - 26.0f;
    TGPhotoPaintTextEntity *entity = [[TGPhotoPaintTextEntity alloc] initWithText:@"" font:_selectedTextFont swatch:_portraitSettingsView.swatch baseFontSize:[self _textBaseFontSizeForCurrentPainting] maxWidth:maxWidth stroke:_selectedStroke];
    entity.position = [self startPositionRelativeToEntity:nil];
    entity.angle = [self startRotation];
    
    TGPhotoTextEntityView *textView = [self _createTextViewWithEntity:entity];
    
    [self selectEntityView:textView];
    
    [self _registerEntityRemovalUndo:entity];
    [self updateActionsView];
    
    [textView beginEditing];
}

- (void)bringTextEntityViewFront:(TGPhotoTextEntityView *)entityView
{
    _editedTextView = entityView;
    entityView.inhibitGestures = true;
    
    [_dimView.superview insertSubview:_dimView belowSubview:entityView];
    
    _textEditingDismissButton = [[UIButton alloc] initWithFrame:_dimView.bounds];
    _dimView.userInteractionEnabled = true;
    [_textEditingDismissButton addTarget:self action:@selector(_dismissButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [_dimView addSubview:_textEditingDismissButton];
    
    _editedTextCenter = entityView.center;
    _editedTextTransform = entityView.transform;
    
    _entitySelectionView.alpha = 0.0f;
    
    void (^changeBlock)(void) = ^
    {
        entityView.center = [self centerPointFittedCropRect];
        entityView.transform = CGAffineTransformMakeRotation([self startRotation]);
        
        _dimView.alpha = 1.0f;
    };
    
    _scrollView.userInteractionEnabled = true;
    _contentWrapperView.userInteractionEnabled = true;
    
    if (iosMajorVersion() >= 7)
    {
        [UIView animateWithDuration:0.4 delay:0.0 usingSpringWithDamping:0.8f initialSpringVelocity:0.0f options:kNilOptions animations:changeBlock completion:nil];
    }
    else
    {
        [UIView animateWithDuration:0.35 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:changeBlock completion:nil];
    }
    
    [self setInterfaceHidden:true animated:true];
}

- (void)_dismissButtonTapped
{
    TGPhotoTextEntityView *entityView = _editedTextView;
    [entityView endEditing];
}

- (void)sendTextEntityViewBack
{
    _scrollView.userInteractionEnabled = false;
    _contentWrapperView.userInteractionEnabled = false;
    
    _dimView.userInteractionEnabled = false;
    [_textEditingDismissButton removeFromSuperview];
    _textEditingDismissButton = nil;
    
    TGPhotoTextEntityView *entityView = _editedTextView;
    _editedTextView = nil;
    
    void (^changeBlock)(void) = ^
    {
        entityView.center = _editedTextCenter;
        entityView.transform = _editedTextTransform;
        _dimView.alpha = 0.0f;
    };
    
    void (^completionBlock)(BOOL) = ^(__unused BOOL finished)
    {
        [_dimView.superview bringSubviewToFront:_dimView];
        entityView.inhibitGestures = false;
        
        if (entityView.isEmpty)
        {
            [self deleteEntityView:entityView];
        }
        else
        {
            [_entitySelectionView update];
            [_entitySelectionView fadeIn];
        }
    };
    
    if (iosMajorVersion() >= 7)
    {
        [UIView animateWithDuration:0.4 delay:0.0 usingSpringWithDamping:0.8f initialSpringVelocity:0.0f options:kNilOptions animations:changeBlock completion:completionBlock];
    }
    else
    {
        [UIView animateWithDuration:0.35 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:changeBlock completion:completionBlock];
    }
    
    [self setInterfaceHidden:false animated:true];
    
    TGMenuContainerView *container = _menuContainerView;
    _menuContainerView = nil;
    [container removeFromSuperview];
}

- (void)containerPressed
{
    if (_currentEntityView == nil)
        return;
    
    if ([_currentEntityView isKindOfClass:[TGPhotoTextEntityView class]])
    {
        TGPhotoTextEntityView *textEntityView = (TGPhotoTextEntityView *)_currentEntityView;
        if ([textEntityView isEditing])
        {
            [textEntityView endEditing];
            return;
        }
    }
    [self selectEntityView:nil];
}

#pragma mark - Relative Size Calculation

- (CGSize)_stickerBaseSizeForCurrentPainting
{
    CGSize fittedSize = [self fittedContentSize];
    CGFloat maxSide = MAX(fittedSize.width, fittedSize.height);
    CGFloat side = ceil(maxSide * 0.3125f);
    return CGSizeMake(side, side);
}

- (CGFloat)_textBaseFontSizeForCurrentPainting
{
    CGSize fittedSize = [self fittedContentSize];
    CGFloat maxSide = MAX(fittedSize.width, fittedSize.height);
    return ceil(maxSide * 0.08f);
}

- (CGFloat)_brushBaseWeightForCurrentPainting
{
    return 25.0f / TGPhotoPaintingMaxSize.width * _painting.size.width;
}

- (CGFloat)_brushWeightRangeForCurrentPainting
{
    return 125.0f / TGPhotoPaintingMaxSize.width * _painting.size.width;
}

- (CGFloat)_brushWeightForSize:(CGFloat)size
{
    return [self _brushBaseWeightForCurrentPainting] + [self _brushWeightRangeForCurrentPainting] * size;
}

- (CGSize)maximumPaintingSize
{
    static dispatch_once_t onceToken;
    static CGSize size;
    dispatch_once(&onceToken, ^
    {
        CGSize screenSize = TGScreenSize();
        if ((NSInteger)screenSize.height == 480)
            size = TGPhotoPaintingLightMaxSize;
        else
            size = TGPhotoPaintingMaxSize;
    });
    return size;
}

#pragma mark - Settings

- (void)setCurrentSwatch:(TGPaintSwatch *)swatch sender:(id)sender
{
    [_canvasView setBrushColor:swatch.color];
    [_canvasView setBrushWeight:[self _brushWeightForSize:swatch.brushWeight]];
    if ([_currentEntityView isKindOfClass:[TGPhotoTextEntityView class]])
        [(TGPhotoTextEntityView *)_currentEntityView setSwatch:swatch];
    
    if (sender != _landscapeSettingsView)
        [_landscapeSettingsView setSwatch:swatch];
    
    if (sender != _portraitSettingsView)
        [_portraitSettingsView setSwatch:swatch];
}

- (void)updateSettingsButton
{
    if ([_currentEntityView isKindOfClass:[TGPhotoTextEntityView class]])
        [self setSettingsButtonIcon:TGPhotoPaintSettingsViewIconText];
    else if ([_currentEntityView isKindOfClass:[TGPhotoStickerEntityView class]])
        [self setSettingsButtonIcon:TGPhotoPaintSettingsViewIconMirror];
    else
        [self setSettingsButtonIcon:TGPhotoPaintSettingsViewIconBrush];
    
    [self _updateTabs];
}

- (void)setSettingsButtonIcon:(TGPhotoPaintSettingsViewIcon)icon
{
    [_portraitSettingsView setIcon:icon animated:true];
    [_landscapeSettingsView setIcon:icon animated:true];
}

- (void)settingsWrapperPressed
{
    [_settingsView dismissWithCompletion:^
    {
        [_settingsView removeFromSuperview];
        _settingsView = nil;
        
        [_settingsViewWrapper removeFromSuperview];
    }];
}

- (UIView *)settingsViewWrapper
{
    if (_settingsViewWrapper == nil)
    {
        _settingsViewWrapper = [[TGPhotoPaintSettingsWrapperView alloc] initWithFrame:self.parentViewController.view.bounds];
        _settingsViewWrapper.exclusiveTouch = true;
        
        __weak TGPhotoPaintController *weakSelf = self;
        _settingsViewWrapper.pressed = ^(__unused CGPoint location)
        {
            __strong TGPhotoPaintController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf settingsWrapperPressed];
        };
        _settingsViewWrapper.suppressTouchAtPoint = ^bool(CGPoint location)
        {
            __strong TGPhotoPaintController *strongSelf = weakSelf;
            if (strongSelf == nil)
                return false;
            
            UIView *view = [strongSelf.view hitTest:[strongSelf.view convertPoint:location fromView:nil] withEvent:nil];
            if ([view isKindOfClass:[TGModernButton class]])
                return true;
            
            if ([view isKindOfClass:[TGPaintCanvas class]])
                return true;
            
            if (view == strongSelf->_portraitToolsWrapperView || view == strongSelf->_landscapeToolsWrapperView)
                return true;
            
            return false;
        };
    }
    
    [self.parentViewController.view addSubview:_settingsViewWrapper];
    
    return _settingsViewWrapper;
}

- (TGPaintBrushPreview *)brushPreview
{
    if ([_brushes.firstObject previewImage] != nil)
        return nil;
    
    if (_brushPreview == nil)
        _brushPreview = [[TGPaintBrushPreview alloc] init];
    
    return _brushPreview;
}

- (void)presentBrushSettingsView
{
    TGPhotoBrushSettingsView *view = [[TGPhotoBrushSettingsView alloc] initWithBrushes:_brushes preview:[self brushPreview]];
    [view setBrush:_painting.brush];
    
    __weak TGPhotoPaintController *weakSelf = self;
    view.brushChanged = ^(TGPaintBrush *brush)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (strongSelf->_canvasView.state.eraser && brush.lightSaber)
            brush = strongSelf->_brushes.firstObject;
        
        [strongSelf->_canvasView setBrush:brush];
        
        [strongSelf settingsWrapperPressed];
    };
    _settingsView = view;
    [view sizeToFit];
    
    UIView *wrapper = [self settingsViewWrapper];
    wrapper.userInteractionEnabled = true;
    [wrapper addSubview:view];
    
    [self viewWillLayoutSubviews];
    
    [view present];
}

- (void)presentTextSettingsView
{
    TGPhotoTextSettingsView *view = [[TGPhotoTextSettingsView alloc] initWithFonts:[TGPhotoPaintFont availableFonts] selectedFont:_selectedTextFont selectedStroke:_selectedStroke];
    
    __weak TGPhotoPaintController *weakSelf = self;
    view.fontChanged = ^(TGPhotoPaintFont *font)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_selectedTextFont = font;

        TGPhotoTextEntityView *textView = (TGPhotoTextEntityView *)strongSelf->_currentEntityView;
        [textView setFont:font];
        
        [strongSelf settingsWrapperPressed];
    };
    view.strokeChanged = ^(bool stroke)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_selectedStroke = stroke;
        
        if (stroke && [strongSelf->_portraitSettingsView.swatch.color isEqual:[UIColor whiteColor]])
        {
            TGPaintSwatch *currentSwatch = strongSelf->_portraitSettingsView.swatch;
            TGPaintSwatch *blackSwatch = [TGPaintSwatch swatchWithColor:[UIColor blackColor] colorLocation:0.85f brushWeight:currentSwatch.brushWeight];
            [strongSelf setCurrentSwatch:blackSwatch sender:nil];
        }
        else if (!stroke && [strongSelf->_portraitSettingsView.swatch.color isEqual:UIColorRGB(0x000000)])
        {
            TGPaintSwatch *currentSwatch = strongSelf->_portraitSettingsView.swatch;
            TGPaintSwatch *whiteSwatch = [TGPaintSwatch swatchWithColor:[UIColor whiteColor] colorLocation:1.0f brushWeight:currentSwatch.brushWeight];
            [strongSelf setCurrentSwatch:whiteSwatch sender:nil];
        }
        
        TGPhotoTextEntityView *textView = (TGPhotoTextEntityView *)strongSelf->_currentEntityView;
        [textView setStroke:stroke];
        
        [strongSelf settingsWrapperPressed];
    };
    
    _settingsView = view;
    [view sizeToFit];
    
    UIView *wrapper = [self settingsViewWrapper];
    wrapper.userInteractionEnabled = true;
    [wrapper addSubview:view];
    
    [self viewWillLayoutSubviews];
    
    [view present];
}

- (void)toggleEraserMode
{
    _canvasView.state.eraser = !_canvasView.state.isEraser;
    
    if (_canvasView.state.eraser)
    {
        if (_canvasView.state.brush.lightSaber)
            [_canvasView setBrush:_brushes.firstObject];
    }
    
    [_portraitSettingsView setHighlighted:_canvasView.state.isEraser];
    [_landscapeSettingsView setHighlighted:_canvasView.state.isEraser];
    
    [self _updateTabs];
}

#pragma mark - Scroll View

- (CGSize)fittedContentSize
{
    CGSize fittedOriginalSize = TGScaleToSize(_photoEditor.originalSize, [self maximumPaintingSize]);
    CGFloat scale = fittedOriginalSize.width / _photoEditor.originalSize.width;
    
    CGSize size = CGSizeMake(_photoEditor.cropRect.size.width * scale, _photoEditor.cropRect.size.height * scale);
    if (_photoEditor.cropOrientation == UIImageOrientationLeft || _photoEditor.cropOrientation == UIImageOrientationRight)
        size = CGSizeMake(size.height, size.width);

    return CGSizeMake(floor(size.width), floor(size.height));
}

- (CGRect)fittedCropRect:(bool)originalSize
{
    CGSize fittedOriginalSize = TGScaleToSize(_photoEditor.originalSize, [self maximumPaintingSize]);
    CGFloat scale = fittedOriginalSize.width / _photoEditor.originalSize.width;
    
    CGSize size = fittedOriginalSize;
    if (!originalSize)
        size = CGSizeMake(_photoEditor.cropRect.size.width * scale, _photoEditor.cropRect.size.height * scale);
    
    return CGRectMake(-_photoEditor.cropRect.origin.x * scale, -_photoEditor.cropRect.origin.y * scale, size.width, size.height);
}

- (CGPoint)fittedCropCenterScale:(CGFloat)scale
{
    CGSize size = CGSizeMake(_photoEditor.cropRect.size.width * scale, _photoEditor.cropRect.size.height * scale);
    CGRect rect = CGRectMake(_photoEditor.cropRect.origin.x * scale, _photoEditor.cropRect.origin.y * scale, size.width, size.height);
    
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

- (void)resetScrollView
{
    CGSize contentSize = [self fittedContentSize];
    CGRect fittedCropRect = [self fittedCropRect:false];
    
    _contentWrapperView.frame = CGRectMake(0.0f, 0.0f, contentSize.width, contentSize.height);
    
    CGFloat scale = _scrollView.bounds.size.width / fittedCropRect.size.width;
    _contentWrapperView.transform = CGAffineTransformMakeScale(scale, scale);
    _contentWrapperView.frame = CGRectMake(0.0f, 0.0f, _scrollView.bounds.size.width, _scrollView.bounds.size.height);
}

#pragma mark - Gestures

- (void)handlePinch:(UIPinchGestureRecognizer *)gestureRecognizer
{
    [_entitiesContainerView handlePinch:gestureRecognizer];
}

- (void)handleRotate:(UIRotationGestureRecognizer *)gestureRecognizer
{
    [_entitiesContainerView handleRotate:gestureRecognizer];
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)__unused gestureRecognizer
{
    return !_canvasView.isTracking;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)__unused gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)__unused otherGestureRecognizer
{
    return true;
}

#pragma mark - Transitions

- (void)transitionIn
{
    _portraitSettingsView.layer.shouldRasterize = true;
    _landscapeSettingsView.layer.shouldRasterize = true;
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _portraitToolsWrapperView.alpha = 1.0f;
        _landscapeToolsWrapperView.alpha = 1.0f;
        
        _portraitActionsView.alpha = 1.0f;
        _landscapeActionsView.alpha = 1.0f;
    } completion:^(__unused BOOL finished)
    {
        _portraitSettingsView.layer.shouldRasterize = false;
        _landscapeSettingsView.layer.shouldRasterize = false;
    }];
}

+ (CGRect)photoContainerFrameForParentViewFrame:(CGRect)parentViewFrame toolbarLandscapeSize:(CGFloat)toolbarLandscapeSize orientation:(UIInterfaceOrientation)orientation panelSize:(CGFloat)panelSize hasOnScreenNavigation:(bool)hasOnScreenNavigation
{
    CGRect frame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:parentViewFrame toolbarLandscapeSize:toolbarLandscapeSize orientation:orientation panelSize:panelSize hasOnScreenNavigation:hasOnScreenNavigation];
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
            frame.origin.x -= TGPhotoPaintTopPanelSize;
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            frame.origin.x += TGPhotoPaintTopPanelSize;
            break;
            
        default:
            frame.origin.y += TGPhotoPaintTopPanelSize;
            break;
    }
    
    return frame;
}

- (CGRect)_targetFrameForTransitionInFromFrame:(CGRect)fromFrame
{
    CGSize referenceSize = [self referenceViewSize];
    UIInterfaceOrientation orientation = self.interfaceOrientation;
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        orientation = UIInterfaceOrientationPortrait;
    
    bool hasOnScreenNavigation = false;
    if (iosMajorVersion() >= 11)
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || _context.safeAreaInset.bottom > FLT_EPSILON;
    
    CGRect containerFrame = [TGPhotoPaintController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoPaintTopPanelSize + TGPhotoPaintBottomPanelSize hasOnScreenNavigation:hasOnScreenNavigation];
    
    CGSize fittedSize = TGScaleToSize(fromFrame.size, containerFrame.size);
    CGRect toFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    return toFrame;
}

- (void)_finishedTransitionInWithView:(UIView *)transitionView
{
    _appeared = true;
    
    [transitionView removeFromSuperview];
 
    [self setupCanvas];
    
    TGPhotoEditorPreviewView *previewView = _previewView;
    [previewView setPaintingHidden:true];
    previewView.hidden = false;
    [_containerView insertSubview:previewView belowSubview:_paintingWrapperView];
    [previewView performTransitionInIfNeeded];
    
    CGRect rect = [self fittedCropRect:true];
    _entitiesContainerView.frame = CGRectMake(0, 0, rect.size.width, rect.size.height);
    _entitiesContainerView.transform = CGAffineTransformMakeRotation(_photoEditor.cropRotation);
    
    CGSize fittedOriginalSize = TGScaleToSize(_photoEditor.originalSize, [self maximumPaintingSize]);
    CGSize rotatedSize = TGRotatedContentSize(fittedOriginalSize, _photoEditor.cropRotation);
    CGPoint centerPoint = CGPointMake(rotatedSize.width / 2.0f, rotatedSize.height / 2.0f);
    
    CGFloat scale = fittedOriginalSize.width / _photoEditor.originalSize.width;
    CGPoint offset = TGPaintSubtractPoints(centerPoint, [self fittedCropCenterScale:scale]);
    
    CGPoint boundsCenter = TGPaintCenterOfRect(_contentWrapperView.bounds);
    _entitiesContainerView.center = TGPaintAddPoints(boundsCenter, offset);
    
    [_contentWrapperView addSubview:_entitiesContainerView];
    
    [self resetScrollView];
    
    [self setupVideoPlaybackIfNeeded];
}

- (void)prepareForCustomTransitionOut
{
    _previewView.hidden = true;
    _canvasView.hidden = true;
    _scrollView.hidden = true;
    [UIView animateWithDuration:0.3f animations:^
    {
        _portraitToolsWrapperView.alpha = 0.0f;
        _landscapeToolsWrapperView.alpha = 0.0f;
    } completion:nil];
}

- (void)transitionOutSwitching:(bool)__unused switching completion:(void (^)(void))completion
{
    TGPhotoEditorPreviewView *previewView = self.previewView;
    previewView.interactionEnded = nil;
    
    _portraitSettingsView.layer.shouldRasterize = true;
    _landscapeSettingsView.layer.shouldRasterize = true;
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _portraitToolsWrapperView.alpha = 0.0f;
        _landscapeToolsWrapperView.alpha = 0.0f;
        
        _portraitActionsView.alpha = 0.0f;
        _landscapeActionsView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        if (completion != nil)
            completion();
    }];
    
    [_player pause];
}

- (CGRect)transitionOutSourceFrameForReferenceFrame:(CGRect)referenceFrame orientation:(UIInterfaceOrientation)orientation
{
    bool hasOnScreenNavigation = false;
    if (iosMajorVersion() >= 11)
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || _context.safeAreaInset.bottom > FLT_EPSILON;
    
    CGRect containerFrame = [TGPhotoPaintController photoContainerFrameForParentViewFrame:self.view.frame toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoPaintTopPanelSize + TGPhotoPaintBottomPanelSize hasOnScreenNavigation:hasOnScreenNavigation];
    
    CGSize fittedSize = TGScaleToSize(referenceFrame.size, containerFrame.size);
    return CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
}

- (void)_animatePreviewViewTransitionOutToFrame:(CGRect)targetFrame saving:(bool)saving parentView:(UIView *)parentView completion:(void (^)(void))completion
{
    _dismissing = true;
    
    [_entitySelectionView removeFromSuperview];
    _entitySelectionView = nil;
    
    TGPhotoEditorPreviewView *previewView = self.previewView;
    [previewView prepareForTransitionOut];
    
    bool hasOnScreenNavigation = false;
    if (iosMajorVersion() >= 11)
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || _context.safeAreaInset.bottom > FLT_EPSILON;
    
    UIInterfaceOrientation orientation = self.interfaceOrientation;
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        orientation = UIInterfaceOrientationPortrait;
    
    CGRect containerFrame = [TGPhotoPaintController photoContainerFrameForParentViewFrame:self.view.frame toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoPaintTopPanelSize + TGPhotoPaintBottomPanelSize hasOnScreenNavigation:hasOnScreenNavigation];
    CGRect referenceFrame = CGRectMake(0, 0, self.photoEditor.rotatedCropSize.width, self.photoEditor.rotatedCropSize.height);
    CGRect rect = CGRectOffset([self transitionOutSourceFrameForReferenceFrame:referenceFrame orientation:orientation], -containerFrame.origin.x, -containerFrame.origin.y);
    previewView.frame = rect;
    
    UIView *snapshotView = nil;
    POPSpringAnimation *snapshotAnimation = nil;
    NSMutableArray *animations = [[NSMutableArray alloc] init];
    
    if (saving && CGRectIsNull(targetFrame) && parentView != nil)
    {
        snapshotView = [previewView snapshotViewAfterScreenUpdates:false];
        snapshotView.frame = [_containerView convertRect:previewView.frame toView:parentView];
        
        UIView *canvasSnapshotView = [_paintingWrapperView resizableSnapshotViewFromRect:[_paintingWrapperView convertRect:previewView.bounds fromView:previewView] afterScreenUpdates:false withCapInsets:UIEdgeInsetsZero];
        canvasSnapshotView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        canvasSnapshotView.transform = _scrollView.transform;
        canvasSnapshotView.frame = snapshotView.bounds;
        [snapshotView addSubview:canvasSnapshotView];
        
        UIView *entitiesSnapshotView = [_contentWrapperView resizableSnapshotViewFromRect:[_contentWrapperView convertRect:previewView.bounds fromView:previewView] afterScreenUpdates:false withCapInsets:UIEdgeInsetsZero];
        entitiesSnapshotView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        entitiesSnapshotView.transform = _scrollView.transform;
        entitiesSnapshotView.frame = snapshotView.bounds;
        [snapshotView addSubview:entitiesSnapshotView];
        
        CGSize fittedSize = TGScaleToSize(previewView.frame.size, self.view.frame.size);
        targetFrame = CGRectMake((self.view.frame.size.width - fittedSize.width) / 2, (self.view.frame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
        
        [parentView addSubview:snapshotView];
        
        snapshotAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
        snapshotAnimation.fromValue = [NSValue valueWithCGRect:snapshotView.frame];
        snapshotAnimation.toValue = [NSValue valueWithCGRect:targetFrame];
        [animations addObject:snapshotAnimation];
    }
    
    targetFrame = CGRectOffset(targetFrame, -containerFrame.origin.x, -containerFrame.origin.y);
    CGPoint targetCenter = TGPaintCenterOfRect(targetFrame);
    
    POPSpringAnimation *previewAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
    previewAnimation.fromValue = [NSValue valueWithCGRect:previewView.frame];
    previewAnimation.toValue = [NSValue valueWithCGRect:targetFrame];
    if (_videoView == nil)
        [animations addObject:previewAnimation];
    
    POPSpringAnimation *previewAlphaAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewAlpha];
    previewAlphaAnimation.fromValue = @(previewView.alpha);
    previewAlphaAnimation.toValue = @(0.0f);
    if (_videoView == nil)
        [animations addObject:previewAnimation];
    
    POPSpringAnimation *entitiesAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewCenter];
    entitiesAnimation.fromValue = [NSValue valueWithCGPoint:_scrollView.center];
    entitiesAnimation.toValue = [NSValue valueWithCGPoint:targetCenter];
    [animations addObject:entitiesAnimation];
    
    CGFloat targetEntitiesScale = targetFrame.size.width / _scrollView.frame.size.width;
    POPSpringAnimation *entitiesScaleAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewScaleXY];
    entitiesScaleAnimation.fromValue = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    entitiesScaleAnimation.toValue = [NSValue valueWithCGSize:CGSizeMake(targetEntitiesScale, targetEntitiesScale)];
    [animations addObject:entitiesScaleAnimation];
    
    POPSpringAnimation *entitiesAlphaAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewAlpha];
    entitiesAlphaAnimation.fromValue = @(_canvasView.alpha);
    entitiesAlphaAnimation.toValue = @(0.0f);
    [animations addObject:entitiesAlphaAnimation];
    
    POPSpringAnimation *paintingAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewCenter];
    paintingAnimation.fromValue = [NSValue valueWithCGPoint:_paintingWrapperView.center];
    paintingAnimation.toValue = [NSValue valueWithCGPoint:targetCenter];
    [animations addObject:paintingAnimation];
    
    CGFloat targetPaintingScale = targetFrame.size.width / _paintingWrapperView.frame.size.width;
    POPSpringAnimation *paintingScaleAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewScaleXY];
    paintingScaleAnimation.fromValue = [NSValue valueWithCGSize:CGSizeMake(1.0f, 1.0f)];
    paintingScaleAnimation.toValue = [NSValue valueWithCGSize:CGSizeMake(targetPaintingScale, targetPaintingScale)];
    [animations addObject:paintingScaleAnimation];

    POPSpringAnimation *paintingAlphaAnimation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewAlpha];
    paintingAlphaAnimation.fromValue = @(_paintingWrapperView.alpha);
    paintingAlphaAnimation.toValue = @(0.0f);
    [animations addObject:paintingAlphaAnimation];
    
    [TGPhotoEditorAnimation performBlock:^(__unused bool allFinished)
    {
        [snapshotView removeFromSuperview];
        
        if (completion != nil)
            completion();
    } whenCompletedAllAnimations:animations];
    
    if (snapshotAnimation != nil)
        [snapshotView pop_addAnimation:snapshotAnimation forKey:@"frame"];
    [previewView pop_addAnimation:previewAnimation forKey:@"frame"];
    [previewView pop_addAnimation:previewAlphaAnimation forKey:@"alpha"];
    
    [_scrollView pop_addAnimation:entitiesAnimation forKey:@"frame"];
    [_scrollView pop_addAnimation:entitiesScaleAnimation forKey:@"scale"];
    [_scrollView pop_addAnimation:entitiesAlphaAnimation forKey:@"alpha"];
    
    [_paintingWrapperView pop_addAnimation:paintingAnimation forKey:@"frame"];
    [_paintingWrapperView pop_addAnimation:paintingScaleAnimation forKey:@"scale"];
    [_paintingWrapperView pop_addAnimation:paintingAlphaAnimation forKey:@"alpha"];
    
    if (saving)
    {
        _scrollView.hidden = true;
        _paintingWrapperView.hidden = true;
        previewView.hidden = true;
    }
}

- (CGRect)transitionOutReferenceFrame
{
    TGPhotoEditorPreviewView *previewView = _previewView;
    return previewView.frame;
}

- (UIView *)transitionOutReferenceView
{
    return _previewView;
}

- (UIView *)snapshotView
{
    TGPhotoEditorPreviewView *previewView = self.previewView;
    return [previewView originalSnapshotView];
}

- (void)setInterfaceHidden:(bool)hidden animated:(bool)animated
{
    CGFloat targetAlpha = hidden ? 0.0f : 1.0;
    void (^changeBlock)(void) = ^
    {
        _portraitActionsView.alpha = targetAlpha;
        _landscapeActionsView.alpha = targetAlpha;
        _portraitSettingsView.alpha = targetAlpha;
        _landscapeSettingsView.alpha = targetAlpha;
    };
    
    if (animated)
        [UIView animateWithDuration:0.25 animations:changeBlock];
    else
        changeBlock();
    
    TGPhotoEditorController *editorController = (TGPhotoEditorController *)self.parentViewController;
    if (![editorController isKindOfClass:[TGPhotoEditorController class]])
        return;
    
    [editorController setToolbarHidden:hidden animated:animated];
}

- (void)setDimHidden:(bool)hidden animated:(bool)animated
{
    if (!hidden)
    {
        [_entitySelectionView fadeOut];
        
        if ([_currentEntityView isKindOfClass:[TGPhotoTextEntityView class]])
            [_dimView.superview insertSubview:_dimView belowSubview:_currentEntityView];
        else
            [_dimView.superview bringSubviewToFront:_dimView];
    }
    else
    {
        [_entitySelectionView fadeIn];
        
        [_dimView.superview bringSubviewToFront:_dimView];
    }
    
    void (^changeBlock)(void) = ^
    {
        _dimView.alpha = hidden ? 0.0f : 1.0f;
    };
    
    if (animated)
        [UIView animateWithDuration:0.25 animations:changeBlock];
    else
        changeBlock();
}

- (id)currentResultRepresentation
{
    return TGPaintCombineCroppedImages(self.photoEditor.currentResultImage, [self image], true, _photoEditor.originalSize, _photoEditor.cropRect, _photoEditor.cropOrientation, _photoEditor.cropRotation, false);
}

#pragma mark - Layout

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateLayout:[[LegacyComponentsGlobals provider] applicationStatusBarOrientation]];
    [_entitySelectionView update];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
 
    if (_menuContainerView != nil)
    {
        [_menuContainerView removeFromSuperview];
        _menuContainerView = nil;
    }
    
    [self updateLayout:toInterfaceOrientation];
}

- (void)updateLayout:(UIInterfaceOrientation)orientation
{
    if ([self inFormSheet] || [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        _landscapeToolsWrapperView.hidden = true;
        orientation = UIInterfaceOrientationPortrait;
    }
    
    CGSize referenceSize = [self referenceViewSize];
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height) + 2 * TGPhotoPaintBottomPanelSize;
    
    CGFloat panelToolbarPortraitSize = TGPhotoPaintBottomPanelSize + TGPhotoEditorToolbarSize;
    CGFloat panelToolbarLandscapeSize = TGPhotoPaintBottomPanelSize + self.toolbarLandscapeSize;
    
    bool hasOnScreenNavigation = false;
    if (iosMajorVersion() >= 11)
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || _context.safeAreaInset.bottom > FLT_EPSILON;
    
    UIEdgeInsets safeAreaInset = [TGViewController safeAreaInsetForOrientation:orientation hasOnScreenNavigation:hasOnScreenNavigation];
    UIEdgeInsets screenEdges = UIEdgeInsetsMake((screenSide - referenceSize.height) / 2, (screenSide - referenceSize.width) / 2, (screenSide + referenceSize.height) / 2, (screenSide + referenceSize.width) / 2);
    screenEdges.top += safeAreaInset.top;
    screenEdges.left += safeAreaInset.left;
    screenEdges.bottom -= safeAreaInset.bottom;
    screenEdges.right -= safeAreaInset.right;
    
    CGRect containerFrame = [TGPhotoPaintController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoPaintTopPanelSize + TGPhotoPaintBottomPanelSize hasOnScreenNavigation:hasOnScreenNavigation];
    
    _settingsViewWrapper.frame = self.parentViewController.view.bounds;
    
    if (_settingsView != nil)
        [_settingsView setInterfaceOrientation:orientation];
    
    _stickersView.safeAreaInset = safeAreaInset;
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
        {
            _landscapeSettingsView.interfaceOrientation = orientation;
            
            [UIView performWithoutAnimation:^
            {
                _landscapeToolsWrapperView.frame = CGRectMake(0, screenEdges.top, panelToolbarLandscapeSize, _landscapeToolsWrapperView.frame.size.height);
                _landscapeSettingsView.frame = CGRectMake(panelToolbarLandscapeSize - TGPhotoPaintBottomPanelSize, 0, TGPhotoPaintBottomPanelSize, _landscapeSettingsView.frame.size.height);
            }];
            
            _landscapeToolsWrapperView.frame = CGRectMake(screenEdges.left, screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);
            _landscapeSettingsView.frame = CGRectMake(_landscapeSettingsView.frame.origin.x, _landscapeSettingsView.frame.origin.y, _landscapeSettingsView.frame.size.width, _landscapeToolsWrapperView.frame.size.height);
            
            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.left, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
            _portraitSettingsView.frame = CGRectMake(0, 0, _portraitToolsWrapperView.frame.size.width, TGPhotoPaintBottomPanelSize);
            
            _landscapeActionsView.frame = CGRectMake(screenEdges.right - TGPhotoPaintTopPanelSize, screenEdges.top, TGPhotoPaintTopPanelSize, referenceSize.height);
            
            _settingsView.frame = CGRectMake(self.toolbarLandscapeSize + 50.0f + safeAreaInset.left, 0.0f, _settingsView.frame.size.width, _settingsView.frame.size.height);
        }
            break;
            
        case UIInterfaceOrientationLandscapeRight:
        {
            _landscapeSettingsView.interfaceOrientation = orientation;
            
            [UIView performWithoutAnimation:^
            {
                _landscapeToolsWrapperView.frame = CGRectMake(screenSide - panelToolbarLandscapeSize, screenEdges.top, panelToolbarLandscapeSize, _landscapeToolsWrapperView.frame.size.height);
                _landscapeSettingsView.frame = CGRectMake(0, 0, TGPhotoPaintBottomPanelSize, _landscapeSettingsView.frame.size.height);
            }];
            
            _landscapeToolsWrapperView.frame = CGRectMake(screenEdges.right - panelToolbarLandscapeSize, screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);
            _landscapeSettingsView.frame = CGRectMake(_landscapeSettingsView.frame.origin.x, _landscapeSettingsView.frame.origin.y, _landscapeSettingsView.frame.size.width, _landscapeToolsWrapperView.frame.size.height);
            
            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.top, screenSide - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
            _portraitSettingsView.frame = CGRectMake(0, 0, _portraitToolsWrapperView.frame.size.width, TGPhotoPaintBottomPanelSize);
            
            _landscapeActionsView.frame = CGRectMake(screenEdges.left, screenEdges.top, TGPhotoPaintTopPanelSize, referenceSize.height);
            
            _settingsView.frame = CGRectMake(_settingsViewWrapper.frame.size.width - _settingsView.frame.size.width - self.toolbarLandscapeSize - 50.0f - safeAreaInset.right, 0.0f, _settingsView.frame.size.width, _settingsView.frame.size.height);
        }
            break;
            
        default:
        {
            CGFloat x = _landscapeToolsWrapperView.frame.origin.x;
            if (x < screenSide / 2)
                x = 0;
            else
                x = screenSide - TGPhotoEditorPanelSize;
            _landscapeToolsWrapperView.frame = CGRectMake(x, screenEdges.top, panelToolbarLandscapeSize, referenceSize.height);
            
            _portraitToolsWrapperView.frame = CGRectMake(screenEdges.left, screenEdges.bottom - panelToolbarPortraitSize, referenceSize.width, panelToolbarPortraitSize);
            _portraitSettingsView.frame = CGRectMake(0, 0, referenceSize.width, TGPhotoPaintBottomPanelSize);
            
            _portraitActionsView.frame = CGRectMake(screenEdges.left, screenEdges.top, referenceSize.width, TGPhotoPaintTopPanelSize);
            
            if ([_context currentSizeClass] == UIUserInterfaceSizeClassRegular)
            {
                if ([_settingsView isKindOfClass:[TGPhotoStickersView class]])
                {
                    _settingsView.frame = CGRectMake(_settingsViewWrapper.frame.size.width / 6 * 2 - 5 - _settingsView.frame.size.width / 2.0f, _settingsViewWrapper.frame.size.height - _settingsView.frame.size.height - TGPhotoEditorToolbarSize + 10.0f, _settingsView.frame.size.width, _settingsView.frame.size.height);
                }
                else
                {
                    _settingsView.frame = CGRectMake(_settingsViewWrapper.frame.size.width / 2.0f - 10.0f, _settingsViewWrapper.frame.size.height - _settingsView.frame.size.height - TGPhotoEditorToolbarSize - 50.0f, _settingsView.frame.size.width, _settingsView.frame.size.height);
                }
            }
            else
            {
                _settingsView.frame = CGRectMake(_settingsViewWrapper.frame.size.width - _settingsView.frame.size.width, _settingsViewWrapper.frame.size.height - _settingsView.frame.size.height - TGPhotoEditorToolbarSize - 50.0f - safeAreaInset.bottom, _settingsView.frame.size.width, _settingsView.frame.size.height);
            }
        }
            break;
    }
    
    PGPhotoEditor *photoEditor = self.photoEditor;
    TGPhotoEditorPreviewView *previewView = self.previewView;
    
    CGSize fittedSize = TGScaleToSize(photoEditor.rotatedCropSize, containerFrame.size);
    CGRect previewFrame = CGRectMake((containerFrame.size.width - fittedSize.width) / 2, (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    CGFloat visibleArea = self.view.frame.size.height - _keyboardHeight;
    CGFloat yCenter = visibleArea / 2.0f;
    CGFloat offset = yCenter - _previewView.center.y - containerFrame.origin.y;
    CGFloat offsetHeight = _keyboardHeight > FLT_EPSILON ? offset : 0.0f;
    
    _wrapperView.frame = CGRectMake((referenceSize.width - screenSide) / 2, (referenceSize.height - screenSide) / 2 + offsetHeight, screenSide, screenSide);
    
    if (_dismissing || (previewView.superview != _containerView && previewView.superview != self.view))
        return;
    
    if (previewView.superview == self.view)
    {
        previewFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    }
    
    UIImageOrientation cropOrientation = _photoEditor.cropOrientation;
    CGRect cropRect = _photoEditor.cropRect;
    CGSize originalSize = _photoEditor.originalSize;
    CGFloat rotation = _photoEditor.cropRotation;
    
    CGAffineTransform rotationTransform = CGAffineTransformMakeRotation(TGRotationForOrientation(cropOrientation));
    _scrollView.transform = rotationTransform;
    _scrollView.frame = previewFrame;
    [self resetScrollView];
    
    _paintingWrapperView.transform = CGAffineTransformMakeRotation(TGRotationForOrientation(cropOrientation));
    _paintingWrapperView.frame = previewFrame;
    
    CGFloat originalWidth = TGOrientationIsSideward(cropOrientation, NULL) ? previewFrame.size.height : previewFrame.size.width;
    CGFloat ratio = originalWidth / cropRect.size.width;
    CGRect originalFrame = CGRectMake(-cropRect.origin.x * ratio, -cropRect.origin.y * ratio, originalSize.width * ratio, originalSize.height * ratio);
    
    previewView.frame = previewFrame;
    
    CGSize fittedOriginalSize = CGSizeMake(originalSize.width * ratio, originalSize.height * ratio);
    CGSize rotatedSize = TGRotatedContentSize(fittedOriginalSize, rotation);
    CGPoint centerPoint = CGPointMake(rotatedSize.width / 2.0f, rotatedSize.height / 2.0f);
    
    CGFloat scale = fittedOriginalSize.width / _photoEditor.originalSize.width;
    CGPoint centerOffset = TGPaintSubtractPoints(centerPoint, [self fittedCropCenterScale:scale]);
    
    _canvasView.transform = CGAffineTransformIdentity;
    _canvasView.frame = originalFrame;
    _canvasView.transform = CGAffineTransformMakeRotation(rotation);
    _canvasView.center = TGPaintAddPoints(TGPaintCenterOfRect(_paintingWrapperView.bounds), centerOffset);
    
    _selectionContainerView.transform = CGAffineTransformRotate(rotationTransform, rotation);
    _selectionContainerView.frame = previewFrame;
    
    _videoView.frame = originalFrame;
    _containerView.frame = CGRectMake(containerFrame.origin.x, containerFrame.origin.y + offsetHeight, containerFrame.size.width, containerFrame.size.height);
}

#pragma mark - Keyboard Avoidance

- (void)keyboardWillChangeFrame:(NSNotification *)notification
{
    UIView *parentView = self.view;
    
    NSTimeInterval duration = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] == nil ? 0.3 : [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    int curve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] intValue];
    CGRect screenKeyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrame = [parentView convertRect:screenKeyboardFrame fromView:nil];
    
    CGFloat keyboardHeight = (keyboardFrame.size.height <= FLT_EPSILON || keyboardFrame.size.width <= FLT_EPSILON) ? 0.0f : (parentView.frame.size.height - keyboardFrame.origin.y);
    keyboardHeight = MAX(keyboardHeight, 0.0f);
    
    _keyboardHeight = keyboardHeight;
    
    [self keyboardHeightChangedTo:keyboardHeight duration:duration curve:curve];
}

- (void)keyboardHeightChangedTo:(CGFloat)height duration:(NSTimeInterval)duration curve:(NSInteger)curve
{
    UIInterfaceOrientation orientation = self.interfaceOrientation;
    if ([self inFormSheet] || [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        orientation = UIInterfaceOrientationPortrait;
    
    bool hasOnScreenNavigation = false;
    if (iosMajorVersion() >= 11)
        hasOnScreenNavigation = (self.viewLoaded && self.view.safeAreaInsets.bottom > FLT_EPSILON) || _context.safeAreaInset.bottom > FLT_EPSILON;
    
    CGSize referenceSize = [self referenceViewSize];
    CGFloat screenSide = MAX(referenceSize.width, referenceSize.height) + 2 * TGPhotoPaintBottomPanelSize;
    
    CGRect containerFrame = [TGPhotoPaintController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoPaintTopPanelSize + TGPhotoPaintBottomPanelSize hasOnScreenNavigation:hasOnScreenNavigation];
    
    CGFloat visibleArea = self.view.frame.size.height - height;
    CGFloat yCenter = visibleArea / 2.0f;
    CGFloat offset = yCenter - _previewView.center.y - containerFrame.origin.y;
    CGFloat offsetHeight = height > FLT_EPSILON ? offset : 0.0f;
    
    [UIView animateWithDuration:duration delay:0.0 options:curve animations:^
    {
        _wrapperView.frame = CGRectMake((referenceSize.width - screenSide) / 2, (referenceSize.height - screenSide) / 2 + offsetHeight, _wrapperView.frame.size.width, _wrapperView.frame.size.height);
        _containerView.frame = CGRectMake(containerFrame.origin.x, containerFrame.origin.y + offsetHeight, containerFrame.size.width, containerFrame.size.height);
    } completion:nil];
}

#pragma mark - Video Playback

- (void)setupVideoPlaybackIfNeeded
{
    if ((![self.item isKindOfClass:[TGMediaAsset class]] || !((TGMediaAsset *)self.item).isVideo) && ![self.item isKindOfClass:[AVAsset class]])
        return;
    
    SSignal *itemSignal = [self.item isKindOfClass:[TGMediaAsset class]] ? [TGMediaAssetImageSignals playerItemForVideoAsset:(TGMediaAsset *)self.item] : [SSignal single:[AVPlayerItem playerItemWithAsset:((AVAsset *)self.item)]];
    ;
    
    __weak TGPhotoPaintController *weakSelf = self;
    [_playerItemDisposable setDisposable:[[itemSignal deliverOn:[SQueue mainQueue]] startWithNext:^(AVPlayerItem *playerItem)
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_player = [AVPlayer playerWithPlayerItem:playerItem];
        strongSelf->_player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
        strongSelf->_player.muted = true;
        
        NSTimeInterval startPosition = 0.0f;
        if (strongSelf->_photoEditor.trimStartValue > DBL_EPSILON)
            startPosition = strongSelf->_photoEditor.trimStartValue;
        
        CMTime targetTime = CMTimeMakeWithSeconds(startPosition, NSEC_PER_SEC);
        [strongSelf->_player.currentItem seekToTime:targetTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    
        [strongSelf _setupPlaybackStartedObserver];
    
        strongSelf->_videoView = [[TGModernGalleryVideoView alloc] initWithFrame:strongSelf->_previewView.frame player:strongSelf->_player];
        strongSelf->_videoView.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        strongSelf->_videoView.playerLayer.opaque = false;
        strongSelf->_videoView.playerLayer.backgroundColor = nil;
        [strongSelf->_paintingWrapperView insertSubview:strongSelf->_videoView atIndex:0];
        
        [strongSelf->_player play];
        
        [strongSelf updateLayout:strongSelf.interfaceOrientation];
    }]];
}

- (void)_setupPlaybackStartedObserver
{
    CMTime startTime = CMTimeMake(10, 100);
    if (_photoEditor.trimStartValue > DBL_EPSILON)
        startTime = CMTimeMakeWithSeconds(_photoEditor.trimStartValue + 0.1, NSEC_PER_SEC);
    
    __weak TGPhotoPaintController *weakSelf = self;
    _playerStartedObserver = [_player addBoundaryTimeObserverForTimes:@[[NSValue valueWithCMTime:startTime]] queue:NULL usingBlock:^
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
    
        [strongSelf->_player removeTimeObserver:strongSelf->_playerStartedObserver];
        strongSelf->_playerStartedObserver = nil;
        
        if (CMTimeGetSeconds(strongSelf->_player.currentItem.duration) > 0)
            [strongSelf _setupPlaybackReachedEndObserver];
    }];
}

- (void)_setupPlaybackReachedEndObserver
{
    CMTime endTime = CMTimeSubtract(_player.currentItem.duration, CMTimeMake(10, 100));
    if (_photoEditor.trimEndValue > DBL_EPSILON && _photoEditor.trimEndValue < CMTimeGetSeconds(_player.currentItem.duration))
        endTime = CMTimeMakeWithSeconds(_photoEditor.trimEndValue - 0.1, NSEC_PER_SEC);
    
    CMTime startTime = CMTimeMake(5, 100);
    if (_photoEditor.trimStartValue > DBL_EPSILON)
        startTime = CMTimeMakeWithSeconds(_photoEditor.trimStartValue + 0.05, NSEC_PER_SEC);
    
    __weak TGPhotoPaintController *weakSelf = self;
    _playerReachedEndObserver = [_player addBoundaryTimeObserverForTimes:@[[NSValue valueWithCMTime:endTime]] queue:NULL usingBlock:^
    {
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf != nil)
            [strongSelf->_player seekToTime:startTime];
    }];
}

#pragma mark - Face Detection

- (void)_setStickerEntityPosition:(TGPhotoPaintStickerEntity *)entity
{
    TGDocumentMediaAttachment *document = entity.document;
    TGDocumentAttributeSticker *sticker = nil;
    for (id attribute in document.attributes)
    {
        if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]])
        {
            sticker = (TGDocumentAttributeSticker *)attribute;
            break;
        }
    }
    
    TGPhotoMaskPosition *position = [self _positionForMask:sticker documentId:document.documentId];
    if (position != nil)
    {
        entity.position = position.center;
        entity.angle = position.angle;
        entity.scale = position.scale;
    }
    else
    {
        entity.position = [self startPositionRelativeToEntity:nil];
        entity.angle = [self startRotation];
    }
}

- (TGPhotoMaskPosition *)_positionForMask:(TGDocumentAttributeSticker *)sticker documentId:(int64_t)documentId
{
    if (sticker.mask == nil)
        return nil;
    
    TGPhotoMaskAnchor anchor = [TGPhotoMaskPosition anchorOfMask:sticker.mask];
    if (anchor == TGPhotoMaskAnchorNone)
        return nil;
    
    TGPaintFace *face = [self _randomFaceWithVacantAnchor:anchor documentId:documentId];
    if (face == nil)
        return nil;
    
    CGPoint referencePoint = CGPointZero;
    CGFloat referenceWidth = 0.0f;
    CGFloat angle = 0.0f;
    CGSize baseSize = [self _stickerBaseSizeForCurrentPainting];
    CGRect faceBounds = [TGPaintFaceUtils transposeRect:face.bounds paintingSize:_painting.size originalSize:_photoEditor.originalSize];
    
    switch (anchor)
    {
        case TGPhotoMaskAnchorForehead:
        {
            referencePoint = [TGPaintFaceUtils transposePoint:[face foreheadPoint] paintingSize:_painting.size originalSize:_photoEditor.originalSize];
            referenceWidth = faceBounds.size.width;
            angle = face.angle;
        }
            break;
            
        case TGPhotoMaskAnchorEyes:
        {
            CGPoint point = [face eyesCenterPointAndDistance:&referenceWidth];
            referenceWidth = [TGPaintFaceUtils transposeWidth:referenceWidth paintingSize:_painting.size originalSize:_photoEditor.originalSize];
            referencePoint = [TGPaintFaceUtils transposePoint:point paintingSize:_painting.size originalSize:_photoEditor.originalSize];
            angle = [face eyesAngle];
        }
            break;
            
        case TGPhotoMaskAnchorMouth:
        {
            referencePoint = [TGPaintFaceUtils transposePoint:[face mouthPoint] paintingSize:_painting.size originalSize:_photoEditor.originalSize];
            referenceWidth = faceBounds.size.width;
            angle = face.angle;
        }
            break;
            
        case TGPhotoMaskAnchorChin:
        {
            referencePoint = [TGPaintFaceUtils transposePoint:[face chinPoint] paintingSize:_painting.size originalSize:_photoEditor.originalSize];
            referenceWidth = faceBounds.size.width;
            angle = face.angle;
        }
            break;
            
        default:
            break;
    }
    
    CGFloat scale = referenceWidth / baseSize.width * sticker.mask.zoom;
    
    CGPoint xComp = CGPointMake(sin(M_PI_2 - angle) * referenceWidth * sticker.mask.point.x,
                                cos(M_PI_2 - angle) * referenceWidth * sticker.mask.point.x);
    CGPoint yComp = CGPointMake(cos(M_PI_2 + angle) * referenceWidth * sticker.mask.point.y,
                                sin(M_PI_2 + angle) * referenceWidth * sticker.mask.point.y);
    
    CGPoint position = CGPointMake(referencePoint.x + xComp.x + yComp.x, referencePoint.y + xComp.y + yComp.y);
    
    return [TGPhotoMaskPosition maskPositionWithCenter:position scale:scale angle:angle];
}

- (TGPaintFace *)_randomFaceWithVacantAnchor:(TGPhotoMaskAnchor)anchor documentId:(int64_t)documentId
{
    NSInteger randomIndex = (NSInteger)arc4random_uniform((uint32_t)_faces.count);
    NSInteger count = _faces.count;
    NSInteger remaining = _faces.count;
    
    for (NSInteger i = randomIndex; remaining > 0; (i = (i + 1) % count), remaining--)
    {
        TGPaintFace *face = _faces[i];
        if (![self _isFaceAnchorOccupied:face anchor:anchor documentId:documentId])
            return face;
    }

    return nil;
}

- (bool)_isFaceAnchorOccupied:(TGPaintFace *)face anchor:(TGPhotoMaskAnchor)anchor documentId:(int64_t)documentId
{
    CGPoint anchorPoint = CGPointZero;
    switch (anchor)
    {
        case TGPhotoMaskAnchorForehead:
        {
            anchorPoint = [TGPaintFaceUtils transposePoint:[face foreheadPoint] paintingSize:_painting.size originalSize:_photoEditor.originalSize];
        }
            break;
            
        case TGPhotoMaskAnchorEyes:
        {
            anchorPoint = [TGPaintFaceUtils transposePoint:[face eyesCenterPointAndDistance:NULL] paintingSize:_painting.size originalSize:_photoEditor.originalSize];
        }
            break;
            
        case TGPhotoMaskAnchorMouth:
        {
            anchorPoint = [TGPaintFaceUtils transposePoint:[face mouthPoint] paintingSize:_painting.size originalSize:_photoEditor.originalSize];
        }
            break;
            
        case TGPhotoMaskAnchorChin:
        {
            anchorPoint = [TGPaintFaceUtils transposePoint:[face chinPoint] paintingSize:_painting.size originalSize:_photoEditor.originalSize];
        }
            break;
            
        default:
        {
            
        }
            break;
    }
    
    CGRect faceBounds = [TGPaintFaceUtils transposeRect:face.bounds paintingSize:_painting.size originalSize:_photoEditor.originalSize];
    CGFloat minDistance = faceBounds.size.width * 1.1;
    
    for (TGPhotoStickerEntityView *view in _entitiesContainerView.subviews)
    {
        if (![view isKindOfClass:[TGPhotoStickerEntityView class]])
            continue;
        
        TGPhotoPaintStickerEntity *entity = view.entity;
        TGDocumentMediaAttachment *document = entity.document;
        TGDocumentAttributeSticker *sticker = nil;
        for (id attribute in document.attributes)
        {
            if ([attribute isKindOfClass:[TGDocumentAttributeSticker class]])
            {
                sticker = (TGDocumentAttributeSticker *)attribute;
                break;
            }
        }
    
        if ([TGPhotoMaskPosition anchorOfMask:sticker.mask] != anchor)
            continue;
        
        if ((documentId == document.documentId || _faces.count > 1) && TGPaintDistance(entity.position, anchorPoint) < minDistance)
            return true;
    }
    
    return false;
}

- (void)performFaceDetection
{
    TGPhotoEditorController *editorController = (TGPhotoEditorController *)self.parentViewController;
    if (![editorController isKindOfClass:[TGPhotoEditorController class]])
        return;
    
    if (self.intent == TGPhotoEditorControllerVideoIntent)
        return;

    if (_faceDetectorDisposable == nil)
        _faceDetectorDisposable = [[SMetaDisposable alloc] init];
    
    id<TGMediaEditableItem> item = self.item;
    CGSize originalSize = _photoEditor.originalSize;
    
    if (editorController.requestOriginalScreenSizeImage == nil)
        return;
    
    SSignal *cachedSignal = [[editorController.editingContext facesForItem:item] mapToSignal:^SSignal *(id result)
    {
        if (result == nil)
            return [SSignal fail:nil];
        return [SSignal single:result];
    }];
    SSignal *imageSignal = [editorController.requestOriginalScreenSizeImage(item, 0) take:1];
    SSignal *detectSignal = [[imageSignal filter:^bool(UIImage *image)
    {
        if (![image isKindOfClass:[UIImage class]])
            return false;
        
        if (image.degraded)
            return false;
        
        return true;
    }] mapToSignal:^SSignal *(UIImage *image) {
        return [[TGPaintFaceDetector detectFacesInImage:image originalSize:originalSize] startOn:[SQueue concurrentDefaultQueue]];
    }];
    
    __weak TGPhotoPaintController *weakSelf = self;
    [_faceDetectorDisposable setDisposable:[[[cachedSignal catch:^SSignal *(__unused id error)
    {
        return detectSignal;
    }] deliverOn:[SQueue mainQueue]] startWithNext:^(NSArray *next)
    {
        [editorController.editingContext setFaces:next forItem:item];
     
        if (next.count == 0)
            return;
        
        __strong TGPhotoPaintController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_faces = next;
    }]];
}

- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures
{
    return UIRectEdgeTop | UIRectEdgeBottom;
}

@end
