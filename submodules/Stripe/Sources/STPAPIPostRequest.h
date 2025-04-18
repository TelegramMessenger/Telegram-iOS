//
//  STPAPIPostRequest.h
//  Stripe
//
//  Created by Jack Flintermann on 10/14/15.
//  Copyright © 2015 Stripe, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STPAPIResponseDecodable.h"
@class STPAPIClient;

@interface STPAPIPostRequest<__covariant ResponseType:id<STPAPIResponseDecodable>> : NSObject

typedef void(^STPAPIPostResponseBlock)(ResponseType object, NSHTTPURLResponse *response, NSError *error);

+ (void)startWithAPIClient:(STPAPIClient *)apiClient
                  endpoint:(NSString *)endpoint
                  postData:(NSData *)postData
                serializer:(ResponseType)serializer
                completion:(STPAPIPostResponseBlock)completion;

@end
