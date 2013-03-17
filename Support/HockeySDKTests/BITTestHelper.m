#import "BITTestHelper.h"

@implementation BITTestHelper

// loads test fixture from json file
// http://blog.roberthoglund.com/2010/12/ios-unit-testing-loading-bundle.html
+ (NSString *)jsonFixture:(NSString *)fixture {
	NSString *path = [[NSBundle bundleForClass:self.class] pathForResource:fixture ofType:@"json"];

	NSError *error = nil;
  NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];

  return content;
}

@end
