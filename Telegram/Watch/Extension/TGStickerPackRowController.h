#import "WKInterfaceTable+TGDataDrivenTable.h"

@class TGBridgeStickerPack;

@interface TGStickerPackRowController : TGTableRowController

@property (nonatomic, weak) IBOutlet WKInterfaceImage *image;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *nameLabel;
@property (nonatomic, weak) IBOutlet WKInterfaceLabel *countLabel;

- (void)updateWithStickerPack:(TGBridgeStickerPack *)stickerPack;

@end
