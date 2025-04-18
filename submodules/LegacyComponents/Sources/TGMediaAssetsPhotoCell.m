#import "TGMediaAssetsPhotoCell.h"

#import <LegacyComponents/TGMediaAsset.h>

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

- (void)setItem:(NSObject *)item signal:(SSignal *)signal
{
    [super setItem:item signal:signal];
    
    TGMediaAsset *asset = (TGMediaAsset *)item;
    if (![asset isKindOfClass:[TGMediaAsset class]])
        return;
    
    self.typeIconView.image = asset.isFavorite ? TGComponentsImageNamed(@"MediaGroupFavorites") : nil;
}

@end
