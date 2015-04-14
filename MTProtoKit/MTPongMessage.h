#import <Foundation/Foundation.h>

@interface MTPongMessage : NSObject

@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, readonly) int64_t pingId;

- (instancetype)initWithMessageId:(int64_t)messageId pingId:(int64_t)pingId;

@end
