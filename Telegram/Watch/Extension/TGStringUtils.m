#import "TGStringUtils.h"
#import "TGWatchCommon.h"
#import <CommonCrypto/CommonDigest.h>

bool TGIsRTL()
{
    static bool value = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        value = ([NSLocale characterDirectionForLanguage:[[NSLocale preferredLanguages] objectAtIndex:0]] == NSLocaleLanguageDirectionRightToLeft);
    });
    
    return value;
}

bool TGIsArabic()
{
    static bool value = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSString *language = [[NSLocale preferredLanguages] objectAtIndex:0];
        value = [language isEqualToString:@"ar"];
    });
    return value;
}

bool TGIsKorean()
{
    static bool value = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSString *language = [[NSLocale preferredLanguages] objectAtIndex:0];
        value = [language isEqualToString:@"ko"];
    });
    return value;
}

bool TGIsLocaleArabic()
{
    static bool value = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSString *identifier = [[NSLocale currentLocale] localeIdentifier];
        value = [identifier isEqualToString:@"ar"] || [identifier hasPrefix:@"ar_"];
    });
    return value;
}

@implementation TGStringUtils

+ (NSString *)stringWithLocalizedNumber:(NSInteger)number
{
    return [self stringWithLocalizedNumberCharacters:[[NSString alloc] initWithFormat:@"%d", (int)number]];
}

+ (NSString *)stringWithLocalizedNumberCharacters:(NSString *)string
{
    NSString *resultString = string;
    
    if (TGIsArabic())
    {
        static NSString *arabicNumbers = @"٠١٢٣٤٥٦٧٨٩";
        NSMutableString *mutableString = [[NSMutableString alloc] init];
        for (int i = 0; i < (int)string.length; i++)
        {
            unichar c = [string characterAtIndex:i];
            if (c >= '0' && c <= '9')
                [mutableString replaceCharactersInRange:NSMakeRange(mutableString.length, 0) withString:[arabicNumbers substringWithRange:NSMakeRange(c - '0', 1)]];
            else
                [mutableString replaceCharactersInRange:NSMakeRange(mutableString.length, 0) withString:[string substringWithRange:NSMakeRange(i, 1)]];
        }
        resultString = mutableString;
    }
    
    return resultString;
}

+ (NSString *)stringForFileSize:(NSUInteger)size precision:(NSInteger)precision
{
    NSString *string = @"";
    if (size < 1024)
    {
        string = [[NSString alloc] initWithFormat:TGLocalized(@"FileSize.B"), [[NSString alloc] initWithFormat:@"%d", (int)size]];}
    else if (size < 1024 * 1024)
    {
        string = [[NSString alloc] initWithFormat:TGLocalized(@"FileSize.KB"), [[NSString alloc] initWithFormat:@"%d", (int)(size / 1024)]];
    }
    else
    {
        NSString *format = [NSString stringWithFormat:@"%%0.%df", (int)precision];
        string = [[NSString alloc] initWithFormat:TGLocalized(@"FileSize.MB"), [[NSString alloc] initWithFormat:format, (CGFloat)(size / 1024.0f / 1024.0f)]];
    }
    
    return string;
}

static bool isEmojiCharacter(NSString *singleChar)
{
    const unichar high = [singleChar characterAtIndex:0];
    
    if (0xd800 <= high && high <= 0xdbff && singleChar.length >= 2)
    {
        const unichar low = [singleChar characterAtIndex:1];
        const int codepoint = ((high - 0xd800) * 0x400) + (low - 0xdc00) + 0x10000;
        
        return (0x1d000 <= codepoint && codepoint <= 0x1f77f);
    }
    
    return (0x2100 <= high && high <= 0x27bf);
}

+ (NSString *)_cleanedUpString:(NSString *)string
{
    NSMutableString *__block buffer = [NSMutableString stringWithCapacity:string.length];
    
    [string enumerateSubstringsInRange:NSMakeRange(0, string.length)
                               options:NSStringEnumerationByComposedCharacterSequences
                            usingBlock: ^(NSString* substring, __unused NSRange substringRange, __unused NSRange enclosingRange, __unused BOOL* stop)
    {
        [buffer appendString:isEmojiCharacter(substring) ? @"" : substring];
    }];
    
    return buffer;
}

+ (NSString *)initialsForFirstName:(NSString *)firstName lastName:(NSString *)lastName single:(bool)single
{
    NSString *initials = @"";
    
    NSString *cleanFirstName = [self _cleanedUpString:firstName];
    NSString *cleanLastName = [self _cleanedUpString:lastName];
    
    if (!single && cleanFirstName.length != 0 && cleanLastName.length != 0)
        initials = [[NSString alloc] initWithFormat:@"%@\u200B%@", [cleanFirstName substringToIndex:1], [cleanLastName substringToIndex:1]]; //\u200B is not rendering properly
    else if (cleanFirstName.length != 0)
        initials = [cleanFirstName substringToIndex:1];
    else if (cleanLastName.length != 0)
        initials = [cleanLastName substringToIndex:1];
    
    return [initials uppercaseString];
}

+ (NSString *)initialForGroupName:(NSString *)groupName
{
    NSString *initial = @" ";
    NSString *cleanGroupName = [self _cleanedUpString:groupName];
    if (cleanGroupName.length > 0)
        initial = [cleanGroupName substringToIndex:1];
    
    return [initial uppercaseString];
}

+ (NSString *)integerValueFormat:(NSString *)prefix value:(NSInteger)value
{
    if (value == 1)
        return [prefix stringByAppendingString:@"1"];
    else if (value == 2)
        return [prefix stringByAppendingString:@"2"];
    else if (value >= 3 && value <= 10)
        return [prefix stringByAppendingString:@"3_10"];
    else
        return [prefix stringByAppendingString:@"any"];
}

+ (NSString *)md5WithString:(NSString *)string
{
    const char *ptr = [string UTF8String];
    unsigned char md5Buffer[16];
    CC_MD5(ptr, (CC_LONG)[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], md5Buffer);
    NSString *output = [[NSString alloc] initWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5Buffer[0], md5Buffer[1], md5Buffer[2], md5Buffer[3], md5Buffer[4], md5Buffer[5], md5Buffer[6], md5Buffer[7], md5Buffer[8], md5Buffer[9], md5Buffer[10], md5Buffer[11], md5Buffer[12], md5Buffer[13], md5Buffer[14], md5Buffer[15]];

    return output;
}

+ (bool)stringContainsEmojiOnly:(NSString *)string length:(NSUInteger *)length
{
    if (string.length == 0)
        return false;
    
    __block bool result = true;
    
    __block NSUInteger count = 0;
    [string enumerateSubstringsInRange:NSMakeRange(0, string.length)
                               options:NSStringEnumerationByComposedCharacterSequences
                            usingBlock: ^(NSString *substring, __unused NSRange substringRange, __unused NSRange enclosingRange, BOOL *stop)
    {
        if (!isEmojiCharacter(substring))
        {
            result = false;
            *stop = true;
        }
        count++;
    }];
    
    if (length != NULL)
        *length = count;
    
    return result;
}

@end


@implementation NSString (NSArrayFormatExtension)

+ (instancetype)stringWithFormat:(NSString *)format array:(NSArray *)arguments
{
    switch (arguments.count)
    {
        case 1:
            return [NSString stringWithFormat:TGLocalized(format), arguments[0]];
            
        case 2:
            return [NSString stringWithFormat:TGLocalized(format), arguments[0], arguments[1]];
            
        case 3:
            return [NSString stringWithFormat:TGLocalized(format), arguments[0], arguments[1], arguments[2]];
            
        case 4:
            return [NSString stringWithFormat:TGLocalized(format), arguments[0], arguments[1], arguments[2], arguments[3]];
            
        default:
            return TGLocalized(format);
    }
}

@end
