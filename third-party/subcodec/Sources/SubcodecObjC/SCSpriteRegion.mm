// Sources/SubcodecObjC/SCSpriteRegion.mm
#import "SCSpriteRegion.h"

@implementation SCSpriteRegion

- (instancetype)initWithSlot:(int)slot
                   colorRect:(CGRect)colorRect
                   alphaRect:(CGRect)alphaRect {
    self = [super init];
    if (self) {
        _slot = slot;
        _colorRect = colorRect;
        _alphaRect = alphaRect;
    }
    return self;
}

@end
