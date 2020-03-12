#import "TGMediaAssetsPhotoCell.h"

#import "LegacyComponentsInternal.h"

NSString *const TGMediaAssetsPhotoCellKind = @"TGMediaAssetsPhotoCellKind";

@implementation TGMediaAssetsPhotoCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.accessibilityLabel = TGLocalized(@"Message.Photo");
    }
    return self;
}

@end
