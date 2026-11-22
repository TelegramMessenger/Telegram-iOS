#import <LegacyComponents/TGMessageEntity.h>

@interface TGMessageEntityMentionName : TGMessageEntity

@property (nonatomic, readonly) int32_t userId;

- (instancetype)initWithRange:(NSRange)range userId:(int32_t)userId;

@end
