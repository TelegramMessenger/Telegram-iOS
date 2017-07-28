//
//  CBCoubAudioSource.h
//  Coub
//
//  Created by Tikhonenko Pavel on 18/11/2013.
//  Copyright (c) 2013 Coub. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CBCoubAudioSource : NSObject

@property (nonatomic, strong) NSString *cover;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *artist;
@property (nonatomic, strong) NSString *itunesURL;
@property (nonatomic, strong) NSString *songName;

+ (CBCoubAudioSource *)sourceFromData:(NSDictionary *)dict;

@end
