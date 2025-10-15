#import "TGStickersSectionHeaderController.h"
#import "TGWatchCommon.h"

NSString *const TGStickersSectionHeaderIdentifier = @"TGStickersSectionHeader";

@implementation TGStickersSectionHeaderController

- (NSString *)title
{
    return self.titleLabel.text;
}

- (void)setTitle:(NSString *)title
{
    self.titleLabel.text = title;
}

+ (NSString *)identifier
{
    return TGStickersSectionHeaderIdentifier;
}

@end
