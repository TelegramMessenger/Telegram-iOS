#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif
    
    int32_t murMurHash32(NSString *string);
    int32_t murMurHashBytes32(void *bytes, int length);
    
    bool TGIsRTL();
    bool TGIsArabic();
    bool TGIsKorean();
    bool TGIsLocaleArabic();
    
#ifdef __cplusplus
}
#endif

@interface TGStringUtils : NSObject

+ (bool)stringContainsEmojiOnly:(NSString *)string length:(NSUInteger *)length;

+ (NSString *)stringWithLocalizedNumber:(NSInteger)number;
+ (NSString *)stringWithLocalizedNumberCharacters:(NSString *)string;

+ (NSString *)stringForFileSize:(NSUInteger)size precision:(NSInteger)precision;

+ (NSString *)initialsForFirstName:(NSString *)firstName lastName:(NSString *)lastName single:(bool)single;
+ (NSString *)initialForGroupName:(NSString *)groupName;

+ (NSString *)integerValueFormat:(NSString *)prefix value:(NSInteger)value;

+ (NSString *)md5WithString:(NSString *)string;

@end


@interface NSString (NSArrayFormatExtension)

+ (id)stringWithFormat:(NSString *)format array:(NSArray*) arguments;

@end
