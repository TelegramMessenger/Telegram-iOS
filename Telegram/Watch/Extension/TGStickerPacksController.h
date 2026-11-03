#import "TGInterfaceController.h"

@class TGBridgeStickerPack;

@interface TGStickerPacksControllerContext : NSObject <TGInterfaceContext>

@property (nonatomic, readonly) NSArray *stickerPacks;
@property (nonatomic, copy) void (^completionBlock)(TGBridgeStickerPack *stickerPack);

- (instancetype)initWithStickerPacks:(NSArray *)stickerPacks;

@end

@interface TGStickerPacksController : TGInterfaceController

@property (nonatomic, weak) IBOutlet WKInterfaceTable *table;
@property (nonatomic, weak) IBOutlet WKInterfaceImage *activityIndicator;

@end
