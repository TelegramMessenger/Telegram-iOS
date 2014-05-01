//
//  BITCrashDetails.h
//  HockeySDK
//
//  Created by Andreas Linde on 03.04.14.
//
//

#import <Foundation/Foundation.h>

@interface BITCrashDetails : NSObject

/**
 *  UUID for the crash report
 */
@property (nonatomic, readonly, strong) NSString *incidentIdentifier;

/**
 *  UUID for the app installation on the device
 */
@property (nonatomic, readonly, strong) NSString *reporterKey;

/**
 *  Signal that caused the crash
 */
@property (nonatomic, readonly, strong) NSString *signal;

/**
 *  Exception name that triggered the crash, nil if the crash was not caused by an exception
 */
@property (nonatomic, readonly, strong) NSString *exceptionName;

/**
 *  Exception reason, nil if the crash was not caused by an exception
 */
@property (nonatomic, readonly, strong) NSString *exceptionReason;

/**
 *  Date and time the app started, nil if unknown
 */
@property (nonatomic, readonly, strong) NSDate *appStartTime;

/**
 *  Date and time the crash occured, nil if unknown
 */
@property (nonatomic, readonly, strong) NSDate *crashTime;

/**
 *  CFBundleVersion value of the app that crashed
 */
@property (nonatomic, readonly, strong) NSString *appBuild;

- (instancetype)initWithIncidentIdentifier:(NSString *)incidentIdentifier
                               reporterKey:(NSString *)reporterKey
                                    signal:(NSString *)signal
                             exceptionName:(NSString *)exceptionName
                           exceptionReason:(NSString *)exceptionReason
                              appStartTime:(NSDate *)appStartTime
                                 crashTime:(NSDate *)crashTime
                                  appBuild:(NSString *)appBuild;

@end
