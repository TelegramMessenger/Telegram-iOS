//
//  CBCoubVideoSource.h
//  Coub
//
//  Created by Tikhonenko Pavel on 18/11/2013.
//  Copyright (c) 2013 Coub. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CBCoubVideoSource : NSObject

@property (nonatomic, strong) NSString *yourtubeURL;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *thumbnail;
@property (nonatomic, readonly) BOOL isYouTube;

+ (CBCoubVideoSource *)sourceFromData:(NSDictionary *)dict;

@end