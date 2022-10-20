#import "RMPhoneFormat.h"

@interface PhoneRule : NSObject

@property (nonatomic, assign) int minVal;
@property (nonatomic, assign) int maxVal;
@property (nonatomic, assign) int byte8;
@property (nonatomic, assign) int maxLen;
@property (nonatomic, assign) int otherFlag;
@property (nonatomic, assign) int prefixLen;
@property (nonatomic, assign) int flag12;
@property (nonatomic, assign) int flag13;
@property (nonatomic) NSString *format;
#ifdef DEBUG
@property (nonatomic) NSSet *countries;
@property (nonatomic) NSString *callingCode;
@property (nonatomic, assign) int matchLen;
#endif

- (NSString *)format:(NSString *)str intlPrefix:(NSString *)intlPrefix trunkPrefix:(NSString *)trunkPrefix;

@end

@implementation PhoneRule

@synthesize minVal = _minVal;
@synthesize maxVal = _maxVal;
@synthesize byte8 = _byte8;
@synthesize maxLen = _maxLen;
@synthesize otherFlag = _otherFlag;
@synthesize prefixLen = _prefixLen;
@synthesize flag12 = _flag12;
@synthesize flag13 = _flag13;
@synthesize format = _format;

#ifdef DEBUG
@synthesize countries = _countries;
@synthesize callingCode = _callingCode;
@synthesize matchLen = _matchLen;
#endif

- (NSString *)format:(NSString *)str intlPrefix:(NSString *)intlPrefix trunkPrefix:(NSString *)trunkPrefix {
    BOOL hadC = NO;
    BOOL hadN = NO;
    BOOL hasOpen = NO;
    int spot = 0;
    NSMutableString *res = [[NSMutableString alloc] initWithCapacity:20];
    for (int i = 0; i < (int)[self.format length]; i++) {
        unichar ch = [self.format characterAtIndex:i];
        switch (ch) {
            case 'c':
                // Add international prefix if there is one.
                hadC = YES;
                if (intlPrefix != nil) {
                    [res appendString:intlPrefix];
                }
                break;
            case 'n':
                // Add trunk prefix if there is one.
                hadN = YES;
                if (trunkPrefix != nil) {
                    [res appendString:trunkPrefix];
                }
                break;
            case '#':
                // Add next digit from number. If there aren't enough digits left then do nothing unless we need to
                // space-fill a pair of parenthesis.
                if (spot < (int)[str length]) {
                    [res appendString:[str substringWithRange:NSMakeRange(spot, 1)]];
                    spot++;
                } else if (hasOpen) {
                    [res appendString:@" "];
                }
                break;
            case '(':
                // Flag we found an open paren so it can be space-filled. But only do so if we aren't beyond the
                // end of the number.
                if (spot < (int)[str length]) {
                    hasOpen = YES;
                }
                // fall through
            default: // rest like ) and -
                // Don't show space after n if no trunkPrefix or after c if no intlPrefix
                if (!(ch == ' ' && i > 0 && (([self.format characterAtIndex:i - 1] == 'n' && trunkPrefix == nil) || ([self.format characterAtIndex:i - 1] == 'c' && intlPrefix == nil)))) {
                    // Only show punctuation if not beyond the end of the supplied number.
                    // The only exception is to show a close paren if we had found
                    if (spot < (int)[str length] || (hasOpen && ch == ')')) {
                        [res appendString:[self.format substringWithRange:NSMakeRange(i, 1)]];
                        if (ch == ')') {
                            hasOpen = NO; // close it
                        }
                    }
                }
                break;
        }
    }
    
    // Not all format strings have a 'c' or 'n' in them. If we have an international prefix or a trunk prefix but the
    // format string doesn't explictly say where to put it then simply add it to the beginning.
    if (intlPrefix != nil && !hadC) {
        [res insertString:[NSString stringWithFormat:@"%@ ", intlPrefix] atIndex:0];
    } else if (trunkPrefix != nil && !hadN) {
        [res insertString:trunkPrefix atIndex:0];
    }
    
    return res;
}

- (NSString *)description {
#ifdef DEBUG
    return [NSString stringWithFormat:@"Rule: { countries: %@, calling code: %@, matchlen: %d, minVal: %d, maxVal: %d, byte8: %d, maxLen: %d, nFlag: %d, prefixLen: %d, flag12: %d, flag13: %d, format: %@ }", self.countries, self.callingCode, self.matchLen, self.minVal, self.maxVal, self.byte8, self.maxLen, self.otherFlag, self.prefixLen, self.flag12, self.flag13, self.format];
#else
    return [NSString stringWithFormat:@"Rule: { minVal: %d, maxVal: %d, byte8: %d, maxLen: %d, nFlag: %d, prefixLen: %d, flag12: %d, flag13: %d, format: %@ }", self.minVal, self.maxVal, self.byte8, self.maxLen, self.otherFlag, self.prefixLen, self.flag12, self.flag13, self.format];
#endif
}


@end


@interface RuleSet : NSObject

@property (nonatomic, assign) int matchLen;
@property (nonatomic) NSMutableArray *rules;

- (NSString *)format:(NSString *)str intlPrefix:(NSString *)intlPrefix trunkPrefix:(NSString *)trunkPrefix prefixRequired:(BOOL)prefixRequired;

@end

@implementation RuleSet

@synthesize matchLen = _matchLen;
@synthesize rules = _rules;

- (NSString *)format:(NSString *)str intlPrefix:(NSString *)intlPrefix trunkPrefix:(NSString *)trunkPrefix prefixRequired:(BOOL)prefixRequired {
    if ((int)[str length] >= self.matchLen)
    {
        NSString *begin = [str substringToIndex:self.matchLen];
        int val = [begin intValue];
        for (PhoneRule *rule in self.rules)
        {
            if (val >= rule.minVal && val <= rule.maxVal && (int)[str length] <= rule.maxLen)
            {
                if (prefixRequired)
                {
                    if (
                         ((rule.flag12 & 0x03) == 0 &&
                         trunkPrefix == nil &&
                         intlPrefix == nil) ||
                         (trunkPrefix != nil && (rule.flag12 & 0x01)) ||
                         (intlPrefix != nil && (rule.flag12 & 0x02))
                       )
                    {
                        return [rule format:str intlPrefix:intlPrefix trunkPrefix:trunkPrefix];
                    }
                }
                else
                {
                    if ((trunkPrefix == nil && intlPrefix == nil) || (trunkPrefix != nil && (rule.flag12 & 0x01)) || (intlPrefix != nil && (rule.flag12 & 0x02)))
                    {
                        return [rule format:str intlPrefix:intlPrefix trunkPrefix:trunkPrefix];
                    }
                }
            }
        }
        
        if (!prefixRequired)
        {
            if (intlPrefix != nil)
            {
                for (PhoneRule *rule in self.rules)
                {
                    if (val >= rule.minVal && val <= rule.maxVal && (int)[str length] <= rule.maxLen)
                    {
                        if (trunkPrefix == nil || (rule.flag12 & 0x01))
                        {
                            return [rule format:str intlPrefix:intlPrefix trunkPrefix:trunkPrefix];
                        }
                    }
                }
            } else if (trunkPrefix != nil)
            {
                for (PhoneRule *rule in self.rules)
                {
                    if (val >= rule.minVal && val <= rule.maxVal && (int)[str length] <= rule.maxLen)
                    {
                        if (intlPrefix == nil || (rule.flag12 & 0x02))
                        {
                            return [rule format:str intlPrefix:intlPrefix trunkPrefix:trunkPrefix];
                        }
                    }
                }
            }
        }
        
        return nil; // no match found
    } else {
        return nil; // not long enough to compare
    }
}

- (NSString *)description {
    NSMutableString *res = [NSMutableString stringWithCapacity:100];
    [res appendFormat:@"RuleSet: { matchLen: %d, rules: %@ }", self.matchLen, self.rules];
    
    return res;
}


@end


@interface CallingCodeInfo : NSObject

@property (nonatomic) NSSet *countries;
@property (nonatomic) NSString *callingCode;
@property (nonatomic) NSMutableArray *trunkPrefixes;
@property (nonatomic) NSMutableArray *intlPrefixes;
@property (nonatomic) NSMutableArray *ruleSets;
@property (nonatomic) NSMutableArray *formatStrings;

- (NSString *)matchingAccessCode:(NSString *)str;
- (NSString *)format:(NSString *)str;

@end

@implementation CallingCodeInfo

@synthesize countries = _countries;
@synthesize callingCode = _callingCode;
@synthesize trunkPrefixes = _trunkPrefixes;
@synthesize intlPrefixes = _intlPrefixes;
@synthesize ruleSets = _ruleSets;
@synthesize formatStrings = _formatStrings;

- (NSString *)matchingAccessCode:(NSString *)str {
    for (NSString *code in self.intlPrefixes) {
        if ([str hasPrefix:code]) {
            return code;
        }
    }
    
    return nil;
}

- (NSString *)matchingTrunkCode:(NSString *)str {
    for (NSString *code in self.trunkPrefixes) {
        if ([str hasPrefix:code]) {
            return code;
        }
    }
    
    return nil;
}

- (NSString *)format:(NSString *)orig
{
    NSString *str = orig;
    NSString *trunkPrefix = nil;
    NSString *intlPrefix = nil;
    if ([str hasPrefix:self.callingCode])
    {
        intlPrefix = self.callingCode;
        str = [str substringFromIndex:[intlPrefix length]];
    }
    else
    {
        NSString *trunk = [self matchingTrunkCode:str];
        if (trunk)
        {
            trunkPrefix = trunk;
            str = [str substringFromIndex:[trunkPrefix length]];
        }
    }

    for (RuleSet *set in self.ruleSets)
    {
        NSString *phone = [set format:str intlPrefix:intlPrefix trunkPrefix:trunkPrefix prefixRequired:YES];
        if (phone)
        {
            return phone;
        }
    }
    
    for (RuleSet *set in self.ruleSets)
    {
        NSString *phone = [set format:str intlPrefix:intlPrefix trunkPrefix:trunkPrefix prefixRequired:NO];
        if (phone)
        {
            return phone;
        }
    }
    
    if (intlPrefix != nil && [str length])
    {
        return [NSString stringWithFormat:@"%@ %@", intlPrefix, str];
    }
    
    return orig;
}

- (NSString *)description {
    NSMutableString *res = [NSMutableString stringWithCapacity:100];
    [res appendFormat:@"CountryInfo { countries: %@, code: %@, trunkPrefixes: %@, intlPrefixes: %@", self.countries, self.callingCode, self.trunkPrefixes, self.intlPrefixes];
    [res appendFormat:@", rule sets: %@ }", self.ruleSets];
    
    return res;
}


@end

static NSCharacterSet *phoneChars = nil;
#ifdef DEBUG
static NSMutableDictionary *extra1CallingCodes = nil;
static NSMutableDictionary *extra2CallingCodes = nil;
static NSMutableDictionary *extra3CallingCodes = nil;
static NSMutableDictionary *flagRules = nil;
#endif

@implementation RMPhoneFormat {
    NSData *_data;
    NSString *_defaultCountry;
    NSString *_defaultCallingCode;
    NSMutableDictionary *_callingCodeOffsets;
    NSMutableDictionary *_callingCodeCountries;
    NSMutableDictionary *_callingCodeData;
    NSMutableDictionary *_countryCallingCode;
}

+ (void)initialize {
    phoneChars = [NSCharacterSet characterSetWithCharactersInString:@"0123456789+*#"];
    
#ifdef DEBUG
    extra1CallingCodes = [[NSMutableDictionary alloc] init];
    extra2CallingCodes = [[NSMutableDictionary alloc] init];
    extra3CallingCodes = [[NSMutableDictionary alloc] init];
    flagRules = [[NSMutableDictionary alloc] init];
#endif
}

+ (NSString *)strip:(NSString *)str {
    NSMutableString *res = [NSMutableString stringWithString:str];
    for (int i = (int)[res length] - 1; i >= 0; i--) {
        if (![phoneChars characterIsMember:[res characterAtIndex:i]]) {
            [res deleteCharactersInRange:NSMakeRange(i, 1)];
        }
    }
    
    return res;
}

+ (RMPhoneFormat *)instance {
    static RMPhoneFormat *instance = nil;
    static dispatch_once_t predicate = 0;
    
    dispatch_once(&predicate, ^{ instance = [self new]; });
    
    return instance;
}

- (id)init {
    self = [self initWithDefaultCountry:nil];
    
    return self;
}

- (id)initWithDefaultCountry:(NSString *)countryCode {
    if ((self = [super init])) {
        _data = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"PhoneFormats" ofType:@"dat"]];
        NSAssert(_data, @"The file PhoneFormats.dat is not in the resource bundle. See the README.");

        if (countryCode.length) {
            _defaultCountry = countryCode;
        } else {
            NSLocale *loc = [NSLocale currentLocale];
            _defaultCountry = [[loc objectForKey:NSLocaleCountryCode] lowercaseString];
        }
        _callingCodeOffsets = [[NSMutableDictionary alloc] initWithCapacity:255];
        _callingCodeCountries = [[NSMutableDictionary alloc] initWithCapacity:255];
        _callingCodeData = [[NSMutableDictionary alloc] initWithCapacity:10];
        _countryCallingCode = [[NSMutableDictionary alloc] initWithCapacity:255];
        
        [self parseDataHeader];
    }
        
    return self;
}

- (NSString *)defaultCallingCode {
    return [self callingCodeForCountryCode:_defaultCountry];
}

- (NSString *)callingCodeForCountryCode:(NSString *)countryCode {
    return [_countryCallingCode objectForKey:[countryCode lowercaseString]];
}

- (NSSet *)countriesForCallingCode:(NSString *)callingCode {
    if ([callingCode hasPrefix:@"+"]) {
        callingCode = [callingCode substringFromIndex:1];
    }
    
    return [_callingCodeCountries objectForKey:callingCode];
}

- (CallingCodeInfo *)findCallingCodeInfo:(NSString *)str {
    CallingCodeInfo *res = nil;
    for (int i = 0; i < 3; i++) {
        if (i < (int)[str length]) {
            res = [self callingCodeInfo:[str substringToIndex:i + 1]];
            if (res) {
                break;
            }
        } else {
            break;
        }
    }
    
    return res;
}

- (NSString *)format:(NSString *)orig implicitPlus:(bool)implicitPlus
{
    NSString *str = [RMPhoneFormat strip:orig];
    
    bool hasPlusPrefix = [str hasPrefix:@"+"];
    
    if ([str hasPrefix:@"+"] || implicitPlus)
    {
        NSString *rest = hasPlusPrefix ? [str substringFromIndex:1] : str;

        CallingCodeInfo *info = [self findCallingCodeInfo:rest];
        if (info)
        {
            NSString *phone = [info format:rest];
            return [@"+" stringByAppendingString:phone];
        } else
        {
            return orig;
        }
    }
    else
    {
        CallingCodeInfo *info = [self callingCodeInfo:_defaultCallingCode];
        if (info == nil)
        {
            return orig;
        }

        NSString *accessCode = [info matchingAccessCode:str];
        if (accessCode)
        {
            NSString *rest = [str substringFromIndex:[accessCode length]];
            NSString *phone = rest;

            CallingCodeInfo *info2 = [self findCallingCodeInfo:rest];
            if (info2)
            {
                phone = [info2 format:rest];
            }
            
            if ([phone length] == 0)
            {
                return accessCode;
            }
            else
            {
                return [NSString stringWithFormat:@"%@ %@", accessCode, phone];
            }
        }
        else
        {
            NSString *phone = [info format:str];
            
            return phone;
        }
    }
    
    return orig;
}

- (uint32_t)value32:(NSUInteger)offset {
    if (offset + 4 <= [_data length]) {
        return OSReadLittleInt32([_data bytes], offset);
    } else {
        return 0;
    }
}

- (int)value16:(NSUInteger)offset {
    if (offset + 2 <= [_data length]) {
        return OSReadLittleInt16([_data bytes], offset);
    } else {
        return 0;
    }
}

- (int)value16BE:(NSUInteger)offset {
    if (offset + 2 <= [_data length]) {
        return OSReadBigInt16([_data bytes], offset);
    } else {
        return 0;
    }
}

- (CallingCodeInfo *)callingCodeInfo:(NSString *)callingCode
{
    CallingCodeInfo *res = [_callingCodeData objectForKey:callingCode];
    if (res == nil)
    {
        NSNumber *num = [_callingCodeOffsets objectForKey:callingCode];
        if (num)
        {
            const uint8_t *bytes = [_data bytes];
            uint32_t start = (int)[num longValue];
            uint32_t offset = start;
            res = [[CallingCodeInfo alloc] init];
            res.callingCode = callingCode;
            res.countries = [_callingCodeCountries objectForKey:callingCode];
            [_callingCodeData setObject:res forKey:callingCode];
            
            uint16_t block1Len = (uint16_t)[self value16:offset];
            offset += 2;
#ifdef DEBUG
            uint16_t extra1 = (uint16_t)[self value16:offset];
#endif
            offset += 2;
            uint16_t block2Len = (uint16_t)[self value16:offset];
            offset += 2;
#ifdef DEBUG
            uint16_t extra2 = (uint16_t)[self value16:offset];
#endif
            offset += 2;
            uint16_t setCnt = (uint16_t)[self value16:offset];
            offset += 2;
#ifdef DEBUG
            uint16_t extra3 = (uint16_t)[self value16:offset];
#endif
            offset += 2;
            
#ifdef DEBUG
            if (extra1) {
                NSMutableArray *vals = [extra1CallingCodes objectForKey:[NSNumber numberWithInt:extra1]];
                if (!vals) {
                    vals = [[NSMutableArray alloc] init];
                    [extra1CallingCodes setObject:vals forKey:[NSNumber numberWithInt:extra1]];
                }
                [vals addObject:res];
            }
            if (extra2) {
                NSMutableArray *vals = [extra2CallingCodes objectForKey:[NSNumber numberWithInt:extra2]];
                if (!vals) {
                    vals = [[NSMutableArray alloc] init];
                    [extra2CallingCodes setObject:vals forKey:[NSNumber numberWithInt:extra2]];
                }
                [vals addObject:res];
            }
            if (extra3) {
                NSMutableArray *vals = [extra3CallingCodes objectForKey:[NSNumber numberWithInt:extra3]];
                if (!vals) {
                    vals = [[NSMutableArray alloc] init];
                    [extra3CallingCodes setObject:vals forKey:[NSNumber numberWithInt:extra3]];
                }
                [vals addObject:res];
            }
#endif

            NSMutableArray *strs = [NSMutableArray arrayWithCapacity:5];
            NSString *str;
            while ([(str = [NSString stringWithCString:(char *)bytes + offset encoding:NSUTF8StringEncoding]) length]) {
                [strs addObject:str];
                offset += [str length] + 1;
            }
            res.trunkPrefixes = strs;
            offset++; // skip NULL

            strs = [NSMutableArray arrayWithCapacity:5];
            while ([(str = [NSString stringWithCString:(char *)bytes + offset encoding:NSUTF8StringEncoding]) length]) {
                [strs addObject:str];
                offset += [str length] + 1;
            }
            res.intlPrefixes = strs;
            
            NSMutableArray *ruleSets = [NSMutableArray arrayWithCapacity:setCnt];
            offset = start + block1Len; // Start of rule sets
            for (int s = 0; s < setCnt; s++) {
                RuleSet *ruleSet = [[RuleSet alloc] init];
                int matchCnt = [self value16:offset];
                ruleSet.matchLen = matchCnt;
                offset += 2;
                int ruleCnt = [self value16:offset];
                offset += 2;
                NSMutableArray *rules = [NSMutableArray arrayWithCapacity:ruleCnt];
                for (int r = 0; r < ruleCnt; r++) {
                    PhoneRule *rule = [[PhoneRule alloc] init];
                    rule.minVal = [self value32:offset];
                    offset += 4;
                    rule.maxVal = [self value32:offset];
                    offset += 4;
                    rule.byte8 = (int)bytes[offset++];
                    rule.maxLen = (int)bytes[offset++];
                    rule.otherFlag = (int)bytes[offset++];
                    rule.prefixLen = (int)bytes[offset++];
                    rule.flag12 = (int)bytes[offset++];
                    rule.flag13 = (int)bytes[offset++];
                    uint16_t strOffset = (uint16_t)[self value16:offset];
                    offset += 2;
                    rule.format = [NSString stringWithCString:(char *)bytes + start + block1Len + block2Len + strOffset encoding:NSUTF8StringEncoding];
                    // Several formats contain [[9]] or [[8]]. Using the Contacts app as a test, I can find no use
                    // for these. Do they mean "optional"? They don't seem to have any use. This code strips out
                    // anything in [[..]]
                    NSRange openPos = [rule.format rangeOfString:@"[["];
                    if (openPos.location != NSNotFound) {
                        NSRange closePos = [rule.format rangeOfString:@"]]"];
                        rule.format = [NSString stringWithFormat:@"%@%@", [rule.format substringToIndex:openPos.location], [rule.format substringFromIndex:closePos.location + closePos.length]];
                    }
                    
                    [rules addObject:rule];
#ifdef DEBUG
                    rule.countries = res.countries;
                    rule.callingCode = res.callingCode;
                    rule.matchLen = matchCnt;
                    if (rule.byte8) {
                        NSMutableDictionary *data = [flagRules objectForKey:@"byte8"];
                        if (!data) {
                            data = [[NSMutableDictionary alloc] init];
                            [flagRules setObject:data forKey:@"byte8"];
                        }
                        NSMutableArray *list = [data objectForKey:[NSNumber numberWithInt:rule.byte8]];
                        if (!list) {
                            list = [[NSMutableArray alloc] init];
                            [data setObject:list forKey:[NSNumber numberWithInt:rule.byte8]];
                        }
                        
                        [list addObject:rule];
                    }
                    if (rule.prefixLen) {
                        NSMutableDictionary *data = [flagRules objectForKey:@"prefixLen"];
                        if (!data) {
                            data = [[NSMutableDictionary alloc] init];
                            [flagRules setObject:data forKey:@"prefixLen"];
                        }
                        NSMutableArray *list = [data objectForKey:[NSNumber numberWithInt:rule.prefixLen]];
                        if (!list) {
                            list = [[NSMutableArray alloc] init];
                            [data setObject:list forKey:[NSNumber numberWithInt:rule.prefixLen]];
                        }
                        
                        [list addObject:rule];
                    }
                    if (rule.otherFlag) {
                        NSMutableDictionary *data = [flagRules objectForKey:@"otherFlag"];
                        if (!data) {
                            data = [[NSMutableDictionary alloc] init];
                            [flagRules setObject:data forKey:@"otherFlag"];
                        }
                        NSMutableArray *list = [data objectForKey:[NSNumber numberWithInt:rule.otherFlag]];
                        if (!list) {
                            list = [[NSMutableArray alloc] init];
                            [data setObject:list forKey:[NSNumber numberWithInt:rule.otherFlag]];
                        }
                        
                        [list addObject:rule];
                    }
                    if (rule.flag12) {
                        NSMutableDictionary *data = [flagRules objectForKey:@"flag12"];
                        if (!data) {
                            data = [[NSMutableDictionary alloc] init];
                            [flagRules setObject:data forKey:@"flag12"];
                        }
                        NSMutableArray *list = [data objectForKey:[NSNumber numberWithInt:rule.flag12]];
                        if (!list) {
                            list = [[NSMutableArray alloc] init];
                            [data setObject:list forKey:[NSNumber numberWithInt:rule.flag12]];
                        }
                        
                        [list addObject:rule];
                    }
                    if (rule.flag13) {
                        NSMutableDictionary *data = [flagRules objectForKey:@"flag13"];
                        if (!data) {
                            data = [[NSMutableDictionary alloc] init];
                            [flagRules setObject:data forKey:@"flag13"];
                        }
                        NSMutableArray *list = [data objectForKey:[NSNumber numberWithInt:rule.flag13]];
                        if (!list) {
                            list = [[NSMutableArray alloc] init];
                            [data setObject:list forKey:[NSNumber numberWithInt:rule.flag13]];
                        }
                        
                        [list addObject:rule];
                    }
#endif
                }
                ruleSet.rules = rules;
                [ruleSets addObject:ruleSet];
            }
            res.ruleSets = ruleSets;
        }
    }
    
    return res;
}

- (void)parseDataHeader {
    int count = [self value32:0];
    uint32_t base = count * 12 + 4;
    const void *bytes = [_data bytes];
    NSUInteger spot = 4;
    for (int i = 0; i < count; i++) {
        NSString *callingCode = [NSString stringWithCString:bytes + spot encoding:NSUTF8StringEncoding];
        spot += 4;
        NSString *country = [NSString stringWithCString:bytes + spot encoding:NSUTF8StringEncoding];
        spot += 4;
        uint32_t offset = [self value32:spot] + base;
        spot += 4;
        
        if ([country isEqualToString:_defaultCountry]) {
            _defaultCallingCode = callingCode;
        }
        
        [_countryCallingCode setObject:callingCode forKey:country];
        
        [_callingCodeOffsets setObject:[NSNumber numberWithLong:offset] forKey:callingCode];
        NSMutableSet *countries = [_callingCodeCountries objectForKey:callingCode];
        if (!countries) {
            countries = [[NSMutableSet alloc] init];
            [_callingCodeCountries setObject:countries forKey:callingCode];
        }
        [countries addObject:country];
    }

    if (_defaultCallingCode) {
        [self callingCodeInfo:_defaultCallingCode];
    }
}

#ifdef DEBUG
- (void)dump {
    NSArray *callingCodes = [[_callingCodeOffsets allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *callingCode in callingCodes) {
        CallingCodeInfo *info = [self callingCodeInfo:callingCode];
        NSLog(@"%@", info);
    }

    NSLog(@"flagRules: %@", flagRules);
    NSLog(@"extra1 calling codes: %@", extra1CallingCodes);
    NSLog(@"extra2 calling codes: %@", extra2CallingCodes);
    NSLog(@"extra3 calling codes: %@", extra3CallingCodes);
}
#endif


@end
