//
// Created by Tikhonenko Pavel on 29/11/2013.
// Copyright (c) 2013 Coub. All rights reserved.
//


#import <Foundation/Foundation.h>

@class CBCoubNew;


@interface CBJSONCoubMapper : NSObject

+ (CBCoubNew *)updateCoubFromCoub:(CBCoubNew *)newCoub coub:(CBCoubNew *)coub;
+ (CBCoubNew *)updateCoubFromJSONObject:(NSDictionary *)jsonObj coub:(CBCoubNew *)coub;
+ (CBCoubNew *)coubFromJSONObject:(NSDictionary *)jsonObj;

@end