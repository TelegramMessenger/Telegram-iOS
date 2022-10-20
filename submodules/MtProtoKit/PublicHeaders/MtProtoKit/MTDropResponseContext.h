

#import <Foundation/Foundation.h>

@interface MTDropResponseContext : NSObject

@property (nonatomic, readonly) int64_t dropMessageId;
@property (nonatomic) int64_t messageId;
@property (nonatomic) int32_t messageSeqNo;

- (instancetype)initWithDropMessageId:(int64_t)dropMessageId;

@end
