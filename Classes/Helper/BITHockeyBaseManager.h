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
/// @name Delegate
///-----------------------------------------------------------------------------

/**
 Sets the `BITUpdateManagerDelegate` delegate.
 
 When using `BITUpdateManager` to distribute updates of your beta or enterprise
 application, it is _REQUIRED_ to set this delegate and implement
 `[BITUpdateManagerDelegate customDeviceIdentifierForUpdateManager:]`!
 */
@property (nonatomic, assign) id delegate;

@end
