#import <Foundation/Foundation.h>

@interface TGDateUtils : NSObject

+ (void)reset;

+ (NSString *)stringForShortTime:(int)time;
+ (NSString *)stringForShortTime:(int)time daytimeVariant:(int *)daytimeVariant;
+ (NSString *)stringForShortTimeWithHours:(int)hours minutes:(int)minutes;
+ (NSString *)stringForDialogTime:(int)time;
+ (NSString *)stringForDayOfWeek:(int)date;
+ (NSString *)stringForMonthOfYear:(int)date;
+ (NSString *)stringForPreciseDate:(int)date;
+ (NSString *)stringForMessageListDate:(int)date;
+ (NSString *)stringForApproximateDate:(int)date;
+ (NSString *)stringForRelativeUpdate:(int)date;
+ (NSString *)stringForFullDate:(int)date;
+ (NSString *)stringForCallsListDate:(int)date;

@end

#ifdef __cplusplus
extern "C" {
#endif

bool TGUse12hDateFormat();
    
NSString *TGWeekdayNameFull(int number);
NSString *TGMonthNameFull(int number);
NSString *TGMonthNameShort(int number);
    
#ifdef __cplusplus
}
#endif
