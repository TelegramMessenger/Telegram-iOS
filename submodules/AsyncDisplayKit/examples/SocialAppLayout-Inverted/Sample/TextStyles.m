//
//  TextStyles.m
//  Texture
//
//  Copyright (c) Facebook, Inc. and its affiliates.  All rights reserved.
//  Changes after 4/13/2017 are: Copyright (c) Pinterest, Inc.  All rights reserved.
//  Licensed under Apache 2.0: http://www.apache.org/licenses/LICENSE-2.0
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
