#import <Foundation/Foundation.h>

@interface MTMsgsStateReqMessage : NSObject

@property (nonatomic, strong, readonly) NSArray *messageIds;

- (instancetype)initWithMessageIds:(NSArray *)messageIds;

@end
