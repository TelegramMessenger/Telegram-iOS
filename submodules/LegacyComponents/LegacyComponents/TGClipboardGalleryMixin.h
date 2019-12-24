#import <Foundation/Foundation.h>
#import <LegacyComponents/TGModernGalleryController.h>

#import <LegacyComponents/LegacyComponentsContext.h>

@class TGClipboardGalleryPhotoItem;

@interface TGClipboardGalleryMixin : NSObject

@property (nonatomic, copy) void (^itemFocused)(TGClipboardGalleryPhotoItem *);

@property (nonatomic, copy) void (^willTransitionIn)();
@property (nonatomic, copy) void (^willTransitionOut)();
@property (nonatomic, copy) void (^didTransitionOut)();
@property (nonatomic, copy) UIView *(^referenceViewForItem)(TGClipboardGalleryPhotoItem *);

@property (nonatomic, copy) void (^completeWithItem)(TGClipboardGalleryPhotoItem *item);

@property (nonatomic, copy) void (^editorOpened)(void);
@property (nonatomic, copy) void (^editorClosed)(void);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context image:(UIImage *)image images:(NSArray *)images parentController:(TGViewController *)parentController thumbnailImage:(UIImage *)thumbnailImage selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext suggestionContext:(TGSuggestionContext *)suggestionContext hasCaptions:(bool)hasCaptions hasTimer:(bool)hasTimer recipientName:(NSString *)recipientName;

- (void)present;

@end
