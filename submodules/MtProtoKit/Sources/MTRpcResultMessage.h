#import <Foundation/Foundation.h>

@class MTRpcError;

@interface MTRpcResultMessage : NSObject

@property (nonatomic, readonly) int64_t requestMessageId;
@property (nonatomic, strong, readonly) NSData *data;

- (instancetype)initWithRequestMessageId:(int64_t)requestMessagId data:(NSData *)data;

@end
