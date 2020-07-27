#import "PGPhotoSkinPass.h"
#import "YUGPUImageHighPassSkinSmoothingFilter.h"

@implementation PGPhotoSkinPass

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        YUGPUImageHighPassSkinSmoothingFilter *filter = [[YUGPUImageHighPassSkinSmoothingFilter alloc] init];
        _filter = filter;
    }
    return self;
}

- (void)setIntensity:(CGFloat)intensity
{
    _intensity = intensity;
    [self updateParameters];
}

- (void)updateParameters
{
    [(YUGPUImageHighPassSkinSmoothingFilter *)_filter setAmount:0.75 * _intensity];
}

- (void)invalidate
{

}

@end
