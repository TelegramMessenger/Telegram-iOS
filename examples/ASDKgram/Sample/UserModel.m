//
//  UserModel.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "UserModel.h"
#import "Utilities.h"

@implementation UserModel
{
  BOOL _fullUserInfoFetchRequested;
  BOOL _fullUserInfoFetchDone;
  void (^_fullUserInfoCompletionBlock)(UserModel *);
}

#pragma mark - Lifecycle

- (instancetype)initWithUnsplashPhoto:(NSDictionary *)dictionary
{
  self = [super init];
  
  if (self) {
    _fullUserInfoFetchRequested = NO;
    _fullUserInfoFetchDone = NO;
    
    [self loadUserDataFromDictionary:dictionary];
  }
  
  return self;
}

#pragma mark - Instance Methods

- (NSAttributedString *)usernameAttributedStringWithFontSize:(CGFloat)size
{
  return [NSAttributedString attributedStringWithString:self.username fontSize:size color:[UIColor darkBlueColor] firstWordColor:nil];
}

- (NSAttributedString *)fullNameAttributedStringWithFontSize:(CGFloat)size
{
  return [NSAttributedString attributedStringWithString:self.fullName fontSize:size color:[UIColor lightGrayColor] firstWordColor:nil];
}

- (void)fetchAvatarImageWithCompletionBlock:(void(^)(UserModel *, UIImage *))block
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
    NSURLSession *session      = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURLSessionDataTask *task = [session dataTaskWithURL:_userPicURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
      if (data) {
        UIImage *image = [UIImage imageWithData:data];
    
        dispatch_async(dispatch_get_main_queue(), ^{
          if (block) {
            block(self, image);
          }
        });
      }
    }];
    [task resume];
  });
}

- (void)downloadCompleteUserDataWithCompletionBlock:(void(^)(UserModel *))block;
{
  if (_fullUserInfoFetchDone) {
    NSAssert(!_fullUserInfoCompletionBlock, @"Should not have a waiting block at this point");
    // complete user info fetch complete - excute completion block
    if (block) {
      block(self);
    }

  } else {
    NSAssert(!_fullUserInfoCompletionBlock, @"Should not have a waiting block at this point");
    // set completion block
    _fullUserInfoCompletionBlock = block;
    
    if (!_fullUserInfoFetchRequested) {
      // if fetch not in progress, beging
      [self fetchCompleteUserData];
    }
  }
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"%@", self.dictionaryRepresentation];
}

#pragma mark - Helper Methods

- (void)fetchCompleteUserData
{
  _fullUserInfoFetchRequested = YES;
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
  
    // fetch JSON data from server
    NSString *urlString     = [NSString stringWithFormat:@"https://api.500px.com/v1/users/show?id=%@&consumer_key=Fi13GVb8g53sGvHICzlram7QkKOlSDmAmp9s9aqC", _userID];
    
    NSURL *url              = [NSURL URLWithString:urlString];
    NSURLSession *session   = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURLSessionDataTask *task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
      if (data) {
        NSDictionary *response  = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        
        // parse JSON data
        if ([response isKindOfClass:[NSDictionary class]]) {
          [self loadUserDataFromDictionary:response];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
          _fullUserInfoFetchDone = YES;
          
          if (_fullUserInfoCompletionBlock) {
            _fullUserInfoCompletionBlock(self);
            
            // IT IS ESSENTIAL to nil the block, as it retains a view controller BECAUSE it uses an instance variable which
            // means that self is retained. It could continue to live on forever
            // If we don't release this.
            _fullUserInfoCompletionBlock = nil;
          }
        });
      }
    }];
    [task resume];
  });
}

- (void)loadUserDataFromDictionary:(NSDictionary *)dictionary
{
  NSDictionary *userDictionary = [dictionary objectForKey:@"user"];
  if (![userDictionary isKindOfClass:[NSDictionary class]]) {
    return;
  }

  _userID                   = [self guardJSONElement:[userDictionary objectForKey:@"id"]];
  _username                 = [[self guardJSONElement:[userDictionary objectForKey:@"username"]] lowercaseString];
  
  if (_username == nil) {
    _username               = @"Anonymous";
  }
  
  _firstName                = [self guardJSONElement:[userDictionary objectForKey:@"first_name"]];
  _lastName                 = [self guardJSONElement:[userDictionary objectForKey:@"last_name"]];
  _fullName                 = [self guardJSONElement:[userDictionary objectForKey:@"name"]];
  _location                 = [self guardJSONElement:[userDictionary objectForKey:@"location"]];
  _about                    = [self guardJSONElement:[userDictionary objectForKey:@"bio"]];
  _photoCount               = [[self guardJSONElement:[userDictionary objectForKey:@"total_photos"]] integerValue];
  _galleriesCount           = [[self guardJSONElement:[userDictionary objectForKey:@"total_collections"]] integerValue];
  _dictionaryRepresentation = userDictionary;
  
  NSString *urlString       = [self guardJSONElement:[userDictionary objectForKey:@"profile_image"][@"medium"]];
  _userPicURL               = urlString ? [NSURL URLWithString:urlString] : nil;

}

- (id)guardJSONElement:(id)element
{
  return (element == [NSNull null]) ? nil : element;
}

@end
