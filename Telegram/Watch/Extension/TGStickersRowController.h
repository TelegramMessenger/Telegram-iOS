#import "WKInterfaceTable+TGDataDrivenTable.h"

@class TGBridgeDocumentMediaAttachment;

@interface TGStickersRowController : TGTableRowController

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *leftStickerImageGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceGroup *rightStickerImageGroup;

- (IBAction)leftStickerPressedAction;
- (IBAction)rightStickerPressedAction;

@property (nonatomic, copy) void (^leftStickerPressed)(void);
@property (nonatomic, copy) void (^rightStickerPressed)(void);

- (void)updateWithLeftSticker:(TGBridgeDocumentMediaAttachment *)leftSticker rightSticker:(TGBridgeDocumentMediaAttachment *)rightSticker;

@end
