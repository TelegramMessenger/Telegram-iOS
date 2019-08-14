//
//  PKPayment+Stripe.m
//  Stripe
//
//  Created by Ben Guo on 7/2/15.
//

#import "PKPayment+Stripe.h"

@implementation PKPayment (Stripe)

- (BOOL)stp_isSimulated {
    return [self.token.transactionIdentifier isEqualToString:@"Simulated Identifier"];
}

+ (NSString *)stp_testTransactionIdentifier {
    NSString *uuid = [[NSUUID UUID] UUIDString];
    uuid = [uuid stringByReplacingOccurrencesOfString:@"~" withString:@""
                                              options:0
                                                range:NSMakeRange(0, uuid.length)];

    // Simulated cards don't have enough info yet. For now, use a fake Visa number
    NSString *number = @"4242424242424242";

    // Without the original PKPaymentRequest, we'll need to use fake data here.
    NSDecimalNumber *amount = [NSDecimalNumber decimalNumberWithString:@"0"];
    NSString *cents = [@([[amount decimalNumberByMultiplyingByPowerOf10:2] integerValue]) stringValue];
    NSString *currency = @"USD";
    NSString *identifier = [@[@"ApplePayStubs", number, cents, currency, uuid] componentsJoinedByString:@"~"];
    return identifier;
}

@end

void linkPKPaymentCategory(void){}
