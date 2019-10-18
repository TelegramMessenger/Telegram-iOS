#import "FormatPhoneNumber.h"

#import <libphonenumber/libphonenumber.h>

static NBPhoneNumberUtil *getNBPhoneNumberUtil() {
    static NBPhoneNumberUtil *value;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        value = [[NBPhoneNumberUtil alloc] init];
    });
    return value;
}

@implementation FormatPhoneNumber

+ (NSString *)cleanInternationalPhone:(NSString *)phone forceInternational:(bool)forceInternational {
    if (phone.length == 0) {
        return @"";
    }
    
    char buf[phone.length];
    int bufPtr = 0;
    
    bool hadPlus = false;
    int length = (int)phone.length;
    for (int i = 0; i < length; i++) {
        unichar c = [phone characterAtIndex:i];
        if ((c >= '0' && c <= '9') || (c == '+' && !hadPlus)) {
            buf[bufPtr++] = (char)c;
            if (c == '+') {
                hadPlus = true;
            }
        }
    }
    
    NSString *result = [[NSString alloc] initWithBytes:buf length:bufPtr encoding:NSUTF8StringEncoding];
    if (forceInternational && bufPtr != 0 && buf[0] != '+') {
        result = [[NSString alloc] initWithFormat:@"+%@", result];
    }
    return result;
}

+ (NSString *)formatPhoneNumber:(NSString *)number {
    NBPhoneNumber *parsed = [getNBPhoneNumberUtil() parse:[@"+" stringByAppendingString:number] defaultRegion:nil error:nil];
    if (parsed == nil) {
        return number;
    }
    NSString *result = [getNBPhoneNumberUtil() format:parsed numberFormat:NBEPhoneNumberFormatINTERNATIONAL error:nil];
    if (result == nil) {
        return number;
    }
    return result;
}

@end
