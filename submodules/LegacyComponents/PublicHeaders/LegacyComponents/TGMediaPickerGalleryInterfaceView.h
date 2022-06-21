#import <LegacyComponents/TGModernGalleryInterfaceView.h>
#import <LegacyComponents/TGModernGalleryItem.h>

#import <LegacyComponents/TGPhotoToolbarView.h>

#import <LegacyComponents/LegacyComponentsContext.h>

@protocol TGPhotoPaintStickersContext;
@class TGMediaSelectionContext;
@class TGMediaEditingContext;
@class TGMediaPickerGallerySelectedItemsModel;

@interface TGMediaPickerGalleryInterfaceView : UIView <TGModernGalleryInterfaceView>

@property (nonatomic, copy) void (^captionSet)(id<TGModernGalleryItem>, NSAttributedString *);
@property (nonatomic, copy) void (^donePressed)(id<TGModernGalleryItem>);
@property (nonatomic, copy) void (^doneLongPressed)(id<TGModernGalleryItem>);

@property (nonatomic, copy) void (^photoStripItemSelected)(NSInteger index);

@property (nonatomic, copy) void (^timerRequested)(void);

@property (nonatomic, assign) bool hasCaptions;
@property (nonatomic, assign) bool allowCaptionEntities;
@property (nonatomic, assign) bool hasTimer;
@property (nonatomic, assign) bool onlyCrop;
@property (nonatomic, assign) bool inhibitDocumentCaptions;
@property (nonatomic, assign) bool usesSimpleLayout;
@property (nonatomic, assign) bool hasSwipeGesture;
@property (nonatomic, assign) bool usesFadeOutForDismissal;
@property (nonatomic, assign) bool inhibitMute;

@property (nonatomic, assign) bool capturing;

@property (nonatomic, readonly) TGPhotoEditorTab currentTabs;
@property (nonatomic, readonly) CGRect doneButtonFrame;

@property (nonatomic, readonly) UIView *timerButton;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context focusItem:(id<TGModernGalleryItem>)focusItem selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext hasSelectionPanel:(bool)hasSelectionPanel hasCameraButton:(bool)hasCameraButton recipientName:(NSString *)recipientName;

- (void)setSelectedItemsModel:(TGMediaPickerGallerySelectedItemsModel *)selectedItemsModel;
- (void)setEditorTabPressed:(void (^)(TGPhotoEditorTab tab))editorTabPressed;

- (void)setThumbnailSignalForItem:(SSignal *(^)(id))thumbnailSignalForItem;

- (void)updateSelectionInterface:(NSUInteger)selectedCount counterVisible:(bool)counterVisible animated:(bool)animated;
- (void)updateSelectedPhotosView:(bool)reload incremental:(bool)incremental add:(bool)add index:(NSInteger)index;
- (void)setSelectionInterfaceHidden:(bool)hidden animated:(bool)animated;
- (void)setAllInterfaceHidden:(bool)hidden delay:(NSTimeInterval)__unused delay animated:(bool)animated;
- (void)setToolbarsHidden:(bool)hidden animated:(bool)animated;

- (void)immediateEditorTransitionIn;
- (void)editorTransitionIn;
- (void)editorTransitionOut;

- (void)setTabBarUserInteractionEnabled:(bool)enabled;

@end
