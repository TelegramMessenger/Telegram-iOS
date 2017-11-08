#import <LegacyComponents/TGModernGalleryController.h>
#import <LegacyComponents/TGMenuSheetItemView.h>
#import <LegacyComponents/TGMediaAsset.h>

@class TGMediaSelectionContext;
@class TGMediaEditingContext;
@class TGSuggestionContext;
@class TGViewController;
@class TGAttachmentCameraView;
@protocol TGModernGalleryTransitionHostScrollView;

@interface TGAttachmentCarouselCollectionView : UICollectionView

@end

@interface TGAttachmentCarouselItemView : TGMenuSheetItemView <TGModernGalleryTransitionHostScrollView>

@property (nonatomic, weak) TGViewController *parentController;

@property (nonatomic, readonly) TGMediaSelectionContext *selectionContext;
@property (nonatomic, readonly) TGMediaEditingContext *editingContext;
@property (nonatomic, strong) TGSuggestionContext *suggestionContext;
@property (nonatomic) bool allowCaptions;
@property (nonatomic) bool inhibitDocumentCaptions;
@property (nonatomic) bool hasTimer;

@property (nonatomic, strong) NSArray *underlyingViews;
@property (nonatomic, assign) bool openEditor;

@property (nonatomic, copy) void (^cameraPressed)(TGAttachmentCameraView *cameraView);
@property (nonatomic, copy) void (^sendPressed)(TGMediaAsset *currentItem, bool asFiles);
@property (nonatomic, copy) void (^avatarCompletionBlock)(UIImage *image);

@property (nonatomic, copy) void (^editorOpened)(void);
@property (nonatomic, copy) void (^editorClosed)(void);

@property (nonatomic, assign) CGFloat remainingHeight;
@property (nonatomic, assign) bool condensed;

@property (nonatomic, strong) NSString *recipientName;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context camera:(bool)hasCamera selfPortrait:(bool)selfPortrait forProfilePhoto:(bool)forProfilePhoto assetType:(TGMediaAssetType)assetType saveEditedPhotos:(bool)saveEditedPhotos allowGrouping:(bool)allowGrouping;

@end
