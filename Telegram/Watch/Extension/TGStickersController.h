#import "TGInterfaceController.h"

@class TGBridgeContext;
@class TGBridgeStickerPack;
@class TGBridgeDocumentMediaAttachment;

@interface TGStickersControllerContext : NSObject <TGInterfaceContext>

@property (nonatomic, copy) void (^completionBlock)(TGBridgeDocumentMediaAttachment *sticker);

@end

@interface TGStickersController : TGInterfaceController

@property (nonatomic, weak) IBOutlet WKInterfaceTable *table;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *activityIndicator;

@property (nonatomic, weak) IBOutlet WKInterfaceGroup *alertGroup;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *alertLabel;

@end
