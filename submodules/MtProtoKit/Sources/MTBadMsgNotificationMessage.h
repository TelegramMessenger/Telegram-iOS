#import <Foundation/Foundation.h>

@interface MTBadMsgNotificationMessage : NSObject

@property (nonatomic, readonly) int64_t badMessageId;
@property (nonatomic, readonly) int32_t badMessageSeqNo;
@property (nonatomic, readonly) int32_t errorCode;

- (instancetype)initWithBadMessageId:(int64_t)badMessageId badMessageSeqNo:(int32_t)badMessageSeqNo errorCode:(int32_t)errorCode;

@end

@interface MTBadServerSaltNotificationMessage : MTBadMsgNotificationMessage

@property (nonatomic, readonly) int64_t nextServerSalt;

- (instancetype)initWithBadMessageId:(int64_t)badMessageId badMessageSeqNo:(int32_t)badMessageSeqNo errorCode:(int32_t)errorCode nextServerSalt:(int64_t)nextServerSalt;

@end
