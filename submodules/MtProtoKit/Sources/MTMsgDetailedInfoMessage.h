#import <Foundation/Foundation.h>

@interface MTMsgDetailedInfoMessage : NSObject

@property (nonatomic, readonly) int64_t responseMessageId;
@property (nonatomic, readonly) int32_t responseLength;
@property (nonatomic, readonly) int32_t status;

- (instancetype)initWithResponseMessageId:(int64_t)responseMessageId responseLength:(int32_t)responseLength status:(int32_t)status;

@end

@interface MTMsgDetailedResponseInfoMessage : MTMsgDetailedInfoMessage

@property (nonatomic, readonly) int64_t requestMessageId;

- (instancetype)initWithRequestMessageId:(int64_t)requestMessageId responseMessageId:(int64_t)responseMessageId responseLength:(int32_t)responseLength status:(int32_t)status;

@end
