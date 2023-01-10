#import <LegacyComponents/TGNavigationController.h>
#import <LegacyComponents/LegacyComponentsContext.h>

#import <LegacyComponents/TGMediaAssetsLibrary.h>

#import <LegacyComponents/TGMediaAssetsUtils.h>

@class TGMediaAssetsPickerController;
@class TGViewController;
@class TGVideoEditAdjustments;

@protocol TGPhotoPaintStickersContext;

typedef enum
{
    TGMediaAssetsControllerSendMediaIntent,
    TGMediaAssetsControllerSendFileIntent,
    TGMediaAssetsControllerSetProfilePhotoIntent,
    TGMediaAssetsControllerSetSignupProfilePhotoIntent,
    TGMediaAssetsControllerSetCustomWallpaperIntent,
    TGMediaAssetsControllerPassportIntent,
    TGMediaAssetsControllerPassportMultipleIntent
} TGMediaAssetsControllerIntent;

@interface TGMediaAssetsPallete : NSObject

@property (nonatomic, readonly) bool isDark;
@property (nonatomic, readonly) UIColor *backgroundColor;
@property (nonatomic, readonly) UIColor *selectionColor;
@property (nonatomic, readonly) UIColor *separatorColor;
@property (nonatomic, readonly) UIColor *textColor;
@property (nonatomic, readonly) UIColor *secondaryTextColor;
@property (nonatomic, readonly) UIColor *accentColor;
@property (nonatomic, readonly) UIColor *destructiveColor;
@property (nonatomic, readonly) UIColor *barBackgroundColor;
@property (nonatomic, readonly) UIColor *barSeparatorColor;
@property (nonatomic, readonly) UIColor *navigationTitleColor;
@property (nonatomic, readonly) UIImage *badge;
@property (nonatomic, readonly) UIColor *badgeTextColor;
@property (nonatomic, readonly) UIImage *sendIconImage;
@property (nonatomic, readonly) UIImage *doneIconImage;

@property (nonatomic, readonly) UIColor *maybeAccentColor;

+ (instancetype)palleteWithDark:(bool)dark backgroundColor:(UIColor *)backgroundColor selectionColor:(UIColor *)selectionColor separatorColor:(UIColor *)separatorColor textColor:(UIColor *)textColor secondaryTextColor:(UIColor *)secondaryTextColor accentColor:(UIColor *)accentColor destructiveColor:(UIColor *)destructiveColor barBackgroundColor:(UIColor *)barBackgroundColor barSeparatorColor:(UIColor *)barSeparatorColor navigationTitleColor:(UIColor *)navigationTitleColor badge:(UIImage *)badge badgeTextColor:(UIColor *)badgeTextColor sendIconImage:(UIImage *)sendIconImage doneIconImage:(UIImage *)doneIconImage maybeAccentColor:(UIColor *)maybeAccentColor;

@end

@interface TGMediaAssetsController : TGNavigationController

@property (nonatomic, strong) TGMediaAssetsPallete *pallete;

@property (nonatomic, readonly) TGMediaEditingContext *editingContext;
@property (nonatomic, readonly) TGMediaSelectionContext *selectionContext;
@property (nonatomic, strong) id<TGPhotoPaintStickersContext> stickersContext;
@property (nonatomic, assign) bool localMediaCacheEnabled;
@property (nonatomic, assign) bool captionsEnabled;
@property (nonatomic, assign) bool allowCaptionEntities;
@property (nonatomic, assign) bool inhibitDocumentCaptions;
@property (nonatomic, assign) bool shouldStoreAssets;
@property (nonatomic, assign) bool hasTimer;
@property (nonatomic, assign) bool onlyCrop;
@property (nonatomic, assign) bool inhibitMute;
@property (nonatomic, assign) bool hasSilentPosting;
@property (nonatomic, assign) bool hasSchedule;
@property (nonatomic, assign) bool reminder;
@property (nonatomic, copy) void (^presentScheduleController)(bool, void (^)(int32_t));
@property (nonatomic, copy) void (^presentTimerController)(void (^)(int32_t));

@property (nonatomic, assign) bool liveVideoUploadEnabled;
@property (nonatomic, assign) bool shouldShowFileTipIfNeeded;

@property (nonatomic, strong) NSString *recipientName;

@property (nonatomic, copy) NSDictionary *(^descriptionGenerator)(id, NSAttributedString *, NSString *, NSString *);
@property (nonatomic, copy) void (^avatarCompletionBlock)(UIImage *image);
@property (nonatomic, copy) void (^completionBlock)(NSArray *signals, bool silentPosting, int32_t scheduleTime);
@property (nonatomic, copy) void (^avatarVideoCompletionBlock)(UIImage *image, AVAsset *asset, TGVideoEditAdjustments *adjustments);
@property (nonatomic, copy) void (^singleCompletionBlock)(id<TGMediaEditableItem> item, TGMediaEditingContext *editingContext);
@property (nonatomic, copy) void (^dismissalBlock)(void);
@property (nonatomic, copy) void (^selectionBlock)(TGMediaAsset *asset, UIImage *);

@property (nonatomic, copy) void (^requestSearchController)(void);

@property (nonatomic, readonly) TGMediaAssetsPickerController *pickerController;
@property (nonatomic, readonly) bool allowGrouping;
@property (nonatomic, readonly) int selectionLimit;

@property (nonatomic, copy) void (^selectionLimitExceeded)(void);

- (UIBarButtonItem *)leftBarButtonItem;
- (UIBarButtonItem *)rightBarButtonItem;

- (void)send:(bool)silently;
- (void)schedule:(bool)schedule;

- (NSArray *)resultSignalsWithCurrentItem:(TGMediaAsset *)currentItem descriptionGenerator:(id (^)(id, NSAttributedString *, NSString *, NSString *))descriptionGenerator;

- (void)completeWithAvatarImage:(UIImage *)image;
- (void)completeWithAvatarVideo:(id)asset adjustments:(TGVideoEditAdjustments *)adjustments image:(UIImage *)image;
- (void)completeWithCurrentItem:(TGMediaAsset *)currentItem silentPosting:(bool)silentPosting scheduleTime:(int32_t)scheduleTime;

- (void)dismiss;

+ (instancetype)controllerWithContext:(id<LegacyComponentsContext>)context assetGroup:(TGMediaAssetGroup *)assetGroup intent:(TGMediaAssetsControllerIntent)intent recipientName:(NSString *)recipientName saveEditedPhotos:(bool)saveEditedPhotos allowGrouping:(bool)allowGrouping selectionLimit:(int)selectionLimit;
+ (instancetype)controllerWithContext:(id<LegacyComponentsContext>)context assetGroup:(TGMediaAssetGroup *)assetGroup intent:(TGMediaAssetsControllerIntent)intent recipientName:(NSString *)recipientName saveEditedPhotos:(bool)saveEditedPhotos allowGrouping:(bool)allowGrouping inhibitSelection:(bool)inhibitSelection selectionLimit:(int)selectionLimit;

+ (TGMediaAssetType)assetTypeForIntent:(TGMediaAssetsControllerIntent)intent;

+ (NSArray *)resultSignalsForSelectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext intent:(TGMediaAssetsControllerIntent)intent currentItem:(TGMediaAsset *)currentItem storeAssets:(bool)storeAssets convertToJpeg:(bool)convertToJpeg descriptionGenerator:(id (^)(id, NSAttributedString *, NSString *, NSString *))descriptionGenerator saveEditedPhotos:(bool)saveEditedPhotos;

+ (NSArray *)pasteboardResultSignalsForSelectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext intent:(TGMediaAssetsControllerIntent)intent currentItem:(id<TGMediaSelectableItem>)currentItem descriptionGenerator:(id (^)(id, NSAttributedString *, NSString *, NSString *))descriptionGenerator;

@end
