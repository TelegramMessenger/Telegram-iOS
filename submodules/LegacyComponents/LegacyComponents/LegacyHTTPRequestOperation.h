#import <Foundation/Foundation.h>

@protocol LegacyHTTPRequestOperation <NSObject>

@property (nonatomic, retain) NSOutputStream *outputStream;

- (void)setCompletionBlockWithSuccess:(void (^)(NSOperation *operation, id responseObject))success
                              failure:(void (^)(NSOperation *operation, NSError *error))failure;
- (void)setDownloadProgressBlock:(void (^)(NSInteger bytesRead, NSInteger totalBytesRead, NSInteger totalBytesExpectedToRead))block;

@end
