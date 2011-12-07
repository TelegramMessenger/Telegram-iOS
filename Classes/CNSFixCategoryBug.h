//
//  CNSFixCategoryBug.h
//  HockeySDK
//
//  Created by Andreas Linde on 12/7/11.
//  Copyright (c) 2011 Andreas Linde. All rights reserved.
//

#ifndef HockeySDK_CNSFixCategoryBug_h
#define HockeySDK_CNSFixCategoryBug_h

/**
 Add this macro before each category implementation, so we don't have to use
 -all_load or -force_load to load object files from static libraries that only contain
 categories and no classes.
 See http://developer.apple.com/library/mac/#qa/qa2006/qa1490.html for more info.
 
 Shamelessly borrowed from Three20
 */

#define CNS_FIX_CATEGORY_BUG(name) @interface CNS_FIX_CATEGORY_BUG##name @end \
@implementation CNS_FIX_CATEGORY_BUG##name @end


#endif
