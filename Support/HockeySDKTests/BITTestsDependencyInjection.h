#import <XCTest/XCTest.h>

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

#define MOCKITO_SHORTHAND
#import <OCMockitoIOS/OCMockitoIOS.h>

@interface BITTestsDependencyInjection : XCTestCase

- (void)setMockNotificationCenter:(id)mockNotificationCenter;
- (id)mockNotificationCenter;

@end
