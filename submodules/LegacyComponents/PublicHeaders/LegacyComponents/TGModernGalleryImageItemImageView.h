#import <LegacyComponents/TGImageView.h>

@interface TGModernGalleryImageItemImageView : TGImageView

@property (nonatomic) bool isPartial;

@property (nonatomic, copy) void (^progressChanged)(CGFloat);
@property (nonatomic, copy) void (^availabilityStateChanged)(bool);

- (bool)isAvailableNow;

@end
