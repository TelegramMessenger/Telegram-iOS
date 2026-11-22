#import <Foundation/Foundation.h>

@interface MTMsgsAckMessage : NSObject

@property (nonatomic, strong, readonly) NSArray *messageIds;

- (instancetype)initWithMessageIds:(NSArray *)messageIds;

@end
