#import <Foundation/Foundation.h>

@interface MTMsgContainerMessage : NSObject

@property (nonatomic, strong, readonly) NSArray *messages;

- (instancetype)initWithMessages:(NSArray *)messages;

@end
