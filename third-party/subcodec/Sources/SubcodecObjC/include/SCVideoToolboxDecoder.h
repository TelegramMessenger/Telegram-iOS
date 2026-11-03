// Sources/SubcodecObjC/include/SCVideoToolboxDecoder.h
#import <Foundation/Foundation.h>
#import "SCDecoding.h"
#import "SCDecodedFrame.h"

NS_ASSUME_NONNULL_BEGIN

@interface SCVideoToolboxDecoder : NSObject <SCDecoding>

+ (nullable SCVideoToolboxDecoder *)createDecoderWithError:(NSError **)error;

- (nullable NSArray<SCDecodedFrame *> *)decodeStream:(NSData *)data
                                               error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
