#import "TGStickersHeaderController.h"
#import "TGWatchCommon.h"

NSString *const TGStickersHeaderIdentifier = @"TGStickersHeader";

@implementation TGStickersHeaderController

- (void)update
{
    self.nameLabel.text = TGLocalized(@"Watch.Stickers.StickerPacks");
}

+ (NSString *)identifier
{
    return TGStickersHeaderIdentifier;
}

@end
