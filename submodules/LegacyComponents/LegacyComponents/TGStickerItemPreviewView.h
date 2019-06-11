#import <LegacyComponents/TGItemMenuSheetPreviewView.h>

@class TGDocumentMediaAttachment;
@class TGStickerPack;

@interface TGStickerItemPreviewView : TGItemMenuSheetPreviewView

@property (nonatomic, readonly) TGStickerPack *stickerPack;
@property (nonatomic, readonly) bool recent;
@property (nonatomic, readonly) CFAbsoluteTime lastFeedbackTime;

- (void)setSticker:(TGDocumentMediaAttachment *)sticker stickerPack:(TGStickerPack *)stickerPack recent:(bool)recent;
- (void)setSticker:(TGDocumentMediaAttachment *)sticker associations:(NSArray *)associations;

- (void)presentActions;

@end
