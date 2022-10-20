#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class TGStickerMaskDescription;

typedef enum
{
    TGPhotoMaskAnchorNone,
    TGPhotoMaskAnchorForehead,
    TGPhotoMaskAnchorEyes,
    TGPhotoMaskAnchorMouth,
    TGPhotoMaskAnchorChin
} TGPhotoMaskAnchor;

@interface TGPhotoMaskPosition : NSObject

@property (nonatomic, readonly) CGPoint center;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) CGFloat angle;

+ (instancetype)maskPositionWithCenter:(CGPoint)center scale:(CGFloat)scale angle:(CGFloat)angle;

+ (TGPhotoMaskAnchor)anchorOfMask:(TGStickerMaskDescription *)mask;

@end
