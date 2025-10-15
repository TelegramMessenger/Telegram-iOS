

#import <Foundation/Foundation.h>

@interface MTTransportTransaction : NSObject

@property (nonatomic, copy, readonly) void (^completion)(bool success, id transactionId);
@property (nonatomic, strong, readonly) NSData *payload;
@property (nonatomic, readonly) bool expectsDataInResponse;
@property (nonatomic, readonly) bool needsQuickAck;

- (instancetype)initWithPayload:(NSData *)payload completion:(void (^)(bool success, id transactionId))completion;
- (instancetype)initWithPayload:(NSData *)payload completion:(void (^)(bool success, id transactionId))completion needsQuickAck:(bool)needsQuickAck expectsDataInResponse:(bool)expectsDataInResponse;

@end
