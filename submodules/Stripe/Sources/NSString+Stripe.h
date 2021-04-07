//
//  NSString+Stripe.h
//  Stripe
//
//  Created by Jack Flintermann on 10/16/15.
//  Copyright © 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Stripe)

- (NSString *)stp_safeSubstringToIndex:(NSUInteger)index;
- (NSString *)stp_safeSubstringFromIndex:(NSUInteger)index;
- (NSString *)stp_reversedString;

@end

void linkNSStringCategory(void);
