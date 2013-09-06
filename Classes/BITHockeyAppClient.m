//
//  BITHockeyAppClient.m
//  HockeySDK
//
//  Created by Stephan Diederich on 06.09.13.
//
//

#import "BITHockeyAppClient.h"

@implementation BITHockeyAppClient
- (void)dealloc {
  [self cancelOperationsWithPath:nil method:nil];
}

- (instancetype)initWithBaseURL:(NSURL *)baseURL {
  self = [super init];
  if ( self ) {
    NSParameterAssert(baseURL);
    _baseURL = baseURL;
  }
  return self;
}

#pragma mark - Networking
- (NSMutableURLRequest *) requestWithMethod:(NSString*) method
                                       path:(NSString *) path
                                 parameters:(NSDictionary *)params {
  NSParameterAssert(self.baseURL);
  NSParameterAssert(method);
  NSParameterAssert(params == nil || [method isEqualToString:@"POST"] || [method isEqualToString:@"GET"]);
  path = path ? : @"";
  
  NSURL *endpoint = [self.baseURL URLByAppendingPathComponent:path];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:endpoint];
  request.HTTPMethod = method;
  
  if (params) {
    if ([method isEqualToString:@"GET"]) {
      NSString *absoluteURLString = [endpoint absoluteString];
      //either path already has parameters, or not
      NSString *appenderFormat = [path rangeOfString:@"?"].location == NSNotFound ? @"?%@" : @"&%@";
      
      endpoint = [NSURL URLWithString:[absoluteURLString stringByAppendingFormat:appenderFormat,
                                       [self.class queryStringFromParameters:params withEncoding:NSUTF8StringEncoding]]];
      [request setURL:endpoint];
    } else {
      //TODO: this is crap. Boundary must be the same as the one in appendData
      //unify this!
      NSString *boundary = @"----FOO";
      NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
      [request setValue:contentType forHTTPHeaderField:@"Content-type"];
      
      NSMutableData *postBody = [NSMutableData data];
      [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        [postBody appendData:[[self class] dataWithPostValue:value forKey:key boundary:boundary]];
      }];
      
      [postBody appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
      
      [request setHTTPBody:postBody];
    }
  }
  
  return request;
}

+ (NSData *)dataWithPostValue:(NSString *)value forKey:(NSString *)key boundary:(NSString *) boundary {
  NSMutableData *postBody = [NSMutableData data];
  
  [postBody appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\";\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[[NSString stringWithFormat:@"Content-Type: text\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];
  [postBody appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  
  return postBody;
}


+ (NSString *) queryStringFromParameters:(NSDictionary *) params withEncoding:(NSStringEncoding) encoding {
  NSMutableString *queryString = [NSMutableString new];
  [params enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSString* value, BOOL *stop) {
    NSAssert([key isKindOfClass:[NSString class]], @"Query parameters can only be string-string pairs");
    NSAssert([value isKindOfClass:[NSString class]], @"Query parameters can only be string-string pairs");
    
    [queryString appendFormat:queryString.length ? @"&%@=%@" : @"%@=%@", key, value];
  }];
  return queryString;
}

- (BITHTTPOperation*) operationWithURLRequest:(NSURLRequest*) request
                                   completion:(BITNetworkCompletionBlock) completion {
  BITHTTPOperation *operation = [BITHTTPOperation operationWithRequest:request
                                 ];
  [operation setCompletion:completion];
  
  return operation;
}

- (void)getPath:(NSString *)path parameters:(NSDictionary *)params completion:(BITNetworkCompletionBlock)completion {
  NSURLRequest *request = [self requestWithMethod:@"GET" path:path parameters:params];
  BITHTTPOperation *op = [self operationWithURLRequest:request
                                            completion:completion];
  [self enqeueHTTPOperation:op];
}

- (void)postPath:(NSString *)path parameters:(NSDictionary *)params completion:(BITNetworkCompletionBlock)completion {
  NSURLRequest *request = [self requestWithMethod:@"POST" path:path parameters:params];
  BITHTTPOperation *op = [self operationWithURLRequest:request
                                            completion:completion];
  [self enqeueHTTPOperation:op];
}

- (void) enqeueHTTPOperation:(BITHTTPOperation *) operation {
  [self.operationQueue addOperation:operation];
}

- (NSUInteger) cancelOperationsWithPath:(NSString*) path
                                 method:(NSString*) method {
  NSUInteger cancelledOperations = 0;
  for(BITHTTPOperation *operation in self.operationQueue.operations) {
    NSURLRequest *request = operation.URLRequest;
    
    BOOL matchedMethod = YES;
    if(method && ![request.HTTPMethod isEqualToString:method]) {
      matchedMethod = NO;
    }
    
    BOOL matchedPath = YES;
    if(path) {
      //method is not interesting here, we' just creating it to get the URL
      NSURL *url = [self requestWithMethod:@"GET" path:path parameters:nil].URL;
      matchedPath = [request.URL isEqual:url];
    }
    
    if(matchedPath && matchedMethod) {
      ++cancelledOperations;
      [operation cancel];
    }
  }
  return cancelledOperations;
}

- (NSOperationQueue *)operationQueue {
  if(nil == _operationQueue) {
    _operationQueue = [[NSOperationQueue alloc] init];
    _operationQueue.maxConcurrentOperationCount = 1;
  }
  return _operationQueue;
}

@end
