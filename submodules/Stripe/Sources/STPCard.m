//
//  STPCard.m
//  Stripe
//
//  Created by Saikat Chakrabarti on 11/2/12.
//
//

#import "STPCard.h"
#import "NSDictionary+Stripe.h"
#import "NSString+Stripe_CardBrands.h"
#import "STPImageLibrary.h"
#import "STPImageLibrary+Private.h"

@interface STPCard ()

@property (nonatomic, readwrite) NSString *cardId;
@property (nonatomic, readwrite) NSString *last4;
@property (nonatomic, readwrite) NSString *dynamicLast4;
@property (nonatomic, readwrite) STPCardBrand brand;
@property (nonatomic, readwrite) STPCardFundingType funding;
@property (nonatomic, readwrite) NSString *fingerprint;
@property (nonatomic, readwrite) NSString *country;
@property (nonatomic, readwrite, nonnull, copy) NSDictionary *allResponseFields;

@end

@implementation STPCard

@dynamic number, cvc, expMonth, expYear, currency, name, addressLine1, addressLine2, addressCity, addressState, addressZip, addressCountry;

- (instancetype)initWithID:(NSString *)stripeID
                     brand:(STPCardBrand)brand
                     last4:(NSString *)last4
                  expMonth:(NSUInteger)expMonth
                   expYear:(NSUInteger)expYear
                   funding:(STPCardFundingType)funding {
    self = [super init];
    if (self) {
        _cardId = stripeID;
        _brand = brand;
        _last4 = last4;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
        self.expMonth = expMonth;
        self.expYear = expYear;
#pragma clang diagnostic pop
        _funding = funding;
    }
    return self;
}

+ (STPCardBrand)brandFromString:(NSString *)string {
    NSString *brand = [string lowercaseString];
    if ([brand isEqualToString:@"visa"]) {
        return STPCardBrandVisa;
    } else if ([brand isEqualToString:@"american express"]) {
        return STPCardBrandAmex;
    } else if ([brand isEqualToString:@"mastercard"]) {
        return STPCardBrandMasterCard;
    } else if ([brand isEqualToString:@"discover"]) {
        return STPCardBrandDiscover;
    } else if ([brand isEqualToString:@"jcb"]) {
        return STPCardBrandJCB;
    } else if ([brand isEqualToString:@"diners club"]) {
        return STPCardBrandDinersClub;
    } else if ([brand isEqualToString:@"other"]) {
        return STPCardBrandOther;
    } else {
        return STPCardBrandUnknown;
    }
}

+ (STPCardFundingType)fundingFromString:(NSString *)string {
    NSString *funding = [string lowercaseString];
    if ([funding isEqualToString:@"credit"]) {
        return STPCardFundingTypeCredit;
    } else if ([funding isEqualToString:@"debit"]) {
        return STPCardFundingTypeDebit;
    } else if ([funding isEqualToString:@"prepaid"]) {
        return STPCardFundingTypePrepaid;
    } else {
        return STPCardFundingTypeOther;
    }
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _brand = STPCardBrandUnknown;
        _funding = STPCardFundingTypeOther;
    }

    return self;
}

- (NSString *)last4 {
    return _last4 ?: [super last4];
}

- (BOOL)isApplePayCard {
    return [self.allResponseFields[@"tokenization_method"] isEqualToString:@"apple_pay"];
}

- (NSString *)type {
    switch (self.brand) {
    case STPCardBrandAmex:
        return @"American Express";
    case STPCardBrandDinersClub:
        return @"Diners Club";
    case STPCardBrandDiscover:
        return @"Discover";
    case STPCardBrandJCB:
        return @"JCB";
    case STPCardBrandMasterCard:
        return @"MasterCard";
    case STPCardBrandVisa:
        return @"Visa";
    case STPCardBrandOther:
        return @"Other";
    default:
        return @"Unknown";
    }
}

- (BOOL)isEqual:(id)other {
    return [self isEqualToCard:other];
}

- (NSUInteger)hash {
    return [self.cardId hash];
}

- (BOOL)isEqualToCard:(STPCard *)other {
    if (self == other) {
        return YES;
    }

    if (!other || ![other isKindOfClass:self.class]) {
        return NO;
    }
    
    return [self.cardId isEqualToString:other.cardId];
}

#pragma mark STPAPIResponseDecodable
+ (NSArray *)requiredFields {
    return @[@"id", @"last4", @"brand", @"exp_month", @"exp_year"];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
+ (instancetype)decodedObjectFromAPIResponse:(NSDictionary *)response {
    NSDictionary *dict = [response stp_dictionaryByRemovingNullsValidatingRequiredFields:[self requiredFields]];
    if (!dict) {
        return nil;
    }
    
    STPCard *card = [self new];
    card.cardId = dict[@"id"];
    card.name = dict[@"name"];
    card.last4 = dict[@"last4"];
    card.dynamicLast4 = dict[@"dynamic_last4"];
    NSString *brand = [dict[@"brand"] lowercaseString];
    card.brand = [self.class brandFromString:brand];
    NSString *funding = dict[@"funding"];
    card.funding = [self.class fundingFromString:funding];
    card.fingerprint = dict[@"fingerprint"];
    card.country = dict[@"country"];
    card.currency = dict[@"currency"];
    card.expMonth = [dict[@"exp_month"] intValue];
    card.expYear = [dict[@"exp_year"] intValue];
    card.addressLine1 = dict[@"address_line1"];
    card.addressLine2 = dict[@"address_line2"];
    card.addressCity = dict[@"address_city"];
    card.addressState = dict[@"address_state"];
    card.addressZip = dict[@"address_zip"];
    card.addressCountry = dict[@"address_country"];
    
    card.allResponseFields = dict;
    return card;
}
#pragma clang diagnostic pop

#pragma mark - STPSource

- (NSString *)stripeID {
    return self.cardId;
}

- (NSString *)label {
    NSString *brand = [NSString stp_stringWithCardBrand:self.brand];
    return [NSString stringWithFormat:@"%@ %@", brand, self.last4];
}

- (UIImage *)image {
    return [STPImageLibrary brandImageForCardBrand:self.brand];
}

- (UIImage *)templateImage {
    return [STPImageLibrary templatedBrandImageForCardBrand:self.brand];
}

@end
