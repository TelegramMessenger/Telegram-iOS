#import "TGStringUtils.h"

#import "LegacyComponentsInternal.h"

#import <CommonCrypto/CommonDigest.h>

#import "TGLocalization.h"
#import "TGPluralization.h"

typedef struct {
    __unsafe_unretained NSString *escapeSequence;
    unichar uchar;
} HTMLEscapeMap;

// Taken from http://www.w3.org/TR/xhtml1/dtds.html#a_dtd_Special_characters
// Ordered by uchar lowest to highest for bsearching
static HTMLEscapeMap gAsciiHTMLEscapeMap[] = {
    // A.2.2. Special characters
    { @"&quot;", 34 },
    { @"&amp;", 38 },
    { @"&apos;", 39 },
    { @"&lt;", 60 },
    { @"&gt;", 62 },
    
    // A.2.1. Latin-1 characters
    { @"&nbsp;", 160 }, 
    { @"&iexcl;", 161 }, 
    { @"&cent;", 162 }, 
    { @"&pound;", 163 }, 
    { @"&curren;", 164 }, 
    { @"&yen;", 165 }, 
    { @"&brvbar;", 166 }, 
    { @"&sect;", 167 }, 
    { @"&uml;", 168 }, 
    { @"&copy;", 169 }, 
    { @"&ordf;", 170 }, 
    { @"&laquo;", 171 }, 
    { @"&not;", 172 }, 
    { @"&shy;", 173 }, 
    { @"&reg;", 174 }, 
    { @"&macr;", 175 }, 
    { @"&deg;", 176 }, 
    { @"&plusmn;", 177 }, 
    { @"&sup2;", 178 }, 
    { @"&sup3;", 179 }, 
    { @"&acute;", 180 }, 
    { @"&micro;", 181 }, 
    { @"&para;", 182 }, 
    { @"&middot;", 183 }, 
    { @"&cedil;", 184 }, 
    { @"&sup1;", 185 }, 
    { @"&ordm;", 186 }, 
    { @"&raquo;", 187 }, 
    { @"&frac14;", 188 }, 
    { @"&frac12;", 189 }, 
    { @"&frac34;", 190 }, 
    { @"&iquest;", 191 }, 
    { @"&Agrave;", 192 }, 
    { @"&Aacute;", 193 }, 
    { @"&Acirc;", 194 }, 
    { @"&Atilde;", 195 }, 
    { @"&Auml;", 196 }, 
    { @"&Aring;", 197 }, 
    { @"&AElig;", 198 }, 
    { @"&Ccedil;", 199 }, 
    { @"&Egrave;", 200 }, 
    { @"&Eacute;", 201 }, 
    { @"&Ecirc;", 202 }, 
    { @"&Euml;", 203 }, 
    { @"&Igrave;", 204 }, 
    { @"&Iacute;", 205 }, 
    { @"&Icirc;", 206 }, 
    { @"&Iuml;", 207 }, 
    { @"&ETH;", 208 }, 
    { @"&Ntilde;", 209 }, 
    { @"&Ograve;", 210 }, 
    { @"&Oacute;", 211 }, 
    { @"&Ocirc;", 212 }, 
    { @"&Otilde;", 213 }, 
    { @"&Ouml;", 214 }, 
    { @"&times;", 215 }, 
    { @"&Oslash;", 216 }, 
    { @"&Ugrave;", 217 }, 
    { @"&Uacute;", 218 }, 
    { @"&Ucirc;", 219 }, 
    { @"&Uuml;", 220 }, 
    { @"&Yacute;", 221 }, 
    { @"&THORN;", 222 }, 
    { @"&szlig;", 223 }, 
    { @"&agrave;", 224 }, 
    { @"&aacute;", 225 }, 
    { @"&acirc;", 226 }, 
    { @"&atilde;", 227 }, 
    { @"&auml;", 228 }, 
    { @"&aring;", 229 }, 
    { @"&aelig;", 230 }, 
    { @"&ccedil;", 231 }, 
    { @"&egrave;", 232 }, 
    { @"&eacute;", 233 }, 
    { @"&ecirc;", 234 }, 
    { @"&euml;", 235 }, 
    { @"&igrave;", 236 }, 
    { @"&iacute;", 237 }, 
    { @"&icirc;", 238 }, 
    { @"&iuml;", 239 }, 
    { @"&eth;", 240 }, 
    { @"&ntilde;", 241 }, 
    { @"&ograve;", 242 }, 
    { @"&oacute;", 243 }, 
    { @"&ocirc;", 244 }, 
    { @"&otilde;", 245 }, 
    { @"&ouml;", 246 }, 
    { @"&divide;", 247 }, 
    { @"&oslash;", 248 }, 
    { @"&ugrave;", 249 }, 
    { @"&uacute;", 250 }, 
    { @"&ucirc;", 251 }, 
    { @"&uuml;", 252 }, 
    { @"&yacute;", 253 }, 
    { @"&thorn;", 254 }, 
    { @"&yuml;", 255 },
    
    // A.2.2. Special characters cont'd
    { @"&OElig;", 338 },
    { @"&oelig;", 339 },
    { @"&Scaron;", 352 },
    { @"&scaron;", 353 },
    { @"&Yuml;", 376 },
    
    // A.2.3. Symbols
    { @"&fnof;", 402 }, 
    
    // A.2.2. Special characters cont'd
    { @"&circ;", 710 },
    { @"&tilde;", 732 },
    
    // A.2.3. Symbols cont'd
    { @"&Alpha;", 913 }, 
    { @"&Beta;", 914 }, 
    { @"&Gamma;", 915 }, 
    { @"&Delta;", 916 }, 
    { @"&Epsilon;", 917 }, 
    { @"&Zeta;", 918 }, 
    { @"&Eta;", 919 }, 
    { @"&Theta;", 920 }, 
    { @"&Iota;", 921 }, 
    { @"&Kappa;", 922 }, 
    { @"&Lambda;", 923 }, 
    { @"&Mu;", 924 }, 
    { @"&Nu;", 925 }, 
    { @"&Xi;", 926 }, 
    { @"&Omicron;", 927 }, 
    { @"&Pi;", 928 }, 
    { @"&Rho;", 929 }, 
    { @"&Sigma;", 931 }, 
    { @"&Tau;", 932 }, 
    { @"&Upsilon;", 933 }, 
    { @"&Phi;", 934 }, 
    { @"&Chi;", 935 }, 
    { @"&Psi;", 936 }, 
    { @"&Omega;", 937 }, 
    { @"&alpha;", 945 }, 
    { @"&beta;", 946 }, 
    { @"&gamma;", 947 }, 
    { @"&delta;", 948 }, 
    { @"&epsilon;", 949 }, 
    { @"&zeta;", 950 }, 
    { @"&eta;", 951 }, 
    { @"&theta;", 952 }, 
    { @"&iota;", 953 }, 
    { @"&kappa;", 954 }, 
    { @"&lambda;", 955 }, 
    { @"&mu;", 956 }, 
    { @"&nu;", 957 }, 
    { @"&xi;", 958 }, 
    { @"&omicron;", 959 }, 
    { @"&pi;", 960 }, 
    { @"&rho;", 961 }, 
    { @"&sigmaf;", 962 }, 
    { @"&sigma;", 963 }, 
    { @"&tau;", 964 }, 
    { @"&upsilon;", 965 }, 
    { @"&phi;", 966 }, 
    { @"&chi;", 967 }, 
    { @"&psi;", 968 }, 
    { @"&omega;", 969 }, 
    { @"&thetasym;", 977 }, 
    { @"&upsih;", 978 }, 
    { @"&piv;", 982 }, 
    
    // A.2.2. Special characters cont'd
    { @"&ensp;", 8194 },
    { @"&emsp;", 8195 },
    { @"&thinsp;", 8201 },
    { @"&zwnj;", 8204 },
    { @"&zwj;", 8205 },
    { @"&lrm;", 8206 },
    { @"&rlm;", 8207 },
    { @"&ndash;", 8211 },
    { @"&mdash;", 8212 },
    { @"&lsquo;", 8216 },
    { @"&rsquo;", 8217 },
    { @"&sbquo;", 8218 },
    { @"&ldquo;", 8220 },
    { @"&rdquo;", 8221 },
    { @"&bdquo;", 8222 },
    { @"&dagger;", 8224 },
    { @"&Dagger;", 8225 },
    // A.2.3. Symbols cont'd  
    { @"&bull;", 8226 }, 
    { @"&hellip;", 8230 }, 
    
    // A.2.2. Special characters cont'd
    { @"&permil;", 8240 },
    
    // A.2.3. Symbols cont'd  
    { @"&prime;", 8242 }, 
    { @"&Prime;", 8243 }, 
    
    // A.2.2. Special characters cont'd
    { @"&lsaquo;", 8249 },
    { @"&rsaquo;", 8250 },
    
    // A.2.3. Symbols cont'd  
    { @"&oline;", 8254 }, 
    { @"&frasl;", 8260 }, 
    
    // A.2.2. Special characters cont'd
    { @"&euro;", 8364 },
    
    // A.2.3. Symbols cont'd  
    { @"&image;", 8465 },
    { @"&weierp;", 8472 }, 
    { @"&real;", 8476 }, 
    { @"&trade;", 8482 }, 
    { @"&alefsym;", 8501 }, 
    { @"&larr;", 8592 }, 
    { @"&uarr;", 8593 }, 
    { @"&rarr;", 8594 }, 
    { @"&darr;", 8595 }, 
    { @"&harr;", 8596 }, 
    { @"&crarr;", 8629 }, 
    { @"&lArr;", 8656 }, 
    { @"&uArr;", 8657 }, 
    { @"&rArr;", 8658 }, 
    { @"&dArr;", 8659 }, 
    { @"&hArr;", 8660 }, 
    { @"&forall;", 8704 }, 
    { @"&part;", 8706 }, 
    { @"&exist;", 8707 }, 
    { @"&empty;", 8709 }, 
    { @"&nabla;", 8711 }, 
    { @"&isin;", 8712 }, 
    { @"&notin;", 8713 }, 
    { @"&ni;", 8715 }, 
    { @"&prod;", 8719 }, 
    { @"&sum;", 8721 }, 
    { @"&minus;", 8722 }, 
    { @"&lowast;", 8727 }, 
    { @"&radic;", 8730 }, 
    { @"&prop;", 8733 }, 
    { @"&infin;", 8734 }, 
    { @"&ang;", 8736 }, 
    { @"&and;", 8743 }, 
    { @"&or;", 8744 }, 
    { @"&cap;", 8745 }, 
    { @"&cup;", 8746 }, 
    { @"&int;", 8747 }, 
    { @"&there4;", 8756 }, 
    { @"&sim;", 8764 }, 
    { @"&cong;", 8773 }, 
    { @"&asymp;", 8776 }, 
    { @"&ne;", 8800 }, 
    { @"&equiv;", 8801 }, 
    { @"&le;", 8804 }, 
    { @"&ge;", 8805 }, 
    { @"&sub;", 8834 }, 
    { @"&sup;", 8835 }, 
    { @"&nsub;", 8836 }, 
    { @"&sube;", 8838 }, 
    { @"&supe;", 8839 }, 
    { @"&oplus;", 8853 }, 
    { @"&otimes;", 8855 }, 
    { @"&perp;", 8869 }, 
    { @"&sdot;", 8901 }, 
    { @"&lceil;", 8968 }, 
    { @"&rceil;", 8969 }, 
    { @"&lfloor;", 8970 }, 
    { @"&rfloor;", 8971 }, 
    { @"&lang;", 9001 }, 
    { @"&rang;", 9002 }, 
    { @"&loz;", 9674 }, 
    { @"&spades;", 9824 }, 
    { @"&clubs;", 9827 }, 
    { @"&hearts;", 9829 }, 
    { @"&diams;", 9830 }
};

@implementation TGStringUtils

+ (void)reset
{
    
}

+ (NSString *)stringByEscapingForURL:(NSString *)string
{
    static NSString * const kAFLegalCharactersToBeEscaped = @"?!@#$^&%*+=,.:;'\"`<>()[]{}/\\|~ ";

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSString *unescapedString = [string stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    if (unescapedString == nil)
        unescapedString = string;
    
    return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)unescapedString, NULL, (CFStringRef)kAFLegalCharactersToBeEscaped, CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
#pragma clang diagnostic pop
}

+ (NSString *)stringByEscapingForActorURL:(NSString *)string
{
    static NSString * const kAFLegalCharactersToBeEscaped = @"?!@#$^&%*+=,:;'\"`<>()[]{}/\\|~ ";

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSString *unescapedString = [string stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    if (unescapedString == nil)
        unescapedString = string;
    
    return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)unescapedString, NULL, (CFStringRef)kAFLegalCharactersToBeEscaped, CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
#pragma clang diagnostic pop
}

+ (NSString *)stringByEncodingInBase64:(NSData *)data
{
    NSUInteger length = [data length];
    NSMutableData *mutableData = [[NSMutableData alloc] initWithLength:((length + 2) / 3) * 4];
    
    uint8_t *input = (uint8_t *)[data bytes];
    uint8_t *output = (uint8_t *)[mutableData mutableBytes];
    
    for (NSUInteger i = 0; i < length; i += 3)
    {
        NSUInteger value = 0;
        for (NSUInteger j = i; j < (i + 3); j++)
        {
            value <<= 8;
            if (j < length)
            {
                value |= (0xFF & input[j]);
            }
        }
        
        static uint8_t const kAFBase64EncodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        
        NSUInteger idx = (i / 3) * 4;
        output[idx + 0] = kAFBase64EncodingTable[(value >> 18) & 0x3F];
        output[idx + 1] = kAFBase64EncodingTable[(value >> 12) & 0x3F];
        output[idx + 2] = (i + 1) < length ? kAFBase64EncodingTable[(value >> 6)  & 0x3F] : '=';
        output[idx + 3] = (i + 2) < length ? kAFBase64EncodingTable[(value >> 0)  & 0x3F] : '=';
    }
    
    return [[NSString alloc] initWithData:mutableData encoding:NSASCIIStringEncoding];
}

+ (NSString *)stringByUnescapingFromHTML:(NSString *)srcString
{
    NSRange range = NSMakeRange(0, [srcString length]);
    NSRange subrange = [srcString rangeOfString:@"&" options:NSBackwardsSearch range:range];
    NSRange tagSubrange = NSMakeRange(0, 0);
    
    if (subrange.length == 0)
    {
        tagSubrange = [srcString rangeOfString:@"<" options:NSBackwardsSearch range:range];
        if (tagSubrange.length == 0)
            return srcString;
    }
    
    NSMutableString *finalString = [NSMutableString stringWithString:srcString];
    if (subrange.length != 0)
    {
        do
        {
            NSRange semiColonRange = NSMakeRange(subrange.location, NSMaxRange(range) - subrange.location);
            semiColonRange = [srcString rangeOfString:@";" options:0 range:semiColonRange];
            range = NSMakeRange(0, subrange.location);
            // if we don't find a semicolon in the range, we don't have a sequence
            if (semiColonRange.location == NSNotFound)
            {
                continue;
            }
            NSRange escapeRange = NSMakeRange(subrange.location, semiColonRange.location - subrange.location + 1);
            NSString *escapeString = [srcString substringWithRange:escapeRange];
            NSUInteger length = [escapeString length];
            
            // a squence must be longer than 3 (&lt;) and less than 11 (&thetasym;)
            if (length > 3 && length < 11)
            {
                if ([escapeString characterAtIndex:1] == '#')
                {
                    unichar char2 = [escapeString characterAtIndex:2];
                    if (char2 == 'x' || char2 == 'X') {
                        // Hex escape squences &#xa3;
                        NSString *hexSequence = [escapeString substringWithRange:NSMakeRange(3, length - 4)];
                        NSScanner *scanner = [NSScanner scannerWithString:hexSequence];
                        unsigned value;
                        if ([scanner scanHexInt:&value] && 
                            value < USHRT_MAX &&
                            value > 0 
                            && [scanner scanLocation] == length - 4) {
                            unichar uchar = (unichar)value;
                            NSString *charString = [NSString stringWithCharacters:&uchar length:1];
                            [finalString replaceCharactersInRange:escapeRange withString:charString];
                        }
                        
                    }
                    else
                    {
                        // Decimal Sequences &#123;
                        NSString *numberSequence = [escapeString substringWithRange:NSMakeRange(2, length - 3)];
                        NSScanner *scanner = [NSScanner scannerWithString:numberSequence];
                        int value;
                        if ([scanner scanInt:&value] && 
                            value < USHRT_MAX &&
                            value > 0 
                            && [scanner scanLocation] == length - 3)
                        {
                            unichar uchar = (unichar)value;
                            NSString *charString = [NSString stringWithCharacters:&uchar length:1];
                            [finalString replaceCharactersInRange:escapeRange withString:charString];
                        }
                    }
                }
                else
                {
                    for (unsigned i = 0; i < sizeof(gAsciiHTMLEscapeMap) / sizeof(HTMLEscapeMap); ++i)
                    {
                        if ([escapeString isEqualToString:gAsciiHTMLEscapeMap[i].escapeSequence])
                        {
                            [finalString replaceCharactersInRange:escapeRange withString:[NSString stringWithCharacters:&gAsciiHTMLEscapeMap[i].uchar length:1]];
                            break;
                        }
                    }
                }
            }
        } while ((subrange = [srcString rangeOfString:@"&" options:NSBackwardsSearch range:range]).length != 0);
    }
    
    [finalString replaceOccurrencesOfString:@"<br/>" withString:@"\n" options:NSLiteralSearch range:NSMakeRange(0, finalString.length)];
    
    return finalString;
}

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

+ (NSString *)md5:(NSString *)string
{
    /*static const char *md5PropertyKey = "MD5Key";
    NSString *result = objc_getAssociatedObject(string, md5PropertyKey);
    if (result != nil)
        return result;*/

    const char *ptr = [string UTF8String];
    unsigned char md5Buffer[16];
    CC_MD5(ptr, (CC_LONG)[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], md5Buffer);
    NSString *output = [[NSString alloc] initWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5Buffer[0], md5Buffer[1], md5Buffer[2], md5Buffer[3], md5Buffer[4], md5Buffer[5], md5Buffer[6], md5Buffer[7], md5Buffer[8], md5Buffer[9], md5Buffer[10], md5Buffer[11], md5Buffer[12], md5Buffer[13], md5Buffer[14], md5Buffer[15]];
    //objc_setAssociatedObject(string, md5PropertyKey, output, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return output;
}

+ (NSString *)md5ForData:(NSData *)data {
    unsigned char md5Buffer[16];
    CC_MD5(data.bytes, (CC_LONG)data.length, md5Buffer);
    NSString *output = [[NSString alloc] initWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5Buffer[0], md5Buffer[1], md5Buffer[2], md5Buffer[3], md5Buffer[4], md5Buffer[5], md5Buffer[6], md5Buffer[7], md5Buffer[8], md5Buffer[9], md5Buffer[10], md5Buffer[11], md5Buffer[12], md5Buffer[13], md5Buffer[14], md5Buffer[15]];
    return output;
}

+ (NSDictionary *)argumentDictionaryInUrlString:(NSString *)string
{
    NSMutableDictionary *queryStringDictionary = [[NSMutableDictionary alloc] init];
    NSArray *urlComponents = [string componentsSeparatedByString:@"&"];

    for (NSString *keyValuePair in urlComponents)
    {
        NSRange equalsSignRange = [keyValuePair rangeOfString:@"="];
        if (equalsSignRange.location != NSNotFound) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            NSString *key = [keyValuePair substringToIndex:equalsSignRange.location];
            NSString *value = [[[keyValuePair substringFromIndex:equalsSignRange.location + equalsSignRange.length] stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
#pragma clang diagnostic pop
            
            [queryStringDictionary setObject:value forKey:key];
        }
    }
    
    return queryStringDictionary;
}

+ (bool)stringContainsEmoji:(NSString *)string
{
    __block bool returnValue = NO;
    [string enumerateSubstringsInRange:NSMakeRange(0, [string length]) options:NSStringEnumerationByComposedCharacterSequences usingBlock:
     ^(NSString *substring, __unused NSRange substringRange, __unused NSRange enclosingRange, __unused BOOL *stop)
    {
         const unichar hs = [substring characterAtIndex:0];

         if (0xd800 <= hs && hs <= 0xdbff)
         {
             if (substring.length > 1)
             {
                 const unichar ls = [substring characterAtIndex:1];
                 const int uc = ((hs - 0xd800) * 0x400) + (ls - 0xdc00) + 0x10000;
                 if (0x1d000 <= uc && uc <= 0x1f77f)
                 {
                     returnValue = YES;
                 }
             }
         } else if (substring.length > 1)
         {
             const unichar ls = [substring characterAtIndex:1];
             if (ls == 0x20e3)
             {
                 returnValue = YES;
             }
             
         } else
         {
             if (0x2100 <= hs && hs <= 0x27ff)
             {
                 returnValue = YES;
             } else if (0x2B05 <= hs && hs <= 0x2b07)
             {
                 returnValue = YES;
             } else if (0x2934 <= hs && hs <= 0x2935)
             {
                 returnValue = YES;
             } else if (0x3297 <= hs && hs <= 0x3299)
             {
                 returnValue = YES;
             } else if (hs == 0xa9 || hs == 0xae || hs == 0x303d || hs == 0x3030 || hs == 0x2b55 || hs == 0x2b1c || hs == 0x2b1b || hs == 0x2b50)
             {
                 returnValue = YES;
             }
         }
        
        if (returnValue && stop != NULL)
            *stop = true;
     }];
    
    return returnValue;
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

+ (NSString *)stringForMessageTimerSeconds:(NSUInteger)seconds
{
    if (seconds < 60)
    {
        int number = (int)seconds;
        
        return [legacyEffectiveLocalization() getPluralized:@"MessageTimer.Seconds" count:(int32_t)number];
    }
    else if (seconds < 60 * 60)
    {
        int number = (int)seconds / 60;
        
        return [legacyEffectiveLocalization() getPluralized:@"MessageTimer.Minutes" count:(int32_t)number];
    }
    else if (seconds < 60 * 60 * 24)
    {
        int number = (int)seconds / (60 * 60);
        
        return [legacyEffectiveLocalization() getPluralized:@"MessageTimer.Hours" count:(int32_t)number];
    }
    else if (seconds < 60 * 60 * 24 * 7)
    {
        int number = (int)seconds / (60 * 60 * 24);
        
        return [legacyEffectiveLocalization() getPluralized:@"MessageTimer.Days" count:(int32_t)number];
    }
    else if (seconds < 60 * 60 * 24 * 7 * 4)
    {
        int number = (int)seconds / (60 * 60 * 24 * 7);

        return [legacyEffectiveLocalization() getPluralized:@"MessageTimer.Weeks" count:(int32_t)number];
    }
    else
    {
        int number = MAX(1, (int)ceilf((int)(seconds / (60 * 60 * 24 * 29))));
        
        return [legacyEffectiveLocalization() getPluralized:@"MessageTimer.Months" count:(int32_t)number];
    }
    
    return @"";
}

+ (NSString *)stringForShortMessageTimerSeconds:(NSUInteger)seconds
{
    if (seconds < 60)
    {
        int number = (int)seconds;
        
        return [legacyEffectiveLocalization() getPluralized:@"MessageTimer.ShortSeconds" count:(int32_t)number];
    }
    else if (seconds < 60 * 60)
    {
        int number = (int)seconds / 60;
        
        return [legacyEffectiveLocalization() getPluralized:@"MessageTimer.ShortMinutes" count:(int32_t)number];
    }
    else if (seconds < 60 * 60 * 24)
    {
        int number = (int)seconds / (60 * 60);
        
        return [legacyEffectiveLocalization() getPluralized:@"MessageTimer.ShortHours" count:(int32_t)number];
    }
    else if (seconds < 60 * 60 * 24 * 7)
    {
        int number = (int)seconds / (60 * 60 * 24);
        
        return [legacyEffectiveLocalization() getPluralized:@"MessageTimer.ShortDays" count:(int32_t)number];
    }
    else
    {
        int number = (int)seconds / (60 * 60 * 24 * 7);
        
        return [legacyEffectiveLocalization() getPluralized:@"MessageTimer.ShortWeeks" count:(int32_t)number];
    }
    
    return @"";
}

+ (NSArray *)stringComponentsForMessageTimerSeconds:(NSUInteger)seconds
{
    NSString *first = @"";
    NSString *second = @"";
    
    if (seconds < 60)
    {
        int number = (int)seconds;
        
        NSString *format = TGLocalized([self integerValueFormat:@"MessageTimer.Seconds_" value:number]);
        
        NSRange range = [format rangeOfString:@"%@"];
        if (range.location != NSNotFound)
        {
            first = [[NSString alloc] initWithFormat:@"%d", number];
            second = [[format substringFromIndex:range.location + range.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        } else {
            first = format;
        }
    }
    else if (seconds < 60 * 60)
    {
        int number = (int)seconds / 60;

        NSString *format = TGLocalized([self integerValueFormat:@"MessageTimer.Minutes_" value:number]);
        
        NSRange range = [format rangeOfString:@"%@"];
        if (range.location != NSNotFound)
        {
            first = [[NSString alloc] initWithFormat:@"%d", number];
            second = [[format substringFromIndex:range.location + range.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        } else {
            first = format;
        }
    }
    else if (seconds < 60 * 60 * 24)
    {
        int number = (int)seconds / (60 * 60);

        NSString *format = TGLocalized([self integerValueFormat:@"MessageTimer.Hours_" value:number]);
        
        NSRange range = [format rangeOfString:@"%@"];
        if (range.location != NSNotFound)
        {
            first = [[NSString alloc] initWithFormat:@"%d", number];
            second = [[format substringFromIndex:range.location + range.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        } else {
            first = format;
        }
    }
    else if (seconds < 60 * 60 * 24 * 7)
    {
        int number = (int)seconds / (60 * 60 * 24);

        NSString *format = TGLocalized([self integerValueFormat:@"MessageTimer.Days_" value:number]);
        
        NSRange range = [format rangeOfString:@"%@"];
        if (range.location != NSNotFound)
        {
            first = [[NSString alloc] initWithFormat:@"%d", number];
            second = [[format substringFromIndex:range.location + range.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        } else {
            first = format;
        }
    }
    else if (seconds < 60 * 60 * 24 * 30)
    {
        int number = (int)seconds / (60 * 60 * 24 * 7);
        
        NSString *format = TGLocalized([self integerValueFormat:@"MessageTimer.Weeks_" value:number]);
        
        NSRange range = [format rangeOfString:@"%@"];
        if (range.location != NSNotFound)
        {
            first = [[NSString alloc] initWithFormat:@"%d", number];
            second = [[format substringFromIndex:range.location + range.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        } else {
            first = format;
        }
    }
    else
    {
        int number = (int)ceilf((seconds / (60 * 60 * 24 * 30.5f)));
        
        NSString *format = TGLocalized([self integerValueFormat:@"MessageTimer.Months_" value:number]);
        
        NSRange range = [format rangeOfString:@"%@"];
        if (range.location != NSNotFound)
        {
            first = [[NSString alloc] initWithFormat:@"%d", number];
            second = [[format substringFromIndex:range.location + range.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        } else {
            first = format;
        }
    }
    
    return @[first, second];
}

+ (NSString *)stringForCallDurationSeconds:(NSUInteger)seconds
{
    if (seconds < 60)
    {
        int number = (int)seconds;
        
        return [legacyEffectiveLocalization() getPluralized:@"Call.Seconds" count:number];
    }
    else
    {
        int number = (int)seconds / 60;
        
        return [legacyEffectiveLocalization() getPluralized:@"Call.Minutes" count:number];
    }
}

+ (NSString *)stringForShortCallDurationSeconds:(NSUInteger)seconds
{
    if (seconds < 60)
    {
        int number = (int)seconds;
        
        return [legacyEffectiveLocalization() getPluralized:@"Call.ShortSeconds" count:(int32_t)number];
    }
    else
    {
        int number = (int)seconds / 60;
        
        return [legacyEffectiveLocalization() getPluralized:@"Call.ShortMinutes" count:(int32_t)number];
    }
}

+ (NSString *)stringForUserCount:(NSUInteger)userCount
{
    NSUInteger number = userCount;
    
    return [legacyEffectiveLocalization() getPluralized:@"UserCount" count:(int32_t)number];
}

+ (NSString *)stringForFileSize:(int64_t)size
{
    NSString *format = @"";
    float floatSize = size;
    bool useFloat = false;
    
    if (floatSize < 1024)
        format = TGLocalized(@"FileSize.B");
    else if (size < 1024 * 1024)
    {
        format = TGLocalized(@"FileSize.KB");
        floatSize = size / 1024;
    }
    else if (size < 1024 * 1024 * 1024)
    {
        format = TGLocalized(@"FileSize.MB");
        floatSize = size / (1024 * 1024);
    } else {
        format = TGLocalized(@"FileSize.GB");
        floatSize = size / (1024.0f * 1024.0f * 1024.0f);
        useFloat = true;
    }
    
    if (useFloat) {
        return [[NSString alloc] initWithFormat:format, [[NSString alloc] initWithFormat:@"%0.1f", floatSize]];
    } else {
        return [[NSString alloc] initWithFormat:format, [[NSString alloc] initWithFormat:@"%d", (int)floatSize]];
    }
}

+ (NSString *)stringForFileSize:(int64_t)size precision:(NSInteger)precision
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

+ (NSString *)integerValueFormat:(NSString *)prefix value:(NSInteger)value
{
    TGLocalization *localization = legacyEffectiveLocalization();
    NSString *form = @"any";
    switch (TGPluralForm(localization.languageCodeHash, (int)value)) {
        case TGPluralFormZero:
            form = @"0";
            break;
        case TGPluralFormOne:
            form = @"1";
            break;
        case TGPluralFormTwo:
            form = @"2";
            break;
        case TGPluralFormFew:
            form = @"3_10";
            break;
        case TGPluralFormMany:
            form = @"many";
            break;
        case TGPluralFormOther:
            form = @"any";
            break;
        default:
            break;
    }
    
    NSString *result = [prefix stringByAppendingString:form];
    if ([localization contains:result]) {
        return result;
    } else {
        return [prefix stringByAppendingString:@"any"];
    }
}

+ (NSString *)stringForMuteInterval:(int)value
{
    value = MAX(1 * 60, value);
    
    if (value < 24 * 60 * 60)
    {
        value /= 60 * 60;
        NSString *format = TGLocalized([self integerValueFormat:@"MuteFor.Hours_" value:value]);
        return [[NSString alloc] initWithFormat:format, [[NSString alloc] initWithFormat:@"%d", value]];
    }
    else
    {
        value /= 24 * 60 * 60;
        NSString *format = TGLocalized([self integerValueFormat:@"MuteFor.Days_" value:value]);
        return [[NSString alloc] initWithFormat:format, [[NSString alloc] initWithFormat:@"%d", value]];
    }
    
    return @"";
}

+ (NSString *)stringForRemainingMuteInterval:(int)value
{
    value = MAX(1 * 60, value);
    
    if (value <= 1 * 60 * 60)
    {
        value = (int)roundf(value / 60.0f);
        NSString *format = TGLocalized([self integerValueFormat:@"MuteExpires.Minutes_" value:value]);
        return [[NSString alloc] initWithFormat:format, [[NSString alloc] initWithFormat:@"%d", value]];
    }
    else if (value <= 24 * 60 * 60)
    {
        value = (int)roundf(value / (60.0f * 60.0f));
        NSString *format = TGLocalized([self integerValueFormat:@"MuteExpires.Hours_" value:value]);
        return [[NSString alloc] initWithFormat:format, [[NSString alloc] initWithFormat:@"%d", value]];
    }
    else
    {
        value = (int)roundf(value / (24.0f * 60.0f * 60.0f));
        NSString *format = TGLocalized([self integerValueFormat:@"MuteExpires.Days_" value:value]);
        return [[NSString alloc] initWithFormat:format, [[NSString alloc] initWithFormat:@"%d", value]];
    }
    
    return @"";
}

+ (NSString *)stringForDeviceType
{
    NSString *model = @"iPhone";
    NSString *rawModel = [[[UIDevice currentDevice] model] lowercaseString];
    if ([rawModel rangeOfString:@"ipod"].location != NSNotFound)
        model = @"iPod";
    else if ([rawModel rangeOfString:@"ipad"].location != NSNotFound)
        model = @"iPad";
    
    return model;
}

+ (NSString *)stringForCurrency:(NSString *)__unused currency amount:(int64_t)__unused amount {
    return nil;
}

+ (NSString *)stringForEmojiHashOfData:(NSData *)data count:(NSInteger)count positionExtractor:(int32_t (^)(uint8_t *, int32_t, int32_t))positionExtractor
{
    if (data.length != 32)
        return @"";
    
    NSArray *emojis = @[ @"😉", @"😍", @"😛", @"😭", @"😱", @"😡", @"😎", @"😴", @"😵", @"😈", @"😬", @"😇", @"😏", @"👮", @"👷", @"💂", @"👶", @"👨", @"👩", @"👴", @"👵", @"😻", @"😽", @"🙀", @"👺", @"🙈", @"🙉", @"🙊", @"💀", @"👽", @"💩", @"🔥", @"💥", @"💤", @"👂", @"👀", @"👃", @"👅", @"👄", @"👍", @"👎", @"👌", @"👊", @"✌️", @"✋️", @"👐", @"👆", @"👇", @"👉", @"👈", @"🙏", @"👏", @"💪", @"🚶", @"🏃", @"💃", @"👫", @"👪", @"👬", @"👭", @"💅", @"🎩", @"👑", @"👒", @"👟", @"👞", @"👠", @"👕", @"👗", @"👖", @"👙", @"👜", @"👓", @"🎀", @"💄", @"💛", @"💙", @"💜", @"💚", @"💍", @"💎", @"🐶", @"🐺", @"🐱", @"🐭", @"🐹", @"🐰", @"🐸", @"🐯", @"🐨", @"🐻", @"🐷", @"🐮", @"🐗", @"🐴", @"🐑", @"🐘", @"🐼", @"🐧", @"🐥", @"🐔", @"🐍", @"🐢", @"🐛", @"🐝", @"🐜", @"🐞", @"🐌", @"🐙", @"🐚", @"🐟", @"🐬", @"🐋", @"🐐", @"🐊", @"🐫", @"🍀", @"🌹", @"🌻", @"🍁", @"🌾", @"🍄", @"🌵", @"🌴", @"🌳", @"🌞", @"🌚", @"🌙", @"🌎", @"🌋", @"⚡️", @"☔️", @"❄️", @"⛄️", @"🌀", @"🌈", @"🌊", @"🎓", @"🎆", @"🎃", @"👻", @"🎅", @"🎄", @"🎁", @"🎈", @"🔮", @"🎥", @"📷", @"💿", @"💻", @"☎️", @"📡", @"📺", @"📻", @"🔉", @"🔔", @"⏳", @"⏰", @"⌚️", @"🔒", @"🔑", @"🔎", @"💡", @"🔦", @"🔌", @"🔋", @"🚿", @"🚽", @"🔧", @"🔨", @"🚪", @"🚬", @"💣", @"🔫", @"🔪", @"💊", @"💉", @"💰", @"💵", @"💳", @"✉️", @"📫", @"📦", @"📅", @"📁", @"✂️", @"📌", @"📎", @"✒️", @"✏️", @"📐", @"📚", @"🔬", @"🔭", @"🎨", @"🎬", @"🎤", @"🎧", @"🎵", @"🎹", @"🎻", @"🎺", @"🎸", @"👾", @"🎮", @"🃏", @"🎲", @"🎯", @"🏈", @"🏀", @"⚽️", @"⚾️", @"🎾", @"🎱", @"🏉", @"🎳", @"🏁", @"🏇", @"🏆", @"🏊", @"🏄", @"☕️", @"🍼", @"🍺", @"🍷", @"🍴", @"🍕", @"🍔", @"🍟", @"🍗", @"🍱", @"🍚", @"🍜", @"🍡", @"🍳", @"🍞", @"🍩", @"🍦", @"🎂", @"🍰", @"🍪", @"🍫", @"🍭", @"🍯", @"🍎", @"🍏", @"🍊", @"🍋", @"🍒", @"🍇", @"🍉", @"🍓", @"🍑", @"🍌", @"🍐", @"🍍", @"🍆", @"🍅", @"🌽", @"🏡", @"🏥", @"🏦", @"⛪️", @"🏰", @"⛺️", @"🏭", @"🗻", @"🗽", @"🎠", @"🎡", @"⛲️", @"🎢", @"🚢", @"🚤", @"⚓️", @"🚀", @"✈️", @"🚁", @"🚂", @"🚋", @"🚎", @"🚌", @"🚙", @"🚗", @"🚕", @"🚛", @"🚨", @"🚔", @"🚒", @"🚑", @"🚲", @"🚠", @"🚜", @"🚦", @"⚠️", @"🚧", @"⛽️", @"🎰", @"🗿", @"🎪", @"🎭", @"🇯🇵", @"🇰🇷", @"🇩🇪", @"🇨🇳", @"🇺🇸", @"🇫🇷", @"🇪🇸", @"🇮🇹", @"🇷🇺", @"🇬🇧", @"1️⃣", @"2️⃣", @"3️⃣", @"4️⃣", @"5️⃣", @"6️⃣", @"7️⃣", @"8️⃣", @"9️⃣", @"0️⃣", @"🔟", @"❗️", @"❓", @"♥️", @"♦️", @"💯", @"🔗", @"🔱", @"🔴", @"🔵", @"🔶", @"🔷" ];
    
    uint8_t bytes[32];
    [data getBytes:bytes length:32];
    
    NSString *result = @"";
    for (int32_t i = 0; i < count; i++)
    {
        int32_t position = positionExtractor(bytes, i, (int32_t)emojis.count);
        NSString *emoji = emojis[position];
        result = [result stringByAppendingString:emoji];
    }
    
    return result;
}

@end

#if defined(_MSC_VER)

#define FORCE_INLINE    __forceinline

#include <stdlib.h>

#define ROTL32(x,y)     _rotl(x,y)
#define ROTL64(x,y)     _rotl64(x,y)

#define BIG_CONSTANT(x) (x)

// Other compilers

#else   // defined(_MSC_VER)

#define FORCE_INLINE __attribute__((always_inline))

static inline uint32_t rotl32 ( uint32_t x, int8_t r )
{
    return (x << r) | (x >> (32 - r));
}

#define ROTL32(x,y)     rotl32(x,y)
#define ROTL64(x,y)     rotl64(x,y)

#define BIG_CONSTANT(x) (x##LLU)

#endif // !defined(_MSC_VER)

//-----------------------------------------------------------------------------
// Block read - if your platform needs to do endian-swapping or can only
// handle aligned reads, do the conversion here

static FORCE_INLINE uint32_t getblock ( const uint32_t * p, int i )
{
    return p[i];
}

//-----------------------------------------------------------------------------
// Finalization mix - force all bits of a hash block to avalanche

static FORCE_INLINE uint32_t fmix ( uint32_t h )
{
    h ^= h >> 16;
    h *= 0x85ebca6b;
    h ^= h >> 13;
    h *= 0xc2b2ae35;
    h ^= h >> 16;
    
    return h;
}

//----------

//-----------------------------------------------------------------------------

static void MurmurHash3_x86_32 ( const void * key, int len,
                         uint32_t seed, void * out )
{
    const uint8_t * data = (const uint8_t*)key;
    const int nblocks = len / 4;
    
    uint32_t h1 = seed;
    
    const uint32_t c1 = 0xcc9e2d51;
    const uint32_t c2 = 0x1b873593;
    
    //----------
    // body
    
    const uint32_t * blocks = (const uint32_t *)(data + nblocks*4);
    
    for(int i = -nblocks; i; i++)
    {
        uint32_t k1 = getblock(blocks,i);
        
        k1 *= c1;
        k1 = ROTL32(k1,15);
        k1 *= c2;
        
        h1 ^= k1;
        h1 = ROTL32(h1,13);
        h1 = h1*5+0xe6546b64;
    }
    
    //----------
    // tail
    
    const uint8_t * tail = (const uint8_t*)(data + nblocks*4);
    
    uint32_t k1 = 0;
    
    switch(len & 3)
    {
        case 3: k1 ^= tail[2] << 16;
        case 2: k1 ^= tail[1] << 8;
        case 1: k1 ^= tail[0];
            k1 *= c1; k1 = ROTL32(k1,15); k1 *= c2; h1 ^= k1;
    };
    
    //----------
    // finalization
    
    h1 ^= len;
    
    h1 = fmix(h1);
    
    *(uint32_t*)out = h1;
}

int32_t legacy_murMurHash32(NSString *string)
{
    const char *utf8 = string.UTF8String;
    
    int32_t result = 0;
    MurmurHash3_x86_32((uint8_t *)utf8, (int)strlen(utf8), -137723950, &result);
    
    return result;
}

int32_t legacy_murMurHashBytes32(void *bytes, int length)
{
    int32_t result = 0;
    MurmurHash3_x86_32(bytes, length, -137723950, &result);
    
    return result;
}

int32_t phoneMatchHash(NSString *phone)
{
    int length = (int)phone.length;
    char cleanString[length];
    int cleanLength = 0;
    
    for (int i = 0; i < length; i++)
    {
        unichar c = [phone characterAtIndex:i];
        if (c >= '0' && c <= '9')
            cleanString[cleanLength++] = (char)c;
    }
    
    int32_t result = 0;
    if (cleanLength > 8)
        MurmurHash3_x86_32((uint8_t *)cleanString + (cleanLength - 8), 8, -137723950, &result);
    else
        MurmurHash3_x86_32((uint8_t *)cleanString, cleanLength, -137723950, &result);
    
    return result;
}

bool TGIsRTL()
{
    static bool value = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        value = ([NSLocale characterDirectionForLanguage:[[NSLocale preferredLanguages] objectAtIndex:0]] == NSLocaleLanguageDirectionRightToLeft);
    });
    
    if (!value && iosMajorVersion() >= 9)
        value = [UIView appearance].semanticContentAttribute == UISemanticContentAttributeForceRightToLeft;
    
    return value;
}

bool TGIsArabic()
{
    static bool value = false;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSString *language = [[NSLocale preferredLanguages] objectAtIndex:0];
        value = [language isEqualToString:@"ar"] || [language hasPrefix:@"ar-"];
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
        value = [language isEqualToString:@"ko"] || [language hasPrefix:@"ko-"];
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
        value = [identifier isEqualToString:@"ar"] || [identifier hasPrefix:@"ar-"];
    });
    return value;
}

@implementation NSString (Telegraph)

- (int)lengthByComposedCharacterSequences
{
    return [self lengthByComposedCharacterSequencesInRange:NSMakeRange(0, self.length)];
}

- (int)lengthByComposedCharacterSequencesInRange:(NSRange)range
{
    __block NSInteger length = 0;
    [self enumerateSubstringsInRange:range options:NSStringEnumerationByComposedCharacterSequences usingBlock:^(__unused NSString *substring, __unused NSRange substringRange, __unused NSRange enclosingRange, __unused BOOL *stop)
    {
        if (substring.length != 0)
            length++;
        //TGLegacyLog(@"substringRange %@, enclosingRange %@, length %d", NSStringFromRange(substringRange), NSStringFromRange(enclosingRange), length);
    }];
    //TGLegacyLog(@"length %d", length);
    
    return (int)length;
}

- (bool)hasNonWhitespaceCharacters
{
    NSInteger textLength = self.length;
    bool hasNonWhitespace = false;
    for (int i = 0; i < textLength; i++)
    {
        unichar c = [self characterAtIndex:i];
        if (c != ' ' && c != '\n' && c != '\t' && c != NSAttachmentCharacter)
        {
            hasNonWhitespace = true;
            break;
        }
    }
    return hasNonWhitespace;
}

- (NSAttributedString *)attributedFormattedStringWithRegularFont:(UIFont *)regularFont boldFont:(UIFont *)boldFont lineSpacing:(CGFloat)lineSpacing paragraphSpacing:(CGFloat)paragraphSpacing alignment:(NSTextAlignment)alignment
{
    NSMutableArray *boldRanges = [[NSMutableArray alloc] init];
    
    NSMutableString *cleanText = [[NSMutableString alloc] initWithString:self];
    while (true)
    {
        NSRange startRange = [cleanText rangeOfString:@"**"];
        if (startRange.location == NSNotFound)
            break;
        
        [cleanText deleteCharactersInRange:startRange];
        
        NSRange endRange = [cleanText rangeOfString:@"**"];
        if (endRange.location == NSNotFound)
            break;
        
        [cleanText deleteCharactersInRange:endRange];
        
        [boldRanges addObject:[NSValue valueWithRange:NSMakeRange(startRange.location, endRange.location - startRange.location)]];
    }
    
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineSpacing = lineSpacing;
    style.lineBreakMode = NSLineBreakByWordWrapping;
    style.alignment = alignment;
    style.paragraphSpacing = paragraphSpacing;
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:cleanText attributes:@
    {
    }];
    
    [attributedString addAttributes:@{NSParagraphStyleAttributeName: style, NSFontAttributeName: regularFont} range:NSMakeRange(0, attributedString.length)];
    
    NSDictionary *boldAttributes = @{NSFontAttributeName: boldFont};
    for (NSValue *nRange in boldRanges)
    {
        [attributedString addAttributes:boldAttributes range:[nRange rangeValue]];
    }
    
    return attributedString;
}

- (NSString *)urlAnchorPart {
    NSURL *url = [[NSURL alloc] initWithString:self];
    return [url fragment];
}

static unsigned char strToChar (char a, char b)
{
    char encoder[3] = {'\0','\0','\0'};
    encoder[0] = a;
    encoder[1] = b;
    return (char)strtol(encoder,NULL,16);
}

- (NSData *)dataByDecodingHexString
{
    const char *bytes = [self cStringUsingEncoding:NSUTF8StringEncoding];
    NSUInteger length = strlen(bytes);
    unsigned char *r = (unsigned char *)malloc(length / 2);
    unsigned char *index = r;
    
    while ((*bytes) && (*(bytes + 1)))
    {
        *index = strToChar(*bytes, *(bytes +1));
        index++;
        bytes+=2;
    }
    
    return [[NSData alloc] initWithBytesNoCopy:r length:length / 2 freeWhenDone:true];
}


- (bool)containsSingleEmoji
{
    if (self.length > 0 && self.length < 16)
    {
        NSArray *emojis = [self emojiArray:false];
        return emojis.count == 1 && [emojis.firstObject isEqualToString:self];
    }
    return false;
}

- (bool)isEmoji
{
    static dispatch_once_t onceToken;
    static NSCharacterSet *variationSelectors;
    dispatch_once(&onceToken, ^
    {
        variationSelectors = [NSCharacterSet characterSetWithRange:NSMakeRange(0xFE00, 16)];
    });
    
    if ([self rangeOfCharacterFromSet:variationSelectors].location != NSNotFound)
        return true;
    
    const unichar high = [self characterAtIndex:0];
    if (0xd800 <= high && high <= 0xdbff)
    {
        if (self.length < 2)
            return false;
        
        const unichar low = [self characterAtIndex:1];
        const int codepoint = ((high - 0xd800) * 0x400) + (low - 0xdc00) + 0x10000;
        return (0x1d000 <= codepoint && codepoint <= 0x1f77f) || (0x1F900 <= codepoint && codepoint <= 0x1f9ff);
    }
    else
    {
        return (0x2100 <= high && high <= 0x27BF);
    }
}

- (NSArray *)emojiArray:(bool)stripModifiers
{
    __block NSMutableArray *emoji = [[NSMutableArray alloc] init];
    [self enumerateSubstringsInRange: NSMakeRange(0, [self length]) options:NSStringEnumerationByComposedCharacterSequences usingBlock:
     ^(NSString *substring, __unused NSRange substringRange, __unused NSRange enclosingRange, __unused BOOL *stop)
    {
        if ([substring isEmoji])
        {
            if (substring.length > 2 && stripModifiers)
            {
                for (int i = 1; i < substring.length - 1; i++)
                {
                    NSString *test = [substring substringToIndex:i];
                    if ([test isEmoji])
                    {
                        [emoji addObject:test];
                        break;
                    }
                }
            }
            else
            {
                [emoji addObject:substring];
            }
        }
    }];
    return emoji;
}

@end

@implementation NSData (Telegraph)

+ (NSData *)dataWithHexString:(NSString *)hex
{
    char buf[3];
    buf[2] = '\0';
    NSAssert(0 == [hex length] % 2, @"Hex strings should have an even number of digits (%@)", hex);
    uint8_t *bytes = (uint8_t *)malloc(hex.length / 2);
    uint8_t *bp = bytes;
    for (CFIndex i = 0; i < [hex length]; i += 2) {
        buf[0] = [hex characterAtIndex:i];
        buf[1] = [hex characterAtIndex:i+1];
        char *b2 = NULL;
        *bp++ = strtol(buf, &b2, 16);
        NSAssert(b2 == buf + 2, @"String should be all hex digits: %@ (bad digit around %d)", hex, (int)i);
    }
    
    return [NSData dataWithBytesNoCopy:bytes length:[hex length]/2 freeWhenDone:YES];
}

- (NSString *)stringByEncodingInHex
{
    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];
    if (dataBuffer == NULL)
        return [NSString string];
    
    NSUInteger dataLength  = [self length];
    NSMutableString *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    for (int i = 0; i < (int)dataLength; ++i)
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    
    return hexString;
}

- (NSString *)stringByEncodingInHexSeparatedByString:(NSString *)string
{
    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];
    if (dataBuffer == NULL)
        return [NSString string];
    
    NSUInteger dataLength  = [self length];
    NSMutableString *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];
    
    NSString *divider = string;
    for (int i = 0; i < (int)dataLength; ++i) {
        if (i == (int)dataLength - 1)
            divider = @"";
        else if (i == (int)dataLength / 2 - 1)
            divider = [divider stringByAppendingString:divider];
        else
            divider = string;
        
        [hexString appendString:[NSString stringWithFormat:@"%02lx%@", (unsigned long)dataBuffer[i], divider]];
    }
    return hexString;
}

@end
