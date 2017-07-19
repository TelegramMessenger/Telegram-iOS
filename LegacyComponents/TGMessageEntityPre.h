#import <LegacyComponents/TGMessageEntity.h>

@interface TGMessageEntityPre : TGMessageEntity

@property (nonatomic, strong, readonly) NSString *language;

- (instancetype)initWithRange:(NSRange)range language:(NSString *)language;

@end
