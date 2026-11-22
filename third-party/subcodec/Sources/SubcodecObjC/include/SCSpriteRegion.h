// Sources/SubcodecObjC/include/SCSpriteRegion.h
#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCSpriteRegion : NSObject

@property (nonatomic, readonly) int slot;
@property (nonatomic, readonly) CGRect colorRect;
@property (nonatomic, readonly) CGRect alphaRect;

- (instancetype)initWithSlot:(int)slot
                   colorRect:(CGRect)colorRect
                   alphaRect:(CGRect)alphaRect;

@end

NS_ASSUME_NONNULL_END
