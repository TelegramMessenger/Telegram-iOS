#import "TGLocalization.h"

#import "TGPluralization.h"

static NSDictionary *fallbackDict(NSString *code) {
    if (code == nil) {
        code = @"en";
    }
    static NSMutableDictionary *dicts = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dicts = [[NSMutableDictionary alloc] init];
    });
    NSDictionary *dict = dicts[code];
    if (dict == nil) {
        NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:code ofType:@"lproj"]];
        NSString *path = [bundle pathForResource:@"Localizable" ofType:@"strings"];
        dict = [NSDictionary dictionaryWithContentsOfFile:path];
        if (dict == nil) {
            dict = @{};
        }
        dicts[code] = dict;
    }
    return dict;
}

static NSString *fallbackString(NSString *key, NSString *code) {
    NSString *value = fallbackDict(code)[key];
    if (value == nil) {
        value = fallbackDict(@"en")[key];
    }
    
    if (value == nil) {
        return key;
    } else {
        return value;
    }
}

@interface TGLocalization () {
    NSDictionary<NSString *, NSString *> *_dict;
}

@end

@implementation TGLocalization
    
- (instancetype)initWithVersion:(int32_t)version code:(NSString *)code dict:(NSDictionary<NSString *, NSString *> *)dict isActive:(bool)isActive {
    self = [super init];
    if (self != nil) {
        _version = version;
        _code = code;
        NSString *appTitle = [[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleDisplayName"];
        if (appTitle == nil) {
            appTitle = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
        }
        if (appTitle == nil) {
            appTitle = @"Telegram";
        }
        NSString *originalTitle = @"Telegram";
        if (![appTitle isEqualToString:originalTitle]) {
            NSMutableDictionary *updatedDict = [[NSMutableDictionary alloc] initWithDictionary:dict];
            for (NSString *key in dict.keyEnumerator) {
                NSString *value = dict[key];
                if ([value rangeOfString:originalTitle].location != NSNotFound) {
                    value = [value stringByReplacingOccurrencesOfString:originalTitle withString:appTitle];
                    updatedDict[key] = value;
                }
            }
            _dict = updatedDict;
        } else {
            _dict = dict;
        }
        _isActive = isActive;
        
        NSString *rawCode = code;
        NSRange range = [rawCode rangeOfString:@"_"];
        if (range.location != NSNotFound) {
            rawCode = [rawCode substringToIndex:range.location];
        }
        range = [rawCode rangeOfString:@"-"];
        if (range.location != NSNotFound) {
            rawCode = [rawCode substringToIndex:range.location];
        }
        rawCode = [rawCode lowercaseString];
        unsigned int lc = 0;
        const char *s = rawCode.UTF8String;
        for (; *s; s++) { lc = (lc << 8) + *s; }
        _languageCodeHash = lc;
    }
    return self;
}
    
- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    return [self initWithVersion:[aDecoder decodeInt32ForKey:@"version"] code:[aDecoder decodeObjectForKey:@"code"] dict:[aDecoder decodeObjectForKey:@"dict"] isActive:[aDecoder decodeBoolForKey:@"isActive"]];
}
    
- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt32:_version forKey:@"version"];
    [aCoder encodeObject:_code forKey:@"code"];
    [aCoder encodeObject:_dict forKey:@"dict"];
    [aCoder encodeBool:_isActive forKey:@"isActive"];
}
    
- (TGLocalization *)mergedWith:(NSDictionary<NSString *, NSString *> *)other version:(int32_t)version {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:_dict];
    [dict addEntriesFromDictionary:other];
    
    return [[TGLocalization alloc] initWithVersion:version code:_code dict:dict isActive:_isActive];
}
    
- (TGLocalization *)withUpdatedIsActive:(bool)isActive {
    return [[TGLocalization alloc] initWithVersion:_version code:_code dict:_dict isActive:isActive];
}

- (NSLocale *)locale
{
    NSString *suffix = @"";
    NSString *identifier = [[NSLocale currentLocale] localeIdentifier];
    NSRange range = [identifier rangeOfString:@"_"];
    if (range.location != NSNotFound)
        suffix = [identifier substringFromIndex:range.location];
    
    identifier = [_code stringByAppendingString:suffix];
    return [NSLocale localeWithLocaleIdentifier:identifier];
}
    
- (NSString *)get:(NSString *)key {
    if (key == nil) {
        return nil;
    }
    NSString *value = _dict[key];

    if (value != nil && value.length != 0) {
        return value;
    } else {
        return fallbackString(key, _code);
    }
}

- (NSString *)getPluralized:(NSString *)key count:(int32_t)count {
    NSString *suffix = nil;
    switch (TGPluralForm(_languageCodeHash, count)) {
        case TGPluralFormZero:
            suffix = @"_0";
            break;
        case TGPluralFormOne:
            suffix = @"_1";
            break;
        case TGPluralFormTwo:
            suffix = @"_2";
            break;
        case TGPluralFormFew:
            suffix = @"_3_10";
            break;
        case TGPluralFormMany:
            suffix = @"_many";
            break;
        case TGPluralFormOther:
            suffix = @"_any";
            break;
    }
    NSString *finalKey = [key stringByAppendingString:suffix];
    if (_dict[finalKey] == nil) {
        finalKey = [key stringByAppendingString:@"_any"];
    }
    
    return [[NSString alloc] initWithFormat:[self get:finalKey], [NSString stringWithFormat:@"%d", count]];
}

- (bool)contains:(NSString *)key {
    return _dict[key] != nil;
}

- (NSDictionary<NSString *, NSString *> *)dict {
    return _dict;
}

@end
