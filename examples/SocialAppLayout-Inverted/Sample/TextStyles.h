//
//  TextStyles.h
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TextStyles : NSObject

+ (NSDictionary *)nameStyle;
+ (NSDictionary *)usernameStyle;
+ (NSDictionary *)timeStyle;
+ (NSDictionary *)postStyle;
+ (NSDictionary *)postLinkStyle;
+ (NSDictionary *)cellControlStyle;
+ (NSDictionary *)cellControlColoredStyle;

@end
