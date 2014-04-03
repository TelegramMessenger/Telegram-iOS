//
//  BITCrashDetails.h
//  HockeySDK
//
//  Created by Andreas Linde on 03.04.14.
//
//

#import <Foundation/Foundation.h>

@interface BITCrashDetails : NSObject

@property (nonatomic, readonly, strong) NSString *incidentIdentifier;

@property (nonatomic, readonly, strong) NSString *reporterKey;

@property (nonatomic, readonly, strong) NSString *signal;

@property (nonatomic, readonly, strong) NSString *exceptionName;

@property (nonatomic, readonly, strong) NSString *exceptionReason;

@property (nonatomic, readonly, strong) NSDate *appStartTime;

@property (nonatomic, readonly, strong) NSDate *crashTime;

- (instancetype)initWithIncidentIdentifier:(NSString *)incidentIdentifier
                               reporterKey:(NSString *)reporterKey
                                    signal:(NSString *)signal
                             exceptionName:(NSString *)exceptionName
                           exceptionReason:(NSString *)exceptionReason
                              appStartTime:(NSDate *)appStartTime
                                 crashTime:(NSDate *)crashTime;

@end
