//
//  CNSHockeyBaseManager.h
//  HockeySDK
//
//  Created by Andreas Linde on 04.06.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>



@interface BITHockeyBaseManager : NSObject

///-----------------------------------------------------------------------------
/// @name Modules
///-----------------------------------------------------------------------------


/**
 Defines the server URL to send data to or request data from
 
 By default this is set to the HockeyApp servers and there rarely should be a
 need to modify that.
 */
@property (nonatomic, copy) NSString *serverURL;


///-----------------------------------------------------------------------------
/// @name User Interface
///-----------------------------------------------------------------------------

/**
 The UIBarStyle of the update user interface navigation bar.
 */
@property (nonatomic, assign) UIBarStyle barStyle;

/**
 The UIModalPresentationStyle for showing the update user interface when invoked
 with the update alert.
 */
@property (nonatomic, assign) UIModalPresentationStyle modalPresentationStyle;


@end
