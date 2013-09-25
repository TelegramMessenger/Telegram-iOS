#import "BITTestHelper.h"
#import "HockeySDKPrivate.h"

@implementation BITTestHelper

// loads test fixture from json file
// http://blog.roberthoglund.com/2010/12/ios-unit-testing-loading-bundle.html
+ (NSString *)jsonFixture:(NSString *)fixture {
	NSString *path = [[NSBundle bundleForClass:self.class] pathForResource:fixture ofType:@"json"];

	NSError *error = nil;
  NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];

  return content;
}

+ (BOOL)createTempDirectory:(NSString *)directory {
  NSFileManager *fm = [[NSFileManager alloc] init];
  
  if (![fm fileExistsAtPath:directory]) {
    NSDictionary *attributes = [NSDictionary dictionaryWithObject: [NSNumber numberWithUnsignedLong: 0755] forKey: NSFilePosixPermissions];
    NSError *theError = NULL;
    
    [fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:attributes error:&theError];
    if (theError)
      return NO;
  }
  
  return YES;
}

+ (BOOL)copyFixtureCrashReportWithFileName:(NSString *)filename {
  NSFileManager *fm = [[NSFileManager alloc] init];

  // the bundle identifier when running with unit tets is "otest"
  const char *progname = getprogname();
  if (progname == NULL) {
    return NO;
  }
  
  NSString *bundleIdentifierPathString = [NSString stringWithUTF8String: progname];

  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
  
  // create the PLCR cache dir
  NSString *plcrRootCrashesDir = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"com.plausiblelabs.crashreporter.data"];
  if (![BITTestHelper createTempDirectory:plcrRootCrashesDir])
    return NO;
  
  NSString *plcrCrashesDir = [plcrRootCrashesDir stringByAppendingPathComponent:bundleIdentifierPathString];
  if (![BITTestHelper createTempDirectory:plcrCrashesDir])
    return NO;
  
	NSString *filePath = [[NSBundle bundleForClass:self.class] pathForResource:filename ofType:@"plcrash"];
  
  NSError *theError = NULL;
  
  [fm copyItemAtPath:filePath toPath:[plcrCrashesDir stringByAppendingPathComponent:@"live_report.plcrash"] error:&theError];
  
  if (theError)
    return NO;
  else
    return YES;
}

@end
