#import <Foundation/Foundation.h>

@interface MTMsgsStateInfoMessage : NSObject

@property (nonatomic, readonly) int64_t requestMessageId;
@property (nonatomic, strong, readonly) NSData *info;

- (instancetype)initWithRequestMessageId:(int64_t)requestMessageId info:(NSData *)info;

@end
