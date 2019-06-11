//
// Created by Tikhonenko Pavel on 30/11/2013.
// Copyright (c) 2013 Coub. All rights reserved.
//


#import <Foundation/Foundation.h>


@interface CBTagNew : NSObject
@property (nonatomic, strong) NSNumber *tagId;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *value;
@property (nonatomic, readonly) NSString *hashTag;

+ (instancetype)tagWithAttributes:(NSDictionary *)attributes;

@end