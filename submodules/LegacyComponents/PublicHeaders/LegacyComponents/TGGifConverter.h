#import <Foundation/Foundation.h>
#import <SSignalKit/SSignalKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TGGifConverter : NSObject

+ (SSignal *)convertGifToMp4:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
