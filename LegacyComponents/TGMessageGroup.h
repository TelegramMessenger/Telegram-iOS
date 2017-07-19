#import <Foundation/Foundation.h>

@interface TGMessageGroup : NSObject

@property (nonatomic, readonly) int32_t minId;
@property (nonatomic, readonly) int32_t minTimestamp;
@property (nonatomic, readonly) int32_t maxId;
@property (nonatomic, readonly) int32_t maxTimestamp;
@property (nonatomic, readonly) int32_t count;

- (instancetype)initWithMinId:(int32_t)minId minTimestamp:(int32_t)minTimestamp maxId:(int32_t)maxId maxTimestamp:(int32_t)maxTimestamp count:(int32_t)count;

@end
