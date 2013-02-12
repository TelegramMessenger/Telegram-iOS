//
//  CNSHockeyBaseManager.h
//  HockeySDK
//
//  Created by Andreas Linde on 04.06.12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


/**
 The internal superclass for all component managers
 
 */

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
 
 Default is UIBarStyleBlackOpaque
 @see tintColor
 */
@property (nonatomic, assign) UIBarStyle barStyle;

/**
 The tint color of the update user interface navigation bar.
 
 The tintColor is used by default, you can either overwrite it `tintColor`
 or define another `barStyle` instead.
 
 Default is RGB(25, 25, 25)
 @see barStyle
 */
@property (nonatomic, strong) UIColor *tintColor;

/**
 The UIModalPresentationStyle for showing the update user interface when invoked
 with the update alert.
 */
@property (nonatomic, assign) UIModalPresentationStyle modalPresentationStyle;


@end
