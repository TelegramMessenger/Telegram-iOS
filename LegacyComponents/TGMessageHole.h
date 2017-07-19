#import <Foundation/Foundation.h>

@interface TGMessageHole : NSObject

@property (nonatomic, readonly) int32_t minId;
@property (nonatomic, readonly) int32_t minTimestamp;
@property (nonatomic, readonly) int32_t maxId;
@property (nonatomic, readonly) int32_t maxTimestamp;

- (instancetype)initWithMinId:(int32_t)minId minTimestamp:(int32_t)minTimestamp maxId:(int32_t)maxId maxTimestamp:(int32_t)maxTimestamp;

- (bool)intersects:(TGMessageHole *)other;
- (bool)covers:(TGMessageHole *)other;
- (NSArray *)exclude:(TGMessageHole *)other;

@end
