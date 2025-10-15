#import "PGPhotoProcessPass.h"

typedef enum
{
    PGBlurToolTypeNone,
    PGBlurToolTypeRadial,
    PGBlurToolTypeLinear,
    PGBlurToolTypePortrait
} PGBlurToolType;

@interface PGPhotoBlurPass : PGPhotoProcessPass

@property (nonatomic, assign) PGBlurToolType type;
@property (nonatomic, assign) CGFloat size;
@property (nonatomic, assign) CGFloat falloff;
@property (nonatomic, assign) CGPoint point;
@property (nonatomic, assign) CGFloat angle;

@end
