#import "TGMediaAssetsPhotoCell.h"

NSString *const TGMediaAssetsPhotoCellKind = @"TGMediaAssetsPhotoCellKind";

@implementation TGMediaAssetsPhotoCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        self.accessibilityLabel = @"Photo";
    }
    return self;
}

@end
