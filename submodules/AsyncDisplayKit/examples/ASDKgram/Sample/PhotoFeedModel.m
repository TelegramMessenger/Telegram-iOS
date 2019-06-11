//
//  PhotoFeedModel.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import "PhotoFeedModel.h"
#import "ImageURLModel.h"

#define unsplash_ENDPOINT_HOST      @"https://api.unsplash.com/"
#define unsplash_ENDPOINT_POPULAR   @"photos?order_by=popular"
#define unsplash_ENDPOINT_SEARCH    @"photos/search?geo="    //latitude,longitude,radius<units>
#define unsplash_ENDPOINT_USER      @"photos?user_id="
#define unsplash_CONSUMER_KEY_PARAM @"&client_id=3b99a69cee09770a4a0bbb870b437dbda53efb22f6f6de63714b71c4df7c9642"   // PLEASE REQUEST YOUR OWN UNSPLASH CONSUMER KEY
#define unsplash_IMAGES_PER_PAGE    30

@implementation PhotoFeedModel
{
  PhotoFeedModelType _feedType;
  
  NSMutableArray *_photos;    // array of PhotoModel objects
  NSMutableArray *_ids;
  
  CGSize         _imageSize;
  NSString       *_urlString;
  NSUInteger     _currentPage;
  NSUInteger     _totalPages;
  NSUInteger     _totalItems;
  BOOL           _fetchPageInProgress;
  BOOL           _refreshFeedInProgress;
  NSURLSessionDataTask *_task;

  NSUInteger    _userID;
}

#pragma mark - Lifecycle

- (instancetype)initWithPhotoFeedModelType:(PhotoFeedModelType)type imageSize:(CGSize)size
{
  self = [super init];
  
  if (self) {
    _feedType    = type;
    _imageSize   = size;
    _photos      = [[NSMutableArray alloc] init];
    _ids         = [[NSMutableArray alloc] init];
    _currentPage = 0;
    
    NSString *apiEndpointString;
    switch (type) {
      case (PhotoFeedModelTypePopular):
        apiEndpointString = unsplash_ENDPOINT_POPULAR;
        break;
        
      case (PhotoFeedModelTypeLocation):
        apiEndpointString = unsplash_ENDPOINT_SEARCH;
        break;
        
      case (PhotoFeedModelTypeUserPhotos):
        apiEndpointString = unsplash_ENDPOINT_USER;
        break;
        
      default:
        break;
    }
    _urlString = [[unsplash_ENDPOINT_HOST stringByAppendingString:apiEndpointString] stringByAppendingString:unsplash_CONSUMER_KEY_PARAM];
  }
  
  return self;
}

#pragma mark - Instance Methods

- (NSArray *)photos
{
  return [_photos copy];
}

- (NSUInteger)totalNumberOfPhotos
{
  return _totalItems;
}

- (NSUInteger)numberOfItemsInFeed
{
  return [_photos count];
}

- (PhotoModel *)objectAtIndex:(NSUInteger)index
{
  return [_photos objectAtIndex:index];
}

- (NSInteger)indexOfPhotoModel:(PhotoModel *)photoModel
{
  return [_photos indexOfObjectIdenticalTo:photoModel];
}

- (void)updatePhotoFeedModelTypeUserId:(NSUInteger)userID
{
  _userID = userID;
  
  NSString *userString = [NSString stringWithFormat:@"%lu", (long)userID];
  _urlString = [unsplash_ENDPOINT_HOST stringByAppendingString:unsplash_ENDPOINT_USER];
  _urlString = [[_urlString stringByAppendingString:userString] stringByAppendingString:@"&sort=created_at&image_size=3&include_store=store_download&include_states=voted"];
  _urlString = [_urlString stringByAppendingString:unsplash_CONSUMER_KEY_PARAM];
}

- (void)clearFeed
{
  _photos = [[NSMutableArray alloc] init];
  _ids = [[NSMutableArray alloc] init];
  _currentPage = 0;
  _fetchPageInProgress = NO;
  _refreshFeedInProgress = NO;
  [_task cancel];
  _task = nil;
}

- (void)requestPageWithCompletionBlock:(void (^)(NSArray *))block numResultsToReturn:(NSUInteger)numResults
{
  // only one fetch at a time
  if (_fetchPageInProgress) {
    return;
  } else {
    _fetchPageInProgress = YES;
    [self fetchPageWithCompletionBlock:block numResultsToReturn:numResults];
  }
}

- (void)refreshFeedWithCompletionBlock:(void (^)(NSArray *))block numResultsToReturn:(NSUInteger)numResults
{
  // only one fetch at a time
  if (_refreshFeedInProgress) {
    return;
    
  } else {
    _refreshFeedInProgress = YES;
    _currentPage = 0;
    
    // FIXME: blow away any other requests in progress
    [self fetchPageWithCompletionBlock:^(NSArray *newPhotos) {
      if (block) {
        block(newPhotos);
      }
      _refreshFeedInProgress = NO;
    } numResultsToReturn:numResults replaceData:YES];
  }
}

#pragma mark - Helper Methods

- (void)fetchPageWithCompletionBlock:(void (^)(NSArray *))block numResultsToReturn:(NSUInteger)numResults
{
  [self fetchPageWithCompletionBlock:block numResultsToReturn:numResults replaceData:NO];
}

- (void)fetchPageWithCompletionBlock:(void (^)(NSArray *))block numResultsToReturn:(NSUInteger)numResults replaceData:(BOOL)replaceData
{
  // early return if reached end of pages
  if (_totalPages) {
    if (_currentPage == _totalPages) {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (block) {
          block(@[]);
        }
      });
      return;
    }
  }

  NSUInteger numPhotos = (numResults < unsplash_IMAGES_PER_PAGE) ? numResults : unsplash_IMAGES_PER_PAGE;
    
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSMutableArray *newPhotos = [NSMutableArray array];
    NSMutableArray *newIDs = [NSMutableArray array];
    
    @synchronized(self) {
      NSUInteger nextPage      = _currentPage + 1;
      NSString *imageSizeParam = [ImageURLModel imageParameterForClosestImageSize:_imageSize];
      NSString *urlAdditions   = [NSString stringWithFormat:@"&page=%lu&per_page=%lu%@", (unsigned long)nextPage, (long)numPhotos, imageSizeParam];
      NSURL *url               = [NSURL URLWithString:[_urlString stringByAppendingString:urlAdditions]];
      NSURLSession *session    = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
      _task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        @synchronized(self) {
          NSHTTPURLResponse *httpResponse = nil;
          if (data && [response isKindOfClass:[NSHTTPURLResponse class]]) {
            httpResponse = (NSHTTPURLResponse *)response;
            NSArray *objects = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            
            if ([objects isKindOfClass:[NSArray class]]) {
              _currentPage = nextPage;
              _totalItems = [[httpResponse allHeaderFields][@"x-total"] integerValue];
              _totalPages  = _totalItems / unsplash_IMAGES_PER_PAGE; // default per page is 10
              if (_totalItems % unsplash_IMAGES_PER_PAGE != 0) {
                _totalPages += 1;
              }
              
              NSArray *photos = objects;
              for (NSDictionary *photoDictionary in photos) {
                if ([photoDictionary isKindOfClass:[NSDictionary class]]) {
                  PhotoModel *photo = [[PhotoModel alloc] initWithUnsplashPhoto:photoDictionary];
                  if (photo) {
                    if (replaceData || ![_ids containsObject:photo.photoID]) {
                      [newPhotos addObject:photo];
                      [newIDs addObject:photo.photoID];
                    }
                  }
                }
              }
            }
          }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
          @synchronized(self) {
            if (replaceData) {
              _photos = [newPhotos mutableCopy];
              _ids = [newIDs mutableCopy];
            } else {
              [_photos addObjectsFromArray:newPhotos];
              [_ids addObjectsFromArray:newIDs];
            }
            if (block) {
              block(newPhotos);
            }
            _fetchPageInProgress = NO;
          }
        });
      }];
      [_task resume];
    }
  });
}

#pragma mark - IGListDiffable

- (id<NSObject>)diffIdentifier
{
  return self;
}

- (BOOL)isEqualToDiffableObject:(id<IGListDiffable>)object
{
  return self == object;
}

@end
