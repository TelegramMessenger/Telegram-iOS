#import <Foundation/Foundation.h>

@interface BITTestHelper : NSObject

+ (id)jsonFixture:(NSString *)fixture;
+ (BOOL)createTempDirectory:(NSString *)directory;
+ (BOOL)copyFixtureCrashReportWithFileName:(NSString *)filename;
+ (NSData *)dataOfFixtureCrashReportWithFileName:(NSString *)filename;

@end
