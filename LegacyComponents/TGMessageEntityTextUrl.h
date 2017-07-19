#import <LegacyComponents/TGMessageEntity.h>

@interface TGMessageEntityTextUrl : TGMessageEntity

@property (nonatomic, strong, readonly) NSString *url;

- (instancetype)initWithRange:(NSRange)range url:(NSString *)url;

@end
