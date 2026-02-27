#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFMpegAVCodec : NSObject

+ (FFMpegAVCodec * _Nullable)findForId:(int)codecId preferHardwareAccelerationCapable:(bool)preferHardwareAccelerationCapable;

- (void *)impl;

@end

NS_ASSUME_NONNULL_END
