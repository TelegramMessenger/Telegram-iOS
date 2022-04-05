#import <LegacyComponents/TGModernGalleryController.h>
#import <LegacyComponents/TGMenuSheetItemView.h>
#import <LegacyComponents/TGMediaAsset.h>

#import <LegacyComponents/TGMediaAssetsUtils.h>

@class TGMediaSelectionContext;
@class TGMediaEditingContext;
@class TGViewController;
@class TGAttachmentCameraView;
@class TGVideoEditAdjustments;
@protocol TGPhotoPaintStickersContext;

@interface TGAttachmentCarouselCollectionView : UICollectionView

@end

@interface TGAttachmentCarouselItemView : TGMenuSheetItemView

@property (nonatomic, weak) TGViewController *parentController;

@property (nonatomic, readonly) TGMediaSelectionContext *selectionContext;
@property (nonatomic, readonly) TGMediaEditingContext *editingContext;
@property (nonatomic, strong) id<TGPhotoPaintStickersContext> stickersContext;
@property (nonatomic) bool allowCaptions;
@property (nonatomic) bool allowCaptionEntities;
@property (nonatomic) bool inhibitDocumentCaptions;
@property (nonatomic) bool hasTimer;
@property (nonatomic) bool onlyCrop;
@property (nonatomic) bool asFile;
@property (nonatomic) bool inhibitMute;
@property (nonatomic) bool disableStickers;
@property (nonatomic) bool hasSilentPosting;
@property (nonatomic) bool hasSchedule;
@property (nonatomic) bool reminder;
@property (nonatomic, copy) void (^presentScheduleController)(bool, void (^)(int32_t));
@property (nonatomic, copy) void (^presentTimerController)(void (^)(int32_t));

@property (nonatomic, strong) NSArray *underlyingViews;
@property (nonatomic, assign) bool openEditor;

@property (nonatomic, copy) void (^cameraPressed)(TGAttachmentCameraView *cameraView);
@property (nonatomic, copy) void (^sendPressed)(TGMediaAsset *currentItem, bool asFiles, bool silentPosting, int32_t scheduleTime, bool isFromPicker);
@property (nonatomic, copy) void (^avatarCompletionBlock)(UIImage *image);
@property (nonatomic, copy) void (^avatarVideoCompletionBlock)(UIImage *image, id asset, TGVideoEditAdjustments *adjustments);

@property (nonatomic, copy) void (^editorOpened)(void);
@property (nonatomic, copy) void (^editorClosed)(void);

@property (nonatomic, copy) void (^selectionLimitExceeded)(void);

@property (nonatomic, assign) CGFloat remainingHeight;
@property (nonatomic, assign) bool condensed;
@property (nonatomic, assign) bool collapsed;

@property (nonatomic, strong) NSString *recipientName;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context camera:(bool)hasCamera selfPortrait:(bool)selfPortrait forProfilePhoto:(bool)forProfilePhoto assetType:(TGMediaAssetType)assetType saveEditedPhotos:(bool)saveEditedPhotos allowGrouping:(bool)allowGrouping;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context camera:(bool)hasCamera selfPortrait:(bool)selfPortrait forProfilePhoto:(bool)forProfilePhoto assetType:(TGMediaAssetType)assetType saveEditedPhotos:(bool)saveEditedPhotos allowGrouping:(bool)allowGrouping allowSelection:(bool)allowSelection allowEditing:(bool)allowEditing document:(bool)document selectionLimit:(int)selectionLimit;

- (void)saveStartImage;
- (UIView *)getItemSnapshot:(NSString *)uniqueId;

@end
