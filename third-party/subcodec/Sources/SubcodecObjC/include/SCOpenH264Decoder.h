// Sources/SubcodecObjC/include/SCOpenH264Decoder.h
#import <Foundation/Foundation.h>
#import "SCDecoding.h"
#import "SCDecodedFrame.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCOpenH264Decoder : NSObject <SCDecoding>

+ (nullable SCOpenH264Decoder *)createDecoderWithError:(NSError **)error;

- (nullable NSArray<SCDecodedFrame *> *)decodeStream:(NSData *)data
                                               error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
