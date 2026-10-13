#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Sanity ceiling applied by +decompress: so untrusted input cannot inflate
// without bound. Callers that know their own limit pass it explicitly.
FOUNDATION_EXTERN NSUInteger const MTGzipDefaultMaxDecompressedLength;

@interface MTGzip : NSObject

// Inflates gzip data. Returns nil for malformed input or when the output would
// exceed MTGzipDefaultMaxDecompressedLength.
+ (NSData * _Nullable)decompress:(NSData *)data;
// Same, with an explicit ceiling on the inflated size.
+ (NSData * _Nullable)decompress:(NSData *)data maxOutputLength:(NSUInteger)maxOutputLength;
+ (NSData * _Nullable)compress:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
