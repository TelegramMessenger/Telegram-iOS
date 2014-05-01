//
//  BITCrashDetails.m
//  HockeySDK
//
//  Created by Andreas Linde on 03.04.14.
//
//

#import "BITCrashDetails.h"

@implementation BITCrashDetails

- (instancetype)initWithIncidentIdentifier:(NSString *)incidentIdentifier
                               reporterKey:(NSString *)reporterKey
                                    signal:(NSString *)signal
                             exceptionName:(NSString *)exceptionName
                           exceptionReason:(NSString *)exceptionReason
                              appStartTime:(NSDate *)appStartTime
                                 crashTime:(NSDate *)crashTime
                                  appBuild:(NSString *)appBuild
{
  if ((self = [super init])) {
    _incidentIdentifier = incidentIdentifier;
    _reporterKey = reporterKey;
    _signal = signal;
    _exceptionName = exceptionName;
    _exceptionReason = exceptionReason;
    _appStartTime = appStartTime;
    _crashTime = crashTime;
    _appBuild = appBuild;
  }
  return self;
}

@end
