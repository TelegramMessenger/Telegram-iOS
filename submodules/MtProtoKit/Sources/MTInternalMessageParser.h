#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTInternalMessageParser : NSObject

+ (nullable id)parseMessage:(NSData *)data;

// Returns `data` itself when it is not a gzip_packed wrapper, the inflated body
// when it is, and nil when the wrapper is truncated or the body does not inflate
// within MTMaxUnpackedMessageLength.
+ (nullable NSData *)unwrapMessage:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
