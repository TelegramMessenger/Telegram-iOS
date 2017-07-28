//
//  CBCoubNew.h
//  Coub
//
//  Created by Tikhonenko Pavel on 18/11/2013.
//  Copyright (c) 2013 Coub. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CBCoubAuthorVO.h"
#import "CBCoubAudioSource.h"
#import "CBCoubVideoSource.h"
#import "CBCoubAsset.h"

@interface CBCoubNew : NSObject<CBCoubAsset>

@property(nonatomic, strong) NSString *coubID;
@property(nonatomic, strong) NSString *permalink;
@property(nonatomic, strong) NSString *originalPermalink;
@property(nonatomic, strong) NSString *visibility; // kCBCoubVisibility*, see above
@property(nonatomic, assign) BOOL isDone;

@property(nonatomic, strong) CBCoubAuthorVO *author;
@property(nonatomic, strong) CBCoubAuthorVO *recouber;

@property(nonatomic, strong) NSString *title;
@property(nonatomic, strong) NSDate *creationDate;
@property(nonatomic, strong) NSDate *originalCreationDate;
@property(nonatomic, strong) NSArray *tags; //CBTagNew

//Stats
@property(nonatomic, assign) NSUInteger viewCount;
@property(nonatomic, assign) NSUInteger likeCount;
@property(nonatomic, assign) NSUInteger recoubCount;
@property(nonatomic, assign) BOOL liked;                                // whether the current user likes the coub; does not update likeCount
@property(nonatomic, assign) BOOL recoubed;
@property(nonatomic, assign) BOOL cotd;
@property(nonatomic, assign) BOOL flagged;
@property(nonatomic, assign) BOOL deleted;

@property(nonatomic, assign) CBCoubAudioType audioType;

@property(nonatomic, strong) NSString *externalDownloadType;
@property(nonatomic, strong) NSString *externalDownloadSource; // youtube/vimeo URL

//@property (nonatomic, readonly) NSOrderedSet *recoubersOthenThanCurrentUser;
@property (nonatomic, readonly) NSURL *coubWebViewURL;
@property(nonatomic, readonly) NSURL *mediumImageURL;
@property(nonatomic, readonly) NSURL *largeImageURL;
@property(nonatomic, readonly) BOOL isRecoub;
@property(nonatomic, readonly) BOOL isMyCoub;

@property(nonatomic, retain) NSString *remoteVideoLocation;
@property(nonatomic, retain) NSString *remoteAudioLocation;
@property(nonatomic, retain) NSString *remoteAudioLocationPattern;
@property(nonatomic, retain) NSString *mediumPicture;
@property(nonatomic, retain) NSString *largePicture;
@property(nonatomic, retain) NSString *creationDateAsString;
@property(nonatomic, retain) NSString *originalCreationDateAsString;

@property(nonatomic, readonly) NSURL *remoteVideoFileURL;

@property(nonatomic, assign) BOOL isCoubSourcesAvailable;
@property(nonatomic, strong) CBCoubAudioSource *audioSource;
@property(nonatomic, strong) CBCoubVideoSource *videoSource;

+ (CBCoubNew *)coubWithAttributes:(NSDictionary *)attributes;

@end
