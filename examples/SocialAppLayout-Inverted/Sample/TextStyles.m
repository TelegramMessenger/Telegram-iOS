//
//  TextStyles.m
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the /ASDK-Licenses directory of this source tree. An additional
//  grant of patent rights can be found in the PATENTS file in the same directory.
//
//  Modifications to this file made after 4/13/2017 are: Copyright (c) 2017-present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//

#import "TextStyles.h"

@implementation TextStyles

+ (NSDictionary *)nameStyle
{
    return @{
        NSFontAttributeName : [UIFont boldSystemFontOfSize:15.0],
        NSForegroundColorAttributeName: [UIColor blackColor]
    };
}

+ (NSDictionary *)usernameStyle
{
    return @{
        NSFontAttributeName : [UIFont systemFontOfSize:13.0],
        NSForegroundColorAttributeName: [UIColor lightGrayColor]
    };
}

+ (NSDictionary *)timeStyle
{
    return @{
        NSFontAttributeName : [UIFont systemFontOfSize:13.0],
        NSForegroundColorAttributeName: [UIColor grayColor]
    };
}

+ (NSDictionary *)postStyle
{
    return @{
        NSFontAttributeName : [UIFont systemFontOfSize:15.0],
        NSForegroundColorAttributeName: [UIColor blackColor]
    };
}

+ (NSDictionary *)postLinkStyle
{
    return @{
        NSFontAttributeName : [UIFont systemFontOfSize:15.0],
        NSForegroundColorAttributeName: [UIColor colorWithRed:59.0/255.0 green:89.0/255.0 blue:152.0/255.0 alpha:1.0],
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
    };
}

+ (NSDictionary *)cellControlStyle
{
    return @{
        NSFontAttributeName : [UIFont systemFontOfSize:13.0],
        NSForegroundColorAttributeName: [UIColor lightGrayColor]
    };
}

+ (NSDictionary *)cellControlColoredStyle
{
    return @{
        NSFontAttributeName : [UIFont systemFontOfSize:13.0],
        NSForegroundColorAttributeName: [UIColor colorWithRed:59.0/255.0 green:89.0/255.0 blue:152.0/255.0 alpha:1.0]
    };
}

@end
