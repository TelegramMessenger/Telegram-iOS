//
//  STPCardValidator.m
//  Stripe
//
//  Created by Jack Flintermann on 7/15/15.
//  Copyright (c) 2015 Stripe, Inc. All rights reserved.
//

#import "STPCardValidator.h"
#import "STPBINRange.h"

@implementation STPCardValidator

+ (NSString *)sanitizedNumericStringForString:(NSString *)string {
    return stringByRemovingCharactersFromSet(string, invertedAsciiDigitCharacterSet());
}

static NSCharacterSet *invertedAsciiDigitCharacterSet() {
    static NSCharacterSet *cs;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cs = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet];
    });
    return cs;
}

+ (NSString *)stringByRemovingSpacesFromString:(NSString *)string {
    NSCharacterSet *set = [NSCharacterSet whitespaceCharacterSet];
    return stringByRemovingCharactersFromSet(string, set);
}

static NSString * _Nonnull stringByRemovingCharactersFromSet(NSString * _Nonnull string, NSCharacterSet * _Nonnull cs) {
    NSRange range = [string rangeOfCharacterFromSet:cs];
    if (range.location != NSNotFound) {
        NSMutableString *newString = [[string substringWithRange:NSMakeRange(0, range.location)] mutableCopy];
        NSUInteger lastPosition = NSMaxRange(range);
        while (lastPosition < string.length) {
            range = [string rangeOfCharacterFromSet:cs options:0 range:NSMakeRange(lastPosition, string.length - lastPosition)];
            if (range.location == NSNotFound) break;
            if (range.location != lastPosition) {
                [newString appendString:[string substringWithRange:NSMakeRange(lastPosition, range.location - lastPosition)]];
            }
            lastPosition = NSMaxRange(range);
        }
        if (lastPosition != string.length) {
            [newString appendString:[string substringWithRange:NSMakeRange(lastPosition, string.length - lastPosition)]];
        }
        return newString;
    } else {
        return string;
    }
}

+ (BOOL)stringIsNumeric:(NSString *)string {
    return [string rangeOfCharacterFromSet:invertedAsciiDigitCharacterSet()].location == NSNotFound;
}

+ (STPCardValidationState)validationStateForExpirationMonth:(NSString *)expirationMonth {

    NSString *sanitizedExpiration = [self stringByRemovingSpacesFromString:expirationMonth];
    
    if (![self stringIsNumeric:sanitizedExpiration]) {
        return STPCardValidationStateInvalid;
    }
    
    switch (sanitizedExpiration.length) {
        case 0:
            return STPCardValidationStateIncomplete;
        case 1:
            return ([sanitizedExpiration isEqualToString:@"0"] || [sanitizedExpiration isEqualToString:@"1"]) ? STPCardValidationStateIncomplete : STPCardValidationStateValid;
        case 2:
            return (0 < sanitizedExpiration.integerValue && sanitizedExpiration.integerValue <= 12) ? STPCardValidationStateValid : STPCardValidationStateInvalid;
        default:
            return STPCardValidationStateInvalid;
    }
}

+ (STPCardValidationState)validationStateForExpirationYear:(NSString *)expirationYear inMonth:(NSString *)expirationMonth inCurrentYear:(NSInteger)currentYear currentMonth:(NSInteger)currentMonth {
    
    NSInteger moddedYear = currentYear % 100;
    
    if (![self stringIsNumeric:expirationMonth] || ![self stringIsNumeric:expirationYear]) {
        return STPCardValidationStateInvalid;
    }
    
    NSString *sanitizedMonth = [self sanitizedNumericStringForString:expirationMonth];
    NSString *sanitizedYear = [self sanitizedNumericStringForString:expirationYear];
    
    switch (sanitizedYear.length) {
        case 0:
        case 1:
            return STPCardValidationStateIncomplete;
        case 2: {
            if (sanitizedYear.integerValue == moddedYear) {
                return sanitizedMonth.integerValue >= currentMonth ? STPCardValidationStateValid : STPCardValidationStateInvalid;
            } else {
                return sanitizedYear.integerValue > moddedYear ? STPCardValidationStateValid : STPCardValidationStateInvalid;
            }
        }
        default:
            return STPCardValidationStateInvalid;
    }
}


+ (STPCardValidationState)validationStateForExpirationYear:(NSString *)expirationYear
                                                   inMonth:(NSString *)expirationMonth {
    return [self validationStateForExpirationYear:expirationYear
                                          inMonth:expirationMonth
                                    inCurrentYear:[self currentYear]
                                     currentMonth:[self currentMonth]];
}


+ (STPCardValidationState)validationStateForCVC:(NSString *)cvc cardBrand:(STPCardBrand)brand {
    
    if (![self stringIsNumeric:cvc]) {
        return STPCardValidationStateInvalid;
    }
    
    NSString *sanitizedCvc = [self sanitizedNumericStringForString:cvc];
    
    NSUInteger minLength = [self minCVCLength];
    NSUInteger maxLength = [self maxCVCLengthForCardBrand:brand];
    if (sanitizedCvc.length < minLength) {
        return STPCardValidationStateIncomplete;
    }
    else if (sanitizedCvc.length > maxLength) {
        return STPCardValidationStateInvalid;
    }
    else {
        return STPCardValidationStateValid;
    }
}

+ (STPCardValidationState)validationStateForNumber:(nonnull NSString *)cardNumber
                               validatingCardBrand:(BOOL)validatingCardBrand {
    
    NSString *sanitizedNumber = [self stringByRemovingSpacesFromString:cardNumber];
    if (![self stringIsNumeric:sanitizedNumber]) {
        return STPCardValidationStateInvalid;
    }
    if (sanitizedNumber.length == 0) {
        return STPCardValidationStateIncomplete;
    }
    STPBINRange *binRange = [STPBINRange mostSpecificBINRangeForNumber:sanitizedNumber];
    if (binRange.brand == STPCardBrandUnknown && validatingCardBrand) {
        return STPCardValidationStateInvalid;
    }
    if (sanitizedNumber.length == binRange.length) {
        BOOL isValidLuhn = [self stringIsValidLuhn:sanitizedNumber];
        return isValidLuhn ? STPCardValidationStateValid : STPCardValidationStateInvalid;
    } else if (sanitizedNumber.length > binRange.length) {
        return STPCardValidationStateInvalid;
    } else {
        return STPCardValidationStateIncomplete;
    }
}

+ (STPCardValidationState)validationStateForCard:(nonnull STPCardParams *)card inCurrentYear:(NSInteger)currentYear currentMonth:(NSInteger)currentMonth {
    STPCardValidationState numberValidation = [self validationStateForNumber:card.number validatingCardBrand:YES];
    NSString *expMonthString = [NSString stringWithFormat:@"%02lu", (unsigned long)card.expMonth];
    STPCardValidationState expMonthValidation = [self validationStateForExpirationMonth:expMonthString];
    NSString *expYearString = [NSString stringWithFormat:@"%02lu", (unsigned long)card.expYear%100];
    STPCardValidationState expYearValidation = [self validationStateForExpirationYear:expYearString
                                                                              inMonth:expMonthString
                                                                        inCurrentYear:currentYear
                                                                         currentMonth:currentMonth];
    STPCardBrand brand = [self brandForNumber:card.number];
    STPCardValidationState cvcValidation = [self validationStateForCVC:card.cvc cardBrand:brand];

    NSArray<NSNumber *> *states = @[@(numberValidation),
                                    @(expMonthValidation),
                                    @(expYearValidation),
                                    @(cvcValidation)];
    BOOL incomplete = NO;
    for (NSNumber *boxedState in states) {
        STPCardValidationState state = [boxedState integerValue];
        if (state == STPCardValidationStateInvalid) {
            return state;
        }
        else if (state == STPCardValidationStateIncomplete) {
            incomplete = YES;
        }
    }
    return incomplete ? STPCardValidationStateIncomplete : STPCardValidationStateValid;
}

+ (STPCardValidationState)validationStateForCard:(STPCardParams *)card {
    return [self validationStateForCard:card
                          inCurrentYear:[self currentYear]
                           currentMonth:[self currentMonth]];
}

+ (NSUInteger)minCVCLength {
    return 3;
}

+ (NSUInteger)maxCVCLengthForCardBrand:(STPCardBrand)brand {
    switch (brand) {
        case STPCardBrandAmex:
        case STPCardBrandUnknown:
            return 4;
        default:
            return 3;
    }
}

+ (STPCardBrand)brandForNumber:(NSString *)cardNumber {
    NSString *sanitizedNumber = [self sanitizedNumericStringForString:cardNumber];
    NSSet *brands = [self possibleBrandsForNumber:sanitizedNumber];
    if (brands.count == 1) {
        return (STPCardBrand)[brands.anyObject integerValue];
    }
    return STPCardBrandUnknown;
}

+ (NSSet *)possibleBrandsForNumber:(NSString *)cardNumber {
    NSArray<STPBINRange *> *binRanges = [STPBINRange binRangesForNumber:cardNumber];
    NSMutableSet *possibleBrands = [NSMutableSet setWithArray:[binRanges valueForKeyPath:@"brand"]];
    [possibleBrands removeObject:@(STPCardBrandUnknown)];
    return [possibleBrands copy];
}

+ (NSSet<NSNumber *>*)lengthsForCardBrand:(STPCardBrand)brand {
    NSMutableSet *set = [NSMutableSet set];
    NSArray<STPBINRange *> *binRanges = [STPBINRange binRangesForBrand:brand];
    for (STPBINRange *binRange in binRanges) {
        [set addObject:@(binRange.length)];
    }
    return [set copy];
}

+ (NSInteger)lengthForCardBrand:(STPCardBrand)brand {
    return [self maxLengthForCardBrand:brand];
}

+ (NSInteger)maxLengthForCardBrand:(STPCardBrand)brand {
    NSInteger maxLength = -1;
    for (NSNumber *length in [self lengthsForCardBrand:brand]) {
        if (length.integerValue > maxLength) {
            maxLength = length.integerValue;
        }
    }
    return maxLength;
}

+ (NSInteger)fragmentLengthForCardBrand:(STPCardBrand)brand {
    switch (brand) {
        case STPCardBrandAmex:
            return 5;
        case STPCardBrandDinersClub:
            return 2;
        default:
            return 4;
    }
}

+ (BOOL)stringIsValidLuhn:(NSString *)number {
    BOOL odd = true;
    int sum = 0;
    NSMutableArray *digits = [NSMutableArray arrayWithCapacity:number.length];
    
    for (int i = 0; i < (NSInteger)number.length; i++) {
        [digits addObject:[number substringWithRange:NSMakeRange(i, 1)]];
    }
    
    for (NSString *digitStr in [digits reverseObjectEnumerator]) {
        int digit = [digitStr intValue];
        if ((odd = !odd)) digit *= 2;
        if (digit > 9) digit -= 9;
        sum += digit;
    }
    
    return sum % 10 == 0;
}

+ (NSInteger)currentYear {
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *dateComponents = [calendar components:NSCalendarUnitYear fromDate:[NSDate date]];
    return dateComponents.year % 100;
}

+ (NSInteger)currentMonth {
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    NSDateComponents *dateComponents = [calendar components:NSCalendarUnitMonth fromDate:[NSDate date]];
    return dateComponents.month;
}

@end
