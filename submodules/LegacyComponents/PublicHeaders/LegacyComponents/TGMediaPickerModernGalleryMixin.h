#import <Foundation/Foundation.h>
#import <LegacyComponents/TGMediaPickerGalleryModel.h>
#import <LegacyComponents/TGModernGalleryController.h>

#import <LegacyComponents/LegacyComponentsContext.h>

@class TGMediaSelectionContext;
@class TGMediaEditingContext;
@class TGMediaPickerGalleryItem;
@class TGMediaAssetFetchResult;
@class TGMediaAssetMomentList;

@protocol TGPhotoPaintStickersContext;

@interface TGMediaPickerModernGalleryMixin : NSObject

@property (nonatomic, weak, readonly) TGMediaPickerGalleryModel *galleryModel;

@property (nonatomic, copy) void (^itemFocused)(TGMediaPickerGalleryItem *);

@property (nonatomic, copy) void (^willTransitionIn)();
@property (nonatomic, copy) void (^willTransitionOut)();
@property (nonatomic, copy) void (^didTransitionOut)();
@property (nonatomic, copy) UIView *(^referenceViewForItem)(TGMediaPickerGalleryItem *);

@property (nonatomic, copy) void (^completeWithItem)(TGMediaPickerGalleryItem *item, bool silentPosting, int32_t scheduleTime);

@property (nonatomic, copy) void (^editorOpened)(void);
@property (nonatomic, copy) void (^editorClosed)(void);

@property (nonatomic, copy) void (^presentScheduleController)(bool, void (^)(int32_t));
@property (nonatomic, copy) void (^presentTimerController)(void (^)(int32_t));

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context item:(id)item fetchResult:(TGMediaAssetFetchResult *)fetchResult parentController:(TGViewController *)parentController thumbnailImage:(UIImage *)thumbnailImage selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext hasCaptions:(bool)hasCaptions allowCaptionEntities:(bool)allowCaptionEntities hasTimer:(bool)hasTimer onlyCrop:(bool)onlyCrop inhibitDocumentCaptions:(bool)inhibitDocumentCaptions inhibitMute:(bool)inhibitMute asFile:(bool)asFile itemsLimit:(NSUInteger)itemsLimit recipientName:(NSString *)recipientName hasSilentPosting:(bool)hasSilentPosting hasSchedule:(bool)hasSchedule reminder:(bool)reminder stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context item:(id)item momentList:(TGMediaAssetMomentList *)momentList parentController:(TGViewController *)parentController thumbnailImage:(UIImage *)thumbnailImage selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext hasCaptions:(bool)hasCaptions allowCaptionEntities:(bool)allowCaptionEntities hasTimer:(bool)hasTimer onlyCrop:(bool)onlyCrop inhibitDocumentCaptions:(bool)inhibitDocumentCaptions inhibitMute:(bool)inhibitMute asFile:(bool)asFile itemsLimit:(NSUInteger)itemsLimit hasSilentPosting:(bool)hasSilentPosting hasSchedule:(bool)hasSchedule reminder:(bool)reminder stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext;

- (void)present;
- (void)updateWithFetchResult:(TGMediaAssetFetchResult *)fetchResult;

- (UIView *)currentReferenceView;

- (void)setThumbnailSignalForItem:(SSignal *(^)(id))thumbnailSignalForItem;

- (UIViewController *)galleryController;
- (void)setPreviewMode;

@end
