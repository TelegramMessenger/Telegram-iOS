#import <LegacyComponents/TGModernGalleryModel.h>

#import <LegacyComponents/TGMediaPickerGalleryInterfaceView.h>
#import <LegacyComponents/TGModernGalleryController.h>

#import <LegacyComponents/TGPhotoEditorController.h>

#import <LegacyComponents/LegacyComponentsContext.h>

@interface TGClipboardGalleryModel : TGModernGalleryModel

@property (nonatomic, copy) void (^willFinishEditingItem)(id<TGMediaEditableItem> item, id<TGMediaEditAdjustments> adjustments, id temporaryRep, bool hasChanges);
@property (nonatomic, copy) void (^didFinishEditingItem)(id<TGMediaEditableItem>item, id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, UIImage *thumbnailImage);
@property (nonatomic, copy) void (^didFinishRenderingFullSizeImage)(id<TGMediaEditableItem> item, UIImage *fullSizeImage);

@property (nonatomic, copy) void (^saveItemCaption)(id<TGMediaEditableItem> item, NSAttributedString *caption);

@property (nonatomic, copy) void (^editorOpened)(void);
@property (nonatomic, copy) void (^editorClosed)(void);

@property (nonatomic, weak) TGModernGalleryController *controller;

@property (nonatomic, readonly, strong) TGMediaPickerGalleryInterfaceView *interfaceView;
@property (nonatomic, readonly, strong) TGMediaPickerGallerySelectedItemsModel *selectedItemsModel;

@property (nonatomic, readonly) TGMediaSelectionContext *selectionContext;
@property (nonatomic, strong) id<TGPhotoPaintStickersContext> stickersContext;

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context images:(NSArray *)images focusIndex:(NSUInteger)focusIndex selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext stickersContext:(id<TGPhotoPaintStickersContext>)stickersContext hasCaptions:(bool)hasCaptions hasTimer:(bool)hasTimer hasSelectionPanel:(bool)hasSelectionPanel recipientName:(NSString *)recipientName;

@end
