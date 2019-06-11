//
//  PKPayment+Stripe.h
//  Stripe
//
//  Created by Ben Guo on 7/2/15.
//

#import <PassKit/PassKit.h>

@interface PKPayment (Stripe)

/// Returns true if the instance is a payment from the simulator.
- (BOOL)stp_isSimulated;

/// Returns a fake transaction identifier with the expected ~-separated format.
+ (NSString *)stp_testTransactionIdentifier;

@end

void linkPKPaymentCategory(void);
