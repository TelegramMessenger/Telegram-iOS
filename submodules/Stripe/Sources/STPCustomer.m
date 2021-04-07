//
//  STPCustomer.m
//  Stripe
//
//  Created by Jack Flintermann on 6/9/16.
//  Copyright © 2016 Stripe, Inc. All rights reserved.
//

#import "STPCustomer.h"
#import "StripeError.h"
#import "STPCard.h"

@interface STPCustomer()

@property(nonatomic, copy)NSString *stripeID;
@property(nonatomic) id<STPSource> defaultSource;
@property(nonatomic) NSArray<id<STPSource>> *sources;

@end

@implementation STPCustomer

+ (instancetype)customerWithStripeID:(NSString *)stripeID
                       defaultSource:(id<STPSource>)defaultSource
                             sources:(NSArray<id<STPSource>> *)sources {
    STPCustomer *customer = [self new];
    customer.stripeID = stripeID;
    customer.defaultSource = defaultSource;
    customer.sources = sources;
    return customer;
}

@end

@interface STPCustomerDeserializer()

@property(nonatomic, nullable)STPCustomer *customer;
@property(nonatomic, nullable)NSError *error;

@end

@implementation STPCustomerDeserializer

- (instancetype)initWithData:(nullable NSData *)data
                 urlResponse:(nullable __unused NSURLResponse *)urlResponse
                       error:(nullable NSError *)error {
    if (error) {
        return [self initWithError:error];
    }
    NSError *jsonError;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    if (!json) {
        return [self initWithError:jsonError];
    }
    return [self initWithJSONResponse:json];
}

- (instancetype)initWithError:(NSError *)error {
    self = [super init];
    if (self) {
        _error = error;
    }
    return self;
}

- (instancetype)initWithJSONResponse:(id)json {
    self = [super init];
    if (self) {
        if (![json isKindOfClass:[NSDictionary class]] || ![json[@"id"] isKindOfClass:[NSString class]]) {
            _error = [NSError stp_genericFailedToParseResponseError];
            return self;
        }
        STPCustomer *customer = [STPCustomer new];
        customer.stripeID = json[@"id"];
        NSString *defaultSourceId;
        if ([json[@"default_source"] isKindOfClass:[NSString class]]) {
            defaultSourceId = json[@"default_source"];
        }
        NSMutableArray *sources = [NSMutableArray array];
        if ([json[@"sources"] isKindOfClass:[NSDictionary class]] && [json[@"sources"][@"data"] isKindOfClass:[NSArray class]]) {
            for (id contents in json[@"sources"][@"data"]) {
                if ([contents isKindOfClass:[NSDictionary class]]) {
                    // eventually support other source types
                    STPCard *card = [STPCard decodedObjectFromAPIResponse:contents];
                    // ignore apple pay cards from the response
                    if (card && !card.isApplePayCard) {
                        [sources addObject:card];
                        if (defaultSourceId && [card.stripeID isEqualToString:defaultSourceId]) {
                            customer.defaultSource = card;
                        }
                    }
                }
            }
            customer.sources = sources;
        }
        _customer = customer;
    }
    return self;
}

@end
