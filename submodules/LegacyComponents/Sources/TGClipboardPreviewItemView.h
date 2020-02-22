#import <LegacyComponents/LegacyComponents.h>

@class TGMediaSelectionContext;
@class TGMediaEditingContext;
@class TGSuggestionContext;

@interface TGClipboardPreviewItemView : TGMenuSheetItemView

@property (nonatomic, weak) TGViewController *parentController;

@property (nonatomic, assign) bool allowCaptions;
@property (nonatomic, assign) bool hasTimer;
@property (nonatomic, strong) NSString *recipientName;

@property (nonatomic, readonly) TGMediaSelectionContext *selectionContext;
@property (nonatomic, readonly) TGMediaEditingContext *editingContext;
@property (nonatomic, strong) TGSuggestionContext *suggestionContext;

@property (nonatomic, copy) void (^selectionChanged)(NSUInteger);
@property (nonatomic, copy) void (^sendPressed)(UIImage *currentItem);

- (instancetype)initWithContext:(id<LegacyComponentsContext>)context images:(NSArray *)images;

- (void)setCollapsed:(bool)collapsed animated:(bool)animated;

@end
