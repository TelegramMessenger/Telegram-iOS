// Sources/SubcodecObjC/include/SCDecodedFrame.h
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCDecodedFrame : NSObject

@property (nonatomic, readonly) int width;
@property (nonatomic, readonly) int height;
@property (nonatomic, readonly) NSData *y;
@property (nonatomic, readonly) NSData *cb;
@property (nonatomic, readonly) NSData *cr;

- (instancetype)initWithWidth:(int)width
                       height:(int)height
                            y:(NSData *)y
                           cb:(NSData *)cb
                           cr:(NSData *)cr;

@end

NS_ASSUME_NONNULL_END
