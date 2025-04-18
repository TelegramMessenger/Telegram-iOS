#import <Foundation/Foundation.h>

@interface TGLocalization : NSObject <NSCoding>
    
@property (nonatomic, readonly) int32_t version;
@property (nonatomic, strong, readonly) NSString *code;
@property (nonatomic, readonly) int languageCodeHash;
@property (nonatomic, readonly) bool isActive;
    
- (instancetype)initWithVersion:(int32_t)version code:(NSString *)code dict:(NSDictionary<NSString *, NSString *> *)dict isActive:(bool)isActive;
    
- (TGLocalization *)mergedWith:(NSDictionary<NSString *, NSString *> *)other version:(int32_t)version;
    
- (TGLocalization *)withUpdatedIsActive:(bool)isActive;

- (NSLocale *)locale;

- (NSString *)get:(NSString *)key;
- (NSString *)getPluralized:(NSString *)key count:(int32_t)count;
- (bool)contains:(NSString *)key;

- (NSDictionary<NSString *, NSString *> *)dict;

@end
