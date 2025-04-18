#import <Foundation/Foundation.h>

@interface MTMsgResendReqMessage : NSObject

@property (nonatomic, strong, readonly) NSArray *messageIds;

- (instancetype)initWithMessageIds:(NSArray *)messageIds;

@end
