#import <Foundation/Foundation.h>

@interface MTMsgAllInfoMessage : NSObject

@property (nonatomic, strong, readonly) NSArray *messageIds;
@property (nonatomic, strong, readonly) NSData *info;

- (instancetype)initWithMessageIds:(NSArray *)messageIds info:(NSData *)info;

@end
