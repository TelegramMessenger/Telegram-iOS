
@interface BITTestHelper : NSObject

+ (id)jsonFixture:(NSString *)fixture;
+ (BOOL)createTempDirectory:(NSString *)directory;
+ (BOOL)copyFixtureCrashReportWithFileName:(NSString *)filename;

@end
