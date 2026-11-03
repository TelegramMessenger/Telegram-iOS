// Sources/SubcodecObjC/include/SCDecoding.h
#import <Foundation/Foundation.h>
#import "SCDecodedFrame.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SCDecoding <NSObject>

+ (nullable id<SCDecoding>)createDecoderWithError:(NSError **)error;

- (nullable NSArray<SCDecodedFrame *> *)decodeStream:(NSData *)data
                                               error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
