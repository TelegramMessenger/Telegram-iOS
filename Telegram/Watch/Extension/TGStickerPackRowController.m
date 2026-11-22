#import "TGStickerPackRowController.h"
#import "TGWatchCommon.h"
#import "TGStringUtils.h"

#import "TGBridgeStickerPack.h"

#import "WKInterfaceImage+Signals.h"
#import "TGBridgeMediaSignals.h"

NSString *const TGStickerPackRowIdentifier = @"TGStickerPackRow";

@implementation TGStickerPackRowController

- (void)updateWithStickerPack:(TGBridgeStickerPack *)stickerPack
{
    [self.image setSignal:[TGBridgeMediaSignals stickerWithDocumentId:0 packId:0 accessHash:0 type:TGMediaStickerImageTypeList] isVisible:self.isVisible];
    self.nameLabel.text = stickerPack.title;
    self.countLabel.text = [[NSString alloc] initWithFormat:TGLocalized([TGStringUtils integerValueFormat:@"StickerPack.StickerCount_" value:stickerPack.documents.count]), [[NSString alloc] initWithFormat:@"%d", (int)stickerPack.documents.count]];
}

- (void)notifyVisiblityChange
{
    [self.image updateIfNeeded];
}

+ (NSString *)identifier
{
    return TGStickerPackRowIdentifier;
}

@end
