// Sources/SubcodecObjC/include/SCSprite.h
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCSprite : NSObject

// SpriteExtractor path: raw YUV → .mbs file on disk
+ (nullable SCSprite *)extractorWithSpriteSize:(int)size
                                            qp:(int)qp
                                    outputPath:(NSString *)path
                                         error:(NSError **)error;

- (BOOL)addFrameY:(NSData *)y yStride:(int)ys
               cb:(NSData *)cb cbStride:(int)cbs
               cr:(NSData *)cr crStride:(int)crs
            alpha:(NSData *)alpha alphaStride:(int)as
            error:(NSError **)error;

- (BOOL)finalizeExtraction:(NSError **)error;

// SpriteEncoder path: raw YUV → NAL data in memory (for reference decode)
+ (nullable SCSprite *)encoderWithWidth:(int)width
                                 height:(int)height
                                     qp:(int)qp
                                  error:(NSError **)error;

- (BOOL)encodeFrameY:(NSData *)y yStride:(int)ys
                  cb:(NSData *)cb cbStride:(int)cbs
                  cr:(NSData *)cr crStride:(int)crs
          frameIndex:(int)idx
               error:(NSError **)error;

- (nullable NSData *)buildStreamWithError:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
