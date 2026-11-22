//
//  STPSource.h
//  Stripe
//
//  Created by Jack Flintermann on 1/15/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 *  A source represents a source of funds for your user that you can charge - for example, a card on file. Currently, only `STPCard` implements this interface, although future payment methods will use it as well. When implementing your server backend, you should pass the `stripeID` property to the Create Charge method as the `source` parameter.
 */
@protocol STPSource <NSObject>

/**
 *  The stripe ID of the source. When implementing your server backend, you should pass this property to the Create Charge method as the `source` parameter.
 */
@property(nonatomic, readonly, copy, nonnull)NSString *stripeID;

@end
