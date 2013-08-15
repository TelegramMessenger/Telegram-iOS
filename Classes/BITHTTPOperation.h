//
//  BITHTTPOperation.h
//  HockeySDK
//
//  Created by Stephan Diederich on 10.08.13.
//
//

#import <Foundation/Foundation.h>

@class BITHTTPOperation;
typedef void (^BITNetworkCompletionBlock)(BITHTTPOperation* operation, id response, NSError* error);

@interface BITHTTPOperation : NSOperation

+ (instancetype) operationWithRequest:(NSURLRequest *) urlRequest;

@property (nonatomic, readonly) NSURLRequest *URLRequest;

//the completion is only called if the operation wasn't cancelled
- (void) setCompletion:(BITNetworkCompletionBlock) completionBlock;

@property (nonatomic, readonly) NSHTTPURLResponse *response;
@property (nonatomic, readonly) NSData *data;
@property (nonatomic, readonly) NSError *error;

@end
